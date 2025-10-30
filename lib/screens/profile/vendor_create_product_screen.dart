import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../config/theme_config.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';

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

  // Temporary controllers for empty shipping form
  final TextEditingController _tempShippingTimeCtrl = TextEditingController();
  String _tempTimeType = 'hours';
  int? _tempCountryId;

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // If on step 0, go back to previous screen or home
          if (_step == 0) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          } else {
            // If on other steps, go back to previous step
            setState(() => _step -= 1);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Create Product',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          backgroundColor: AppTheme.darkAppBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_step == 0) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              } else {
                setState(() => _step -= 1);
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Stepper
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                child: _buildStepper(),
              ),
              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  child: _buildStepBody(),
                ),
              ),
              // Bottom Navigation Bar
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['Basic Info', 'Additional Details', 'Medias'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final active = _step == i;
        final completed = i < _step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.orange
                            : completed
                            ? Colors.orange.shade300
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: completed
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: active ? Colors.white : Colors.orange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? Colors.orange : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: completed ? Colors.orange : Colors.grey.shade300,
                  ),
                ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(
          label: 'Product Title',
          controller: _nameCtrl,
          hint: 'e.g., Casual Shirt',
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        _buildCategoryField(),
        const SizedBox(height: AppTheme.spacingMedium),
        // Price and Quantity in Row
        Row(
          children: [
            Expanded(
              flex: 2,
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
          ],
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        _textField(
          label: 'Minimum Order Quantity',
          controller: _minQtyCtrl,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        _multiline(label: 'Product Short Summary', controller: _shortCtrl),
        const SizedBox(height: AppTheme.spacingMedium),
        _multiline(
          label: 'Product Description',
          controller: _descCtrl,
          minLines: 5,
        ),
        const SizedBox(height: AppTheme.spacingMedium),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Area Management Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Product Area Management',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),

        // Location Fields - Better spacing
        _categoryStyleDropdown<int>(
          label: 'Select Your Country',
          value: _countryId,
          enabled: true,
          hint: 'Select country...',
          icon: Icons.public,
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
              ? const [DropdownMenuItem(value: null, child: Text('Loading...'))]
              : _countries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e['id'] as int?,
                        child: Text('${e['name']}'),
                      ),
                    )
                    .toList(),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        _categoryStyleDropdown<int>(
          label: 'Select Your State',
          value: _stateId,
          enabled: _countryId != null,
          hint: 'Select country first...',
          icon: Icons.location_city,
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
        const SizedBox(height: AppTheme.spacingMedium),
        _categoryStyleDropdown<int>(
          label: 'Select Your City',
          value: _cityId,
          enabled: _stateId != null,
          hint: 'Select state first...',
          icon: Icons.place,
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

        const SizedBox(height: AppTheme.spacingLarge),

        // ADD SHIPPING COUNTRY Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.yellow.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'ADD SHIPPING COUNTRY',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),

        // Shipping Editor
        _buildShippingEditor(),
      ],
    );
  }

  Widget _buildShippingEditor() {
    return Column(
      children: [
        // Show existing shipping entries
        for (int i = 0; i < _shipping.length; i++) _shippingTile(i),

        // Empty form card (always visible)
        Container(
          margin: EdgeInsets.only(
            bottom: _shipping.isEmpty ? 0 : AppTheme.spacingMedium,
          ),
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country dropdown
              _categoryStyleDropdown<int>(
                label: 'Country',
                value: _tempCountryId,
                enabled: true,
                hint: 'Select a Country',
                icon: Icons.public,
                onChanged: (v) {
                  setState(() {
                    _tempCountryId = v;
                  });
                },
                items: _countries
                    .where((e) => !_shipping.any((s) => s.countryId == e['id']))
                    .map(
                      (e) => DropdownMenuItem(
                        value: e['id'] as int?,
                        child: Text('${e['name']}'),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppTheme.spacingMedium),

              // Shipping Time field
              _textField(
                label: 'Shipping Time',
                controller: _tempShippingTimeCtrl,
                hint: 'e.g., 5',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppTheme.spacingMedium),

              // Time Type dropdown
              _categoryStyleDropdown<String>(
                label: 'Time Type',
                value: _tempTimeType,
                enabled: true,
                hint: 'Select Time Type',
                icon: Icons.access_time,
                onChanged: (v) => setState(() => _tempTimeType = v ?? 'hours'),
                items: const [
                  DropdownMenuItem(value: 'hours', child: Text('hours')),
                  DropdownMenuItem(value: 'min', child: Text('min')),
                  DropdownMenuItem(value: 'days', child: Text('days')),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMedium),

              // Add Country button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_tempCountryId != null) {
                      setState(() {
                        _shipping.add(
                          _ShippingCountry(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            countryId: _tempCountryId,
                            shippingTime: _tempShippingTimeCtrl.text.trim(),
                            timeType: _tempTimeType,
                          ),
                        );
                        // Reset form
                        _tempCountryId = null;
                        _tempShippingTimeCtrl.clear();
                        _tempTimeType = 'hours';
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Country'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _fetchShippingStates(
    _ShippingCountry item,
    int countryId,
  ) async {
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
        item.states = list;
      });
    } catch (_) {
      setState(() {
        item.states = const [];
      });
    }
  }

  Future<void> _fetchShippingCities(_ShippingCountry item, int stateId) async {
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
        item.cities = list;
      });
    } catch (_) {
      setState(() {
        item.cities = const [];
      });
    }
  }

  Widget _shippingTile(int index) {
    final item = _shipping[index];

    // Load states if country is selected but states not loaded
    if (item.countryId != null && item.states.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchShippingStates(item, item.countryId!);
      });
    }

    // Load cities if state is selected but cities not loaded
    if (item.stateId != null && item.cities.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchShippingCities(item, item.stateId!);
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country dropdown
          _categoryStyleDropdown<int>(
            label: 'Country',
            value: item.countryId,
            enabled: true,
            hint: 'Select a Country',
            icon: Icons.public,
            onChanged: (v) async {
              setState(() {
                item.countryId = v;
                item.stateId = null;
                item.cityId = null;
                item.states = const [];
                item.cities = const [];
              });
              if (v != null) {
                await _fetchShippingStates(item, v);
              }
            },
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
          const SizedBox(height: AppTheme.spacingMedium),

          // Shipping Time field
          _textField(
            label: 'Shipping Time',
            controller: item.timeCtrl,
            hint: 'e.g., 5',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppTheme.spacingMedium),

          // Time Type dropdown
          Row(
            children: [
              Expanded(
                child: _categoryStyleDropdown<String>(
                  label: 'Time Type',
                  value: item.timeType,
                  enabled: true,
                  hint: 'Select Time Type',
                  icon: Icons.access_time,
                  onChanged: (v) =>
                      setState(() => item.timeType = v ?? 'hours'),
                  items: const [
                    DropdownMenuItem(value: 'hours', child: Text('hours')),
                    DropdownMenuItem(value: 'min', child: Text('min')),
                    DropdownMenuItem(value: 'days', child: Text('days')),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: IconButton(
                  onPressed: () => setState(() => _shipping.removeAt(index)),
                  icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                  tooltip: 'Delete',
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingMedium,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: _step == 0
            ? MainAxisAlignment.start
            : MainAxisAlignment.spaceBetween,
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step -= 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.orange.shade700, width: 1.5),
                  foregroundColor: Colors.orange.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_step > 0) const SizedBox(width: AppTheme.spacingMedium),
          ElevatedButton.icon(
            onPressed: _submitting ? null : _onNextOrSubmit,
            icon: Icon(
              _step < 2 ? Icons.arrow_forward : Icons.upload_file,
              size: 20,
            ),
            label: Text(
              _step < 2
                  ? 'Next'
                  : (_submitting ? 'Uploading...' : 'Upload Product'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
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
        if (s.stateId != null)
          payload['shippingCountries[$i][state_id]'] = s.stateId;
        if (s.cityId != null)
          payload['shippingCountries[$i][city_id]'] = s.cityId;
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

  Widget _categoryStyleDropdown<T>({
    required String label,
    required T? value,
    required ValueChanged<T?> onChanged,
    required List<DropdownMenuItem<T>> items,
    bool enabled = true,
    String? hint,
    required IconData icon,
  }) {
    String? displayText;
    if (value != null && items.isNotEmpty) {
      try {
        final selectedItem = items.firstWhere((e) => e.value == value);
        // Extract text from Text widget
        if (selectedItem.child is Text) {
          displayText = (selectedItem.child as Text).data ?? '';
        } else {
          displayText = selectedItem.child.toString();
        }
      } catch (_) {
        displayText = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Opacity(
          opacity: enabled ? 1 : .6,
          child: TextField(
            readOnly: true,
            controller: TextEditingController(text: displayText),
            onTap: enabled && items.isNotEmpty
                ? () => _showDropdownBottomSheet<T>(
                    context: context,
                    items: items,
                    currentValue: value,
                    onSelected: onChanged,
                    hint: hint,
                  )
                : null,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey.shade600),
              hintText: hint ?? (enabled ? 'Select...' : 'Select first...'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDropdownBottomSheet<T>({
    required BuildContext context,
    required List<DropdownMenuItem<T>> items,
    required T? currentValue,
    required ValueChanged<T?> onSelected,
    String? hint,
  }) {
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
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
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: const Icon(Icons.label_outline),
                        title: item.child,
                        selected: item.value == currentValue,
                        onTap: () {
                          onSelected(item.value);
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
}

class _ShippingCountry {
  _ShippingCountry({
    required this.id,
    required this.countryId,
    this.stateId,
    this.cityId,
    required String shippingTime,
    required this.timeType,
  }) : timeCtrl = TextEditingController(text: shippingTime);

  final String id;
  int? countryId;
  int? stateId;
  int? cityId;
  final TextEditingController timeCtrl;
  String timeType; // hours | min | days

  // Store states and cities for this shipping entry
  List<Map<String, dynamic>> states = const [];
  List<Map<String, dynamic>> cities = const [];
}
