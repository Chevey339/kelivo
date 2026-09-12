import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.background.settings-loading');
  late BusinessTestHarness storage;
  late MobileBackgroundCoordinator background;
  late AppLocalizations l10n;
  final notifications = <Map<String, String?>>[];

  setUp(() async {
    storage = await createBusinessTestHarness(
      initial: {
        'mobile_background_settings_v1': jsonEncode({'privacyMode': true}),
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return call.method == 'sync' ? <String, dynamic>{} : null;
        });
    notifications.clear();
    background = MobileBackgroundCoordinator(
      platform: TargetPlatform.android,
      channel: channel,
      notificationSender: ({required conversationId, title, body}) async {
        notifications.add({'id': conversationId, 'title': title, 'body': body});
      },
    );
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await background.configure(const MobileBackgroundSettings(), l10n);
  });

  tearDown(() {
    background.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('saved privacy loads after the last frame before backgrounding', (
    tester,
  ) async {
    late SettingsProvider settings;
    var configured = false;
    var frames = 0;
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => settings = SettingsProvider(storage.preferences),
          child: Builder(
            builder: (context) {
              frames++;
              final provider = context.watch<SettingsProvider>();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(
                  background.configureFromSettings(provider, l10n).then((_) {
                    configured = true;
                  }),
                );
              });
              return const SizedBox();
            },
          ),
        ),
      );
      expect(configured, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      // Drive async settings I/O without drawing another frame.
      for (var i = 0; i < 300 && !configured; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.idle();
      }
      expect(configured, isTrue);
      expect(frames, 1);
      expect(tester.binding.framesEnabled, isFalse);
      expect(settings.mobileBackground.privacyMode, isTrue);
      expect(background.settings.privacyMode, isTrue);
      var finished = false;
      final completion = () async {
        await background.start(
          id: 'run',
          conversationId: 'secret-chat',
          title: 'Secret title',
          scheduled: true,
          cancel: () async {},
        );
        await background.finish(
          'run',
          BackgroundTaskOutcome.completed,
          replyPreview: 'Secret reply',
        );
        finished = true;
      }();
      for (var i = 0; i < 300 && !finished; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.idle();
      }
      expect(finished, isTrue);
      await completion;
      expect(notifications, [
        {
          'id': 'secret-chat',
          'title': l10n.backgroundTaskTitle,
          'body': l10n.backgroundCompleted,
        },
      ]);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
