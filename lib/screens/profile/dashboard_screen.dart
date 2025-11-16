import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/share_utils.dart';

import '../../config/theme_config.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/translated_text.dart';
import '../../services/translation_service.dart';
import '../../providers/auth_provider.dart';

import '../../providers/dashboard_provider.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _statsController = PageController();
  int _currentStatsIndex = 0;
  bool _isStatsListView = false; // false = slider, true = list
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    // Load dashboard data on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardProvider>().loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _statsController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isStatsListView) {
        if (_currentStatsIndex < 3) {
          _statsController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Reset to first page
          _statsController.animateToPage(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  Future<bool> _onWillPop(BuildContext context) async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    return false;
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TranslationService().translate('share.linkCopied')),
        ),
      );
    }
  }

  Future<void> _shareLink(String link) async {
    await ShareUtils.shareLinkWithImage(
      link: link,
      subject: 'Comisionista247 - Referral Link',
      context: context,
    );
  }

  Future<void> _openWhatsApp(String link) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(link)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check if user is logged in
    if (!authProvider.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                const TranslatedText(
                  'auth.loginRequired',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  TranslationService().translate('auth.loginRequiredDashboard'),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: TranslatedText('auth.login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        drawer: const AppDrawer(current: 'dashboard'),
        appBar: CustomAppBar(
          title: TranslationService().translate('dashboard.title'),
          isDark: true,
          actions: [], // Remove profile icon from top bar
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Consumer<DashboardProvider>(
            builder: (context, dash, _) {
              if (dash.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return RefreshIndicator(
                onRefresh: () =>
                    context.read<DashboardProvider>().loadDashboard(),
                child: ListView(
                  padding: EdgeInsets.only(
                    left: AppTheme.spacingMedium,
                    right: AppTheme.spacingMedium,
                    top: AppTheme.spacingMedium,
                    bottom:
                        AppTheme.spacingMedium +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    // Header Section
                    Text(
                      TranslationService().translate(
                        'dashboard.referralDashboard',
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            TranslationService().translate(
                              'dashboard.monitorSubtitle',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                        // Toggle Button for View Mode - Icon only
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isStatsListView = !_isStatsListView;
                            });
                            if (_isStatsListView) {
                              _stopAutoScroll();
                            } else {
                              _startAutoScroll();
                            }
                          },
                          child: Icon(
                            _isStatsListView ? Icons.view_carousel : Icons.list,
                            size: 20,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),

                    // Stats Section - Slider or List View
                    _isStatsListView
                        ? _buildStatsListView(dash)
                        : _buildStatsSliderView(dash),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Possible Loan Amount Card (Dark Blue)
                    _buildLoanCard(dash),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Your Referral Link Card with Slider
                    _buildReferralLinkCard(dash),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Recent Referral Activity Card
                    _buildRecentActivityCard(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String iconPosition,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              Icon(icon, color: Colors.orange, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppTheme.textSecondaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppTheme.textColor),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSliderView(DashboardProvider dash) {
    // Start auto-scroll when slider view is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _statsController,
            onPageChanged: (index) {
              setState(() {
                _currentStatsIndex = index;
              });
              // Restart timer when page changes (user interaction)
              _startAutoScroll();
            },
            itemCount: 4,
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _buildInfoCard(
                    title: TranslationService().translate(
                      'referral.totalEarnings',
                    ),
                    icon: Icons.people,
                    iconPosition: 'right',
                    children: [
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.pointAReferrer',
                        ),
                        dash.totalPointAReferer.toString(),
                        Icons.person,
                      ),
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.pointAVendor',
                        ),
                        dash.totalPointAVendor.toString(),
                        Icons.store,
                      ),
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.referProduct',
                        ),
                        dash.totalReferProduct.toString(),
                        Icons.card_giftcard,
                      ),
                    ],
                  );
                case 1:
                  return _buildInfoCard(
                    title: TranslationService().translate(
                      'referral.commissions',
                    ),
                    icon: Icons.attach_money,
                    iconPosition: 'right',
                    children: [
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.convertedCommissions',
                        ),
                        '\$${dash.convertedCommission}',
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.pendingCommissions',
                        ),
                        '\$${dash.pendingCommission}',
                        Icons.access_time,
                        color: Colors.orange,
                      ),
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.possibleCommissions',
                        ),
                        '\$${dash.possibleCommission}',
                        Icons.star,
                        color: Colors.blue,
                      ),
                    ],
                  );
                case 2:
                  return _buildInfoCard(
                    title: TranslationService().translate(
                      'referral.productsTitle',
                    ),
                    icon: Icons.inventory_2,
                    iconPosition: 'right',
                    children: [
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.pointWebProducts',
                        ),
                        dash.pointWebProduct.toString(),
                        Icons.language,
                      ),
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.vendorProducts',
                        ),
                        dash.vendorProduct.toString(),
                        Icons.store,
                      ),
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.stats.pointRegularProducts',
                        ),
                        dash.pointRegularProduct.toString(),
                        Icons.shopping_bag,
                      ),
                    ],
                  );
                case 3:
                  return _buildInfoCard(
                    title: TranslationService().translate(
                      'referral.loanSummary',
                    ),
                    icon: Icons.account_balance_wallet,
                    iconPosition: 'right',
                    children: [
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.totalPossibleLoan',
                        ),
                        '\$${dash.totalPossibleLoan}',
                        Icons.attach_money,
                      ),
                      _buildInfoRow(
                        TranslationService().translate(
                          'referral.totalInterest',
                        ),
                        '\$${dash.totalInterest}',
                        Icons.percent,
                      ),
                      _buildInfoRow(
                        TranslationService().translate('referral.loanTaken'),
                        '\$${dash.loanTaken}',
                        Icons.attach_money,
                      ),
                    ],
                  );
                default:
                  return const SizedBox();
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        // Stats Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentStatsIndex == index ? 12 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentStatsIndex == index
                    ? Colors.orange
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatsListView(DashboardProvider dash) {
    return Column(
      children: [
        // Total Earnings Card
        _buildInfoCard(
          title: TranslationService().translate('referral.totalEarnings'),
          icon: Icons.people,
          iconPosition: 'right',
          children: [
            _buildInfoRow(
              TranslationService().translate('referral.stats.pointAReferrer'),
              dash.totalPointAReferer.toString(),
              Icons.person,
            ),
            _buildInfoRow(
              TranslationService().translate('referral.stats.pointAVendor'),
              dash.totalPointAVendor.toString(),
              Icons.store,
            ),
            _buildInfoRow(
              TranslationService().translate('referral.stats.referProduct'),
              dash.totalReferProduct.toString(),
              Icons.card_giftcard,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        // Commissions Card
        _buildInfoCard(
          title: TranslationService().translate('referral.commissions'),
          icon: Icons.attach_money,
          iconPosition: 'right',
          children: [
            _buildInfoRow(
              TranslationService().translate(
                'referral.stats.convertedCommissions',
              ),
              '\$${dash.convertedCommission}',
              Icons.check_circle,
              color: Colors.green,
            ),
            _buildInfoRow(
              TranslationService().translate(
                'referral.stats.pendingCommissions',
              ),
              '\$${dash.pendingCommission}',
              Icons.access_time,
              color: Colors.orange,
            ),
            _buildInfoRow(
              TranslationService().translate(
                'referral.stats.possibleCommissions',
              ),
              '\$${dash.possibleCommission}',
              Icons.star,
              color: Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        // Products Card
        _buildInfoCard(
          title: TranslationService().translate('referral.productsTitle'),
          icon: Icons.inventory_2,
          iconPosition: 'right',
          children: [
            _buildInfoRow(
              TranslationService().translate('referral.stats.pointWebProducts'),
              dash.pointWebProduct.toString(),
              Icons.language,
            ),
            _buildInfoRow(
              TranslationService().translate('referral.stats.vendorProducts'),
              dash.vendorProduct.toString(),
              Icons.store,
            ),
            _buildInfoRow(
              TranslationService().translate(
                'referral.stats.pointRegularProducts',
              ),
              dash.pointRegularProduct.toString(),
              Icons.shopping_bag,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        // Loan Summary Card
        _buildInfoCard(
          title: TranslationService().translate('referral.loanSummary'),
          icon: Icons.account_balance_wallet,
          iconPosition: 'right',
          children: [
            _buildInfoRow(
              TranslationService().translate('referral.totalPossibleLoan'),
              '\$${dash.totalPossibleLoan}',
              Icons.attach_money,
            ),
            _buildInfoRow(
              TranslationService().translate('referral.totalInterest'),
              '\$${dash.totalInterest}',
              Icons.percent,
            ),
            _buildInfoRow(
              TranslationService().translate('referral.loanTaken'),
              '\$${dash.loanTaken}',
              Icons.attach_money,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoanCard(DashboardProvider dash) {
    final possibleLoan = dash.totalPossibleLoan;
    final canGetLoan = dash.canGetLoan;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F), // Dark blue
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'referral.possibleLoanTitle',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${possibleLoan.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64B5F6), // Light blue
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TranslationService().translate('referral.loanCalculatedDesc'),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: canGetLoan ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                canGetLoan
                    ? TranslationService().translate('referral.loanEligible')
                    : TranslationService().translate(
                        'referral.loanNotEligible',
                      ),
                style: TextStyle(
                  fontSize: 12,
                  color: canGetLoan ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (canGetLoan) {
                  // TODO: Implement loan request
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        TranslationService().translate(
                          'referral.loanRequestComingSoon',
                        ),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        TranslationService().translate(
                          'referral.loanNotEligible',
                        ),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const TranslatedText(
                'referral.getLoan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralLinkCard(DashboardProvider dash) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'referral.yourLinkTitle',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          const TranslatedText(
            'referral.yourLinkDesc',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          // Point A Vendor Link
          _buildReferralLinkItem(
            TranslationService().translate('pointOptions.pointAVendor.title'),
            dash.pointAVendor ?? '',
          ),
          const SizedBox(height: 16),
          // Point A Referer Link
          _buildReferralLinkItem(
            TranslationService().translate('pointOptions.pointAReferrer.title'),
            dash.pointAReferer ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildReferralLinkItem(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  url.isEmpty
                      ? TranslationService().translate(
                          'referral.noLinkAvailable',
                        )
                      : url,
                  style: TextStyle(
                    fontSize: 12,
                    color: url.isEmpty
                        ? AppTheme.textSecondaryColor
                        : AppTheme.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: url.isEmpty ? null : () => _copyToClipboard(url),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.facebook, size: 18),
                onPressed: url.isEmpty ? null : () => _shareLink(url),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                onPressed: url.isEmpty ? null : () => _openWhatsApp(url),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationService().translate('referral.recentReferralActivity'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                TranslationService().translate('referral.noRecentReferrals'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: null,
                child: Text(
                  TranslationService().translate('referral.previous'),
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              TextButton(
                onPressed: null,
                child: Text(
                  TranslationService().translate('referral.next'),
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
