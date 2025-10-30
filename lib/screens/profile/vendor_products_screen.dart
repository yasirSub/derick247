import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../widgets/app_drawer.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
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
        _errorMessage = 'Failed to load products';
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
    if (_query.isEmpty) {
      setState(() {
        _filtered = List<Product>.from(_products);
      });
      return;
    }

    final q = _query.toLowerCase();
    final result = _products.where((p) {
      final inName = p.name.toLowerCase().contains(q);
      final inCategory = (p.categoryName ?? '').toLowerCase().contains(q);
      final inType = (p.productType ?? '').toLowerCase().contains(q);
      return inName || inCategory || inType;
    }).toList();

    setState(() {
      _filtered = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'vendor'),
      appBar: AppBar(
        title: const Text('Vendor Products'),
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
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddProductOptions,
            tooltip: 'Add Product',
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
                child: const Text('Retry'),
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
            child: const Center(child: Text('No products available')),
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
            return _buildSearchField();
          }
          final product = _filtered[index - 1];
          return _VendorListTile(
            product: product,
            onEdit: () async {
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
            },
            onDelete: () async {
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
                      const Text(
                        'Delete Product',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Are you sure you want to delete this product?',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
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
                              child: const Text('Delete'),
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
                    const SnackBar(content: Text('Product deleted')),
                  );
                  _fetchProducts();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
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
        hintText: 'Search products, categories, types...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.all(AppTheme.spacingSmall),
      ),
    );
  }

  Future<void> _showAddProductOptions() async {
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
                const Text(
                  'Which product do you want to add?',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Add Product'),
                  subtitle: const Text('Simple form to add or edit product.'),
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
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
