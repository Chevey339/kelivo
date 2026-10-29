import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../support/business_test_harness.dart';
import 'dart:async';

import 'package:Kelivo/features/chat/controllers/selection_translation_controller.dart';
import 'package:Kelivo/features/chat/widgets/selection_result_panel.dart';
import 'package:Kelivo/features/settings/widgets/language_select_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'translation states, language change and copy use the current result',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      final runs = <StreamController<String>>[];
      final languages = <String>[];
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final controller = SelectionTranslationController(
        text: 'source',
        cancel: (_) {},
        request: (_, language, id) {
          languages.add(language);
          final stream = StreamController<String>();
          runs.add(stream);
          return stream.stream;
        },
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 392,
                  height: 400,
                  child: SelectionResultPanel(
                    controller: controller,
                    initialLanguage: supportedLanguages.first,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Finder button(String label) => find.text(label);
      await tester.pump();
      expect(find.text('正在翻译…'), findsOneWidget);
      await tester.tap(button('重新生成'));
      await tester.pump();
      expect(languages, ['Simplified Chinese']);
      runs.first.add('部分译文');
      await tester.pump();
      expect(find.text('部分译文'), findsOneWidget);
      await tester.tap(button('重新生成'));
      await tester.pump();
      expect(languages, ['Simplified Chinese']);
      runs.first.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      runs.last.add('完整译文');
      unawaited(runs.last.close());
      await tester.pumpAndSettle();
      expect(find.text('完整译文'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      final copyLabel = MaterialLocalizations.of(
        tester.element(find.byType(SelectionResultPanel)),
      ).copyButtonLabel;
      await tester.tap(button(copyLabel));
      await tester.pump();
      expect(copied, '完整译文');
      await tester.tap(find.text('简体中文'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pump();
      expect(languages.last, 'English');
      expect(find.text('完整译文'), findsNothing);
      runs.last.add('New translation');
      unawaited(runs.last.close());
      await tester.pumpAndSettle();
      expect(find.text('New translation'), findsOneWidget);
      await tester.tap(button('重新生成'));
      await tester.pump();
      expect(languages, [
        'Simplified Chinese',
        'Simplified Chinese',
        'English',
        'English',
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      for (final stream in runs) {
        unawaited(stream.close());
      }
      await tester.pump();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );
}
