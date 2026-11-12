import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';

/// All Windows tabs and their download cookies share one writable profile.
/// The selected app data directory also covers portable/custom installations.
class BrowserWindowsEnvironment {
  BrowserWindowsEnvironment({Future<Directory> Function()? dataDirectory})
    : _dataDirectory = dataDirectory ?? AppDirectories.getAppDataDirectory;

  static final instance = BrowserWindowsEnvironment();

  final Future<Directory> Function() _dataDirectory;
  Future<WebViewEnvironment>? _environment;

  Future<WebViewEnvironment> get() => _environment ??= _create();

  Future<WebViewEnvironment> _create() async {
    try {
      final root = await _dataDirectory();
      final profile = Directory(p.join(root.path, 'browser', 'webview2'));
      await profile.create(recursive: true);
      return await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: profile.path),
      );
    } catch (_) {
      // A failed Runtime/profile initialization must not poison later retries.
      _environment = null;
      rethrow;
    }
  }
}
