import 'dart:convert';

import 'backup_scope.dart';
export 'backup_scope.dart';

class BackupSettingsSaveException implements Exception {
  const BackupSettingsSaveException();
}

enum RestoreMode {
  overwrite, // 覆盖所选内容，保留未选内容
  merge, // 增量合并：智能去重
}

Map<String, dynamic>? _decodeBackupPreference(
  Object? stored,
  void Function(String?)? onInvalidField,
) {
  if (stored == null) return null;
  if (stored is String) {
    try {
      final json = jsonDecode(stored);
      if (json is Map<String, dynamic>) return json;
    } on FormatException {
      // The decoder's exception may contain the stored credentials.
    }
  }
  onInvalidField?.call(null);
  return null;
}

class _BackupConfigFields {
  const _BackupConfigFields(this.json, this.onInvalidField);

  final Map<String, dynamic> json;
  final void Function(String)? onInvalidField;

  T? read<T>(String name) {
    final value = json[name];
    if (value is T) return value;
    if (json.containsKey(name)) onInvalidField?.call(name);
    return null;
  }

  String trimmed(String name, [String fallback = '']) {
    final value = read<String>(name)?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  BackupScope get scope {
    final flags = read<Map<String, dynamic>>('scope');
    if (flags == null) return const BackupScope();
    final valid = <String, bool>{};
    for (final category in BackupCategory.values) {
      final name = category.name;
      final enabled = flags[name];
      if (enabled is bool) {
        valid[name] = enabled;
      } else if (flags.containsKey(name)) {
        onInvalidField?.call('scope.$name');
      }
    }
    return BackupScope.fromJson(valid);
  }
}

class WebDavConfig {
  final String url;
  final String username;
  final String password;
  final String path;
  final String userAgent;
  final BackupScope scope;

  const WebDavConfig({
    this.url = '',
    this.username = '',
    this.password = '',
    this.path = 'kelivo_backups',
    this.userAgent = '',
    this.scope = const BackupScope(),
  });

  WebDavConfig copyWith({
    String? url,
    String? username,
    String? password,
    String? path,
    String? userAgent,
    BackupScope? scope,
  }) {
    return WebDavConfig(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      path: path ?? this.path,
      userAgent: userAgent ?? this.userAgent,
      scope: scope ?? this.scope,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'username': username,
    'password': password,
    'path': path,
    'userAgent': userAgent,
    'scope': scope.toJson(),
  };

  static WebDavConfig fromJson(
    Map<String, dynamic> json, {
    void Function(String)? onInvalidField,
  }) {
    final fields = _BackupConfigFields(json, onInvalidField);
    return WebDavConfig(
      url: fields.trimmed('url'),
      username: fields.trimmed('username'),
      password: fields.read<String>('password') ?? '',
      path: fields.trimmed('path', const WebDavConfig().path),
      userAgent: fields.read<String>('userAgent') ?? '',
      scope: fields.scope,
    );
  }

  static WebDavConfig fromPreference(
    Object? stored, {
    void Function(String?)? onInvalidField,
  }) {
    final json = _decodeBackupPreference(stored, onInvalidField);
    return json == null
        ? const WebDavConfig()
        : fromJson(json, onInvalidField: onInvalidField);
  }

  String toJsonString() => jsonEncode(toJson());
}

class S3Config {
  final String
  endpoint; // e.g. https://s3.amazonaws.com or https://<accountid>.r2.cloudflarestorage.com
  final String
  region; // e.g. us-east-1 / auto (for some S3-compatible providers)
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken; // optional
  final String prefix; // object key prefix/folder
  final bool
  pathStyle; // safer for custom endpoints (no bucket subdomain TLS mismatch)
  final String userAgent;
  final BackupScope scope;

  const S3Config({
    this.endpoint = '',
    this.region = 'us-east-1',
    this.bucket = '',
    this.accessKeyId = '',
    this.secretAccessKey = '',
    this.sessionToken = '',
    this.prefix = 'kelivo_backups',
    this.pathStyle = true,
    this.userAgent = '',
    this.scope = const BackupScope(),
  });

  S3Config copyWith({
    String? endpoint,
    String? region,
    String? bucket,
    String? accessKeyId,
    String? secretAccessKey,
    String? sessionToken,
    String? prefix,
    bool? pathStyle,
    String? userAgent,
    BackupScope? scope,
  }) {
    return S3Config(
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      bucket: bucket ?? this.bucket,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      secretAccessKey: secretAccessKey ?? this.secretAccessKey,
      sessionToken: sessionToken ?? this.sessionToken,
      prefix: prefix ?? this.prefix,
      pathStyle: pathStyle ?? this.pathStyle,
      userAgent: userAgent ?? this.userAgent,
      scope: scope ?? this.scope,
    );
  }

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'region': region,
    'bucket': bucket,
    'accessKeyId': accessKeyId,
    'secretAccessKey': secretAccessKey,
    'sessionToken': sessionToken,
    'prefix': prefix,
    'pathStyle': pathStyle,
    'userAgent': userAgent,
    'scope': scope.toJson(),
  };

  static S3Config fromJson(
    Map<String, dynamic> json, {
    void Function(String)? onInvalidField,
  }) {
    final fields = _BackupConfigFields(json, onInvalidField);
    return S3Config(
      endpoint: fields.trimmed('endpoint'),
      region: fields.trimmed('region', const S3Config().region),
      bucket: fields.trimmed('bucket'),
      accessKeyId: fields.trimmed('accessKeyId'),
      secretAccessKey: fields.read<String>('secretAccessKey') ?? '',
      sessionToken: fields.read<String>('sessionToken') ?? '',
      prefix: fields.trimmed('prefix', const S3Config().prefix),
      pathStyle: fields.read<bool>('pathStyle') ?? const S3Config().pathStyle,
      userAgent: fields.read<String>('userAgent') ?? '',
      scope: fields.scope,
    );
  }

  static S3Config fromPreference(
    Object? stored, {
    void Function(String?)? onInvalidField,
  }) {
    final json = _decodeBackupPreference(stored, onInvalidField);
    return json == null
        ? const S3Config()
        : fromJson(json, onInvalidField: onInvalidField);
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
