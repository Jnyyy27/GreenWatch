import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TimelineEntry(
      action: data['action'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      user: data['user'] ?? '',
      notes: data['notes'] ?? '',
      images: List<String>.from(data['images'] ?? []),
    );
  }
}

// -------------------- SCREEN 1: THE LIST --------------------
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: user == null
          ? const Center(child: Text("Please login first"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                // 1. HANDLE ERRORS EXPLICITLY
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Error loading reports:\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No reports submitted yet"));
                }

                final docs = [...snapshot.data!.docs];
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final tsA = dataA['createdAt'];
                  final tsB = dataB['createdAt'];
                  DateTime? dtA;
                  DateTime? dtB;
                  if (tsA is Timestamp) dtA = tsA.toDate();
                  if (tsB is Timestamp) dtB = tsB.toDate();
                  if (dtA != null && dtB != null) return dtB.compareTo(dtA);
                  return 0;
                });

                return ListView.builder(
                  // ... (rest of your ListView code remains the same)
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildReportCard(context, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: data['imageBase64Thumbnail'] != null && data['imageBase64Thumbnail'].isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(data['imageBase64Thumbnail']), fit: BoxFit.cover))
              : const Icon(Icons.image, color: Colors.grey),
        ),
        title: Text(data['category'] ?? 'Issue', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['exactLocation'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailScreen(data: data))),
      ),
    );
  }
}

// -------------------- SCREEN 2: THE DETAILS --------------------
class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const ReportDetailScreen({super.key, required this.data});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'viewed':
        return Colors.orange;
      case 'in progress':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.send;
      case 'viewed':
        return Icons.visibility;
      case 'in progress':
        return Icons.build;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final reportId = data['reportId'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Area
            Container(
              height: 250, width: double.infinity, color: Colors.grey[200],
              child: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                  ? Image.network(data['imageUrl'], fit: BoxFit.cover)
                  : (data['imageBase64Thumbnail'] != null && data['imageBase64Thumbnail'].isNotEmpty
                      ? Image.memory(base64Decode(data['imageBase64Thumbnail']), fit: BoxFit.cover)
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_not_supported, size: 50, color: Colors.grey), Text("No Image")])),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Category', data['category']),
                  _detailRow('Department', data['department']),
                  const Divider(height: 30),
                  _detailRow('Location', data['exactLocation']),
                  _detailRow('Coordinates', '${data['latitude']}, ${data['longitude']}'),
                  const Divider(height: 30),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(data['description'] ?? 'No description', style: const TextStyle(fontSize: 16)),
                  const Divider(height: 30),
                  TimelineSection(
                    reportId: reportId,
                    formatDateTime: _formatDateTime,
                    getStatusColor: _getStatusColor,
                    getStatusIcon: _getStatusIcon,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value ?? 'N/A', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class TimelineSection extends StatelessWidget {
  final String? reportId;
  final String Function(DateTime) formatDateTime;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;

  const TimelineSection({
    super.key,
    required this.reportId,
    required this.formatDateTime,
    required this.getStatusColor,
    required this.getStatusIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (reportId == null || reportId!.isEmpty) {
      return const Text(
        'Timeline unavailable for this report.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timeline',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .doc(reportId)
                .collection('timeline')
                .orderBy('timestamp')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Error loading timeline',
                  style: TextStyle(color: Colors.red.shade400),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final entries = snapshot.data?.docs
                      .map((doc) => TimelineEntry.fromFirestore(doc))
                      .toList() ??
                  [];

              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Pending verification',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: entries.asMap().entries.map((entry) {
                  final isLast = entry.key == entries.length - 1;
                  return _TimelineItem(
                    item: entry.value,
                    isLast: isLast,
                    formatDateTime: formatDateTime,
                    getStatusColor: getStatusColor,
                    getStatusIcon: getStatusIcon,
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TimelineEntry item;
  final bool isLast;
  final String Function(DateTime) formatDateTime;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;

  const _TimelineItem({
    required this.item,
    required this.isLast,
    required this.formatDateTime,
    required this.getStatusColor,
    required this.getStatusIcon,
  });

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(item.action);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(getStatusIcon(item.action), size: 16, color: color),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withOpacity(0.3),
                        Colors.grey.shade300,
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.action,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateTime(item.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'By: ${item.user}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (item.images.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.images.map((img) {
                        try {
                          final bytes = base64Decode(img);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              bytes,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          );
                        } catch (_) {
                          return Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
