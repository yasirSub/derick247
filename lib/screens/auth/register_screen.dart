import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/translated_text.dart';
import '../../models/location_model.dart' as loc;
import 'package:country_flags/country_flags.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _dobController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<loc.Country> _countries = [];
  loc.Country? _selectedPhoneCountry;
  loc.Country? _selectedWhatsappCountry;
  loc.Country? _selectedProfileCountry;
  bool _isLoadingCountries = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _selectedDob;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
    });
    try {
      final response = await _apiService.getCountries();
      if (response.statusCode == 200 && response.data != null) {
        final rawList = _extractCountryList(response.data);
        final parsedCountries = rawList
            .whereType<Map<String, dynamic>>()
            .map(loc.Country.fromJson)
            .where(
              (country) =>
                  country.phoneCode != null && country.phoneCode!.isNotEmpty,
            )
            .toList();
        if (parsedCountries.isNotEmpty && mounted) {
          setState(() {
            _countries = parsedCountries;
            final defaultCountry = parsedCountries.first;
            _selectedPhoneCountry ??= defaultCountry;
            _selectedWhatsappCountry ??= defaultCountry;
            _selectedProfileCountry ??= defaultCountry;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load countries: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCountries = false;
        });
      }
    }
  }

  List<dynamic> _extractCountryList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      if (data['data'] is List) return data['data'];
      if (data['countries'] is List) return data['countries'];
      if (data['locations'] is List) return data['locations'];
    }
    return [];
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLoadingCountries) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait while we load country data')),
      );
      return;
    }

    final phoneCountry = _selectedPhoneCountry;
    final whatsappCountry = _selectedWhatsappCountry;
    final profileCountry = _selectedProfileCountry;

    if (phoneCountry == null ||
        whatsappCountry == null ||
        profileCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a country code for phone and WhatsApp'),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final userData = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
      'password_confirmation': _confirmPasswordController.text,
      'username': _usernameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'phone_country_code': phoneCountry.phoneCode ?? '',
      'whatsapp': _whatsappController.text.trim(),
      'whatsapp_country_code': whatsappCountry.phoneCode ?? '',
      'country_id': profileCountry.id,
    };

    if (_selectedDob != null) {
      userData['dob'] = _formatIsoDate(_selectedDob!);
    }

    _logRegistrationDebug('Sending registration payload', userData);

    final success = await authProvider.register(userData);

    if (success && mounted) {
      _logRegistrationDebug(
        'Registration succeeded for ${userData['email'] ?? userData['username']}',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (mounted) {
      final errorMessage = authProvider.error ?? 'Registration failed';
      _logRegistrationDebug('Registration failed: $errorMessage', userData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Registration failed'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 80, now.month, now.day);
    final lastDate = DateTime(now.year - 16, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDisplayDate(picked);
      });
    }
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatDisplayDate(DateTime date) {
    return '${_twoDigits(date.day)}-${_twoDigits(date.month)}-${date.year}';
  }

  String _formatIsoDate(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  void _logRegistrationDebug(String message, [Map<String, dynamic>? payload]) {
    if (!kDebugMode) return;
    final timestamp = DateTime.now().toIso8601String();
    final payloadText = payload != null
        ? '\nPayload:\n${const JsonEncoder.withIndent('  ').convert(payload)}'
        : '';
    debugPrint('🔍 [Registration][$timestamp] $message$payloadText');
  }

  InputDecoration _buildFieldDecoration({
    String? hintText,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.orange, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppTheme.spacingXLarge),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.shopping_bag,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Comisionista247',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      const TranslatedText(
                        'auth.register.title',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const TranslatedText(
                        'auth.register.subtitle',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingXLarge),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TranslatedText(
                                  'auth.register.firstName',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _firstNameController,
                                  style: const TextStyle(fontSize: 16),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return TranslationService().translate(
                                        'auth.register.firstNameRequired',
                                      );
                                    }
                                    return null;
                                  },
                                  decoration: _buildFieldDecoration(
                                    hintText: TranslationService().translate(
                                      'auth.register.firstNamePlaceholder',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TranslatedText(
                                  'auth.register.lastName',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _lastNameController,
                                  style: const TextStyle(fontSize: 16),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return TranslationService().translate(
                                        'auth.register.lastNameRequired',
                                      );
                                    }
                                    return null;
                                  },
                                  decoration: _buildFieldDecoration(
                                    hintText: TranslationService().translate(
                                      'auth.register.lastNamePlaceholder',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Username',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(fontSize: 16),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                            decoration: _buildFieldDecoration(
                              hintText: 'Choose a username',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 16),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            decoration: _buildFieldDecoration(
                              hintText: 'email@example.com',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _isLoadingCountries
                                    ? Container(
                                        height: 56,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child:
                                            const CircularProgressIndicator(),
                                      )
                                    : DropdownButtonFormField<loc.Country>(
                                        value: _selectedPhoneCountry,
                                        isExpanded: true,
                                        decoration: _buildFieldDecoration(
                                          hintText: 'Code',
                                        ),
                                        items: _countries.map((country) {
                                          return DropdownMenuItem<loc.Country>(
                                            value: country,
                                            child: Row(
                                              children: [
                                                if (country.code != null &&
                                                    country.code!.isNotEmpty)
                                                  CountryFlag.fromCountryCode(
                                                    country.code!,
                                                    height: 18,
                                                    width: 26,
                                                  ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '+${country.phoneCode ?? ''}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedPhoneCountry = value;
                                          });
                                        },
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontSize: 16),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter phone number';
                                    }
                                    return null;
                                  },
                                  decoration: _buildFieldDecoration(
                                    hintText: '0123456789',
                                    prefixText:
                                        _selectedPhoneCountry != null &&
                                            _selectedPhoneCountry!.phoneCode !=
                                                null
                                        ? '+${_selectedPhoneCountry!.phoneCode} '
                                        : '',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WhatsApp Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _isLoadingCountries
                                    ? Container(
                                        height: 56,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child:
                                            const CircularProgressIndicator(),
                                      )
                                    : DropdownButtonFormField<loc.Country>(
                                        value: _selectedWhatsappCountry,
                                        isExpanded: true,
                                        decoration: _buildFieldDecoration(
                                          hintText: 'Code',
                                        ),
                                        items: _countries.map((country) {
                                          return DropdownMenuItem<loc.Country>(
                                            value: country,
                                            child: Row(
                                              children: [
                                                if (country.code != null &&
                                                    country.code!.isNotEmpty)
                                                  CountryFlag.fromCountryCode(
                                                    country.code!,
                                                    height: 18,
                                                    width: 26,
                                                  ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '+${country.phoneCode ?? ''}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedWhatsappCountry = value;
                                          });
                                        },
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: _whatsappController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontSize: 16),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter WhatsApp number';
                                    }
                                    return null;
                                  },
                                  decoration: _buildFieldDecoration(
                                    hintText: '0123456789',
                                    prefixText:
                                        _selectedWhatsappCountry != null &&
                                            _selectedWhatsappCountry!
                                                    .phoneCode !=
                                                null
                                        ? '+${_selectedWhatsappCountry!.phoneCode} '
                                        : '',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date of Birth',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _dobController,
                            readOnly: true,
                            onTap: _pickDob,
                            validator: (value) {
                              if (_selectedDob == null) {
                                return 'Please select your date of birth';
                              }
                              return null;
                            },
                            decoration: _buildFieldDecoration(
                              hintText: 'dd-mm-yyyy',
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(fontSize: 16),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  decoration: _buildFieldDecoration(
                                    hintText: 'Password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Confirm password',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  style: const TextStyle(fontSize: 16),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                  decoration: _buildFieldDecoration(
                                    hintText: 'Confirm password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Country',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isLoadingCountries
                              ? Container(
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: const CircularProgressIndicator(),
                                )
                              : DropdownButtonFormField<loc.Country>(
                                  value: _selectedProfileCountry,
                                  isExpanded: true,
                                  decoration: _buildFieldDecoration(
                                    hintText: TranslationService().translate('checkout.selectCountry'),
                                  ),
                                  items: _countries.map((country) {
                                    return DropdownMenuItem<loc.Country>(
                                      value: country,
                                      child: Row(
                                        children: [
                                          if (country.code != null &&
                                              country.code!.isNotEmpty)
                                            CountryFlag.fromCountryCode(
                                              country.code!,
                                              height: 18,
                                              width: 26,
                                            ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              country.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedProfileCountry = value;
                                    });
                                  },
                                ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreeToTerms = value ?? false;
                              });
                            },
                            activeColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _agreeToTerms = !_agreeToTerms;
                                });
                              },
                              child: const Text(
                                'I agree to the Terms and Conditions',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          final button = Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Color(0xFFEA580C)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  (authProvider.isLoading || !_agreeToTerms)
                                  ? null
                                  : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          );

                          return button;
                        },
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF374151),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
