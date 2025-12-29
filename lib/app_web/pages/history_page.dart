import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/report_model.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryPage extends StatefulWidget {
  final String department;

  const HistoryPage({required this.department, super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedDateFilter = 'Most Recent';
  DateTimeRange? _selectedDateRange;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  final Map<String, List<String>> _departmentCategories = {
    'MBPP': [
      'Public facilities',
      'Road signs',
      'Faded road markings',
      'Traffic lights',
      'Fallen trees',
    ],
    'TNB': ['Streetlights'],
    'JKR': ['Damage roads', 'Road potholes'],
  };

  List<String> get _categories {
    final deptCategories = _departmentCategories[widget.department] ?? [];
    return ['All', ...deptCategories];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          Expanded(child: _buildResolvedList()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'History',
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
        decoration: InputDecoration(
          hintText: 'Search by description or location...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade300, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value!);
                },
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.category,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                dropdownColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showDateFilterMenu,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDateFilter == 'Custom'
                            ? 'Custom'
                            : _selectedDateFilter,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_selectedDateFilter != 'Most Recent') ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: IconButton(
                icon: Icon(Icons.clear, size: 20, color: Colors.red.shade700),
                onPressed: () {
                  setState(() {
                    _selectedDateFilter = 'Most Recent';
                    _selectedDateRange = null;
                  });
                },
                tooltip: 'Reset filter',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDateFilterMenu() {
    String _tempDateFilter = _selectedDateFilter;
    DateTime? _dialogTempStartDate = _tempStartDate;
    DateTime? _dialogTempEndDate = _tempEndDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Filter History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Filter Options Section
                            Row(
                              children: [
                                Icon(
                                  Icons.sort,
                                  size: 20,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sort By',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ),
                                    title: const Text(
                                      'Most Recent',
                                      style: TextStyle(fontSize: 15),
                                    ),
                                    value: 'Most Recent',
                                    groupValue: _tempDateFilter,
                                    activeColor: Colors.green.shade600,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        _tempDateFilter =
                                            value ?? 'Most Recent';
                                      });
                                    },
                                  ),
                                  RadioListTile<String>(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ),
                                    title: const Text(
                                      'Oldest First',
                                      style: TextStyle(fontSize: 15),
                                    ),
                                    value: 'Oldest First',
                                    groupValue: _tempDateFilter,
                                    activeColor: Colors.green.shade600,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        _tempDateFilter =
                                            value ?? 'Oldest First';
                                      });
                                    },
                                  ),
                                  RadioListTile<String>(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ),
                                    title: const Text(
                                      'Custom',
                                      style: TextStyle(fontSize: 15),
                                    ),
                                    value: 'Custom',
                                    groupValue: _tempDateFilter,
                                    activeColor: Colors.green.shade600,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        _tempDateFilter = value ?? 'Custom';
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Custom Date Range (show only if Custom is selected)
                            if (_tempDateFilter == 'Custom') ...[
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Date Range',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _dialogTempStartDate ??
                                                DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now(),
                                            builder: (context, child) {
                                              return Theme(
                                                data: Theme.of(context)
                                                    .copyWith(
                                                      colorScheme:
                                                          ColorScheme.light(
                                                            primary: Colors
                                                                .green
                                                                .shade600,
                                                          ),
                                                    ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (date != null) {
                                            setDialogState(() {
                                              _dialogTempStartDate = date;
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _dialogTempStartDate == null
                                                    ? 'Start Date'
                                                    : '${_dialogTempStartDate!.day}/${_dialogTempStartDate!.month}/${_dialogTempStartDate!.year}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color:
                                                      _dialogTempStartDate ==
                                                          null
                                                      ? Colors.grey.shade600
                                                      : Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _dialogTempEndDate ??
                                                DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now(),
                                            builder: (context, child) {
                                              return Theme(
                                                data: Theme.of(context)
                                                    .copyWith(
                                                      colorScheme:
                                                          ColorScheme.light(
                                                            primary: Colors
                                                                .green
                                                                .shade600,
                                                          ),
                                                    ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (date != null) {
                                            setDialogState(() {
                                              _dialogTempEndDate = date;
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.event,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _dialogTempEndDate == null
                                                    ? 'End Date'
                                                    : '${_dialogTempEndDate!.day}/${_dialogTempEndDate!.month}/${_dialogTempEndDate!.year}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color:
                                                      _dialogTempEndDate == null
                                                      ? Colors.grey.shade600
                                                      : Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 32),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setDialogState(() {
                                        _tempDateFilter = 'All Time';
                                        _dialogTempStartDate = null;
                                        _dialogTempEndDate = null;
                                      });
                                    },
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey.shade700,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedDateFilter = _tempDateFilter;
                                        if (_tempDateFilter == 'Custom') {
                                          _tempStartDate = _dialogTempStartDate;
                                          _tempEndDate = _dialogTempEndDate;
                                          if (_tempStartDate != null &&
                                              _tempEndDate != null) {
                                            _selectedDateRange = DateTimeRange(
                                              start: _tempStartDate!,
                                              end: _tempEndDate!,
                                            );
                                          }
                                          if (_tempStartDate != null &&
                                              _tempEndDate == null) {
                                            _selectedDateRange = DateTimeRange(
                                              start: _tempStartDate!,
                                              end: DateTime.now(),
                                            );
                                          }
                                          if (_tempStartDate == null &&
                                              _tempEndDate != null) {
                                            // Incomplete range, reset to null
                                            _selectedDateRange = DateTimeRange(
                                              start: DateTime(2020),
                                              end: _tempEndDate!,
                                            );
                                          }
                                        } else {
                                          _selectedDateRange = null;
                                          _tempStartDate = null;
                                          _tempEndDate = null;
                                        }
                                      });
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text(
                                      'Apply',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResolvedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('department', isEqualTo: widget.department)
          .where('status', isEqualTo: 'Resolved')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.green.shade600),
                const SizedBox(height: 16),
                Text(
                  'Loading resolved issues...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No resolved issues found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Resolved reports will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        var filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final category = (data['category'] ?? '').toString();
          final description = (data['description'] ?? '')
              .toString()
              .toLowerCase();
          final location = (data['exactLocation'] ?? '')
              .toString()
              .toLowerCase();
          final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

          if (_selectedCategory != 'All' && category != _selectedCategory) {
            return false;
          }
          if (_searchQuery.isNotEmpty &&
              !description.contains(_searchQuery) &&
              !location.contains(_searchQuery)) {
            return false;
          }
          if (_selectedDateRange != null && updatedAt != null) {
            if (updatedAt.isBefore(_selectedDateRange!.start) ||
                updatedAt.isAfter(
                  _selectedDateRange!.end.add(const Duration(days: 1)),
                )) {
              return false;
            }
          }
          return true;
        }).toList();

        // Apply sorting based on date filter
        if (_selectedDateFilter == 'Most Recent') {
          filteredDocs.sort((a, b) {
            final aDate = ((a.data() as Map)['updatedAt'] as Timestamp?)
                ?.toDate();
            final bDate = ((b.data() as Map)['updatedAt'] as Timestamp?)
                ?.toDate();
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });
        } else if (_selectedDateFilter == 'Oldest First') {
          filteredDocs.sort((a, b) {
            final aDate = ((a.data() as Map)['updatedAt'] as Timestamp?)
                ?.toDate();
            final bDate = ((b.data() as Map)['updatedAt'] as Timestamp?)
                ?.toDate();
            if (aDate == null || bDate == null) return 0;
            return aDate.compareTo(bDate);
          });
        }

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No matches found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filters',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final report = Report.fromFirestore(filteredDocs[index]);

            return _buildReportCard(report, data);
          },
        );
      },
    );
  }

  Widget _buildReportCard(Report report, Map<String, dynamic> data) {
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    final hasImage = report.imageBase64Thumbnail.isNotEmpty;

    return Card(
      color: const Color.fromARGB(255, 255, 255, 255),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => ReportDetailModal(report: report),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Image ----------
              if (hasImage)
                Container(
                  width: 80,
                  height: 105,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(report.imageBase64Thumbnail),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),

              // ---------- Info Column ----------
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category + Resolved Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['category'] ?? 'No category',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Location
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              report.exactLocation,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Reported & Resolved Time
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoChip(
                            Icons.access_time,
                            'Reported',
                            createdAt != null ? _formatDate(createdAt) : 'N/A',
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoChip(
                            Icons.update,
                            'Resolved',
                            updatedAt != null ? _formatDate(updatedAt) : 'N/A',
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // shrink to content
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ------------------------------------------------
// ReportDetailDialog: same as I sent previously
// ------------------------------------------------
class ReportDetailModal extends StatefulWidget {
  final Report report;

  const ReportDetailModal({required this.report, super.key});

  @override
  State<ReportDetailModal> createState() => _ReportDetailModalState();
}

class _ReportDetailModalState extends State<ReportDetailModal> {
  late String _selectedStatus;
  List<TimelineEntry> _timeline = [];
  final TextEditingController _commentController = TextEditingController();

  final List<String> _statusOptions = [
    'Submitted',
    'Viewed',
    'In Progress',
    'Resolved',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = _normalizeStatus(widget.report.status);
    if (!_statusOptions.contains(_selectedStatus))
      _selectedStatus = 'Submitted';
    _loadLatestStatus();
    _loadTimeline();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _loadTimeline() {
    final reportRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.report.reportId);
    reportRef.collection('timeline').orderBy('timestamp').snapshots().listen((
      snapshot,
    ) {
      setState(() {
        _timeline = snapshot.docs
            .map((doc) => TimelineEntry.fromFirestore(doc))
            .toList();
        if (_timeline.isEmpty && _selectedStatus == 'Submitted') {
          reportRef.collection('timeline').add({
            'action': 'Submitted',
            'timestamp': widget.report.createdAt,
            'user': 'System',
            'notes': 'Report submitted detail',
            'images': [],
          });
        }
      });
    });
  }

  String _normalizeStatus(String status) {
    final statusMap = {
      'submitted': 'Submitted',
      'viewed': 'Viewed',
      'in progress': 'In Progress',
      'resolved': 'Resolved',
    };
    return statusMap[status.toLowerCase()] ?? status;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'viewed':
        return Colors.orange;
      case 'in progress':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.send;
      case 'viewed':
        return Icons.visibility;
      case 'in progress':
        return Icons.build;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Future<void> _loadLatestStatus() async {
    try {
      final reportRef = FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.reportId);
      final reportSnap = await reportRef.get();
      setState(() => _selectedStatus = _normalizeStatus(reportSnap['status']));
    } catch (e) {
      setState(() => _selectedStatus = _normalizeStatus(widget.report.status));
    }
  }

  Future<void> _openGoogleMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${widget.report.latitude},${widget.report.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: const Text(
                'Report Details',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black87),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_selectedStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(_selectedStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(_selectedStatus),
                        size: 16,
                        color: _getStatusColor(_selectedStatus),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedStatus,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(_selectedStatus),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: Colors.grey.shade200, height: 1),
              ),
            ),
            body: Row(
              children: [
                Expanded(flex: 1, child: _buildLeftPanel()),
                Container(width: 1, color: Colors.grey.shade200),
                Expanded(flex: 1, child: _buildRightPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.report.imageBase64Thumbnail.isNotEmpty)
              _buildImageSection(),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _buildDescriptionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 350,
              child: Image.memory(
                base64Decode(widget.report.imageBase64Thumbnail),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: InkWell(
                onTap: () =>
                    _showFullImage(context, widget.report.imageBase64Thumbnail),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'View Full',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: Colors.white, // ✅ white background
            child: _buildInfoCard(
              icon: Icons.category,
              label: 'Category',
              value: widget.report.category,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            color: Colors.white, // ✅ white background
            child: _buildInfoCard(
              icon: Icons.access_time,
              label: 'Reported',
              value: _formatDate(widget.report.createdAt),
              color: Colors.orange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.place, color: Colors.red.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.report.exactLocation,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.report.latitude != 0.0 &&
            widget.report.longitude != 0.0) ...[
          const SizedBox(height: 16),
          _buildMapWidget(),
        ],
      ],
    );
  }

  Widget _buildMapWidget() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.report.latitude, widget.report.longitude),
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('loc'),
                  position: LatLng(
                    widget.report.latitude,
                    widget.report.longitude,
                  ),
                  infoWindow: InfoWindow(title: widget.report.exactLocation),
                ),
              },
              zoomControlsEnabled: false,
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: InkWell(
                onTap: _openGoogleMaps,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Open in Maps',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.description, 'Description'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            widget.report.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCards(),
            const SizedBox(height: 24),
            _buildTimelineSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.timeline, 'Timeline'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: _timeline.isEmpty
                ? [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No timeline entries',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ]
                : _timeline
                      .asMap()
                      .entries
                      .map(
                        (e) => _buildTimelineItem(
                          e.key,
                          e.value,
                          e.key == _timeline.length - 1,
                        ),
                      )
                      .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(int index, TimelineEntry item, bool isLast) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getStatusColor(item.action).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getStatusColor(item.action),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getStatusIcon(item.action),
                  size: 16,
                  color: _getStatusColor(item.action),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _getStatusColor(item.action).withOpacity(0.3),
                        Colors.grey.shade300,
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.action,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(item.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  'By: ${item.user}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      item.notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                if (item.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.images.map((img) {
                      return GestureDetector(
                        onTap: () => _showFullImage(context, img),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(img),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.green.shade700),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String base64Image) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PhotoView(
              imageProvider: MemoryImage(base64Decode(base64Image)),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
            Positioned(
              top: 32,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
