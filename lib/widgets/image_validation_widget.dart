import 'package:flutter/material.dart';
import 'dart:io';
import '../services/ml_validator_service.dart';

class ImageValidationWidget extends StatefulWidget {
  final String imagePath;
  final VoidCallback? onValidationSuccess;
  final Function(String)? onValidationError;

  const ImageValidationWidget({
    super.key,
    required this.imagePath,
    this.onValidationSuccess,
    this.onValidationError,
  });

  @override
  State<ImageValidationWidget> createState() => _ImageValidationWidgetState();
}

class _ImageValidationWidgetState extends State<ImageValidationWidget> {
  late MLValidatorService _mlValidator;
  ValidationResult? _validationResult;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _mlValidator = MLValidatorService();
    _validateImage();
  }

  Future<void> _validateImage() async {
    setState(() => _isValidating = true);

    try {
      // Initialize the ML validator if not already done
      await _mlValidator.initialize();

      // Validate the image with hybrid strategy (no description available in this widget)
      final validationResult = await _mlValidator.validateImage(
        widget.imagePath,
        category: 'unknown',
      );

      setState(() {
        _validationResult = validationResult;
        _isValidating = false;
      });

      if (validationResult.isValid) {
        widget.onValidationSuccess?.call();
      } else {
        widget.onValidationError?.call(validationResult.message);
      }
    } catch (e) {
      setState(() => _isValidating = false);
      widget.onValidationError?.call('Error validating image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.imagePath),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // Validation Status
            if (_isValidating)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text(
                    'Analyzing image...',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            else if (_validationResult != null) ...[
              _buildValidationStatus(),
              const SizedBox(height: 12),
              _buildPredictionsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationStatus() {
    final result = _validationResult!;
    final isValid = result.isValid;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? Colors.green : Colors.red,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsList() {
    final predictions = _validationResult?.allPredictions ?? [];

    if (predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Predictions:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...predictions.asMap().entries.map((entry) {
          final index = entry.key;
          final prediction = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    prediction.label,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(prediction.confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  void dispose() {
    _mlValidator.dispose();
    super.dispose();
  }
}

/// Widget for checking duplicate images
class DuplicateCheckWidget extends StatefulWidget {
  final String newImagePath;
  final List<String> previousImagePaths;
  final Function(bool isDuplicate, double similarity)? onDuplicateCheckComplete;

  const DuplicateCheckWidget({
    super.key,
    required this.newImagePath,
    required this.previousImagePaths,
    this.onDuplicateCheckComplete,
  });

  @override
  State<DuplicateCheckWidget> createState() => _DuplicateCheckWidgetState();
}

class _DuplicateCheckWidgetState extends State<DuplicateCheckWidget> {
  late MLValidatorService _mlValidator;
  bool _isChecking = false;
  double _maxSimilarity = 0.0;
  bool _isDuplicate = false;

  @override
  void initState() {
    super.initState();
    _mlValidator = MLValidatorService();
    _checkForDuplicates();
  }

  Future<void> _checkForDuplicates() async {
    setState(() => _isChecking = true);

    try {
      // This widget is using an outdated API
      // Duplicate checking is now handled in report_screen.dart during submission
      // For now, disable the old check
      setState(() {
        _isChecking = false;
        _maxSimilarity = 0.0;
        _isDuplicate = false;
      });

      widget.onDuplicateCheckComplete?.call(false, 0.0);
    } catch (e) {
      setState(() => _isChecking = false);
      print('❌ Error checking for duplicates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Duplicate Check',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_isChecking)
              Row(
                children: const [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Checking against ${3} previous reports...'),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDuplicate
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isDuplicate ? Colors.orange : Colors.green,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isDuplicate ? Icons.warning : Icons.done,
                      color: _isDuplicate ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDuplicate
                                ? 'Similar image found'
                                : 'No duplicates detected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isDuplicate
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                          Text(
                            'Similarity: ${(_maxSimilarity * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mlValidator.dispose();
    super.dispose();
  }
}
