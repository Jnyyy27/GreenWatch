import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img_pkg;

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
      case 'Public equipment':
      case 'Road signs':
      case 'Faded road markings':
      case 'Traffic light':
        return 'MBPP';
      case 'Streetlights':
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
  Future<String> submitReport({
    required String category,
    required String description,
    required String exactLocation,
    required double latitude,
    required double longitude,
    File? imageFile,
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

      return reportId;
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
}
