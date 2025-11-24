import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme_config.dart';
import '../../../services/api_service.dart';
import '../../../services/translation_service.dart';
import '../../../providers/locale_provider.dart';
import '../paypal_webview_screen.dart';

class GuestCheckoutScreen extends StatefulWidget {
  final String checkoutToken;

  const GuestCheckoutScreen({Key? key, required this.checkoutToken})
    : super(key: key);

  @override
  State<GuestCheckoutScreen> createState() => _GuestCheckoutScreenState();
}

class _GuestCheckoutScreenState extends State<GuestCheckoutScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  Map<String, dynamic>? _checkoutData;

  // Product information (loaded separately if product_id exists)
  Map<String, dynamic>? _productData;
  bool _isLoadingProduct = false;

  // Form controllers
  final _recipientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Dropdown values
  int? _countryId;
  int? _stateId;
  int? _cityId;

  // Location data
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];

  // Loading states
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;

  // Selected payment method
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
    _loadCountries();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckoutData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    print('🛒 Loading guest checkout with token: ${widget.checkoutToken}');

    try {
      final response = await _apiService.getGuestCheckout(widget.checkoutToken);

      print('📦 Checkout response status: ${response.statusCode}');
      print('📦 Checkout response data keys: ${response.data.keys}');

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Validate response structure
        print('📋 Response structure validation:');
        print('   - Has status: ${responseData.containsKey('status')}');
        print('   - Status value: ${responseData['status']}');
        print('   - Has data: ${responseData.containsKey('data')}');

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final data = responseData['data'];

          // Validate data structure - new format has direct fields
          print('📋 Data structure validation:');
          print(
            '   - Has payment_method: ${data.containsKey('payment_method')}',
          );
          print('   - Has product_id: ${data.containsKey('product_id')}');
          print(
            '   - Has recipient_name: ${data.containsKey('recipient_name')}',
          );

          setState(() {
            _checkoutData = data;

            print('✅ Checkout data loaded successfully');
            print('   - Payment method: ${data['payment_method']}');
            print('   - Product ID: ${data['product_id']}');
            print('   - Referrer ID: ${data['referrer_id']}');
            print('   - Recipient name: ${data['recipient_name']}');
            print('   - Shipping ID: ${data['shipping_id']}');

            // Pre-fill form if data exists
            final recipientName = data['recipient_name']?.toString();
            final recipientPhone = data['recipient_phone']?.toString();
            final address = data['address']?.toString();

            if (recipientName != null && recipientName.isNotEmpty) {
              _recipientNameController.text = recipientName;
            }
            if (recipientPhone != null && recipientPhone.isNotEmpty) {
              _phoneController.text = recipientPhone;
            }
            if (address != null && address.isNotEmpty) {
              _addressController.text = address;
            }

            _countryId = data['country_id'] as int?;
            _stateId = data['state_id'] as int?;
            _cityId = data['city_id'] as int?;

            // Load states and cities if IDs exist
            if (_countryId != null) {
              _loadStates(_countryId!);
              if (_stateId != null) {
                _loadCities(_stateId!);
              }
            }

            // Auto-select payment method if available
            _selectedPaymentMethod =
                data['payment_method']?.toString() ?? 'paypal_checkout';
            _isLoading = false;
          });

          // Load product details if product_id exists
          final productId = data['product_id'] as int?;
          if (productId != null) {
            print('🛍️ Loading product details for product ID: $productId');
            _loadProductDetails(productId);
          } else {
            print('⚠️ No product_id in checkout data');
          }
        } else {
          final errorMsg =
              responseData['message']?.toString() ??
              'Failed to load checkout information';
          print('❌ Checkout API returned error: $errorMsg');
          setState(() {
            _error = errorMsg;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 500) {
        // Handle 500 server errors with better messages
        final errorMessage = response.data['message']?.toString() ?? '';
        final errorFile = response.data['file']?.toString() ?? '';

        print('❌ Server error (500) when loading checkout');
        print('   - Error message: $errorMessage');
        print('   - Error file: $errorFile');

        // Check for specific server bugs
        String userMessage;
        if (errorMessage.contains('payment_status') ||
            errorMessage.contains('shippingAvailable') ||
            errorMessage.contains('on null')) {
          userMessage =
              'Server error: Unable to load checkout data. '
              'Please try again later or contact support. '
              'The checkout link may still be valid.';
        } else {
          userMessage =
              'Server error: Unable to load checkout. '
              'Please try again later or contact support.';
        }

        setState(() {
          _error = userMessage;
          _isLoading = false;
        });
      } else {
        final errorMsg =
            response.data['message']?.toString() ??
            'Failed to load checkout information (Status: ${response.statusCode})';
        print(
          '❌ Checkout API returned status ${response.statusCode}: $errorMsg',
        );
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading checkout: $e');
      print('   - Error type: ${e.runtimeType}');

      // Provide user-friendly error message
      String errorMessage;
      if (e.toString().contains('500') ||
          e.toString().contains('Server error')) {
        errorMessage =
            'Server error: Unable to load checkout. Please try again later or contact support.';
      } else if (e.toString().contains('404') ||
          e.toString().contains('Not found')) {
        errorMessage =
            'Checkout link is invalid or expired. Please request a new checkout link.';
      } else if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        errorMessage = 'Access denied. The checkout link may be invalid.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Connection timeout. Please check your internet connection and try again.';
      } else {
        // Extract just the error message, not the full exception details
        final errorStr = e.toString();
        if (errorStr.contains('DioException')) {
          // Try to extract a meaningful message
          if (errorStr.contains('500')) {
            errorMessage =
                'Server error: Unable to load checkout. Please try again later.';
          } else {
            errorMessage = 'Failed to load checkout. Please try again.';
          }
        } else {
          errorMessage =
              'Failed to load checkout: ${errorStr.split('\n').first}';
        }
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProductDetails(int productId) async {
    setState(() {
      _isLoadingProduct = true;
    });

    try {
      print('🛍️ Fetching product details for ID: $productId');
      final response = await _apiService.getProductDetail(productId);

      if (response.statusCode == 200 && response.data['data'] != null) {
        setState(() {
          _productData = response.data['data'];
          _isLoadingProduct = false;
        });
        print('✅ Product loaded: ${_productData!['name']}');
        print('   - Price: ${_productData!['price']}');
        print('   - Currency: ${_productData!['currency_symbol']}');
      } else {
        setState(() {
          _isLoadingProduct = false;
        });
        print('⚠️ Failed to load product details');
      }
    } catch (e) {
      setState(() {
        _isLoadingProduct = false;
      });
      print('❌ Error loading product: $e');
    }
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
    });

    try {
      final response = await _apiService.getCountries();
      if (response.statusCode == 200) {
        final responseData = response.data;
        final responseType = responseData['type']?.toString().toLowerCase();

        if (responseType == null || responseType == 'countries') {
          final data = responseData['data'] ?? responseData;
          final countriesList = data is List ? data : (data['countries'] ?? []);
          setState(() {
            _countries = List<Map<String, dynamic>>.from(countriesList);
            _isLoadingCountries = false;
          });
        } else {
          setState(() {
            _isLoadingCountries = false;
            _countries = [];
          });
        }
      } else {
        setState(() {
          _isLoadingCountries = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCountries = false;
      });
    }
  }

  Future<void> _loadStates(int countryId) async {
    setState(() {
      _isLoadingStates = true;
      _stateId = null;
      _cityId = null;
      _states = [];
      _cities = [];
    });

    try {
      final response = await _apiService.getStates(countryId);
      if (response.statusCode == 200) {
        final responseData = response.data;
        final responseType = responseData['type']?.toString().toLowerCase();

        if (responseType == null || responseType == 'states') {
          final data = responseData['data'] ?? responseData;
          final statesList = data is List ? data : (data['states'] ?? []);
          setState(() {
            _states = List<Map<String, dynamic>>.from(statesList);
            _isLoadingStates = false;
          });
        } else {
          setState(() {
            _isLoadingStates = false;
            _states = [];
          });
        }
      } else {
        setState(() {
          _isLoadingStates = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingStates = false;
      });
    }
  }

  Future<void> _loadCities(int stateId) async {
    setState(() {
      _isLoadingCities = true;
      _cityId = null;
      _cities = [];
    });

    try {
      final response = await _apiService.getCities(stateId);
      if (response.statusCode == 200) {
        final responseData = response.data;
        final responseType = responseData['type']?.toString().toLowerCase();

        if (responseType == null || responseType == 'cities') {
          final data = responseData['data'] ?? responseData;
          final citiesList = data is List ? data : (data['cities'] ?? []);
          setState(() {
            _cities = List<Map<String, dynamic>>.from(citiesList);
            _isLoadingCities = false;
          });
        } else {
          setState(() {
            _isLoadingCities = false;
            _cities = [];
          });
        }
      } else {
        setState(() {
          _isLoadingCities = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCities = false;
      });
    }
  }

  Future<void> _submitCheckout() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_countryId == null || _stateId == null || _cityId == null) {
      final translationService = TranslationService();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translationService.translate('checkout.selectLocation'),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedPaymentMethod == null) {
      final translationService = TranslationService();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translationService.translate('checkout.selectPayment')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final checkoutData = {
        'recipient_name': _recipientNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country_id': _countryId.toString(),
        'state_id': _stateId.toString(),
        'city_id': _cityId.toString(),
        'address': _addressController.text.trim(),
        'payment_method': _selectedPaymentMethod,
      };

      // Add product_id and referrer_id from checkout data if available
      if (_checkoutData != null) {
        final productId = _checkoutData!['product_id'];
        final referrerId = _checkoutData!['referrer_id'];
        if (productId != null) {
          checkoutData['product_id'] = productId.toString();
        }
        if (referrerId != null) {
          checkoutData['referrer_id'] = referrerId.toString();
        }
      }

      final response = await _apiService.submitGuestCheckout(
        widget.checkoutToken,
        checkoutData,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Handle PayPal redirect if approval link exists
        if (responseData != null && responseData is Map) {
          final rawApprovalLink =
              responseData['approvalLink'] ??
              responseData['approval_url'] ??
              responseData['approvalUrl'];
          if (rawApprovalLink != null &&
              rawApprovalLink.toString().isNotEmpty) {
            final approvalLink = rawApprovalLink.toString();
            print('🔗 Opening PayPal approval link: $approvalLink');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening PayPal...'),
                  backgroundColor: AppTheme.successColor,
                  duration: Duration(seconds: 2),
                ),
              );

              final paypalResult = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PaypalWebViewScreen(approvalUrl: approvalLink),
                ),
              );

              // Handle PayPal return result
              if (mounted && paypalResult != null) {
                final translationService = TranslationService();
                if (paypalResult is Map) {
                  final isSuccess = paypalResult['success'] == true;

                  if (isSuccess) {
                    // Payment successful - wait a moment for backend to process order
                    await Future.delayed(const Duration(seconds: 1));
                    
                    // Show success message and navigate back
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          responseData['message']?.toString() ??
                              translationService.translate('checkout.orderPlaced'),
                        ),
                        backgroundColor: AppTheme.successColor,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    Navigator.of(context).pop(true);
                  } else {
                    // Payment cancelled or failed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment was cancelled'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                } else {
                  // Fallback: wait a moment for backend processing
                  await Future.delayed(const Duration(seconds: 1));
                  
                  // Show success message and navigate back
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        responseData['message']?.toString() ??
                            translationService.translate('checkout.orderPlaced'),
                      ),
                      backgroundColor: AppTheme.successColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Navigator.of(context).pop(true);
                }
              }
            }
            return;
          }
        }

        // Fallback: just show success message if no approval link
        if (mounted) {
          final translationService = TranslationService();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseData != null && responseData is Map
                    ? responseData['message']?.toString() ??
                          translationService.translate('checkout.orderPlaced')
                    : translationService.translate('checkout.orderPlaced'),
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        final errorMessage =
            response.data['message']?.toString() ??
            'Failed to process checkout. Please try again.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process checkout: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to translations
    Provider.of<LocaleProvider>(context, listen: true);
    final translationService = TranslationService();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shopping_bag, color: Colors.orange[700], size: 28),
            const SizedBox(width: 8),
            Text(
              translationService.translate('checkout.secureCheckout'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.darkAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState(translationService)
          : _checkoutData == null
          ? Center(child: Text(translationService.translate('checkout.noData')))
          : _buildCheckoutContent(translationService),
    );
  }

  Widget _buildErrorState(TranslationService translationService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            translationService.translate('checkout.loadError'),
            style: TextStyle(fontSize: 18, color: AppTheme.errorColor),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCheckoutData,
            child: Text(translationService.translate('app.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutContent(TranslationService translationService) {
    // Handle new response structure - product_id instead of order
    final productId = _checkoutData!['product_id'] as int?;
    final productData = _productData;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shipping Details Section
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.orange[700], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    translationService.translate('checkout.shippingDetails'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Shipping Form
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
              ),
              child: Column(
                children: [
                  // Recipient Name
                  TextFormField(
                    controller: _recipientNameController,
                    decoration: InputDecoration(
                      labelText: translationService.translate(
                        'checkout.recipientName',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return translationService.translate(
                          'checkout.recipientNameRequired',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: translationService.translate(
                        'checkout.recipientPhone',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return translationService.translate(
                          'checkout.phoneRequired',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // Country Dropdown
                  DropdownButtonFormField<int>(
                    value: _countryId,
                    decoration: InputDecoration(
                      labelText: translationService.translate(
                        'checkout.country',
                      ),
                      hintText: translationService.translate(
                        'checkout.selectCountry',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: _isLoadingCountries
                        ? [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                translationService.translate('app.loading'),
                              ),
                            ),
                          ]
                        : _countries.map((country) {
                            return DropdownMenuItem(
                              value: country['id'] as int?,
                              child: Text(country['name']?.toString() ?? ''),
                            );
                          }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _countryId = value;
                        _stateId = null;
                        _cityId = null;
                        _states = [];
                        _cities = [];
                      });
                      if (value != null) {
                        _loadStates(value);
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return translationService.translate(
                          'checkout.countryRequired',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // State Dropdown
                  DropdownButtonFormField<int>(
                    value: _stateId,
                    decoration: InputDecoration(
                      labelText: translationService.translate('checkout.state'),
                      hintText: translationService.translate(
                        'checkout.selectState',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: _countryId == null || _isLoadingStates
                        ? [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                _countryId == null
                                    ? translationService.translate(
                                        'checkout.selectCountryFirst',
                                      )
                                    : translationService.translate(
                                        'app.loading',
                                      ),
                              ),
                            ),
                          ]
                        : _states.map((state) {
                            return DropdownMenuItem(
                              value: state['id'] as int?,
                              child: Text(state['name']?.toString() ?? ''),
                            );
                          }).toList(),
                    onChanged: (_countryId != null && !_isLoadingStates)
                        ? (value) {
                            setState(() {
                              _stateId = value;
                              _cityId = null;
                              _cities = [];
                            });
                            if (value != null) {
                              _loadCities(value);
                            }
                          }
                        : null,
                    validator: (value) {
                      if (value == null) {
                        return translationService.translate(
                          'checkout.stateRequired',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // City Dropdown
                  DropdownButtonFormField<int>(
                    value: _cityId,
                    decoration: InputDecoration(
                      labelText: translationService.translate('checkout.city'),
                      hintText: translationService.translate(
                        'checkout.selectCity',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: _stateId == null || _isLoadingCities
                        ? [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                _stateId == null
                                    ? translationService.translate(
                                        'checkout.selectStateFirst',
                                      )
                                    : translationService.translate(
                                        'app.loading',
                                      ),
                              ),
                            ),
                          ]
                        : _cities.map((city) {
                            return DropdownMenuItem(
                              value: city['id'] as int?,
                              child: Text(city['name']?.toString() ?? ''),
                            );
                          }).toList(),
                    onChanged: (_stateId != null && !_isLoadingCities)
                        ? (value) {
                            setState(() {
                              _cityId = value;
                            });
                          }
                        : null,
                    validator: (value) {
                      if (value == null) {
                        return translationService.translate(
                          'checkout.cityRequired',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: translationService.translate(
                        'checkout.address',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return translationService.translate(
                          'checkout.addressRequired',
                        );
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Payment Method Section
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Text(
                translationService.translate('checkout.paymentMethod'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // PayPal Payment Option
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
              ),
              child: Card(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = 'paypal_checkout';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            'assets/images/paypal.png',
                            width: 32,
                            height: 32,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.payment, color: Colors.blue[700]),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMedium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PayPal',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                translationService.translate(
                                  'checkout.fastSecure',
                                ),
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeSmall,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedPaymentMethod == 'paypal_checkout')
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.orange[700],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Order Summary - show product info if available
            if (productData != null)
              _buildProductSummary(productData, translationService)
            else if (_isLoadingProduct)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        translationService.translate('app.loading'),
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              )
            else if (productId != null)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Text(
                  translationService.translate('app.loading'),
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
              ),

            // Submit Button
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          translationService.translate('checkout.placeOrder'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.fontSizeMedium,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSummary(
    Map<String, dynamic> product,
    TranslationService translationService,
  ) {
    final productName = product['name']?.toString() ?? '';
    final productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
    final currencySymbol = product['currency_symbol']?.toString() ?? '\$';
    final quantity = 1; // Default quantity for guest checkout
    final totalAmount = productPrice * quantity;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMedium),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translationService.translate('checkout.orderSummary'),
            style: const TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            '${translationService.translate('checkout.items')} (1)',
            style: const TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          // Product Item
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeSmall,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${translationService.translate('checkout.quantity')}: $quantity',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeSmall,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$currencySymbol${productPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeSmall,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white54, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                translationService.translate('checkout.total'),
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeMedium,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$currencySymbol${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeMedium,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                translationService.translate('checkout.total'),
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '\$${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
