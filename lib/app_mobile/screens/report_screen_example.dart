import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../../services/report_service.dart';
import '../../services/ml_validator_service.dart';
import '../../widgets/report_validation_helper.dart';
import 'map_search_screen.dart';
import '../../services/ml_validator_service.dart';
import '../../widgets/report_validation_helper.dart';

// NOTE: This is an EXAMPLE showing how to integrate ML validation
// Copy the key parts into your existing report_screen.dart

class ReportScreenWithMLValidation extends StatefulWidget {
  const ReportScreenWithMLValidation({super.key});

  @override
  State<ReportScreenWithMLValidation> createState() =>
      _ReportScreenWithMLValidationState();
}

class _ReportScreenWithMLValidationState
    extends State<ReportScreenWithMLValidation> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final ReportService _reportService = ReportService();
  late MLValidatorService _mlValidator;

  String? _selectedCategory;
  String _department = '';
  File? _selectedImage;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  ValidationResult? _lastValidationResult;

  final List<String> _categories = [
    'Water Pollution',
    'Air Pollution',
    'Waste Management',
    'Industrial Hazard',
    'Environmental Damage',
  ];

  @override
  void initState() {
    super.initState();
    _mlValidator = MLValidatorService();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _mlValidator.dispose();
    super.dispose();
  }

  // ==================== ML VALIDATION METHODS ====================

  /// Validate image when it's picked
  Future<void> _validateAndPickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    // Show validation dialog
    if (mounted) {
      final isApproved = await ReportValidationHelper.showImageValidationDialog(
        context,
        image.path,
      );

      if (isApproved && mounted) {
        setState(() {
          _selectedImage = File(image.path);
        });

        // Validate for future use with hybrid strategy (no description available at this stage)
        _lastValidationResult = await _mlValidator.validateImage(
          image.path,
          category: 'unknown',
        );

        _showSnackBar(
          'Image selected and validated! ✅',
          Colors.green,
          Icons.check_circle,
        );
      } else {
        _showSnackBar(
          'Image rejected. Please try another image.',
          Colors.orange,
          Icons.warning_amber_rounded,
        );
      }
    }
  }

  /// Enhanced submit with ML validation
  Future<void> _submitReportWithValidation() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedCategory == null) {
      _showSnackBar(
        'Please select a category',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      _showSnackBar(
        'Please capture your GPS location',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
      return;
    }

    if (_selectedImage == null) {
      _showSnackBar(
        'Please upload an image of the issue',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
      return;
    }

    // ==================== ADDITIONAL ML CHECKS ====================
    // Re-validate image before submission with hybrid strategy (confidence + semantics + description)
    final validationResult = await _mlValidator.validateImage(
      _selectedImage!.path,
      category: _selectedCategory ?? 'unknown',
      description: _descriptionController.text,
    );

    if (!validationResult.isValid) {
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Image Validation Warning'),
            content: Text(validationResult.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit Anyway'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }
    }

    // ==================== SUBMIT ====================
    setState(() {
      _isSubmitting = true;
    });

    try {
      final submitResult = await _reportService.submitReport(
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        exactLocation: _locationController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        imageFile: _selectedImage,
      );

      final String reportId = submitResult['reportId'] as String;
      final verification =
          submitResult['verification'] as Map<String, dynamic>?;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Report Submitted Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Report ID: $reportId'),
                if (validationResult.isValid)
                  Text(
                    'Detected: ${validationResult.topPrediction?.label ?? 'Unknown'}',
                  ),
                Text(
                  'Status: ${verification != null ? verification['status'] : 'pending verification'}',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

        // Show verification dialog if available
        if (verification != null && mounted) {
          final String vStatus =
              verification['status'] ?? 'pending verification';
          final String vReason = verification['reason'] ?? '';
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                vStatus == 'submitted'
                    ? 'Report Submitted'
                    : 'Verification Result',
              ),
              content: Text(
                vReason.isNotEmpty
                    ? vReason
                    : 'No additional verification details',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        // Reset form
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error submitting report: $e',
          Colors.red,
          Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _descriptionController.clear();
    _locationController.clear();
    setState(() {
      _selectedCategory = null;
      _department = '';
      _selectedImage = null;
      _latitude = null;
      _longitude = null;
      _lastValidationResult = null;
    });
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Environmental Report'),
        elevation: 0,
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting your report...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                      validator: (value) {
                        if (value == null) return 'Please select a category';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the environmental issue...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please provide a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Location
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please provide a location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Image picker with ML validation
                    if (_selectedImage != null) ...[
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (_lastValidationResult != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _lastValidationResult!.isValid
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _lastValidationResult!.isValid
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _lastValidationResult!.isValid
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: _lastValidationResult!.isValid
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _lastValidationResult!
                                              .topPrediction
                                              ?.label ??
                                          'Image validated',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_lastValidationResult!.topPrediction !=
                                        null)
                                      Text(
                                        'Confidence: ${(_lastValidationResult!.topPrediction!.confidence * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _validateAndPickImage,
                        icon: const Icon(Icons.edit),
                        label: const Text('Change Image'),
                      ),
                    ] else
                      ElevatedButton.icon(
                        onPressed: _validateAndPickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Pick Image'),
                      ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : _submitReportWithValidation,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
