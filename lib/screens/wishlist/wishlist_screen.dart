import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/black_board_entry.dart';
import '../../providers/black_board_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/referral_popup.dart';

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
        title: 'Top Commission Board',
        isDark: true,
        actions: const [],
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            Text(
              'Top Commission Board',
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
          Row(
            children: const [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                'Top Commission Board',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Who earned the most? Check the leaderboard below!',
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
        color: const Color(0xFF232837),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search products or category',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.white54),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = _searchController.text.trim();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w600),
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
          children: const [
            Icon(Icons.leaderboard_outlined, color: Colors.white30, size: 64),
            SizedBox(height: 16),
            Text(
              'No leaderboard entries yet',
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openRefer(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E4F0), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 82,
                    height: 82,
                    color: Colors.white,
                    child: entry.imageUrl != null && entry.imageUrl!.isNotEmpty
                        ? Image.network(
                            entry.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF9EA6BA),
                            ),
                          )
                        : const Icon(
                            Icons.image_outlined,
                            color: Color(0xFF9EA6BA),
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.productName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22304B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (entry.category != null && entry.category!.isNotEmpty)
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF5F6D8B),
                            ),
                            children: [
                              const TextSpan(text: 'Category: '),
                              TextSpan(
                                text: entry.category,
                                style: const TextStyle(
                                  color: Color(0xFFF7931E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Referrer Commission: ',
                              style: TextStyle(color: Color(0xFF22304B)),
                            ),
                            TextSpan(
                              text: entry.formattedCommission,
                              style: const TextStyle(color: Color(0xFFF7931E)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.center,
                        child: _buildReferButton(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -10,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _badgeColor(rank),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _badgeColor(rank).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF22304B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _openRefer(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFFEB642), Color(0xFFF57815)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF57815).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          'Refer Now',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
