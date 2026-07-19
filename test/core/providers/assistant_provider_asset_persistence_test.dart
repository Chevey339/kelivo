import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';

import '../../support/business_preferences_test_harness.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

Future<AssistantProvider> _loadedProvider({
  required BusinessPreferencesTestSession session,
  required List<Map<String, Object?>> assistants,
}) async {
  await session.preferences.setString('assistants_v1', jsonEncode(assistants));
  await session.preferences.setString(
    'current_assistant_id_v1',
    assistants.first['id'].toString(),
  );

  final provider = AssistantProvider(preferences: session.preferences);
  for (var i = 0; i < 25; i++) {
    if (provider.assistants.length == assistants.length) return provider;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_assistant_asset_test_',
    );
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await harness.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'copies local assistant avatar and background into managed backup directories',
    () async {
      final provider = await _loadedProvider(
        session: session,
        assistants: const [
          {'id': 'assistant-a', 'name': 'Assistant A'},
        ],
      );

      final externalAvatarDir = Directory(
        p.join(tempDir.path, 'external', 'avatars'),
      );
      final externalImagesDir = Directory(
        p.join(tempDir.path, 'external', 'images'),
      );
      await externalAvatarDir.create(recursive: true);
      await externalImagesDir.create(recursive: true);
      final avatarSource = File(p.join(externalAvatarDir.path, 'avatar.png'));
      final backgroundSource = File(p.join(externalImagesDir.path, 'bg.jpg'));
      await avatarSource.writeAsBytes(const [1, 2, 3], flush: true);
      await backgroundSource.writeAsBytes(const [4, 5, 6], flush: true);

      await provider.updateAssistant(
        provider.assistants.single.copyWith(
          avatar: avatarSource.path,
          background: backgroundSource.path,
        ),
      );

      final updated = provider.assistants.single;
      expect(updated.avatar, isNot(avatarSource.path));
      expect(updated.background, isNot(backgroundSource.path));

      final managedAvatars = p.normalize(p.join(tempDir.path, 'avatars'));
      final managedImages = p.normalize(p.join(tempDir.path, 'images'));
      final avatarPath = p.normalize(updated.avatar!);
      final backgroundPath = p.normalize(updated.background!);

      expect(p.isWithin(managedAvatars, avatarPath), isTrue);
      expect(p.isWithin(managedImages, backgroundPath), isTrue);
      expect(await File(avatarPath).readAsBytes(), const [1, 2, 3]);
      expect(await File(backgroundPath).readAsBytes(), const [4, 5, 6]);

      final stored =
          jsonDecode(session.preferences.getString('assistants_v1')!) as List;
      final storedAssistant = stored.single as Map;
      expect(storedAssistant['avatar'], updated.avatar);
      expect(storedAssistant['background'], updated.background);
    },
  );
}
