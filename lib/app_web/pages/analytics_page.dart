import 'package:flutter/material.dart';

class AnalyticsPage extends StatelessWidget {
  final String department;

  const AnalyticsPage({required this.department, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
      ),
      body: Center(child: Text('Analytics Dashboard for $department')),
    );
  }
}
