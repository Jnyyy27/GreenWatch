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

  final Map<String, String> departmentMap = {
    'MBPP': 'Majlis Bandaraya Pulau Pinang',
    'JKR': 'Jabatan Kerja Raya',
    'TNB': 'Tenaga Nasional Berhad',
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
          TextField(
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
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 10),
          // Filters
          Row(
            children: [
              _filterChip(
                label: 'Department',
                value: _selectedDepartment == 'All'
                    ? 'All'
                    : departmentMap[_selectedDepartment] ?? _selectedDepartment,
                options: _departments
                    .map((d) => d == 'All' ? 'All' : departmentMap[d] ?? d)
                    .toList(),
                onChanged: (v) {
                  // convert full name back to code
                  final key = departmentMap.entries
                      .firstWhere(
                        (e) => e.value == v,
                        orElse: () => MapEntry('All', 'All'),
                      )
                      .key;
                  setState(() => _selectedDepartment = key);
                },
              ),

              const SizedBox(width: 8),
              _filterChip(
                label: 'Category',
                value: _selectedCategory,
                options: _categories,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required String value,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) =>
          options.map((o) => PopupMenuItem(value: o, child: Text(o))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
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
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    departmentMap[a.department] ?? a.department ?? 'Department',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  a.createdAt != null ? _formatDate(a.createdAt!) : '',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
            if (a.category != null)
              Row(
                children: [
                  Icon(Icons.label, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    a.category!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
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
