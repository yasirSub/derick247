import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/theme_config.dart';

class CurrencySelectionDialog extends StatefulWidget {
  const CurrencySelectionDialog({Key? key}) : super(key: key);

  @override
  State<CurrencySelectionDialog> createState() =>
      _CurrencySelectionDialogState();
}

class _CurrencySelectionDialogState extends State<CurrencySelectionDialog> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  List<Map<String, dynamic>> _currencies = [];
  bool _isLoading = true;
  String? _selectedCurrency;
  bool _isSettingCurrency = false;

  String _emojiFlagForCurrency(String? code) {
    if (code == null) return '';
    switch (code.toUpperCase()) {
      case 'USD':
        return '🇺🇸';
      case 'HNL':
        return '🇭🇳';
      case 'EUR':
        return '🇪🇺';
      case 'GBP':
        return '🇬🇧';
      case 'INR':
        return '🇮🇳';
      case 'PKR':
        return '🇵🇰';
      case 'AUD':
        return '🇦🇺';
      case 'CAD':
        return '🇨🇦';
      case 'JPY':
        return '🇯🇵';
      default:
        return '';
    }
  }

  String? _countryCodeForCurrency(String? code) {
    if (code == null) return null;
    switch (code.toUpperCase()) {
      case 'USD':
        return 'US';
      case 'HNL':
        return 'HN';
      case 'EUR':
        return 'EU'; // Not a country; package may not have EU; handled below
      case 'GBP':
        return 'GB';
      case 'INR':
        return 'IN';
      case 'PKR':
        return 'PK';
      case 'AUD':
        return 'AU';
      case 'CAD':
        return 'CA';
      case 'JPY':
        return 'JP';
      default:
        return null;
    }
  }

  String? _countryCodeFromEmoji(String? emoji) {
    if (emoji == null || emoji.isEmpty) return null;
    // Expect two Regional Indicator Symbols representing letters A-Z
    final runes = emoji.runes.toList();
    if (runes.length < 2) return null;
    const base = 0x1F1E6; // Regional Indicator Symbol Letter A
    final first = runes[0] - base;
    final second = runes[1] - base;
    if (first < 0 || first > 25 || second < 0 || second > 25) return null;
    final code = String.fromCharCode(0x41 + first) + String.fromCharCode(0x41 + second);
    return code;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _loadSelectedCurrency();
  }

  Future<void> _loadSelectedCurrency() async {
    final savedCurrency = await _storageService.getSelectedCurrency();
    if (mounted) {
      setState(() {
        _selectedCurrency = savedCurrency;
      });
    }
  }

  Future<void> _loadCurrencies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getCountries();
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<Map<String, dynamic>> currenciesList = [];

        if (data is Map && data['data'] != null) {
          final countries = data['data'] as List;
          for (var country in countries) {
            if (country is Map &&
                country['currency_code'] != null &&
                country['currency_code'].toString().isNotEmpty) {
              // Avoid duplicates
              final currencyCode = country['currency_code'].toString();
              if (!currenciesList.any((c) => c['currency_code'] == currencyCode)) {
                currenciesList.add({
                  'currency_code': currencyCode,
                  'country_name': country['name'] ?? country['country_name'] ?? '',
                  'flag': country['flag'] ?? '',
                });
              }
            }
          }
        } else if (data is List) {
          for (var country in data) {
            if (country is Map &&
                country['currency_code'] != null &&
                country['currency_code'].toString().isNotEmpty) {
              final currencyCode = country['currency_code'].toString();
              if (!currenciesList.any((c) => c['currency_code'] == currencyCode)) {
                currenciesList.add({
                  'currency_code': currencyCode,
                  'country_name': country['name'] ?? country['country_name'] ?? '',
                  'flag': country['flag'] ?? '',
                });
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _currencies = currenciesList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showError('Failed to load currencies');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error loading currencies: $e');
      }
    }
  }

  Future<void> _setCurrency(String currencyCode) async {
    setState(() {
      _isSettingCurrency = true;
    });

    try {
      final response = await _apiService.setCurrency(currencyCode);
      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['success'] == true) {
        // Save to local storage (currency + derived country code if available)
        await _storageService.saveSelectedCurrency(currencyCode);
        final mappedCode = _countryCodeForCurrency(currencyCode);
        String? toSaveIso = mappedCode;
        if (toSaveIso == null) {
          // Try from flag field in the list
          try {
            final cur = _currencies.firstWhere(
              (c) => c['currency_code'] == currencyCode,
              orElse: () => {},
            );
            final raw = cur['flag']?.toString();
            final emojiIso = _countryCodeFromEmoji(raw);
            if (emojiIso != null) toSaveIso = emojiIso;
          } catch (_) {}
        }
        if (toSaveIso != null && toSaveIso.isNotEmpty) {
          await _storageService.saveSelectedCountryCode(toSaveIso);
        }

        if (mounted) {
          setState(() {
            _selectedCurrency = currencyCode;
            _isSettingCurrency = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data['message'] ?? 'Currency set successfully!',
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );

          Navigator.of(context).pop(currencyCode);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSettingCurrency = false;
          });
          _showError(
            response.data?['message'] ?? 'Failed to set currency',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSettingCurrency = false;
        });
        _showError('Error setting currency: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Compact header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                const Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Content
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _currencies.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No currencies available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadCurrencies,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _currencies.length,
                        itemBuilder: (context, index) {
                          final currency = _currencies[index];
                          final currencyCode = currency['currency_code'] as String;
                          final isSelected = _selectedCurrency == currencyCode;
                          final isSetting = _isSettingCurrency &&
                              _selectedCurrency == currencyCode;

                          return InkWell(
                            onTap: isSetting
                                ? null
                                : () {
                                    _setCurrency(currencyCode);
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  // Flag display: prefer local asset flags via package, fallback to emoji, then API URL, then placeholder
                                  Builder(builder: (context) {
                                    final countryCode = _countryCodeForCurrency(currencyCode);
                                    if (countryCode != null && countryCode != 'EU') {
                                      return Container(
                                        width: 32,
                                        height: 24,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 0.5,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: CountryFlag.fromCountryCode(
                                          countryCode,
                                          height: 24,
                                          width: 32,
                                        ),
                                      );
                                    }

                                    // Emoji fallback (e.g., EUR)
                                    final fallbackEmoji = _emojiFlagForCurrency(currencyCode);
                                    if (fallbackEmoji.isNotEmpty) {
                                      return Container(
                                        width: 32,
                                        height: 24,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            fallbackEmoji,
                                            style: const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      );
                                    }

                                    final raw = currency['flag']?.toString() ?? '';
                                    // If API provides an emoji flag, convert to ISO code and use local asset
                                    final emojiIso = _countryCodeFromEmoji(raw);
                                    if (emojiIso != null) {
                                      return Container(
                                        width: 32,
                                        height: 24,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 0.5,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: CountryFlag.fromCountryCode(
                                          emojiIso,
                                          height: 24,
                                          width: 32,
                                        ),
                                      );
                                    }
                                    if (raw.isNotEmpty && (raw.startsWith('http') || raw.startsWith('https')))
                                    {
                                      return Container(
                                        width: 32,
                                        height: 24,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.network(
                                            raw,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.flag,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }

                                    return Container(
                                      width: 32,
                                      height: 24,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.flag,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    );
                                  }),
                                  Expanded(
                                    child: Text(
                                      currencyCode,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.textColor,
                                      ),
                                    ),
                                  ),
                                  if (isSetting)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
