import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../services/report_model.dart';

class AnalyticsPage extends StatefulWidget {
  final String department;

  const AnalyticsPage({required this.department, super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedRange = 'Last 30 Days';
  final dateFormat = DateFormat('dd/MM/yy');

  final List<String> _rangeOptions = [
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days',
    'This Year',
    'Custom Range',
  ];

  List<AreaReportData> _areaData = [];
  List<ChartData> _categoryData = [];
  List<TimeSeriesData> _dailyData = [];
  bool _isLoading = true;
  DateTimeRange? _customDateRange;

  int _totalReports = 0;
  int _successfulReports = 0;
  double _successRate = 0.0;
  String _topArea = '-';

  final List<String> knownPenangAreas = [
    'george town',
    'georgetown',
    'jelutong',
    'sungai pinang',
    'datuk keramat',
    'macallum',
    'kampung melayu',
    'kampung jawa',
    'kampung kolam',
    'kampung baru',
    'kampung siam',
    'pulau tikus',
    'tanjung tokong',
    'tanjung bungah',
    'batu ferringhi',
    'teluk bahang',
    'balik pulau',
    'teluk kumbar',
    'sungai ara',
    'bayan lepas',
    'bayan baru',
    'relau',
    'bukit jambul',
    'gelugor',
    'sungai dua',
    'universiti sains malaysia',
    'usm',
    'bukit gambier',
    'ayer itam',
    'air itam',
    'paya terubong',
    'farlim',
    'bandar baru air itam',
    'mount erskine',
    'greenlane',
    'jalan scotland',
    'jesselton',
    'pulau betong',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  DateTimeRange _getDateRangeForSelection() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'Last 7 Days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      case 'Last 30 Days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      case 'Last 90 Days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 90)),
          end: now,
        );
      case 'This Year':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case 'Custom Range':
        return _customDateRange ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            );
      default:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedRange = 'Custom Range';
      });
      _fetchData();
    }
  }

  String _extractArea(String location) {
    final lower = location.toLowerCase();
    for (final area in knownPenangAreas) {
      if (lower.contains(area)) return _capitalizeWords(area);
    }
    return 'Unknown';
  }

  String _capitalizeWords(String text) {
    return text
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final dateRange = _getDateRangeForSelection();

    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('department', isEqualTo: widget.department)
        .get();

    final Map<String, int> areaCounts = {};
    final Map<String, int> categoryCounts = {};
    final Map<DateTime, int> dailyCounts = {};

    int totalCount = 0;
    int successCount = 0;

    List<TimeSeriesData> fillMissing(
      DateTime start,
      DateTime end,
      Map<DateTime, int> counts,
    ) {
      List<TimeSeriesData> list = [];

      if (_selectedRange == 'This Year') {
        // By month
        for (int m = 1; m <= 12; m++) {
          final monthDate = DateTime(start.year, m);
          list.add(TimeSeriesData(monthDate, counts[monthDate] ?? 0));
        }
      } else {
        // By day
        for (
          int i = 0;
          start.add(Duration(days: i)).isBefore(end.add(Duration(days: 1)));
          i++
        ) {
          final dayDate = DateTime(start.year, start.month, start.day + i);
          list.add(TimeSeriesData(dayDate, counts[dayDate] ?? 0));
        }
      }

      return list;
    }

    for (var doc in snapshot.docs) {
      final report = Report.fromFirestore(doc);

      // Filter by date range
      final createdAt = report.createdAt;
      if (createdAt.isBefore(dateRange.start) ||
          createdAt.isAfter(dateRange.end))
        continue;

      // Exclude unsuccessful reports from all chart counts
      if (report.status.toLowerCase() == 'unsuccessful') continue;

      // Count total reports (excluding unsuccessful)
      totalCount++;

      // Count resolved reports
      if (report.status.toLowerCase() == 'resolved') successCount++;

      // Count area
      final area = _extractArea(report.exactLocation);
      if (area != 'Unknown') areaCounts[area] = (areaCounts[area] ?? 0) + 1;

      // Count category
      final category = report.category ?? 'Unknown';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

      // Count per day
      if (_selectedRange == 'This Year') {
        // Aggregate by month
        final monthKey = DateTime(createdAt.year, createdAt.month);
        dailyCounts[monthKey] = (dailyCounts[monthKey] ?? 0) + 1;
      } else {
        // Aggregate by day
        final dayKey = DateTime(createdAt.year, createdAt.month, createdAt.day);
        dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
      }
    }

    // Sort and get top areas
    final sortedAreas = areaCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topAreas = sortedAreas.take(10).toList();

    setState(() {
      _totalReports = totalCount;
      _successfulReports = successCount;
      _successRate = totalCount > 0 ? (successCount / totalCount) * 100 : 0;
      _topArea = topAreas.isNotEmpty ? topAreas.first.key : '-';

      _areaData = topAreas.map((e) => AreaReportData(e.key, e.value)).toList();
      _categoryData =
          categoryCounts.entries.map((e) => ChartData(e.key, e.value)).toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      _dailyData = fillMissing(dateRange.start, dateRange.end, dailyCounts);

      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Analytics Dashboard',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsCards(),
                        const SizedBox(height: 24),
                        _buildChartsGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final dateRange = _getDateRangeForSelection();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: PopupMenuButton<String>(
                  initialValue: _selectedRange,
                  onSelected: (value) {
                    setState(() {
                      _selectedRange = value;
                    });
                    if (value != 'Custom Range') {
                      _fetchData();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedRange == 'Custom Range'
                              ? '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}'
                              : _selectedRange,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(width: 8),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => _rangeOptions
                      .map(
                        (option) =>
                            PopupMenuItem(value: option, child: Text(option)),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Custom date buttons appear only for Custom Range
          if (_selectedRange == 'Custom Range')
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    label: 'Start Date',
                    date: _customDateRange?.start,
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customDateRange?.start ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _customDateRange = DateTimeRange(
                            start: picked,
                            end:
                                _customDateRange?.end ??
                                DateTime.now(), // keep previous end or today
                          );
                        });
                        _fetchData();
                      }
                    },
                    onClear: _customDateRange != null
                        ? () {
                            setState(() {
                              _customDateRange = null;
                              _selectedRange = 'Last 30 Days';
                            });
                            _fetchData();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateButton(
                    label: 'End Date',
                    date: _customDateRange?.end,
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customDateRange?.end ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _customDateRange = DateTimeRange(
                            start:
                                _customDateRange?.start ??
                                DateTime.now(), // keep previous start or today
                            end: picked,
                          );
                        });
                        _fetchData();
                      }
                    },
                    onClear: _customDateRange != null
                        ? () {
                            setState(() {
                              _customDateRange = null;
                              _selectedRange = 'Last 30 Days';
                            });
                            _fetchData();
                          }
                        : null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Reusable date button like in AnnouncementsPage
  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
    VoidCallback? onClear,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: date != null ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: date != null ? Colors.blue.shade200 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: date != null
                    ? Colors.blue.shade700
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  date != null ? DateFormat('dd/MM/yy').format(date) : label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: date != null
                        ? Colors.blue.shade700
                        : Colors.grey.shade700,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Reports',
            _totalReports.toString(),
            Icons.description_outlined,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Resolved Reports',
            _successfulReports.toString(),
            Icons.check_circle_outline,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Resolved Rate',
            '${_successRate.toStringAsFixed(1)}%',
            Icons.trending_up,
            const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Top Area',
            _topArea,
            Icons.location_on_outlined,
            const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon and label
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Value on the right
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsGrid() {
    return Column(
      children: [
        // Time series chart - full width
        _buildChartCard(
          'Reports Over Time',
          _dailyData.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No data available for selected period'),
                  ),
                )
              : _buildTimeSeriesChart(),
          height: 320,
        ),
        const SizedBox(height: 24),
        // Two charts side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildChartCard(
                'Top 10 Areas',
                _areaData.isEmpty
                    ? const Center(child: Text('No area data available'))
                    : _buildAreaChart(),
                height: 400,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildChartCard(
                'Reports by Category',
                _categoryData.isEmpty
                    ? const Center(child: Text('No category data available'))
                    : _buildCategoryChart(),
                height: 400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart, {double? height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildTimeSeriesChart() {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        majorGridLines: const MajorGridLines(width: 0),
        dateFormat: _selectedRange == 'This Year'
            ? DateFormat('MMM') // show only month names
            : DateFormat('MMM d'), // show day
        intervalType: _selectedRange == 'This Year'
            ? DateTimeIntervalType.months
            : DateTimeIntervalType.days,
      ),

      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        minimum: 0,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y reports',
      ),

      series: <CartesianSeries>[
        AreaSeries<TimeSeriesData, DateTime>(
          dataSource: _dailyData,
          xValueMapper: (data, _) => data.date,
          yValueMapper: (data, _) => data.count,
          color: const Color(0xFF10B981).withOpacity(0.3),
          borderColor: const Color(0xFF10B981),
          borderWidth: 2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 4,
            width: 4,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaChart() {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        labelRotation: 45,
      ),
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        minimum: 0,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        ColumnSeries<AreaReportData, String>(
          dataSource: _areaData,
          xValueMapper: (data, _) => data.area,
          yValueMapper: (data, _) => data.count,
          color: const Color(0xFF3B82F6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChart() {
    return SfCircularChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries>[
        DoughnutSeries<ChartData, String>(
          dataSource: _categoryData,
          xValueMapper: (data, _) => data.label,
          yValueMapper: (data, _) => data.value,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 11),
          ),
          innerRadius: '60%',
        ),
      ],
    );
  }
}

// ---------- MODELS ----------
class ChartData {
  final String label;
  final int value;
  ChartData(this.label, this.value);
}

class AreaReportData {
  final String area;
  final int count;
  AreaReportData(this.area, this.count);
}

class TimeSeriesData {
  final DateTime date;
  final int count;
  TimeSeriesData(this.date, this.count);
}
