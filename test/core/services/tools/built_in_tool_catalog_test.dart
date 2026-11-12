import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/core/services/tools/built_in_tool_catalog.dart';
import 'package:Kelivo/core/services/tools/tool_schema_overrides.dart';
import 'package:Kelivo/core/services/tools/view_image_tool.dart';
import 'package:Kelivo/core/models/tool_schema_override.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(DeviceLocalTools.debugResetIosCapabilities);

  test(
    'workspace catalog includes every executable schema and accepts overrides',
    () {
      final entries =
          BuiltInToolCatalog.entries(
                lang: MemoryPromptLang.en,
                legacyMemoryMode: false,
              )
              .where(
                (entry) =>
                    entry.group == BuiltInToolGroup.workspace ||
                    entry.group == BuiltInToolGroup.images,
              )
              .toList();
      expect(
        entries.map((e) => e.name).toSet(),
        WorkspaceToolsService.toolNames,
      );
      final image = entries.singleWhere((entry) => entry.name == 'view_image');
      expect(image.group, BuiltInToolGroup.images);
      expect(ViewImageTool.supportsFiles(image.defaultDefinition), isTrue);
      expect(ViewImageTool.supportsHistory(image.defaultDefinition), isTrue);
      expect(
        entries.map((entry) => entry.name),
        isNot(contains('read_chat_image')),
      );
      for (final definition in WorkspaceToolsService.definitions()) {
        final name = definition['function']['name'];
        if (name == 'view_image') continue;
        expect(
          entries.singleWhere((entry) => entry.name == name).defaultDefinition,
          definition,
        );
      }
      final result = ToolSchemaOverrides.apply(
        WorkspaceToolsService.definitions(),
        {
          'read_file': const ToolSchemaOverride(
            description: 'Custom file reader',
          ),
        },
      );
      final read = result.singleWhere(
        (d) => d['function']['name'] == 'read_file',
      );
      expect(read['function']['description'], 'Custom file reader');
      expect(read['function']['parameters']['required'], ['path']);
    },
  );
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
