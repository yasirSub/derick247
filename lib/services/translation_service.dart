import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Map<String, dynamic> _translations = {};
  String _currentLanguage = 'en';
  final StorageService _storageService = StorageService();

  String get currentLanguage => _currentLanguage;

  // Initialize translation service
  Future<void> initialize() async {
    // Load saved language preference or default to English
    final savedLanguage = await _storageService.getUserPreference<String>(
      'language',
    );
    if (savedLanguage != null) {
      // Map language names to codes
      final languageMap = {'English': 'en', 'Spanish': 'es'};
      _currentLanguage = languageMap[savedLanguage] ?? 'en';
    }
    await loadTranslations(_currentLanguage);
  }

  // Load translations for a specific language
  Future<void> loadTranslations(String languageCode) async {
    try {
      print('🔄 Loading translations for: $languageCode');
      final String jsonString = await rootBundle.loadString(
        'lib/l10n/translations/$languageCode.json',
      );
      _translations = json.decode(jsonString) as Map<String, dynamic>;
      _currentLanguage = languageCode;
      print('✅ Translations loaded successfully. Notifying listeners...');
      notifyListeners(); // Notify listeners when translations change
      print('✅ Listeners notified for language: $languageCode');
    } catch (e) {
      print('❌ Error loading translations for $languageCode: $e');
      // Fallback to English if language file doesn't exist
      if (languageCode != 'en') {
        await loadTranslations('en');
      }
    }
  }

  // Get translation by key (supports nested keys with dot notation)
  String translate(String key, {Map<String, String>? params}) {
    if (_translations.isEmpty) {
      // If translations not loaded yet, return key
      return key;
    }
    final keys = key.split('.');
    dynamic value = _translations;

    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Return key if translation not found
      }
    }

    String translation = value.toString();

    // Replace parameters if provided
    if (params != null) {
      params.forEach((key, value) {
        translation = translation.replaceAll('{$key}', value);
      });
    }

    return translation;
  }

  // Change language
  Future<void> setLanguage(String languageName) async {
    print('🌐 setLanguage called with: $languageName');
    final languageMap = {'English': 'en', 'Spanish': 'es'};

    final languageCode = languageMap[languageName] ?? 'en';
    print('🌐 Loading language code: $languageCode');
    await loadTranslations(languageCode);
    await _storageService.saveUserPreference('language', languageName);
    print('✅ Language preference saved: $languageName');
  }
}
