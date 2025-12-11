import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

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
                  .collection('my_reports')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
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

                return ListView.builder(
                  // ... (rest of your ListView code remains the same)
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return _buildReportCard(context, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> data) {
    String status = data['status'] ?? 'Pending';
    Color color = status == 'resolved' ? Colors.green : Colors.orange;

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
            const SizedBox(height: 4),
            Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
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
                  _detailRow('Status', data['status']?.toUpperCase() ?? 'PENDING'),
                  const Divider(height: 30),
                  _detailRow('Location', data['exactLocation']),
                  _detailRow('Coordinates', '${data['latitude']}, ${data['longitude']}'),
                  const Divider(height: 30),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(data['description'] ?? 'No description', style: const TextStyle(fontSize: 16)),
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