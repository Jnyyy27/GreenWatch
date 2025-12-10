// // import 'package:flutter/material.dart';

// // class AdminDashboardPage extends StatelessWidget {
// //   const AdminDashboardPage({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Admin Dashboard')),
// //       body: const Center(child: Text('Admin dashboard coming soon')),
// //     );
// //   }
// // }
// import 'package:flutter/material.dart';

// class Report {
//   final String title;
//   final String department;

//   Report({required this.title, required this.department});
// }

// // Example data
// final List<Report> allReports = [
//   Report(title: 'Pothole on Jalan XYZ', department: 'MBPP'),
//   Report(title: 'Blocked drain near ABC', department: 'JKR'),
//   Report(title: 'Flooding at bridge', department: 'PBAPP'),
//   Report(title: 'Illegal dumping', department: 'JAS'),
// ];

// class AdminDashboardPage extends StatelessWidget {
//   final String department;

//   const AdminDashboardPage({required this.department, super.key});

//   @override
//   Widget build(BuildContext context) {
//     final reports = allReports
//         .where((r) => r.department == department)
//         .toList();

//     return Scaffold(
//       appBar: AppBar(title: Text('$department Dashboard')),
//       body: reports.isEmpty
//           ? const Center(child: Text('No reports yet'))
//           : ListView.builder(
//               itemCount: reports.length,
//               itemBuilder: (context, index) {
//                 return ListTile(title: Text(reports[index].title));
//               },
//             ),
//     );
//   }
// }
