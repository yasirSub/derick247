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
  /// The text can include product title with link hidden behind it
  static Future<void> shareLinkWithImage({
    required String link,
    String? subject,
    String? productImageUrl,
    String? shareText, // Optional: Custom text (e.g., product title + link)
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
      
      // Format share text - include link for deep linking to work
      // Put link after title with spacing to make it less visible but still functional
      String textToShare;
      if (shareText != null && link.isNotEmpty) {
        // Check if shareText already contains the link
        if (shareText.contains(link)) {
          // Link is already in shareText, use as is
          textToShare = shareText;
        } else {
          // Link is not in shareText, add it after title for deep linking
          // Extract title (first line if multiline)
          final lines = shareText.split('\n');
          final title = lines.first.trim();
          // Include link for deep linking functionality (hidden at bottom with spacing)
          textToShare = '$title\n\n\n\n\n$link';
        }
      } else {
        textToShare = shareText ?? link;
      }
      
      // Share with image if available
      if (imagePath != null && File(imagePath).existsSync()) {
        final xFile = XFile(imagePath);
        // Share with image and text containing link (link is required for deep linking)
        // Link is placed at bottom with spacing to make it less visible
        await Share.shareXFiles(
          [xFile],
          text: textToShare, // Title + link (link at bottom for deep linking)
          subject: subject ?? 'Comisionista247',
        );
      } else {
        // Fallback to text-only sharing
        await Share.share(textToShare, subject: subject ?? 'Comisionista247');
      }
    } catch (e) {
      // If sharing with image fails, fallback to text-only
      try {
        final textToShare = shareText ?? link;
        await Share.share(textToShare, subject: subject ?? 'Comisionista247');
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
      // Ensure URL is absolute
      String url = imageUrl;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // If relative URL, prepend base URL
        url = 'https://comisionista247.com$url';
      }
      
      final dio = Dio();
      
      // Set timeout and follow redirects
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      dio.options.followRedirects = true;
      
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final Directory tempDir = await getTemporaryDirectory();
        
        // Detect file extension from URL or content type
        String extension = 'png';
        final contentType = response.headers.value('content-type');
        if (contentType != null) {
          if (contentType.contains('jpeg') || contentType.contains('jpg')) {
            extension = 'jpg';
          } else if (contentType.contains('png')) {
            extension = 'png';
          } else if (contentType.contains('webp')) {
            extension = 'webp';
          }
        } else {
          // Try to get extension from URL
          final urlLower = url.toLowerCase();
          if (urlLower.contains('.jpg') || urlLower.contains('.jpeg')) {
            extension = 'jpg';
          } else if (urlLower.contains('.png')) {
            extension = 'png';
          } else if (urlLower.contains('.webp')) {
            extension = 'webp';
          }
        }
        
        final String tempPath = '${tempDir.path}/product_share_${DateTime.now().millisecondsSinceEpoch}.$extension';
        
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(response.data!);
        
        // Verify file was created and has content
        if (await tempFile.exists() && await tempFile.length() > 0) {
          return tempPath;
        }
      }
    } catch (e) {
      // If download fails, return null to use app logo
      print('Failed to download product image: $e');
    }
    return null;
  }
}

