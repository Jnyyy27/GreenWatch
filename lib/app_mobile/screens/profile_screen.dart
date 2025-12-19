import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'my_reports_screen.dart';
import 'notification_screen.dart'; // Ensure notification_screen.dart exists in the same folder

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // The specific green from your Green Watch theme
  final Color _primaryGreen = const Color.fromARGB(255, 114, 164, 117);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header Section (Green Background with User Info + Notification Bell)
            _buildHeader(context, user),

            // 2. Stats Dashboard (Overlapping Card)
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStatsCard(),
              ),
            ),

            // 3. Menu Options (Account, Community, etc.)
            _buildMenuItems(context),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildHeader(BuildContext context, User? user) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 60, bottom: 50, left: 20, right: 20),
          decoration: BoxDecoration(
            color: _primaryGreen,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .get(),
            builder: (context, snapshot) {
              String displayName = "Loading...";
              String displayEmail = user?.email ?? "";

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                displayName = data['name'] ?? "User";
              } else if (snapshot.hasError) {
                displayName = "User";
              }

              return Column(
                children: [
                  // Profile Avatar with Custom Image
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      // Load the local asset image here
                      backgroundImage: AssetImage('assets/images/greenwatch.png'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Welcome Text
                  Text(
                    "Welcome, $displayName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    displayEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              );
            },
          ),
        ),
        
        // --- BELL ICON (Top Right) ---
        Positioned(
          top: 40, // Adjust for safe area
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            tooltip: 'Notifications',
            onPressed: () {
              // Navigate to the Notification Screen
              // FIX: Removed 'const' keyword here to prevent build error
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
    );
  }

  Widget _buildStatsCard() {
    // Note: In a real app, you would wrap this in a StreamBuilder to fetch real counts
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem("Total", "0", Colors.black87),
          _buildVerticalDivider(),
          _buildStatItem("Pending", "0", Colors.orange),
          _buildVerticalDivider(),
          _buildStatItem("Resolved", "0", _primaryGreen),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }

  Widget _buildMenuItems(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Account & Reports",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          _buildMenuTile(
            icon: Icons.history_edu,
            title: "My Reports",
            subtitle: "Check status of submitted issues",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyReportsScreen()),
              );
            },
          ),

          const SizedBox(height: 20),
          const Text(
            "Community & Support",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          _buildMenuTile(
            icon: Icons.menu_book_outlined,
            title: "User Guidelines",
            subtitle: "How to use Green Watch",
            onTap: () {
              _showGuidelines(context);
            },
          ),

          const SizedBox(height: 20),

          // LOGOUT BUTTON
          _buildMenuTile(
            icon: Icons.logout,
            title: "Logout",
            subtitle: "Sign out of your account",
            isDestructive: true,
            onTap: () async {
              // Sign out and let main.dart handle the redirect to Login
              await AuthService().signOut();
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red[50]
                : _primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isDestructive ? Colors.red : _primaryGreen),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  void _showGuidelines(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "User Guidelines",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              const ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text("Take Clear Photos"),
                subtitle: Text(
                  "Ensure the issue is clearly visible for AI verification.",
                ),
              ),
              const ListTile(
                leading: Icon(Icons.location_on),
                title: Text("Check Location"),
                subtitle: Text(
                  "GPS tagging helps authorities find the issue fast.",
                ),
              ),
              const ListTile(
                leading: Icon(Icons.category),
                title: Text("Select Category"),
                subtitle: Text(
                  "Choose the correct issue type (e.g., Pothole, Trash).",
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
