import 'package:flutter/material.dart';
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
        // Save to local storage
        await _storageService.saveSelectedCurrency(currencyCode);

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
                                  // Flag display
                                  if (currency['flag'] != null &&
                                      currency['flag'].toString().isNotEmpty)
                                    Container(
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
                                        child: currency['flag'].toString().startsWith('http') ||
                                                currency['flag'].toString().startsWith('https')
                                            ? Image.network(
                                                currency['flag'],
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
                                              )
                                            : Center(
                                                child: Text(
                                                  currency['flag'],
                                                  style: const TextStyle(fontSize: 20),
                                                ),
                                              ),
                                      ),
                                    )
                                  else
                                    Container(
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
                                    ),
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
