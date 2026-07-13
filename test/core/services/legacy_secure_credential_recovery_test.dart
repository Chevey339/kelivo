import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/services/legacy_secure_credential_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('recovers provider keys and scalar secrets into preferences', () async {
    final sanitizedProviders = jsonEncode({
      'openai': {
        'id': 'openai',
        'apiKey': '',
        'apiKeys': [
          {'id': 'secondary', 'key': '', 'enabled': true},
        ],
      },
    });
    SharedPreferences.setMockInitialValues({
      'provider_configs_v1': sanitizedProviders,
    });
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'kelivo.credentials.v1.json.provider_configs_v1',
      value: jsonEncode([
        {
          'path': ['openai', 'apiKey'],
          'value': 'primary-secret',
        },
        {
          'path': ['openai', 'apiKeys', 0, 'key'],
          'value': 'secondary-secret',
        },
      ]),
    );
    await storage.write(
      key: 'kelivo.credentials.v1.value.global_proxy_password_v1',
      value: 'proxy-secret',
    );

    final prefs = await SharedPreferences.getInstance();
    final changed = await const LegacySecureCredentialRecovery().recover(prefs);

    expect(changed, isTrue);
    final providers =
        jsonDecode(prefs.getString('provider_configs_v1')!) as Map;
    expect((providers['openai'] as Map)['apiKey'], 'primary-secret');
    expect(
      (((providers['openai'] as Map)['apiKeys'] as List).single as Map)['key'],
      'secondary-secret',
    );
    expect(prefs.getString('global_proxy_password_v1'), 'proxy-secret');
    expect(
      await storage.read(key: 'kelivo.credentials.v1.json.provider_configs_v1'),
      isNull,
    );
  });

  test('does not overwrite a newer preference credential', () async {
    SharedPreferences.setMockInitialValues({
      'provider_configs_v1': jsonEncode({
        'openai': {'id': 'openai', 'apiKey': 'new-secret'},
      }),
    });
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'kelivo.credentials.v1.json.provider_configs_v1',
      value: jsonEncode([
        {
          'path': ['openai', 'apiKey'],
          'value': 'old-secret',
        },
      ]),
    );

    final prefs = await SharedPreferences.getInstance();
    await const LegacySecureCredentialRecovery().recover(prefs);

    final providers =
        jsonDecode(prefs.getString('provider_configs_v1')!) as Map;
    expect((providers['openai'] as Map)['apiKey'], 'new-secret');
  });
}
