import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 平台工具类，提供跨平台兼容性支持
class PlatformUtils {
  /// 检查是否为桌面平台
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 检查是否为移动平台
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 检查是否为Windows平台
  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// 安全地检查文件是否存在
  static bool fileExistsSync(String path) {
    if (kIsWeb) return false;
    try {
      return File(path).existsSync();
    } catch (e) {
      return false;
    }
  }

  /// 安全地检查文件是否存在（异步）
  static Future<bool> fileExists(String path) async {
    if (kIsWeb) return false;
    try {
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }

  /// 安全地读取文件
  static Future<List<int>?> readFileBytes(String path) async {
    if (kIsWeb) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error reading file: $e');
    }
    return null;
  }

  /// 安全地写入文件
  static Future<bool> writeFileBytes(String path, List<int> bytes) async {
    if (kIsWeb) return false;
    try {
      final file = File(path);
      await file.writeAsBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('Error writing file: $e');
      return false;
    }
  }

  /// 安全地调用平台特定的插件
  static Future<T?> callPlatformMethod<T>(Future<T> Function() method, {T? fallback}) async {
    try {
      return await method();
    } on MissingPluginException catch (e) {
      debugPrint('Plugin not available: $e');
      return fallback;
    } on PlatformException catch (e) {
      debugPrint('Platform error: $e');
      return fallback;
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return fallback;
    }
  }

  /// 检查插件是否可用
  static Future<bool> isPluginAvailable(Future<void> Function() testMethod) async {
    try {
      await testMethod();
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 获取支持的文件选择器扩展名
  static List<String> getSupportedFileExtensions() {
    if (isWindows) {
      // Windows支持的文件类型
      return ['pdf', 'txt', 'doc', 'docx', 'md', 'json', 'xml', 'csv'];
    }
    // 其他平台
    return ['*'];
  }

  /// 检查是否支持触觉反馈
  static bool get supportsHapticFeedback {
    return isMobile && !kIsWeb;
  }

  /// 检查是否支持文件分享
  static bool get supportsFileSharing {
    return !kIsWeb;
  }

  /// 检查是否支持相机
  static bool get supportsCamera {
    if (kIsWeb) return true; // Web通过浏览器API支持
    if (isWindows) return false; // Windows桌面版暂不支持相机
    return true;
  }

  /// 获取临时目录路径（Windows兼容）
  static Future<String?> getTempDirectoryPath() async {
    if (kIsWeb) return null;
    try {
      if (isWindows) {
        // Windows特殊处理
        final tempPath = Platform.environment['TEMP'] ?? Platform.environment['TMP'];
        if (tempPath != null) return tempPath;
      }
      // 使用path_provider的通用方法
      return null; // 将在具体使用时调用path_provider
    } catch (e) {
      debugPrint('Error getting temp directory: $e');
      return null;
    }
  }
}
