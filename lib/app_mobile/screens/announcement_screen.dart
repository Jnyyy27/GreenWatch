import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'announcement_detail_screen.dart';
import '../../services/announcement_model.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  String _selectedCategory = 'All';
  bool _sortNewestFirst = true;

  final Map<String, String> departmentMap = {
    'MBPP': 'Majlis Bandaraya Pulau Pinang',
    'JKR': 'Jabatan Kerja Raya',
    'TNB': 'Tenaga Nasional Berhad',
  };

  final Map<String, String> departmentLogoMap = {
    'MBPP': 'assets/images/mbpp.png',
    'JKR': 'assets/images/jkr.png',
    'TNB': 'assets/images/tnb.png',
  };

  final List<String> _departments = ['All', 'MBPP', 'JKR', 'TNB'];

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
  }

  // Fetch distinct departments and categories from Firebase

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color.fromARGB(255, 96, 156, 101),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _emptyState();
                }

                // Convert documents to Announcement model
                final announcements = snapshot.data!.docs
                    .map((doc) => Announcement.fromFirestore(doc))
                    .toList();

                // Apply search and filter
                final filtered = announcements.where((a) {
                  final matchSearch = a.title.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
                  final matchDept =
                      _selectedDepartment == 'All' ||
                      a.department == _selectedDepartment;
                  final matchCat =
                      _selectedCategory == 'All' ||
                      a.category == _selectedCategory;
                  return matchSearch && matchDept && matchCat;
                }).toList();

                if (filtered.isEmpty) return _emptyState();
                filtered.sort((a, b) {
                  if (a.createdAt == null || b.createdAt == null) return 0;
                  return _sortNewestFirst
                      ? b.createdAt!.compareTo(a.createdAt!)
                      : a.createdAt!.compareTo(b.createdAt!);
                });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _announcementCard(context, filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------- Search & Filters -----------------------------
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Column(
        children: [
          // Search bar
          // Row(
          //   children: [
          //     Expanded(
          //       child: TextField(
          //         decoration: InputDecoration(
          //           hintText: 'Search announcements...',
          //           prefixIcon: const Icon(Icons.search),
          //           filled: true,
          //           fillColor: Colors.grey.shade100,
          //           border: OutlineInputBorder(
          //             borderRadius: BorderRadius.circular(12),
          //             borderSide: BorderSide.none,
          //           ),
          //         ),
          //         onChanged: (value) => setState(() => _searchQuery = value),
          //       ),
          //     ),
          //     const SizedBox(width: 8),
          //     IconButton(
          //       icon: const Icon(Icons.filter_list),
          //       onPressed: _openFilterDialog,
          //     ),
          //   ],
          // ),
          Column(
            children: [
              // Search bar + filter icon
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search announcements...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _openFilterDialog,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Active filters row
              if (_selectedDepartment != 'All' ||
                  _selectedCategory != 'All' ||
                  !_sortNewestFirst)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedDepartment != 'All')
                        _activeFilterChip(
                          label: 'Department',
                          value:
                              departmentMap[_selectedDepartment] ??
                              _selectedDepartment,
                        ),
                      if (_selectedCategory != 'All')
                        _activeFilterChip(
                          label: 'Category',
                          value: _selectedCategory,
                        ),
                      if (!_sortNewestFirst)
                        _activeFilterChip(label: 'Sort', value: 'Oldest first'),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDepartment = 'All';
                            _selectedCategory = 'All';
                            _sortNewestFirst = true;
                          });
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeFilterChip({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                if (label == 'Department') _selectedDepartment = 'All';
                if (label == 'Category') _selectedCategory = 'All';
                if (label == 'Sort') _sortNewestFirst = true;
              });
            },
            child: const Icon(Icons.close, size: 14, color: Colors.green),
          ),
        ],
      ),
    );
  }

  void _openFilterDialog() {
    String tempDepartment = _selectedDepartment;
    String tempCategory = _selectedCategory;
    bool tempSortNewest = _sortNewestFirst;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filter Announcements'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Department
                    const Text('Department'),
                    DropdownButton<String>(
                      value: tempDepartment,
                      isExpanded: true,
                      items: _departments
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(
                                d == 'All' ? 'All' : departmentMap[d] ?? d,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setStateDialog(() {
                          tempDepartment = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Category
                    const Text('Category'),
                    DropdownButton<String>(
                      value: tempCategory,
                      isExpanded: true,
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setStateDialog(() {
                          tempCategory = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Sort
                    const Text('Sort by Date'),
                    RadioListTile<bool>(
                      title: const Text('Newest first'),
                      value: true,
                      groupValue: tempSortNewest,
                      onChanged: (v) {
                        setStateDialog(() {
                          tempSortNewest = v!;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('Oldest first'),
                      value: false,
                      groupValue: tempSortNewest,
                      onChanged: (v) {
                        setStateDialog(() {
                          tempSortNewest = v!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDepartment = 'All';
                      _selectedCategory = 'All';
                      _sortNewestFirst = true;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDepartment = tempDepartment;
                      _selectedCategory = tempCategory;
                      _sortNewestFirst = tempSortNewest;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------- Announcement Card -----------------------------
  Widget _announcementCard(BuildContext context, Announcement a) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(data: a)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Department & Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      if (departmentLogoMap[a.department] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            6,
                          ), // small rounded corners
                          child: Container(
                            width: 50, // max width
                            height: 50, // max height
                            color: Colors.white, // optional background
                            padding: const EdgeInsets.all(2),
                            child: Image.asset(
                              departmentLogoMap[a.department]!,
                              fit: BoxFit.contain, // preserve aspect ratio
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        departmentMap[a.department] ??
                            a.department ??
                            'Department',
                        style: TextStyle(
                          fontSize: 13, // slightly bigger text
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            // Title
            Text(
              a.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            // Category
            if (a.category != null || a.createdAt != null)
              Row(
                children: [
                  if (a.category != null) ...[
                    Icon(Icons.label, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.category!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                  if (a.createdAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(a.createdAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------- Empty State -----------------------------
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.announcement_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No announcements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Updates will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
