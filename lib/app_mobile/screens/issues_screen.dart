import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:green_watch/app_mobile/screens/issue_detail_screen.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  String? _selectedCategory;
  String _areaSearchQuery = '';
  final TextEditingController _areaSearchController = TextEditingController();

  final List<String> _categories = [
    'Damage roads',
    'Road potholes',
    'Road signs',
    'Faded road markings',
    'Traffic lights',
    'Streetlights',
    'Public facilities',
  ];

  @override
  void dispose() {
    _areaSearchController.dispose();
    super.dispose();
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins minute${mins > 1 ? 's' : ''} ago';
    } else if (diff.inHours < 24) {
      final hrs = diff.inHours;
      return '$hrs hour${hrs > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 30) {
      final days = diff.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    // Check category filter
    if (_selectedCategory != null) {
      final category = data['category'] as String? ?? '';
      if (category != _selectedCategory) return false;
    }

    // Check area filter
    if (_areaSearchQuery.isNotEmpty) {
      final location = (data['exactLocation'] as String? ?? '').toLowerCase();
      if (!location.contains(_areaSearchQuery.toLowerCase())) return false;
    }

    return true;
  }

  void _showCategoryFilterMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          color: const Color.fromARGB(255, 96, 156, 101),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedCategory = null;
                              });
                              setState(() {
                                _selectedCategory = null;
                              });
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              _selectedCategory == null
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _selectedCategory == null
                                  ? const Color.fromARGB(255, 96, 156, 101)
                                  : Colors.grey,
                            ),
                            title: const Text('All Categories'),
                            onTap: () {
                              setModalState(() {
                                _selectedCategory = null;
                              });
                              setState(() {
                                _selectedCategory = null;
                              });
                              Navigator.pop(context);
                            },
                          ),
                          ..._categories.map((category) {
                            final isSelected = _selectedCategory == category;
                            return ListTile(
                              leading: Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? const Color.fromARGB(255, 96, 156, 101)
                                    : Colors.grey,
                              ),
                              title: Text(category),
                              onTap: () {
                                setModalState(() {
                                  _selectedCategory = category;
                                });
                                setState(() {
                                  _selectedCategory = category;
                                });
                                Navigator.pop(context);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        // Compact Filter Bar
        Container(
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Filter Button
                Material(
                  color: _selectedCategory != null
                      ? const Color.fromARGB(255, 96, 156, 101)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _showCategoryFilterMenu(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedCategory != null
                              ? const Color.fromARGB(255, 96, 156, 101)
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 20,
                            color: _selectedCategory != null
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCategory ?? 'Category',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedCategory != null
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: _selectedCategory != null
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Compact Search Bar
                Expanded(
                  child: TextField(
                    controller: _areaSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search area...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      suffixIcon: _areaSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _areaSearchController.clear();
                                setState(() {
                                  _areaSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 96, 156, 101),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (value) {
                      setState(() {
                        _areaSearchQuery = value;
                      });
                    },
                  ),
                ),

                // Clear All Button (only show when filters active)
                if (_selectedCategory != null || _areaSearchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Clear all filters',
                      color: Colors.grey.shade700,
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                          _areaSearchQuery = '';
                          _areaSearchController.clear();
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Active Filters Chips (if any)
        if (_selectedCategory != null || _areaSearchQuery.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade50,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selectedCategory != null)
                  Chip(
                    label: Text(_selectedCategory!),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                    backgroundColor: const Color.fromARGB(
                      255,
                      96,
                      156,
                      101,
                    ).withOpacity(0.1),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 96, 156, 101),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                if (_areaSearchQuery.isNotEmpty)
                  Chip(
                    label: Text('Area: $_areaSearchQuery'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      _areaSearchController.clear();
                      setState(() {
                        _areaSearchQuery = '';
                      });
                    },
                    backgroundColor: const Color.fromARGB(
                      255,
                      96,
                      156,
                      101,
                    ).withOpacity(0.1),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 96, 156, 101),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Issues',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color.fromARGB(255, 96, 156, 101),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('status', isEqualTo: 'submitted ')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _matchesFilters(data);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No verified issues yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Once reports are verified they will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Results count
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.white,
                      child: Text(
                        '${filteredDocs.length} issue${filteredDocs.length != 1 ? 's' : ''} found',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Issues list
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_off,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No issues match your filters',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredDocs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final data =
                                    filteredDocs[index].data()
                                        as Map<String, dynamic>;
                                final docId = filteredDocs[index].id;
                                final category =
                                    data['category'] as String? ?? '';
                                final description =
                                    data['description'] as String? ?? '';
                                final location =
                                    data['exactLocation'] as String? ?? '';
                                final timestamp = data['createdAt'];
                                DateTime? dateTime;
                                if (timestamp is Timestamp)
                                  dateTime = timestamp.toDate();
                                final imageBase64 =
                                    data['imageBase64Thumbnail'] as String? ??
                                    '';

                                Widget leading;
                                if (imageBase64.isNotEmpty) {
                                  try {
                                    final bytes = base64Decode(imageBase64);
                                    leading = ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        bytes,
                                        width: 100,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  } catch (_) {
                                    leading = Container(
                                      width: 100,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey.shade500,
                                      ),
                                    );
                                  }
                                } else {
                                  leading = Container(
                                    width: 100,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.grey.shade500,
                                    ),
                                  );
                                }

                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              IssueDetailScreen(
                                                issueData: data,
                                                docId: docId,
                                              ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Category and Description
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                category,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: 8.0,
                                          ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: 180,
                                            child: leading,
                                          ),
                                        ),
                                        // Location and Time
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 16,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      location,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey
                                                            .shade700,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              if (dateTime != null)
                                                Text(
                                                  _getRelativeTime(dateTime),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
