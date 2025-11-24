import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../widgets/app_drawer.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/translated_text.dart';
import 'vendor_create_product_screen.dart';

class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({Key? key}) : super(key: key);

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Product> _products = const [];
  List<Product> _filtered = const [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _selectedFilter; // 'all', 'web', 'normal', null

  // Check if user has vendor product permissions
  bool _hasCreatePermission() {
    final user = AuthService().currentUser;
    if (user == null) return false;
    final allPermissions = [
      ...user.userPermissions,
      ...user.vendorPermissions,
    ];
    return allPermissions.contains('create_product');
  }

  bool _hasEditPermission() {
    final user = AuthService().currentUser;
    if (user == null) return false;
    final allPermissions = [
      ...user.userPermissions,
      ...user.vendorPermissions,
    ];
    return allPermissions.contains('edit_product');
  }

  bool _hasDeletePermission() {
    final user = AuthService().currentUser;
    if (user == null) return false;
    final allPermissions = [
      ...user.userPermissions,
      ...user.vendorPermissions,
    ];
    return allPermissions.contains('delete_product');
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ApiService();
      final response = await api.getVendorProducts();
      final data = response.data;

      // Tolerate shapes like vendror.txt
      List<dynamic> items = const [];
      if (data is Map<String, dynamic>) {
        final root = data['data'];
        if (root is Map<String, dynamic> && root['data'] is List) {
          items = root['data'] as List;
        } else if (data['data'] is List) {
          items = data['data'] as List;
        }
      } else if (data is List) {
        items = data;
      }

      final products = items
          .whereType<Map<String, dynamic>>()
          .map((e) => Product.fromJson(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _products = products;
        _filtered = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = TranslationService().translate('vendor.failedToLoadProducts');
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _applyFilter);
  }

  void _applyFilter() {
    List<Product> result = List<Product>.from(_products);

    // Apply product type filter
    if (_selectedFilter != null && _selectedFilter!.isNotEmpty && _selectedFilter != 'all') {
      if (_selectedFilter == 'web') {
        result = result.where((p) => 
          p.productType == 'point_web_product'
        ).toList();
      } else if (_selectedFilter == 'normal') {
        result = result.where((p) => 
          p.productType == 'point_regular_product'
        ).toList();
      }
      // If 'all' or null, show all products (no filter applied)
    }

    // Apply search query filter
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((p) {
        final inName = p.name.toLowerCase().contains(q);
        final inCategory = (p.categoryName ?? '').toLowerCase().contains(q);
        final inType = (p.productType ?? '').toLowerCase().contains(q);
        return inName || inCategory || inType;
      }).toList();
    }

    setState(() {
      _filtered = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'vendor'),
      appBar: AppBar(
        title: TranslatedText('vendor.vendorProducts'),
        backgroundColor: AppTheme.darkAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        actions: [
          if (_hasCreatePermission())
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAddProductOptions,
              tooltip: TranslationService().translate('vendor.addProduct'),
            ),
        ],
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: AppTheme.spacingMedium),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              ElevatedButton(
                onPressed: _fetchProducts,
                child: TranslatedText('common.retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchProducts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(child: TranslatedText('common.noProductsAvailable')),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProducts,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacingSmall),
        itemCount: _filtered.length + 1,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppTheme.spacingSmall),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchField(),
                const SizedBox(height: 12),
                _buildFilterChips(),
              ],
            );
          }
          final product = _filtered[index - 1];
          final hasEditPermission = _hasEditPermission();
          final hasDeletePermission = _hasDeletePermission();
          return _VendorListTile(
            product: product,
            onEdit: hasEditPermission ? () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VendorCreateProductScreen(productId: product.id),
                ),
              );
              if (created == true) {
                _fetchProducts();
              }
            } : null,
            onDelete: hasDeletePermission ? () async {
              final confirm = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
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
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      TranslatedText(
                        'common.deleteProduct',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TranslatedText('common.deleteProductConfirm', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: TranslatedText('common.cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: TranslatedText('common.delete'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
              if (confirm == true) {
                try {
                  await ApiService().deleteVendorProduct(product.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: TranslatedText('common.productDeleted')),
                  );
                  _fetchProducts();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(
                    content: Text(
                      TranslationService().translate(
                        'common.deleteFailed',
                        params: {'error': e.toString()},
                      ),
                    ),
                  ));
                }
              }
            } : null,
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: TranslationService().translate('search.searchProductsCategoriesTypes'),
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.all(AppTheme.spacingSmall),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            value: 'all',
            icon: Icons.grid_view,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Web Product',
            value: 'web',
            icon: Icons.link,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Normal Product',
            value: 'normal',
            icon: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : AppTheme.primaryColor,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          // If clicking the already selected chip, deselect it (show all)
          if (isSelected && selected) {
            _selectedFilter = null;
          } else {
            _selectedFilter = selected ? value : null;
          }
        });
        _applyFilter();
      },
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textColor,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
    );
  }

  Future<void> _showAddProductOptions() async {
    // Check permission before showing add options
    if (!_hasCreatePermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to add vendor products'),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationService().translate('vendor.whichProductToAdd'),
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: TranslatedText('vendor.addProduct'),
                  subtitle: TranslatedText('vendor.simpleFormToAddOrEdit'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, 'normal'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (result == 'normal') {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const VendorCreateProductScreen()),
      );
      if (created == true) {
        _fetchProducts();
      }
    }
  }
}

class _VendorListTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _VendorListTile({required this.product, this.onEdit, this.onDelete});

  bool get _canEdit => onEdit != null;
  bool get _canDelete => onDelete != null;

  Color _statusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spacingSmall),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: SizedBox(
            width: 56,
            height: 56,
            child: product.firstImage != null
                ? Image.network(product.firstImage!, fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        title: Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (product.categoryName != null) ...[
                  Icon(Icons.category, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      product.categoryName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(product.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    (product.status ?? 'unknown').toLowerCase(),
                    style: TextStyle(
                      color: _statusColor(product.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              product.formattedPrice,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: onEdit,
                tooltip: TranslationService().translate('vendor.edit'),
              ),
            if (_canDelete)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
                tooltip: TranslationService().translate('vendor.delete'),
              ),
          ],
        ),
      ),
    );
  }
}
