import 'package:flutter/material.dart';

class CommunityPage extends StatelessWidget {
  final String department;

  const CommunityPage({required this.department, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
      ),
      body: Center(child: Text('Community Page for $department')),
    );
  }
}
