import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/theme_config.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/translation_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/translated_text.dart';
import '../../widgets/currency_selection_dialog.dart';
import 'package:country_flags/country_flags.dart';
import '../../utils/responsive.dart';

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
  // Guarantee fields
  final TextEditingController _guaranteeDurationCtrl = TextEditingController();
  final TextEditingController _guaranteeDetailsCtrl = TextEditingController();
  bool _guaranteeEnabled = false;
  String _guaranteeType = 'Service';
  final List<String> _guaranteeTypes = const ['Replacement', 'Service'];
  // Normal product owner fields
  final TextEditingController _ownerNameCtrl = TextEditingController();
  final TextEditingController _ownerPhoneCtrl = TextEditingController();
  final TextEditingController _ownerCommentsCtrl = TextEditingController();

  bool _submitting = false;
  bool _loadingCategories = true;
  bool _loadingExisting = false;
  // Track if this is a normal product (can be set after loading existing product)
  bool _isNormalProduct = false;
  String? _categoriesError;
  List<Map<String, dynamic>> _categories = const [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final TextEditingController _categorySearchCtrl = TextEditingController();

  // Subcategories
  bool _loadingSubcategories = false;
  List<Map<String, dynamic>> _subcategories = const [];
  String? _selectedSubcategoryId;
  String? _selectedSubcategoryName;
  final TextEditingController _subcategorySearchCtrl = TextEditingController();

  // Media
  File? _thumbnail;
  final List<File> _gallery = [];
  String? _existingThumbnailUrl;
  final List<Map<String, dynamic>> _existingGalleryImages = []; // Store {id, url}
  int _step = 0; // 0: Basic Info, 1: Media

  // Currency
  String _currencyCode = 'USD';
  String? _selectedCountryCode; // for showing flag next to currency

  // Check if user has dropshipping_product permission
  bool _hasDropshippingPermission() {
    final user = AuthService().currentUser;
    if (user == null) return false;
    
    // Check both userPermissions and vendorPermissions
    final allPermissions = [
      ...user.userPermissions,
      ...user.vendorPermissions,
    ];
    
    return allPermissions.contains('dropshipping_product');
  }

  void initState() {
    super.initState();
    
    // Check permission before allowing access
    if (!_hasDropshippingPermission()) {
      // Permission check will be handled in build method
      return;
    }
    
    // Initialize _isNormalProduct from widget.isNormal (for new products)
    _isNormalProduct = widget.isNormal;
    // Load categories first, then load existing product if editing
    _loadCategories().then((_) {
      // Only load existing product after categories are loaded
      if (widget.productId != null) {
        _loadExistingProduct(widget.productId!);
      }
    });
    _loadDefaultCurrencyFromPrefs();
  }

  Future<void> _loadDefaultCurrencyFromPrefs() async {
    try {
      final storage = StorageService();
      String? saved = await storage.getSelectedCurrency();
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

  Future<void> _loadExistingProduct(int id) async {
    print('🔍 [EDIT PRODUCT] Loading existing product ID: $id');
    setState(() {
      _loadingExisting = true;
    });
    final api = ApiService();
    try {
      // Try dropshipping detail then vendor detail
      Map<String, dynamic>? obj;
      try {
        print('🔍 [EDIT PRODUCT] Trying dropshipping product API...');
        final res = await api.getDropshippingProduct(id);
        final data = res.data;
        print(
          '🔍 [EDIT PRODUCT] Dropshipping API response status: ${res.statusCode}',
        );
        if (data is Map<String, dynamic>) {
          obj = (data['data'] is Map<String, dynamic>) ? data['data'] : data;
          print('🔍 [EDIT PRODUCT] Found product data from dropshipping API');
        }
      } catch (e) {
        print('⚠️ [EDIT PRODUCT] Dropshipping API error: $e');
      }
      if (obj == null) {
        try {
          print('🔍 [EDIT PRODUCT] Trying vendor product API...');
          final res = await api.getVendorProduct(id);
          final data = res.data;
          print(
            '🔍 [EDIT PRODUCT] Vendor API response status: ${res.statusCode}',
          );
          if (data is Map<String, dynamic>) {
            obj = (data['data'] is Map<String, dynamic>) ? data['data'] : data;
            print('🔍 [EDIT PRODUCT] Found product data from vendor API');
          }
        } catch (e) {
          print('⚠️ [EDIT PRODUCT] Vendor API error: $e');
        }
      }

      if (obj != null) {
        print('✅ [EDIT PRODUCT] Product data loaded successfully');
        print(
          '🔍 [EDIT PRODUCT] Full product object keys: ${obj.keys.toList()}',
        );

        // Detect product type from API response
        // API now returns 'product_type', fallback to 'type' for backwards compatibility
        final productType =
            (obj['product_type'] ?? obj['type'])?.toString() ?? '';
        final detectedIsNormal = productType == 'point_regular_product';
        print('🔍 [EDIT PRODUCT] Product type from API: $productType');
        print('🔍 [EDIT PRODUCT] Raw type field: ${obj['type']}');
        print(
          '🔍 [EDIT PRODUCT] Raw product_type field: ${obj['product_type']}',
        );
        print('🔍 [EDIT PRODUCT] isNormal: $detectedIsNormal');

        // Update _isNormalProduct based on detected type
        setState(() {
          _isNormalProduct = detectedIsNormal;
        });

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

        // Load guarantee data
        _guaranteeEnabled = (obj['has_guarantee'] ?? 0) == 1;
        if (obj['guarantee'] is Map) {
          final guarantee = obj['guarantee'] as Map;
          _guaranteeType = (guarantee['type'] ?? 'Service').toString();
          _guaranteeDurationCtrl.text = (guarantee['duration'] ?? '').toString();
          _guaranteeDetailsCtrl.text = (guarantee['details'] ?? '').toString();
        } else {
          // Fallback: try direct fields
          _guaranteeType = (obj['guarantee_type'] ?? 'Service').toString();
          _guaranteeDurationCtrl.text = (obj['guarantee_duration'] ?? '').toString();
          _guaranteeDetailsCtrl.text = (obj['guarantee_details'] ?? '').toString();
        }

        // Load owner fields for normal products
        if (detectedIsNormal) {
          _ownerNameCtrl.text = (obj['owner_name'] ?? '').toString();
          _ownerPhoneCtrl.text = (obj['owner_phone'] ?? '').toString();
          _ownerCommentsCtrl.text =
              (obj['about_owner'] ?? obj['owner_comments'] ?? '').toString();
        }

        // Category mapping - check multiple possible field names
        String? incomingCategoryId;
        String? incomingCategoryName;

        // Try category_id first (snake_case)
        if (obj['category_id'] != null) {
          incomingCategoryId = obj['category_id'].toString();
        }
        // Try categoryId (camelCase)
        else if (obj['categoryId'] != null) {
          incomingCategoryId = obj['categoryId'].toString();
        }
        // Try category object with id field
        else if (obj['category'] is Map) {
          final catObj = obj['category'] as Map;
          if (catObj['id'] != null) {
            incomingCategoryId = catObj['id'].toString();
          }
        }

        // Try category_name first (snake_case)
        if (obj['category_name'] != null) {
          incomingCategoryName = obj['category_name'].toString();
        }
        // Try categoryName (camelCase)
        else if (obj['categoryName'] != null) {
          incomingCategoryName = obj['categoryName'].toString();
        }
        // Try category object with name field
        else if (obj['category'] is Map) {
          final catObj = obj['category'] as Map;
          if (catObj['name'] != null) {
            incomingCategoryName = catObj['name'].toString();
          }
        }
        // Try category as string
        else if (obj['category'] is String) {
          incomingCategoryName = obj['category'].toString();
        }

        print('🔍 [EDIT PRODUCT] Category data from API:');
        print('   - category_id (direct): ${obj['category_id']}');
        print('   - categoryId (camelCase): ${obj['categoryId']}');
        print('   - category object: ${obj['category']}');
        print('   - category_name (direct): ${obj['category_name']}');
        print('   - categoryName (camelCase): ${obj['categoryName']}');
        print('   - Final incomingCategoryId: $incomingCategoryId');
        print('   - Final incomingCategoryName: $incomingCategoryName');
        print('   - Loaded categories count: ${_categories.length}');

        if (incomingCategoryId != null && incomingCategoryId.isNotEmpty) {
          _selectedCategoryId = incomingCategoryId;
          print(
            '✅ [EDIT PRODUCT] Set category ID from API: $_selectedCategoryId',
          );

          // If we have category ID but no name, try to find name from loaded categories
          if ((incomingCategoryName == null || incomingCategoryName.isEmpty) &&
              _categories.isNotEmpty) {
            print(
              '🔍 [EDIT PRODUCT] Category ID found but no name - searching in loaded categories...',
            );
            try {
              final match = _categories.firstWhere(
                (e) => (e['id'] ?? '').toString() == incomingCategoryId,
                orElse: () => const {'name': null},
              );
              if (match['name'] != null) {
                _selectedCategoryName = match['name'].toString();
                print(
                  '✅ [EDIT PRODUCT] Found category name by ID: $_selectedCategoryName',
                );
              } else {
                print(
                  '⚠️ [EDIT PRODUCT] Category ID "$incomingCategoryId" not found in loaded categories',
                );
              }
            } catch (e) {
              print('❌ [EDIT PRODUCT] Error searching category name by ID: $e');
            }
          }
        }

        if (incomingCategoryName != null && incomingCategoryName.isNotEmpty) {
          _selectedCategoryName = incomingCategoryName.toString();
          print(
            '✅ [EDIT PRODUCT] Set category name from API: $_selectedCategoryName',
          );
        }

        // If we only have name, try to find id from loaded categories
        if ((_selectedCategoryId == null || _selectedCategoryId!.isEmpty) &&
            _selectedCategoryName != null &&
            _categories.isNotEmpty) {
          print(
            '🔍 [EDIT PRODUCT] Searching for category by name in loaded categories...',
          );
          try {
            final match = _categories.firstWhere(
              (e) => (e['name'] ?? '') == _selectedCategoryName,
              orElse: () => const {'id': null},
            );
            if (match['id'] != null) {
              _selectedCategoryId = match['id'].toString();
              print(
                '✅ [EDIT PRODUCT] Found category ID by name: $_selectedCategoryId',
              );
            } else {
              print(
                '⚠️ [EDIT PRODUCT] Category name "$_selectedCategoryName" not found in loaded categories',
              );
            }
          } catch (e) {
            print('❌ [EDIT PRODUCT] Error searching categories: $e');
          }
        } else if ((_selectedCategoryId == null ||
                _selectedCategoryId!.isEmpty) &&
            _selectedCategoryName != null) {
          print(
            '⚠️ [EDIT PRODUCT] Cannot match category by name - categories list is empty or still loading',
          );
        }

        _categorySearchCtrl.text = _selectedCategoryName ?? '';
        print('🔍 [EDIT PRODUCT] Final category selection:');
        print('   - Selected category ID: $_selectedCategoryId');
        print('   - Selected category name: $_selectedCategoryName');

        // Update UI after setting category fields
        if (mounted) {
          setState(() {
            // Trigger rebuild to show selected category in UI
          });
        }

        // Subcategory mapping - check multiple possible field names
        String? incomingSubcategoryId;
        String? incomingSubcategoryName;

        // Try subcategory_id first (snake_case)
        if (obj['subcategory_id'] != null) {
          incomingSubcategoryId = obj['subcategory_id'].toString();
        }
        // Try subcategoryId (camelCase)
        else if (obj['subcategoryId'] != null) {
          incomingSubcategoryId = obj['subcategoryId'].toString();
        }
        // Try subcategory object with id field
        else if (obj['subcategory'] is Map) {
          final subcatObj = obj['subcategory'] as Map;
          if (subcatObj['id'] != null) {
            incomingSubcategoryId = subcatObj['id'].toString();
          }
        }

        // Try subcategory_name first (snake_case)
        if (obj['subcategory_name'] != null) {
          incomingSubcategoryName = obj['subcategory_name'].toString();
        }
        // Try subcategoryName (camelCase)
        else if (obj['subcategoryName'] != null) {
          incomingSubcategoryName = obj['subcategoryName'].toString();
        }
        // Try subcategory object with name field
        else if (obj['subcategory'] is Map) {
          final subcatObj = obj['subcategory'] as Map;
          if (subcatObj['name'] != null) {
            incomingSubcategoryName = subcatObj['name'].toString();
          }
        }
        // Try subcategory as string
        else if (obj['subcategory'] is String) {
          incomingSubcategoryName = obj['subcategory'].toString();
        }

        print('🔍 [EDIT PRODUCT] Subcategory data from API:');
        print('   - subcategory_id (direct): ${obj['subcategory_id']}');
        print('   - subcategoryId (camelCase): ${obj['subcategoryId']}');
        print('   - subcategory object: ${obj['subcategory']}');
        print('   - subcategory_name (direct): ${obj['subcategory_name']}');
        print('   - subcategoryName (camelCase): ${obj['subcategoryName']}');
        print('   - Final incomingSubcategoryId: $incomingSubcategoryId');
        print('   - Final incomingSubcategoryName: $incomingSubcategoryName');

        if (incomingSubcategoryId != null && incomingSubcategoryId.isNotEmpty) {
          _selectedSubcategoryId = incomingSubcategoryId;
          print(
            '✅ [EDIT PRODUCT] Set subcategory ID from API: $_selectedSubcategoryId',
          );
        }
        if (incomingSubcategoryName != null &&
            incomingSubcategoryName.isNotEmpty) {
          _selectedSubcategoryName = incomingSubcategoryName.toString();
          print(
            '✅ [EDIT PRODUCT] Set subcategory name from API: $_selectedSubcategoryName',
          );
        }
        _subcategorySearchCtrl.text = _selectedSubcategoryName ?? '';

        // If we have a category ID, fetch subcategories (and wait for them to load before setting selected subcategory)
        if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
          final categoryIdInt = int.tryParse(_selectedCategoryId!);
          if (categoryIdInt != null) {
            print(
              '🔍 [EDIT PRODUCT] Fetching subcategories for category ID: $categoryIdInt',
            );
            await _fetchSubcategories(categoryIdInt);

            // After subcategories are loaded, try to match by ID or name
            if (_subcategories.isNotEmpty) {
              // If we have subcategory ID but no name, try to find name from loaded subcategories
              if ((_selectedSubcategoryId != null &&
                      _selectedSubcategoryId!.isNotEmpty) &&
                  (_selectedSubcategoryName == null ||
                      _selectedSubcategoryName!.isEmpty)) {
                print(
                  '🔍 [EDIT PRODUCT] Subcategory ID found but no name - searching in loaded subcategories...',
                );
                try {
                  final match = _subcategories.firstWhere(
                    (e) => (e['id'] ?? '').toString() == _selectedSubcategoryId,
                    orElse: () => const {'name': null},
                  );
                  if (match['name'] != null) {
                    _selectedSubcategoryName = match['name'].toString();
                    _subcategorySearchCtrl.text = _selectedSubcategoryName!;
                    print(
                      '✅ [EDIT PRODUCT] Found subcategory name by ID: $_selectedSubcategoryName',
                    );
                  }
                } catch (e) {
                  print(
                    '❌ [EDIT PRODUCT] Error searching subcategory name by ID: $e',
                  );
                }
              }

              // If we have subcategory name but no ID, try to match it
              if ((_selectedSubcategoryId == null ||
                      _selectedSubcategoryId!.isEmpty) &&
                  _selectedSubcategoryName != null &&
                  _selectedSubcategoryName!.isNotEmpty) {
                print(
                  '🔍 [EDIT PRODUCT] Searching for subcategory by name in loaded subcategories...',
                );
                try {
                  final match = _subcategories.firstWhere(
                    (e) => (e['name'] ?? '') == _selectedSubcategoryName,
                    orElse: () => const {'id': null},
                  );
                  if (match['id'] != null) {
                    _selectedSubcategoryId = match['id'].toString();
                    print(
                      '✅ [EDIT PRODUCT] Found subcategory ID by name: $_selectedSubcategoryId',
                    );
                  } else {
                    print(
                      '⚠️ [EDIT PRODUCT] Subcategory name "$_selectedSubcategoryName" not found in loaded subcategories',
                    );
                  }
                } catch (e) {
                  print('❌ [EDIT PRODUCT] Error searching subcategories: $e');
                }
              }
            }
          }
        } else {
          print(
            '⚠️ [EDIT PRODUCT] Cannot fetch subcategories - no valid category ID',
          );
        }

        print('🔍 [EDIT PRODUCT] Final subcategory selection:');
        print('   - Selected subcategory ID: $_selectedSubcategoryId');
        print('   - Selected subcategory name: $_selectedSubcategoryName');

        // Update UI after setting all fields
        if (mounted) {
          setState(() {
            // Trigger rebuild to show selected category and subcategory in UI
          });
        }

        // Existing media (for preview)
        final thumb = obj['thumbnail'] ?? obj['thumb'] ?? obj['image'];
        if (thumb is String && thumb.isNotEmpty) {
          _existingThumbnailUrl = thumb;
        } else if (obj['medias'] is Map<String, dynamic>) {
          final m = obj['medias'] as Map<String, dynamic>;
          if (m['thumbnail'] is String) _existingThumbnailUrl = m['thumbnail'];
        }

        // Gallery can be in medias map, or gallery list/array
        // Extract image IDs along with URLs for delete functionality
        _existingGalleryImages.clear();
        if (obj['gallery'] is List) {
          for (final it in (obj['gallery'] as List)) {
            String? url;
            int? imageId;
            
            if (it is String) {
              url = it;
            } else if (it is Map) {
              url = it['url'] as String?;
              // Try to extract ID from various possible field names
              if (it['id'] != null) {
                imageId = (it['id'] is int) ? it['id'] : int.tryParse(it['id'].toString());
              } else if (it['image_id'] != null) {
                imageId = (it['image_id'] is int) ? it['image_id'] : int.tryParse(it['image_id'].toString());
              }
            }
            
            if (url != null && url.isNotEmpty) {
              _existingGalleryImages.add({
                'id': imageId,
                'url': url,
              });
            }
          }
        } else if (obj['medias'] is Map<String, dynamic>) {
          final m = obj['medias'] as Map<String, dynamic>;
          final g = m['gallery'];
          if (g is List) {
            for (final it in g) {
              String? url;
              int? imageId;
              
              if (it is String) {
                url = it;
              } else if (it is Map) {
                url = it['url'] as String?;
                // Try to extract ID from various possible field names
                if (it['id'] != null) {
                  imageId = (it['id'] is int) ? it['id'] : int.tryParse(it['id'].toString());
                } else if (it['image_id'] != null) {
                  imageId = (it['image_id'] is int) ? it['image_id'] : int.tryParse(it['image_id'].toString());
                }
              }
              
              if (url != null && url.isNotEmpty) {
                _existingGalleryImages.add({
                  'id': imageId,
                  'url': url,
                });
              }
            }
          } else if (g is Map<String, dynamic>) {
            // Handle case where gallery is a map with IDs as keys
            g.forEach((key, value) {
              String? url;
              int? imageId;
              
              if (value is String) {
                url = value;
                imageId = int.tryParse(key);
              } else if (value is Map) {
                url = value['url'] as String?;
                imageId = int.tryParse(key);
              }
              
              if (url != null && url.isNotEmpty) {
                _existingGalleryImages.add({
                  'id': imageId,
                  'url': url,
                });
              }
            });
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
    print('📂 [CATEGORIES] Starting to load categories...');
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      List<dynamic> allItems = [];
      int currentPage = 1;
      bool hasMore = true;

      // Load all pages of categories
      while (hasMore) {
        print('📂 [CATEGORIES] Loading page $currentPage...');
        final res = await ApiService().getCategories(page: currentPage);
        print('📂 [CATEGORIES] API response status: ${res.statusCode}');
        final data = res.data;
        print('📂 [CATEGORIES] Response data type: ${data.runtimeType}');

        List<dynamic> items = const [];
        Map<String, dynamic>? paginationData;

        if (data is List) {
          items = data;
          print('📂 [CATEGORIES] Data is List, items count: ${items.length}');
        } else if (data is Map<String, dynamic>) {
          print('📂 [CATEGORIES] Data is Map, keys: ${data.keys.toList()}');

          // Handle {success: true, data: {data: [...]}} structure (same as products API)
          if (data['success'] != null && data['data'] is Map<String, dynamic>) {
            final innerData = data['data'] as Map<String, dynamic>;
            print(
              '📂 [CATEGORIES] Found success wrapper, checking inner data...',
            );
            if (innerData['data'] is List) {
              items = innerData['data'] as List;
              paginationData = innerData as Map<String, dynamic>?;
              print(
                '📂 [CATEGORIES] Found categories in success.data.data, count: ${items.length}',
              );
            } else if (innerData['categories'] is List) {
              items = innerData['categories'] as List;
              print(
                '📂 [CATEGORIES] Found categories in success.data.categories, count: ${items.length}',
              );
            }
          }
          // Handle {data: {data: [...]}} structure
          else if (data['data'] is Map && (data['data'] as Map)['data'] is List) {
            items = (data['data'] as Map)['data'] as List;
            paginationData = data['data'] as Map<String, dynamic>?;
            print(
              '📂 [CATEGORIES] Found categories in data.data, count: ${items.length}',
            );
          }
          // Handle {data: []} structure
          else if (data['data'] is List) {
            items = data['data'] as List;
            print(
              '📂 [CATEGORIES] Found categories in data, count: ${items.length}',
            );
          }
          // Handle {categories: []} structure
          else if (data['categories'] is List) {
            items = data['categories'] as List;
            print(
              '📂 [CATEGORIES] Found categories in categories, count: ${items.length}',
            );
          } else {
            print('⚠️ [CATEGORIES] Could not find categories array in response');
          }
        }

        allItems.addAll(items);

        // Check pagination metadata to determine if there are more pages
        if (paginationData != null) {
          final nextPageUrl = paginationData['next_page_url'];
          if (nextPageUrl != null) {
            hasMore = true;
          } else {
            final currentPageNum = paginationData['current_page'] as int?;
            final lastPage = paginationData['last_page'] as int?;
            if (currentPageNum != null && lastPage != null) {
              hasMore = currentPageNum < lastPage;
            } else {
              hasMore = items.length >= 10; // Assume 10 per page if no metadata
            }
          }
        } else {
          // If no pagination metadata, check if we got a full page
          hasMore = items.length >= 10;
        }

        currentPage++;
        print('📂 [CATEGORIES] Loaded page ${currentPage - 1}: ${items.length} items (Total: ${allItems.length})');
        
        // Safety check to prevent infinite loops
        if (currentPage > 100) {
          print('📂 [CATEGORIES] Safety limit reached, stopping pagination');
          break;
        }
      }

      final cats = allItems
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => {
              'id': (e['id'] ?? e['category_id']).toString(),
              'name': (e['name'] ?? e['title'] ?? '').toString(),
            },
          )
          .where((e) => e['name']!.isNotEmpty)
          .toList();

      print('📂 [CATEGORIES] Processed categories count: ${cats.length}');
      if (cats.isNotEmpty) {
        print('📂 [CATEGORIES] First few categories:');
        for (int i = 0; i < (cats.length > 3 ? 3 : cats.length); i++) {
          print('   - ${cats[i]['id']}: ${cats[i]['name']}');
        }
      }

      // Fallback hardcoded minimal set if empty (ensures selectable values)
      final fallback = [
        {'id': '1', 'name': 'Electronics'},
        {'id': '2', 'name': 'Smartphones'},
        {'id': '3', 'name': 'Laptops'},
        {'id': '4', 'name': 'Tablets'},
      ];

      final finalCategories = cats.isNotEmpty ? cats : fallback;
      print(
        '📂 [CATEGORIES] Final categories to use: ${finalCategories.length} (${cats.isNotEmpty ? "from API" : "fallback"})',
      );

      setState(() {
        _categories = finalCategories;
        _selectedCategoryId = null; // no default selection
        _selectedCategoryName = null;
        _loadingCategories = false;
      });
      print('✅ [CATEGORIES] Categories loaded successfully');
    } catch (e) {
      print('❌ [CATEGORIES] Error loading categories: $e');
      setState(() {
        _categoriesError = 'Failed to load categories';
        _loadingCategories = false;
      });
    }
  }

  Future<void> _submit() async {
    // Check permission before submitting
    if (!_hasDropshippingPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to add or edit dropshipping products'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      if (_step != 0) setState(() => _step = 0);
      return;
    }
    
    // Additional validation for guarantee fields when enabled
    if (_guaranteeEnabled) {
      if (_guaranteeDurationCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService().translate('dropshipping.required') + 
              ': ' + TranslationService().translate('vendorCreate.guaranteeDuration'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (_step != 0) setState(() => _step = 0);
        return;
      }
      if (_guaranteeDetailsCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService().translate('dropshipping.required') + 
              ': ' + TranslationService().translate('vendorCreate.guaranteeDetails'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (_step != 0) setState(() => _step = 0);
        return;
      }
    }
    
    setState(() => _submitting = true);

    try {
      final api = ApiService();
      final Map<String, dynamic> payload = {
        if (!_isNormalProduct) 'product_link': _productLinkCtrl.text.trim(),
        'type': _isNormalProduct
            ? 'point_regular_product'
            : 'point_web_product',
        'name': _nameCtrl.text.trim(),
        'category_id': _selectedCategoryId ?? '',
        if (_selectedSubcategoryId != null &&
            _selectedSubcategoryId!.isNotEmpty)
          'subcategory_id': _selectedSubcategoryId,
        'price': _priceCtrl.text.trim(),
        'currency': _currencyCode,
        'quantity': _quantityCtrl.text.trim(),
        'min_buying_qty': _minQtyCtrl.text.trim(),
        'short_summary': _shortSummaryCtrl.text.trim().isEmpty
            ? 'N/A'
            : _shortSummaryCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'has_guarantee': _guaranteeEnabled ? 1 : 0,
        // Always send guarantee fields (the backend expects them)
        // Send actual values if guarantee is enabled, empty strings if disabled
        'guarantee[type]': _guaranteeEnabled ? _guaranteeType : '',
        'guarantee[duration]': _guaranteeEnabled
            ? _guaranteeDurationCtrl.text.trim()
            : '',
        'guarantee[details]': _guaranteeEnabled
            ? _guaranteeDetailsCtrl.text.trim()
            : '',
        if (_isNormalProduct) ...{
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
          SnackBar(
            content: TranslatedText(
              'dropshipping.productSubmittedForProcessing',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService().translate(
                'dropshipping.failed',
                params: {'code': res.statusCode.toString()},
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService().translate(
              'dropshipping.error',
              params: {'error': e.toString()},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check permission and show error if not authorized
    if (!_hasDropshippingPermission()) {
      return Scaffold(
        appBar: CustomAppBar(
          title: TranslationService().translate('dropshipping.createProduct'),
          isDark: true,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.red),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  'Access Denied',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                const Text(
                  'You do not have permission to add or edit dropshipping products.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: TranslatedText('app.back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: TranslationService().translate('dropshipping.createProduct'),
        isDark: true,
        actions: const [], // Remove profile icon from top menu
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
                if (!_isNormalProduct)
                  _buildText(
                    TranslationService().translate('dropshipping.productLink'),
                    _productLinkCtrl,
                    hint: TranslationService().translate(
                      'dropshipping.productLinkHint',
                    ),
                    requiredField: true,
                  ),
                const SizedBox(height: AppTheme.spacingSmall),
                _buildSectionTitle(
                  TranslationService().translate(
                    'dropshipping.basicInformation',
                  ),
                ),
                if (_isNormalProduct) ...[
                  _subSectionBar(
                    TranslationService().translate('dropshipping.ownerDetails'),
                  ),
                  const SizedBox(height: 8),
                  ResponsivePair(
                    first: _buildText(
                      TranslationService().translate('dropshipping.ownerName'),
                      _ownerNameCtrl,
                      hint: TranslationService().translate(
                        'dropshipping.ownerNameHint',
                      ),
                      requiredField: true,
                    ),
                    second: _buildText(
                      TranslationService().translate('dropshipping.ownerPhone'),
                      _ownerPhoneCtrl,
                      hint: TranslationService().translate(
                        'dropshipping.ownerPhoneHint',
                      ),
                      requiredField: true,
                      keyboard: TextInputType.phone,
                    ),
                  ),
                  _buildText(
                    TranslationService().translate('dropshipping.comments'),
                    _ownerCommentsCtrl,
                    hint: TranslationService().translate(
                      'dropshipping.commentsHint',
                    ),
                    maxLines: 3,
                  ),
                  _subSectionBar(
                    TranslationService().translate(
                      'dropshipping.productDetails',
                    ),
                  ),
                ],
                _buildText(
                  TranslationService().translate('vendor.productTitle'),
                  _nameCtrl,
                  requiredField: true,
                ),
                _buildCategoryField(),
                _buildSubcategoryField(),
                // Price field
                _buildPriceField(),
                
                const SizedBox(height: AppTheme.spacingMedium),
                
                // Minimum Order Quantity - full width like vendor screen
                _buildText(
                  TranslationService().translate(
                    'dropshipping.minimumOrderQuantity',
                  ),
                  _minQtyCtrl,
                  requiredField: true,
                  keyboard: TextInputType.number,
                ),
                
                // Product Quantity - full width like vendor screen
                _buildText(
                  TranslationService().translate(
                    'dropshipping.productQuantity',
                  ),
                  _quantityCtrl,
                  requiredField: true,
                  keyboard: TextInputType.number,
                ),
                _buildGuaranteeSection(),
                _buildText(
                  TranslationService().translate(
                    'dropshipping.productShortSummary',
                  ),
                  _shortSummaryCtrl,
                  maxLines: 3,
                ),
                _buildText(
                  TranslationService().translate(
                    'dropshipping.productDescription',
                  ),
                  _descriptionCtrl,
                  maxLines: 6,
                ),
              ] else ...[
                _buildSectionTitle(
                  TranslationService().translate('dropshipping.media'),
                ),
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
                          child: TranslatedText('dropshipping.back'),
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
                                  Text(
                                    _step == 0
                                        ? TranslationService().translate(
                                            'dropshipping.next',
                                          )
                                        : TranslationService().translate(
                                            'dropshipping.uploadProduct',
                                          ),
                                  ),
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
            return TranslationService().translate('dropshipping.required');
          }
          // Additional validation for number fields
          if (keyboard == TextInputType.number && v != null && v.trim().isNotEmpty) {
            final intVal = int.tryParse(v.trim());
            if (intVal == null || intVal < 1) {
              return TranslationService().translate('dropshipping.mustBeOneOrMore');
            }
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
              child: TranslatedText('dropshipping.retry'),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              TranslationService().translate('dropshipping.chooseCategories'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextFormField(
            controller: _categorySearchCtrl,
            readOnly: true,
            enabled: !_loadingCategories && _categories.isNotEmpty,
            onTap: (!_loadingCategories && _categories.isNotEmpty)
                ? _openCategoryPicker
                : null,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _loadingCategories
                  ? 'Loading categories...'
                  : (_categories.isEmpty
                        ? 'No categories available'
                        : (_selectedCategoryName ??
                              TranslationService().translate(
                                'dropshipping.searchCategory',
                              ))),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            validator: (_) => (_selectedCategoryId == null)
                ? TranslationService().translate('dropshipping.required')
                : null,
          ),
          if (!_loadingCategories && _categories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Categories not available. Please try again.',
                style: TextStyle(color: Colors.orange[700], fontSize: 12),
              ),
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
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: TranslationService().translate(
                      'dropshipping.searchCategory',
                    ),
                    border: const OutlineInputBorder(),
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
                            _categorySearchCtrl.text = _selectedCategoryName!;
                            // Clear subcategory when category changes
                            _selectedSubcategoryId = null;
                            _selectedSubcategoryName = null;
                            _subcategorySearchCtrl.clear();
                            _subcategories = const [];
                          });
                          // Fetch subcategories for selected category
                          final categoryIdInt = int.tryParse(
                            _selectedCategoryId!,
                          );
                          if (categoryIdInt != null) {
                            _fetchSubcategories(categoryIdInt);
                          }
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

  Future<void> _fetchSubcategories(int categoryId) async {
    print(
      '📂 [SUBCATEGORIES] Starting to fetch subcategories for category ID: $categoryId',
    );
    setState(() {
      _loadingSubcategories = true;
      _subcategories = const [];
    });

    try {
      final res = await ApiService().getSubcategories(categoryId);
      print('📂 [SUBCATEGORIES] API response status: ${res.statusCode}');
      final data = res.data;
      print('📂 [SUBCATEGORIES] Response data type: ${data.runtimeType}');

      List<dynamic> items = const [];
      if (data is List) {
        items = data;
        print('📂 [SUBCATEGORIES] Data is List, items count: ${items.length}');
      } else if (data is Map<String, dynamic>) {
        print('📂 [SUBCATEGORIES] Data is Map, keys: ${data.keys.toList()}');

        // Handle {success: true, data: {data: [...]}} structure (same as products/categories API)
        if (data['success'] != null && data['data'] is Map<String, dynamic>) {
          final innerData = data['data'] as Map<String, dynamic>;
          print(
            '📂 [SUBCATEGORIES] Found success wrapper, checking inner data...',
          );
          if (innerData['data'] is List) {
            items = innerData['data'] as List;
            print(
              '📂 [SUBCATEGORIES] Found subcategories in success.data.data, count: ${items.length}',
            );
          } else if (innerData['subcategories'] is List) {
            items = innerData['subcategories'] as List;
            print(
              '📂 [SUBCATEGORIES] Found subcategories in success.data.subcategories, count: ${items.length}',
            );
          }
        }
        // Handle {data: {data: [...]}} structure
        else if (data['data'] is Map && (data['data'] as Map)['data'] is List) {
          items = (data['data'] as Map)['data'] as List;
          print(
            '📂 [SUBCATEGORIES] Found subcategories in data.data, count: ${items.length}',
          );
        }
        // Handle {data: []} structure
        else if (data['data'] is List) {
          items = data['data'] as List;
          print(
            '📂 [SUBCATEGORIES] Found subcategories in data, count: ${items.length}',
          );
        }
        // Handle {subcategories: []} structure
        else if (data['subcategories'] is List) {
          items = data['subcategories'] as List;
          print(
            '📂 [SUBCATEGORIES] Found subcategories in subcategories, count: ${items.length}',
          );
        } else {
          print(
            '⚠️ [SUBCATEGORIES] Could not find subcategories array in response',
          );
        }
      }

      final subs = items
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => {
              'id': (e['id'] ?? e['subcategory_id']).toString(),
              'name': (e['name'] ?? e['title'] ?? '').toString(),
            },
          )
          .where((e) => e['name']!.isNotEmpty)
          .toList();

      print('📂 [SUBCATEGORIES] Processed subcategories count: ${subs.length}');
      if (subs.isNotEmpty) {
        print('📂 [SUBCATEGORIES] First few subcategories:');
        for (int i = 0; i < (subs.length > 3 ? 3 : subs.length); i++) {
          print('   - ${subs[i]['id']}: ${subs[i]['name']}');
        }
      }

      setState(() {
        _subcategories = subs;
        _loadingSubcategories = false;
      });
      print('✅ [SUBCATEGORIES] Subcategories loaded successfully');
    } catch (e) {
      print('❌ [SUBCATEGORIES] Error loading subcategories: $e');
      setState(() {
        _loadingSubcategories = false;
        _subcategories = const [];
      });
    }
  }

  Widget _buildSubcategoryField() {
    final enabled =
        _selectedCategoryId != null && _selectedCategoryId!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Product Subcategory',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextFormField(
            controller: _subcategorySearchCtrl,
            readOnly: true,
            enabled: enabled && !_loadingSubcategories,
            onTap: enabled && !_loadingSubcategories
                ? _openSubcategoryPicker
                : null,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.subdirectory_arrow_right_outlined),
              hintText: _loadingSubcategories
                  ? 'Loading subcategories...'
                  : (enabled
                        ? (_subcategorySearchCtrl.text.isEmpty
                              ? 'Select subcategory...'
                              : null)
                        : 'Select category first...'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  void _openSubcategoryPicker() {
    if (_loadingSubcategories || _subcategories.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        List<Map<String, dynamic>> filtered = List.from(_subcategories);
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
                          filtered = _subcategories
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
                          'dropshipping.searchSubcategory',
                        ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: TranslatedText(
                                'dropshipping.noSubcategoriesFound',
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
                                  leading: const Icon(
                                    Icons.label_important_outline,
                                  ),
                                  title: Text(item['name'] ?? item['id']),
                                  onTap: () {
                                    setState(() {
                                      _selectedSubcategoryId = item['id']
                                          .toString();
                                      _selectedSubcategoryName =
                                          (item['name'] ?? '').toString();
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
      },
    );
  }

  Widget _buildStepperTabs() {
    return Wrap(
      spacing: AppTheme.spacingMedium,
      runSpacing: AppTheme.spacingSmall,
      children: [
        _buildStepChip(
          1,
          TranslationService().translate('dropshipping.basicInfo'),
          active: _step == 0,
        ),
        _buildStepChip(
          2,
          TranslationService().translate('dropshipping.media'),
          active: _step == 1,
        ),
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
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: TranslationService().translate('dropshipping.productPrice'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              children: [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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
                    borderRadius: BorderRadius.circular(
                      AppTheme.radiusMedium,
                    ),
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
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final txt = (v ?? '').trim();
                    if (txt.isEmpty)
                      return TranslationService().translate(
                        'dropshipping.required',
                      );
                    final numVal = num.tryParse(txt);
                    if (numVal == null || numVal <= 0)
                      return TranslationService().translate(
                        'dropshipping.enterValidAmount',
                      );
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
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
            // Guarantee Type Dropdown
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TranslationService().translate('vendorCreate.guaranteeType'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _guaranteeType,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMedium,
                        vertical: AppTheme.spacingMedium,
                      ),
                    ),
                    items: _guaranteeTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          TranslationService().translate(
                            'vendorCreate.${type.toLowerCase()}',
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _guaranteeType = value;
                        });
                      }
                    },
                    validator: (v) {
                      if (_guaranteeEnabled && (v == null || v.isEmpty)) {
                        return TranslationService().translate('dropshipping.required');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            // Guarantee Duration
            _buildText(
              TranslationService().translate('vendorCreate.guaranteeDuration'),
              _guaranteeDurationCtrl,
              hint: TranslationService().translate('vendorCreate.guaranteeDurationHint'),
              requiredField: true,
              keyboard: TextInputType.number,
            ),
            // Guarantee Details
            _buildText(
              TranslationService().translate('vendorCreate.guaranteeDetails'),
              _guaranteeDetailsCtrl,
              maxLines: 3,
              requiredField: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaPickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mediaSectionTitle(
          TranslationService().translate('vendor.addProductThumbnail'),
        ),
        const SizedBox(height: 6),
        _uploadZone(
          height: 160,
          onTap: () => _showImageSourceDialog(isThumbnail: true),
          child: _buildThumbnailPreview(),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        _mediaSectionTitle(
          TranslationService().translate('vendor.addProductGallery'),
        ),
        const SizedBox(height: 6),
        _uploadZone(
          height: 160,
          onTap: () => _showImageSourceDialog(isThumbnail: false),
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
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to add image',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Camera or Gallery • Max 5MB',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
          ),
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
    final hasExisting = _existingGalleryImages.isNotEmpty;
    if (!hasNew && !hasExisting) return _uploadHint();

    final totalCount = _existingGalleryImages.length + _gallery.length;
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount + 1, // +1 for the add more button
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // Show "Add More" button at the end
          if (index == totalCount) {
            return GestureDetector(
              onTap: () => _showImageSourceDialog(isThumbnail: false),
              child: Container(
                width: 120,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_circle_outline,
                        size: 32,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add More',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (index < _existingGalleryImages.length) {
            // Existing image with delete API functionality
            final imageData = _existingGalleryImages[index];
            final url = imageData['url'] as String;
            final imageId = imageData['id'] as int?;

            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 120,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 120,
                        height: 140,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () async {
                      // Only allow deletion if we have an image ID
                      if (imageId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot delete image: No image ID available'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: TranslatedText('vendorCreate.deleteImage'),
                          content: TranslatedText('vendorCreate.deleteImageConfirm'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: TranslatedText('common.cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: TranslatedText('common.delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && mounted) {
                        try {
                          // Call API to delete the image
                          final response = await ApiService()
                              .deleteProductGalleryImage(imageId);

                          if (response.statusCode == 200) {
                            // Successfully deleted, remove from list
                            setState(() {
                              _existingGalleryImages.removeAt(index);
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: TranslatedText('vendorCreate.imageDeleted'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            // Handle error
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to delete image: ${response.data is Map ? (response.data['message'] ?? 'Unknown error') : 'Unknown error'}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting image: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.delete,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // New image (not yet uploaded)
          final file = _gallery[index - _existingGalleryImages.length];
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    file,
                    width: 120,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
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

  // ---- Image Picker Methods ----

  Future<void> _showImageSourceDialog({required bool isThumbnail}) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  isThumbnail
                      ? 'Select Thumbnail Source'
                      : 'Select Image Source',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        description: 'Take a photo',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromCamera(isThumbnail: isThumbnail);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        description: 'Choose from gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromGallery(isThumbnail: isThumbnail);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera({required bool isThumbnail}) async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera);
      
      if (x != null) {
        setState(() {
          if (isThumbnail) {
            _thumbnail = File(x.path);
          } else {
            _gallery.add(File(x.path));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery({required bool isThumbnail}) async {
    try {
      final picker = ImagePicker();
      
      if (isThumbnail) {
        final x = await picker.pickImage(source: ImageSource.gallery);
        if (x != null) {
          setState(() => _thumbnail = File(x.path));
        }
      } else {
        final xs = await picker.pickMultiImage();
        if (xs.isNotEmpty) {
          setState(() => _gallery.addAll(xs.map((e) => File(e.path))));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing gallery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
