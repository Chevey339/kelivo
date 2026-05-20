import 'dart:typed_data';

import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _transparentPngDataUrl =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwAD'
    'hgGAWjR9awAAAABJRU5ErkJggg==';

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0xDA,
  0x63,
  0x64,
  0xF8,
  0xCF,
  0x50,
  0x0F,
  0x00,
  0x03,
  0x86,
  0x01,
  0x80,
  0x5A,
  0x34,
  0x7D,
  0x6B,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  testWidgets('ImageViewerPage uses a preloaded provider for the first frame', (
    tester,
  ) async {
    final provider = MemoryImage(Uint8List.fromList(_transparentPngBytes));

    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(
          images: const [_transparentPngDataUrl],
          imageProviders: {_transparentPngDataUrl: provider},
        ),
      ),
    );
    await tester.pump();

    expect(
      identical(tester.widget<Image>(find.byType(Image)).image, provider),
      isTrue,
    );
  });

  testWidgets(
    'ImageViewerPage keeps data image provider stable after rebuild',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerPage(images: [_transparentPngDataUrl]),
        ),
      );
      await tester.pump();

      final firstProvider = tester.widget<Image>(find.byType(Image)).image;

      await tester.drag(find.byType(Image), const Offset(0, 24));
      await tester.pump();

      final secondProvider = tester.widget<Image>(find.byType(Image)).image;
      final stableProvider = identical(secondProvider, firstProvider);

      await tester.pump(const Duration(milliseconds: 50));

      expect(stableProvider, isTrue);
    },
  );
}
