import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/profile/dropshipping_products_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/dashboard_screen.dart';
import '../screens/profile/vendor_products_screen.dart';
import '../screens/orders/orders_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../providers/locale_provider.dart';
import '../services/translation_service.dart';

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
    // Listen to TranslationService for updates when language changes
    // Also listen to LocaleProvider to ensure rebuild when locale changes
    Provider.of<LocaleProvider>(
      context,
      listen: true,
    ); // Force rebuild on locale change
    final translationService = Provider.of<TranslationService>(
      context,
      listen: true,
    );

    return Drawer(
      elevation: 0,
      backgroundColor: const Color(0xFF1A1D24),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF1A1D24)),
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
                        border: Border.all(color: Colors.green, width: 2),
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
                      user.fullName.isNotEmpty
                          ? user.fullName
                          : translationService.translate('app.systemUser'),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
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
                        border: Border.all(color: Colors.green, width: 2),
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
                    Text(
                      translationService.translate('app.guestUser'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      translationService.translate('app.notLoggedIn'),
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
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
                    label: translationService.translate('app.home'),
                    selected: _is('home'),
                    onTap: () {
                      if (_is('home')) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.dashboard_outlined,
                    label: translationService.translate('app.dashboard'),
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
                    label: translationService.translate('app.products'),
                    selected: _is('vendor'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
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
                    label: translationService.translate('app.mines'),
                    selected: _is('pointer'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
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
                    label: translationService.translate('app.orders'),
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
                    label: translationService.translate('app.profile'),
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
                    label: translationService.translate('app.wallet'),
                    selected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.language_outlined,
                    label: translationService.translate('app.language'),
                    selected: _is('language'),
                    onTap: () {
                      Navigator.pop(context);
                      _showLanguageDialog(context);
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
                    final navigator = Navigator.of(
                      context,
                      rootNavigator: true,
                    );
                    Navigator.pop(context);
                    await authProvider.logout();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => HomeScreen(forceRefresh: true),
                      ),
                      (_) => false,
                    );
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
                    children: [
                      const Icon(Icons.arrow_forward, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        translationService.translate('app.logout'),
                        style: const TextStyle(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) async {
    final languages = ['English', 'Spanish'];
    final storageService = StorageService();
    final currentLanguage =
        await storageService.getUserPreference<String>('language') ?? 'English';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _LanguageDialogContent(
        languages: languages,
        currentLanguage: currentLanguage,
        storageService: storageService,
      ),
    );
  }
}

class _LanguageDialogContent extends StatefulWidget {
  final List<String> languages;
  final String currentLanguage;
  final StorageService storageService;

  const _LanguageDialogContent({
    Key? key,
    required this.languages,
    required this.currentLanguage,
    required this.storageService,
  }) : super(key: key);

  @override
  State<_LanguageDialogContent> createState() => _LanguageDialogContentState();
}

class _LanguageDialogContentState extends State<_LanguageDialogContent> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D24),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Consumer<TranslationService>(
            builder: (context, translationService, child) {
              return Text(
                translationService.translate('app.selectLanguage'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ...widget.languages
              .map(
                (language) => Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RadioListTile<String>(
                    title: Text(
                      language,
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: language,
                    groupValue: _selectedLanguage,
                    onChanged: (value) {
                      if (value == null) return;
                      final localeProvider = Provider.of<LocaleProvider>(
                        context,
                        listen: false,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        await localeProvider.setLanguage(value);
                        if (!mounted) return;
                        setState(() {
                          _selectedLanguage = value;
                        });
                        Navigator.pop(context);
                        final translationService =
                            Provider.of<TranslationService>(
                              context,
                              listen: false,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${translationService.translate('app.languageChanged')} $value',
                            ),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        // Navigate to home and refresh
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      });
                    },
                    activeColor: Colors.orange,
                    selectedTileColor: Colors.orange.withOpacity(0.1),
                  ),
                ),
              )
              .toList(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
