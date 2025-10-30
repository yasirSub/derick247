import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_app_bar.dart';
import '../home/home_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  Future<bool> _onWillPop(BuildContext context) async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        drawer: const AppDrawer(current: 'dashboard'),
        appBar: CustomAppBar(
          title: 'Dashboard',
          isDark: true,
          actions: [], // Force no profile icon or any actions
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat cards row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _statCard('Products', '128', Icons.shopping_bag, Colors.blue)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Pointers', '42', Icons.pin_drop, Colors.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Orders', '67', Icons.receipt_long, Colors.orange)),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                // Sales progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sales This Month', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(
                      '68%',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.68,
                    minHeight: 13,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                // Dummy recent activity
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.shopping_cart, color: Colors.blue)),
                        title: Text('New order from John Doe'),
                        trailing: Text('10 min ago', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.star, color: Colors.orange)),
                        title: Text('Product "Headphone X" rated 5★'),
                        trailing: Text('40 min ago', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(Icons.person_add, color: Colors.green)),
                        title: Text('Pointer Alexander joined'),
                        trailing: Text('1 hr ago', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.purple.shade50, child: Icon(Icons.edit_note, color: Colors.purple)),
                        title: Text('Product "Phone Z" updated'),
                        trailing: Text('3 hr ago', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.17),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
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
