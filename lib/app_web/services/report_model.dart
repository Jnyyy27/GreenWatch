import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String reportId;
  final String category;
  final DateTime createdAt;
  final String department;
  final String description;
  final String exactLocation;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime updatedAt;

  Report({
    required this.reportId,
    required this.category,
    required this.createdAt,
    required this.department,
    required this.description,
    required this.exactLocation,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.updatedAt,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      reportId: data['reportId'] ?? '',
      category: data['category'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      department: data['department'] ?? '',
      description: data['description'] ?? '',
      exactLocation: data['exactLocation'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending verification',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
