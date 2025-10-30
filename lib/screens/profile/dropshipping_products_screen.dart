import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../widgets/app_drawer.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import 'dropshipping_product_detail_screen.dart';
import 'add_web_dropshipping_product_screen.dart';

class DropshippingProductsScreen extends StatefulWidget {
  const DropshippingProductsScreen({Key? key}) : super(key: key);

  @override
  State<DropshippingProductsScreen> createState() =>
      _DropshippingProductsScreenState();
}

class _DropshippingProductsScreenState
    extends State<DropshippingProductsScreen> {
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
      final response = await api.getDropshippingProducts();
      final data = response.data;

      // Debug print the shape to help diagnose empties
      // ignore: avoid_print
      print('Dropshipping API raw response: ${data.runtimeType} -> $data');

      // Tolerate common shapes: [], {data: []}, {products: []}, {result: []}, {items: []}, {data: {data: []}}
      List<dynamic> items = const [];
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic>) {
        final map = data;
        if (map['data'] is List) {
          items = map['data'] as List;
        } else if (map['products'] is List) {
          items = map['products'] as List;
        } else if (map['items'] is List) {
          items = map['items'] as List;
        } else if (map['result'] is List) {
          items = map['result'] as List;
        } else if (map['data'] is Map && (map['data'] as Map)['data'] is List) {
          items = (map['data'] as Map)['data'] as List;
        }
      }

      List<Product> products = items
          .whereType<Map<String, dynamic>>()
          .map((e) => Product.fromJson(e))
          .toList();

      // Fallback: if no dropshipping items, try vendor products (some accounts use vendor endpoint)
      if (products.isEmpty) {
        final vendorRes = await api.getVendorProducts();
        final vData = vendorRes.data;
        // ignore: avoid_print
        print('Vendor API raw response: ${vData.runtimeType} -> $vData');
        List<dynamic> vItems = const [];
        if (vData is List) {
          vItems = vData;
        } else if (vData is Map<String, dynamic>) {
          final map = vData;
          if (map['data'] is List) {
            vItems = map['data'] as List;
          } else if (map['products'] is List) {
            vItems = map['products'] as List;
          } else if (map['items'] is List) {
            vItems = map['items'] as List;
          } else if (map['result'] is List) {
            vItems = map['result'] as List;
          } else if (map['data'] is Map &&
              (map['data'] as Map)['data'] is List) {
            vItems = (map['data'] as Map)['data'] as List;
          }
        }
        products = vItems
            .whereType<Map<String, dynamic>>()
            .map((e) => Product.fromJson(e))
            .toList();
      }

      if (mounted) {
        setState(() {
          _products = products;
          _filtered = products;
          _isLoading = false;
        });

        // Show a one-time debug count to understand why list is empty on device
        if (_products.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No dropshipping products returned by API'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load products';
          _isLoading = false;
        });
        // ignore: avoid_print
        print('Dropshipping API error: $e');
      }
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
      drawer: const AppDrawer(current: 'pointer'),
      appBar: AppBar(
        title: const Text('Dropshipping Products'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddProductOptions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProducts,
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
      return const Center(child: Text('No products available'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      itemCount: _filtered.length + 1,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppTheme.spacingSmall),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSearchField();
        }
        final product = _filtered[index - 1];
        return _DropshippingListTile(
          product: product,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DropshippingProductDetailScreen(productId: product.id),
              ),
            );
          },
          onEdit: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AddWebDropshippingProductScreen(productId: product.id),
              ),
            );
            if (created == true) {
              _fetchProducts();
            }
          },
          onDelete: () async {
            final confirm = await showModalBottomSheet<bool>(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delete Product',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeLarge,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSmall),
                        const Text(
                          'Are you sure you want to delete this product?',
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
            if (confirm == true) {
              try {
                await ApiService().deleteDropshippingProduct(product.id);
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
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Add Web Product'),
                  subtitle: const Text(
                    'Requires a product link as a referral.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, 'web'),
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Add Normal Product'),
                  subtitle: const Text('Requires owner name and phone number.'),
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
    if (result == 'web') {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AddWebDropshippingProductScreen(),
        ),
      );
      if (created == true) {
        _fetchProducts();
      }
    } else if (result == 'normal') {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AddWebDropshippingProductScreen(isNormal: true),
        ),
      );
      if (created == true) {
        _fetchProducts();
      }
    }
  }
}

// Drawer moved to shared widget AppDrawer

class _DropshippingListTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DropshippingListTile({
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

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
        onTap: onTap,
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
