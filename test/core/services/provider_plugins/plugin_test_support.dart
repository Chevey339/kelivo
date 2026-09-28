import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/models/provider_plugin.dart';
import 'package:Kelivo/core/models/provider_plugin_session.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/oauth_callback.dart';
import 'package:Kelivo/core/services/provider_plugins/provider_plugin_service.dart';

final testNow = DateTime.utc(2026, 9, 29);

Map<String, dynamic> manifestJson({bool oauth = true}) => {
  'schemaVersion': 1,
  'id': 'test.example.provider',
  'name': 'Example',
  'version': '1.0.0',
  'protocol': 'openai',
  'baseUrl': 'https://api.example.test/v1',
  'models': ['example-model'],
  if (oauth)
    'oauth': {
      'authorizationEndpoint': 'https://auth.example.test/authorize',
      'tokenEndpoint': 'https://auth.example.test/token',
      'clientId': 'public-kelivo-client',
      'scopes': ['inference', 'offline_access'],
    },
};

ProviderConfig pluginConfig({
  String id = 'plugin-test',
  bool expired = false,
  String accessToken = 'access-old',
  String refreshToken = 'refresh-old',
  String sessionId = 'session-one',
  ProviderPluginManifest? manifest,
}) {
  final plugin = manifest ?? ProviderPluginManifest.fromJson(manifestJson());
  return ProviderConfig(
    id: id,
    enabled: true,
    name: plugin.name,
    apiKey: '',
    baseUrl: plugin.baseUrl.toString(),
    providerType: ProviderPluginService.kindFor(plugin),
    useResponseApi: plugin.protocol == 'openai-responses',
    providerPlugin: plugin,
    providerPluginSession: plugin.oauth == null
        ? null
        : ProviderPluginSession(
            manifestFingerprint: plugin.fingerprint,
            credentials: ProviderOAuthCredentials(
              accessToken: accessToken,
              refreshToken: refreshToken,
              expiresAt: expired
                  ? testNow.subtract(const Duration(minutes: 1))
                  : testNow.add(const Duration(hours: 1)),
              sessionId: sessionId,
            ),
          ),
  );
}

class MemoryPluginStore implements ProviderPluginStore {
  MemoryPluginStore([Iterable<ProviderConfig> configs = const []])
    : rows = {for (final config in configs) config.id: config};
  final Map<String, ProviderConfig> rows;

  @override
  ProviderConfig? read(String id) => rows[id];
  @override
  Future<void> save(ProviderConfig config, {bool prepend = false}) async {
    rows[config.id] = config;
  }

  @override
  Future<void> remove(String id) async {
    rows.remove(id);
  }
}

class TestCallback implements OAuthCallback {
  @override
  final redirectUri = Uri.parse('http://127.0.0.1:45823/oauth/callback');
  Uri? authorization;
  bool closed = false;

  @override
  Future<Uri> authorize(
    Uri url,
    Duration timeout,
    OAuthUrlLauncher launcher,
  ) async {
    authorization = url;
    return redirectUri.replace(
      queryParameters: {
        'state': url.queryParameters['state']!,
        'code': 'one-time-code',
      },
    );
  }

  @override
  Future<Uri> waitForCallback(Duration timeout) =>
      throw StateError('authorize() is used in these tests');
  @override
  Future<void> close() async {
    closed = true;
  }
}
