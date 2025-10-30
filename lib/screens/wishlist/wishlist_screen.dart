import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../widgets/custom_app_bar.dart';
import '../products/products_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  // Mock wishlist data - in real app, this would come from a provider or API
  final List<Map<String, dynamic>> _wishlistItems = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'Wishlist',
        isDark: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () {
              // Optionally implement a relevant action or leave as is
            },
            tooltip: 'Wishlist',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh wishlist data
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: _wishlistItems.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildEmptyWishlist(),
              )
            : _buildWishlistContent(),
      ),
    );
  }

  Widget _buildEmptyWishlist() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: AppTheme.spacingLarge),
            const Text(
              'Your Wishlist is Empty',
              style: TextStyle(
                fontSize: AppTheme.fontSizeXLarge,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            const Text(
              'Start adding products you love to your wishlist!',
              style: TextStyle(
                fontSize: AppTheme.fontSizeMedium,
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXLarge),
            ElevatedButton(
              onPressed: () {
                // Navigate to products screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXLarge,
                  vertical: AppTheme.spacingMedium,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: const Text('Browse Products'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistContent() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      itemCount: _wishlistItems.length,
      itemBuilder: (context, index) {
        final item = _wishlistItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.shopping_bag, color: Colors.orange),
            ),
            title: Text(
              item['name'] ?? 'Product Name',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              item['price'] ?? '\$0',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSmall,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () {
                setState(() {
                  _wishlistItems.removeAt(index);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Removed from wishlist')),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
