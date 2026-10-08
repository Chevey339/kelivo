import 'dart:convert';

import 'backup_scope.dart';
export 'backup_scope.dart';

enum RestoreMode {
  overwrite, // 覆盖所选内容，保留未选内容
  merge, // 增量合并：智能去重
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

  static WebDavConfig fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      url: (json['url'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      password: (json['password'] as String?) ?? '',
      path: (json['path'] as String?)?.trim().isNotEmpty == true
          ? (json['path'] as String).trim()
          : 'kelivo_backups',
      userAgent: (json['userAgent'] as String?) ?? '',
      scope: BackupScope.fromJson(json['scope']),
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

  static S3Config fromJson(Map<String, dynamic> json) {
    return S3Config(
      endpoint: (json['endpoint'] as String?)?.trim() ?? '',
      region: (json['region'] as String?)?.trim().isNotEmpty == true
          ? (json['region'] as String).trim()
          : 'us-east-1',
      bucket: (json['bucket'] as String?)?.trim() ?? '',
      accessKeyId: (json['accessKeyId'] as String?)?.trim() ?? '',
      secretAccessKey: (json['secretAccessKey'] as String?) ?? '',
      sessionToken: (json['sessionToken'] as String?) ?? '',
      prefix: (json['prefix'] as String?)?.trim().isNotEmpty == true
          ? (json['prefix'] as String).trim()
          : 'kelivo_backups',
      pathStyle: json['pathStyle'] as bool? ?? true,
      userAgent: (json['userAgent'] as String?) ?? '',
      scope: BackupScope.fromJson(json['scope']),
    );
  }

  static S3Config fromJsonString(String s) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return S3Config.fromJson(map);
    } catch (_) {
      return const S3Config();
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
