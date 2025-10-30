import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../config/theme_config.dart';
import '../../services/api_service.dart';

class VendorCreateProductScreen extends StatefulWidget {
  final int? productId; // when present -> edit mode
  const VendorCreateProductScreen({Key? key, this.productId}) : super(key: key);

  @override
  State<VendorCreateProductScreen> createState() =>
      _VendorCreateProductScreenState();
}

class _VendorCreateProductScreenState extends State<VendorCreateProductScreen> {
  int _step = 0;

  // Step 1 controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _minQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _shortCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  int? _categoryId;
  bool _loadingCategories = false;
  List<Map<String, dynamic>> _categories = const [];
  String? _selectedCategoryName;
  final TextEditingController _categorySearchCtrl = TextEditingController();

  // Step 2 state
  int? _countryId;
  int? _stateId;
  int? _cityId;

  final List<_ShippingCountry> _shipping = [];

  // Step 3 - media
  File? _thumbnail;
  final List<File> _gallery = [];

  bool _submitting = false;

  // Locations
  bool _loadingCountries = false;
  bool _loadingStates = false;
  bool _loadingCities = false;
  List<Map<String, dynamic>> _countries = const [];
  List<Map<String, dynamic>> _states = const [];
  List<Map<String, dynamic>> _cities = const [];

  @override
  void initState() {
    super.initState();
    _fetchCountries();
    _fetchCategories();
    if (widget.productId != null) {
      _loadExisting(widget.productId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Product'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange,
        elevation: 0,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            children: [
              _buildStepper(),
              const SizedBox(height: AppTheme.spacingMedium),
              Expanded(child: _buildStepBody()),
              const SizedBox(height: AppTheme.spacingMedium),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['Basic Info', 'Additional Details', 'Medias'];
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(steps.length, (i) {
        final active = _step == i;
        return GestureDetector(
          onTap: () => setState(() => _step = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? Colors.orange.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.orange,
                  child: (i < _step)
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[i],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.orange : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildStepOne();
      case 1:
        return _buildStepTwo();
      default:
        return _buildStepThree();
    }
  }

  Widget _buildStepOne() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _textField(
            label: 'Product Title',
            controller: _nameCtrl,
            hint: 'e.g., Casual Shirt',
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          _buildCategoryField(),
          const SizedBox(height: AppTheme.spacingSmall),
          Row(
            children: [
              Expanded(
                child: _currencyField(
                  label: 'Product Price',
                  controller: _priceCtrl,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: _textField(
                  label: 'Product Quantity',
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: _textField(
                  label: 'Minimum Order Quantity',
                  controller: _minQtyCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          _multiline(label: 'Product Short Summary', controller: _shortCtrl),
          const SizedBox(height: AppTheme.spacingSmall),
          _multiline(
            label: 'Product Description',
            controller: _descCtrl,
            minLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdown<int>(
                  label: 'Select Your Country',
                  value: _countryId,
                  enabled: true,
                  hint: 'Select country...',
                  onChanged: (v) {
                    setState(() {
                      _countryId = v;
                      _stateId = null;
                      _cityId = null;
                      _states = const [];
                      _cities = const [];
                    });
                    if (v != null) _fetchStates(v);
                  },
                  items: _loadingCountries
                      ? const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Loading...'),
                          ),
                        ]
                      : _countries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e['id'] as int?,
                                child: Text('${e['name']}'),
                              ),
                            )
                            .toList(),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: _dropdown<int>(
                  label: 'Select Your State',
                  value: _stateId,
                  enabled: _countryId != null,
                  hint: 'Select country first...',
                  onChanged: (v) {
                    setState(() {
                      _stateId = v;
                      _cityId = null;
                      _cities = const [];
                    });
                    if (v != null) _fetchCities(v);
                  },
                  items: _countryId == null
                      ? const []
                      : (_loadingStates
                            ? const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('Loading...'),
                                ),
                              ]
                            : _states
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e['id'] as int?,
                                      child: Text('${e['name']}'),
                                    ),
                                  )
                                  .toList()),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: _dropdown<int>(
                  label: 'Select Your City',
                  value: _cityId,
                  enabled: _stateId != null,
                  hint: 'Select state first...',
                  onChanged: (v) => setState(() => _cityId = v),
                  items: _stateId == null
                      ? const []
                      : (_loadingCities
                            ? const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('Loading...'),
                                ),
                              ]
                            : _cities
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e['id'] as int?,
                                      child: Text('${e['name']}'),
                                    ),
                                  )
                                  .toList()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(.07),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Text(
              'ADD SHIPPING OPTION',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          _buildShippingEditor(),
        ],
      ),
    );
  }

  Widget _buildShippingEditor() {
    return Column(
      children: [
        for (int i = 0; i < _shipping.length; i++) _shippingTile(i),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _shipping.add(
                    _ShippingCountry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      countryId: null,
                      shippingTime: '',
                      timeType: 'hours',
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Shipping Option'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shippingTile(int index) {
    final item = _shipping[index];
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: AppTheme.spacingSmall,
        runSpacing: AppTheme.spacingSmall,
        children: [
          SizedBox(
            width: 260,
            child: _dropdown<int>(
              label: 'Country',
              value: item.countryId,
              onChanged: (v) => setState(() => item.countryId = v),
              items: _countries
                  .where(
                    (e) => !_shipping
                        .where((s) => s != item)
                        .any((s) => s.countryId == e['id']),
                  )
                  .map(
                    (e) => DropdownMenuItem(
                      value: e['id'] as int?,
                      child: Text('${e['name']}'),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(
            width: 180,
            child: _textField(
              label: 'Shipping Time',
              controller: item.timeCtrl,
              keyboardType: TextInputType.number,
            ),
          ),
          SizedBox(
            width: 180,
            child: _dropdown<String>(
              label: 'Time Type',
              value: item.timeType,
              onChanged: (v) => setState(() => item.timeType = v ?? 'hours'),
              items: const [
                DropdownMenuItem(value: 'hours', child: Text('hours')),
                DropdownMenuItem(value: 'min', child: Text('min')),
                DropdownMenuItem(value: 'days', child: Text('days')),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _shipping.removeAt(index)),
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildStepThree() {
    return SingleChildScrollView(
      child: Column(
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
      ),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton(
            onPressed: () => setState(() => _step -= 1),
            child: const Text('Back'),
          ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _onNextOrSubmit,
          icon: _step < 2
              ? const Icon(Icons.arrow_forward)
              : const Icon(Icons.upload_file),
          label: Text(
            _step < 2
                ? 'Next'
                : (_submitting ? 'Uploading...' : 'Upload Product'),
          ),
        ),
      ],
    );
  }

  Future<void> _onNextOrSubmit() async {
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }

    // Submit
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        if (_categoryId != null) 'category_id': _categoryId,
        'price': _priceCtrl.text.trim(),
        'quantity': _qtyCtrl.text.trim(),
        'min_buying_qty': _minQtyCtrl.text.trim(),
        'short_summary': _shortCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_countryId != null) 'country_id': _countryId,
        if (_stateId != null) 'state_id': _stateId,
        if (_cityId != null) 'city_id': _cityId,
      };

      for (int i = 0; i < _shipping.length; i++) {
        final s = _shipping[i];
        payload['shippingCountries[$i][id]'] = s.id;
        if (s.countryId != null)
          payload['shippingCountries[$i][country_id]'] = s.countryId;
        payload['shippingCountries[$i][shipping_time]'] = s.timeCtrl.text
            .trim();
        payload['shippingCountries[$i][time_type]'] = s.timeType;
      }

      // Media
      if (_thumbnail != null) {
        payload['thumbnail'] = await MultipartFile.fromFile(
          _thumbnail!.path,
          filename: _thumbnail!.path.split('/').last,
        );
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

      if (widget.productId == null) {
        await ApiService().addVendorProduct(payload);
      } else {
        await ApiService().updateVendorProduct(widget.productId!, payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadExisting(int id) async {
    try {
      final res = await ApiService().getVendorProduct(id);
      final data = res.data;
      Map<String, dynamic>? obj;
      if (data is Map<String, dynamic>) {
        obj = (data['data'] is Map<String, dynamic>) ? data['data'] : data;
      }
      if (obj == null) return;

      setState(() {
        _nameCtrl.text = (obj!['name'] ?? '').toString();
        _priceCtrl.text = (obj['price'] ?? '').toString();
        _qtyCtrl.text = (obj['quantity'] ?? obj['stock'] ?? '1').toString();
        _minQtyCtrl.text = (obj['min_buying_qty'] ?? '1').toString();
        _shortCtrl.text =
            (obj['short_summary'] ?? obj['short_description'] ?? '').toString();
        _descCtrl.text = (obj['description'] ?? '').toString();
        if (obj['category_id'] != null) {
          _categoryId = (obj['category_id'] as num).toInt();
          _selectedCategoryName = obj['category_name']?.toString();
          if (_selectedCategoryName != null) {
            _categorySearchCtrl.text = _selectedCategoryName!;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _loadingCategories = true;
      _categories = const [];
    });
    try {
      final res = await ApiService().getCategories();
      final data = res.data;
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

      final cats = items
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => {
              'id': e['id'] ?? e['category_id'],
              'name': e['name'] ?? e['title'] ?? 'Unknown',
            },
          )
          .where((e) => e['id'] != null)
          .toList();

      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (_) {
      setState(() => _loadingCategories = false);
    }
  }

  Widget _buildCategoryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Product Category',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextField(
            controller: _categorySearchCtrl,
            readOnly: true,
            onTap: _openCategoryPicker,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.category_outlined),
              hintText:
                  _selectedCategoryName ??
                  (_loadingCategories
                      ? 'Loading categories...'
                      : 'Select category...'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  void _openCategoryPicker() {
    if (_loadingCategories) return;
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
                        leading: const Icon(Icons.label_outline),
                        title: Text(item['name'].toString()),
                        onTap: () {
                          setState(() {
                            _categoryId = (item['id'] as num).toInt();
                            _selectedCategoryName = item['name'].toString();
                            _categorySearchCtrl.text = _selectedCategoryName!;
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

  // ---- Media helpers ----
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
    return _uploadHint();
  }

  Widget _buildGalleryPreview() {
    if (_gallery.isEmpty) return _uploadHint();
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _gallery.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = _gallery[index];
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

  // ---- Location fetching ----
  Future<void> _fetchCountries() async {
    setState(() {
      _loadingCountries = true;
      _countries = const [];
    });
    try {
      final res = await ApiService().getCountries();
      final data = res.data;
      List<Map<String, dynamic>> list = [];
      if (data is List) {
        list = data
            .whereType<Map<String, dynamic>>()
            .map(
              (e) => {
                'id': e['id'] ?? e['country_id'],
                'name': e['name'] ?? e['country_name'] ?? e['title'],
              },
            )
            .where(
              (e) => e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
            )
            .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
            .toList();
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        final items = (data['data'] as List).whereType<Map<String, dynamic>>();
        list = items
            .map(
              (e) => {
                'id': e['id'] ?? e['country_id'],
                'name': e['name'] ?? e['country_name'] ?? e['title'],
              },
            )
            .where(
              (e) => e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
            )
            .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
            .toList();
      }
      setState(() {
        _countries = list;
        _loadingCountries = false;
      });
    } catch (_) {
      setState(() => _loadingCountries = false);
    }
  }

  Future<void> _fetchStates(int countryId) async {
    setState(() {
      _loadingStates = true;
      _states = const [];
    });
    try {
      final res = await ApiService().getStates(countryId);
      final data = res.data;
      List<Map<String, dynamic>> list = [];
      if (data is List) {
        list = data
            .whereType<Map<String, dynamic>>()
            .map(
              (e) => {
                'id': e['id'] ?? e['state_id'],
                'name': e['name'] ?? e['state_name'] ?? e['title'],
              },
            )
            .where(
              (e) => e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
            )
            .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
            .toList();
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        final items = (data['data'] as List).whereType<Map<String, dynamic>>();
        list = items
            .map(
              (e) => {
                'id': e['id'] ?? e['state_id'],
                'name': e['name'] ?? e['state_name'] ?? e['title'],
              },
            )
            .where(
              (e) => e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
            )
            .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
            .toList();
      }
      setState(() {
        _states = list;
        _loadingStates = false;
      });
    } catch (_) {
      setState(() => _loadingStates = false);
    }
  }

  Future<void> _fetchCities(int stateId) async {
    setState(() {
      _loadingCities = true;
      _cities = const [];
    });
    try {
      final res = await ApiService().getCities(stateId);
      final data = res.data;
      List<Map<String, dynamic>> list = [];
      if (data is List) {
        list = data
            .whereType<Map<String, dynamic>>()
            .map(
              (e) => {
                'id': e['id'] ?? e['city_id'],
                'name': e['name'] ?? e['city_name'] ?? e['title'],
              },
            )
            .where(
              (e) => e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
            )
            .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
            .toList();
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        final items = (data['data'] as List).whereType<Map<String, dynamic>>();
        list = items
            .map(
              (e) => {
                'id': e['id'] ?? e['city_id'],
                'name': e['name'] ?? e['city_name'] ?? e['title'],
              },
            )
            .where(
              (e) => e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
            )
            .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
            .toList();
      }
      setState(() {
        _cities = list;
        _loadingCities = false;
      });
    } catch (_) {
      setState(() => _loadingCities = false);
    }
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),
      ],
    );
  }

  Widget _currencyField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Text('USD'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _multiline({
    required String label,
    required TextEditingController controller,
    int minLines = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: 8,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required ValueChanged<T?> onChanged,
    required List<DropdownMenuItem<T>> items,
    bool enabled = true,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Opacity(
          opacity: enabled ? 1 : .6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              onChanged: enabled ? onChanged : null,
              hint: hint != null ? Text(hint) : null,
              items: items,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShippingCountry {
  _ShippingCountry({
    required this.id,
    required this.countryId,
    required String shippingTime,
    required this.timeType,
  }) : timeCtrl = TextEditingController(text: shippingTime);

  final String id;
  int? countryId;
  final TextEditingController timeCtrl;
  String timeType; // hours | min | days
}
