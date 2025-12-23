import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'my_reports_screen.dart';
import 'announcement_detail_screen.dart';
import '../../services/announcement_model.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("Please log in to see notifications"))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildAnnouncementsSection(),
                const SizedBox(height: 16),
                _buildReportUpdatesSection(user.uid),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 96, 156, 101).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color.fromARGB(255, 96, 156, 101)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Announcements', Icons.campaign),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('announcements')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text(
                'Error loading announcements',
                style: TextStyle(color: Colors.red.shade400),
              );
            }
            final announcements = snapshot.data?.docs
                    .map((doc) => Announcement.fromFirestore(doc))
                    .toList() ??
                [];
            if (announcements.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No announcements yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }
            return Column(
              children: announcements.map((a) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 96, 156, 101),
                      child: Icon(Icons.campaign, color: Colors.white),
                    ),
                    title: Text(
                      a.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          a.description ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (a.createdAt != null)
                          Text(
                            _relativeTime(a.createdAt!),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AnnouncementDetailScreen(data: a),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReportUpdatesSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Report updates', Icons.update),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Error loading report updates',
                style: TextStyle(color: Colors.red.shade400),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No report updates yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            final docs = [...snapshot.data!.docs];
            docs.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              final tsA = dataA['updatedAt'] ?? dataA['createdAt'];
              final tsB = dataB['updatedAt'] ?? dataB['createdAt'];
              DateTime? dtA;
              DateTime? dtB;
              if (tsA is Timestamp) dtA = tsA.toDate();
              if (tsB is Timestamp) dtB = tsB.toDate();
              if (dtA != null && dtB != null) return dtB.compareTo(dtA);
              return 0;
            });

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final String status = data['status'] ?? 'Unknown';
                final String category = data['category'] ?? 'Report';
                final String reportId = data['reportId'] ?? 'ID: ????';

                Color statusColor = Colors.grey;
                IconData statusIcon = Icons.info_outline;

                if (status.toLowerCase() == 'resolved') {
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle_outline;
                } else if (status.toLowerCase().contains('pending')) {
                  statusColor = Colors.orange;
                  statusIcon = Icons.access_time;
                } else if (status.toLowerCase().contains('progress')) {
                  statusColor = Colors.blue;
                  statusIcon = Icons.build;
                } else if (status.toLowerCase().contains('viewed')) {
                  statusColor = Colors.purple;
                  statusIcon = Icons.visibility;
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.1),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    title: Text(
                      "Update on $category",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "Status changed to: ${status.toUpperCase()}",
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Report ID: $reportId",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(data: data),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
