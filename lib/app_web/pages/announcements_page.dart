import 'package:flutter/material.dart';

class AnnouncementsPage extends StatelessWidget {
  final String department;

  const AnnouncementsPage({required this.department, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
      ),
      body: Center(child: Text('Announcements for $department')),
    );
  }
}
