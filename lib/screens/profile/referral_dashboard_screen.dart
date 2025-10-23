import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../services/referral_service.dart';
import '../../widgets/referral_popup.dart';
import '../../models/product_model.dart';

class ReferralDashboardScreen extends StatefulWidget {
  const ReferralDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ReferralDashboardScreen> createState() =>
      _ReferralDashboardScreenState();
}

class _ReferralDashboardScreenState extends State<ReferralDashboardScreen> {
  final ReferralService _referralService = ReferralService();
  Map<String, dynamic>? _referralStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralStats();
  }

  Future<void> _loadReferralStats() async {
    try {
      final stats = await _referralService.getReferralStats();
      setState(() {
        _referralStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading referral stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Referral Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadReferralStats();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                children: [
                  _buildStatsOverview(),
                  const SizedBox(height: AppTheme.spacingLarge),
                  _buildQuickActions(),
                  const SizedBox(height: AppTheme.spacingLarge),
                  _buildReferralHistory(),
                  const SizedBox(height: AppTheme.spacingLarge),
                  _buildFeaturedProducts(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsOverview() {
    final stats = _referralStats ?? {};
    final totalEarnings = stats['totalEarnings'] ?? 0.0;
    final totalClicks = stats['totalClicks'] ?? 0;
    final totalPurchases = stats['totalPurchases'] ?? 0;
    final conversionRate = stats['conversionRate'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral Overview',
            style: TextStyle(
              fontSize: AppTheme.fontSizeXLarge,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Earnings',
                  '\$${totalEarnings.toStringAsFixed(2)}',
                  Icons.monetization_on,
                  Colors.green,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: _buildStatCard(
                  'Total Clicks',
                  totalClicks.toString(),
                  Icons.touch_app,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Purchases',
                  totalPurchases.toString(),
                  Icons.shopping_cart,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: _buildStatCard(
                  'Conversion Rate',
                  '${conversionRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXSmall),
          Text(
            title,
            style: TextStyle(fontSize: AppTheme.fontSizeSmall, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Generate Link',
                  Icons.link,
                  Colors.blue,
                  () {
                    // TODO: Implement generate link functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Generate link functionality coming soon!',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: _buildActionButton(
                  'Share Products',
                  Icons.share,
                  Colors.green,
                  () {
                    // TODO: Implement share products functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Share products functionality coming soon!',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralHistory() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _referralService.getReferralHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError ||
                  snapshot.data == null ||
                  snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacingLarge),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 50, color: Colors.grey),
                        SizedBox(height: AppTheme.spacingMedium),
                        Text(
                          'No referral activity yet',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeMedium,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingSmall),
                        Text(
                          'Start referring products to see your activity here',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeSmall,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final activity = snapshot.data![index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      child: const Icon(Icons.touch_app, color: Colors.orange),
                    ),
                    title: Text(
                      'Referral Activity',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      activity['data'] ?? 'Activity recorded',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeSmall,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    trailing: Text(
                      _formatDate(activity['timestamp']),
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeSmall,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Earning Products',
            style: TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          const Text(
            'These products offer the highest referral commissions:',
            style: TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          _buildProductList(),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    // Mock data for featured products - in real app, this would come from API
    final featuredProducts = [
      Product(
        id: 1,
        name: 'iPhone 14',
        slug: 'iphone-14',
        price: 1320,
        currencySymbol: '\$',
        referrerCommission: 36,
        shareLink: 'https://derick247.com/product/iphone-14',
        thumbnail: 'https://derick247.com/storage/seedar/three.webp',
        minBuyingQty: 1,
        shippingAvailable: [],
        medias: {},
      ),
      Product(
        id: 2,
        name: 'Samsung Galaxy S23',
        slug: 'samsung-galaxy-s23',
        price: 1100,
        currencySymbol: '\$',
        referrerCommission: 30,
        shareLink: 'https://derick247.com/product/samsung-galaxy-s23',
        thumbnail: 'https://derick247.com/storage/seedar/ten.avif',
        minBuyingQty: 1,
        shippingAvailable: [],
        medias: {},
      ),
      Product(
        id: 6,
        name: 'MacBook Air M2',
        slug: 'macbook-air-m2',
        price: 1650,
        currencySymbol: '\$',
        referrerCommission: 45,
        shareLink: 'https://derick247.com/product/macbook-air-m2',
        thumbnail: 'https://derick247.com/storage/seedar/seven.avif',
        minBuyingQty: 1,
        shippingAvailable: [],
        medias: {},
      ),
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: featuredProducts.length,
      itemBuilder: (context, index) {
        final product = featuredProducts[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.shopping_bag, color: Colors.orange),
            ),
            title: Text(
              product.name,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Earn ${product.formattedCommission} per referral',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ReferralPopup(
                    product: product,
                    onClose: () => Navigator.pop(context),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Refer'),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Recent';
    }
  }
}
