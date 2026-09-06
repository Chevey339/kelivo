import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'persists CRUD and privacy, preserving Unicode and whitespace',
    () async {
      final harness = await createBusinessTestHarness();
      final env = EnvironmentProvider(preferences: harness.preferences);
      addTearDown(env.dispose);
      await env.loaded;
      expect(env.privacyMode, isTrue);
      await env.saveVariable(
        const EnvironmentVariable(
          name: ' API_KEY ',
          value: ' 密钥\n"abc" ',
          note: ' service ',
        ),
      );
      final snapshot = await env.loadExecutionConfig();
      await env.saveVariable(
        const EnvironmentVariable(name: 'NEW_KEY', value: 'new-secret'),
        previousName: 'API_KEY',
      );
      await env.setPrivacyMode(false);
      final restored = EnvironmentProvider(preferences: harness.preferences);
      addTearDown(restored.dispose);
      await restored.loaded;
      expect(restored.variables.single.name, 'NEW_KEY');
      expect(restored.variables.single.value, 'new-secret');
      expect(restored.privacyMode, isFalse);
      expect(snapshot.variables, {'API_KEY': ' 密钥\n"abc" '});
      expect(snapshot.privacyMode, isTrue);
      await restored.deleteVariable('NEW_KEY');
      final reloaded = EnvironmentProvider(preferences: harness.preferences);
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.variables, isEmpty);
    },
  );

  test(
    'validates names and values, rejects duplicates and recovers after failure',
    () async {
      final harness = await createBusinessTestHarness();
      final env = EnvironmentProvider(preferences: harness.preferences);
      addTearDown(env.dispose);
      for (final name in ['1KEY', 'A=B', 'KEY\nBAD', '']) {
        await expectLater(
          env.saveVariable(EnvironmentVariable(name: name, value: 'secret')),
          throwsA(EnvironmentVariableError.invalidName),
        );
      }
      for (final value in ['', 'bad\u0000value']) {
        await expectLater(
          env.saveVariable(EnvironmentVariable(name: 'KEY', value: value)),
          throwsA(EnvironmentVariableError.invalidValue),
        );
      }
      await env.saveVariable(
        const EnvironmentVariable(name: '_KEY', value: 'secret'),
      );
      await expectLater(
        env.saveVariable(
          const EnvironmentVariable(name: '_KEY', value: 'replacement'),
        ),
        throwsA(EnvironmentVariableError.duplicateName),
      );
      expect(env.variables.single.value, 'secret');
      await env.saveVariable(
        const EnvironmentVariable(name: 'OTHER', value: 'other'),
      );
      await expectLater(
        env.saveVariable(
          const EnvironmentVariable(name: '_KEY', value: 'changed'),
          previousName: 'OTHER',
        ),
        throwsA(EnvironmentVariableError.duplicateName),
      );
      expect(env.variables.length, 2);
    },
  );

  test(
    'concurrent saves during loading do not overwrite one another',
    () async {
      final env = EnvironmentProvider(
        preferences: createBusinessTestPreferences(),
      );
      addTearDown(env.dispose);
      await Future.wait([
        env.saveVariable(
          const EnvironmentVariable(name: 'FIRST', value: 'first'),
        ),
        env.saveVariable(
          const EnvironmentVariable(name: 'SECOND', value: 'second'),
        ),
        env.setPrivacyMode(false),
      ]);
      expect((await env.loadExecutionConfig()).variables, {
        'FIRST': 'first',
        'SECOND': 'second',
      });
      expect(env.privacyMode, isFalse);
    },
  );
}
