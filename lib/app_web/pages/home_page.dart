import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'navigation_sidebar.dart';
import 'dashboard_page.dart';
import 'report_queue_page.dart';
import 'announcements_page.dart';
import 'history_page.dart';
import 'analytics_page.dart';

class HomePage extends StatefulWidget {
  final String department;

  const HomePage({required this.department, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late final String _departmentCode;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Convert full department name to code
    _departmentCode = AuthService.getDepartmentCode(widget.department);

    _pages = [
      DashboardPage(department: _departmentCode),
      ReportQueuePage(department: _departmentCode),
      AnnouncementsPage(department: _departmentCode),
      HistoryPage(department: _departmentCode),
      AnalyticsPage(department: _departmentCode),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationSidebar(
            department: widget.department,
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
