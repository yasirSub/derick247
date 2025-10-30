import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../screens/profile/dropshipping_products_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/vendor_products_screen.dart';
import '../screens/profile/dashboard_screen.dart';

class AppDrawer extends StatelessWidget {
  final String current; // e.g., 'profile', 'pointer'

  const AppDrawer({Key? key, required this.current}) : super(key: key);

  bool _is(String key) => current == key;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'Menu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _tile(
                    context,
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    selected: _is('dashboard'),
                    onTap: () {
                      if (_is('dashboard')) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.shopping_cart_outlined,
                    label: 'Products',
                    selected: _is('vendor'),
                    onTap: () {
                      if (_is('vendor')) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VendorProductsScreen(),
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
                      if (_is('pointer')) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DropshippingProductsScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Orders',
                    selected: false,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Orders coming soon!')),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.person_outline,
                    label: 'Profile',
                    selected: _is('profile'),
                    onTap: () {
                      if (_is('profile')) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pop(context);
                      Navigator.pushReplacement(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wallet coming soon!')),
                      );
                    },
                  ),
                  const Divider(),
                  _tile(
                    context,
                    icon: Icons.settings,
                    label: 'Settings',
                    selected: false,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings coming soon!')),
                      );
                    },
                  ),
                ],
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
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.orange : Colors.black54),
      title: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.fontSizeMedium,
          color: selected ? Colors.orange : AppTheme.textColor,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
