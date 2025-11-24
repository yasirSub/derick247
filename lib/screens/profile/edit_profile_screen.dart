import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_app_bar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _addressController;

  String _selectedPhoneCountryCode = '504';
  String _selectedWhatsappCountryCode = '504';
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _appliedForVendor = false;

  // Vendor permissions
  final List<String> _vendorPermissionOptions = [
    'create_product',
    'edit_product',
    'delete_product',
    'bulk_update',
    'refer_product',
    'refer_friend_to_call_center',
    'dropshipping_product',
  ];
  Set<String> _selectedVendorPermissions = {};

  // Profile image
  File? _avatarFile;
  String? _existingAvatarUrl;

  // Location data
  int? _countryId;
  int? _stateId;
  int? _cityId;
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;

  // Country codes list
  final List<Map<String, String>> _countryCodes = [
    {'code': '504', 'label': 'HN 504'},
    {'code': '1', 'label': 'US +1'},
    {'code': '502', 'label': 'GT 502'},
    {'code': '507', 'label': 'PA 507'},
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _whatsappController = TextEditingController();
    _addressController = TextEditingController();

    // Load profile from API and countries
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfile();
      await _fetchCountries();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final response = await _apiService.getProfile();
      if (response.statusCode == 200) {
        final data = response.data;
        final profileData = data is Map<String, dynamic> && data['data'] != null
            ? data['data']
            : data;

        // Store API values temporarily before setting state
        final countryIdFromApi = profileData['country_id'];
        final stateIdFromApi = profileData['state_id'];
        final cityIdFromApi = profileData['city_id'];

        // Validate phone country codes exist in our list
        final phoneCode = profileData['phone_country_code'] ?? '504';
        final whatsappCode = profileData['whatsapp_country_code'] ?? '504';

        setState(() {
          _firstNameController.text = profileData['first_name'] ?? '';
          _lastNameController.text = profileData['last_name'] ?? '';
          _emailController.text = profileData['email'] ?? '';
          _phoneController.text = profileData['phone'] ?? '';
          _whatsappController.text = profileData['whatsapp'] ?? '';
          _addressController.text = profileData['address'] ?? '';

          _selectedPhoneCountryCode =
              _countryCodes.any((c) => c['code'] == phoneCode)
              ? phoneCode
              : '504';
          _selectedWhatsappCountryCode =
              _countryCodes.any((c) => c['code'] == whatsappCode)
              ? whatsappCode
              : '504';

          // Don't set location IDs yet - will be validated after countries load
          _countryId = null;
          _stateId = null;
          _cityId = null;
          _appliedForVendor = profileData['applied_for_vendor'] ?? false;
          _existingAvatarUrl = profileData['avatar'];

          // Load vendor permissions
          if (profileData['vendor_permission'] != null) {
            _selectedVendorPermissions = Set<String>.from(
              profileData['vendor_permission'] is List
                  ? profileData['vendor_permission']
                  : [],
            );
          }

          _isLoadingProfile = false;
        });

        // Load countries first, then validate and set location IDs
        await _fetchCountries();

        // After countries are loaded, validate and set country ID
        if (countryIdFromApi != null && _countries.isNotEmpty) {
          final countryExists = _countries.any(
            (c) => c['id'] == countryIdFromApi,
          );
          if (countryExists) {
            setState(() {
              _countryId = countryIdFromApi;
            });
            await _fetchStates(countryIdFromApi);

            // After states are loaded, validate and set state ID
            if (stateIdFromApi != null && _states.isNotEmpty) {
              final stateExists = _states.any((s) => s['id'] == stateIdFromApi);
              if (stateExists) {
                setState(() {
                  _stateId = stateIdFromApi;
                });
                await _fetchCities(stateIdFromApi);

                // After cities are loaded, validate and set city ID
                if (cityIdFromApi != null && _cities.isNotEmpty) {
                  final cityExists = _cities.any(
                    (c) => c['id'] == cityIdFromApi,
                  );
                  if (cityExists) {
                    setState(() {
                      _cityId = cityIdFromApi;
                    });
                  }
                }
              }
            }
          }
        }
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingProfile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _fetchCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countries = [];
    });

    try {
      final res = await _apiService.getCountries();
      final data = res.data;
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

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
          _isLoadingCountries = false;

          // Validate countryId exists in loaded countries
          if (_countryId != null && list.isNotEmpty) {
            final countryExists = list.any((c) => c['id'] == _countryId);
            if (!countryExists) {
              _countryId = null;
              _stateId = null;
              _cityId = null;
              _states = [];
              _cities = [];
            }
          }
        });
      } else {
        setState(() {
          _countries = [];
          _isLoadingCountries = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingCountries = false);
    }
  }

  Future<void> _fetchStates(int countryId) async {
    setState(() {
      _isLoadingStates = true;
      _states = [];
    });

    try {
      final res = await _apiService.getStates(countryId);
      final data = res.data;
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

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
          _isLoadingStates = false;

          // Validate stateId exists in loaded states
          if (_stateId != null && list.isNotEmpty) {
            final stateExists = list.any((s) => s['id'] == _stateId);
            if (!stateExists) {
              _stateId = null;
              _cityId = null;
              _cities = [];
            }
          }
        });
      } else {
        setState(() {
          _states = [];
          _isLoadingStates = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingStates = false);
    }
  }

  Future<void> _fetchCities(int stateId) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
    });

    try {
      final res = await _apiService.getCities(stateId);
      final data = res.data;
      final responseType = data is Map<String, dynamic>
          ? data['type']?.toString().toLowerCase()
          : null;

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
          _isLoadingCities = false;

          // Validate cityId exists in loaded cities
          if (_cityId != null && list.isNotEmpty) {
            final cityExists = list.any((c) => c['id'] == _cityId);
            if (!cityExists) {
              _cityId = null;
            }
          }
        });
      } else {
        setState(() {
          _cities = [];
          _isLoadingCities = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingCities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(title: 'My Profile', isDark: true),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
                vertical: AppTheme.spacingMedium,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: AppTheme.spacingLarge),
                    _buildUserInformationSection(),
                    const SizedBox(height: AppTheme.spacingLarge),
                    _buildUserLocationSection(),
                    const SizedBox(height: AppTheme.spacingLarge),
                    _buildApplyForVendorSection(),
                    if (_appliedForVendor) ...[
                      const SizedBox(height: AppTheme.spacingLarge),
                      _buildVendorPermissionsSection(),
                    ],
                    const SizedBox(height: AppTheme.spacingXLarge),
                    _buildUpdateProfileButton(),
                    const SizedBox(height: AppTheme.spacingXLarge),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Profile Picture
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: AppTheme.secondaryColor, width: 3),
            ),
            child: _avatarFile != null
                ? ClipOval(child: Image.file(_avatarFile!, fit: BoxFit.cover))
                : _existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _existingAvatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.black,
                        child: Center(
                          child: Text(
                            _firstNameController.text.isNotEmpty
                                ? _firstNameController.text[0].toUpperCase()
                                : 'P',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.black,
                        child: Center(
                          child: Text(
                            _firstNameController.text.isNotEmpty
                                ? _firstNameController.text[0].toUpperCase()
                                : 'P',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _firstNameController.text.isNotEmpty
                          ? _firstNameController.text[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        // Hint text
        Text(
          'Click image to change',
          style: TextStyle(
            fontSize: AppTheme.fontSizeSmall,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeLarge,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
    );
  }

  Widget _buildUserInformationSection() {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('USER INFORMATION'),
          const SizedBox(height: AppTheme.spacingMedium),
          // First Name
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'Enter Your First Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'First name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Last Name
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Enter Your Last Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Enter Your email address',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Phone Number
          Row(
            children: [
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  value:
                      _countryCodes.any(
                        (c) => c['code'] == _selectedPhoneCountryCode,
                      )
                      ? _selectedPhoneCountryCode
                      : '504',
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                  ),
                  items: _countryCodes.map((code) {
                    return DropdownMenuItem(
                      value: code['code'],
                      child: Text(code['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPhoneCountryCode = value ?? '504';
                    });
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // WhatsApp Number
          Row(
            children: [
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  value:
                      _countryCodes.any(
                        (c) => c['code'] == _selectedWhatsappCountryCode,
                      )
                      ? _selectedWhatsappCountryCode
                      : '504',
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                  ),
                  items: _countryCodes.map((code) {
                    return DropdownMenuItem(
                      value: code['code'],
                      child: Text(code['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedWhatsappCountryCode = value ?? '504';
                    });
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'WhatsApp number is required';
                    }
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

  Widget _buildUserLocationSection() {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('USER LOCATION'),
          const SizedBox(height: AppTheme.spacingMedium),
          // Country
          _categoryStyleDropdown<int>(
            label: 'Country',
            value: _countryId,
            enabled: !_isLoadingCountries && _countries.isNotEmpty,
            hint: _isLoadingCountries
                ? 'Loading...'
                : (_countries.isEmpty
                      ? 'No countries available'
                      : 'Select country...'),
            icon: Icons.public,
            onChanged: (v) {
              setState(() {
                _countryId = v;
                _stateId = null;
                _cityId = null;
                _states = [];
                _cities = [];
              });
              if (v != null) _fetchStates(v);
            },
            items: _isLoadingCountries
                ? []
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
          // State
          _categoryStyleDropdown<int>(
            label: 'Select Your State',
            value: _stateId,
            enabled: _countryId != null && !_isLoadingStates,
            hint: _countryId == null
                ? 'Select country first...'
                : (_isLoadingStates
                      ? 'Loading...'
                      : (_states.isEmpty
                            ? 'No states available'
                            : 'Select state...')),
            icon: Icons.location_city,
            onChanged: (v) {
              setState(() {
                _stateId = v;
                _cityId = null;
                _cities = [];
              });
              if (v != null) _fetchCities(v);
            },
            items: _countryId == null
                ? []
                : _states
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as int?,
                          child: Text('${e['name']}'),
                        ),
                      )
                      .toList(),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // City
          _categoryStyleDropdown<int>(
            label: 'Select Your City',
            value: _cityId,
            enabled: _stateId != null && !_isLoadingCities,
            hint: _stateId == null
                ? 'Select state first...'
                : (_isLoadingCities
                      ? 'Loading...'
                      : (_cities.isEmpty
                            ? 'No cities available'
                            : 'Select city...')),
            icon: Icons.place,
            onChanged: (v) => setState(() => _cityId = v),
            items: _stateId == null
                ? []
                : _cities
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as int?,
                          child: Text('${e['name']}'),
                        ),
                      )
                      .toList(),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          // Address
          TextFormField(
            controller: _addressController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Your Address Details',
              hintText: 'Type Address Details here.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyForVendorSection() {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('APPLY FOR VENDOR'),
          const SizedBox(height: AppTheme.spacingMedium),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              color: AppTheme.darkAppBarColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Apply For Vendor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: _appliedForVendor,
                  onChanged: (value) {
                    setState(() {
                      _appliedForVendor = value;
                    });
                  },
                  activeColor: AppTheme.secondaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorPermissionsSection() {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.darkAppBarColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._vendorPermissionOptions.map((permission) {
            final displayName = permission
                .replaceAll('_', ' ')
                .split(' ')
                .map((word) => word[0].toUpperCase() + word.substring(1))
                .join(' ');
            return CheckboxListTile(
              title: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTheme.fontSizeMedium,
                ),
              ),
              value: _selectedVendorPermissions.contains(permission),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedVendorPermissions.add(permission);
                  } else {
                    _selectedVendorPermissions.remove(permission);
                  }
                });
              },
              activeColor: Colors.blue,
              checkColor: Colors.white,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildUpdateProfileButton() {
    return Container(
      margin: EdgeInsets.zero,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'UPDATE PROFILE',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  // Category style dropdown (same as product create)
  Widget _categoryStyleDropdown<T>({
    required String label,
    required T? value,
    required ValueChanged<T?> onChanged,
    required List<DropdownMenuItem<T>> items,
    bool enabled = true,
    String? hint,
    required IconData icon,
    bool isRequired = false,
  }) {
    String? displayText;
    T? safeValue = value;

    // Validate that the value exists in items list
    if (value != null && items.isNotEmpty) {
      try {
        final matchingItems = items.where((e) => e.value == value).toList();
        if (matchingItems.isEmpty) {
          // Value doesn't exist in items, set to null
          safeValue = null;
          displayText = null;
        } else if (matchingItems.length == 1) {
          // Value exists and is unique
          final selectedItem = matchingItems.first;
          if (selectedItem.child is Text) {
            displayText = (selectedItem.child as Text).data ?? '';
          } else {
            displayText = selectedItem.child.toString();
          }
        } else {
          // Multiple items with same value - this shouldn't happen but handle it
          safeValue = null;
          displayText = null;
        }
      } catch (_) {
        safeValue = null;
        displayText = null;
      }
    } else if (value != null && items.isEmpty) {
      // Value is set but items are empty - clear the value
      safeValue = null;
      displayText = null;
    }

    final bool showStar = isRequired && safeValue == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 14,
            ),
            children: [
              if (showStar)
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
        Opacity(
          opacity: enabled ? 1 : .6,
          child: TextField(
            readOnly: true,
            controller: TextEditingController(text: displayText),
            onTap: enabled && items.isNotEmpty
                ? () {
                    _showDropdownBottomSheet<T>(
                      context: context,
                      items: items,
                      currentValue: safeValue,
                      onSelected: onChanged,
                      hint: hint,
                    );
                  }
                : () {
                    if (!enabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            hint ?? 'Please select previous option first',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else if (items.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Loading options...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
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

  // Image picker methods (same as product create)
  Future<void> _showImageSourceDialog() async {
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
                const Text(
                  'Select Profile Picture Source',
                  style: TextStyle(
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
                          _pickImageFromCamera();
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
                          _pickImageFromGallery();
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
                child: Icon(icon, size: 36, color: AppTheme.primaryColor),
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera);

      if (x != null) {
        setState(() {
          _avatarFile = File(x.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing camera: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery);

      if (x != null) {
        setState(() {
          _avatarFile = File(x.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing gallery: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final profileData = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone_country_code': _selectedPhoneCountryCode,
        'whatsapp': _whatsappController.text.trim(),
        'whatsapp_country_code': _selectedWhatsappCountryCode,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        if (_countryId != null) 'country_id': _countryId,
        if (_stateId != null) 'state_id': _stateId,
        if (_cityId != null) 'city_id': _cityId,
        'applied_for_vendor': _appliedForVendor ? 1 : 0,
        // Send vendor permissions only when applied for vendor and permissions exist
        if (_appliedForVendor && _selectedVendorPermissions.isNotEmpty)
          'vendor_permission[]': _selectedVendorPermissions.toList(),
      };

      // Add avatar file ONLY if selected (don't send existing URL - server will preserve it)
      if (_avatarFile != null) {
        print('📸 [PROFILE UPDATE] Adding avatar file: ${_avatarFile!.path}');
        profileData['avatar'] = await MultipartFile.fromFile(
          _avatarFile!.path,
          filename: _avatarFile!.path.split('/').last,
        );
      } else {
        print(
          '⚠️ [PROFILE UPDATE] No new avatar file selected - server will preserve existing avatar',
        );
        // Don't send avatar field at all if not updating it
        // Server will preserve the existing avatar automatically
      }

      // Debug: Print all profile data being sent
      print('📤 [PROFILE UPDATE] Sending profile data:');
      profileData.forEach((key, value) {
        if (value is MultipartFile) {
          print('   → $key: MultipartFile (${value.filename})');
        } else {
          print('   → $key: $value');
        }
      });
      print('📤 [PROFILE UPDATE] Total fields: ${profileData.length}');

      final response = await _apiService.updateProfile(profileData);

      print('📥 [PROFILE UPDATE] Response status: ${response.statusCode}');
      print('📥 [PROFILE UPDATE] Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Update user in AuthProvider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.refreshUser();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
