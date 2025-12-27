import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String reportId;
  final String category;
  final DateTime createdAt;
  final String department;
  final String description;
  final String exactLocation;
  final String imageBase64Thumbnail;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime updatedAt;
  final int likesCount;

  Report({
    required this.reportId,
    required this.category,
    required this.createdAt,
    required this.department,
    required this.description,
    required this.exactLocation,
    required this.imageBase64Thumbnail,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.updatedAt,
    required this.likesCount,
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
      imageBase64Thumbnail: data['imageBase64Thumbnail'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
    );
  }
}

class TimelineEntry {
  final String action;
  final DateTime timestamp;
  final String user;
  final String notes;
  final List<String> images; // Base64 encoded images

  TimelineEntry({
    required this.action,
    required this.timestamp,
    required this.user,
    required this.notes,
    required this.images,
  });

  factory TimelineEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimelineEntry(
      action: data['action'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      user: data['user'] ?? '',
      notes: data['notes'] ?? '',
      images: List<String>.from(data['images'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'action': action,
      'timestamp': timestamp,
      'user': user,
      'notes': notes,
      'images': images,
    };
  }
}
