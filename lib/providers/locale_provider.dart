import 'package:flutter/material.dart';
import '../services/translation_service.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en'); // Default to English
  TranslationService? _translationService;

  Locale get locale => _locale;

  // Language name to Locale mapping
  final Map<String, Locale> _languageMap = {
    'English': const Locale('en'),
    'Spanish': const Locale('es'),
  };

  // Initialize locale from storage
  Future<void> initialize() async {
    _translationService = TranslationService();
    await _translationService!.initialize();
    final currentLanguageCode = _translationService!.currentLanguage;
    _locale = Locale(currentLanguageCode);
    notifyListeners();
  }

  // Change language
  Future<void> setLanguage(String languageName) async {
    print('🌍 LocaleProvider.setLanguage called: $languageName');
    if (_languageMap.containsKey(languageName)) {
      _translationService ??= TranslationService();
      await _translationService!.setLanguage(languageName);
      _locale = _languageMap[languageName]!;
      print('🌍 Locale updated to: $_locale');
      // Force both providers to notify listeners
      notifyListeners();
      print('🌍 LocaleProvider listeners notified');
      // Also ensure TranslationService notifies (it should already be notified, but ensure it)
      if (_translationService != null) {
        _translationService!.notifyListeners();
        print('🌍 TranslationService listeners notified');
      }
    } else {
      print('⚠️ Language not found in map: $languageName');
    }
  }

  Locale? getLocaleFromLanguageName(String languageName) {
    return _languageMap[languageName];
  }
}
