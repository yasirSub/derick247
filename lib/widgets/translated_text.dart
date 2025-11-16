import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/translation_service.dart';
import '../providers/locale_provider.dart';

/// A widget that automatically translates text and rebuilds when language changes
class TranslatedText extends StatelessWidget {
  final String translationKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String>? params;

  const TranslatedText(
    this.translationKey, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.params,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to LocaleProvider to rebuild when language changes
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final translationService = TranslationService();
        return Text(
          translationService.translate(translationKey, params: params),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

/// Extension to easily get translations in any widget
extension TranslationExtension on BuildContext {
  String translate(String key, {Map<String, String>? params}) {
    // Use listen: false to allow calling from event handlers
    Provider.of<LocaleProvider>(this, listen: false);
    return TranslationService().translate(key, params: params);
  }
}

