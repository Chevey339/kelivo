import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/provider_plugin.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

import 'plugin_test_support.dart';

void main() {
  test('manifest round-trip has a stable, full-configuration fingerprint', () {
    final plugin = ProviderPluginManifest.fromJson(manifestJson());
    expect(
      ProviderPluginManifest.parse(jsonEncode(plugin.toJson())).fingerprint,
      plugin.fingerprint,
    );
    final modified = manifestJson()..['baseUrl'] = 'https://other.test/v1';
    expect(
      ProviderPluginManifest.fromJson(modified).fingerprint,
      isNot(plugin.fingerprint),
    );
  });

  for (final key in ['script', 'entrypoint', 'access_token', 'apiKey']) {
    test('rejects forbidden/unknown manifest field $key', () {
      expect(
        () => ProviderPluginManifest.fromJson(manifestJson()..[key] = 'x'),
        throwsFormatException,
      );
    });
  }

  test('rejects client secrets and credentials inside OAuth metadata', () {
    final json = manifestJson();
    (json['oauth'] as Map)['clientSecret'] = 'must-never-be-shipped';
    expect(() => ProviderPluginManifest.fromJson(json), throwsFormatException);
  });

  for (final endpoint in [
    'http://auth.example.test/token',
    'https://user:pass@auth.example.test/token',
    'https://auth.example.test/token?api_key=secret',
    'https://auth.example.test/token#fragment',
    'file:///tmp/token',
  ]) {
    test('rejects unsafe OAuth endpoint $endpoint', () {
      final json = manifestJson();
      (json['oauth'] as Map)['tokenEndpoint'] = endpoint;
      expect(
        () => ProviderPluginManifest.fromJson(json),
        throwsFormatException,
      );
    });
  }

  test(
    'allows explicit loopback development APIs, not arbitrary plain HTTP',
    () {
      expect(
        ProviderPluginManifest.fromJson(
          manifestJson(oauth: false)..['baseUrl'] = 'http://127.0.0.1:8080/v1',
        ).baseUrl.host,
        '127.0.0.1',
      );
      expect(
        () => ProviderPluginManifest.fromJson(
          manifestJson(oauth: false)..['baseUrl'] = 'http://example.test/v1',
        ),
        throwsFormatException,
      );
    },
  );

  test('endpoint confinement is origin- and path-aware', () {
    final plugin = ProviderPluginManifest.fromJson(manifestJson());
    expect(
      plugin.allowsRequest(
        Uri.parse('https://api.example.test/v1/chat/completions'),
      ),
      isTrue,
    );
    for (final url in [
      'https://api.example.test.evil.test/v1/chat',
      'https://api.example.test:444/v1/chat',
      'http://api.example.test/v1/chat',
      'https://api.example.test/v10/chat',
      'https://api.example.test/v1/../outside',
      'https://api.example.test/v1/%2e%2e/outside',
      'https://api.example.test/v1/%252e%252e/outside',
      'https://api.example.test/v1/a%2fb',
      'https://user@api.example.test/v1/chat',
      'https://api.example.test/v1/chat#fragment',
    ]) {
      expect(plugin.allowsRequest(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test('bounds manifest size and hides malformed input in errors', () {
    expect(
      () => ProviderPluginManifest.parse('x' * (256 * 1024 + 1)),
      throwsFormatException,
    );
    try {
      ProviderPluginManifest.parse('secret-api-key{');
      fail('Must reject malformed JSON');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains('secret-api-key')));
    }
  });

  test('models are immutable and duplicates are rejected', () {
    final plugin = ProviderPluginManifest.fromJson(manifestJson());
    expect(() => plugin.models.add('x'), throwsUnsupportedError);
    expect(
      () => ProviderPluginManifest.fromJson(
        manifestJson()..['models'] = ['x', 'x'],
      ),
      throwsFormatException,
    );
  });

  test('configuration round-trip and explicit session clearing', () {
    final config = pluginConfig();
    final restored = ProviderConfig.fromJson(
      (jsonDecode(jsonEncode(config.toJson())) as Map).cast<String, dynamic>(),
    );
    expect(
      restored.providerPlugin!.fingerprint,
      config.providerPlugin!.fingerprint,
    );
    expect(
      restored.providerPluginSession!.credentials.refreshToken,
      'refresh-old',
    );
    expect(restored.copyWith(name: 'renamed').providerPluginSession, isNotNull);
    expect(
      restored.copyWith(providerPluginSession: null).providerPluginSession,
      isNull,
    );
    expect(restored.copyWith(providerPlugin: null).providerPlugin, isNull);
  });

  test('exported manifest never contains API keys or OAuth sessions', () {
    final config = pluginConfig().copyWith(apiKey: 'private-api-key');
    final exported = jsonEncode(config.providerPlugin!.toJson());
    for (final secret in [
      'private-api-key',
      'access-old',
      'refresh-old',
      'session-one',
      'providerPluginSession',
    ]) {
      expect(exported, isNot(contains(secret)));
    }
  });
}
