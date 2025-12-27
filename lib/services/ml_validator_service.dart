import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';

class ImageClassification {
  final String label;
  final double confidence;

  ImageClassification({required this.label, required this.confidence});

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(2)}%)';
}

class DuplicateDetectionResult {
  final bool isDuplicate;
  final double similarity;

  DuplicateDetectionResult({
    required this.isDuplicate,
    required this.similarity,
  });
}

class DuplicateChecker {
  final MLValidatorService _mlValidator;
  DuplicateChecker() : _mlValidator = MLValidatorService();
}

class ValidationResult {
  final bool isValid;
  final String message;
  final ImageClassification? topPrediction;
  final List<ImageClassification>? allPredictions;
  final DuplicateDetectionResult? duplicateResult;

  ValidationResult({
    required this.isValid,
    required this.message,
    this.topPrediction,
    this.allPredictions,
    this.duplicateResult,
  });
}

class MLValidatorService {
  late Interpreter _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  static const double radius = 0.00045;

  /// True when model and labels were successfully loaded and interpreter is ready
  bool _modelsLoaded = false;

  // Environmental & infrastructure issue related ImageNet-style keywords
  static const Map<String, List<String>> ISSUE_KEYWORDS = {

    // 1. Damage roads (cracks, broken surface, uneven road)
    "Damage roads": [
      "road",
      "street",
      "asphalt",
      "pavement",
      "sidewalk",
      "curb",
      "lane",
      "crack",
      "broken road",
      "damaged road",
    ],

    // 2. Road potholes (specific road surface holes)
    "Road potholes": [
      "pothole",
      "hole",
      "asphalt",
      "road",
      "street",
      "pavement",
      "trench",
    ],

    // 3. Road signs (missing, damaged, unclear signs)
    "Road signs": [
      "road sign",
      "traffic sign",
      "street sign",
      "stop sign",
      "warning sign",
      "direction sign",
      "signboard",
      "sign",
      "metal pole",
    ],

    // 4. Faded road markings (lines, symbols on roads)
    "Faded road markings": [
      "road",
      "street",
      "lane",
      "crosswalk",
      "zebra crossing",
      "road marking",
      "line",
      "paint",
    ],

    // 5. Fallen trees (blocking roads, sidewalks, facilities)
    "Fallen trees": [
      "tree",
      "fallen tree",
      "branch",
      "log",
      "wood",
      "plant",
    ],

    // 6. Traffic lights (junction signal problems)
    "Traffic lights": [
      "traffic light",
      "traffic signal",
      "signal light",
      "intersection",
      "pole",
    ],

    // 7. Streetlights (lamp posts, lighting issues)
    "Streetlights": [
      "street light",
      "streetlight",
      "lamp post",
      "street lamp",
      "lamp",
      "lantern",
      "light pole",
    ],

    // 8. Public facilities (general public assets)
    "Public facilities": [
      "bench",
      "park bench",
      "bus stop",
      "bus shelter",
      "public toilet",
      "toilet",
      "playground",
      "slide",
      "swing",
      "seesaw",
      "barrier",
      "bollard",
      "fence",
      "vending machine",
      "mailbox",
      "parking meter",
    ],
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔧 Initializing ML Validator...');

      // Load the TensorFlow Lite model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilenet_v2_1.0_224.tflite',
      );

      // Load labels
      final labelsData = await rootBundle.loadString(
        'assets/models/imagenet_labels.txt',
      );
      _labels = labelsData
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList();

      _isInitialized = true;
      _modelsLoaded = true;
      print('✅ ML Validator initialized successfully (models loaded)');
    } catch (e) {
      print('⚠️  ML Validator initialization failed: $e');
      print(
        '📝 App will run without ML validation. Download models to enable validation.',
      );
      _isInitialized = true; // initialization attempted
      _modelsLoaded = false; // models not available
    }
  }

  // Validates an image for environmental issue relevance using hybrid strategy:
  // 1. Confidence-based inference (≥0.6) accepted
  // 2. Semantic keyword matching for infrastructure/damage patterns
  // 3. User description verification (keyword matching against damage descriptions)
  Future<ValidationResult> validateImage(
    String imagePath, {
    double confidenceThreshold = 0.3,
    required String category,
    String? description,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Check if ML model is available
      if (!_modelsLoaded || _labels.isEmpty) {
        return ValidationResult(
          isValid: true,
          message:
              '📝 ML validation unavailable (models not downloaded). Image accepted. Download models from TENSORFLOWLITE_SETUP.md to enable validation.',
        );
      }

      // Load and preprocess image
      final imageData = File(imagePath).readAsBytesSync();
      final decodedImage = img.decodeImage(imageData);

      if (decodedImage == null) {
        return ValidationResult(
          isValid: false,
          message: '❌ Failed to decode image. Please use a valid image file.',
        );
      }

      // Check image quality (minimum size)
      if (decodedImage.width < 100 || decodedImage.height < 100) {
        return ValidationResult(
          isValid: false,
          message:
              '❌ Image too small. Please use an image with at least 100x100 pixels.',
        );
      }

      // Resize to model input size (224x224 for MobileNetV2)
      final resizedImage = img.copyResize(
        decodedImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Convert to input tensor
      final input = _imageToByteListFloat32(resizedImage);

      // Run inference
      final output = List<double>.filled(1001, 0.0).reshape([1, 1001]);
      _interpreter.run(input, output);

      // Get predictions
      final predictions = output[0];

      // Find top-k predictions
      final topPredictions = _getTopPredictions(predictions, 10);

      if (topPredictions.isEmpty) {
        return ValidationResult(
          isValid: false,
          message: '❌ Failed to classify image. Please try another image.',
        );
      }

      // Check if user description contains environmental damage keywords (description verification)
      bool descriptionValidates = false;
      if (description != null && description.isNotEmpty) {
        descriptionValidates = _matchesDescriptionSemantics(description);
        if (descriptionValidates) {
          print(
            '✅ Description verification: User provided description confirms infrastructure issue',
          );
        }
      }

      // Check if ANY of the top predictions match environmental issues (not just the first)
      ImageClassification? bestEnvironmentalMatch;
      for (final prediction in topPredictions) {
        if (_isEnvironmentalIssue(
          prediction.label,
          prediction.confidence,
          category,
        )) {
          bestEnvironmentalMatch = prediction;
          break; // Found the best match
        }
      }

      // Hybrid decision: accept if image matches OR description confirms issue
      if (bestEnvironmentalMatch != null || descriptionValidates) {
        return ValidationResult(
          isValid: true,
          message: bestEnvironmentalMatch != null
              ? '✅ Image appears to be an environmental issue: ${bestEnvironmentalMatch.label}'
              : '✅ Description confirms environmental issue (confirmed by user)',
          topPrediction: bestEnvironmentalMatch,
          allPredictions: topPredictions,
        );
      } else {
        final topPrediction = topPredictions.first;
        return ValidationResult(
          isValid: false,
          message:
              '❌ Image does not appear to be related to environmental issues. Top detection: ${topPrediction.label}',
          topPrediction: topPrediction,
          allPredictions: topPredictions,
        );
      }
    } catch (e) {
      print('⚠️  Error during image validation: $e');
      return ValidationResult(
        isValid: true,
        message:
            '📝 Image accepted (validation unavailable). Click continue to proceed.',
      );
    }
  }

  // Check if the detected object/scene is valid based on hybrid strategy:
  // 1. High confidence (≥0.6) always accepted
  // 2. Semantic keyword matching for category-specific infrastructure
  // 3. Damage/deterioration patterns catch partially visible damaged objects
  bool _isEnvironmentalIssue(String label, double confidence, String category) {
    final lowerLabel = label.toLowerCase();

    // Rule 1: High confidence always accepted
    if (confidence >= 0.6) {
      print(
        '✅ High confidence accepted: $label (${(confidence * 100).toStringAsFixed(1)}%)',
      );
      return true;
    }

    // Rule 2: Category-specific keyword matching (reduces false negatives)
    final keywords = ISSUE_KEYWORDS[category];
    if (keywords != null) {
      for (final keyword in keywords) {
        if (lowerLabel.contains(keyword.toLowerCase())) {
          print(
            '✅ Category keyword match: "$keyword" in "$label" (${(confidence * 100).toStringAsFixed(1)}%)',
          );
          return true;
        }
      }
    }

    // Rule 3: Semantic patterns for infrastructure (catches missed predictions)
    if (_matchesInfrastructureSemantics(lowerLabel)) {
      print(
        '✅ Infrastructure semantic match: "$label" (${(confidence * 100).toStringAsFixed(1)}%)',
      );
      return true;
    }

    // Rule 4: Damage/deterioration patterns (catches partially visible damaged items)
    if (_matchesDamageSemantics(lowerLabel)) {
      print(
        '✅ Damage semantic match: "$label" (${(confidence * 100).toStringAsFixed(1)}%)',
      );
      return true;
    }

    print('❌ No match: "$label" (${(confidence * 100).toStringAsFixed(1)}%)');
    return false;
  }

  /// Check if label contains infrastructure-related semantics
  /// Catches: streets, roads, sidewalks, poles, signs, barriers, etc.
  bool _matchesInfrastructureSemantics(String label) {
    final infraPatterns = [
      'street',
      'road',
      'sidewalk',
      'pavement',
      'asphalt',
      'curb',
      'lane',
      'pole',
      'post',
      'sign',
      'light',
      'lamp',
      'bollard',
      'barrier',
      'fence',
      'guardrail',
      'railing',
      'wall',
      'concrete',
      'path',
      'walkway',
      'public',
      'outdoor',
      'infrastructure',
    ];
    return infraPatterns.any((pattern) => label.contains(pattern));
  }

  /// Check if label contains damage/deterioration semantics
  /// Catches: broken, damaged, cracked, worn, rusty, missing, etc.
  bool _matchesDamageSemantics(String label) {
    final damagePatterns = [
      'broken',
      'damaged',
      'crack',
      'hole',
      'pothole',
      'rubble',
      'torn',
      'dent',
      'worn',
      'deteriorat',
      'decay',
      'fallen',
      'rust',
      'corros',
      'chip',
      'scratch',
      'mark',
      'debris',
      'fragment',
      'rubble',
      'fractured',
      'split',
      'splintered',
      'missing',
      'absent',
      'vacant',
      'empty',
      'collapsed',
    ];
    return damagePatterns.any((pattern) => label.contains(pattern));
  }

  // Check if user's description contains keywords indicating environmental damage/issues
  // This provides a third validation pillar: user-provided description verification
  bool _matchesDescriptionSemantics(String description) {
    final lowerDescription = description.toLowerCase();

    // Damage-related keywords the user might use in their description
    final damageKeywords = [
      'pothole',
      'broken',
      'crack',
      'damage',
      'dent',
      'hole',
      'missing',
      'broken',
      'rusted',
      'rust',
      'graffiti',
      'litter',
      'trash',
      'debris',
      'rubble',
      'worn',
      'deteriorat',
      'loose',
      'fallen',
      'hazard',
      'unsafe',
      'problem',
      'issue',
      'damaged',
      'broken light',
      'street light',
      'lamp',
      'sign',
      'pavement',
      'road',
      'sidewalk',
      'curb',
      'bench',
      'barrier',
      'pole',
      'railing',
      'fence',
    ];

    final matchCount = damageKeywords
        .where((keyword) => lowerDescription.contains(keyword.toLowerCase()))
        .length;

    // Accept if description contains at least 1 relevant damage keyword
    if (matchCount > 0) {
      print(
        '\u2705 Description contains $matchCount damage/infrastructure keyword(s)',
      );
      return true;
    }

    print('\u274c Description does not contain relevant damage keywords');
    return false;
  }

  // Get confidence threshold for a specific category
  // Using unified 0.6 confidence threshold across all categories
  double _getConfidenceThresholdForCategory(String category) {
    return 0.6; // Unified threshold for all categories
  }

  // Get top-k predictions with labels (filtering out very low confidence predictions)
  List<ImageClassification> _getTopPredictions(
    List<double> predictions,
    int k,
  ) {
    final List<MapEntry<int, double>> indexedPredictions = [];
    for (int i = 0; i < predictions.length; i++) {
      indexedPredictions.add(MapEntry(i, predictions[i]));
    }

    // Sort by confidence descending
    indexedPredictions.sort((a, b) => b.value.compareTo(a.value));

    // Get top-k, filtering out predictions below a minimum threshold
    return indexedPredictions
        .take(k)
        .where(
          (entry) => entry.value > 0.005,
        ) // Lower threshold to capture more predictions
        .map((entry) {
          final labelIndex = entry.key;
          final confidence = entry.value;
          final label = labelIndex < _labels.length
              ? _labels[labelIndex].split(' ').skip(1).join(' ').trim()
              : 'Unknown';

          return ImageClassification(label: label, confidence: confidence);
        })
        .toList();
  }

  /// Convert image to input tensor format
  List<List<List<List<double>>>> _imageToByteListFloat32(img.Image image) {
    final List<List<List<List<double>>>> input = List.filled(
      1,
      List.filled(224, List.filled(224, List.filled(3, 0.0))),
    );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = image.getPixelSafe(x, y);
        // Normalize pixel values to [-1, 1] range (MobileNetV2 standard)
        input[0][y][x][0] = (pixel.rNormalized * 2) - 1;
        input[0][y][x][1] = (pixel.gNormalized * 2) - 1;
        input[0][y][x][2] = (pixel.bNormalized * 2) - 1;
      }
    }

    return input;
  }

  // Extract image embedding using the neural network
  // Returns a feature vector representation of the image
  Future<List<double>> getImageEmbedding(String imagePath) async {
    try {
      if (!_modelsLoaded) {
        print('⚠️  getImageEmbedding called but models are not loaded');
        return [];
      }
      final imageData = File(imagePath).readAsBytesSync();
      final decodedImage = img.decodeImage(imageData);

      if (decodedImage == null) {
        return [];
      }

      // Resize to model input size (224x224 for MobileNetV2)
      final resizedImage = img.copyResize(
        decodedImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Convert to input tensor
      final input = _imageToByteListFloat32(resizedImage);

      // Run inference to get feature embeddings
      final output = List<double>.filled(1001, 0.0).reshape([1, 1001]);
      _interpreter.run(input, output);

      // Use the output as embedding (neural network features)
      return output[0].toList();
    } catch (e) {
      print('❌ Error extracting image embedding: $e');
      return [];
    }
  }

  // Check for duplicate reports using image similarity and location proximity
  Future<DuplicateDetectionResult> checkForDuplicates({
    required String imagePath,
    required String category,
    required double latitude,
    required double longitude,
    double similarityThreshold = 0.85,
  }) async {
    try {
      if (!_modelsLoaded) {
        print('⚠️  ML models not loaded, skipping duplicate check');
        return DuplicateDetectionResult(isDuplicate: false, similarity: 0.0);
      }

      // 1. Find nearby reports in the same category
      final nearbyReports = await _findNearbyReports(
        category,
        latitude,
        longitude,
      );

      if (nearbyReports.isEmpty) {
        print('ℹ️  No nearby reports found');
        return DuplicateDetectionResult(isDuplicate: false, similarity: 0.0);
      }

      print('🔍 Found ${nearbyReports.length} nearby reports in same category');

      // 2. Get embedding for the new image
      final newEmbedding = await getImageEmbedding(imagePath);

      print('🔢 New embedding length: ${newEmbedding.length}');

      if (newEmbedding.isEmpty) {
        print('⚠️  Could not extract image embedding');
        return DuplicateDetectionResult(isDuplicate: false, similarity: 0.0);
      }

      // 3. Compare with each nearby report
      double maxSimilarity = 0.0;
      String? mostSimilarReportId;

      for (var doc in nearbyReports) {
        try {
          final docData = doc.data() as Map<String, dynamic>;

          // Check if embedding exists
          if (docData.containsKey('embedding')) {
            final oldEmbedding = (docData['embedding'] as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList();

            print(
              '🔎 Comparing with report ${doc.id}, embedding length: ${oldEmbedding.length}',
            );

            // Calculate geographic distance to be conservative (km)
            double docLat = (docData['latitude'] as num?)?.toDouble() ?? 0.0;
            double docLng = (docData['longitude'] as num?)?.toDouble() ?? 0.0;
            final double distKm = _distanceKm(
              latitude,
              longitude,
              docLat,
              docLng,
            );
            print(
              '📍 Distance to report ${doc.id}: ${(distKm * 1000).toStringAsFixed(1)} meters',
            );

            // Calculate cosine similarity
            final similarity = _cosineSimilarity(newEmbedding, oldEmbedding);
            print(
              '📊 Similarity with report ${doc.id}: ${(similarity * 100).toStringAsFixed(2)}%',
            );

            // Only consider as duplicate if both similarity and proximity checks pass
            if (distKm <= 0.05 && similarity >= similarityThreshold) {
              print(
                '⚠️  DUPLICATE DETECTED: ${(similarity * 100).toStringAsFixed(2)}% similar to report ${doc.id} at ${(distKm * 1000).toStringAsFixed(1)}m',
              );
              return DuplicateDetectionResult(
                isDuplicate: true,
                similarity: similarity,
              );
            }

            if (similarity > maxSimilarity) {
              maxSimilarity = similarity;
              mostSimilarReportId = doc.id;
            }
          }
        } catch (e) {
          print('⚠️  Error processing report ${doc.id}: $e');
          continue;
        }
      }

      print(
        'ℹ️  Max similarity: ${(maxSimilarity * 100).toStringAsFixed(2)}% (below threshold)',
      );
      return DuplicateDetectionResult(
        isDuplicate: false,
        similarity: maxSimilarity,
      );
    } catch (e) {
      print('❌ Error checking for duplicates: $e');
      return DuplicateDetectionResult(isDuplicate: false, similarity: 0.0);
    }
  }

  /// Calculate similarity between two images using color histogram
  double _calculateImageSimilarity(img.Image image1, img.Image image2) {
    final hist1 = _getColorHistogram(image1);
    final hist2 = _getColorHistogram(image2);

    // Calculate chi-square distance
    double distance = 0.0;
    for (int i = 0; i < hist1.length; i++) {
      if (hist1[i] + hist2[i] > 0) {
        final diff = hist1[i] - hist2[i];
        distance += (diff * diff) / (hist1[i] + hist2[i]);
      }
    }

    // Convert to similarity score (0-1, where 1 is identical)
    return 1.0 / (1.0 + distance / 1000.0);
  }

  /// Get normalized color histogram for an image
  List<double> _getColorHistogram(img.Image image) {
    const int bins = 256;
    final histogram = List<int>.filled(bins * 3, 0);

    for (final pixel in image) {
      final r = (pixel.rNormalized * (bins - 1)).toInt();
      final g = (pixel.gNormalized * (bins - 1)).toInt();
      final b = (pixel.bNormalized * (bins - 1)).toInt();

      histogram[r]++;
      histogram[bins + g]++;
      histogram[bins * 2 + b]++;
    }

    // Normalize
    final total = histogram.fold<int>(0, (a, b) => a + b);
    return histogram.map((count) => count / total).toList();
  }

  void dispose() {
    try {
      if (_modelsLoaded) {
        // Only close if interpreter was actually initialized
        _interpreter.close();
      }
    } catch (e) {
      // Ignore errors during disposal
    }
    _isInitialized = false;
  }

  Future<List<QueryDocumentSnapshot>> _findNearbyReports(
    String category,
    double lat,
    double lng,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection("reports")
        .where("category", isEqualTo: category)
        .where("latitude", isGreaterThan: lat - radius)
        .where("latitude", isLessThan: lat + radius)
        .get();

    List<QueryDocumentSnapshot> nearby = [];

    for (var doc in snap.docs) {
      double existingLng = doc["longitude"];
      if ((existingLng - lng).abs() < radius) {
        nearby.add(doc);
      }
    }
    return nearby;
  }
}

double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  if (a.length != b.length) return 0.0;

  double dot = 0.0;
  double normA = 0.0;
  double normB = 0.0;

  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  final double magA = sqrt(normA);
  final double magB = sqrt(normB);
  if (magA == 0.0 || magB == 0.0) return 0.0;

  return (dot / (magA * magB)).clamp(-1.0, 1.0);
}

double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadiusKm = 6371.0;
  final double dLat = (lat2 - lat1) * pi / 180.0;
  final double dLng = (lng2 - lng1) * pi / 180.0;
  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180.0) *
          cos(lat2 * pi / 180.0) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}
