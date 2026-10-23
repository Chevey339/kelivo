import 'dart:io';
import 'package:flutter/material.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../../support/business_test_harness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/home/widgets/forward_messages_sheet.dart';
import 'package:Kelivo/features/chat/widgets/forwarded_messages_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  testWidgets('desktop destination list scrolls and search narrows choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showForwardMessagesSheet(
                  context,
                  conversations: List.generate(
                    40,
                    (i) => Conversation(id: '$i', title: 'Conversation $i'),
                  ),
                  record: ForwardedMessagesPart(messages: []),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(ForwardMessagesSheet)).height,
      lessThanOrEqualTo(600),
    );
    await tester.scrollUntilVisible(
      find.text('Conversation 39'),
      250,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Conversation 39'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Conversation 12');
    await tester.pumpAndSettle();
    expect(find.text('Conversation 39'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Conversation 12'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(ForwardMessagesSheet)).height,
      lessThan(400),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  testWidgets(
    'local forwarded image decodes and local file opens from details',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync(
        'forward-visible-assets-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final image = File(
        'assets/icons/kelivo.png',
      ).copySync('${directory.path}/image.png');
      final file = File('${directory.path}/review.txt')
        ..writeAsStringSync('Review contents');
      final record = ForwardedMessagesPart(
        messages: [
          ForwardedMessageSnapshot(
            author: 'A',
            role: 'assistant',
            timestamp: DateTime(2026),
            parts: [
              ImagePart(uri: image.path),
              FilePart(uri: file.path, name: 'review.txt'),
            ],
          ),
        ],
      );
      final settings = SettingsProvider(createBusinessTestPreferences());
      Widget app(Widget home) => ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );
      await tester.pumpWidget(app(const Scaffold(body: SizedBox())));
      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(
        () => precacheImage(
          SafeResizeImage.display(
            FileImage(image),
            width: 240,
            height: 180,
            allowUpscaling: false,
          ),
          context,
        ),
      );
      String? opened;
      await tester.pumpWidget(
        app(
          ForwardedMessagesDetails(
            record: record,
            openFile: (path, _) async {
              opened = path;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final decoded = tester.widgetList<RawImage>(find.byType(RawImage));
      expect(decoded.any((image) => image.image != null), isTrue);
      expect(find.text('review.txt'), findsOneWidget);
      await tester.tap(find.text('review.txt'));
      await tester.pumpAndSettle();
      expect(opened, file.path);
      expect(File(opened!).readAsStringSync(), 'Review contents');
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('compact card opens readonly attachments and nested history', (
    tester,
  ) async {
    final nested = ForwardedMessagesPart(
      messages: [
        ForwardedMessageSnapshot(
          author: 'B',
          role: 'assistant',
          timestamp: DateTime(2026),
          parts: const [TextPart('Inner answer')],
        ),
      ],
    );
    final record = ForwardedMessagesPart(
      messages: [
        ForwardedMessageSnapshot(
          author: 'A',
          role: 'assistant',
          timestamp: DateTime(2026),
          parts: [
            const TextPart('Outer answer'),
            const ImagePart(uri: 'missing.png', unavailable: true),
            const FilePart(
              uri: 'missing.pdf',
              name: 'Review.pdf',
              unavailable: true,
            ),
            nested,
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ForwardedMessagesCard(record: record)),
        ),
      ),
    );
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Review.pdf'), findsNothing);
    await tester.tap(find.byType(ForwardedMessagesCard));
    await tester.pumpAndSettle();
    expect(find.text('Review.pdf'), findsOneWidget);
    expect(find.byType(ForwardedMessagesDetails), findsOneWidget);
    await tester.tap(find.byType(ForwardedMessagesCard).last);
    await tester.pumpAndSettle();
    expect(find.text('Inner answer'), findsOneWidget);
  });
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'preview and destination confirmation at width $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ForwardMessagesRequest? result;
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showForwardMessagesSheet(
                        context,
                        conversations: [
                          Conversation(id: 'target', title: 'Destination'),
                        ],
                        record: ForwardedMessagesPart(
                          messages: [
                            ForwardedMessageSnapshot(
                              author: 'Assistant A',
                              role: 'assistant',
                              timestamp: DateTime.utc(2026),
                              parts: const [
                                TextPart('@B historical answer @全部'),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.textContaining('historical answer'), findsNothing);
        expect(find.byKey(const ValueKey('forward-comment')), findsNothing);
        if (width == 1200 || defaultTargetPlatform == TargetPlatform.macOS) {
          expect(find.byType(BottomSheet), findsNothing);
          expect(
            tester.getSize(find.byType(ForwardMessagesSheet)).height,
            lessThan(400),
          );
        }
        expect(result, isNull);
        await tester.tap(find.text('Destination'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Assistant A'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('forward-comment')),
          'Please review',
        );
        await tester.ensureVisible(find.text('Forward').last);
        await tester.tap(find.text('Forward').last);
        await tester.pumpAndSettle();
        expect(result?.conversationId, 'target');
        expect(result?.comment, 'Please review');
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );
  }
}
