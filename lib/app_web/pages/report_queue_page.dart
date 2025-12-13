import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_detail_page.dart';
import '../services/report_model.dart';

class ReportQueuePage extends StatefulWidget {
  final String department;

  const ReportQueuePage({required this.department, super.key});

  @override
  State<ReportQueuePage> createState() => _ReportQueuePageState();
}

class _ReportQueuePageState extends State<ReportQueuePage> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String? _selectedStatus;
  Set<String> _selectedCategories = {};
  DateTime? _startDate;
  DateTime? _endDate;

  final Map<String, List<String>> _departmentCategories = {
    'MBPP': [
      'Public equipment problem',
      'Damage/missing road signs',
      'Faded road markings',
      'Traffic light problem',
    ],
    'TNB': ['Streetlights problem'],
    'JKR': ['Damage roads', 'Road potholes'],
  };

  final List<String> _allStatuses = [
    'All',
    'Submitted',
    'Viewed',
    'In Progress',
    'Resolved',
  ];

  // add this near your other fields
  final ValueNotifier<Report?> selectedReportNotifier = ValueNotifier<Report?>(
    null,
  );

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedStatus = 'All';
  }

  @override
  void dispose() {
    _searchController.dispose();
    selectedReportNotifier.dispose();
    super.dispose();
  }

  List<Report> _filterReports(List<Report> reports) {
    return reports.where((report) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          report.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.exactLocation.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          report.description.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _selectedStatus == 'All' ||
          _selectedStatus == _normalizeStatus(report.status);

      final matchesCategory =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(report.category);

      final matchesDate =
          (_startDate == null || report.createdAt.isAfter(_startDate!)) &&
          (_endDate == null ||
              report.createdAt.isBefore(
                _endDate!.add(const Duration(days: 1)),
              ));

      return matchesSearch && matchesStatus && matchesCategory && matchesDate;
    }).toList();
  }

  String _normalizeStatus(String status) {
    final statusMap = {
      'pending verification': 'Submitted',
      'viewed': 'Viewed',
      'in progress': 'In Progress',
      'resolved': 'Resolved',
    };
    return statusMap[status.toLowerCase()] ?? status;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedCategories: _selectedCategories,
        departmentCategories: _departmentCategories[widget.department] ?? [],
        startDate: _startDate,
        endDate: _endDate,
        onApply: (categories, startDate, endDate) {
          setState(() {
            _selectedCategories = categories;
            _startDate = startDate;
            _endDate = endDate;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Submitted':
        return const Color(0xFFF57C00);
      case 'Viewed':
        return const Color(0xFF512DA8);
      case 'In Progress':
        return const Color(0xFF1976D2);
      case 'Resolved':
        return const Color(0xFF388E3C);
      default:
        return Colors.grey.shade400;
    }
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Queue',
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
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Main Search Bar with integrated filters
                Row(
                  children: [
                    // Search Input
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search reports...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Dropdown
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          items: _allStatuses
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(status),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedStatus = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // More Filters Button
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color:
                            (_selectedCategories.isNotEmpty ||
                                _startDate != null ||
                                _endDate != null)
                            ? const Color(0xFF2E7D32)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              (_selectedCategories.isNotEmpty ||
                                  _startDate != null ||
                                  _endDate != null)
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showFilterDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 18,
                                  color:
                                      (_selectedCategories.isNotEmpty ||
                                          _startDate != null ||
                                          _endDate != null)
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                if (_selectedCategories.isNotEmpty ||
                                    _startDate != null ||
                                    _endDate != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${(_selectedCategories.length + (_startDate != null ? 1 : 0) + (_endDate != null ? 1 : 0))}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Active Filters Chips (if any)
                if (_selectedCategories.isNotEmpty ||
                    _startDate != null ||
                    _endDate != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Category chips
                        ..._selectedCategories.map(
                          (category) => _buildFilterChip(
                            label: category,
                            onDelete: () {
                              setState(
                                () => _selectedCategories.remove(category),
                              );
                            },
                          ),
                        ),
                        // Date range chip
                        if (_startDate != null || _endDate != null)
                          _buildFilterChip(
                            label:
                                '${_startDate != null ? '${_startDate!.day}/${_startDate!.month}' : 'Start'} - ${_endDate != null ? '${_endDate!.day}/${_endDate!.month}' : 'End'}',
                            onDelete: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                          ),
                        // Clear all button
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategories.clear();
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Clear all',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Main Content: Left Panel (List) and Right Panel (Details)
          Expanded(
            child: Row(
              children: [
                // Left Panel: Report List
                Expanded(
                  flex: 1,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .where('department', isEqualTo: widget.department)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No reports available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final allReports = snapshot.data!.docs
                          .map((doc) => Report.fromFirestore(doc))
                          .toList();

                      final filteredReports = _filterReports(allReports);

                      if (filteredReports.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No reports match your filters',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ValueListenableBuilder<Report?>(
                        valueListenable: selectedReportNotifier,
                        builder: (context, selectedReport, _) {
                          return ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredReports.length,
                            itemBuilder: (context, index) {
                              final report = filteredReports[index];
                              final isSelected =
                                  selectedReport?.reportId == report.reportId;

                              return _buildReportListItem(report, isSelected);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                // Divider
                Container(width: 1, color: Colors.grey.shade300),
                // Right Panel: Report Details
                // Right Panel: Report Details (listens to selectedReportNotifier)
                Expanded(
                  flex: 1,
                  child: ValueListenableBuilder<Report?>(
                    valueListenable: selectedReportNotifier,
                    builder: (context, selectedReport, _) {
                      if (selectedReport == null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a report to view more details',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _buildReportDetailsPanel(selectedReport);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportListItem(Report report, bool isSelected) {
    return Card(
      key: ValueKey(report.reportId),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Colors.green.shade50 : Colors.white,
      child: InkWell(
        onTap: () {
          selectedReportNotifier.value = report;
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(_normalizeStatus(report.status)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.exactLocation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Reported: ${_formatDate(report.createdAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildReportDetailsPanel(Report report) {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // Image
  //         if (report.imageUrl.isNotEmpty)
  //           Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 'Submitted Image',
  //                 style: TextStyle(
  //                   fontSize: 13,
  //                   fontWeight: FontWeight.w600,
  //                   color: Colors.grey.shade800,
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               Container(
  //                 width: double.infinity,
  //                 height: 200,
  //                 decoration: BoxDecoration(
  //                   color: Colors.grey.shade200,
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(color: Colors.grey.shade300),
  //                 ),
  //                 child: Icon(
  //                   Icons.image,
  //                   size: 48,
  //                   color: Colors.grey.shade400,
  //                 ),
  //               ),
  //               const SizedBox(height: 16),
  //             ],
  //           ),
  //         // Category and Status
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     report.category,
  //                     style: const TextStyle(
  //                       fontSize: 18,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 8),
  //                   _buildStatusBadge(_normalizeStatus(report.status)),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //         // Location
  //         _buildDetailRow('Location', report.exactLocation),
  //         const SizedBox(height: 12),
  //         // Reported Date
  //         _buildDetailRow('Reported', _formatDate(report.createdAt)),
  //         const SizedBox(height: 12),
  //         // Updated Date
  //         _buildDetailRow('Last Updated', _formatDate(report.updatedAt)),
  //         const SizedBox(height: 16),
  //         // Map Placeholder
  //         Container(
  //           width: double.infinity,
  //           height: 200,
  //           decoration: BoxDecoration(
  //             color: Colors.grey.shade200,
  //             borderRadius: BorderRadius.circular(8),
  //             border: Border.all(color: Colors.grey.shade300),
  //           ),
  //           child: Center(
  //             child: Column(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Icon(Icons.map, size: 48, color: Colors.grey.shade400),
  //                 const SizedBox(height: 8),
  //                 Text(
  //                   'Map View\nLat: ${report.latitude.toStringAsFixed(4)}, Lng: ${report.longitude.toStringAsFixed(4)}',
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         // Description
  //         Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'Description',
  //               style: TextStyle(
  //                 fontSize: 13,
  //                 fontWeight: FontWeight.w600,
  //                 color: Colors.grey.shade800,
  //               ),
  //             ),
  //             const SizedBox(height: 8),
  //             Container(
  //               width: double.infinity,
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: Colors.grey.shade50,
  //                 borderRadius: BorderRadius.circular(8),
  //                 border: Border.all(color: Colors.grey.shade300),
  //               ),
  //               child: Text(
  //                 report.description,
  //                 style: const TextStyle(fontSize: 13, height: 1.5),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 24),
  //         // Manage Button
  //         SizedBox(
  //           width: double.infinity,
  //           child: ElevatedButton(
  //             onPressed: () {
  //               _showReportDetailModal(report);
  //             },
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.green.shade700,
  //               foregroundColor: Colors.white,
  //               padding: const EdgeInsets.symmetric(vertical: 14),
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //             ),
  //             child: const Text(
  //               'Manage Report',
  //               style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildReportDetailsPanel(Report report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  report.category,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1a1a1a),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(_normalizeStatus(report.status)),
            ],
          ),
          const SizedBox(height: 24),

          // Submitted Image
          if (report.imageUrl.isNotEmpty)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.network(
                      report.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          if (report.imageUrl.isEmpty) const SizedBox(height: 5),
          Text(
            'Submitted Image',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),

          // Info Cards
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: report.exactLocation,
                  iconColor: const Color(0xFFE53935),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.access_time_outlined,
                  label: 'Reported',
                  value: _formatDate(report.createdAt),
                  iconColor: const Color(0xFF1976D2),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.update_outlined,
                  label: 'Last Updated',
                  value: _formatDate(report.updatedAt),
                  iconColor: const Color(0xFF7B1FA2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  report.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Manage Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showReportDetailModal(report);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Manage Report',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1a1a1a),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showReportDetailModal(Report report) {
    showDialog(
      context: context,
      builder: (context) => ReportDetailModal(report: report),
    );
  }

  // Widget _buildDetailRow(String label, String value) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 12,
  //           fontWeight: FontWeight.w600,
  //           color: Colors.grey.shade600,
  //         ),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(value, style: const TextStyle(fontSize: 13)),
  //     ],
  //   );
  // }

  Widget _buildStatusBadge(String status) {
    final statusColors = {
      'Submitted': Color(0xFFFFF3E0),
      'Viewed': Color(0xFFEDE7F6),
      'In Progress': Color(0xFFE3F2FD),
      'Resolved': Color(0xFFE8F5E9),
    };

    final statusTextColors = {
      'Submitted': Color(0xFFF57C00),
      'Viewed': Color(0xFF512DA8),
      'In Progress': Color(0xFF1976D2),
      'Resolved': Color(0xFF388E3C),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColors[status] ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: statusTextColors[status] ?? Colors.grey.shade700,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final t = '${date.day}/${date.month}/${date.year}';

    if (difference.inHours < 1) {
      return t + ' ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return t + ' ${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return t + ' ${difference.inDays}d ago';
    } else {
      return t + ' ${date.day}/${date.month}/${date.year}';
    }
  }
}

class _FilterDialog extends StatefulWidget {
  final Set<String> selectedCategories;
  final List<String> departmentCategories;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(Set<String>, DateTime?, DateTime?) onApply;

  const _FilterDialog({
    required this.selectedCategories,
    required this.departmentCategories,
    required this.startDate,
    required this.endDate,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late Set<String> _tempCategories;
  late DateTime? _tempStartDate;
  late DateTime? _tempEndDate;

  @override
  void initState() {
    super.initState();
    _tempCategories = Set.from(widget.selectedCategories);
    _tempStartDate = widget.startDate;
    _tempEndDate = widget.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Additional Filters'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter
            Text(
              'Problem Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...widget.departmentCategories.map((category) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(category, style: const TextStyle(fontSize: 14)),
                value: _tempCategories.contains(category),
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      _tempCategories.add(category);
                    } else {
                      _tempCategories.remove(category);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 16),
            // Date Range Filter
            Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _tempStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _tempStartDate = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _tempStartDate == null
                          ? 'Start'
                          : '${_tempStartDate!.day}/${_tempStartDate!.month}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _tempEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _tempEndDate = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _tempEndDate == null
                          ? 'End'
                          : '${_tempEndDate!.day}/${_tempEndDate!.month}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _tempCategories.clear();
              _tempStartDate = null;
              _tempEndDate = null;
            });
          },
          child: const Text('Reset'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_tempCategories, _tempStartDate, _tempEndDate);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
          ),
          child: const Text('Apply', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
