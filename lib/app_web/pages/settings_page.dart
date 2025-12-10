import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final String department;

  const SettingsPage({required this.department, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
      ),
      body: Center(child: Text('Settings for $department')),
    );
  }
}
