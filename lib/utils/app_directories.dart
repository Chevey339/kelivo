import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Platform-specific application data directory utilities.
///
/// - Windows/macOS/Linux: use the Application Support (app data) directory
///   provided by `path_provider`.
/// - Android/iOS: keep using the Application Documents directory.
class AppDirectories {
  AppDirectories._();

  /// Gets the root directory for application data storage.
  ///
  /// - Windows/macOS/Linux: Application Support directory
  /// - Android/iOS: Application Documents directory
  static Future<Directory> getAppDataDirectory() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return await getApplicationSupportDirectory();
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return await getApplicationDocumentsDirectory();
    }
  }

  /// Gets the directory for uploaded files.
  static Future<Directory> getUploadDirectory() async {
    final root = await getAppDataDirectory();
    return Directory('${root.path}/upload');
  }

  /// Gets the directory for image files.
  static Future<Directory> getImagesDirectory() async {
    final root = await getAppDataDirectory();
    return Directory('${root.path}/images');
  }

  /// Gets the directory for avatar files.
  static Future<Directory> getAvatarsDirectory() async {
    final root = await getAppDataDirectory();
    return Directory('${root.path}/avatars');
  }

  /// Gets the directory for cache files.
  static Future<Directory> getCacheDirectory() async {
    final root = await getAppDataDirectory();
    return Directory('${root.path}/cache');
  }

  /// Gets the platform-provided application cache directory.
  ///
  /// - Android: /data/user/0/`<package>`/cache
  /// - iOS/macOS: Caches directory
  /// - Windows/Linux: platform cache directory (app-specific on Linux via XDG)
  static Future<Directory> getSystemCacheDirectory() async {
    // TODO: Add error handling for getApplicationCacheDirectory; fallback to getCacheDirectory.
    return await getApplicationCacheDirectory();
  }

  /// Gets the directory for avatar cache files.
  static Future<Directory> getAvatarCacheDirectory() async {
    final root = await getAppDataDirectory();
    return Directory('${root.path}/cache/avatars');
  }

  /// Get file extension from MIME type
  static String extFromMime(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      default:
        return 'png';
    }
  }

  /// Save base64 image data to images directory.
  /// [prefix] is used for filename (e.g. 'img', 'mcp_img').
  /// Returns the saved file path, or null if failed.
  static Future<String?> saveBase64Image(String mime, String base64Data, {String prefix = 'img'}) async {
    try {
      final dir = await getImagesDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final cleaned = base64Data.replaceAll(RegExp(r'\s'), '');
      List<int> bytes;
      // Support both standard base64 and URL-safe base64
      if (cleaned.contains('-') || cleaned.contains('_')) {
        bytes = base64Url.decode(cleaned);
      } else {
        bytes = base64Decode(cleaned);
      }
      final ext = extFromMime(mime);
      final path = '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return path;
    } catch (e) {
      debugPrint('Failed to save image: $e');
      return null;
    }
  }
}
