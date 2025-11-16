import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/translation_service.dart';
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
    final code =
        String.fromCharCode(0x41 + first) + String.fromCharCode(0x41 + second);
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
              if (!currenciesList.any(
                (c) => c['currency_code'] == currencyCode,
              )) {
                currenciesList.add({
                  'currency_code': currencyCode,
                  'country_name':
                      country['name'] ?? country['country_name'] ?? '',
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
              if (!currenciesList.any(
                (c) => c['currency_code'] == currencyCode,
              )) {
                currenciesList.add({
                  'currency_code': currencyCode,
                  'country_name':
                      country['name'] ?? country['country_name'] ?? '',
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
          _showError(
            TranslationService().translate('currency.failedToLoadCurrencies'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(
          TranslationService().translate(
            'currency.errorLoadingCurrencies',
            params: {'error': e.toString()},
          ),
        );
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
                response.data['message'] ??
                    TranslationService().translate(
                      'currency.currencySetSuccessfully',
                    ),
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
            response.data?['message'] ??
                TranslationService().translate('currency.failedToSetCurrency'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSettingCurrency = false;
        });
        _showError(
          TranslationService().translate(
            'currency.errorSettingCurrency',
            params: {'error': e.toString()},
          ),
        );
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
        color: Color(0xFF1A1D24),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            TranslationService().translate('currency.selectCurrency'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
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
                        Text(
                          TranslationService().translate(
                            'currency.noCurrenciesAvailable',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCurrencies,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: Text(
                            TranslationService().translate('app.retry'),
                            style: const TextStyle(color: Colors.white),
                          ),
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
                      final isSetting =
                          _isSettingCurrency &&
                          _selectedCurrency == currencyCode;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RadioListTile<String>(
                          value: currencyCode,
                          groupValue: _selectedCurrency,
                          onChanged: isSetting
                              ? null
                              : (value) {
                                  if (value != null) {
                                    _setCurrency(value);
                                  }
                                },
                          activeColor: Colors.orange,
                          selectedTileColor: Colors.orange.withOpacity(0.1),
                          title: Row(
                            children: [
                              // Flag display
                              Builder(
                                builder: (context) {
                                  final countryCode = _countryCodeForCurrency(
                                    currencyCode,
                                  );
                                  if (countryCode != null &&
                                      countryCode != 'EU') {
                                    return Container(
                                      width: 32,
                                      height: 24,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey[600]!,
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
                                  final fallbackEmoji = _emojiFlagForCurrency(
                                    currencyCode,
                                  );
                                  if (fallbackEmoji.isNotEmpty) {
                                    return Container(
                                      width: 32,
                                      height: 24,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey[600]!,
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

                                  final raw =
                                      currency['flag']?.toString() ?? '';
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
                                          color: Colors.grey[600]!,
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
                                  if (raw.isNotEmpty &&
                                      (raw.startsWith('http') ||
                                          raw.startsWith('https'))) {
                                    return Container(
                                      width: 32,
                                      height: 24,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey[600]!,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          raw,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[700],
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
                                      color: Colors.grey[700],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.flag,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                currencyCode,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isSetting) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
