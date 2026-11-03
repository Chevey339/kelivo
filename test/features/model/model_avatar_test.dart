import 'dart:io';

import 'package:Kelivo/core/models/avatar_config.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/model_spec_edit_dialog.dart';
import 'package:Kelivo/features/home/widgets/model_icon.dart';
import 'package:Kelivo/features/model/pages/model_spec_edit_page.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/configurable_avatar.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/avatar_cache.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

ProviderConfig _config(String id) => ProviderConfig(
  id: id,
  enabled: true,
  name: id,
  apiKey: '',
  baseUrl: '',
  models: const ['nemotron', 'alias'],
  modelOverrides: const {
    'alias': {'apiModelId': 'nemotron', 'name': 'My model'},
  },
);

ModelSpecFormController _editor(
  SettingsProvider settings, {
  String model = 'nemotron',
}) => ModelSpecFormController(
  config: settings.getProviderConfig('A'),
  modelKey: model,
  isNew: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsProvider> settings() async {
    final harness = await createBusinessTestHarness();
    final value = SettingsProvider(harness.preferences);
    await value.loaded;
    await value.setProviderConfig('A', _config('A'));
    await value.setProviderConfig('B', _config('B'));
    addTearDown(value.dispose);
    return value;
  }

  test(
    'model icon drafts, save, reload and reset are scoped to a logical model',
    () async {
      final sp = await settings();
      const icon = AvatarConfig(
        type: AvatarType.lobehub,
        value: 'nvidia',
        monochrome: true,
      );
      final draft = _editor(sp);
      draft.setAvatar(icon);
      expect(sp.getProviderConfig('A').modelAvatar('nemotron'), isNull);
      draft.dispose();
      final edit = _editor(sp);
      addTearDown(edit.dispose);
      expect(edit.avatar, isNull);
      edit.setAvatar(icon);
      expect(await edit.save(sp), isTrue);
      final saved = ProviderConfig.fromJson(sp.getProviderConfig('A').toJson());
      expect(saved.modelAvatar('nemotron'), icon);
      expect(saved.modelAvatar('alias'), isNull);
      expect(sp.getProviderConfig('B').modelAvatar('nemotron'), isNull);

      final reopened = _editor(sp);
      addTearDown(reopened.dispose);
      expect(reopened.avatar, icon);
      reopened.setDisplayName('Renamed');
      expect(await reopened.save(sp), isTrue);
      expect(sp.getProviderConfig('A').modelAvatar('nemotron'), icon);
      reopened.setAvatar(null);
      expect(await reopened.save(sp), isTrue);
      final after = sp.getProviderConfig('A');
      expect(
        (after.modelOverrides['nemotron'] as Map).containsKey('avatar'),
        isFalse,
      );
      expect((after.modelOverrides['nemotron'] as Map)['name'], 'Renamed');
      expect(
        after.modelOverrides['alias'],
        _config('A').modelOverrides['alias'],
      );
    },
  );

  test(
    'new models retain their chosen icon under the generated logical key',
    () async {
      final sp = await settings();
      final edit = ModelSpecFormController(
        config: sp.getProviderConfig('A'),
        modelKey: '',
        isNew: true,
      );
      addTearDown(edit.dispose);
      edit.setApiModelId('nemotron');
      const avatar = AvatarConfig(type: AvatarType.emoji, value: '🌟');
      edit.setAvatar(avatar);
      expect(await edit.save(sp), isTrue);
      expect(sp.getProviderConfig('A').modelAvatar('nemotron#2'), avatar);
      expect(sp.getProviderConfig('A').modelAvatar('nemotron'), isNull);
    },
  );

  test(
    'file icons are copied to backup-managed storage only on save',
    () async {
      final root = await Directory.systemTemp.createTemp('model-avatar-');
      final paths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(root.path);
      addTearDown(() async {
        PathProviderPlatform.instance = paths;
        await root.delete(recursive: true);
      });
      final source = File('${root.path}/selection.svg');
      await source.writeAsString('<svg xmlns="http://www.w3.org/2000/svg"/>');
      final sp = await settings();
      final edit = _editor(sp);
      addTearDown(edit.dispose);
      edit.setAvatar(AvatarConfig(type: AvatarType.file, value: source.path));
      final managed = await AppDirectories.getAvatarsDirectory();
      expect(await managed.exists(), isFalse);
      expect(await edit.save(sp), isTrue);
      final path = sp.getProviderConfig('A').modelAvatar('nemotron')!.value;
      expect(path, startsWith('${managed.path}/'));
      expect(await File(path).readAsString(), await source.readAsString());
      await source.delete();
      expect(await File(path).exists(), isTrue);
      edit.setAvatar(AvatarConfig(type: AvatarType.file, value: source.path));
      expect(await edit.save(sp), isFalse);
      expect(sp.getProviderConfig('A').modelAvatar('nemotron')!.value, path);
    },
  );

  test('provider monochrome setting survives persistence and reset', () async {
    final sp = await settings();
    await sp.setProviderAvatarLobehub('A', 'nvidia', monochrome: true);
    expect(
      ProviderConfig.fromJson(
        sp.getProviderConfig('A').toJson(),
      ).avatarMonochrome,
      isTrue,
    );
    await sp.setProviderAvatarLobehub('A', 'nvidia');
    expect(sp.getProviderConfig('A').avatarMonochrome, isFalse);
    await sp.resetProviderAvatar('A');
    expect(sp.getProviderConfig('A').avatar, isNull);
  });

  test(
    'monochrome never requests a colored SVG, including explicit suffixes',
    () {
      expect(BrandAssets.lobehubIconUrls('Nvidia-color', monochrome: true), [
        BrandAssets.lobehubIconUrl('nvidia'),
      ]);
      expect(BrandAssets.lobehubIconUrls('nvidia'), [
        BrandAssets.lobehubIconUrl('nvidia-color'),
        BrandAssets.lobehubIconUrl('nvidia'),
      ]);
      expect(BrandAssets.lobehubIconUrls('../nvidia'), isEmpty);
    },
  );

  testWidgets(
    'model icon updates live and overrides the provider icon without affecting other providers',
    (tester) async {
      final sp = await settings();
      await sp.setProviderAvatarEmoji('A', '🟢');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sp,
          child: const MaterialApp(
            home: Row(
              children: [
                CurrentModelIcon(providerKey: 'A', modelId: 'nemotron'),
                CurrentModelIcon(providerKey: 'B', modelId: 'nemotron'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('🟢'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      final edit = _editor(sp);
      addTearDown(edit.dispose);
      edit.setAvatar(const AvatarConfig(type: AvatarType.emoji, value: '🌟'));
      expect(await edit.save(sp), isTrue);
      await tester.pump();
      expect(find.text('🌟'), findsOneWidget);
      expect(find.text('🟢'), findsNothing);
      expect(find.text('N'), findsOneWidget);
      edit.setAvatar(null);
      await edit.save(sp);
      await tester.pump();
      expect(find.text('🟢'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} model editor saves, reopens, switches and resets LobeHub style',
      (tester) async {
        final sp = await settings();
        tester.view.physicalSize = desktop
            ? const Size(1200, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: sp,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => desktop
                        ? showDesktopModelSpecEditDialog(
                            context,
                            providerKey: 'A',
                            modelKey: 'nemotron',
                          )
                        : showModelSpecEditPage(
                            context,
                            providerKey: 'A',
                            modelKey: 'nemotron',
                          ),
                    child: const Text('Open editor'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('Open editor'));
          await tester.pumpAndSettle();
        }

        Future<void> source() async {
          await tester.tap(find.byKey(const ValueKey('model-avatar-field')));
          await tester.pumpAndSettle();
        }

        Future<void> lobehub() async {
          await source();
          await tester.tap(find.text('Enter LobeHub Icon'));
          await tester.pumpAndSettle();
        }

        Future<void> save() async {
          await tester.tap(
            find.byKey(
              ValueKey(desktop ? 'model-spec-confirm' : 'model-spec-save'),
            ),
          );
          await tester.pumpAndSettle();
        }

        await open();
        await source();
        await tester.tap(find.text('Choose Built-in Icon'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Gemini'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ConfigurableAvatar>(find.byType(ConfigurableAvatar))
              .avatar
              ?.value,
          'assets/icons/gemini-color.svg',
        );
        Navigator.of(
          tester.element(find.byKey(const ValueKey('model-avatar-field'))),
        ).pop();
        await tester.pumpAndSettle();
        expect(sp.getProviderConfig('A').modelAvatar('nemotron'), isNull);
        await open();
        await lobehub();
        await tester.enterText(
          find.byKey(const ValueKey('model-avatar-input-field')),
          'nvidia',
        );
        await tester.tap(find.text('Monochrome'));
        await tester.tap(find.byKey(const ValueKey('model-avatar-input-save')));
        await tester.pumpAndSettle();
        expect(sp.getProviderConfig('A').modelAvatar('nemotron'), isNull);
        expect(
          tester
              .widget<ConfigurableAvatar>(find.byType(ConfigurableAvatar))
              .avatar
              ?.monochrome,
          isTrue,
        );
        await save();
        expect(
          sp.getProviderConfig('A').modelAvatar('nemotron')?.monochrome,
          isTrue,
        );
        await open();
        await lobehub();
        expect(find.text('nvidia'), findsOneWidget);
        expect(
          tester
              .widget<SegmentedTabs>(
                find.descendant(
                  of: find.byKey(const ValueKey('model-avatar-input-dialog')),
                  matching: find.byType(SegmentedTabs),
                ),
              )
              .index,
          1,
        );
        await tester.tap(find.text('Color'));
        await tester.tap(find.byKey(const ValueKey('model-avatar-input-save')));
        await tester.pumpAndSettle();
        await save();
        expect(
          sp.getProviderConfig('A').modelAvatar('nemotron')?.monochrome,
          isFalse,
        );
        await open();
        await source();
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        await save();
        expect(sp.getProviderConfig('A').modelAvatar('nemotron'), isNull);
        await tester.pumpWidget(const SizedBox());
        AvatarCache.clearMemory();
      },
    );
  }
}
