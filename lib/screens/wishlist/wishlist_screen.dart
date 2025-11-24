import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/black_board_entry.dart';
import '../../providers/black_board_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/referral_popup.dart';
import '../../services/translation_service.dart';
import '../../widgets/translated_text.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<BlackBoardProvider>().loadEntries(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF10131A),
      appBar: CustomAppBar(
        title: TranslationService().translate('leaderboard.title'),
        isDark: true,
        actions: const [],
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            TranslatedText(
              'leaderboard.title',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Consumer<BlackBoardProvider>(
          builder: (context, provider, _) {
            final entries = provider.entries.where((entry) {
              final query = _searchQuery.toLowerCase();
              if (query.isEmpty) return true;
              final category = entry.category?.toLowerCase() ?? '';
              return entry.productName.toLowerCase().contains(query) ||
                  category.contains(query);
            }).toList();

            return RefreshIndicator(
              onRefresh: () => provider.loadEntries(refresh: true),
              color: Colors.amber,
              backgroundColor: const Color(0xFF1C1F2B),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context, provider)),
                  if (provider.isLoading && entries.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      ),
                    )
                  else if (provider.error != null && entries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildError(provider.error!, provider),
                    )
                  else if (entries.isEmpty)
                    _buildEmptyState(),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = entries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _TopCommissionCard(
                          entry: entry,
                          rank: index + 1,
                        ),
                      );
                    }, childCount: entries.length),
                  ),
                  if (provider.isLoading && entries.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        ),
                      ),
                    ),
                  if (!provider.isLoading && provider.canLoadMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: provider.loadMore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Load More',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 24,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BlackBoardProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E2434), Color(0xFF151923)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'leaderboard.subtitle',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black, fontSize: 14),
              decoration: InputDecoration(
                hintText: TranslationService().translate('search.searchProductsOrCategory'),
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48, // Fixed height to match TextField
            margin: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = _searchController.text.trim();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 0,
                ),
                minimumSize: const Size(0, 48), // Same height
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                TranslationService().translate('search.search'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message, BlackBoardProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.amber, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadEntries(refresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  SliverFillRemaining _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_outlined, color: Colors.white30, size: 64),
            SizedBox(height: 16),
            const TranslatedText(
              'leaderboard.noEntries',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCommissionCard extends StatelessWidget {
  final BlackBoardEntry entry;
  final int rank;

  const _TopCommissionCard({required this.entry, required this.rank});

  Future<void> _openRefer(BuildContext context) async {
    final productProvider = context.read<ProductProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    try {
      await productProvider.loadProductDetail(entry.productId);
    } finally {
      Navigator.of(context, rootNavigator: true).pop();
    }

    final product = productProvider.selectedProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load product details.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ReferralPopup(
          product: product,
          onClose: () {
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  Color _badgeColor(int position) {
    switch (position) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return const Color(0xFF9EA7BD);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
      onTap: () => _openRefer(context),
        borderRadius: BorderRadius.circular(6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
            ),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Product Image (small, compact)
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                  child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[100],
                    child: entry.imageUrl != null && entry.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: entry.imageUrl!,
                            fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                            ),
                          )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 24,
                              ),
                          ),
                  ),
                ),
                  const SizedBox(width: 12),
                  // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                    children: [
                        // Product Name (at top)
                      Text(
                        entry.productName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                        // Category
                        if (entry.category != null && entry.category!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                  text: 'Category: ',
                              ),
                              TextSpan(
                                text: entry.category,
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                        const SizedBox(height: 4),
                        // Referrer Commission text
                        Text(
                          'Referrer Commission: ${entry.formattedCommission}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // White button with "Refer Now"
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _openRefer(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              minimumSize: const Size(0, 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: Colors.grey.shade600,
                                  width: 1,
                            ),
                        ),
                      ),
                            child: TranslatedText(
                              'leaderboard.referNow',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
            // Rank badge (top-left)
          Positioned(
              top: 6,
              left: 6,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _badgeColor(rank),
                  borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: _badgeColor(rank).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

}
