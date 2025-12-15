import 'package:flutter/material.dart';

class CommunityPage extends StatelessWidget {
  final String department;

  const CommunityPage({required this.department, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Community',
          style: TextStyle(
            color: Color(0xFF1a1a1a),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 159, 232, 177),
        surfaceTintColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.grey.shade700),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Center(child: Text('Community Page for $department')),
    );
  }
}
