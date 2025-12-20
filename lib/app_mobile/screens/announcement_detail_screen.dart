import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/announcement_model.dart'; // make sure path is correct

class AnnouncementDetailScreen extends StatelessWidget {
  final Announcement data;

  const AnnouncementDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final createdAt = data.createdAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement'),
        backgroundColor: const Color.fromARGB(255, 96, 156, 101),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (data.imageBase64 != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(data.imageBase64!),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),

            // Title
            Text(
              data.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Date
            if (createdAt != null)
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Description
            if (data.description != null)
              Text(
                data.description!,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            const SizedBox(height: 24),

            // Meta info
            if (data.category != null) _infoRow(Icons.label, data.category!),
            if (data.exactLocation != null)
              _infoRow(Icons.place, data.exactLocation!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}/${date.year}';
}
