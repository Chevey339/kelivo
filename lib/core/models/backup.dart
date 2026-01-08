import 'dart:convert';

enum RestoreMode {
  overwrite, // 完全覆盖：清空本地后恢复
  merge,     // 增量合并：智能去重
}

enum RestoreAction {
  ignore,    // 忽略：不恢复此项
  merge,     // 合并：增量合并，保留本地配置（适合手机/电脑差异化设置）
  overwrite, // 覆盖：完全覆盖本地配置
}

class RestoreOptions {
  final RestoreAction settingsAction;
  final RestoreAction providersAction;
  final RestoreAction chatsAction;
  final RestoreAction filesAction;

  const RestoreOptions({
    this.settingsAction = RestoreAction.merge,
    this.providersAction = RestoreAction.merge,
    this.chatsAction = RestoreAction.merge,
    this.filesAction = RestoreAction.merge,
  });

  /// Check if this is a legacy full overwrite (all actions are overwrite)
  bool get isFullOverwrite =>
      settingsAction == RestoreAction.overwrite &&
      providersAction == RestoreAction.overwrite &&
      chatsAction == RestoreAction.overwrite &&
      filesAction == RestoreAction.overwrite;

  /// Helper for legacy mode compatibility
  static RestoreOptions fromMode(RestoreMode mode) {
    if (mode == RestoreMode.overwrite) {
      return const RestoreOptions(
        settingsAction: RestoreAction.overwrite,
        providersAction: RestoreAction.overwrite,
        chatsAction: RestoreAction.overwrite,
        filesAction: RestoreAction.overwrite,
      );
    } else {
      return const RestoreOptions(
        settingsAction: RestoreAction.merge,
        providersAction: RestoreAction.merge,
        chatsAction: RestoreAction.merge,
        filesAction: RestoreAction.merge,
      );
    }
  }
}

class WebDavConfig {
  final String url;
  final String username;
  final String password;
  final String path;
  final bool includeChats; // Hive boxes
  final bool includeFiles; // uploads/

  const WebDavConfig({
    this.url = '',
    this.username = '',
    this.password = '',
    this.path = 'kelivo_backups',
    this.includeChats = true,
    this.includeFiles = true,
  });

  WebDavConfig copyWith({
    String? url,
    String? username,
    String? password,
    String? path,
    bool? includeChats,
    bool? includeFiles,
  }) {
    return WebDavConfig(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      path: path ?? this.path,
      includeChats: includeChats ?? this.includeChats,
      includeFiles: includeFiles ?? this.includeFiles,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'path': path,
        'includeChats': includeChats,
        'includeFiles': includeFiles,
      };

  static WebDavConfig fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      url: (json['url'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      password: (json['password'] as String?) ?? '',
      path: (json['path'] as String?)?.trim().isNotEmpty == true
          ? (json['path'] as String).trim()
          : 'kelivo_backups',
      includeChats: json['includeChats'] as bool? ?? true,
      includeFiles: json['includeFiles'] as bool? ?? true,
    );
  }

  static WebDavConfig fromJsonString(String s) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return WebDavConfig.fromJson(map);
    } catch (_) {
      return const WebDavConfig();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}

class BackupFileItem {
  final Uri href; // absolute
  final String displayName;
  final int size;
  final DateTime? lastModified;
  const BackupFileItem({
    required this.href,
    required this.displayName,
    required this.size,
    required this.lastModified,
  });
}

