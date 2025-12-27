import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:green_watch/app_mobile/screens/issue_detail_screen.dart';
import 'package:green_watch/app_mobile/screens/resolved_issue_detail_screen.dart';
import 'package:green_watch/services/report_service.dart';

class IssuesScreen extends StatefulWidget {
  final bool startResolved;

  const IssuesScreen({super.key, this.startResolved = false});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

enum _SortOption { mostUpvoted, newest }

class _IssuesScreenState extends State<IssuesScreen> {
  String? _selectedCategory;
  String _areaSearchQuery = '';
  final TextEditingController _areaSearchController = TextEditingController();
  final ReportService _reportService = ReportService();
  final Set<String> _upvoteInProgress = {};
  bool _showResolvedIssues = false;
  bool _sortByMostUpvoted = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _showResolvedIssues = widget.startResolved;
    _pageController = PageController(initialPage: widget.startResolved ? 1 : 0);
  }

  String get _engagementAction => _showResolvedIssues ? 'like' : 'upvote';

  String get _sortChipLabel =>
      _showResolvedIssues ? 'Most liked' : 'Most upvoted';

  String _engagementCountLabel(int count) {
    final singular = _showResolvedIssues ? 'like' : 'up';
    final plural = _showResolvedIssues ? 'likes' : 'ups';
    return '$count ${count == 1 ? singular : plural}';
  }

  final List<String> _categories = [
    'Damage roads',
    'Road potholes',
    'Road signs',
    'Faded road markings',
    'Traffic lights',
    'Streetlights',
    'Public facilities',
  ];

  // Helper method to get status color and icon
  Map<String, dynamic> _getStatusStyle(String status) {
    switch (status) {
      case 'Submitted':
        return {
          'color': const Color(0xFF2196F3), // Blue
          'icon': Icons.upload_file,
          'label': 'Submitted',
        };
      case 'Viewed':
        return {
          'color': const Color(0xFFFFC107), // Yellow/Amber
          'icon': Icons.visibility,
          'label': 'Viewed',
        };
      case 'In Progress':
        return {
          'color': const Color(0xFFFF9800), // Orange
          'icon': Icons.hourglass_empty,
          'label': 'In Progress',
        };
      case 'Resolved':
        return {
          'color': const Color(0xFF4CAF50), // Green
          'icon': Icons.check_circle,
          'label': 'Resolved',
        };
      default:
        return {
          'color': Colors.grey,
          'icon': Icons.help_outline,
          'label': 'Unknown',
        };
    }
  }

  // Build status chip widget
  Widget _buildStatusChip(String status) {
    final style = _getStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (style['color'] as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style['color'] as Color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style['icon'] as IconData,
            size: 14,
            color: style['color'] as Color,
          ),
          const SizedBox(width: 4),
          Text(
            style['label'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: style['color'] as Color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _areaSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _showResolvedIssues = page == 1;
    });
  }

  void _switchToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggleUpvote(String docId) async {
    if (_upvoteInProgress.contains(docId)) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please sign in to $_engagementAction issues.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _upvoteInProgress.add(docId);
    });

    try {
      await _reportService.toggleUpvote(docId, user.uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update $_engagementAction. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _upvoteInProgress.remove(docId);
        });
      }
    }
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
    final status = (data['status'] as String? ?? '');
    if (_showResolvedIssues) {
      if (status != 'Resolved') return false;
    } else {
      if (status == 'Resolved') return false;
    }

    if (_selectedCategory != null) {
      final category = data['category'] as String? ?? '';
      if (category != _selectedCategory) return false;
    }

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

  Widget _buildStatusToggleBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 210, 236, 210),
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  label: 'Active Issues',
                  isSelected: !_showResolvedIssues,
                  onTap: () => _switchToPage(0),
                ),
                _buildToggleButton(
                  label: 'Resolved Issues',
                  isSelected: _showResolvedIssues,
                  onTap: () => _switchToPage(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color.fromARGB(255, 96, 156, 101)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
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
                Material(
                  color: _sortByMostUpvoted
                      ? const Color.fromARGB(255, 96, 156, 101)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: PopupMenuButton<_SortOption>(
                    tooltip: 'Sort',
                    onSelected: (value) {
                      setState(() {
                        _sortByMostUpvoted = value == _SortOption.mostUpvoted;
                      });
                    },
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: _SortOption.mostUpvoted,
                        checked: _sortByMostUpvoted,
                        child: Text(_sortChipLabel),
                      ),
                      CheckedPopupMenuItem(
                        value: _SortOption.newest,
                        checked: !_sortByMostUpvoted,
                        child: const Text('Newest'),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _sortByMostUpvoted
                              ? const Color.fromARGB(255, 96, 156, 101)
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.filter_alt,
                        size: 20,
                        color: _sortByMostUpvoted
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _areaSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search by area',
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
                if (_selectedCategory != null ||
                    _areaSearchQuery.isNotEmpty ||
                    _sortByMostUpvoted)
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
                          _sortByMostUpvoted = false;
                          _areaSearchController.clear();
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedCategory != null ||
            _areaSearchQuery.isNotEmpty ||
            _sortByMostUpvoted)
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
                if (_sortByMostUpvoted)
                  Chip(
                    label: Text(_sortChipLabel),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _sortByMostUpvoted = false;
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

  Widget _buildIssuesList(bool isResolved) {
    CollectionReference<Map<String, dynamic>> collection = FirebaseFirestore
        .instance
        .collection('reports');
    Query<Map<String, dynamic>> query;
    if (isResolved) {
      query = collection.where('status', isEqualTo: 'Resolved');
    } else {
      query = collection.where(
        'status',
        whereIn: ['Submitted', 'Viewed', 'In Progress'],
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('createdAt', descending: true).snapshots(),

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

        if (_sortByMostUpvoted) {
          filteredDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final upvotesA = (dataA['likesCount'] is int)
                ? dataA['likesCount'] as int
                : (dataA['likesCount'] as num?)?.toInt() ?? 0;
            final upvotesB = (dataB['likesCount'] is int)
                ? dataB['likesCount'] as int
                : (dataB['likesCount'] as num?)?.toInt() ?? 0;
            if (upvotesA != upvotesB) {
              return upvotesB.compareTo(upvotesA);
            }

            final timestampA = dataA['createdAt'];
            final timestampB = dataB['createdAt'];
            DateTime? dateA;
            DateTime? dateB;
            if (timestampA is Timestamp) dateA = timestampA.toDate();
            if (timestampB is Timestamp) dateB = timestampB.toDate();

            if (dateA != null && dateB != null) {
              return dateB.compareTo(dateA);
            }

            return 0;
          });
        }

        final currentUser = FirebaseAuth.instance.currentUser;

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isResolved ? Icons.check_circle_outline : Icons.inbox,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isResolved
                        ? 'No resolved issues yet'
                        : 'No active issues yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isResolved
                        ? 'Once reports are resolved they will appear here.'
                        : 'Report an issue to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        if (filteredDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final docId = filteredDocs[index].id;
            final upvoteCount = (data['likesCount'] is int)
                ? data['likesCount'] as int
                : (data['likesCount'] as num?)?.toInt() ?? 0;
            final List<String> upvotedBy = data['likedBy'] is Iterable
                ? List<String>.from(data['likedBy'] as Iterable)
                : <String>[];
            final bool isUpvoted =
                currentUser != null && upvotedBy.contains(currentUser.uid);
            final bool upvoteLoading = _upvoteInProgress.contains(docId);
            final category = data['category'] as String? ?? '';
            final description = data['description'] as String? ?? '';
            final location = data['exactLocation'] as String? ?? '';
            final status = data['status'] as String? ?? 'Unknown';
            final timestamp = data['createdAt'];
            DateTime? dateTime;
            if (timestamp is Timestamp) dateTime = timestamp.toDate();
            final imageBase64 = data['imageBase64Thumbnail'] as String? ?? '';

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
                  child: Icon(Icons.broken_image, color: Colors.grey.shade500),
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
                child: Icon(Icons.image, color: Colors.grey.shade500),
              );
            }

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  if (status == 'Resolved') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResolvedIssueDetailScreen(
                          issueData: data,
                          docId: docId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            IssueDetailScreen(issueData: data, docId: docId),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Add padding to the right to avoid overlap with status chip
                              Padding(
                                padding: const EdgeInsets.only(right: 100),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: upvoteLoading
                                      ? null
                                      : () => _toggleUpvote(docId),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isUpvoted
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 22,
                                          color: isUpvoted
                                              ? const Color.fromARGB(
                                                  255,
                                                  220,
                                                  95,
                                                  95,
                                                )
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _engagementCountLabel(upvoteCount),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (upvoteLoading)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Status chip positioned at top right
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _buildStatusChip(status),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          _buildStatusToggleBar(),
          const SizedBox(height: 4),
          _buildFilterBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildIssuesList(false), // Active Issues
                _buildIssuesList(true), // Resolved Issues
              ],
            ),
          ),
        ],
      ),
    );
  }
}
