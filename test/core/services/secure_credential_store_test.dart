import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/services/secure_credential_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('migrates credential leaves and hydrates the config shape', () async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode({
      'openai': {
        'id': 'openai',
        'name': 'OpenAI',
        'apiKey': 'primary-secret',
        'baseUrl': 'https://user:pass@example.test/v1',
        'apiKeys': [
          {'id': 'secondary', 'key': 'secondary-secret', 'enabled': true},
        ],
      },
    });
    await prefs.setString('provider_configs_v1', raw);
    const store = SecureCredentialStore();

    final hydrated = await store.readProtectedJson(
      prefs,
      'provider_configs_v1',
    );
    final persisted = prefs.getString('provider_configs_v1')!;

    expect(hydrated, raw);
    expect(persisted, isNot(contains('primary-secret')));
    expect(persisted, isNot(contains('secondary-secret')));
    expect(persisted, isNot(contains('user:pass')));
    expect(
      (await const FlutterSecureStorage().readAll()).values.join(),
      contains('primary-secret'),
    );
  });

  test('moves scalar passwords out of SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'global_proxy_password_v1': 'proxy-secret',
    });
    final prefs = await SharedPreferences.getInstance();
    const store = SecureCredentialStore();

    expect(
      await store.readSecret(prefs, 'global_proxy_password_v1'),
      'proxy-secret',
    );
    expect(prefs.containsKey('global_proxy_password_v1'), isFalse);
    expect(
      await const FlutterSecureStorage().read(
        key: 'kelivo.credentials.v1.value.global_proxy_password_v1',
      ),
      'proxy-secret',
    );
  });
}
