import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img_pkg;
import 'ml_validator_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Test Firebase connectivity
  Future<bool> testFirebaseConnection() async {
    try {
      print('🔍 Testing Firebase connection...');
      print('📦 Firebase app name: ${Firebase.app().name}');
      print('📦 Firebase app options: ${Firebase.app().options.projectId}');

      // Try to read from Firestore (this will test connectivity and rules)
      await _firestore.collection('test').limit(1).get();
      print('✅ Firebase connection test successful');
      return true;
    } catch (e) {
      print('❌ Firebase connection test failed: $e');
      return false;
    }
  }

  // Test Firestore write permissions
  Future<String> testFirestoreWrite() async {
    try {
      print('🧪 Testing Firestore write permissions...');
      final testRef = _firestore.collection('test').doc('connection_test');
      await testRef.set({
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Firestore write test successful');

      // Clean up test document
      await testRef.delete();
      return 'Write test successful';
    } catch (e) {
      print('❌ Firestore write test failed: $e');
      String errorMsg = e.toString();
      if (errorMsg.contains('permission-denied')) {
        return 'PERMISSION DENIED: Check Firestore security rules!';
      } else if (errorMsg.contains('unavailable')) {
        return 'SERVICE UNAVAILABLE: Check internet connection';
      } else {
        return 'Error: $errorMsg';
      }
    }
  }

  // Map categories to departments
  static String getDepartmentForCategory(String category) {
    switch (category) {
      case 'Public equipment problem':
      case 'Damage/missing road signs':
      case 'Faded road markings':
      case 'Traffic light problem':
        return 'MBPP';
      case 'Streetlights problem':
        return 'TNB';
      case 'Damage roads':
      case 'Road potholes':
        return 'JKR';
      default:
        return 'Unknown';
    }
  }

  // Upload image to Firebase Storage
  Future<String> uploadImage(File imageFile, String reportId) async {
    try {
      print('📤 Starting image upload...');
      final String fileName =
          '${reportId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('📁 File name: $fileName');

      final Reference ref = _storage.ref().child('report_images/$fileName');
      print('📂 Storage reference created');

      final UploadTask uploadTask = ref.putFile(imageFile);
      print('⏳ Uploading file...');

      final TaskSnapshot snapshot = await uploadTask;
      print('✅ Upload complete');

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 Download URL obtained: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      print('❌ Error uploading image: $e');
      print('📚 Stack trace: $stackTrace');
      throw Exception('Error uploading image: $e');
    }
  }

  // Compress image and return Base64 string (thumbnail). Throws if too large.
  Future<String> _encodeFileToBase64(
    File file, {
    int quality = 75,
    int minWidth = 800,
    int maxBase64Bytes = 900000,
  }) async {
    try {
      final Uint8List bytes = await file.readAsBytes();

      final img_pkg.Image? decoded = img_pkg.decodeImage(bytes);
      if (decoded == null) throw Exception('Unable to decode image');

      // Resize keeping aspect ratio; only shrink if larger than target width
      final img_pkg.Image resized = decoded.width > minWidth
          ? img_pkg.copyResize(decoded, width: minWidth)
          : decoded;

      final List<int> jpg = img_pkg.encodeJpg(resized, quality: quality);

      final int base64Size = ((jpg.length + 2) ~/ 3) * 4;
      if (base64Size > maxBase64Bytes) {
        throw Exception(
          'Compressed image too large for Firestore (base64 ${base64Size} bytes)',
        );
      }

      return base64Encode(jpg);
    } catch (e) {
      rethrow;
    }
  }

  // Submit report to Firestore
  // Returns a map containing `reportId` and `verification` result
  Future<Map<String, dynamic>> submitReport({
    required String category,
    required String description,
    required String exactLocation,
    required double latitude,
    required double longitude,
    File? imageFile,
    bool flaggedSensitive = false,
  }) async {
    try {
      print('📝 Starting report submission...');

      // Get department based on category
      final String department = getDepartmentForCategory(category);
      print('🏢 Department determined: $department');

      // Create report document
      final DocumentReference reportRef = _firestore
          .collection('reports')
          .doc();
      final String reportId = reportRef.id;
      print('🆔 Report ID generated: $reportId');

      String? imageUrl;
      String? imageBase64Thumbnail;
      List<double>? imageEmbedding;

      if (imageFile != null) {
        print('📸 Uploading image...');
        try {
          imageUrl = await uploadImage(imageFile, reportId);
          print('✅ Image uploaded successfully: $imageUrl');
        } catch (e) {
          print('❌ Image upload failed: $e');
          // Continue without image if upload fails
        }
        // Try to also create a small compressed Base64 thumbnail and store in Firestore
        try {
          imageBase64Thumbnail = await _encodeFileToBase64(
            imageFile,
            quality: 70,
            minWidth: 600,
            maxBase64Bytes: 900000,
          );
          print(
            '✅ Created Base64 thumbnail (length=${imageBase64Thumbnail.length})',
          );
        } catch (e) {
          print('⚠️ Could not create Base64 thumbnail: $e');
          imageBase64Thumbnail = null;
        }

        // Extract image embedding for duplicate detection
        try {
          print('🧠 Extracting image embedding for duplicate detection...');
          // Create a temporary instance to extract embeddings
          // This allows duplicate checking even if the ML validator hasn't been initialized elsewhere
          final mlValidator = MLValidatorService();
          await mlValidator.initialize();

          imageEmbedding = await mlValidator.getImageEmbedding(imageFile.path);

          if (imageEmbedding != null && imageEmbedding.isNotEmpty) {
            print(
              '✅ Image embedding extracted (length=${imageEmbedding.length})',
            );
          } else {
            print('⚠️ Could not extract image embedding');
          }

          mlValidator.dispose();
        } catch (e) {
          print('⚠️ Error extracting embedding: $e');
          imageEmbedding = null;
        }
      } else {
        print('ℹ️ No image provided');
      }

      // Create report data
      final Map<String, dynamic> reportData = {
        'reportId': reportId,
        'category': category,
        'department': department,
        'description': description,
        'exactLocation': exactLocation,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'pending verification',
        //'imageUrl': imageUrl ?? '',
        'imageBase64Thumbnail': imageBase64Thumbnail ?? '',
        if (imageEmbedding != null && imageEmbedding.isNotEmpty)
          'embedding': imageEmbedding,
        if (flaggedSensitive) 'flaggedSensitive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('💾 Saving to Firestore...');
      print('📋 Report data: $reportData');

      // Save to Firestore
      print('⏳ Attempting to write to Firestore...');
      await reportRef
          .set(reportData)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Firestore write timeout - check internet connection',
              );
            },
          );

      // Verify the document was saved by reading it back
      print('🔍 Verifying document was saved...');
      final docSnapshot = await reportRef.get();
      if (docSnapshot.exists) {
        print('✅ Report saved and verified with ID: $reportId');
        print('📄 Document data: ${docSnapshot.data()}');
      } else {
        throw Exception('Document was not saved - verification failed');
      }

      // Trigger AI verification (category match + duplicate check + description verification)
      final verification = await verifyReport(
        reportId: reportId,
        imagePath: imageFile?.path,
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        flaggedSensitive: flaggedSensitive,
      );

      return {'reportId': reportId, 'verification': verification};
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      print('📚 Error details: ${e.toString()}');

      String errorMessage = 'Firebase error: ${e.code}';
      if (e.code == 'permission-denied') {
        errorMessage =
            'PERMISSION DENIED: Firestore security rules are blocking writes. Please update your Firestore rules to allow writes to the "reports" collection.';
      } else if (e.code == 'unavailable') {
        errorMessage =
            'SERVICE UNAVAILABLE: Check your internet connection and Firebase project status.';
      } else if (e.code == 'unauthenticated') {
        errorMessage = 'UNAUTHENTICATED: Authentication required.';
      }

      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      print('❌ Error submitting report: $e');
      print('📚 Stack trace: $stackTrace');
      throw Exception('Error submitting report: $e');
    }
  }

  // Update report status in Firestore
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    try {
      print('🔄 Updating report status to: $newStatus');

      await _firestore.collection('reports').doc(reportId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Report status updated successfully');
    } catch (e) {
      print('❌ Error updating report status: $e');
      throw Exception('Error updating report status: $e');
    }
  }

  // Run ML-based verification and duplicate detection for a saved report.
  // Uses hybrid strategy: confidence-based inference + semantic matching + user description verification
  // Duplicate scoring based on: category match, location, description similarity, image similarity, and timeline
  // Ethical considerations: if flagged sensitive, skip ML and mark unsuccessful
  // Returns a map with verification details and updates the report document with results.
  Future<Map<String, dynamic>> verifyReport({
    required String reportId,
    String? imagePath,
    required String category,
    String? description,
    required double latitude,
    required double longitude,
    double similarityThreshold = 0.85,
    bool flaggedSensitive = false,
  }) async {
    final Map<String, dynamic> verification = {
      'status': 'unsuccessful',
      'reason': 'Verification not run',
      'topPrediction': null,
      'duplicateScore': 0.0,
      'isDuplicate': false,
      'autoVerified': false,
      'checkedAt': FieldValue.serverTimestamp(),
    };

    try {
      final mlValidator = MLValidatorService();
      await mlValidator.initialize();

      // If flagged sensitive, mark unsuccessful immediately
      if (flaggedSensitive) {
        verification['reason'] = 'Flagged sensitive content in description';
        verification['status'] = 'Unsuccessful';
        await _firestore.collection('reports').doc(reportId).update({
          'verificationStatus': verification['status'],
          'verificationReason': verification['reason'],
          'autoVerified': false,
          'verificationCheckedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await updateReportStatus(reportId, verification['status']);
        mlValidator.dispose();
        return verification;
      }

      // If no image available, mark unsuccessful
      if (imagePath == null) {
        verification['reason'] = 'No image provided for verification';
        await _firestore.collection('reports').doc(reportId).update({
          'verificationStatus': verification['status'],
          'verificationReason': verification['reason'],
          'autoVerified': false,
          'verificationCheckedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return verification;
      }

      // Run content validation with hybrid strategy: confidence + semantics + description
      final validationResult = await mlValidator.validateImage(
        imagePath,
        category: category,
        description: description,
      );
      verification['topPrediction'] = validationResult.topPrediction
          ?.toString();

      // If ML explicitly flagged as invalid, return unsuccessful with reason
      if (!validationResult.isValid) {
        verification['reason'] =
            'Image does not match selected category. ${validationResult.topPrediction?.label ?? 'unknown'}';
        verification['status'] = 'Unsuccessful';
      }

      // Run enhanced duplicate check with scoring system
      final dupResult = await _checkDuplicatesWithScoring(
        imagePath: imagePath,
        category: category,
        description: description ?? '',
        latitude: latitude,
        longitude: longitude,
        mlValidator: mlValidator,
        similarityThreshold: similarityThreshold,
      );

      verification['duplicateScore'] = dupResult['score'];
      verification['isDuplicate'] = dupResult['isDuplicate'];

      // Persist near-miss comparison debug info to Firestore for troubleshooting
      try {
        final List<dynamic>? comps =
            (dupResult['comparisons'] as List<dynamic>?);
        if (comps != null && comps.isNotEmpty) {
          // Filter near-miss comparisons (just below threshold) and also keep the top matches
          final double nearMissFloor = (similarityThreshold - 0.15).clamp(
            0.0,
            1.0,
          );
          final nearMisses = comps
              .where((c) => (c['compositeScore'] as double) >= nearMissFloor)
              .toList();

          if (nearMisses.isNotEmpty) {
            await _firestore.collection('reports').doc(reportId).update({
              'duplicateDebug': {
                'nearMisses': nearMisses,
                'checkedAt': FieldValue.serverTimestamp(),
              },
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        print('⚠️ Error saving duplicate debug info: $e');
      }

      if (dupResult['isDuplicate']) {
        verification['reason'] =
            'Duplicate report found (Thank you for helping to keep reports unique)';
        verification['status'] = 'Unsuccessful';
      }

      // If ML validation passed and not duplicate -> submitted
      if (validationResult.isValid && !dupResult['isDuplicate']) {
        verification['status'] = 'Submitted';
        verification['reason'] =
            'Auto-verified: image matches category and not duplicated';
        verification['autoVerified'] = true;
      }

      // Persist verification metadata in the report document
      await _firestore.collection('reports').doc(reportId).update({
        'verificationStatus': verification['status'],
        'verificationReason': verification['reason'],
        'verificationTopPrediction': verification['topPrediction'] ?? '',
        'duplicateScore': verification['duplicateScore'],
        'isDuplicate': verification['isDuplicate'],
        'autoVerified': verification['autoVerified'],
        'verificationCheckedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update main status field for routing
      await updateReportStatus(reportId, verification['status']);

      mlValidator.dispose();
      return verification;
    } catch (e, st) {
      print('❌ Error during verifyReport: $e');
      print(st);
      // Store that verification failed but keep report in pending for manual review
      verification['status'] = 'pending verification';
      verification['reason'] = 'Verification error: $e';
      await _firestore.collection('reports').doc(reportId).update({
        'verificationStatus': verification['status'],
        'verificationReason': verification['reason'],
        'autoVerified': false,
        'verificationCheckedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return verification;
    }
  }

  // Duplication Scores based on: category match, location proximity, description similarity, image similarity, timeline
  // Returns: {score: 0.0-1.0, isDuplicate: bool}
  Future<Map<String, dynamic>> _checkDuplicatesWithScoring({
    required String imagePath,
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required MLValidatorService mlValidator,
    double similarityThreshold = 0.75,
  }) async {
    try {
      print('🔍 Starting enhanced duplicate detection with scoring...');

      // Get nearby reports (wider radius for scoring consideration)
      final nearbyReportsRaw = await _findNearbyReportsExtended(
        category,
        latitude,
        longitude,
        radiusMultiplier: 2.0, // Larger search radius
      );

      // Only compare against reports that were successfully verified
      final nearbyReports = nearbyReportsRaw.where((doc) {
        try {
          final d = doc.data() as Map<String, dynamic>;
          final verificationStatus = (d['verificationStatus'] as String?) ?? '';
          final status = (d['status'] as String?) ?? '';
          final autoVerified = (d['autoVerified'] as bool?) ?? false;

          return verificationStatus.toLowerCase() == 'Submitted' ||
              status.toLowerCase() == 'successfully verified' ||
              autoVerified == true;
        } catch (e) {
          return false;
        }
      }).toList();

      if (nearbyReports.isEmpty) {
        print('ℹ️  No nearby reports found');
        return {'score': 0.0, 'isDuplicate': false};
      }

      print('🔍 Found ${nearbyReports.length} nearby reports in same category');

      // Get embedding for the new image
      final newEmbedding = await mlValidator.getImageEmbedding(imagePath);
      if (newEmbedding.isEmpty) {
        print('⚠️  Could not extract image embedding');
        return {'score': 0.0, 'isDuplicate': false};
      }

      double maxScore = 0.0;
      String? mostSimilarReportId;
      final List<Map<String, dynamic>> comparisons = [];

      // Compare with each nearby report and calculate composite score
      for (var doc in nearbyReports) {
        try {
          final docData = doc.data() as Map<String, dynamic>;
          final reportId = doc.id;

          // Calculate individual scores for each factor
          double categoryScore = 1.0; // Already matched (same collection query)

          // Location score: based on distance (0-1, closer = higher)
          final double reportLat =
              (docData['latitude'] as num?)?.toDouble() ?? 0;
          final double reportLng =
              (docData['longitude'] as num?)?.toDouble() ?? 0;
          final double locationScore = _calculateLocationScore(
            latitude,
            longitude,
            reportLat,
            reportLng,
          );

          // Description score: text similarity (0-1)
          final String reportDescription =
              (docData['description'] as String?) ?? '';
          final double descriptionScore = _calculateDescriptionSimilarity(
            description,
            reportDescription,
          );

          // --- HARD DUPLICATE RULE ---
          // If same day + within 100m + high description similarity > 0.7, mark as duplicate immediately
          final double distanceKm = _calculateDistance(
            latitude,
            longitude,
            reportLat,
            reportLng,
          );
          final double distanceMeters = distanceKm * 1000;
          final timestamp = docData['createdAt'] as Timestamp?;
          final bool sameDay =
              timestamp != null && _isSameDayOrToday(timestamp.toDate());

          if (sameDay && distanceMeters <= 100.0 && descriptionScore > 0.7) {
            print(
              '🚨 HARD DUPLICATE RULE TRIGGERED: Report $reportId (same day, ${distanceMeters.toStringAsFixed(1)}m away, description similarity ${(descriptionScore * 100).toStringAsFixed(1)}%)',
            );
            return {
              'score': 1.0,
              'isDuplicate': true,
              'comparisons': [
                {
                  'comparedReportId': reportId,
                  'compositeScore': 1.0,
                  'hardDuplicateRule': true,
                  'reason':
                      'Same day + within 100m + high description similarity',
                },
              ],
            };
          }

          // Image similarity score: using embeddings (0-1)
          double imageSimilarity = 0.0;
          if (docData.containsKey('embedding')) {
            try {
              final oldEmbedding = (docData['embedding'] as List<dynamic>)
                  .map((e) => (e as num).toDouble())
                  .toList();
              imageSimilarity = _cosineSimilarity(
                newEmbedding,
                oldEmbedding,
              ).clamp(0.0, 1.0);
            } catch (e) {
              print('⚠️  Error comparing embeddings: $e');
            }
          }

          // Timeline score: based on age (within 2 weeks = higher score)
          final double timelineScore = _calculateTimelineScore(docData);

          // Composite score: weighted average
          // Weights updated to reduce location importance and increase description weight
          // Weights: category (15%), location (10%), description (35%), image (20%), timeline (20%)
          final double compositeScore =
              (categoryScore * 0.15) +
              (locationScore * 0.10) +
              (descriptionScore * 0.35) +
              (imageSimilarity * 0.20) +
              (timelineScore * 0.20);

          // Record comparison details for debugging / near-miss logging
          comparisons.add({
            'comparedReportId': reportId,
            'compositeScore': compositeScore,
            'categoryScore': categoryScore,
            'locationScore': locationScore,
            'descriptionScore': descriptionScore,
            'imageSimilarity': imageSimilarity,
            'timelineScore': timelineScore,
            'reportLatitude': reportLat,
            'reportLongitude': reportLng,
            'createdAt': docData['createdAt'],
          });

          print(
            '📊 Report $reportId - Category: ${(categoryScore * 100).toStringAsFixed(1)}%, '
            'Location: ${(locationScore * 100).toStringAsFixed(1)}%, '
            'Description: ${(descriptionScore * 100).toStringAsFixed(1)}%, '
            'Image: ${(imageSimilarity * 100).toStringAsFixed(1)}%, '
            'Timeline: ${(timelineScore * 100).toStringAsFixed(1)}% → '
            'Total: ${(compositeScore * 100).toStringAsFixed(1)}%',
          );

          if (compositeScore > maxScore) {
            maxScore = compositeScore;
            mostSimilarReportId = reportId;
          }
        } catch (e) {
          print('⚠️  Error processing report ${doc.id}: $e');
          continue;
        }
      }

      final bool isDuplicate = maxScore >= similarityThreshold;
      if (isDuplicate) {
        print(
          '⚠️  DUPLICATE DETECTED: ${(maxScore * 100).toStringAsFixed(1)}% similar to report $mostSimilarReportId',
        );
      } else {
        print(
          'ℹ️  Max similarity: ${(maxScore * 100).toStringAsFixed(1)}% (below threshold)',
        );
      }

      return {
        'score': maxScore,
        'isDuplicate': isDuplicate,
        'comparisons': comparisons,
      };
    } catch (e) {
      print('❌ Error in duplicate scoring: $e');
      return {'score': 0.0, 'isDuplicate': false, 'comparisons': []};
    }
  }

  // Check if a date is the same day as today (calendar day, not 24 hours)
  bool _isSameDayOrToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Calculate location proximity score (0-1, closer = higher)
  // 100m or less = 1.0, 30m = 1.0, 50m = 0.8, 100m = 0.5, beyond 100m = 0.0
  double _calculateLocationScore(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final double distanceKm = _calculateDistance(lat1, lng1, lat2, lng2);
    final double distanceMeters = distanceKm * 1000;

    if (distanceMeters <= 30) return 1.0;
    if (distanceMeters <= 50) return 0.8;
    if (distanceMeters <= 100) return 0.5;
    return 0.0;
  }

  // Calculate distance between two coordinates in kilometers (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusKm = 6371;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Calculate description text similarity (0-1)
  // Uses token overlap and keyword matching
  double _calculateDescriptionSimilarity(String desc1, String desc2) {
    if (desc1.isEmpty && desc2.isEmpty) return 1.0;
    if (desc1.isEmpty || desc2.isEmpty) return 0.0;

    final tokens1 = desc1.toLowerCase().split(RegExp(r'\W+'));
    final tokens2 = desc2.toLowerCase().split(RegExp(r'\W+'));

    final set1 = tokens1.toSet();
    final set2 = tokens2.toSet();

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    if (union == 0) return 0.0;
    return intersection / union; // Jaccard similarity
  }

  // Within 2 weeks = 1.0, decreases linearly beyond 2 weeks
  // Calculate timeline similarity score (0–1)
  double _calculateTimelineScore(Map<String, dynamic> docData) {
    try {
      final timestamp = docData['createdAt'] as Timestamp?;
      if (timestamp == null) return 0.0;

      final reportDate = timestamp.toDate();
      final now = DateTime.now();
      final daysDifference = now.difference(reportDate).inDays;

      if (daysDifference <= 0) return 1.0; // Same day
      if (daysDifference <= 3) return 0.8; // Within 3 days
      if (daysDifference <= 7) return 0.4; // Within a week
      return 0.0; // Older than 7 days
    } catch (e) {
      print('⚠️ Error calculating timeline score: $e');
      return 0.0;
    }
  }

  // Calculate cosine similarity between two vectors (0-1)
  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.isEmpty || vec2.isEmpty) return 0.0;
    if (vec1.length != vec2.length) return 0.0;

    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      magnitude1 += vec1[i] * vec1[i];
      magnitude2 += vec2[i] * vec2[i];
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    if (magnitude1 == 0.0 || magnitude2 == 0.0) return 0.0;

    return dotProduct / (magnitude1 * magnitude2);
  }

  // Find nearby reports with extended radius
  Future<List<QueryDocumentSnapshot>> _findNearbyReportsExtended(
    String category,
    double lat,
    double lng, {
    double radiusMultiplier = 2.0,
  }) async {
    const double baseRadius = 0.00045; // ~50 meters
    final double searchRadius = baseRadius * radiusMultiplier;

    final snap = await _firestore
        .collection("reports")
        .where("category", isEqualTo: category)
        .where("latitude", isGreaterThan: lat - searchRadius)
        .where("latitude", isLessThan: lat + searchRadius)
        .get();

    List<QueryDocumentSnapshot> nearby = [];

    for (var doc in snap.docs) {
      double existingLng = doc["longitude"];
      if ((existingLng - lng).abs() < searchRadius) {
        nearby.add(doc);
      }
    }
    return nearby;
  }
}
