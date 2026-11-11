import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import '../../support/business_test_harness.dart';

void main() {
  test('native shell path persists and can be reset to automatic', () async {
    final prefs = createBusinessTestPreferences();
    final env = EnvironmentProvider(preferences: prefs);
    await env.setNativeShellPath(' /bin/zsh ');
    final restored = EnvironmentProvider(preferences: prefs);
    await restored.loaded;
    expect(restored.nativeShellPath, '/bin/zsh');
    await restored.setNativeShellPath('');
    expect(restored.nativeShellPath, isEmpty);
    final automatic = EnvironmentProvider(preferences: prefs);
    await automatic.loaded;
    expect(automatic.nativeShellPath, isEmpty);
    await expectLater(
      automatic.setNativeShellPath('/bin/sh\u0000'),
      throwsFormatException,
    );
  });
}
