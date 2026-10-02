import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A data-only plugin. Importing a manifest never executes code or sends HTTP.
/// Transport implementations remain Kelivo's built-in, audited protocols.
class ProviderPluginManifest {
  ProviderPluginManifest._({
    required this.id,
    required this.name,
    required this.version,
    required this.protocol,
    required this.baseUrl,
    required this.models,
    required this.oauth,
  });

  static const maxBytes = 256 * 1024;
  final String id;
  final String name;
  final String version;
  final String protocol;
  final Uri baseUrl;
  final List<String> models;
  final ProviderPluginOAuth? oauth;

  static ProviderPluginManifest parse(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('Provider plugin exceeds 256 KiB');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      // Do not include the input: a mistaken import could contain credentials.
      throw const FormatException('Invalid provider plugin JSON');
    }
    return ProviderPluginManifest.fromJson(_object(decoded));
  }

  factory ProviderPluginManifest.fromJson(Map<String, dynamic> json) {
    _keys(json, const {
      'schemaVersion',
      'id',
      'name',
      'version',
      'protocol',
      'baseUrl',
      'models',
      'oauth',
    });
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported provider plugin schema');
    }
    final id = _text(json, 'id', max: 128);
    if (!RegExp(r'^[a-z0-9]+(?:[.-][a-z0-9]+)+$').hasMatch(id)) {
      throw const FormatException('Plugin id must be a reverse-domain id');
    }
    final protocol = _text(json, 'protocol');
    if (!const {
      'openai',
      'openai-responses',
      'anthropic',
      'gemini',
    }.contains(protocol)) {
      throw const FormatException('Unsupported provider plugin protocol');
    }
    final base = _endpoint(_text(json, 'baseUrl'), allowLoopback: true);
    final baseUrl = base.replace(
      path: base.path.replaceFirst(RegExp(r'/+$'), ''),
    );
    final models = _strings(json['models'] ?? const [], maxCount: 1024);
    if (models.toSet().length != models.length) {
      throw const FormatException('Duplicate plugin model ids');
    }
    return ProviderPluginManifest._(
      id: id,
      name: _text(json, 'name', max: 128),
      version: _text(json, 'version', max: 64),
      protocol: protocol,
      baseUrl: baseUrl,
      models: List.unmodifiable(models),
      oauth: json['oauth'] == null
          ? null
          : ProviderPluginOAuth.fromJson(_object(json['oauth'])),
    );
  }

  /// Binds a login to the complete approved manifest, not merely its name/id.
  String get fingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'version': version,
    'protocol': protocol,
    'baseUrl': baseUrl.toString(),
    'models': models,
    if (oauth != null) 'oauth': oauth!.toJson(),
  };

  /// Credential-bearing requests may only target the approved API subtree.
  bool allowsRequest(Uri uri) {
    if (uri.scheme != baseUrl.scheme ||
        uri.host != baseUrl.host ||
        uri.port != baseUrl.port ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_safePath(uri)) {
      return false;
    }
    final prefix = baseUrl.path;
    return prefix.isEmpty ||
        uri.path == prefix ||
        uri.path.startsWith('$prefix/');
  }
}

class ProviderPluginOAuth {
  ProviderPluginOAuth._({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.scopes,
    required this.issuer,
    required this.loopbackRedirect,
  });

  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final String clientId;
  final List<String> scopes;

  /// When configured, the authorization response must contain a matching iss.
  final Uri? issuer;

  /// Omit to use Kelivo's platform-native callback. Port zero is allocated by
  /// the OS. Fixed ports are allowed for providers requiring registered URLs.
  final Uri? loopbackRedirect;

  factory ProviderPluginOAuth.fromJson(Map<String, dynamic> json) {
    _keys(json, const {
      'authorizationEndpoint',
      'tokenEndpoint',
      'clientId',
      'scopes',
      'issuer',
      'loopbackRedirect',
    });
    final scopes = _strings(json['scopes'] ?? const [], maxCount: 64);
    for (final scope in scopes) {
      if (!RegExp(r'^[\x21\x23-\x5B\x5D-\x7E]+$').hasMatch(scope)) {
        throw const FormatException('Invalid OAuth scope');
      }
    }
    Uri? redirect;
    if (json['loopbackRedirect'] != null) {
      redirect = Uri.tryParse(_text(json, 'loopbackRedirect'));
      if (redirect == null ||
          redirect.scheme != 'http' ||
          redirect.host != '127.0.0.1' ||
          !redirect.hasPort ||
          redirect.port < 0 ||
          redirect.port > 65535 ||
          redirect.userInfo.isNotEmpty ||
          redirect.hasQuery ||
          redirect.hasFragment ||
          redirect.path.isEmpty ||
          !_safePath(redirect)) {
        throw const FormatException('Invalid OAuth loopback redirect');
      }
    }
    return ProviderPluginOAuth._(
      authorizationEndpoint: _endpoint(_text(json, 'authorizationEndpoint')),
      tokenEndpoint: _endpoint(_text(json, 'tokenEndpoint')),
      clientId: _text(json, 'clientId', max: 512),
      scopes: List.unmodifiable(scopes),
      issuer: json['issuer'] == null ? null : _endpoint(_text(json, 'issuer')),
      loopbackRedirect: redirect,
    );
  }

  Map<String, dynamic> toJson() => {
    'authorizationEndpoint': authorizationEndpoint.toString(),
    'tokenEndpoint': tokenEndpoint.toString(),
    'clientId': clientId,
    'scopes': scopes,
    if (issuer != null) 'issuer': issuer.toString(),
    if (loopbackRedirect != null)
      'loopbackRedirect': loopbackRedirect.toString(),
  };
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}

void _keys(Map<String, dynamic> json, Set<String> allowed) {
  if (json.keys.any((key) => !allowed.contains(key))) {
    // Reject unknown fields, including scripts, client secrets and tokens.
    throw const FormatException('Unknown provider plugin field');
  }
}

String _text(Map<String, dynamic> json, String key, {int max = 4096}) {
  final value = json[key];
  if (value is! String ||
      value.isEmpty ||
      value.trim() != value ||
      value.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw FormatException('Invalid $key');
  }
  return value;
}

List<String> _strings(Object? value, {required int maxCount}) {
  if (value is! List || value.length > maxCount) {
    throw const FormatException('Invalid provider plugin list');
  }
  return [
    for (final item in value) _text({'item': item}, 'item', max: 256),
  ];
}

Uri _endpoint(String source, {bool allowLoopback = false}) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      !(uri.scheme == 'https' ||
          (allowLoopback &&
              uri.scheme == 'http' &&
              const {'127.0.0.1', '::1'}.contains(uri.host))) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port < 1 ||
      uri.port > 65535 ||
      !_safePath(uri)) {
    throw const FormatException('Invalid provider plugin endpoint');
  }
  return uri;
}

bool _safePath(Uri uri) => !uri.pathSegments.any(
  (segment) =>
      segment == '.' ||
      segment == '..' ||
      segment.contains('/') ||
      segment.contains('\\') ||
      segment.contains('%') ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(segment),
);
