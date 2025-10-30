import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/theme_config.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_app_bar.dart';

class AddWebDropshippingProductScreen extends StatefulWidget {
  final int? productId; // when present, treat as edit
  final bool isNormal; // true => hide product link, treat as normal product
  const AddWebDropshippingProductScreen({
    Key? key,
    this.productId,
    this.isNormal = false,
  }) : super(key: key);

  @override
  State<AddWebDropshippingProductScreen> createState() => _State();
}

class _State extends State<AddWebDropshippingProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productLinkCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');
  final TextEditingController _minQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _shortSummaryCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  // Normal product owner fields
  final TextEditingController _ownerNameCtrl = TextEditingController();
  final TextEditingController _ownerPhoneCtrl = TextEditingController();
  final TextEditingController _ownerCommentsCtrl = TextEditingController();

  bool _submitting = false;
  bool _loadingCategories = true;
  bool _loadingExisting = false;
  String? _categoriesError;
  List<Map<String, dynamic>> _categories = const [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final TextEditingController _categorySearchCtrl = TextEditingController();

  // Media
  File? _thumbnail;
  final List<File> _gallery = [];
  String? _existingThumbnailUrl;
  final List<String> _existingGalleryUrls = [];
  int _step = 0; // 0: Basic Info, 1: Media

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.productId != null) {
      _loadExistingProduct(widget.productId!);
    }
  }

  Future<void> _loadExistingProduct(int id) async {
    setState(() {
      _loadingExisting = true;
    });
    final api = ApiService();
    try {
      // Try dropshipping detail then vendor detail
      Map<String, dynamic>? obj;
      try {
        final res = await api.getDropshippingProduct(id);
        final data = res.data;
        if (data is Map<String, dynamic>) {
          obj = (data['data'] is Map<String, dynamic>) ? data['data'] : data;
        }
      } catch (_) {}
      if (obj == null) {
        final res = await api.getVendorProduct(id);
        final data = res.data;
        if (data is Map<String, dynamic>) {
          obj = (data['data'] is Map<String, dynamic>) ? data['data'] : data;
        }
      }

      if (obj != null) {
        // Basic text fields
        _nameCtrl.text = (obj['name'] ?? '').toString();
        _productLinkCtrl.text = (obj['product_link'] ?? obj['link'] ?? '')
            .toString();
        _priceCtrl.text = (obj['price'] ?? '').toString();
        _quantityCtrl.text = (obj['quantity'] ?? obj['stock'] ?? '1')
            .toString();
        _minQtyCtrl.text = (obj['min_buying_qty'] ?? '1').toString();
        _shortSummaryCtrl.text =
            (obj['short_summary'] ?? obj['short_description'] ?? '').toString();
        _descriptionCtrl.text = (obj['description'] ?? '').toString();

        // Category mapping by id, otherwise by name
        final incomingCategoryId = obj['category_id']?.toString();
        final incomingCategoryName = obj['category_name'] ?? obj['category'];
        if (incomingCategoryId != null && incomingCategoryId.isNotEmpty) {
          _selectedCategoryId = incomingCategoryId;
        }
        if (incomingCategoryName != null) {
          _selectedCategoryName = incomingCategoryName.toString();
        }
        // If we only have name, try to find id from loaded categories
        if ((_selectedCategoryId == null || _selectedCategoryId!.isEmpty) &&
            _selectedCategoryName != null &&
            _categories.isNotEmpty) {
          final match = _categories.firstWhere(
            (e) => (e['name'] ?? '') == _selectedCategoryName,
            orElse: () => const {'id': null},
          );
          if (match['id'] != null) {
            _selectedCategoryId = match['id'].toString();
          }
        }
        _categorySearchCtrl.text = _selectedCategoryName ?? '';

        // Existing media (for preview)
        final thumb = obj['thumbnail'] ?? obj['thumb'] ?? obj['image'];
        if (thumb is String && thumb.isNotEmpty) {
          _existingThumbnailUrl = thumb;
        } else if (obj['medias'] is Map<String, dynamic>) {
          final m = obj['medias'] as Map<String, dynamic>;
          if (m['thumbnail'] is String) _existingThumbnailUrl = m['thumbnail'];
        }

        // Gallery can be in medias map, or gallery list/array
        if (obj['gallery'] is List) {
          for (final it in (obj['gallery'] as List)) {
            final url = (it is String)
                ? it
                : (it is Map && it['url'] is String)
                ? it['url'] as String
                : null;
            if (url != null && url.isNotEmpty) _existingGalleryUrls.add(url);
          }
        } else if (obj['medias'] is Map<String, dynamic>) {
          final m = obj['medias'] as Map<String, dynamic>;
          final g = m['gallery'];
          if (g is List) {
            for (final it in g) {
              final url = (it is String)
                  ? it
                  : (it is Map && it['url'] is String)
                  ? it['url'] as String
                  : null;
              if (url != null && url.isNotEmpty) _existingGalleryUrls.add(url);
            }
          }
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      final res = await ApiService().getCategories();
      final data = res.data;
      List<dynamic> items = const [];
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic>) {
        if (data['data'] is List) {
          items = data['data'];
        } else if (data['categories'] is List) {
          items = data['categories'];
        } else if (data['data'] is Map &&
            (data['data'] as Map)['data'] is List) {
          items = (data['data'] as Map)['data'] as List;
        }
      }
      final cats = items
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => {
              'id': (e['id'] ?? e['category_id']).toString(),
              'name': (e['name'] ?? e['title'] ?? '').toString(),
            },
          )
          .where((e) => e['name']!.isNotEmpty)
          .toList();
      // Fallback hardcoded minimal set if empty (ensures selectable values)
      final fallback = [
        {'id': '1', 'name': 'Electronics'},
        {'id': '2', 'name': 'Smartphones'},
        {'id': '3', 'name': 'Laptops'},
        {'id': '4', 'name': 'Tablets'},
      ];
      setState(() {
        _categories = cats.isNotEmpty ? cats : fallback;
        _selectedCategoryId = null; // no default selection
        _selectedCategoryName = null;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _categoriesError = 'Failed to load categories';
        _loadingCategories = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      if (_step != 0) setState(() => _step = 0);
      return;
    }
    setState(() => _submitting = true);

    try {
      final api = ApiService();
      final Map<String, dynamic> payload = {
        if (!widget.isNormal) 'product_link': _productLinkCtrl.text.trim(),
        'type': widget.isNormal ? 'point_regular_product' : 'point_web_product',
        'name': _nameCtrl.text.trim(),
        'category_id': _selectedCategoryId ?? '',
        'price': _priceCtrl.text.trim(),
        'quantity': _quantityCtrl.text.trim(),
        'min_buying_qty': _minQtyCtrl.text.trim(),
        'short_summary': _shortSummaryCtrl.text.trim().isEmpty
            ? 'N/A'
            : _shortSummaryCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        if (widget.isNormal) ...{
          'owner_name': _ownerNameCtrl.text.trim(),
          'owner_phone': _ownerPhoneCtrl.text.trim(),
          'about_owner': _ownerCommentsCtrl.text.trim(),
        },
      };

      // Attach files when provided. If editing and no new thumbnail selected,
      // re-upload the existing thumbnail URL to satisfy server-side validation.
      if (_thumbnail != null) {
        payload['thumbnail'] = await MultipartFile.fromFile(
          _thumbnail!.path,
          filename: _thumbnail!.path.split('/').last,
        );
      } else if (widget.productId != null &&
          _existingThumbnailUrl != null &&
          _existingThumbnailUrl!.isNotEmpty) {
        try {
          final dir = await getTemporaryDirectory();
          final tempPath =
              '${dir.path}/thumb_${widget.productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final resp = await Dio().download(_existingThumbnailUrl!, tempPath);
          if (resp.statusCode == 200) {
            payload['thumbnail'] = await MultipartFile.fromFile(
              tempPath,
              filename: tempPath.split('/').last,
            );
          }
        } catch (_) {
          // If download fails, let server return a clear error
        }
      }
      if (_gallery.isNotEmpty) {
        payload['gallery[]'] = await Future.wait(
          _gallery.map(
            (f) => MultipartFile.fromFile(
              f.path,
              filename: f.path.split('/').last,
            ),
          ),
        );
      }

      final res = widget.productId == null
          ? await api.addDropshippingProduct(payload)
          : await api.updateDropshippingProduct(widget.productId!, payload);
      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product submitted for processing')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${res.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Create Product',
        isDark: true,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingExisting) const LinearProgressIndicator(minHeight: 2),
              _buildStepperTabs(),
              const SizedBox(height: AppTheme.spacingMedium),
              if (_step == 0) ...[
                if (!widget.isNormal)
                  _buildText(
                    'Product Link',
                    _productLinkCtrl,
                    hint: 'https://example.com/product',
                    requiredField: true,
                  ),
                const SizedBox(height: AppTheme.spacingSmall),
                _buildSectionTitle('Basic Information'),
                if (widget.isNormal) ...[
                  _subSectionBar('OWNER DETAILS'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildText(
                          'Owner Name',
                          _ownerNameCtrl,
                          hint: 'e.g., John Doe',
                          requiredField: true,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSmall),
                      Expanded(
                        child: _buildText(
                          'Owner Phone',
                          _ownerPhoneCtrl,
                          hint: 'e.g., 01700000000',
                          requiredField: true,
                          keyboard: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  _buildText(
                    'Comments',
                    _ownerCommentsCtrl,
                    hint: 'e.g., Write your about owner...',
                    maxLines: 3,
                  ),
                  _subSectionBar('PRODUCT DETAILS'),
                ],
                _buildText('Product Title', _nameCtrl, requiredField: true),
                _buildCategoryField(),
                // Make fields more readable on mobile: price in its own row,
                // then two wide inputs for quantity and minimum order.
                _buildPriceField(),
                const SizedBox(height: AppTheme.spacingSmall),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        'Product Quantity',
                        _quantityCtrl,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Expanded(
                      child: _buildNumberField(
                        'Minimum Order Quantity',
                        _minQtyCtrl,
                      ),
                    ),
                  ],
                ),
                _buildText(
                  'Product Short Summary',
                  _shortSummaryCtrl,
                  maxLines: 3,
                ),
                _buildText(
                  'Product Description',
                  _descriptionCtrl,
                  maxLines: 6,
                ),
              ] else ...[
                _buildSectionTitle('Media'),
                _buildMediaPickers(),
              ],
              const SizedBox(height: AppTheme.spacingLarge),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    if (_step == 1)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _step = 0),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step == 1) const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting
                            ? null
                            : (_step == 0
                                  ? () => setState(() => _step = 1)
                                  : _submit),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_step == 1) ...[
                                    const Icon(Icons.upload_file, size: 18),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(_step == 0 ? 'Next' : 'Upload Product'),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildText(
    String label,
    TextEditingController c, {
    String? hint,
    bool requiredField = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: (v) {
          if (requiredField && (v == null || v.trim().isEmpty)) {
            return 'Required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCategoryField() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppTheme.spacingMedium),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (_categoriesError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_categoriesError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Choose Categories',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextFormField(
            controller: _categorySearchCtrl,
            readOnly: true,
            onTap: _openCategoryPicker,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _selectedCategoryName ?? 'Search category...',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            validator: (_) => (_selectedCategoryId == null) ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  void _openCategoryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        List<Map<String, dynamic>> filtered = List.from(_categories);
        final controller = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spacingMedium,
              right: AppTheme.spacingMedium,
              top: AppTheme.spacingMedium,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (q) {
                    final query = q.toLowerCase();
                    filtered = _categories
                        .where(
                          (e) => (e['name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(query),
                        )
                        .toList();
                    (context as Element).markNeedsBuild();
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search category...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return ListTile(
                        title: Text(item['name'] ?? item['id']),
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = item['id'].toString();
                            _selectedCategoryName = (item['name'] ?? '')
                                .toString();
                            // keep last filtered set only for picker scope
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepperTabs() {
    return Row(
      children: [
        _buildStepChip(1, 'Basic Info', active: _step == 0),
        const SizedBox(width: AppTheme.spacingMedium),
        _buildStepChip(2, 'Media', active: _step == 1),
      ],
    );
  }

  Widget _buildStepChip(int num, String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: active ? Colors.orange.withOpacity(0.15) : Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: active ? Colors.orange : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: active ? Colors.orange : Colors.grey,
            child: Text('$num', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.orange : AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subSectionBar(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildPriceField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: TextFormField(
        controller: _priceCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Product Price',
          prefixIcon: Container(
            alignment: Alignment.center,
            width: 48,
            child: const Text('HNL'),
          ),
          border: const OutlineInputBorder(),
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingMedium,
          ),
        ),
        validator: (v) {
          final txt = (v ?? '').trim();
          if (txt.isEmpty) return 'Required';
          final numVal = num.tryParse(txt);
          if (numVal == null || numVal <= 0) return 'Enter a valid amount';
          return null;
        },
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController c) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingMedium,
        ),
      ),
      validator: (v) {
        final txt = (v ?? '').trim();
        if (txt.isEmpty) return 'Required';
        final intVal = int.tryParse(txt);
        if (intVal == null || intVal < 1) return 'Must be 1 or more';
        return null;
      },
    );
  }

  Widget _buildMediaPickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mediaSectionTitle('ADD PRODUCT THUMBNAIL'),
        const SizedBox(height: 6),
        _uploadZone(
          height: 160,
          onTap: () async {
            final picker = ImagePicker();
            final x = await picker.pickImage(source: ImageSource.gallery);
            if (x != null) setState(() => _thumbnail = File(x.path));
          },
          child: _buildThumbnailPreview(),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        _mediaSectionTitle('ADD PRODUCT GALLERY IMAGES'),
        const SizedBox(height: 6),
        _uploadZone(
          height: 160,
          onTap: () async {
            final picker = ImagePicker();
            final xs = await picker.pickMultiImage();
            if (xs.isNotEmpty) {
              setState(() => _gallery.addAll(xs.map((e) => File(e.path))));
            }
          },
          child: _buildGalleryPreview(),
        ),
      ],
    );
  }

  Widget _mediaSectionTitle(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _uploadZone({
    required double height,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _uploadHint() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(
          Icons.cloud_upload_outlined,
          size: 28,
          color: AppTheme.textSecondaryColor,
        ),
        SizedBox(height: 8),
        Text('Drag & drop image or click to upload'),
        SizedBox(height: 4),
        Text(
          'Max size: 5MB per file',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildThumbnailPreview() {
    if (_thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(_thumbnail!, height: 140, fit: BoxFit.contain),
      );
    }
    if (_existingThumbnailUrl != null && _existingThumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _existingThumbnailUrl!,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _uploadHint(),
        ),
      );
    }
    return _uploadHint();
  }

  Widget _buildGalleryPreview() {
    final hasNew = _gallery.isNotEmpty;
    final hasExisting = _existingGalleryUrls.isNotEmpty;
    if (!hasNew && !hasExisting) return _uploadHint();

    final total = _existingGalleryUrls.length + _gallery.length;
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isExisting = index < _existingGalleryUrls.length;
          if (isExisting) {
            final url = _existingGalleryUrls[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 120,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            );
          }
          final file = _gallery[index - _existingGalleryUrls.length];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file,
                  width: 120,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _gallery.remove(file)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
