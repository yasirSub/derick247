// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, unnecessary_null_comparison

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dio/dio.dart';

import '../../config/theme_config.dart';

import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/translated_text.dart';

import '../home/home_screen.dart';

import '../../widgets/currency_selection_dialog.dart';

import '../../services/storage_service.dart';

import 'package:country_flags/country_flags.dart';

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

  final TextEditingController _guaranteeDurationCtrl = TextEditingController();

  final TextEditingController _guaranteeDetailsCtrl = TextEditingController();

  int? _categoryId;

  int? _subcategoryId;

  bool _loadingCategories = false;

  List<Map<String, dynamic>> _categories = const [];

  // Currency

  String _currencyCode = 'USD';

  String? _selectedCountryCode; // for showing flag next to currency

  // Guarantee

  bool _guaranteeEnabled = false;

  String _guaranteeType = 'Service';

  final List<String> _guaranteeTypes = const ['Replacement', 'Service'];

  bool _loadingSubcategories = false;

  List<Map<String, dynamic>> _subcategories = const [];

  String? _selectedCategoryName;

  String? _selectedSubcategoryName;

  final TextEditingController _categorySearchCtrl = TextEditingController();

  final TextEditingController _subcategorySearchCtrl = TextEditingController();

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

    // Initialize with one empty shipping country for new products
    if (widget.productId == null) {
      _shipping.add(
        _ShippingCountry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          countryId: null,
          shippingTime: '',
          timeType: 'hours',
        ),
      );
    }

    // Defer async operations to after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Load countries and categories first
        await _fetchCountries();
        await _fetchCategories();

        // Load default currency
        _loadDefaultCurrencyFromPrefs();

        // Then load existing product data (after categories are loaded)
        if (widget.productId != null && mounted) {
          await _loadExisting(widget.productId!);
        }
      }
    });
  }

  Widget _buildGuaranteeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),

        border: Border.all(color: Colors.grey.shade300),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),

            blurRadius: 8,

            offset: const Offset(0, 3),
          ),
        ],
      ),

      padding: const EdgeInsets.all(AppTheme.spacingMedium),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(
                TranslationService().translate('vendorCreate.guarantee'),

                style: TextStyle(
                  fontSize: AppTheme.fontSizeLarge,

                  fontWeight: FontWeight.w600,
                ),
              ),

              Switch(
                value: _guaranteeEnabled,

                onChanged: (value) {
                  setState(() {
                    _guaranteeEnabled = value;
                  });
                },
              ),
            ],
          ),

          if (_guaranteeEnabled) ...[
            const SizedBox(height: AppTheme.spacingSmall),

            _categoryStyleDropdown<String>(
              label: TranslationService().translate(
                'vendorCreate.guaranteeType',
              ),

              value: _guaranteeType,

              enabled: true,

              hint: TranslationService().translate(
                'vendorCreate.selectGuaranteeType',
              ),

              icon: Icons.verified_user_outlined,

              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _guaranteeType = value;
                });
              },

              items: _guaranteeTypes
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(
                        TranslationService().translate(
                          'vendorCreate.${e.toLowerCase()}',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: AppTheme.spacingMedium),

            _textField(
              label: TranslationService().translate(
                'vendorCreate.guaranteeDuration',
              ),

              controller: _guaranteeDurationCtrl,

              keyboardType: TextInputType.number,

              hint: TranslationService().translate(
                'vendorCreate.guaranteeDurationHint',
              ),
            ),

            const SizedBox(height: AppTheme.spacingMedium),

            _multiline(
              label: TranslationService().translate(
                'vendorCreate.guaranteeDetails',
              ),

              controller: _guaranteeDetailsCtrl,

              minLines: 3,
            ),
          ],
        ],
      ),
    );
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
          title: Text(
            TranslationService().translate('vendorCreate.createProduct'),

            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
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

  Future<void> _loadDefaultCurrencyFromPrefs() async {
    try {
      final storage = StorageService();

      String? saved = await storage.getSelectedCurrency();

      // Fallback to generic user pref key if previously used elsewhere

      final String? legacy = await storage.getUserPreference<String>(
        'currency',
      );

      saved ??= legacy;

      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() {
          _currencyCode = saved!;
        });
      }

      final savedIso = await storage.getSelectedCountryCode();

      if (mounted) {
        setState(() {
          _selectedCountryCode = savedIso;
        });
      }
    } catch (_) {}
  }

  Widget _buildStepper() {
    final steps = [
      TranslationService().translate('vendorCreate.basicInfo'),
      TranslationService().translate('vendorCreate.additionalDetails'),
      TranslationService().translate('vendorCreate.medias'),
    ];

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
          label: TranslationService().translate('vendorCreate.productTitle'),

          controller: _nameCtrl,

          hint: TranslationService().translate('vendorCreate.productTitleHint'),
        ),

        const SizedBox(height: AppTheme.spacingMedium),

        _buildCategoryField(),

        const SizedBox(height: AppTheme.spacingMedium),

        _buildSubcategoryField(),

        const SizedBox(height: AppTheme.spacingMedium),

        // Price and Quantity in Row
        Row(
          children: [
            Expanded(
              flex: 2,

              child: _currencyField(
                label: TranslationService().translate(
                  'vendorCreate.productPrice',
                ),

                controller: _priceCtrl,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spacingMedium),

        _textField(
          label: TranslationService().translate(
            'vendorCreate.minimumOrderQuantity',
          ),

          controller: _minQtyCtrl,

          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: AppTheme.spacingMedium),

        _textField(
          label: TranslationService().translate('vendorCreate.productQuantity'),

          controller: _qtyCtrl,

          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: AppTheme.spacingMedium),

        _buildGuaranteeSection(),

        const SizedBox(height: AppTheme.spacingMedium),

        _multiline(
          label: TranslationService().translate(
            'vendorCreate.productShortSummary',
          ),
          controller: _shortCtrl,
        ),

        const SizedBox(height: AppTheme.spacingMedium),

        _multiline(
          label: TranslationService().translate(
            'vendorCreate.productDescription',
          ),

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

              Text(
                TranslationService().translate(
                  'vendorCreate.productAreaManagement',
                ),

                style: const TextStyle(
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
          label: TranslationService().translate('checkout.selectYourCountry'),

          value: _countryId,

          enabled: true,

          hint: TranslationService().translate('checkout.selectCountry'),

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
              ? [
                  DropdownMenuItem(
                    value: null,
                    child: TranslatedText('app.loading'),
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

        const SizedBox(height: AppTheme.spacingMedium),

        _categoryStyleDropdown<int>(
          label: TranslationService().translate('checkout.selectState'),

          value: _stateId,

          enabled: _countryId != null,

          hint: TranslationService().translate('checkout.selectCountryFirst'),

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
                    ? [
                        DropdownMenuItem(
                          value: null,

                          child: TranslatedText('app.loading'),
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
          label: TranslationService().translate('checkout.selectCity'),

          value: _cityId,

          enabled: _stateId != null,

          hint: TranslationService().translate('checkout.selectStateFirst'),

          icon: Icons.place,

          onChanged: (v) => setState(() => _cityId = v),

          items: _stateId == null
              ? const []
              : (_loadingCities
                    ? [
                        DropdownMenuItem(
                          value: null,

                          child: TranslatedText('app.loading'),
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
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        // Section title
        if (_shipping.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
            child: Text(
              TranslationService().translate('vendorCreate.shippingAddress'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ),

        // Show all shipping entries
        for (int i = 0; i < _shipping.length; i++) _shippingTile(i),

        // Add Country button (always visible at the bottom)
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacingMedium),
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Add a new empty shipping country
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

                print('✅ [SHIPPING] Added new shipping country entry');
                print('   → Total shipping countries: ${_shipping.length}');
              },

              icon: const Icon(Icons.add, size: 18),

              label: TranslatedText('vendorCreate.addAnotherCountry'),
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
        ),
      ],
    );
  }

  Future<void> _fetchShippingStates(
    _ShippingCountry item,

    int countryId,
  ) async {
    if (!mounted) return;

    try {
      final res = await ApiService().getStates(countryId);

      final data = res.data;

      // Check if response type is states
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

      // Only process if type is 'states' or if no type field exists (backward compatibility)
      if (responseType == null || responseType == 'states') {
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
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          final items = (data['data'] as List)
              .whereType<Map<String, dynamic>>();
          list = items
              .map(
                (e) => {
                  'id': e['id'] ?? e['state_id'],

                  'name': e['name'] ?? e['state_name'] ?? e['title'],
                },
              )
              .where(
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        }

        if (mounted) {
          // Update item state first
          item.states = list;

          item.loadingStates = false;
          // Use SchedulerBinding to defer setState call
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      } else {
        // Wrong type returned, don't process
        if (mounted) {
          item.states = const [];
          item.loadingStates = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        item.states = const [];

        item.loadingStates = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  Future<void> _fetchShippingCities(_ShippingCountry item, int stateId) async {
    if (!mounted) return;

    try {
      final res = await ApiService().getCities(stateId);

      final data = res.data;

      // Check if response type is cities
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

      // Only process if type is 'cities' or if no type field exists (backward compatibility)
      if (responseType == null || responseType == 'cities') {
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
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          final items = (data['data'] as List)
              .whereType<Map<String, dynamic>>();
          list = items
              .map(
                (e) => {
                  'id': e['id'] ?? e['city_id'],

                  'name': e['name'] ?? e['city_name'] ?? e['title'],
                },
              )
              .where(
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        }

        if (mounted) {
          // Update item state first
          item.cities = list;

          item.loadingCities = false;
          // Use SchedulerBinding to defer setState call
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      } else {
        // Wrong type returned (e.g., 'countries' when expecting 'cities'), don't process
        if (mounted) {
          item.cities = const [];

          item.loadingCities = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        item.cities = const [];
        item.loadingCities = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  Widget _shippingTile(int index) {
    final item = _shipping[index];
    final isLastItem = _shipping.length == 1;

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
          // Header with delete button (if not the only item)
          if (!isLastItem)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TranslationService().translate(
                    'vendorCreate.shippingAddressNumber',
                    params: {'number': (index + 1).toString()},
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _shipping.removeAt(index);
                      print(
                        '🗑️ [SHIPPING] Removed shipping country at index $index',
                      );
                      print(
                        '   → Remaining shipping countries: ${_shipping.length}',
                      );
                    });
                  },
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          if (!isLastItem) const SizedBox(height: AppTheme.spacingMedium),

          // Country dropdown
          _categoryStyleDropdown<int>(
            label: TranslationService().translate('checkout.country'),

            value: item.countryId,

            enabled: !_loadingCountries && _countries.isNotEmpty,
            hint: _loadingCountries
                ? TranslationService().translate('app.loading')
                : (_countries.isEmpty
                      ? TranslationService().translate(
                          'common.noProductsAvailable',
                        )
                      : TranslationService().translate(
                          'checkout.selectYourCountry',
                        )),
            icon: Icons.public,

            onChanged: (v) {
              if (!mounted) return;

              // Update item state directly (no setState during callback)
              item.countryId = v;

              item.stateId = null;

              item.cityId = null;

              item.states = const [];

              item.cities = const [];

              item.loadingStates = false;
              item.loadingCities = false;

              // Use post-frame callback to update UI and fetch states
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  // State already updated above, just trigger rebuild
                });

                // Fetch states asynchronously after rebuild
                if (v != null) {
                  item.loadingStates = true;
                  _fetchShippingStates(item, v);
                }
              });
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

          // Shipping Time field (numeric only - digits only)
          _textField(
            label: 'Shipping Time',

            controller: item.timeCtrl,

            hint: 'e.g., 5',

            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: AppTheme.spacingMedium),

          // Time Type dropdown
          _categoryStyleDropdown<String>(
            label: 'Time Type',

            value: item.timeType,

            enabled: true,

            hint: 'Select Time Type',

            icon: Icons.access_time,

            onChanged: (v) => setState(() => item.timeType = v ?? 'hours'),
            items: const [
              DropdownMenuItem(value: 'hours', child: Text('hours')),

              DropdownMenuItem(value: 'min', child: Text('min')),

              DropdownMenuItem(value: 'days', child: Text('days')),
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
          _mediaSectionTitle(
            TranslationService().translate('vendorCreate.addProductThumbnail'),
          ),

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

          _mediaSectionTitle(
            TranslationService().translate('vendorCreate.addProductGallery'),
          ),

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

                child: TranslatedText(
                  'vendorCreate.back',

                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                  ? TranslationService().translate('vendorCreate.next')
                  : (_submitting
                        ? TranslationService().translate(
                            'vendorCreate.uploading',
                          )
                        : TranslationService().translate(
                            'vendorCreate.uploadProduct',
                          )),

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
      // Validate quantities: product quantity must be greater than or equal to minimum order quantity

      final int? quantity = int.tryParse(_qtyCtrl.text.trim());

      final int? minQty = int.tryParse(_minQtyCtrl.text.trim());

      if (quantity == null || minQty == null) {
        setState(() => _submitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid numeric quantities.'),

            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      if (quantity < minQty) {
        setState(() => _submitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Product quantity must be greater than minimum quantity.',
            ),

            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      // Build payload with debug logging
      print('📦 [SUBMIT] Building payload...');
      print('   → Product ID: ${widget.productId}');
      print('   → Name: ${_nameCtrl.text.trim()}');
      print('   → Category ID: $_categoryId');
      print('   → Subcategory ID: $_subcategoryId');
      print('   → Currency: $_currencyCode');
      print('   → Price: ${_priceCtrl.text.trim()}');
      print('   → Quantity: ${_qtyCtrl.text.trim()}');
      print('   → Min Buying Qty: ${_minQtyCtrl.text.trim()}');
      print('   → Product Origin - Country ID: $_countryId');
      print('   → Product Origin - State ID: $_stateId');
      print('   → Product Origin - City ID: $_cityId');
      print('   → Has Guarantee: $_guaranteeEnabled');
      print('   → Shipping Destinations Count: ${_shipping.length}');
      if (_shipping.isNotEmpty) {
        print('   → Shipping Destinations Details:');
        for (int i = 0; i < _shipping.length; i++) {
          final s = _shipping[i];
          print(
            '      [$i] country_id=${s.countryId}, time=${s.timeCtrl.text.trim()}, type=${s.timeType}',
          );
        }
      } else {
        print('   ⚠️  WARNING: No shipping destinations in list!');
      }
      print(
        '   → Thumbnail: ${_thumbnail != null ? _thumbnail!.path : "none"}',
      );
      print('   → Gallery Count: ${_gallery.length}');

      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),

        if (_categoryId != null) 'category_id': _categoryId,

        if (_subcategoryId != null) 'subcategory_id': _subcategoryId,

        'currency': _currencyCode,

        'price': _priceCtrl.text.trim(),

        'quantity': _qtyCtrl.text.trim(),

        'min_buying_qty': _minQtyCtrl.text.trim(),

        'short_summary': _shortCtrl.text.trim(),

        'description': _descCtrl.text.trim(),

        if (_countryId != null) 'country_id': _countryId,

        if (_stateId != null) 'state_id': _stateId,

        if (_cityId != null) 'city_id': _cityId,

        'has_guarantee': _guaranteeEnabled ? 1 : 0,

        // Only add guarantee fields if guarantee is enabled AND fields have values
        if (_guaranteeEnabled && _guaranteeType.isNotEmpty)
          'guarantee_type': _guaranteeType,
        if (_guaranteeEnabled && _guaranteeDurationCtrl.text.trim().isNotEmpty)
          'guarantee_duration_days': _guaranteeDurationCtrl.text.trim(),

        if (_guaranteeEnabled && _guaranteeDetailsCtrl.text.trim().isNotEmpty)
          'guarantee_details': _guaranteeDetailsCtrl.text.trim(),
      };

      // Add shipping destinations to payload (where product can be shipped TO)
      // IMPORTANT: Only send shipping countries if they exist in the list
      if (_shipping.isEmpty) {
        print('   ⚠️  No shipping destinations to add (list is empty)');
      } else {
        print('   → Processing ${_shipping.length} shipping destinations...');

        // Use a counter for valid shipping countries (some might be skipped)
        int validShippingIndex = 0;

        for (int i = 0; i < _shipping.length; i++) {
          final s = _shipping[i];

          final shippingTime = s.timeCtrl.text.trim();

          print(
            '   → Shipping Destination[$i]: country=${s.countryId}, state=${s.stateId}, city=${s.cityId}, time=$shippingTime, type=${s.timeType}',
          );

          // Validate shipping time before adding to payload
          if (shippingTime.isEmpty) {
            print(
              '   ⚠️  Warning: Shipping[$i] has empty shipping time, skipping',
            );
            continue;
          }

          // Ensure country_id is always present
          if (s.countryId == null) {
            print('   ⚠️  Warning: Shipping[$i] has no country_id, skipping');
            continue;
          }

          // Add shipping country data - use Laravel array format with valid index
          // Use validShippingIndex to ensure continuous indexing (0, 1, 2...) even if some are skipped
          payload['shippingCountries[$validShippingIndex][id]'] = s.id;
          payload['shippingCountries[$validShippingIndex][country_id]'] =
              s.countryId;
          payload['shippingCountries[$validShippingIndex][shipping_time]'] =
              shippingTime;
          payload['shippingCountries[$validShippingIndex][time_type]'] =
              s.timeType;

          // Optional: Add state and city if they exist
          if (s.stateId != null) {
            payload['shippingCountries[$validShippingIndex][state_id]'] =
                s.stateId;
          }
          if (s.cityId != null) {
            payload['shippingCountries[$validShippingIndex][city_id]'] =
                s.cityId;
          }

          print(
            '   ✓ Shipping Destination[$validShippingIndex] added to payload: country_id=${s.countryId}, time=$shippingTime, type=${s.timeType}',
          );

          // Increment valid index only after successfully adding
          validShippingIndex++;
        }

        print('   → Total shipping destinations in list: ${_shipping.length}');
        print(
          '   → Valid shipping destinations added to payload: $validShippingIndex',
        );
      }

      // Media

      if (_thumbnail != null) {
        print('   → Adding thumbnail: ${_thumbnail!.path}');
        payload['thumbnail'] = await MultipartFile.fromFile(
          _thumbnail!.path,

          filename: _thumbnail!.path.split('/').last,
        );
      }

      if (_gallery.isNotEmpty) {
        print('   → Adding ${_gallery.length} gallery images');
        payload['gallery[]'] = await Future.wait(
          _gallery.map(
            (f) => MultipartFile.fromFile(
              f.path,

              filename: f.path.split('/').last,
            ),
          ),
        );
      }

      // Count shipping destinations actually added to payload
      int shippingDestinationsAdded = 0;
      for (int i = 0; i < _shipping.length; i++) {
        final s = _shipping[i];
        final shippingTime = s.timeCtrl.text.trim();
        if (shippingTime.isNotEmpty && s.countryId != null) {
          shippingDestinationsAdded++;
        }
      }

      print('📦 [SUBMIT] Payload built with ${payload.length} fields');
      print('   → Payload keys count: ${payload.keys.length}');

      // Debug: Check if shipping destinations are in payload
      final shippingKeys = payload.keys
          .where((key) => key.toString().contains('shippingCountries'))
          .toList();
      print(
        '   → Shipping destination keys in payload: ${shippingKeys.length} keys',
      );
      print('   → Shipping destinations in list: ${_shipping.length}');
      print(
        '   → Shipping destinations added to payload: $shippingDestinationsAdded',
      );

      // Log all shipping country keys for debugging
      if (shippingKeys.isNotEmpty) {
        print(
          '   → Shipping keys: ${shippingKeys.take(10).join(', ')}${shippingKeys.length > 10 ? '...' : ''}',
        );
      }

      Response response;
      if (widget.productId == null) {
        print('📤 [SUBMIT] Creating new product');
        response = await ApiService().addVendorProduct(payload);
      } else {
        print('📤 [SUBMIT] Updating product ID: ${widget.productId}');
        response = await ApiService().updateVendorProduct(
          widget.productId!,
          payload,
        );
      }

      print('📥 [SUBMIT] Response received');
      print('   → Status Code: ${response.statusCode}');
      print('   → Response Data: ${response.data}');

      if (!mounted) return;

      // Check response status - handle 422 validation errors specially
      if (response.statusCode == 422) {
        // 422 Unprocessable Entity - Validation errors
        String errorMessage = 'Validation failed. Please check your input.';
        List<String> errorDetails = [];

        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;

          // Try to extract validation errors
          if (data.containsKey('errors') && data['errors'] is Map) {
            final errors = data['errors'] as Map;
            errors.forEach((key, value) {
              if (value is List) {
                errorDetails.addAll(value.map((e) => '$key: $e').toList());
              } else {
                errorDetails.add('$key: $value');
              }
            });
            if (errorDetails.isNotEmpty) {
              errorMessage = 'Validation Errors:\n${errorDetails.join('\n')}';
            }
          } else if (data.containsKey('message')) {
            errorMessage = data['message'].toString();
          } else if (data.containsKey('error')) {
            errorMessage = data['error'].toString();
          }
        }

        print('❌ [SUBMIT] Validation Error (422): $errorMessage');
        if (errorDetails.isNotEmpty) {
          print('   → Error details: $errorDetails');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        setState(() => _submitting = false);
        return;
      }

      // Check response status
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        final message = response.data is Map<String, dynamic>
            ? (response.data['message'] ??
                  (response.data['success'] == true
                      ? 'Product updated successfully'
                      : 'Product saved successfully'))
            : 'Product saved successfully';

        print('✅ [SUBMIT] Success: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        // Error response
        String errorMessage = 'Failed to save product';

        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;

          // Try to get error message
          if (data.containsKey('message')) {
            errorMessage = data['message'].toString();
          } else if (data.containsKey('error')) {
            errorMessage = data['error'].toString();
          } else if (data.containsKey('errors')) {
            // Handle validation errors
            final errors = data['errors'];
            if (errors is Map) {
              final errorList = <String>[];
              errors.forEach((key, value) {
                if (value is List) {
                  errorList.addAll(value.map((e) => e.toString()));
                } else {
                  errorList.add(value.toString());
                }
              });
              errorMessage = errorList.join('\n');
            } else if (errors is String) {
              errorMessage = errors;
            }
          }

          // Add status code to error message
          errorMessage = 'Status ${response.statusCode}: $errorMessage';
        } else if (response.statusMessage != null) {
          errorMessage =
              'Status ${response.statusCode}: ${response.statusMessage}';
        } else {
          errorMessage = 'Status ${response.statusCode}: $errorMessage';
        }

        print('❌ [SUBMIT] Error: $errorMessage');
        print('   → Full response: ${response.data}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ [SUBMIT] Exception occurred');
      print('   → Error: $e');
      print('   → Stack trace: $stackTrace');

      if (!mounted) return;

      String errorMessage = 'Save failed: ${e.toString()}';

      // Try to extract more meaningful error message from DioException
      try {
        // Check if it's a DioException by trying to access response
        final response = (e as dynamic).response;
        final statusCode = response?.statusCode;
        final responseData = response?.data;
        final errorType = (e as dynamic).type;
        final errorMessage_dio = (e as dynamic).message;

        if (responseData != null) {
          if (responseData is Map<String, dynamic>) {
            if (responseData.containsKey('message')) {
              errorMessage = responseData['message'].toString();
            } else if (responseData.containsKey('error')) {
              errorMessage = responseData['error'].toString();
            } else if (responseData.containsKey('errors')) {
              final errors = responseData['errors'];
              if (errors is Map) {
                final errorList = <String>[];
                errors.forEach((key, value) {
                  if (value is List) {
                    errorList.addAll(value.map((e) => e.toString()));
                  } else {
                    errorList.add(value.toString());
                  }
                });
                errorMessage = errorList.join('\n');
              } else if (errors is String) {
                errorMessage = errors;
              }
            }
          }
        }

        if (statusCode != null) {
          errorMessage = 'Status $statusCode: $errorMessage';
        } else if (errorType != null) {
          // Handle different error types
          final errorTypeStr = errorType.toString();
          if (errorTypeStr.contains('connectionTimeout') ||
              errorTypeStr.contains('receiveTimeout')) {
            errorMessage =
                'Connection timeout. Please check your internet connection.';
          } else if (errorTypeStr.contains('connectionError')) {
            errorMessage =
                'Connection error. Please check your internet connection.';
          } else if (errorMessage_dio != null) {
            errorMessage = 'Network error: $errorMessage_dio';
          }
        }
      } catch (_) {
        // If error parsing fails, use the original error message
        errorMessage = 'Save failed: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadExisting(int id) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('📥 [LOAD EXISTING] Starting to load product ID: $id');
      print('═══════════════════════════════════════════════════════════');

      print('   → Calling API: getVendorProduct($id)');
      final res = await ApiService().getVendorProduct(id);

      print('   → API Response Status: ${res.statusCode}');
      print('   → API Response Headers: ${res.headers}');

      final data = res.data;

      print('   → Raw Response Data Type: ${data.runtimeType}');

      Map<String, dynamic>? obj;

      if (data is Map<String, dynamic>) {
        print('   → Response is Map, checking structure...');
        print('   → Top-level keys: ${data.keys.toList()}');

        if (data.containsKey('data')) {
          print('   → Found "data" key in response');
          if (data['data'] is Map<String, dynamic>) {
            obj = data['data'] as Map<String, dynamic>;
            print('   → Using data["data"] as product object');
          } else {
            print(
              '   → data["data"] is not a Map, type: ${data['data'].runtimeType}',
            );
            obj = data;
            print('   → Using entire response as product object');
          }
        } else {
          print('   → No "data" key found, using entire response');
          obj = data;
        }
      } else {
        print('   → Response is not a Map, type: ${data.runtimeType}');
      }

      if (obj == null) {
        print('❌ [LOAD EXISTING] No product data found');
        print('   → Full response data: $data');
        return;
      }

      print('   → Product Object Keys: ${obj.keys.toList()}');
      print('   → Product Object Values:');
      obj.forEach((key, value) {
        if (value is List) {
          print('      • $key: List with ${value.length} items');
          if (value.isNotEmpty && value.first is Map) {
            print(
              '         → First item keys: ${(value.first as Map).keys.toList()}',
            );
          }
        } else if (value is Map) {
          print('      • $key: Map with keys: ${value.keys.toList()}');
        } else {
          print('      • $key: $value (${value.runtimeType})');
        }
      });

      // Wait for categories AND countries to be loaded first (if not already loaded)
      print('   → Checking categories list...');
      print('      • Categories loaded: ${_categories.length}');
      print('      • Categories loading: $_loadingCategories');

      if (_categories.isEmpty && !_loadingCategories) {
        print('   → Categories list is empty, fetching categories...');
        await _fetchCategories();
      } else if (_loadingCategories) {
        print('   → Categories are still loading, waiting...');
      } else {
        print('   → Categories already loaded: ${_categories.length} items');
      }

      // Wait for categories to finish loading (increase retries)
      int retries = 0;
      while (_loadingCategories && retries < 30 && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        if (retries % 5 == 0) {
          print('      • Still waiting for categories... (retry $retries/30)');
        }
      }

      if (_loadingCategories && mounted) {
        print('   ⚠️  Warning: Categories still loading after 30 retries');
      } else if (mounted) {
        print('   → Categories ready: ${_categories.length} items');
        if (_categories.isEmpty) {
          print(
            '   ⚠️  Warning: Categories list is still empty after loading!',
          );
        }
      }

      // Also wait for countries to be loaded (needed for shipping countries)
      print('   → Checking countries list...');
      print('      • Countries loaded: ${_countries.length}');
      print('      • Countries loading: $_loadingCountries');

      if (_countries.isEmpty && !_loadingCountries) {
        print('   → Countries list is empty, fetching countries...');
        await _fetchCountries();
      } else if (_loadingCountries) {
        print('   → Countries are still loading, waiting...');
      } else {
        print('   → Countries already loaded: ${_countries.length} items');
      }

      // Wait for countries to finish loading
      retries = 0;
      while (_loadingCountries && retries < 30 && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        if (retries % 5 == 0) {
          print('      • Still waiting for countries... (retry $retries/30)');
        }
      }

      if (_loadingCountries && mounted) {
        print('   ⚠️  Warning: Countries still loading after 30 retries');
      } else if (mounted) {
        print('   → Countries ready: ${_countries.length} items');
        if (_countries.isEmpty) {
          print('   ⚠️  Warning: Countries list is still empty after loading!');
        }
      }

      print('   → Setting basic fields...');
      setState(() {
        // Basic fields
        final name = (obj!['name'] ?? '').toString();
        final price = (obj['price'] ?? '').toString();
        final qty = (obj['quantity'] ?? obj['stock'] ?? '1').toString();
        final minQty = (obj['min_buying_qty'] ?? '1').toString();
        final shortSummary =
            (obj['short_summary'] ?? obj['short_description'] ?? '').toString();

        final description = (obj['description'] ?? '').toString();

        print('      • Name: "$name" (from: ${obj['name']})');
        print('      • Price: "$price" (from: ${obj['price']})');
        print(
          '      • Quantity: "$qty" (from: ${obj['quantity']} or ${obj['stock']})',
        );
        print('      • Min Qty: "$minQty" (from: ${obj['min_buying_qty']})');
        print(
          '      • Short Summary: "${shortSummary.length > 50 ? shortSummary.substring(0, 50) + "..." : shortSummary}"',
        );
        print(
          '      • Description: "${description.length > 50 ? description.substring(0, 50) + "..." : description}"',
        );

        _nameCtrl.text = name;
        _priceCtrl.text = price;
        _qtyCtrl.text = qty;
        _minQtyCtrl.text = minQty;
        _shortCtrl.text = shortSummary;
        _descCtrl.text = description;

        // Currency
        print('   → Setting currency...');
        if (obj['currency'] != null) {
          _currencyCode = obj['currency'].toString();
          print('      • Currency Code: $_currencyCode (from: currency)');
        } else if (obj['currency_symbol'] != null) {
          // Try to extract currency code from symbol
          final symbol = obj['currency_symbol'].toString();
          print('      • Currency Symbol: "$symbol" (from: currency_symbol)');
          // Map common symbols to codes (this might need adjustment based on your API)
          if (symbol == '\$')
            _currencyCode = 'USD';
          else if (symbol == '€')
            _currencyCode = 'EUR';
          else if (symbol == '£')
            _currencyCode = 'GBP';
          else {
            print(
              '      ⚠️  Unknown currency symbol: "$symbol", keeping default: $_currencyCode',
            );
          }
          print('      • Mapped Currency Code: $_currencyCode');
        } else {
          print(
            '      • No currency data found, keeping default: $_currencyCode',
          );
        }

        // Category - must be set after categories list is loaded
        print('   → Setting category...');
        if (obj['category_id'] != null) {
          final categoryId = (obj['category_id'] as num).toInt();
          // Try to get category name from API first, but if not available, look it up from loaded categories
          String? categoryName = obj['category_name']?.toString();
          print('      • Category ID from API: $categoryId');
          print('      • Category Name from API: "$categoryName"');

          // Check if category exists in loaded categories and get the name
          Map<String, dynamic>? foundCategory;
          try {
            foundCategory = _categories.firstWhere(
              (c) => (c['id'] as num).toInt() == categoryId,
            );
          } catch (_) {
            foundCategory = null;
          }

          final categoryExists = foundCategory != null;
          print('      • Category exists in list: $categoryExists');

          // If category name is not in API response, get it from loaded categories
          if (categoryName == null ||
              categoryName.isEmpty ||
              categoryName == 'null') {
            if (foundCategory != null) {
              categoryName = foundCategory['name']?.toString();
              print(
                '      • Category name retrieved from loaded list: "$categoryName"',
              );
            } else {
              print(
                '      ⚠️  Warning: Category ID $categoryId not found in categories list!',
              );
              print(
                '      • Available category IDs: ${_categories.map((c) => c['id']).toList()}',
              );
            }
          }

          _categoryId = categoryId;
          _selectedCategoryName = categoryName;
          if (_selectedCategoryName != null &&
              _selectedCategoryName!.isNotEmpty &&
              _selectedCategoryName != 'null') {
            _categorySearchCtrl.text = _selectedCategoryName!;
            print('      • Category search text set: "$_selectedCategoryName"');
          } else {
            print(
              '      ⚠️  Warning: Category name is null or empty, not setting search text',
            );
          }
          print(
            '   ✓ Category loaded: ID=$_categoryId, Name=$_selectedCategoryName',
          );
        } else {
          print('      • No category_id found in product data');
        }

        // Location (Product Origin) - IDs will be set after states/cities are loaded
        print('   → Setting location (Product Origin)...');
        if (obj['country_id'] != null) {
          _countryId = (obj['country_id'] as num).toInt();
          print('      • Country ID: $_countryId (from: country_id)');
        } else {
          print('      • No country_id found');
        }

        if (obj['state_id'] != null) {
          print(
            '      • State ID from API: ${obj['state_id']} (will be set after states load)',
          );
        } else {
          print('      • No state_id found');
        }

        if (obj['city_id'] != null) {
          print(
            '      • City ID from API: ${obj['city_id']} (will be set after cities load)',
          );
        } else {
          print('      • No city_id found');
        }
      });

      // After setting category, fetch subcategories (outside setState to avoid issues)
      print('   → Processing subcategory...');
      if (_categoryId != null && mounted) {
        print('   → Category ID is set: $_categoryId');
        print('   → Fetching subcategories for category ID: $_categoryId');

        // Clear existing subcategory before fetching new ones
        if (mounted) {
          setState(() {
            _subcategoryId = null;
            _selectedSubcategoryName = null;
            _subcategorySearchCtrl.clear();
          });
        }

        await _fetchSubcategories(_categoryId!);

        // Wait for subcategories to finish loading (increase retries)
        int retries = 0;
        while (_loadingSubcategories && retries < 20 && mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
          retries++;
          if (retries % 5 == 0) {
            print(
              '      • Still waiting for subcategories... (retry $retries/20)',
            );
          }
        }

        if (_loadingSubcategories) {
          print(
            '      ⚠️  Warning: Subcategories still loading after 20 retries',
          );
        }

        print('   → Subcategories loaded: ${_subcategories.length} items');
        if (_subcategories.isNotEmpty) {
          print(
            '      • Available subcategory IDs: ${_subcategories.map((s) => s['id']).toList()}',
          );
          print(
            '      • Available subcategory Names: ${_subcategories.map((s) => s['name']).toList()}',
          );
        } else {
          print(
            '      ⚠️  Warning: No subcategories found for category ID $_categoryId',
          );
        }

        // Now set subcategory after subcategories are loaded
        if (mounted && obj != null) {
          // Check for subcategory_id in various possible fields
          final subcategoryIdRaw =
              obj['subcategory_id'] ??
              obj['sub_category_id'] ??
              obj['subcategoryId'];
          final subcategoryNameRaw =
              obj['subcategory_name'] ??
              obj['sub_category_name'] ??
              obj['subcategoryName'] ??
              obj['subcategory']?['name'];

          print('      • Checking for subcategory data...');
          print('         → subcategory_id: $subcategoryIdRaw');
          print('         → subcategory_name: $subcategoryNameRaw');

          if (subcategoryIdRaw != null) {
            final subcategoryId = (subcategoryIdRaw as num).toInt();
            final subcategoryName = subcategoryNameRaw?.toString();
            print('      • Subcategory ID from API: $subcategoryId');
            print('      • Subcategory Name from API: "$subcategoryName"');

            // Check if subcategory exists in loaded subcategories
            final subcategoryExists = _subcategories.any(
              (s) => (s['id'] as num).toInt() == subcategoryId,
            );
            print('      • Subcategory exists in list: $subcategoryExists');
            if (!subcategoryExists && _subcategories.isNotEmpty) {
              print(
                '      ⚠️  Warning: Subcategory ID $subcategoryId not found in subcategories list!',
              );
              print(
                '      • Available subcategory IDs: ${_subcategories.map((s) => s['id']).toList()}',
              );
            } else if (subcategoryExists) {
              // Find the subcategory name from the list if not provided
              final foundSubcategory = _subcategories.firstWhere(
                (s) => (s['id'] as num).toInt() == subcategoryId,
              );
              final finalSubcategoryName =
                  subcategoryName ?? foundSubcategory['name']?.toString();

              print(
                '      • Found subcategory in list: ${foundSubcategory['name']}',
              );

              // Set subcategory values
              if (mounted) {
                setState(() {
                  _subcategoryId = subcategoryId;
                  _selectedSubcategoryName = finalSubcategoryName;
                  if (finalSubcategoryName != null &&
                      finalSubcategoryName.isNotEmpty) {
                    _subcategorySearchCtrl.text = finalSubcategoryName;
                  }
                  print(
                    '   ✓ Subcategory set: ID=$_subcategoryId, Name=$_selectedSubcategoryName',
                  );
                  print('   ✓ Controller text: ${_subcategorySearchCtrl.text}');
                });
              }
            }
          } else {
            print('      • No subcategory_id found in product data');
            print('      • Available keys in obj: ${obj.keys.toList()}');
            // Try to find subcategory in nested structures
            if (obj['category'] != null && obj['category'] is Map) {
              print('      • Found category object: ${obj['category']}');
            }
            if (obj['subcategory'] != null) {
              print('      • Found subcategory object: ${obj['subcategory']}');
            }
          }
        } else {
          print(
            '      • Skipping subcategory setting: mounted=$mounted, obj=${obj != null}',
          );
        }
      } else {
        print(
          '      • Skipping subcategory fetch: categoryId=$_categoryId, mounted=$mounted',
        );
      }

      // After setting country, fetch states and cities (outside setState)
      print('   → Processing location data...');
      if (_countryId != null && mounted && obj != null) {
        print('   → Fetching states for country ID: $_countryId');
        await _fetchStates(_countryId!);

        // Wait for states to finish loading
        int retries = 0;
        while (_loadingStates && retries < 10 && mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
          retries++;
          if (retries % 5 == 0) {
            print('      • Still waiting for states... (retry $retries/10)');
          }
        }

        print('   → States loaded: ${_states.length} items');
        if (_states.isNotEmpty) {
          print(
            '      • Available state IDs: ${_states.map((s) => s['id']).toList()}',
          );
        }

        // Now set state after states are loaded
        if (mounted && obj['state_id'] != null) {
          final stateId = (obj!['state_id'] as num).toInt();
          print('      • State ID from API: $stateId');

          // Check if state exists in loaded states
          final stateExists = _states.any((s) => s['id'] == stateId);
          print('      • State exists in list: $stateExists');
          if (!stateExists && _states.isNotEmpty) {
            print(
              '      ⚠️  Warning: State ID $stateId not found in states list!',
            );
          }

          setState(() {
            _stateId = stateId;
            print('   ✓ State set after loading: ID=$_stateId');
          });

          // Fetch cities for this state
          print('   → Fetching cities for state ID: $_stateId');
          await _fetchCities(_stateId!);

          // Wait for cities to finish loading
          retries = 0;
          while (_loadingCities && retries < 10 && mounted) {
            await Future.delayed(const Duration(milliseconds: 100));
            retries++;
            if (retries % 5 == 0) {
              print('      • Still waiting for cities... (retry $retries/10)');
            }
          }

          print('   → Cities loaded: ${_cities.length} items');
          if (_cities.isNotEmpty) {
            print(
              '      • Available city IDs: ${_cities.map((c) => c['id']).toList()}',
            );
          }

          // Now set city after cities are loaded
          if (mounted && obj['city_id'] != null) {
            final cityId = (obj!['city_id'] as num).toInt();
            print('      • City ID from API: $cityId');

            // Check if city exists in loaded cities
            final cityExists = _cities.any((c) => c['id'] == cityId);
            print('      • City exists in list: $cityExists');
            if (!cityExists && _cities.isNotEmpty) {
              print(
                '      ⚠️  Warning: City ID $cityId not found in cities list!',
              );
            }

            setState(() {
              _cityId = cityId;
              print('   ✓ City set after loading: ID=$_cityId');
            });
          } else {
            print('      • No city_id found in product data');
          }
        } else {
          print('      • No state_id found, skipping city loading');
        }
      } else {
        print(
          '      • Skipping location loading: countryId=$_countryId, mounted=$mounted',
        );
      }

      // Load guarantee and shipping countries in a separate setState
      print('   → Processing guarantee and shipping countries...');
      if (mounted && obj != null) {
        setState(() {
          // Guarantee
          print('      • Checking guarantee data...');
          final dynamic hasGuaranteeRaw =
              obj!['has_guarantee'] ??
              obj['guarantee_enabled'] ??
              obj['is_guarantee'];

          print('         → has_guarantee: ${obj['has_guarantee']}');
          print('         → guarantee_enabled: ${obj['guarantee_enabled']}');
          print('         → is_guarantee: ${obj['is_guarantee']}');
          print('         → Combined value: $hasGuaranteeRaw');

          if (hasGuaranteeRaw != null) {
            final bool hasGuarantee = hasGuaranteeRaw is bool
                ? hasGuaranteeRaw
                : hasGuaranteeRaw.toString() == '1' ||
                      hasGuaranteeRaw.toString().toLowerCase() == 'true';

            _guaranteeEnabled = hasGuarantee;

            print('         → Guarantee enabled: $_guaranteeEnabled');
          } else {
            print(
              '         → No guarantee data found, keeping default: $_guaranteeEnabled',
            );
          }

          if (_guaranteeEnabled) {
            _guaranteeType = (obj['guarantee_type'] ?? _guaranteeType)
                .toString();
            _guaranteeDurationCtrl.text =
                (obj['guarantee_duration_days'] ??
                        obj['guarantee_duration'] ??
                        '')
                    .toString();

            _guaranteeDetailsCtrl.text = (obj['guarantee_details'] ?? '')
                .toString();

            print('         → Guarantee type: $_guaranteeType');
            print(
              '         → Guarantee duration: ${_guaranteeDurationCtrl.text}',
            );
            print(
              '         → Guarantee details: "${_guaranteeDetailsCtrl.text.length > 30 ? _guaranteeDetailsCtrl.text.substring(0, 30) + "..." : _guaranteeDetailsCtrl.text}"',
            );
          }

          // Shipping Countries
          print('      • Checking shipping countries data...');
          print('         → shipping_countries: ${obj['shipping_countries']}');
          print('         → shippingCountries: ${obj['shippingCountries']}');
          print('         → shippingDetails: ${obj['shippingDetails']}');

          // Check for shippingDetails first (as returned by API), then fallback to other field names
          final shippingData =
              obj['shippingDetails'] ??
              obj['shipping_countries'] ??
              obj['shippingCountries'];

          if (shippingData != null) {
            print(
              '         → Shipping data found, type: ${shippingData.runtimeType}',
            );

            if (shippingData is List) {
              print(
                '         → Shipping data is a List with ${shippingData.length} items',
              );
              _shipping.clear();

              for (int i = 0; i < shippingData.length; i++) {
                final item = shippingData[i];
                print(
                  '         → Processing shipping item[$i]: ${item.runtimeType}',
                );

                if (item is Map<String, dynamic>) {
                  print('            → Item keys: ${item.keys.toList()}');
                  final countryId = item['country_id'];
                  final shippingTime =
                      item['shipping_time'] ?? item['shippingTime'] ?? '';
                  final timeType =
                      item['time_type'] ?? item['timeType'] ?? 'hours';
                  final stateId = item['state_id'];
                  final cityId = item['city_id'];

                  print('            → country_id: $countryId');
                  print('            → shipping_time: $shippingTime');
                  print('            → time_type: $timeType');
                  print('            → state_id: $stateId');
                  print('            → city_id: $cityId');

                  if (countryId != null && shippingTime.toString().isNotEmpty) {
                    _shipping.add(
                      _ShippingCountry(
                        id:
                            (item['id'] ??
                                    DateTime.now().millisecondsSinceEpoch)
                                .toString(),
                        countryId: (countryId as num).toInt(),
                        shippingTime: shippingTime.toString(),
                        timeType: timeType.toString(),
                      ),
                    );
                    print(
                      '            ✓ Shipping country[$i] added: country_id=$countryId, time=$shippingTime, type=$timeType',
                    );
                  } else {
                    print(
                      '            ⚠️  Skipping shipping country[$i]: missing country_id or shipping_time',
                    );
                  }
                } else {
                  print(
                    '            ⚠️  Shipping item[$i] is not a Map, skipping',
                  );
                }
              }
              print(
                '   ✓ Total shipping countries loaded: ${_shipping.length}',
              );
            } else {
              print(
                '         ⚠️  Shipping data is not a List, type: ${shippingData.runtimeType}',
              );
            }
          } else {
            print('      • No shipping countries data found');
          }
        });
      }

      print('═══════════════════════════════════════════════════════════');
      print('✅ [LOAD EXISTING] Product data loaded successfully');
      print('   → Final state:');
      print('      • Category ID: $_categoryId');
      print('      • Subcategory ID: $_subcategoryId');
      print('      • Country ID: $_countryId');
      print('      • State ID: $_stateId');
      print('      • City ID: $_cityId');
      print('      • Shipping countries: ${_shipping.length}');
      print('      • Guarantee enabled: $_guaranteeEnabled');
      print('═══════════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [LOAD EXISTING] Error loading product: $e');
      print('   → Error type: ${e.runtimeType}');
      print('   → Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
    }
  }

  Future<void> _fetchCategories() async {
    print('📂 [FETCH CATEGORIES] Starting fetch...');
    setState(() {
      _loadingCategories = true;

      _categories = const [];
    });

    try {
      print('   → Calling API: getCategories()');
      final res = await ApiService().getCategories();

      print('   → API Response Status: ${res.statusCode}');
      final data = res.data;

      print('   → Response Data Type: ${data.runtimeType}');

      List<dynamic> items = const [];

      if (data is Map<String, dynamic>) {
        print('   → Response is Map, keys: ${data.keys.toList()}');
        final root = data['data'];

        print('   → data field type: ${root.runtimeType}');
        if (root is Map<String, dynamic> && root['data'] is List) {
          items = root['data'] as List;

          print('   → Found nested data.data list with ${items.length} items');
        } else if (data['data'] is List) {
          items = data['data'] as List;

          print('   → Found data list with ${items.length} items');
        } else if (root is List) {
          items = root as List;
          print('   → Found data as direct list with ${items.length} items');
        }
      } else if (data is List) {
        items = data;

        print('   → Response is direct list with ${items.length} items');
      }

      print('   → Processing ${items.length} items...');
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

      print('   → Processed ${cats.length} valid categories');
      if (cats.isNotEmpty) {
        print('   → Category IDs: ${cats.map((c) => c['id']).toList()}');
        print('   → Category Names: ${cats.map((c) => c['name']).toList()}');
      } else {
        print('   ⚠️  Warning: No valid categories found!');
        print('   → Raw items: $items');
      }

      setState(() {
        _categories = cats;

        _loadingCategories = false;
      });

      print('   ✓ Categories loaded successfully: ${_categories.length} items');
    } catch (e, stackTrace) {
      print('   ❌ Error fetching categories: $e');
      print('   → Stack trace: $stackTrace');
      setState(() {
        _loadingCategories = false;
        _categories = const [];
      });
    }
  }

  Future<void> _fetchSubcategories(int categoryId) async {
    print(
      '📋 [FETCH SUBCATEGORIES] Starting fetch for category ID: $categoryId',
    );
    setState(() {
      _loadingSubcategories = true;

      _subcategories = const [];
    });

    try {
      print('   → Calling API: getSubcategories($categoryId)');
      final res = await ApiService().getSubcategories(categoryId);

      print('   → API Response Status: ${res.statusCode}');
      final data = res.data;

      print('   → Response Data Type: ${data.runtimeType}');

      List<dynamic> items = const [];

      if (data is Map<String, dynamic>) {
        print('   → Response is Map, keys: ${data.keys.toList()}');
        final root = data['data'];

        print('   → data field type: ${root.runtimeType}');
        if (root is Map<String, dynamic> && root['data'] is List) {
          items = root['data'] as List;

          print('   → Found nested data.data list with ${items.length} items');
        } else if (data['data'] is List) {
          items = data['data'] as List;

          print('   → Found data list with ${items.length} items');
        } else if (root is List) {
          items = root as List;
          print('   → Found data as direct list with ${items.length} items');
        }
      } else if (data is List) {
        items = data;

        print('   → Response is direct list with ${items.length} items');
      }

      print('   → Processing ${items.length} items...');
      final subs = items
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => {
              'id': e['id'] ?? e['subcategory_id'],

              'name': e['name'] ?? e['title'] ?? 'Unknown',
            },
          )
          .where((e) => e['id'] != null)
          .toList();

      print('   → Processed ${subs.length} valid subcategories');
      if (subs.isNotEmpty) {
        print('   → Subcategory IDs: ${subs.map((s) => s['id']).toList()}');
        print('   → Subcategory Names: ${subs.map((s) => s['name']).toList()}');
      } else {
        print('   ⚠️  Warning: No valid subcategories found!');
        print('   → Raw items: $items');
      }

      setState(() {
        _subcategories = subs;

        _loadingSubcategories = false;
      });

      print(
        '   ✓ Subcategories loaded successfully: ${_subcategories.length} items',
      );
    } catch (e, stackTrace) {
      print('   ❌ Error fetching subcategories: $e');
      print('   → Stack trace: $stackTrace');
      setState(() {
        _loadingSubcategories = false;
        _subcategories = const [];
      });
    }
  }

  Widget _buildCategoryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),

            child: Text(
              TranslationService().translate('vendorCreate.productCategory'),

              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          TextField(
            controller: _categorySearchCtrl,

            readOnly: true,

            enabled: !_loadingCategories,
            onTap: _loadingCategories ? null : _openCategoryPicker,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.category_outlined),

              hintText: _loadingCategories
                  ? TranslationService().translate(
                      'vendorCreate.loadingCategories',
                    )
                  : (_categorySearchCtrl.text.isEmpty
                        ? TranslationService().translate(
                            'vendorCreate.selectCategory',
                          )
                        : null),
              border: const OutlineInputBorder(),

              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  void _openCategoryPicker() {
    if (_loadingCategories) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('vendorCreate.categoriesStillLoading'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      print('   ⚠️  [CATEGORY PICKER] Categories are still loading');
      return;
    }

    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('vendorCreate.noCategoriesAvailable'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      print('   ⚠️  [CATEGORY PICKER] Categories list is empty!');
      print('   → Categories count: ${_categories.length}');
      print('   → Loading: $_loadingCategories');
      // Try to fetch categories again
      _fetchCategories();
      return;
    }

    print(
      '   → [CATEGORY PICKER] Opening with ${_categories.length} categories',
    );
    showModalBottomSheet<void>(
      context: context,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (context) {
        List<Map<String, dynamic>> filtered = List.from(_categories);

        final controller = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
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

                        setModalState(() {
                          filtered = _categories
                              .where(
                                (e) => (e['name'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(query),
                              )
                              .toList();
                        });
                      },

                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),

                        hintText: TranslationService().translate(
                          'vendorCreate.searchCategory',
                        ),

                        border: const OutlineInputBorder(),

                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: TranslatedText(
                                'vendorCreate.noCategoriesFound',
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,

                              itemCount: filtered.length,

                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = filtered[index];

                                return ListTile(
                                  leading: const Icon(Icons.label_outline),

                                  title: Text(item['name'].toString()),

                                  onTap: () {
                                    setState(() {
                                      _categoryId = (item['id'] as num).toInt();

                                      _selectedCategoryName = item['name']
                                          .toString();
                                      _categorySearchCtrl.text =
                                          _selectedCategoryName!;
                                      _subcategoryId = null;

                                      _selectedSubcategoryName = null;

                                      _subcategorySearchCtrl.clear();
                                    });

                                    _fetchSubcategories(_categoryId!);

                                    Navigator.pop(context);

                                    print(
                                      '   ✓ [CATEGORY PICKER] Selected: ${item['name']} (ID: ${item['id']})',
                                    );
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
      },
    );
  }

  Widget _buildSubcategoryField() {
    final enabled = _categoryId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),

            child: Text(
              'Product Subcategory',

              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          TextField(
            controller: _subcategorySearchCtrl,

            readOnly: true,

            enabled: enabled && !_loadingSubcategories,
            onTap: enabled && !_loadingSubcategories
                ? _openSubcategoryPicker
                : null,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.subdirectory_arrow_right_outlined),

              hintText: _loadingSubcategories
                  ? TranslationService().translate(
                      'vendorCreate.loadingSubcategories',
                    )
                  : (enabled
                        ? (_subcategorySearchCtrl.text.isEmpty
                              ? TranslationService().translate(
                                  'vendorCreate.selectSubcategory',
                                )
                              : null)
                        : TranslationService().translate(
                            'vendorCreate.selectCategoryFirst',
                          )),
              border: const OutlineInputBorder(),

              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  void _openSubcategoryPicker() {
    if (_loadingSubcategories) return;

    showModalBottomSheet<void>(
      context: context,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (context) {
        List<Map<String, dynamic>> filtered = List.from(_subcategories);

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

                    filtered = _subcategories
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

                    hintText: 'Search subcategory...',

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
                        leading: const Icon(Icons.label_important_outline),

                        title: Text(item['name'].toString()),

                        onTap: () {
                          setState(() {
                            _subcategoryId = (item['id'] as num).toInt();

                            _selectedSubcategoryName = item['name'].toString();

                            _subcategorySearchCtrl.text =
                                _selectedSubcategoryName!;
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

      // Check if response type is countries or if it's a direct list
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

      // Only process if type is 'countries' or if no type field exists (backward compatibility)
      if (responseType == null || responseType == 'countries') {
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
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          final items = (data['data'] as List)
              .whereType<Map<String, dynamic>>();
          list = items
              .map(
                (e) => {
                  'id': e['id'] ?? e['country_id'],

                  'name': e['name'] ?? e['country_name'] ?? e['title'],
                },
              )
              .where(
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        }

        setState(() {
          _countries = list;

          _loadingCountries = false;
        });
      } else {
        // Wrong type returned, don't process
        setState(() {
          _countries = const [];
          _loadingCountries = false;
        });
      }
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

      // Check if response type is states
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

      // Only process if type is 'states' or if no type field exists (backward compatibility)
      if (responseType == null || responseType == 'states') {
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
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          final items = (data['data'] as List)
              .whereType<Map<String, dynamic>>();
          list = items
              .map(
                (e) => {
                  'id': e['id'] ?? e['state_id'],

                  'name': e['name'] ?? e['state_name'] ?? e['title'],
                },
              )
              .where(
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        }

        setState(() {
          _states = list;

          _loadingStates = false;
        });
      } else {
        // Wrong type returned, don't process
        setState(() {
          _states = const [];
          _loadingStates = false;
        });
      }
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

      // Check if response type is cities
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

      // Only process if type is 'cities' or if no type field exists (backward compatibility)
      if (responseType == null || responseType == 'cities') {
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
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          final items = (data['data'] as List)
              .whereType<Map<String, dynamic>>();
          list = items
              .map(
                (e) => {
                  'id': e['id'] ?? e['city_id'],

                  'name': e['name'] ?? e['city_name'] ?? e['title'],
                },
              )
              .where(
                (e) =>
                    e['id'] != null && (e['name'] ?? '').toString().isNotEmpty,
              )
              .map((e) => {'id': (e['id'] as num).toInt(), 'name': e['name']})
              .toList();
        }

        setState(() {
          _cities = list;

          _loadingCities = false;
        });
      } else {
        // Wrong type returned (e.g., 'countries' when expecting 'cities'), don't process
        setState(() {
          _cities = const [];
          _loadingCities = false;
        });
      }
    } catch (_) {
      setState(() => _loadingCities = false);
    }
  }

  Widget _textField({
    required String label,

    required TextEditingController controller,

    String? hint,

    TextInputType? keyboardType,

    bool enabled = true,

    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),

        const SizedBox(height: 6),

        TextField(
          controller: controller,

          keyboardType: keyboardType,

          enabled: enabled,

          inputFormatters: inputFormatters,
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
            GestureDetector(
              onTap: _openCurrencyPicker,

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,

                  vertical: 14,
                ),

                decoration: BoxDecoration(
                  color: Colors.white,

                  border: Border.all(color: Colors.grey.shade300),

                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    if (_selectedCountryCode != null &&
                        _selectedCountryCode!.isNotEmpty)
                      Container(
                        width: 24,

                        height: 16,

                        margin: const EdgeInsets.only(right: 6),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),

                          border: Border.all(
                            color: Colors.grey.shade300,

                            width: .5,
                          ),
                        ),

                        clipBehavior: Clip.antiAlias,

                        child: CountryFlag.fromCountryCode(
                          _selectedCountryCode!,

                          height: 16,

                          width: 24,
                        ),
                      ),

                    Text(_currencyCode),

                    const SizedBox(width: 4),

                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
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

  void _openCurrencyPicker() {
    showModalBottomSheet<String>(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) => const CurrencySelectionDialog(),
    ).then((selected) {
      if (selected != null && selected.isNotEmpty && mounted) {
        setState(() {
          _currencyCode = selected;
        });

        // Also refresh stored country code for flag

        StorageService().getSelectedCountryCode().then((iso) {
          if (mounted) {
            setState(() {
              _selectedCountryCode = iso;
            });
          }
        });
      }
    });
  }

  Widget _multiline({
    required String label,

    required TextEditingController controller,

    int minLines = 3,

    bool enabled = true,
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

          enabled: enabled,

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

    this.countryId,
    String shippingTime = '',
    this.timeType = 'hours',
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

  // Flags to prevent multiple simultaneous loads (public for state management)
  bool loadingStates = false;
  bool loadingCities = false;
}
