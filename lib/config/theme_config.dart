import 'package:flutter/material.dart';

class AppTheme {
  // Colors based on the website design
  static const Color primaryColor = Color(0xFF2563EB); // Blue
  static const Color secondaryColor = Color(0xFFF59E0B); // Orange/Yellow
  static const Color backgroundColor = Color(0xFFF8FAFC); // Light gray
  static const Color cardColor = Color(0xFFFFFFFF); // White
  static const Color textColor = Color(0xFF1F2937); // Dark gray
  static const Color textSecondaryColor = Color(0xFF6B7280); // Medium gray
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color successColor = Color(0xFF10B981); // Green
  
  // Unified Design System Colors
  static const Color darkAppBarColor = Color(0xFF2D2D2D); // Dark gray for app bars
  static const Color lightAppBarColor = Color(0xFFFFFFFF); // White for some app bars
  static const Color dividerColor = Color(0xFFE5E7EB); // Light gray divider
  static const Color shadowColor = Color(0x1A000000); // 10% opacity black for shadows

  // Font sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 18.0;
  static const double fontSizeXXLarge = 24.0;
  static const double fontSizeTitle = 20.0;

  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0; // For pill-shaped elements

  // Elevation/Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // App theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightAppBarColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        shadowColor: shadowColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondaryColor,
          side: const BorderSide(color: secondaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: secondaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingMedium,
        ),
      ),
    );
  }
  
  // Reusable card widget helper
  static Widget buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: spacingMedium),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(radiusMedium),
        shadowColor: shadowColor,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusMedium),
          child: Container(
            padding: padding ?? const EdgeInsets.all(spacingMedium),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(radiusMedium),
              boxShadow: cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
  
  // Reusable section title
  static Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacingMedium),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: fontSizeTitle,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
