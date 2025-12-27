import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../../services/report_service.dart';
import '../../services/ml_validator_service.dart';
import 'map_search_screen.dart';

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

  // Basic sensitive words list for ethical/content validation.
  // Expand this list as policy requirements evolve or load from remote config.
  final Set<String> _sensitiveWords = {
    'stupid',
    'idiot',
    'dumb',
    'fool',
    'useless',
    'trash',
    'garbage',
    'pathetic',
    'lazy',
    'incompetent',
    'hate',
    'hell',
    'damn',
    'shut up',
    'blame',
    'worst',
    'irresponsible',
    'negligent',
    'fuck you',
    'fuck',
  };

  String? _selectedCategory;
  String _department = '';
  File? _selectedImage;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  ValidationResult? _lastValidationResult;

  final List<String> _categories = [
    'Public equipment problem',
    'Damage/missing road signs',
    'Faded road markings',
    'Traffic light problem',
    'Streetlights problem',
    'Damage roads',
    'Road potholes',
  ];

  @override
  void initState() {
    super.initState();
    _mlValidator = MLValidatorService();
  }

  List<String> _findSensitiveWords(String text) {
    if (text.trim().isEmpty) return <String>[];
    final lower = text.toLowerCase();
    return _sensitiveWords.where((w) => lower.contains(w)).toList();
  }

  Future<List<String>> _checkImageSensitiveWords() async {
    if (_selectedImage == null) return <String>[];
    try {
      final validation = await _mlValidator.validateImage(
        _selectedImage!.path,
        category: _selectedCategory ?? 'unknown',
        description: _descriptionController.text,
      );

      final combined =
          '${validation.message ?? ''} ${validation.topPrediction?.label ?? ''}'
              .toLowerCase();
      return _findSensitiveWords(combined);
    } catch (e) {
      // If ML service fails, we conservatively return no matches so submission can continue,
      // but we log the error for debugging.
      print('Error during image sensitive-word check: $e');
      return <String>[];
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _mlValidator.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationAndAddress() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showSnackBar(
            'Location services are disabled. Please enable them.',
            Colors.orange,
            Icons.warning_amber_rounded,
          );
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showSnackBar(
              'Location permissions are denied.',
              Colors.red,
              Icons.error_outline,
            );
          }
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnackBar(
            'Location permissions are permanently denied. Please enable them in settings.',
            Colors.red,
            Icons.error_outline,
          );
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = _formatAddress(place);

          setState(() {
            _locationController.text = address;
          });
        }
      } catch (e) {
        print('Error getting address: $e');
      }

      setState(() {
        _isLoadingLocation = false;
      });

      if (mounted) {
        _showSnackBar(
          'Location captured successfully!',
          Colors.green,
          Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error getting location: $e',
          Colors.red,
          Icons.error_outline,
        );
      }
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  String _formatAddress(Placemark place) {
    List<String> addressParts = [];

    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.postalCode != null && place.postalCode!.isNotEmpty) {
      addressParts.add(place.postalCode!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }

    return addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Location: ${_latitude?.toStringAsFixed(6)}, ${_longitude?.toStringAsFixed(6)}';
  }

  Future<void> _pickImageWithValidation() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    if (mounted) {
      setState(() {
        _selectedImage = File(image.path);
      });

      _showSnackBar('Image selected! ✅', Colors.green, Icons.check_circle);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error taking photo: $e',
          Colors.red,
          Icons.error_outline,
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Select Image Source',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageSourceOption(
                icon: Icons.photo_library,
                title: 'Gallery',
                subtitle: 'Choose from your photos',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _pickImageWithValidation();
                },
              ),
              const SizedBox(height: 12),
              _buildImageSourceOption(
                icon: Icons.camera_alt,
                title: 'Camera',
                subtitle: 'Take a new photo',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      if (category != null) {
        _department = ReportService.getDepartmentForCategory(category);
      } else {
        _department = '';
      }
    });
  }

  void _showSnackBar(String message, Color backgroundColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _validateAndShowResults(String reportId) async {
    try {
      if (_selectedImage == null) {
        print('⚠️ Validation skipped: no selected image');
        return;
      }

      final imagePath = _selectedImage!.path;
      final hasLocationAndCategory =
          _selectedCategory != null && _latitude != null && _longitude != null;

      // Step 1: Validate image content with hybrid strategy (confidence + semantics + description)
      ValidationResult validationResult;
      try {
        validationResult = await _mlValidator.validateImage(
          imagePath,
          category: _selectedCategory ?? 'unknown',
          description: _descriptionController.text,
        );
        print(
          'ℹ️ Validation result: isValid=${validationResult.isValid}, message=${validationResult.message}',
        );
        if (validationResult.topPrediction != null) {
          print(
            'ℹ️ Top prediction: ${validationResult.topPrediction!.label} (${(validationResult.topPrediction!.confidence * 100).toStringAsFixed(2)}%)',
          );
        }
      } catch (e, st) {
        print('❌ Exception during validateImage: $e');
        print(st);
        rethrow;
      }

      DuplicateDetectionResult? duplicateResult;
      if (hasLocationAndCategory) {
        try {
          duplicateResult = await _mlValidator.checkForDuplicates(
            imagePath: imagePath,
            category: _selectedCategory!,
            latitude: _latitude!,
            longitude: _longitude!,
            similarityThreshold: 0.85,
          );
        } catch (e, st) {
          print('❌ Exception during checkForDuplicates: $e');
          print(st);
        }
      } else {
        print('ℹ️ Skipping duplicate check: missing category or location');
      }

      // Normalize duplicate result into local non-nullable variables to avoid any null dereference
      final bool dupIsDuplicate = duplicateResult?.isDuplicate ?? false;
      final double dupSimilarity = duplicateResult?.similarity ?? 0.0;
      if (duplicateResult != null) {
        print(
          'ℹ️ Duplicate check result: isDuplicate=$dupIsDuplicate, similarity=$dupSimilarity',
        );
      }

      final isValidationPassed =
          validationResult.isValid || dupIsDuplicate || (dupSimilarity >= 0.85);

      if (isValidationPassed) {
        print('✅ Validation passed - updating status to successfully verified');
        await _reportService.updateReportStatus(
          reportId,
          'successfully verified',
        );
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ML Validation Results'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isValidationPassed
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      border: Border.all(
                        color: isValidationPassed
                            ? Colors.green
                            : Colors.orange,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isValidationPassed
                              ? Icons.verified_user
                              : Icons.info_outline,
                          color: isValidationPassed
                              ? Colors.green
                              : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isValidationPassed
                                    ? 'Successfully Verified ✓'
                                    : 'Needs Review',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isValidationPassed
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isValidationPassed
                                    ? 'Report passed all validations'
                                    : 'Report requires manual verification',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Content validation result
                  const Text(
                    'Content Analysis:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    validationResult.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: validationResult.isValid
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Duplicate detection result
                  const Text(
                    'Duplicate Detection:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (dupIsDuplicate)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Duplicate Found',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Similarity: ${(dupSimilarity * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (dupSimilarity > 0.6)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Similar Report Found',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Similarity: ${(dupSimilarity * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'No duplicates found',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Report ID: $reportId',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (validationResult.topPrediction != null) ...<Widget>[
                    const SizedBox(height: 12),
                    const Text(
                      'Top Detection:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      validationResult.topPrediction.toString(),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
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
    } catch (e) {
      print('Error validating image: $e');
    }
  }

  Future<void> _submitReport() async {
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

    // --- Ethical/content validation: check description for sensitive words ---
    final descMatches = _findSensitiveWords(_descriptionController.text);
    final bool flaggedSensitive = descMatches.isNotEmpty;
    if (flaggedSensitive) {
      final String joined = descMatches.join(', ');
      // Inform the user that the report will be submitted but marked unsuccessful
      _showSnackBar(
        'Description contains sensitive words ($joined). Report will be submitted but marked unsuccessful.',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
    }

    // --- Check image content using ML predictions for sensitive words ---
    final imageMatches = await _checkImageSensitiveWords();
    if (imageMatches.isNotEmpty) {
      final String joined = imageMatches.join(', ');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Image Content Flagged'),
          content: Text(
            'The attached image appears to contain content flagged by the model: $joined. Please choose a different image or edit the report.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final Map<String, dynamic> submitResult = await _reportService
          .submitReport(
            category: _selectedCategory!,
            description: _descriptionController.text.trim(),
            exactLocation: _locationController.text.trim(),
            latitude: _latitude!,
            longitude: _longitude!,
            imageFile: _selectedImage,
            flaggedSensitive: flaggedSensitive,
          );

      final String reportId = submitResult['reportId'] as String;
      final Map<String, dynamic>? verification =
          submitResult['verification'] as Map<String, dynamic>?;

      // ==================== ML VALIDATION AFTER SUBMISSION ====================
      // Validate based on: image confidence > 0.6 and description match
      final validationResult = await _mlValidator.validateImage(
        _selectedImage!.path,
        category: _selectedCategory ?? 'unknown',
        description: _descriptionController.text,
      );

      // Show immediate verification feedback if available
      if (mounted && verification != null) {
        final String vStatus = verification['status'] ?? 'pending verification';
        final String vReason = verification['reason'] ?? '';

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              vStatus == 'Submitted'
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
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error submitting report: $e';

        if (e.toString().contains('PERMISSION DENIED') ||
            e.toString().contains('permission-denied')) {
          errorMessage =
              'Permission denied. Please check Firebase security rules.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('UNAVAILABLE')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        }

        _showSnackBar(errorMessage, Colors.red, Icons.error_outline);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Submit Report',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color.fromARGB(255, 96, 156, 101),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // onPressed: () => Navigator.of(context).maybePop(),
          onPressed: _isSubmitting ? null : _pickImageWithValidation,
          tooltip: 'Back',
        ),
      ),
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Submitting your report...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // Category Dropdown
                    _buildSectionLabel('Issue Category', required: true),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          hintText: 'Select issue category',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.category,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.green.shade400,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: const TextStyle(fontSize: 15),
                            ),
                          );
                        }).toList(),
                        onChanged: _onCategoryChanged,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Department
                    _buildSectionLabel('Department'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _department.isEmpty
                              ? Colors.grey.shade200
                              : Colors.green.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _department.isEmpty
                                  ? Colors.grey.shade100
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.business,
                              color: _department.isEmpty
                                  ? Colors.grey.shade400
                                  : Colors.green.shade700,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _department.isEmpty
                                  ? 'Select a category first'
                                  : _department,
                              style: TextStyle(
                                fontSize: 15,
                                color: _department.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                                fontWeight: _department.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    _buildSectionLabel('Description', required: true),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Describe the issue in detail...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Container(
                            margin: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              top: 12,
                            ),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.description,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.green.shade400,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          if (value.trim().length < 10) {
                            return 'Description must be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Location
                    _buildSectionLabel('Location', required: true),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              hintText: 'Tap button below to auto-fill',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.green.shade400,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter or auto-fill location';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // GPS Button
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade400,
                                      Colors.green.shade600,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isLoadingLocation
                                        ? null
                                        : _getCurrentLocationAndAddress,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _isLoadingLocation
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.my_location,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Use GPS',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Map Search Button
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const MapSearchScreen(),
                                        ),
                                      );
                                      if (result != null && result is Map) {
                                        final address =
                                            result['address'] as String?;
                                        final lat =
                                            result['latitude'] as double?;
                                        final lng =
                                            result['longitude'] as double?;
                                        setState(() {
                                          if (address != null &&
                                              address.isNotEmpty) {
                                            _locationController.text = address;
                                          }
                                          _latitude = lat;
                                          _longitude = lng;
                                        });
                                        if (mounted) {
                                          _showSnackBar(
                                            'Location selected from map',
                                            Colors.green,
                                            Icons.check_circle,
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Search Map',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_latitude != null && _longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade50,
                                Colors.green.shade100,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'GPS: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Image Upload
                    _buildSectionLabel('Upload Image', required: true),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_selectedImage != null)
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    children: [
                                      Image.file(
                                        _selectedImage!,
                                        height: 220,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Image added',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showImageSourceDialog,
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 20,
                                        ),
                                        label: const Text('Change'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.blue.shade700,
                                          side: BorderSide(
                                            color: Colors.blue.shade300,
                                            width: 1.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedImage = null;
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                        ),
                                        label: const Text('Remove'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          side: BorderSide(
                                            color: Colors.red.shade300,
                                            width: 1.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: _showImageSourceDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 2,
                                    strokeAlign: BorderSide.strokeAlignInside,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.grey.shade50,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate,
                                        color: Colors.blue.shade700,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Add Image',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap to choose from gallery or camera',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Info Text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade50, Colors.amber.shade100],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.hourglass_empty,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your report will be verified before appearing on the map',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
      ],
    );
  }
}
