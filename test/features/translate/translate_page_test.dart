import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_translate_page.dart';
import 'package:Kelivo/features/translate/pages/translate_page.dart';
import 'package:Kelivo/features/translate/widgets/translation_output.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (ready()) return;
  }
  fail('The translation did not reach the expected state.');
}

Future<void> _sendDelta(HttpResponse response, String text) async {
  response.write(
    'data: ${jsonEncode({
      'choices': [
        {
          'index': 0,
          'delta': {'content': text},
        },
      ],
    })}\n\n',
  );
  await response.flush();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} translation renders streaming math '
      'and copies original text after completion and cancellation',
      (tester) async {
        debugDefaultTargetPlatformOverride = desktop
            ? TargetPlatform.windows
            : TargetPlatform.android;
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = desktop
              ? const Size(1100, 800)
              : const Size(390, 844);
          addTearDown(tester.view.reset);

          final previousHttp = HttpOverrides.current;
          HttpOverrides.global = null;
          addTearDown(() => HttpOverrides.global = previousHttp);
          late HttpServer server;
          late StreamIterator<HttpRequest> requests;
          late SettingsProvider settings;
          late AssistantProvider assistants;
          await tester.runAsync(() async {
            server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
            requests = StreamIterator(server);
            addTearDown(() => requests.cancel());
            addTearDown(() => server.close(force: true));
            final harness = await createBusinessTestHarness();
            settings = SettingsProvider(harness.preferences);
            assistants = AssistantProvider(preferences: harness.preferences);
            addTearDown(settings.dispose);
            addTearDown(assistants.dispose);
            await Future.wait([settings.loaded, assistants.loaded]);
            await settings.setRequestLogEnabled(false);
            await settings.setProviderConfig(
              'translation-test',
              ProviderConfig(
                id: 'translation-test',
                name: 'Translation test',
                enabled: true,
                apiKey: 'test-key',
                baseUrl: 'http://127.0.0.1:${server.port}/v1',
                providerType: ProviderKind.openai,
                models: const ['translation-model'],
              ),
            );
            await settings.setTranslateModel(
              'translation-test',
              'translation-model',
            );
          });

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
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider.value(value: assistants),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: desktop
                    ? const DesktopTranslatePage()
                    : const TranslatePage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Translated result appears here…'), findsOneWidget);

          final output = find.byType(TranslationOutput);
          final markdown = find.descendant(
            of: output,
            matching: find.byType(MarkstreamView),
          );
          Finder action(String label) => desktop
              ? find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics && widget.properties.tooltip == label,
                )
              : find.byTooltip(label);

          Future<HttpResponse> start() async {
            HttpResponse? response;
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              Future<void> accept() async {
                if (!await requests.moveNext()) return;
                final request = requests.current;
                await request.drain<void>();
                response = request.response
                  ..headers.contentType = ContentType('text', 'event-stream')
                  ..bufferOutput = false;
              }

              unawaited(accept());
              await tester.tap(
                desktop
                    ? find.text('Translate').last
                    : find.widgetWithText(IosCardPress, 'Translate'),
              );
            });
            await tester.pump();
            expect(
              tester.widget<TranslationOutput>(output).streaming,
              isTrue,
              reason: 'Tapping Translate must start the request.',
            );
            await _pumpUntil(tester, () => response != null);
            return response!;
          }

          await tester.enterText(
            find.byType(TextField),
            'Translate this article.',
          );
          final response = await start();
          const first = '\n\n  # Result\n\nTranslated **text** with \$x';
          const second = '^2\$.\n\n\$\$\n\\frac{a}{b}\n\$\$\n';
          const original = first + second;
          await tester.runAsync(() => _sendDelta(response, first));
          await _pumpUntil(tester, () => markdown.evaluate().isNotEmpty);
          expect(tester.widget<MarkstreamView>(markdown).streaming, isTrue);
          expect(find.byType(Math), findsNothing);
          expect(
            markdownParagraph(tester, 'Result').text.toPlainText(),
            'Result',
          );
          await tester.runAsync(() => _sendDelta(response, second));
          await _pumpUntil(
            tester,
            () => find.byType(Math).evaluate().length == 2,
          );
          await tester.tap(action('Copy result'));
          await tester.pump();
          expect(
            copied,
            original,
            reason: 'Copy must retain markup and whitespace.',
          );

          await tester.runAsync(() async {
            response.write('data: [DONE]\n\n');
            await response.close();
          });
          await _pumpUntil(
            tester,
            () => !tester.widget<MarkstreamView>(markdown).streaming,
          );
          expect(find.byType(Math), findsNWidgets(2));
          await tester.tap(action('Copy result'));
          await tester.pump();
          expect(copied, original);

          await tester.tap(action('Clear All'));
          await _pumpUntil(tester, () => markdown.evaluate().isEmpty);
          await tester.pumpAndSettle();
          expect(markdown, findsNothing);
          expect(find.text('Translated result appears here…'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Another article.');
          final pending = await start();
          await tester.runAsync(() => _sendDelta(pending, first));
          await _pumpUntil(tester, () => markdown.evaluate().isNotEmpty);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Stop'));
          await _pumpUntil(
            tester,
            () => !tester.widget<MarkstreamView>(markdown).streaming,
          );
          expect(find.byType(Math), findsNothing);
          await tester.tap(action('Copy result'));
          await tester.pump();
          expect(copied, first);
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
