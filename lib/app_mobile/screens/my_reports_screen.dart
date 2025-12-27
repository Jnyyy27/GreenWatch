import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

// --- Enhanced Theme Constants ---
const kPrimaryColor = Color.fromARGB(255, 76, 175, 80); // Green 500
const kPrimaryLight = Color(0xFFA5D6A7); // Green 200
const kPrimaryDark = Color(0xFF388E3C); // Green 700
const kBackgroundColor = Color(0xFFF8FAFC); // Slate 50
const kCardBackground = Color(0xFFFFFFFF);
const kTextPrimary = Color(0xFF0F172A); // Slate 900
const kTextSecondary = Color(0xFF64748B); // Slate 500
const kTextTertiary = Color(0xFF94A3B8); // Slate 400
const kBorderColor = Color(0xFFE2E8F0); // Slate 200
const kShadowColor = Color(0x0D000000);

// ---------------------------------------------------------
// SCREEN 1: LIST OF REPORTS - ENHANCED
// ---------------------------------------------------------
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 70,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kBorderColor.withOpacity(0),
                  kBorderColor,
                  kBorderColor.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: user == null
          ? _buildLoginPrompt()
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildError(snapshot.error.toString());
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: kPrimaryColor,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading reports...',
                          style: TextStyle(
                            color: kTextSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return _buildEmptyState();

                // Manual sort by createdAt descending
                final sortedDocs = [...docs];
                sortedDocs.sort((a, b) {
                  final tsA = (a.data() as Map)['createdAt'] as Timestamp?;
                  final tsB = (b.data() as Map)['createdAt'] as Timestamp?;
                  return (tsB?.toDate() ?? DateTime.now())
                      .compareTo(tsA?.toDate() ?? DateTime.now());
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          Icon(Icons.assignment_outlined, 
                            size: 20, 
                            color: kTextSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${sortedDocs.length} ${sortedDocs.length == 1 ? 'Report' : 'Reports'}',
                            style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: sortedDocs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final data = sortedDocs[index].data() as Map<String, dynamic>;
                          return _ReportCard(data: data);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: kShadowColor,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Login Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to view your reports',
              style: TextStyle(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 56,
              color: kPrimaryColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Reports Yet',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your submitted reports will appear here',
            style: TextStyle(
              color: kTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    
    return Container(
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: kShadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReportDetailScreen(data: data)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(data['imageBase64Thumbnail']),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['category'] ?? 'General Issue',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: kTextPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: kPrimaryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data['exactLocation'] ?? 'Unknown Location',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: kTextSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: kTextTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(createdAt),
                                  style: TextStyle(
                                    color: kTextTertiary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatusChip(status: data['status'] ?? 'Submitted'),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: kTextTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? base64) {
    Uint8List? bytes;
    if (base64 != null && base64.isNotEmpty) {
      try {
        bytes = base64Decode(base64);
      } catch (_) {
        bytes = null;
      }
    }

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _imageFallback(),
              )
            : _imageFallback(),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: kPrimaryColor.withOpacity(0.05),
      child: Icon(
        Icons.image_outlined,
        color: kPrimaryColor.withOpacity(0.4),
        size: 32,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

// ---------------------------------------------------------
// SCREEN 2: REPORT DETAILS - ENHANCED
// ---------------------------------------------------------
class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const ReportDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final reportId = data['reportId'];
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final base64Thumb = data['imageBase64Thumbnail'] as String?;
    Uint8List? thumbBytes;
    if (base64Thumb != null && base64Thumb.isNotEmpty) {
      try {
        thumbBytes = base64Decode(base64Thumb);
      } catch (_) {
        thumbBytes = null;
      }
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            elevation: 0,
            backgroundColor: kCardBackground,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: kTextPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _heroImageFallback(thumbBytes),
                    )
                  else if (thumbBytes != null)
                    Image.memory(
                      thumbBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _heroImageFallback(null),
                    )
                  else
                    _heroImageFallback(null),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: kCardBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusChip(status: data['status'] ?? 'Submitted', large: true),
                        const SizedBox(height: 20),
                        Text(
                          data['category'] ?? 'Issue Details',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          text: data['exactLocation'] ?? 'Location not specified',
                        ),
                        if (data['createdAt'] != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            text: DateFormat('MMMM d, yyyy • h:mm a')
                                .format((data['createdAt'] as Timestamp).toDate()),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 8,
                    color: kBackgroundColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader("DESCRIPTION"),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: Text(
                            data['description'] ?? 'No description provided.',
                            style: const TextStyle(
                              fontSize: 15,
                              color: kTextPrimary,
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 8,
                    color: kBackgroundColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader("TRACKING TIMELINE"),
                        const SizedBox(height: 24),
                        _ModernTimeline(reportId: reportId),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: kPrimaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

Widget _heroImageFallback(Uint8List? thumbBytes) {
  if (thumbBytes != null) {
    return Image.memory(
      thumbBytes,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _heroGradientPlaceholder(),
    );
  }
  return _heroGradientPlaceholder();
}

Widget _heroGradientPlaceholder() {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          kPrimaryColor.withOpacity(0.12),
          kPrimaryColor.withOpacity(0.05),
        ],
      ),
    ),
    child: Icon(
      Icons.broken_image_outlined,
      size: 64,
      color: kPrimaryColor.withOpacity(0.3),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: kPrimaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// COMPONENTS: TIMELINE & CHIPS - ENHANCED
// ---------------------------------------------------------
class _ModernTimeline extends StatelessWidget {
  final String? reportId;
  const _ModernTimeline({this.reportId});

  @override
  Widget build(BuildContext context) {
    if (reportId == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: kTextSecondary),
            const SizedBox(width: 12),
            Text(
              "Timeline unavailable",
              style: TextStyle(color: kTextSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .collection('timeline')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 48,
                  color: kTextTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  "Waiting for first update...",
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final entry = docs[index].data() as Map<String, dynamic>;
            final isFirst = index == 0;
            final isLast = index == docs.length - 1;
            final DateTime? dt = (entry['timestamp'] as Timestamp?)?.toDate();

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isFirst ? kPrimaryColor : kCardBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst ? kPrimaryColor : kBorderColor,
                            width: isFirst ? 3 : 2,
                          ),
                          boxShadow: isFirst
                              ? [
                                  BoxShadow(
                                    color: kPrimaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  kBorderColor,
                                  kBorderColor.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isFirst
                            ? kPrimaryColor.withOpacity(0.05)
                            : kBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFirst
                              ? kPrimaryColor.withOpacity(0.2)
                              : kBorderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  entry['action'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: isFirst ? kPrimaryDark : kTextPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (dt != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kCardBackground,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: kBorderColor),
                                  ),
                                  child: Text(
                                    DateFormat('MMM d, h:mm a').format(dt),
                                    style: TextStyle(
                                      color: kTextSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (entry['notes'] != null &&
                              entry['notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              entry['notes'] ?? '',
                              style: TextStyle(
                                color: kTextSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
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
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool large;
  const _StatusChip({required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFF3B82F6); // Blue
    IconData icon = Icons.pending_outlined;
    
    String s = status.toLowerCase();
    if (s.contains('resolved') || s.contains('completed')) {
      color = kPrimaryColor;
      icon = Icons.check_circle_outline;
    } else if (s.contains('progress') || s.contains('processing')) {
      color = const Color(0xFFF59E0B); // Amber
      icon = Icons.sync_outlined;
    } else if (s.contains('viewed') || s.contains('reviewed')) {
      color = const Color(0xFF6366F1); // Indigo
      icon = Icons.visibility_outlined;
    } else if (s.contains('rejected') || s.contains('cancelled')) {
      color = const Color(0xFFEF4444); // Red
      icon = Icons.cancel_outlined;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 10 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: large ? 16 : 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: large ? 12 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
