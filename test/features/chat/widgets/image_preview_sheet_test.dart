import 'dart:io';
import 'package:Kelivo/features/chat/widgets/image_preview_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

Uint8List _pngBytes({required int width, required int height}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(image_lib.ColorRgba8(255, 255, 255, 255));
  return image_lib.encodePng(image);
}

Uint8List _blankPaddedPng({
  required int width,
  required int height,
  required int contentLeft,
  required int contentTop,
  required int contentWidth,
  required int contentHeight,
}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(image_lib.ColorRgba8(255, 255, 255, 255));
  image
    ..setPixelRgba(0, 0, 0, 0, 0, 0)
    ..setPixelRgba(width - 1, 0, 0, 0, 0, 0)
    ..setPixelRgba(0, height - 1, 0, 0, 0, 0)
    ..setPixelRgba(width - 1, height - 1, 0, 0, 0, 0);
  for (var y = contentTop; y < contentTop + contentHeight; y += 1) {
    for (var x = contentLeft; x < contentLeft + contentWidth; x += 1) {
      image.setPixelRgba(x, y, 255, 0, 0, 255);
    }
  }
  return image_lib.encodePng(image);
}

Uint8List _blankPaddedPngWithEdgeNoise({
  required int width,
  required int height,
  required int contentLeft,
  required int contentTop,
  required int contentWidth,
  required int contentHeight,
}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(image_lib.ColorRgba8(255, 255, 255, 255));
  for (var y = contentTop; y < contentTop + contentHeight; y += 1) {
    for (var x = contentLeft; x < contentLeft + contentWidth; x += 1) {
      image.setPixelRgba(x, y, 255, 0, 0, 255);
    }
  }

  for (var y = 0; y < height; y += 12) {
    image.setPixelRgba(0, y, 240, 240, 240, 255);
  }
  for (var x = 0; x < width; x += 12) {
    image.setPixelRgba(x, height - 1, 240, 240, 240, 255);
  }
  return image_lib.encodePng(image);
}

Future<File> _writeBytes(Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('kelivo_preview_test_');
  final file = File('${dir.path}/preview.png');
  await file.writeAsBytes(bytes);
  return file;
}

Future<File> _writePng({required int width, required int height}) {
  return _writeBytes(_pngBytes(width: width, height: height));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image preview renders tall exports at available width', () async {
    final file = await _writePng(width: 144, height: 1200);

    final image = buildPreviewImageForTesting(file: file, width: 360);

    expect(image.width, 360);
    expect(image.height, 3000);
    expect(image.fit, BoxFit.contain);
    final provider = image.image;
    expect(provider, isA<FileImage>());
    expect((provider as FileImage).file.path, file.path);
  });

  test('image preview splits very tall exports into display tiles', () async {
    final file = await _writePng(width: 144, height: 5000);

    final layout = previewImageDisplayLayoutForTesting(file: file, width: 360);

    expect(layout.height, 12500);
    expect(layout.tileCount, 3);
    expect(layout.providers, everyElement(isA<MemoryImage>()));
  });

  test(
    'image preview reuses decoded display during save state rebuilds',
    () async {
      final file = await _writePng(width: 144, height: 5000);
      final display = readPreviewDisplayForTesting(file);

      final first = previewImageDisplayLayoutForTesting(
        file: file,
        width: 360,
        cachedDisplay: display,
      );
      final second = previewImageDisplayLayoutForTesting(
        file: file,
        width: 360,
        cachedDisplay: display,
      );

      expect(first.tileCount, 3);
      expect(second.tileCount, 3);
      expect(identical(first.providers.first, second.providers.first), isTrue);
    },
  );

  test('image preview can prepare tall display data asynchronously', () async {
    final file = await _writePng(width: 144, height: 5000);

    final display = await readPreviewDisplayAsyncForTesting(file);
    final layout = previewImageDisplayLayoutForTesting(
      file: file,
      width: 360,
      cachedDisplay: display,
    );

    expect(layout.height, 12500);
    expect(layout.tileCount, 3);
    expect(layout.providers, everyElement(isA<MemoryImage>()));
  });

  test('image preview trims outer blank padding before sizing', () async {
    final file = await _writeBytes(
      _blankPaddedPng(
        width: 120,
        height: 600,
        contentLeft: 20,
        contentTop: 250,
        contentWidth: 80,
        contentHeight: 100,
      ),
    );

    final image = buildPreviewImageForTesting(file: file, width: 360);

    expect(image.width, 360);
    expect(image.height, 588);
    expect(image.fit, BoxFit.contain);
    expect(image.image, isA<MemoryImage>());
  });

  test(
    'image preview ignores sparse edge noise when trimming blank padding',
    () async {
      final file = await _writeBytes(
        _blankPaddedPngWithEdgeNoise(
          width: 120,
          height: 600,
          contentLeft: 20,
          contentTop: 250,
          contentWidth: 80,
          contentHeight: 100,
        ),
      );

      final image = buildPreviewImageForTesting(file: file, width: 360);

      expect(image.width, 360);
      expect(image.height, 588);
      expect(image.fit, BoxFit.contain);
      expect(image.image, isA<MemoryImage>());
    },
  );

  test('saving preview preserves the original PNG file', () async {
    final file = await _writePng(width: 32, height: 96);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('image_gallery_saver_plus'),
          (call) async {
            calls.add(call);
            return <String, Object>{'isSuccess': true, 'filePath': file.path};
          },
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('image_gallery_saver_plus'),
            null,
          );
    });

    await saveImagePreviewFileForTesting(file, name: 'preview');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'saveFileToGallery');
    expect(calls.single.arguments, containsPair('file', file.path));
    expect(calls.single.arguments, isNot(contains('imageBytes')));
  });
}
