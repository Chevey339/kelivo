import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:Kelivo/features/chat/utils/export_image_processor.dart';
import 'package:Kelivo/features/chat/widgets/export_image_capture.dart';
import 'package:Kelivo/features/chat/widgets/image_preview_sheet.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'dart:io';

void main() {
  testWidgets(
    'export progress shows real slice counts and indeterminate encoding',
    (tester) async {
      Future<void> show(ExportImageProgress value) => tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: buildImageExportProgressForTesting(value)),
        ),
      );
      await show(
        const ExportImageProgress(
          ExportImageStage.capturing,
          completed: 2,
          total: 8,
        ),
      );
      expect(find.text('Capturing image 2/8…'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .25,
      );
      await show(const ExportImageProgress(ExportImageStage.processing));
      expect(
        find.text('Combining image and preparing preview…'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    },
  );

  testWidgets(
    'long export mounts content once and keeps 3x pixels across seams',
    (tester) async {
      late BuildContext context;
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final states = <ExportImageProgress>[];
      ProcessedExportImage? result;
      Object? failure;
      var done = false;
      unawaited(
        captureExportWidget(
              context,
              Builder(
                builder: (_) {
                  builds++;
                  return const SizedBox(
                    width: 64,
                    height: 5200,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 8,
                          child: ColoredBox(
                            color: Colors.red,
                            child: SizedBox.expand(),
                          ),
                        ),
                        Expanded(
                          child: ColoredBox(
                            color: Colors.green,
                            child: SizedBox.expand(),
                          ),
                        ),
                        SizedBox(
                          height: 8,
                          child: ColoredBox(
                            color: Colors.blue,
                            child: SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              theme: ThemeData(),
              width: 64,
              onProgress: states.add,
            )
            .then((r) {
              result = r;
            })
            .catchError((Object e) {
              failure = e;
            })
            .whenComplete(() {
              done = true;
            }),
      );
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(failure, isNull);
      expect(done, isTrue);
      expect(builds, 1);
      final image = img.decodePng(result!.pngBytes)!;
      expect((image.width, image.height), (192, 15600));
      expect(image.getPixel(96, 10).r, 244);
      expect(image.getPixel(96, 15590).b, 243);
      for (final y in [4094, 4095, 8189, 8190, 12284, 12285]) {
        expect(image.getPixel(96, y).toList(), [76, 175, 80, 255]);
      }
      final captures = states
          .where((s) => s.stage == ExportImageStage.capturing)
          .toList();
      expect(captures.map((s) => s.completed), [0, 1, 2, 3, 4]);
      expect(captures.map((s) => s.total), everyElement(4));
      final display = previewDisplayFromExportForTesting(result!.preview!);
      final layout = previewImageDisplayLayoutForTesting(
        file: File('/not-read/export.png'),
        width: 64,
        cachedDisplay: display,
      );
      expect(layout.height, 5200);
      expect(layout.tileCount, 4);
    },
  );
}
