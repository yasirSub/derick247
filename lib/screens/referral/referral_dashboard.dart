import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../providers/referral_provider.dart';
import '../../widgets/translated_text.dart';

class ReferralDashboard extends StatefulWidget {
  const ReferralDashboard({Key? key}) : super(key: key);

  @override
  State<ReferralDashboard> createState() => _ReferralDashboardState();
}

class _ReferralDashboardState extends State<ReferralDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReferralProvider>(context, listen: false).loadReferralData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const TranslatedText('referral.dashboardTitle'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ReferralProvider>(
        builder: (context, referralProvider, child) {
          if (referralProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await referralProvider.loadReferralData();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingLarge),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.secondaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        const TranslatedText(
                          'referral.totalEarnings',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeMedium,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '\$${referralProvider.totalEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeXXLarge,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Stats Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: AppTheme.spacingMedium,
                    mainAxisSpacing: AppTheme.spacingMedium,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                        'referral.stats.totalClicks',
                        referralProvider.totalClicks.toString(),
                        Icons.mouse,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'referral.stats.purchases',
                        referralProvider.totalPurchases.toString(),
                        Icons.shopping_cart,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'referral.stats.commission',
                        '\$${referralProvider.totalCommission.toStringAsFixed(2)}',
                        Icons.trending_up,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'referral.stats.conversion',
                        '${referralProvider.conversionRate.toStringAsFixed(1)}%',
                        Icons.percent,
                        Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // How it Works Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingLarge),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText(
                          'referral.howItWorksTitle',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeXLarge,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        _buildStep(
                          '1',
                          'referral.steps.shareProductTitle',
                          'referral.steps.shareProductDesc',
                          Icons.share,
                        ),
                        _buildStep(
                          '2',
                          'referral.steps.friendClicksTitle',
                          'referral.steps.friendClicksDesc',
                          Icons.mouse,
                        ),
                        _buildStep(
                          '3',
                          'referral.steps.friendPurchaseTitle',
                          'referral.steps.friendPurchaseDesc',
                          Icons.monetization_on,
                        ),
                        _buildStep(
                          '4',
                          'referral.steps.earnMoneyTitle',
                          'referral.steps.earnMoneyDesc',
                          Icons.account_balance_wallet,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Tips Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingLarge),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText(
                          'referral.tipsTitle',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeXLarge,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        _buildTip(
                          'referral.tips.shareOnSocialTitle',
                          'referral.tips.shareOnSocialDesc',
                          Icons.share,
                        ),
                        _buildTip(
                          'referral.tips.emailTitle',
                          'referral.tips.emailDesc',
                          Icons.email,
                        ),
                        _buildTip(
                          'referral.tips.wordOfMouthTitle',
                          'referral.tips.wordOfMouthDesc',
                          Icons.chat,
                        ),
                        _buildTip(
                          'referral.tips.qualityProductsTitle',
                          'referral.tips.qualityProductsDesc',
                          Icons.star,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          TranslatedText(
            title,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeSmall,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    String number,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                TranslatedText(
                  description,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeSmall,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _buildTip(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppTheme.secondaryColor),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                TranslatedText(
                  description,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeSmall,
                    color: AppTheme.textSecondaryColor,
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
