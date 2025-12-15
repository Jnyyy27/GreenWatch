import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_view/photo_view.dart';

class Announcement {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? imageBase64;
  final String? exactLocation;
  final double? latitude;
  final double? longitude;
  final String department;
  final String category;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.updatedAt,
    this.imageBase64,
    this.exactLocation,
    this.latitude,
    this.longitude,
    required this.department,
    required this.category,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      imageBase64: data['imageBase64'],
      exactLocation: data['exactLocation'],
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      department: data['department'] ?? '',
      category: data['category'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
      'imageBase64': imageBase64,
      'exactLocation': exactLocation,
      'latitude': latitude,
      'longitude': longitude,
      'department': department,
      'category': category,
    };
  }
}

class AnnouncementsPage extends StatefulWidget {
  final String department;

  const AnnouncementsPage({required this.department, super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _dateOrder = 'Newest'; // 'Newest' | 'Oldest'
  DateTime? _startDate;
  DateTime? _endDate;

  // Temporary values for dialog (UX-friendly)
  String _tempCategory = 'All';
  String _tempDateOrder = 'Newest';
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  final List<String> _categories = [
    'All',
    'General Announcement',
    'Infrastructure & Public Works',
    'Planning & Development',
    'Public Safety & Emergency',
    'Environmental & Health Services',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Announcements',
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
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search announcements...',
                      prefixIcon: const Icon(Icons.search),
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
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
          ),
          // Selected filters display
          if (_selectedCategory != 'All' ||
              _startDate != null ||
              _endDate != null ||
              _dateOrder != 'Newest')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Category Chip
                  if (_selectedCategory != 'All')
                    Chip(
                      label: Text('Category: $_selectedCategory'),
                      onDeleted: () {
                        setState(() => _selectedCategory = 'All');
                      },
                    ),

                  // Date Order Chip
                  if (_dateOrder != 'Newest')
                    Chip(
                      label: Text('Order: $_dateOrder'),
                      onDeleted: () {
                        setState(() => _dateOrder = 'Newest');
                      },
                    ),

                  // Start Date Chip
                  if (_startDate != null)
                    Chip(
                      label: Text('From: ${_formatDate(_startDate!)}'),
                      onDeleted: () {
                        setState(() => _startDate = null);
                      },
                    ),

                  // End Date Chip
                  if (_endDate != null)
                    Chip(
                      label: Text('To: ${_formatDate(_endDate!)}'),
                      onDeleted: () {
                        setState(() => _endDate = null);
                      },
                    ),

                  // Clear All Chip
                  Chip(
                    label: const Text('Clear All'),
                    backgroundColor: Colors.red.shade100,
                    labelStyle: TextStyle(color: Colors.red.shade800),
                    onDeleted: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _dateOrder = 'Newest';
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Announcements list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .where('department', isEqualTo: widget.department)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No announcements yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allAnnouncements = snapshot.data!.docs
                    .map((doc) => Announcement.fromFirestore(doc))
                    .toList();

                final filtered = allAnnouncements.where((ann) {
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      ann.title.toLowerCase().contains(_searchQuery) ||
                      ann.description.toLowerCase().contains(_searchQuery);

                  final matchesCategory =
                      _selectedCategory == 'All' ||
                      ann.category == _selectedCategory;

                  final matchesStartDate =
                      _startDate == null ||
                      ann.createdAt.isAfter(
                        DateTime(
                          _startDate!.year,
                          _startDate!.month,
                          _startDate!.day - 1,
                        ),
                      );

                  final matchesEndDate =
                      _endDate == null ||
                      ann.createdAt.isBefore(
                        DateTime(
                          _endDate!.year,
                          _endDate!.month,
                          _endDate!.day + 1,
                        ),
                      );

                  return matchesSearch &&
                      matchesCategory &&
                      matchesStartDate &&
                      matchesEndDate;
                }).toList();

                // SORT
                filtered.sort((a, b) {
                  return _dateOrder == 'Newest'
                      ? b.createdAt.compareTo(a.createdAt)
                      : a.createdAt.compareTo(b.createdAt);
                });

                if (filtered.isEmpty) {
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
                          'No results found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ann = filtered[index];
                    return _buildAnnouncementCard(ann);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color.fromARGB(255, 188, 255, 192),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  void _showFilterDialog() {
    _tempCategory = _selectedCategory;
    _tempDateOrder = _dateOrder;
    _tempStartDate = _startDate;
    _tempEndDate = _endDate;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
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
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Filter Announcements',
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
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Section
                          _buildSectionLabel('Category', Icons.label_outline),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _tempCategory,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: InputBorder.none,
                              ),
                              dropdownColor: Colors.white,
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setDialogState(() => _tempCategory = value!);
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Sort Order Section
                          _buildSectionLabel('Sort By', Icons.sort),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _tempDateOrder,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: InputBorder.none,
                              ),
                              dropdownColor: Colors.white,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Newest',
                                  child: Row(
                                    children: [
                                      Icon(Icons.arrow_downward, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Most Recent',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Oldest',
                                  child: Row(
                                    children: [
                                      Icon(Icons.arrow_upward, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Oldest First',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() => _tempDateOrder = value!);
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Date Range Section
                          _buildSectionLabel('Date Range', Icons.date_range),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateButton(
                                  context: context,
                                  label: 'Start Date',
                                  date: _tempStartDate,
                                  icon: Icons.calendar_today,
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _tempStartDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: Colors.blue.shade600,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setDialogState(
                                        () => _tempStartDate = picked,
                                      );
                                    }
                                  },
                                  onClear: _tempStartDate != null
                                      ? () {
                                          setDialogState(
                                            () => _tempStartDate = null,
                                          );
                                        }
                                      : null,
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
                                child: _buildDateButton(
                                  context: context,
                                  label: 'End Date',
                                  date: _tempEndDate,
                                  icon: Icons.event,
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _tempEndDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: Colors.blue.shade600,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setDialogState(
                                        () => _tempEndDate = picked,
                                      );
                                    }
                                  },
                                  onClear: _tempEndDate != null
                                      ? () {
                                          setDialogState(
                                            () => _tempEndDate = null,
                                          );
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      _tempCategory = 'All';
                                      _tempDateOrder = 'Newest';
                                      _tempStartDate = null;
                                      _tempEndDate = null;
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
                                      _selectedCategory = _tempCategory;
                                      _dateOrder = _tempDateOrder;
                                      _startDate = _tempStartDate;
                                      _endDate = _tempEndDate;
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
                                    backgroundColor: Colors.blue.shade600,
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
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for section labels
  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // Helper method for date buttons
  Widget _buildDateButton({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required IconData icon,
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
                icon,
                size: 16,
                color: date != null
                    ? Colors.blue.shade700
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null ? 'Select' : _formatDate(date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? Colors.blue.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
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

  // Announcement Card Widget

  Widget _buildAnnouncementCard(Announcement announcement) {
    return GestureDetector(
      onTap: () => _showAnnouncementDetail(announcement),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Divider
              Container(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Date info + chips row using Wrap
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date info
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Published',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(announcement.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Wrap for chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.label, size: 12, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              announcement.category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Photo indicator
                      if (announcement.imageBase64 != null)
                        Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image,
                                size: 12,
                                color: Colors.purple.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple.shade600,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.purple.shade50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      // Location indicator
                      if (announcement.exactLocation != null)
                        Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.blue.shade50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                announcement.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => _CreateAnnouncementDialog(
        department: widget.department,
        onCreated: () => setState(() {}),
      ),
    );
  }

  void _showAnnouncementDetail(Announcement announcement) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image section
                      if (announcement.imageBase64 != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  _showFullImage(
                                    context,
                                    announcement.imageBase64!,
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    height: 280,
                                    color: Colors.grey.shade100,
                                    child: Image.memory(
                                      base64Decode(announcement.imageBase64!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              // Zoom icon
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () {
                                    _showFullImage(
                                      context,
                                      announcement.imageBase64!,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Content section
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.label,
                                    size: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    announcement.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Title
                            Text(
                              announcement.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                height: 1.3,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Date info card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Published',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(announcement.createdAt),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (announcement.updatedAt != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Updated',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(announcement.updatedAt!),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Description section
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                announcement.description,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.7,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),

                            // Location section
                            if (announcement.latitude != null &&
                                announcement.longitude != null) ...[
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Colors.red.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Location',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        announcement.latitude!,
                                        announcement.longitude!,
                                      ),
                                      zoom: 15,
                                    ),
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId(
                                          'announcementLocation',
                                        ),
                                        position: LatLng(
                                          announcement.latitude!,
                                          announcement.longitude!,
                                        ),
                                        infoWindow: InfoWindow(
                                          title:
                                              announcement.exactLocation ??
                                              'Location',
                                        ),
                                      ),
                                    },
                                    zoomControlsEnabled: false,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showEditDialog(announcement);
                                    },
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showDeleteConfirm(announcement.id);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade600,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(
                                        color: Colors.red.shade300,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
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
            ],
          ),
        ),
      ),
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

  void _showEditDialog(Announcement announcement) {
    showDialog(
      context: context,
      builder: (_) => _EditAnnouncementDialog(
        announcement: announcement,
        onUpdated: () => setState(() {}),
      ),
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('announcements')
                  .doc(id)
                  .delete();
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Announcement deleted')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

// Create Announcement Dialog

class _CreateAnnouncementDialog extends StatefulWidget {
  final String department;
  final VoidCallback onCreated;

  const _CreateAnnouncementDialog({
    required this.department,
    required this.onCreated,
  });

  @override
  State<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends State<_CreateAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String? _imageBase64;
  double? _latitude;
  double? _longitude;
  String _selectedCategory = 'General Announcement';
  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _imageBase64 = base64Encode(bytes));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // void _showMapPicker() {
  //   showDialog(
  //     context: context,
  //     builder: (_) => Dialog(
  //       child: SizedBox(
  //         width: 500,
  //         height: 400,
  //         child: Column(
  //           children: [
  //             Expanded(
  //               child: GoogleMap(
  //                 initialCameraPosition: const CameraPosition(
  //                   target: LatLng(3.1390, 101.6869),
  //                   zoom: 12,
  //                 ),
  //                 onTap: (LatLng position) async {
  //                   final address = await _getAddressFromLatLng(
  //                     position.latitude,
  //                     position.longitude,
  //                   );

  //                   setState(() {
  //                     _latitude = position.latitude;
  //                     _longitude = position.longitude;
  //                     _locationController.text = address ?? ''; // ADD THIS LINE
  //                   });
  //                 },
  //               ),
  //             ),
  //             Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: Text(
  //                 'Tap on map to select location',
  //                 style: TextStyle(color: Colors.grey.shade600),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Future<void> _createAnnouncement() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageBase64': _imageBase64,
        'exactLocation': _locationController.text.isEmpty
            ? null
            : _locationController.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'department': widget.department,
        'category': _selectedCategory,
      });

      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Announcement created')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Announcement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter announcement title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter announcement details',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Category *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'General Announcement',
                          child: Text('General Announcement'),
                        ),
                        DropdownMenuItem(
                          value: 'Infrastructure & Public Works',
                          child: Text('Infrastructure & Public Works'),
                        ),
                        DropdownMenuItem(
                          value: 'Planning & Development',
                          child: Text('Planning & Development'),
                        ),
                        DropdownMenuItem(
                          value: 'Public Safety & Emergency',
                          child: Text('Public Safety & Emergency'),
                        ),
                        DropdownMenuItem(
                          value: 'Environmental & Health Services',
                          child: Text('Environmental & Health Services'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Upload Image',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_imageBase64 == null)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 32,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Click to upload image',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_imageBase64!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _imageBase64 = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _latitude ?? 3.1390,
                            _longitude ?? 101.6869,
                          ),
                          zoom: 12,
                        ),
                        markers: _latitude != null && _longitude != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('selectedLocation'),
                                  position: LatLng(_latitude!, _longitude!),
                                ),
                              }
                            : {},
                        onTap: (LatLng position) async {
                          final address = await _getAddressFromLatLng(
                            position.latitude,
                            position.longitude,
                          );

                          setState(() {
                            _latitude = position.latitude;
                            _longitude = position.longitude;
                            _locationController.text = address ?? '';
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location selected'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        mapType: MapType.normal,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createAnnouncement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Create',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _getAddressFromLatLng(double? lat, double? lng) async {
  // ✅ Guard: if location not selected, return null
  if (lat == null || lng == null) return null;

  try {
    final placemarks = await placemarkFromCoordinates(lat, lng);

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;

      final List<String> parts = [];

      if (place.street?.isNotEmpty == true) parts.add(place.street!);
      if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
      if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
      if (place.administrativeArea?.isNotEmpty == true) {
        parts.add(place.administrativeArea!);
      }
      if (place.country?.isNotEmpty == true) parts.add(place.country!);

      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }
  } catch (e) {
    debugPrint('Reverse geocoding failed: $e');
  }

  // ✅ Safe fallback — still no crash
  return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
}

// Edit Announcement Dialog

class _EditAnnouncementDialog extends StatefulWidget {
  final Announcement announcement;
  final VoidCallback onUpdated;

  const _EditAnnouncementDialog({
    required this.announcement,
    required this.onUpdated,
  });

  @override
  State<_EditAnnouncementDialog> createState() =>
      _EditAnnouncementDialogState();
}

class _EditAnnouncementDialogState extends State<_EditAnnouncementDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  String? _imageBase64;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement.title);
    _descriptionController = TextEditingController(
      text: widget.announcement.description,
    );
    _locationController = TextEditingController(
      text: widget.announcement.exactLocation ?? '',
    );
    _imageBase64 = widget.announcement.imageBase64;
    _latitude = widget.announcement.latitude;
    _longitude = widget.announcement.longitude;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _imageBase64 = base64Encode(bytes));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showMapPicker() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_latitude ?? 3.1390, _longitude ?? 101.6869),
                    zoom: 12,
                  ),
                  onTap: (LatLng position) async {
                    final address = await _getAddressFromLatLng(
                      position.latitude,
                      position.longitude,
                    );

                    setState(() {
                      _latitude = position.latitude;
                      _longitude = position.longitude;
                      _locationController.text = address ?? '';
                    });

                    Navigator.pop(context);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tap on map to select location',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateAnnouncement() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(widget.announcement.id)
          .update({
            'title': _titleController.text,
            'description': _descriptionController.text,
            'imageBase64': _imageBase64,
            'exactLocation': _locationController.text.isEmpty
                ? null
                : _locationController.text,
            'latitude': _latitude,
            'longitude': _longitude,
            'updatedAt': DateTime.now(),
          });

      widget.onUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Announcement updated')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Announcement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Image',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_imageBase64 == null)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 32,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click to change image',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_imageBase64!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _imageBase64 = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _latitude ?? 3.1390,
                            _longitude ?? 101.6869,
                          ),
                          zoom: 12,
                        ),
                        markers: _latitude != null && _longitude != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('selectedLocation'),
                                  position: LatLng(_latitude!, _longitude!),
                                ),
                              }
                            : {},
                        onTap: (LatLng position) async {
                          final address = await _getAddressFromLatLng(
                            position.latitude,
                            position.longitude,
                          );

                          setState(() {
                            _latitude = position.latitude;
                            _longitude = position.longitude;
                            _locationController.text = address ?? '';
                          });
                        },
                        mapType: MapType.normal,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateAnnouncement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Update',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
