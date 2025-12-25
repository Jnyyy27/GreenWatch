import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'my_reports_screen.dart';
import 'notification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  // Enhanced Color Palette based on Color(255, 76, 175, 80)
  static const Color kPrimaryGreen = Color(0xFF4CAF50); // Main theme color
  static const Color kPrimaryLight = Color(0xFF81C784); // Light green
  static const Color kPrimaryDark = Color(0xFF388E3C); // Dark green
  static const Color kAccentGreen = Color(0xFF66BB6A); // Accent
  static const Color kBackgroundGray = Color(0xFFF8F9FA);
  static const Color kCardWhite = Color(0xFFFFFFFF);
  static const Color kTextPrimary = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Color(0xFF6B7280);
  static const Color kBorderColor = Color(0xFFE5E7EB);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  String? _localName;
  Uint8List? _localAvatarBytes;
  bool _loadingLocal = true;

  Color get kPrimaryGreen => ProfileScreen.kPrimaryGreen;
  Color get kPrimaryLight => ProfileScreen.kPrimaryLight;
  Color get kPrimaryDark => ProfileScreen.kPrimaryDark;
  Color get kAccentGreen => ProfileScreen.kAccentGreen;
  Color get kBackgroundGray => ProfileScreen.kBackgroundGray;
  Color get kCardWhite => ProfileScreen.kCardWhite;
  Color get kTextPrimary => ProfileScreen.kTextPrimary;
  Color get kTextSecondary => ProfileScreen.kTextSecondary;
  Color get kBorderColor => ProfileScreen.kBorderColor;

  @override
  void initState() {
    super.initState();
    _loadLocalProfile();
  }

  Future<void> _loadLocalProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loadingLocal = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('profile_name_${user.uid}');
    final savedPhoto = prefs.getString('profile_photo_${user.uid}');
    Uint8List? photoBytes;
    if (savedPhoto != null) {
      try {
        photoBytes = base64Decode(savedPhoto);
      } catch (_) {
        photoBytes = null;
      }
    }

    setState(() {
      _localName = savedName;
      _localAvatarBytes = photoBytes;
      _loadingLocal = false;
    });
  }

  Future<void> _updateLocalName(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name_${user.uid}', name);
    setState(() {
      _localName = name;
    });
  }

  Future<void> _pickNewPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_photo_${user.uid}', base64Encode(bytes));

    setState(() {
      _localAvatarBytes = bytes;
    });
  }

  void _showPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View photo'),
                enabled: _localAvatarBytes != null,
                onTap: _localAvatarBytes == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _viewCurrentPhoto();
                      },
              ),
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: const Text('Upload new photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickNewPhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewCurrentPhoto() {
    if (_localAvatarBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              child: Image.memory(
                _localAvatarBytes!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptEditName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      await _updateLocalName(newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBackgroundGray,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Enhanced Header with User Info
            _buildHeader(context, user),

            // 2. Stats Dashboard (Overlapping)
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStatsSection(user),
              ),
            ),

            // 3. Menu Options
            _buildMenuItems(context),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildHeader(BuildContext context, User? user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryGreen, kPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimaryGreen.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: -40,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            
            // Main content
            Column(
              children: [
                // Top bar with title and notification
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Stack(
                            children: [
                              const Icon(Icons.notifications_outlined, 
                                color: Colors.white, 
                                size: 24,
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          tooltip: 'Notifications',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotificationScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // User Avatar and Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
                  child: FutureBuilder<DocumentSnapshot>(
                    future: user == null
                        ? null
                        : FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get(),
                    builder: (context, snapshot) {
                      final displayEmail = user?.email ?? "";
                      String fetchedName = "User";
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        fetchedName = (data['name'] as String?)?.trim().isNotEmpty == true
                            ? data['name']
                            : "User";
                      }

                      String resolvedName = _localName ?? fetchedName;
                      if (_localName == null &&
                          user != null &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        resolvedName = "Loading...";
                      }

                      final avatarProvider = _localAvatarBytes != null
                          ? MemoryImage(_localAvatarBytes!)
                          : const AssetImage('assets/images/greenwatch.png') as ImageProvider;

                      return Column(
                        children: [
                          SizedBox(
                            width: 116,
                            height: 116,
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.white.withOpacity(0.8),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: kCardWhite,
                                      ),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: kBackgroundGray,
                                        backgroundImage: avatarProvider,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Material(
                                    color: kPrimaryGreen,
                                    shape: const CircleBorder(),
                                    elevation: 4,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: user == null
                                          ? null
                                          : () => _showPhotoOptions(context),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  resolvedName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (user != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                  tooltip: 'Edit name',
                                  onPressed: () => _promptEditName(resolvedName),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    displayEmail,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required int totalCount,
    required int inProgressCount,
    required int resolvedCount,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: kPrimaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Report Statistics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "Total",
                  isLoading ? "..." : totalCount.toString(),
                  kPrimaryGreen,
                  Icons.assignment_outlined,
                ),
              ),
              Container(
                height: 60,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kBorderColor.withOpacity(0),
                      kBorderColor,
                      kBorderColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  "inProgress",
                  isLoading ? "..." : inProgressCount.toString(),
                  Color(0xFFFB8C00),
                  Icons.pending_outlined,
                ),
              ),
              Container(
                height: 60,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kBorderColor.withOpacity(0),
                      kBorderColor,
                      kBorderColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  "Resolved",
                  isLoading ? "..." : resolvedCount.toString(),
                  kAccentGreen,
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: kTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(User? user) {
    if (user == null) {
      return _buildStatsCard(
        totalCount: 0,
        inProgressCount: 0,
        resolvedCount: 0,
        isLoading: false,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        int inProgress = 0;
        int resolved = 0;

        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] as String? ?? '').toLowerCase();
            if (status == 'resolved') {
              resolved += 1;
            } else {
              // Treat all non-resolved statuses as inProgress/in progress buckets
              inProgress += 1;
            }
          }
        }

        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        return _buildStatsCard(
          totalCount: total,
          inProgressCount: inProgress,
          resolvedCount: resolved,
          isLoading: isLoading,
        );
      },
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _menuSectionTitle("Account & Reports"),
          const SizedBox(height: 12),
          _buildMenuTile(
            icon: Icons.description_outlined,
            title: "My Reports",
            subtitle: "Track your submitted issues",
            iconColor: kPrimaryGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyReportsScreen()),
              );
            },
          ),
          
          const SizedBox(height: 24),
          _menuSectionTitle("Support"),
          const SizedBox(height: 12),
          _buildMenuTile(
            icon: Icons.menu_book_outlined,
            title: "User Guidelines",
            subtitle: "Learn how to use Green Watch",
            iconColor: kAccentGreen,
            onTap: () {
              _showGuidelines(context);
            },
          ),
          const SizedBox(height: 24),
          _menuSectionTitle("Settings"),
          const SizedBox(height: 12),
          _buildMenuTile(
            icon: Icons.logout_rounded,
            title: "Logout",
            subtitle: "Sign out of your account",
            iconColor: Color(0xFFEF5350),
            isDestructive: true,
            onTap: () async {
              await AuthService().signOut();
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _menuSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: kTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDestructive 
            ? Color(0xFFEF5350).withOpacity(0.2)
            : kBorderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDestructive ? Color(0xFFEF5350) : kTextPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: kTextSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: kTextSecondary.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuidelines(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: kCardWhite,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kPrimaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: kPrimaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          "User Guidelines",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildGuidelineItem(
                      icon: Icons.category_outlined,
                      title: "Pick Issue Category",
                      description: "Choose the right issue type so it reaches the correct department.",
                      color: kAccentGreen,
                    ),
                    const SizedBox(height: 16),
                    _buildGuidelineItem(
                      icon: Icons.location_on_outlined,
                      title: "Pin Location",
                      description: "Use GPS if you are there; use Search Map if reporting another spot.",
                      color: kPrimaryGreen,
                    ),
                    const SizedBox(height: 16),
                    _buildGuidelineItem(
                      icon: Icons.camera_alt_outlined,
                      title: "Add Details and a Photo",
                      description: "Short description plus one clear photo (required) before submitting.",
                      color: kPrimaryLight,
                    ),
                    const SizedBox(height: 16),
                    _buildGuidelineItem(
                      icon: Icons.notifications_active_outlined,
                      title: "Submit and Track",
                      description: "Submit, then watch status updates. You’ll get notified when authorities update it.",
                      color: kPrimaryDark,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuidelineItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBackgroundGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: kTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
