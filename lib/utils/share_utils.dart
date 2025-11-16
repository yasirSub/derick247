import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import '../services/translation_service.dart';

class ShareUtils {
  /// Share a link with an image (product image or app logo)
  static Future<void> shareLinkWithImage({
    required String link,
    String? subject,
    String? productImageUrl,
    BuildContext? context,
  }) async {
    try {
      String? imagePath;
      
      // Try to use product image if available
      if (productImageUrl != null && productImageUrl.isNotEmpty) {
        imagePath = await _downloadAndSaveImage(productImageUrl);
      }
      
      // Fallback to app logo if product image not available
      if (imagePath == null) {
        imagePath = await _getAppLogoPath();
      }
      
      // Share with image if available
      if (imagePath != null && File(imagePath).existsSync()) {
        final xFile = XFile(imagePath);
        await Share.shareXFiles(
          [xFile],
          text: link,
          subject: subject ?? 'Comisionista247',
        );
      } else {
        // Fallback to text-only sharing
        await Share.share(link, subject: subject ?? 'Comisionista247');
      }
    } catch (e) {
      // If sharing with image fails, fallback to text-only
      try {
        await Share.share(link, subject: subject ?? 'Comisionista247');
      } catch (e2) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${TranslationService().translate('app.error')}: $e2',
              ),
            ),
          );
        }
      }
    }
  }

  /// Share text only (for cases where image sharing is not needed)
  static Future<void> shareText({
    required String text,
    String? subject,
    BuildContext? context,
  }) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService().translate('app.error')}: $e',
            ),
          ),
        );
      }
    }
  }

  /// Get app logo path from assets
  static Future<String?> _getAppLogoPath() async {
    try {
      // Try to get the app logo from assets
      final ByteData data = await rootBundle.load('AppIcons/playstore.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/comisionista247_logo.png';
      
      // Write the image to temporary file
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);
      
      return tempPath;
    } catch (e) {
      // If app logo not found, try alternative logo
      try {
        final ByteData data = await rootBundle.load('assets/mobile/equxx icon logo.png');
        final Uint8List bytes = data.buffer.asUint8List();
        
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = '${tempDir.path}/comisionista247_logo.png';
        
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(bytes);
        
        return tempPath;
      } catch (e2) {
        return null;
      }
    }
  }

  /// Download and save product image from URL
  static Future<String?> _downloadAndSaveImage(String imageUrl) async {
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = '${tempDir.path}/product_share_${DateTime.now().millisecondsSinceEpoch}.png';
        
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(response.data!);
        
        return tempPath;
      }
    } catch (e) {
      // If download fails, return null to use app logo
    }
    return null;
  }
}

