import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/announcement_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final Announcement data;

  const AnnouncementDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final createdAt = data.createdAt;
    final hasImage = data.imageBase64 != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Announcement Details'),
        backgroundColor: const Color.fromARGB(255, 96, 156, 101),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Department Logo at the top
            _departmentLogoSection(data.department),

            // Content Card
            Transform.translate(
              offset: Offset(0, 0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: hasImage
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ]
                      : [],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge + Date Row
                    if (data.category != null || createdAt != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Category Badge
                          if (data.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(
                                  255,
                                  96,
                                  156,
                                  101,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.label,
                                    size: 14,
                                    color: const Color.fromARGB(
                                      255,
                                      96,
                                      156,
                                      101,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data.category!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color.fromARGB(255, 96, 156, 101),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Created Date
                          if (createdAt != null)
                            Row(
                              children: [
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(createdAt),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Title
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Divider
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 20),

                    // Announcement Photo
                    if (data.imageBase64 != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullImageViewer(
                                imageBase64: data.imageBase64!,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Hero(
                            tag: 'announcement-image',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(data.imageBase64!),
                                fit: BoxFit.contain, // <-- Show full image
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    if (data.description != null) ...[
                      // Description box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data.description!,
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.8,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Location Section
                    if (data.latitude != null && data.longitude != null)
                      _mapSection(context, data.latitude!, data.longitude!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _departmentLogoSection(String? department) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 96, 156, 101),
            const Color.fromARGB(255, 105, 239, 117),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: department != null && departmentLogoMap[department] != null
            ? Image.asset(departmentLogoMap[department]!, fit: BoxFit.contain)
            : Icon(
                Icons.campaign,
                size: 64,
                color: Colors.white.withOpacity(0.8),
              ),
      ),
    );
  }

  Widget _mapSection(BuildContext context, double lat, double lng) {
    final LatLng location = LatLng(lat, lng);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    96,
                    156,
                    101,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 20,
                  color: Color.fromARGB(255, 96, 156, 101),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: location,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('announcement_location'),
                    position: location,
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('Open in Google Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 96, 156, 101),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => _openInMaps(lat, lng),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
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

class FullImageViewer extends StatelessWidget {
  final String imageBase64;

  const FullImageViewer({super.key, required this.imageBase64});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: 'announcement-image',
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.memory(base64Decode(imageBase64), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

final Map<String, String> departmentLogoMap = {
  'MBPP': 'assets/images/mbpp.png',
  'JKR': 'assets/images/jkr.png',
  'TNB': 'assets/images/tnb.png',
};
