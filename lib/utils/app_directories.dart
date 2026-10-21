import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Platform-specific application data directory utilities.
///
/// - Windows/macOS/Linux: use the Application Support (app data) directory
///   provided by `path_provider`.
/// - iOS: database state in Application Support; user files in Documents.
/// - Android: Application Documents directory.
class AppDirectories {
  AppDirectories._();

  /// Gets the root directory for application data storage.
  ///
  /// - Windows/macOS/Linux: Application Support directory
  /// - iOS: private Application Support storage
  /// - Android: Application Documents directory
  static Future<Directory> getAppDataDirectory() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return await getApplicationSupportDirectory();
      case TargetPlatform.iOS:
        return Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            privateDataDirectoryName,
          ),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return await getApplicationDocumentsDirectory();
    }
  }

  static const privateDataDirectoryName = 'kelivo-data';

  /// Public iOS files, including the retained original database family.
  static Future<Directory?> documentsDirectoryFor(Directory active) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    final support = await getApplicationSupportDirectory();
    if (!p.equals(
      active.path,
      p.join(support.path, privateDataDirectoryName),
    )) {
      return null;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Files users may access in Files: snapshots, attachments and other assets.
  static Future<Directory> getContentDirectory() async =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? getApplicationDocumentsDirectory()
      : getAppDataDirectory();

  /// Resolve live assets for a database root without redirecting temporary
  /// restore candidates or test directories to the real app container.
  static Future<Directory> contentDirectoryFor(Directory databaseRoot) async =>
      await documentsDirectoryFor(databaseRoot) ?? databaseRoot;

  /// Gets the directory for uploaded files.
  static Future<Directory> getUploadDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/upload');
  }

  /// Gets the directory for image files.
  static Future<Directory> getImagesDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/images');
  }

  /// Gets the directory for avatar files.
  static Future<Directory> getAvatarsDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/avatars');
  }

  /// Gets the directory for user-imported font files.
  static Future<Directory> getFontsDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/fonts');
  }

  /// Gets the directory for cache files.
  static Future<Directory> getCacheDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/cache');
  }

  /// Managed workspace roots: `<appData>/workspaces`.
  static Future<Directory> getWorkspacesDirectory() =>
      _ensureSubdir('workspaces');

  /// Per-conversation session roots: `<appData>/sessions`.
  static Future<Directory> getSessionsDirectory() => _ensureSubdir('sessions');

  /// Installed skill bodies: `<appData>/skills`.
  static Future<Directory> getSkillsDirectory() => _ensureSubdir('skills');

  /// Sandbox environment install root: `<appData>/environment`.
  static Future<Directory> getEnvironmentDirectory() =>
      _ensureSubdir('environment');

  /// Files root for a managed workspace: `<appData>/workspaces/<id>/files`.
  static Future<Directory> workspaceFilesDir(String workspaceId) {
    return _ensurePath('workspaces/$workspaceId/files');
  }

  /// Session root for a conversation, with `attachments/` and `outputs/`.
  static Future<Directory> sessionDir(String conversationId) async {
    final dir = await _ensurePath('sessions/$conversationId');
    await Directory('${dir.path}/attachments').create(recursive: true);
    await Directory('${dir.path}/outputs').create(recursive: true);
    return dir;
  }

  /// Skill body directory: `<appData>/skills/<id>`.
  static Future<Directory> skillDir(String skillId) {
    return _ensurePath('skills/$skillId');
  }

  static Future<Directory> _ensureSubdir(String name) => _ensurePath(name);

  static Future<Directory> _ensurePath(String relativePath) async {
    final root = await getContentDirectory();
    final dir = Directory('${root.path}/$relativePath');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Gets the platform-provided application cache directory.
  ///
  /// - Android: /data/user/0/`<package>`/cache
  /// - iOS/macOS: Caches directory
  /// - Windows/Linux: platform cache directory (app-specific on Linux via XDG)
  static Future<Directory> getSystemCacheDirectory() async {
    return await getApplicationCacheDirectory();
  }

  /// Gets the directory for avatar cache files.
  static Future<Directory> getAvatarCacheDirectory() async {
    final root = await getContentDirectory();
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
  static Future<String?> saveBase64Image(
    String mime,
    String base64Data, {
    String prefix = 'img',
  }) async {
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
      final path =
          '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return path;
    } catch (e) {
      debugPrint('Failed to save image: $e');
      return null;
    }
  }
}
