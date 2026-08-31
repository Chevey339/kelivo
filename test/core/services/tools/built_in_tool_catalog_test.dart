import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/core/services/tools/built_in_tool_catalog.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(DeviceLocalTools.debugResetIosCapabilities);
  tearDown(() {
    DeviceLocalTools.debugResetIosCapabilities();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'iOS weather and health stay out of the catalog until capabilities resolve',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final before = BuiltInToolCatalog.entries(
        lang: MemoryPromptLang.en,
        legacyMemoryMode: false,
      ).map((e) => e.name);

      expect(before, isNot(contains(LocalToolNames.weather)));
      expect(before, isNot(contains(LocalToolNames.healthSummary)));

      DeviceLocalTools.debugSetWeatherKitAvailable(true);
      DeviceLocalTools.debugSetHealthDataAvailable(true);

      final after = BuiltInToolCatalog.entries(
        lang: MemoryPromptLang.en,
        legacyMemoryMode: false,
      ).map((e) => e.name);

      expect(after, contains(LocalToolNames.weather));
      expect(after, contains(LocalToolNames.healthSummary));
    },
  );
}
