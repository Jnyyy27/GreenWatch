import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String title;
  final String? description;
  final String? department;
  final String? category;
  final DateTime? createdAt;
  final String? imageBase64;
  final String? exactLocation;
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  Announcement({
    required this.title,
    this.description,
    this.department,
    this.category,
    this.createdAt,
    this.imageBase64,
    this.exactLocation,
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      title: data['title'] ?? '',
      description: data['description'],
      department: data['department'],
      category: data['category'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      imageBase64: data['imageBase64'],
      exactLocation: data['exactLocation'],
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
