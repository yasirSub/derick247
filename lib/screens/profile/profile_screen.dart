import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme_config.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_app_bar.dart';
import '../../providers/auth_provider.dart';
import '../../services/translation_service.dart';
import '../../widgets/translated_text.dart';
import '../../models/user_model.dart';
import '../home/home_screen.dart';
import 'edit_profile_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh user profile data when screen loads to ensure location data is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfile();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning from edit screen to get updated vendor status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfile();
    });
  }

  Future<void> _refreshProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      print('🔄 [PROFILE] Refreshing profile data...');
      print('   → User logged in: ${authProvider.isLoggedIn}');
      print('   → Email verified: ${authProvider.isEmailVerified}');
      print('   → User email: ${authProvider.user?.email ?? "N/A"}');
      print(
        '   → email_verified_at: ${authProvider.user?.emailVerifiedAt ?? "N/A"}',
      );
      print(
        '   → Has Google ID: ${authProvider.user?.googleId != null && authProvider.user!.googleId!.isNotEmpty}',
      );

      // Force refresh from API to get latest data including location names and vendor status
      await authProvider.refreshUser();

      print('✅ [PROFILE] Profile refreshed successfully');
      print(
        '   → Email verified after refresh: ${authProvider.isEmailVerified}',
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ [PROFILE] Error refreshing profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        drawer: const AppDrawer(current: 'profile'),
        appBar: CustomAppBar(
          title: 'My Profile',
          isDark: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
              tooltip: 'Edit Profile',
            ),
          ],
        ),
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            print('👤 [PROFILE] Building profile screen:');
            print('   → User logged in: ${authProvider.isLoggedIn}');
            print('   → Email verified: ${authProvider.isEmailVerified}');
            print('   → Is loading: ${authProvider.isLoading}');

            if (authProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!authProvider.isLoggedIn) {
              print('   → User not logged in, showing login prompt');
              return _buildLoginPrompt();
            }

            final user = authProvider.user!;

            print('   → User data loaded:');
            print('      • Email: ${user.email}');
            print('      • Name: ${user.firstName} ${user.lastName}');
            print(
              '      • Email verified at: ${user.emailVerifiedAt ?? "N/A"}',
            );
            print('      • Google ID: ${user.googleId ?? "N/A"}');

            // Debug: Print location data
            print('📍 [PROFILE] Location Data:');
            print(
              '   → Country ID: ${user.countryId}, Country: ${user.country}',
            );
            print('   → State ID: ${user.stateId}, State: ${user.state}');
            print('   → City ID: ${user.cityId}, City: ${user.city}');
            print('   → Address: ${user.address}');

            // Debug: Print vendor status
            print('👤 [PROFILE] Vendor Status:');
            print('   → appliedForVendor: ${user.appliedForVendor}');
            print('   → role: ${user.role}');

            // Get permissions based on actual user vendor status (from API)
            // Show user_permissions if appliedForVendor is false
            // Show vendor_permission if appliedForVendor is true
            final displayPermissions = user.appliedForVendor
                ? user.vendorPermissions
                : user.userPermissions;

            return RefreshIndicator(
              onRefresh: () async {
                await authProvider.refreshUser();
                // Consumer will automatically rebuild when notifyListeners() is called
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingMedium,
                ),
                child: Column(
                  children: [
                    _buildProfileHeader(user),
                    const SizedBox(height: AppTheme.spacingLarge),
                    _buildUserInformationSection(user),
                    const SizedBox(height: AppTheme.spacingLarge),
                    _buildUserLocationSection(user),
                    const SizedBox(height: AppTheme.spacingLarge),
                    // Show "Apply For Vendor" option ONLY if user is NOT a vendor
                    // Check both appliedForVendor flag and role to be safe
                    if (!user.appliedForVendor && user.role != 'vendor') ...[
                      _buildApplyForVendorOption(),
                      const SizedBox(height: AppTheme.spacingLarge),
                    ],
                    _buildPermissionsSection(
                      user,
                      user.appliedForVendor,
                      displayPermissions,
                    ),
                    const SizedBox(height: AppTheme.spacingXLarge),
                    _buildLogoutButton(authProvider),
                    const SizedBox(height: AppTheme.spacingXLarge),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              TranslationService().translate('app.loginPrompt'),
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXLarge,
                  vertical: AppTheme.spacingMedium,
                ),
              ),
              child: TranslatedText('profile.login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    final avatarUrl = user.avatar;

    return Column(
      children: [
        // Profile Picture
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(color: AppTheme.secondaryColor, width: 3),
          ),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Text(
                          user.firstName?.substring(0, 1).toUpperCase() ?? 'P',
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Text(
                          user.firstName?.substring(0, 1).toUpperCase() ?? 'P',
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    user.firstName?.substring(0, 1).toUpperCase() ?? 'P',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUserInformationSection(User user) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              'USER INFORMATION',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // First Name
          _buildInfoField(
            icon: Icons.person,
            label: 'First Name',
            value: user.firstName,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Last Name
          _buildInfoField(
            icon: Icons.person_outline,
            label: 'Last Name',
            value: user.lastName,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Email
          _buildInfoField(
            icon: Icons.email,
            label: 'Email Address',
            value: user.email,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Phone Number
          _buildPhoneField(
            icon: Icons.phone,
            label: 'Phone Number',
            code: user.phoneCountryCode ?? '504',
            number: user.phone,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // WhatsApp Number
          _buildPhoneField(
            icon: Icons.chat,
            label: 'WhatsApp Number',
            code: user.whatsappCountryCode ?? '504',
            number: user.whatsapp,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required String? value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
            const SizedBox(width: AppTheme.spacingXSmall),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingXSmall),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingMedium,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            border: Border.all(color: AppTheme.dividerColor),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            value ?? 'Not set',
            style: TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              color: value != null
                  ? AppTheme.textColor
                  : AppTheme.textSecondaryColor,
              fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField({
    required IconData icon,
    required String label,
    required String code,
    required String? number,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
            const SizedBox(width: AppTheme.spacingXSmall),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingXSmall),
        Row(
          children: [
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
                vertical: AppTheme.spacingMedium,
              ),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                border: Border.all(color: AppTheme.dividerColor),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                'HN $code',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeMedium,
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingMedium,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  border: Border.all(color: AppTheme.dividerColor),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  number ?? 'Not set',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeMedium,
                    color: number != null
                        ? AppTheme.textColor
                        : AppTheme.textSecondaryColor,
                    fontWeight: number != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserLocationSection(User user) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              'USER LOCATION',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Country
          _buildLocationField(
            icon: Icons.public,
            label: 'Country',
            value: (user.country != null && user.country!.isNotEmpty)
                ? user.country
                : (user.countryId != null ? 'Not set' : null),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // State
          _buildLocationField(
            icon: Icons.location_city,
            label: 'State',
            value: (user.state != null && user.state!.isNotEmpty)
                ? user.state
                : (user.stateId != null ? 'Not set' : null),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // City
          _buildLocationField(
            icon: Icons.place,
            label: 'City',
            value: (user.city != null && user.city!.isNotEmpty)
                ? user.city
                : (user.cityId != null ? 'Not set' : null),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Address
          _buildLocationField(
            icon: Icons.home,
            label: 'Address',
            value: user.address,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required IconData icon,
    required String label,
    required String? value,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
            const SizedBox(width: AppTheme.spacingXSmall),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingXSmall),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingMedium,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            border: Border.all(color: AppTheme.dividerColor),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            value ?? 'Not set',
            style: TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              color: value != null
                  ? AppTheme.textColor
                  : AppTheme.textSecondaryColor,
              fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildApplyForVendorOption() {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.darkAppBarColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Apply For Vendor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTheme.fontSizeLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                    // Refresh profile when returning from edit screen to update vendor status
                    if (mounted) {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      await authProvider.refreshUser();
                    }
                  },
                  tooltip: 'Click to apply for vendor',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSmall,
            ),
            child: Text(
              'Click here to apply for vendor status and unlock additional features',
              style: TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                color: AppTheme.textSecondaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection(
    User user,
    bool isVendor,
    List<String> permissions,
  ) {
    // Show user_permissions if appliedForVendor is false
    // Show vendor_permission if appliedForVendor is true
    final title = isVendor ? 'Vendor Permissions' : 'User Permissions';

    if (permissions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: isVendor
                  ? AppTheme.secondaryColor.withOpacity(0.15)
                  : AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Wrap(
            spacing: AppTheme.spacingSmall,
            runSpacing: AppTheme.spacingSmall,
            children: permissions.map((permission) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: isVendor
                      ? AppTheme.secondaryColor.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  border: Border.all(
                    color: isVendor
                        ? AppTheme.secondaryColor.withOpacity(0.3)
                        : AppTheme.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: isVendor
                          ? AppTheme.secondaryColor
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: AppTheme.spacingXSmall),
                    Text(
                      _formatPermissionName(permission),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeSmall,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatPermissionName(String permission) {
    // Convert snake_case to Title Case
    return permission
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildLogoutButton(AuthProvider authProvider) {
    return Container(
      margin: EdgeInsets.zero,
      child: ElevatedButton(
        onPressed: () async {
          // Show confirmation dialog
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );

          if (shouldLogout == true && mounted) {
            await authProvider.logout();
            // Navigate to login screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.errorColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLarge,
            vertical: AppTheme.spacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 20),
            const SizedBox(width: AppTheme.spacingSmall),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
