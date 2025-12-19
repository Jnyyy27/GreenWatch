import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/report_model.dart';

class AnalyticsPage extends StatelessWidget {
  final String department;

  const AnalyticsPage({required this.department, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 159, 232, 177),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
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

          /// ---------- DATA PROCESSING ----------
          final statusCounts = <String, int>{
            'Submitted': 0,
            'In Progress': 0,
            'Resolved': 0,
          };

          final categoryCounts = <String, int>{};
          final Map<String, int> dailyCounts = {};

          for (var r in reports) {
            // Status
            if (r.status.toLowerCase() == 'submitted') {
              statusCounts['Submitted'] = statusCounts['Submitted']! + 1;
            } else if (r.status.toLowerCase() == 'in progress') {
              statusCounts['In Progress'] = statusCounts['In Progress']! + 1;
            } else if (r.status.toLowerCase() == 'resolved') {
              statusCounts['Resolved'] = statusCounts['Resolved']! + 1;
            }

            // Category
            categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;

            // Daily trend (yyyy-mm-dd)
            final dateKey =
                '${r.createdAt.year}-${r.createdAt.month}-${r.createdAt.day}';
            dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
          }

          final barData = statusCounts.entries
              .map((e) => ChartData(e.key, e.value))
              .toList();

          final pieData = categoryCounts.entries
              .map((e) => ChartData(e.key, e.value))
              .toList();

          final lineData =
              dailyCounts.entries.map((e) => ChartData(e.key, e.value)).toList()
                ..sort((a, b) => a.label.compareTo(b.label));

          /// ---------- UI ----------
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _sectionTitle('Report Status Overview'),
                _barChart(barData),

                const SizedBox(height: 32),

                _sectionTitle('Reports Trend Over Time'),
                _lineChart(lineData),

                const SizedBox(height: 32),

                _sectionTitle('Category Distribution'),
                _pieChart(pieData),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ---------- UI HELPERS ----------

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// ---------- BAR CHART ----------
  Widget _barChart(List<ChartData> data) {
    return _chartCard(
      SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        series: <CartesianSeries<ChartData, String>>[
          ColumnSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (d, _) => d.label,
            yValueMapper: (d, _) => d.value,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  /// ---------- LINE CHART ----------
  Widget _lineChart(List<ChartData> data) {
    return _chartCard(
      SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        series: <CartesianSeries<ChartData, String>>[
          LineSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (d, _) => d.label,
            yValueMapper: (d, _) => d.value,
            markerSettings: const MarkerSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  /// ---------- PIE CHART ----------
  Widget _pieChart(List<ChartData> data) {
    return _chartCard(
      SfCircularChart(
        legend: Legend(isVisible: true, position: LegendPosition.bottom),
        series: <CircularSeries>[
          PieSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (d, _) => d.label,
            yValueMapper: (d, _) => d.value,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  /// ---------- CARD WRAPPER ----------
  Widget _chartCard(Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: chart,
    );
  }
}

/// ---------- MODEL ----------
class ChartData {
  final String label;
  final int value;

  ChartData(this.label, this.value);
}
