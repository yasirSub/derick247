import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../screens/profile/dropshipping_products_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/dashboard_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/orders/orders_list_screen.dart';
import '../screens/home/home_screen.dart';

class AppDrawer extends StatelessWidget {
  final String current; // e.g., 'profile', 'pointer'

  const AppDrawer({Key? key, required this.current}) : super(key: key);

  bool _is(String key) => current == key;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            margin: EdgeInsets.only(top: kToolbarHeight + 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  blurRadius: 32,
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(8, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 27,
                        color: Colors.black54,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close menu',
                      splashRadius: 22,
                      padding: const EdgeInsets.only(top: 4, right: 7),
                    ),
                  ],
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
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
                          if (_is('orders')) {
                            Navigator.pop(context);
                            return;
                          }
                          Navigator.pop(context);
                          Navigator.pushReplacement(
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
                          if (_is('profile')) {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
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
                            const SnackBar(
                              content: Text('Wallet coming soon!'),
                            ),
                          );
                        },
                      ),
                      _tile(
                        context,
                        icon: Icons.favorite_border,
                        label: 'Wishlist',
                        selected: false,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Wishlist coming soon!'),
                            ),
                          );
                        },
                      ),
                      _tile(
                        context,
                        icon: Icons.notifications_none_outlined,
                        label: 'Notifications',
                        selected: false,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notifications coming soon!'),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        height: 18,
                        thickness: 0.5,
                        indent: 10,
                        endIndent: 10,
                      ),
                      _tile(
                        context,
                        icon: Icons.settings,
                        label: 'Settings',
                        selected: false,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _tile(
                        context,
                        icon: Icons.help_outline,
                        label: 'Help & Support',
                        selected: false,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Help & Support coming soon!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 210),
      curve: Curves.ease,
      decoration: BoxDecoration(
        color: selected ? Colors.orange.withOpacity(0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        minVerticalPadding: 5,
        minLeadingWidth: 28,
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Icon(
            icon,
            color: selected ? Colors.orange : Colors.black54,
            size: 18,
            key: ValueKey(selected),
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: selected ? Colors.orange : AppTheme.textColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        //splashColor: Colors.orange.withOpacity(0.15),
        selected: false, // handled above
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 0),
        horizontalTitleGap: 8,
        visualDensity: const VisualDensity(vertical: -2.1, horizontal: -1.2),
      ),
    );
  }
}
