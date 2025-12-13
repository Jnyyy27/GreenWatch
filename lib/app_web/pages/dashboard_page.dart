import 'package:flutter/material.dart';
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

  bool get isVerified => status != 'pending verification';
}

class DashboardPage extends StatelessWidget {
  final String department;

  const DashboardPage({required this.department, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$department - Dashboard'),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to $department',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Overview of recent activities and key metrics',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('department', isEqualTo: department)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No reports available'));
                }

                final reports = snapshot.data!.docs
                    .map((doc) => Report.fromFirestore(doc))
                    .toList();

                final today = DateTime.now();
                final newReportsToday = reports
                    .where(
                      (r) =>
                          r.createdAt.year == today.year &&
                          r.createdAt.month == today.month &&
                          r.createdAt.day == today.day,
                    )
                    .length;

                final pendingVerification = reports
                    .where((r) => r.status == 'viewed')
                    .length;

                final inProgress = reports
                    .where(
                      (r) =>
                          r.status == 'in progress' ||
                          r.status == 'In Progress',
                    )
                    .length;

                final resolved = reports
                    .where((r) => r.status == 'resolved')
                    .length;

                final unverifiedReports =
                    reports
                        .where((r) => r.status == 'pending verification')
                        .toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Cards
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildKPICard(
                          'New Reports (24h)',
                          newReportsToday.toString(),
                          Colors.blue,
                          Icons.new_releases,
                        ),
                        _buildKPICard(
                          'Pending Verification',
                          pendingVerification.toString(),
                          Colors.orange,
                          Icons.pending_actions,
                        ),
                        _buildKPICard(
                          'In Progress',
                          inProgress.toString(),
                          Colors.amber,
                          Icons.hourglass_bottom,
                        ),
                        _buildKPICard(
                          'Resolved',
                          resolved.toString(),
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Quick Action Section
                    Text(
                      'Quick Actions - Pending Verification',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (unverifiedReports.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'All reports verified!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: unverifiedReports.length > 5
                            ? 5
                            : unverifiedReports.length,
                        itemBuilder: (context, index) {
                          final report = unverifiedReports[index];
                          return _buildQuickActionCard(report);
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(Report report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.expand_circle_down,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.exactLocation,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reported: ${_formatDate(report.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Review', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
