import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/profile/dropshipping_products_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/dashboard_screen.dart';
import '../screens/orders/orders_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/auth/login_screen.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class AppDrawer extends StatelessWidget {
  final String current; // e.g., 'profile', 'pointer'

  const AppDrawer({Key? key, required this.current}) : super(key: key);

  bool _is(String key) => current == key;

  String _getInitials(User user) {
    if (user.firstName != null && user.lastName != null) {
      return '${user.firstName![0].toUpperCase()}${user.lastName![0].toUpperCase()}';
    } else if (user.firstName != null && user.firstName!.isNotEmpty) {
      return user.firstName![0].toUpperCase();
    } else if (user.username.isNotEmpty) {
      return user.username[0].toUpperCase();
    } else if (user.email.isNotEmpty) {
      return user.email[0].toUpperCase();
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Drawer(
      elevation: 0,
      backgroundColor: const Color(0xFF1A1D24),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // User Profile Section
            if (user != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 50, bottom: 20),
                child: Column(
                  children: [
                    // Avatar with green border
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          _getInitials(user),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF8C00), // Orange-yellow color
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // User Name
                    Text(
                      user.fullName.isNotEmpty ? user.fullName : 'System user',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // User Email
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              // Separator
              Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.grey[700],
                indent: 20,
                endIndent: 20,
              ),
            ] else ...[
              // If not logged in, show placeholder
              Padding(
                padding: const EdgeInsets.only(top: 50, bottom: 20),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.grey[800],
                        child: const Text(
                          'U',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF8C00),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Guest User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Not logged in',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.grey[700],
                indent: 20,
                endIndent: 20,
              ),
            ],
            // Navigation Links
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _tile(
                    context,
                    icon: Icons.home_outlined,
                    label: 'Home',
                    selected: _is('home'),
                    onTap: () {
                      if (_is('home')) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    selected: _is('dashboard'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'Pointer Products',
                    selected: _is('pointer'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const DropshippingProductsScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Orders',
                    selected: _is('orders'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrdersListScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.person_outline,
                    label: 'Profile',
                    selected: _is('profile'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    selected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WalletScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Logout Button
            if (user != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C00), // Orange
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.arrow_forward, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? Colors.orange.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: selected ? Colors.orange : Colors.white,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: selected ? Colors.orange : Colors.white,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
