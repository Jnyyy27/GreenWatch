import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class TimelineEntry {
  final String action;
  final DateTime timestamp;
  final String user;
  final String notes;
  final List<String> images;

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
}

class ResolvedIssueDetailScreen extends StatefulWidget {
  final Map<String, dynamic> issueData;
  final String docId;

  const ResolvedIssueDetailScreen({
    super.key,
    required this.issueData,
    required this.docId,
  });

  @override
  State<ResolvedIssueDetailScreen> createState() =>
      _ResolvedIssueDetailScreenState();
}

class _ResolvedIssueDetailScreenState extends State<ResolvedIssueDetailScreen> {
  TimelineEntry? _resolvedEntry;

  @override
  void initState() {
    super.initState();
    _fetchResolvedEntry();
  }

  Future<void> _fetchResolvedEntry() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.docId)
          .collection('timeline')
          .where('action', isEqualTo: 'Resolved')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _resolvedEntry = TimelineEntry.fromFirestore(snapshot.docs.first);
        });
      }
    } catch (e) {
      print('Error fetching resolved entry: $e');
    }
  }

  // Helper method to get status color and icon
  Map<String, dynamic> _getStatusStyle(String status) {
    switch (status) {
      case 'Submitted':
        return {
          'color': const Color(0xFF2196F3), // Blue
          'icon': Icons.upload_file,
          'label': 'Submitted',
        };
      case 'Viewed':
        return {
          'color': const Color(0xFFFFC107), // Yellow/Amber
          'icon': Icons.visibility,
          'label': 'Viewed',
        };
      case 'In Progress':
        return {
          'color': const Color(0xFFFF9800), // Orange
          'icon': Icons.hourglass_empty,
          'label': 'In Progress',
        };
      case 'Resolved':
        return {
          'color': const Color(0xFF4CAF50), // Green
          'icon': Icons.check_circle,
          'label': 'Resolved',
        };
      default:
        return {
          'color': Colors.grey,
          'icon': Icons.help_outline,
          'label': 'Unknown',
        };
    }
  }

  // Build status chip widget
  Widget _buildStatusChip(String status) {
    final style = _getStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (style['color'] as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style['color'] as Color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style['icon'] as IconData,
            size: 16,
            color: style['color'] as Color,
          ),
          const SizedBox(width: 6),
          Text(
            style['label'] as String,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: style['color'] as Color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins minute${mins > 1 ? 's' : ''} ago';
    } else if (diff.inHours < 24) {
      final hrs = diff.inHours;
      return '$hrs hour${hrs > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 30) {
      final days = diff.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }

  Future<void> _openGoogleMaps() async {
    final latitude = widget.issueData['latitude'] as double?;
    final longitude = widget.issueData['longitude'] as double?;

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(
        Uri.parse(googleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  Widget _buildResolvedSection() {
    if (_resolvedEntry == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Resolution Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromARGB(255, 96, 156, 101),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 96, 156, 101).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 96, 156, 101),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Issue Resolved',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resolution Notes
                    if (_resolvedEntry!.notes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 16,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Resolution Notes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _resolvedEntry!.notes,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Resolution Images
                    if (_resolvedEntry!.images.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Resolution Photos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _resolvedEntry!.images.length > 1
                              ? 2
                              : 1,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: _resolvedEntry!.images.length > 1
                              ? 1.2
                              : 1.2,
                        ),
                        itemCount: _resolvedEntry!.images.length,
                        itemBuilder: (context, index) {
                          try {
                            final bytes = base64Decode(
                              _resolvedEntry!.images[index],
                            );
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.memory(bytes, fit: BoxFit.cover),
                              ),
                            );
                          } catch (_) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey.shade400,
                                size: 36,
                              ),
                            );
                          }
                        },
                      ),
                    ],

                    // Timestamp
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(
                          255,
                          96,
                          156,
                          101,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: const Color.fromARGB(255, 96, 156, 101),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_resolvedEntry!.timestamp.toString().split('.')[0]}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 96, 156, 101),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            ' • ${_getRelativeTime(_resolvedEntry!.timestamp)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.issueData['category'] as String? ?? '';
    final description = widget.issueData['description'] as String? ?? '';
    final location = widget.issueData['exactLocation'] as String? ?? '';
    final department = widget.issueData['department'] as String? ?? '';
    final status = widget.issueData['status'] as String? ?? 'Unknown';
    final latitude = widget.issueData['latitude'] as double?;
    final longitude = widget.issueData['longitude'] as double?;
    final timestamp = widget.issueData['createdAt'];
    final imageBase64 =
        widget.issueData['imageBase64Thumbnail'] as String? ?? '';

    DateTime? dateTime;
    if (timestamp is Timestamp) dateTime = timestamp.toDate();

    Widget imageWidget;
    if (imageBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
        );
      } catch (_) {
        imageWidget = Container(
          width: double.infinity,
          height: 300,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.broken_image,
            size: 64,
            color: Colors.grey.shade500,
          ),
        );
      }
    } else {
      imageWidget = Container(
        width: double.infinity,
        height: 300,
        color: Colors.grey.shade200,
        child: Icon(Icons.image, size: 64, color: Colors.grey.shade500),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Resolved Issue Details'),
        backgroundColor: const Color.fromARGB(255, 96, 156, 101),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width image
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.grey.shade200,
              child: imageWidget,
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status chip at the top
                  Row(children: [_buildStatusChip(status)]),
                  const SizedBox(height: 16),
                  // Category and Department
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.business,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              department,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Description
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Location
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Latitude: $latitude, Longitude: $longitude',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Map Preview
                  if (latitude != null && longitude != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Map',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _openGoogleMaps,
                          child: Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(latitude, longitude),
                                    zoom: 15,
                                  ),
                                  onMapCreated: (controller) {
                                    // Map created
                                  },
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId(
                                        'issue_location',
                                      ),
                                      position: LatLng(latitude, longitude),
                                      infoWindow: InfoWindow(title: location),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.open_in_new,
                                          size: 16,
                                          color: Color.fromARGB(
                                            255,
                                            96,
                                            156,
                                            101,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Open in Maps',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color.fromARGB(
                                              255,
                                              96,
                                              156,
                                              101,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  // Timestamp
                  if (dateTime != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reported',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateTime.toString().split('.')[0]} (${_getRelativeTime(dateTime)})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  // Resolution Section (Only shows Resolved status)
                  _buildResolvedSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
