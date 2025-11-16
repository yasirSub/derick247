import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/translated_text.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({Key? key}) : super(key: key);

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _recipientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Dropdown values
  int? _countryId;
  int? _stateId;
  int? _cityId;
  String _addressType = 'home';

  // Location data
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];

  // Loading states
  bool _isLoadingCountries = true;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;
  bool _isSubmitting = false;

  final List<String> _addressTypes = ['home', 'work', 'other'];

  final Map<String, String> _addressTypeLabels = {
    'home': 'Home',
    'work': 'Work',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
    });

    try {
      final response = await _apiService.getCountries();
      if (response.statusCode == 200) {
        final responseData = response.data;
        // Check if response type is countries or if it's a direct list
        final responseType = responseData['type']?.toString().toLowerCase();

        // Only process if type is 'countries' or if no type field exists (backward compatibility)
        if (responseType == null || responseType == 'countries') {
          final data = responseData['data'] ?? responseData;
          final countriesList = data is List ? data : (data['countries'] ?? []);
          setState(() {
            _countries = List<Map<String, dynamic>>.from(countriesList);
            _isLoadingCountries = false;
          });
        } else {
          // Wrong type returned, show error
          setState(() {
            _isLoadingCountries = false;
            _countries = [];
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unexpected response type: $responseType'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } else {
        setState(() {
          _isLoadingCountries = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data['message']?.toString() ??
                    'Failed to load countries',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingCountries = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading countries: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
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
        // Check if response type is states
        final responseType = responseData['type']?.toString().toLowerCase();

        // Only process if type is 'states' or if no type field exists (backward compatibility)
        if (responseType == null || responseType == 'states') {
          final data = responseData['data'] ?? responseData;
          final statesList = data is List ? data : (data['states'] ?? []);
          setState(() {
            _states = List<Map<String, dynamic>>.from(statesList);
            _isLoadingStates = false;
          });
        } else {
          // Wrong type returned, show error
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
        // Check if response type is cities
        final responseType = responseData['type']?.toString().toLowerCase();

        // Only process if type is 'cities' or if no type field exists (backward compatibility)
        if (responseType == null || responseType == 'cities') {
          final data = responseData['data'] ?? responseData;
          final citiesList = data is List ? data : (data['cities'] ?? []);
          setState(() {
            _cities = List<Map<String, dynamic>>.from(citiesList);
            _isLoadingCities = false;
          });
        } else {
          // Wrong type returned (e.g., 'countries' when expecting 'cities')
          setState(() {
            _isLoadingCities = false;
            _cities = [];
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to load cities. Unexpected response type: $responseType',
                ),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
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

  Future<void> _submitAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_countryId == null || _stateId == null || _cityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('checkout.selectLocation'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final addressData = {
        'recipient_name': _recipientNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country_id': _countryId.toString(),
        'state_id': _stateId.toString(),
        'city_id': _cityId.toString(),
        'address': _addressController.text.trim(),
        'address_type': _addressType,
      };

      final response = await _apiService.storeAddress(addressData);

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data['message']?.toString() ??
                    'Shipping address added successfully!',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        final errorMessage =
            response.data['message']?.toString() ??
            'Failed to add shipping address';
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
            content: Text('Failed to add address: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const CustomAppBar(title: 'Add New Address', isDark: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipient Name
              TextFormField(
                controller: _recipientNameController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Name',
                  hintText: 'Enter recipient name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter recipient name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // Country Dropdown
              DropdownButtonFormField<int>(
                value: _countryId,
                decoration: InputDecoration(
                  labelText: TranslationService().translate('checkout.country'),
                  border: const OutlineInputBorder(),
                ),
                items: _isLoadingCountries
                    ? [
                        DropdownMenuItem(
                          value: null,
                          child: TranslatedText('app.loading'),
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
                    return TranslationService().translate(
                      'checkout.countryRequired',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // State Dropdown
              DropdownButtonFormField<int>(
                value: _stateId,
                decoration: InputDecoration(
                  labelText: TranslationService().translate('checkout.state'),
                  border: const OutlineInputBorder(),
                ),
                items: _isLoadingStates
                    ? [
                        DropdownMenuItem(
                          value: null,
                          child: TranslatedText('app.loading'),
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
                    return TranslationService().translate(
                      'checkout.stateRequired',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // City Dropdown
              DropdownButtonFormField<int>(
                value: _cityId,
                decoration: InputDecoration(
                  labelText: TranslationService().translate('checkout.city'),
                  border: const OutlineInputBorder(),
                ),
                items: _isLoadingCities
                    ? [
                        DropdownMenuItem(
                          value: null,
                          child: TranslatedText('app.loading'),
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
                    return TranslationService().translate(
                      'checkout.cityRequired',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter full address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // Address Type Dropdown
              DropdownButtonFormField<String>(
                value: _addressType,
                decoration: const InputDecoration(
                  labelText: 'Address Type',
                  border: OutlineInputBorder(),
                ),
                items: _addressTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_addressTypeLabels[type] ?? type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _addressType = value ?? 'home';
                  });
                },
              ),
              const SizedBox(height: AppTheme.spacingLarge * 2),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAddress,
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
                      : const Text(
                          'SAVE ADDRESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.fontSizeMedium,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
