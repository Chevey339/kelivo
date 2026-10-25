import 'dart:io';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/services/incoming_share_service.dart';
import 'package:Kelivo/features/home/widgets/composer_attachment_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 260, height: 88, child: child)),
  ),
);

void main() {
  testWidgets(
    'large attachments show metadata, stay compact, and can be removed',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('composer_card_');
      try {
        final file = File('${root.path}/project.zip');
        file.openSync(mode: FileMode.write)
          ..truncateSync(178 * 1024 * 1024)
          ..closeSync();
        var removed = false;
        await tester.pumpWidget(
          app(
            ComposerAttachmentCard(
              file: DocumentAttachment(
                path: file.path,
                fileName: '工作区项目与设计资源.zip',
                mime: 'application/zip',
              ),
              onRemove: () => removed = true,
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        expect(find.text('178.00 MB'), findsOneWidget);
        await tester.tap(find.byTooltip('Remove attachment'));
        await tester.pump();
        expect(removed, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  testWidgets('only audio attachments get a play control', (tester) async {
    Widget card(String name, String mime) => ComposerAttachmentCard(
      file: DocumentAttachment(path: '/tmp/$name', fileName: name, mime: mime),
      onRemove: () {},
    );

    await tester.pumpWidget(app(card('voice_1.wav', 'audio/wav')));
    expect(find.byTooltip('Play audio'), findsOneWidget);
    expect(find.text('voice_1.wav'), findsOneWidget);

    await tester.pumpWidget(app(card('notes.txt', 'text/plain')));
    expect(find.byTooltip('Play audio'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'import progress shows byte fraction and a working cancel action',
    (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        app(
          ComposerImportProgress(
            progress: const ShareImportProgress(
              id: 'job',
              name: 'archive.zip',
              index: 1,
              count: 2,
              bytes: 512,
              total: 1024,
            ),
            onCancel: () => cancelled = true,
          ),
        ),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.5,
      );
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      expect(cancelled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
