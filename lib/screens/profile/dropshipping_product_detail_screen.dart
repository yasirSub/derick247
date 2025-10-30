import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';

class DropshippingProductDetailScreen extends StatefulWidget {
  final int productId;
  const DropshippingProductDetailScreen({required this.productId, Key? key})
    : super(key: key);

  @override
  State<DropshippingProductDetailScreen> createState() => _State();
}

class _State extends State<DropshippingProductDetailScreen> {
  bool _loading = true;
  String? _error;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ApiService();
    try {
      // Try dropshipping detail first
      final res = await api.getDropshippingProduct(widget.productId);
      final data = res.data;
      Map<String, dynamic>? obj;
      if (data is Map<String, dynamic>) {
        if (data['data'] is Map<String, dynamic>) {
          obj = data['data'];
        } else {
          obj = data;
        }
      }
      if (obj == null) {
        // Fallback to vendor detail
        final v = await api.getVendorProduct(widget.productId);
        final vData = v.data;
        if (vData is Map<String, dynamic>) {
          obj = vData['data'] is Map<String, dynamic> ? vData['data'] : vData;
        }
      }
      if (obj != null) {
        setState(() {
          _product = Product.fromJson(obj!);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Product not found';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load product';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange,
        elevation: 0,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final p = _product!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.firstImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Image.network(
                p.firstImage!,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            p.name,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (p.categoryName != null)
            Text(
              p.categoryName!,
              style: const TextStyle(color: AppTheme.textSecondaryColor),
            ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            p.formattedPrice,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeXLarge,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          if (p.shortDescription != null) Text(p.shortDescription!),
          const SizedBox(height: AppTheme.spacingMedium),
          if (p.description != null)
            Text(p.description!, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}
