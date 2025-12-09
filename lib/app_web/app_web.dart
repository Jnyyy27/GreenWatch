import 'package:flutter/material.dart';
import 'pages/admin_dashboard_page.dart';

class MyWebApp extends StatelessWidget {
  const MyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      home: const AdminDashboardPage(),
    );
  }
}
