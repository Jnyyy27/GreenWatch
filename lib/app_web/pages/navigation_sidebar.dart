import 'package:flutter/material.dart';
import 'login_page.dart';

class NavigationSidebar extends StatelessWidget {
  final String department;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const NavigationSidebar({
    required this.department,
    required this.selectedIndex,
    required this.onItemSelected,
    super.key,
  });

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = [
      ('Dashboard', Icons.home, 0),
      ('Report Queue', Icons.assignment, 1),
      ('Announcements', Icons.notifications, 2),
      ('Community', Icons.public, 3),
      ('Analytics', Icons.analytics, 4),
      ('Settings', Icons.settings, 5),
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Placeholder for department logo/image
                // Container(
                //   width: 48,
                //   height: 48,
                //   decoration: BoxDecoration(
                //     color: const Color(0xFFF5F5F5),
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(color: Colors.grey.shade300, width: 1),
                //   ),
                //   // child: Icon(
                //   //   Icons.apartment,
                //   //   color: Colors.grey.shade400,
                //   //   size: 24,
                //   // ),
                // ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        department,
                        style: const TextStyle(
                          color: Color(0xFF1a1a1a),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Department Portal',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final (label, icon, _) = navItems[index];
                final isSelected = selectedIndex == index;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8F5E9)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Icon(
                      icon,
                      color: isSelected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF424242),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    onTap: () => onItemSelected(index),
                    hoverColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
            ),
          ),

          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
