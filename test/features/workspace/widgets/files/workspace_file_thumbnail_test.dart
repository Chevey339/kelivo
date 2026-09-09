import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_file_thumbnail.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class _ThumbnailTestBinding extends AutomatedTestWidgetsFlutterBinding {
  bool blockPixelDecoding = false;
  int blockedDecodeCalls = 0;
  Completer<void>? decodeGate;
  int decodeCalls = 0;

  @override
  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) async {
    decodeCalls++;
    if (decodeGate != null) await decodeGate!.future;
    if (blockPixelDecoding) {
      blockedDecodeCalls++;
      buffer.dispose();
      return Future<ui.Codec>.error(StateError('Unexpected pixel decoding'));
    }
    return super.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: getTargetSize,
    );
  }
}

/// A valid solid grayscale PNG built one scanline at a time. Even the 144 MP
/// fixture never needs a full-size pixel allocation in the test process.
Uint8List _solidPng(int width, int height) {
  final output = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> payload) {
    final body = Uint8List.fromList([...ascii.encode(type), ...payload]);
    final length = ByteData(4)..setUint32(0, payload.length);
    final checksum = ByteData(4)..setUint32(0, getCrc32(body));
    output
      ..add(length.buffer.asUint8List())
      ..add(body)
      ..add(checksum.buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8);
  chunk('IHDR', header.buffer.asUint8List());
  final compressor = ZLibEncoder(level: 1).startChunkedConversion(
    ByteConversionSink.withCallback((bytes) => chunk('IDAT', bytes)),
  );
  final row = Uint8List(width + 1);
  for (var y = 0; y < height; y++) {
    compressor.add(row);
  }
  compressor.close();
  chunk('IEND', []);
  return output.takeBytes();
}

FileBrowserEntry _entry(File file) {
  final stat = file.statSync();
  return FileBrowserEntry(
    name: file.uri.pathSegments.last,
    hostPath: file.path,
    isDirectory: false,
    size: stat.size,
    modified: stat.modified,
  );
}

Widget _thumbnail(FileBrowserEntry entry) => MaterialApp(
  home: Center(
    child: WorkspaceFileThumbnail(entry: entry, iconColor: Colors.grey),
  ),
);

Future<void> _waitUntil(WidgetTester tester, bool Function() completed) async {
  final timeout = Stopwatch()..start();
  while (!completed() && timeout.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(completed(), isTrue, reason: 'Thumbnail load did not complete');
}

Future<Object?> _load(WidgetTester tester, {int imageIndex = 0}) async {
  final image = tester.widget<Image>(find.byType(Image).at(imageIndex));
  final stream = image.image.resolve(ImageConfiguration.empty);
  var completed = false;
  Object? failure;
  final listener = ImageStreamListener(
    (info, _) {
      info.dispose();
      completed = true;
    },
    onError: (error, _) {
      failure = error;
      completed = true;
    },
  );
  stream.addListener(listener);
  try {
    // File reads run outside FakeAsync, but the widget's decode continuations
    // return to it. Pump between I/O turns instead of awaiting a fake-zone
    // image future inside runAsync (which would prevent it from completing).
    await _waitUntil(tester, () => completed);
  } finally {
    stream.removeListener(listener);
  }
  await tester.pump();
  return failure;
}

Future<List<int>> _pixel(WidgetTester tester) async {
  final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return data!.buffer.asUint8List().take(4).toList();
}

void main() {
  final binding = _ThumbnailTestBinding();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kelivo_file_thumbnail_');
  });

  tearDown(() {
    binding.blockPixelDecoding = false;
    binding.blockedDecodeCalls = 0;
    if (binding.decodeGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    binding.decodeGate = null;
    binding.decodeCalls = 0;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    tempDir.deleteSync(recursive: true);
  });

  for (final dimensions in [(12000, 12000), (4097, 4096)]) {
    testWidgets(
      'rejects ${dimensions.$1}x${dimensions.$2} before codec creation',
      (tester) async {
        final file = File('${tempDir.path}/compressed.png')
          ..writeAsBytesSync(_solidPng(dimensions.$1, dimensions.$2));
        expect(
          file.lengthSync(),
          lessThan(WorkspaceFileThumbnail.maxSourceBytes),
        );
        binding.blockPixelDecoding = true;
        await tester.pumpWidget(_thumbnail(_entry(file)));
        final failure = await _load(tester);

        // If the guard regresses, the binding blocks the real allocation and
        // this assertion fails instead of risking an OOM in the test runner.
        expect(binding.blockedDecodeCalls, 0);
        expect(
          failure,
          isA<StateError>().having(
            (error) => error.message,
            'reason',
            'Image exceeds the thumbnail source pixel limit',
          ),
        );
        expect(find.byType(RawImage), findsNothing);
        expect(find.byIcon(Lucide.FileImage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'decodes one image at a time and continues after a failed image',
    (tester) async {
      final broken = File('${tempDir.path}/broken.png')
        ..writeAsStringSync('not an image');
      final bytes = img.encodePng(img.Image(width: 32, height: 32));
      final first = File('${tempDir.path}/first.png')..writeAsBytesSync(bytes);
      final second = File('${tempDir.path}/second.png')
        ..writeAsBytesSync(bytes);
      final gate = binding.decodeGate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              for (final file in [broken, first, second])
                WorkspaceFileThumbnail(
                  entry: _entry(file),
                  iconColor: Colors.grey,
                ),
            ],
          ),
        ),
      );
      expect(await _load(tester), isNotNull);
      await _waitUntil(tester, () => binding.decodeCalls > 0);
      // Give another file read time to finish: the second valid image must
      // still be queued while the first one's decoder is held open.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(binding.decodeCalls, 1);

      gate.complete();
      expect(await _load(tester, imageIndex: 1), isNull);
      expect(await _load(tester, imageIndex: 2), isNull);
      expect(binding.decodeCalls, 2);
      expect(find.byType(RawImage), findsNWidgets(2));
      expect(find.byIcon(Lucide.FileImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large image is decoded to a small bounded thumbnail', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 4;
    addTearDown(tester.view.resetDevicePixelRatio);
    final file = File('${tempDir.path}/large.PNG')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 4096, height: 2048)));
    expect(WorkspaceFileThumbnail.supports(_entry(file)), isTrue);
    await tester.pumpWidget(_thumbnail(_entry(file)));
    await _load(tester);

    final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(decoded.width, 128);
    expect(decoded.height, 64);
    expect(decoded.width * decoded.height * 4, lessThanOrEqualTo(65536));
    expect(
      tester.getSize(find.byType(WorkspaceFileThumbnail)),
      const Size(32, 32),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('extreme aspect ratios keep both decode axes nonzero', (
    tester,
  ) async {
    final file = File('${tempDir.path}/panorama.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 8192, height: 1)));
    await tester.pumpWidget(_thumbnail(_entry(file)));
    await _load(tester);
    final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(decoded.width, 128);
    expect(decoded.height, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('corrupt images fall back to the file icon', (tester) async {
    final file = File('${tempDir.path}/broken.png')
      ..writeAsStringSync('not an image');
    await tester.pumpWidget(_thumbnail(_entry(file)));
    await _load(tester);
    expect(find.byIcon(Lucide.FileImage), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oversized encoded files are not loaded', (tester) async {
    final file = File('${tempDir.path}/huge.jpg');
    // Sparse fixture: exercises the input limit without allocating large bytes.
    file.openSync(mode: FileMode.write)
      ..truncateSync(WorkspaceFileThumbnail.maxSourceBytes + 1)
      ..closeSync();
    await tester.pumpWidget(_thumbnail(_entry(file)));
    expect(find.byIcon(Lucide.FileImage), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('refreshing an overwritten image replaces its cached thumbnail', (
    tester,
  ) async {
    final red = img.fill(
      img.Image(width: 16, height: 16),
      color: img.ColorRgb8(255, 0, 0),
    );
    final blue = img.fill(
      img.Image(width: 16, height: 16),
      color: img.ColorRgb8(0, 0, 255),
    );
    final file = File('${tempDir.path}/edited.png')
      ..writeAsBytesSync(img.encodePng(red));
    final before = _entry(file);
    await tester.pumpWidget(_thumbnail(before));
    await _load(tester);
    expect(await _pixel(tester), [255, 0, 0, 255]);
    final oldProvider = tester.widget<Image>(find.byType(Image)).image;

    file.writeAsBytesSync(img.encodePng(blue));
    file.setLastModifiedSync(before.modified.add(const Duration(seconds: 2)));
    await tester.pumpWidget(_thumbnail(_entry(file)));
    await _load(tester);
    expect(tester.widget<Image>(find.byType(Image)).image, isNot(oldProvider));
    expect(await _pixel(tester), [0, 0, 255, 255]);
  });

  testWidgets('animated images expose a static first frame', (tester) async {
    final encoder = img.GifEncoder()
      ..addFrame(
        img.fill(
          img.Image(width: 16, height: 16),
          color: img.ColorRgb8(255, 0, 0),
        ),
        duration: 2,
      )
      ..addFrame(
        img.fill(
          img.Image(width: 16, height: 16),
          color: img.ColorRgb8(0, 0, 255),
        ),
        duration: 2,
      );
    final file = File('${tempDir.path}/animated.gif')
      ..writeAsBytesSync(encoder.finish()!);
    await tester.pumpWidget(_thumbnail(_entry(file)));
    await _load(tester);
    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(provider, isA<SafeResizeImage>());
    expect(
      provider.resolve(ImageConfiguration.empty).completer,
      isA<OneFrameImageStreamCompleter>(),
    );
    expect(await _pixel(tester), [255, 0, 0, 255]);
    await tester.pump(const Duration(milliseconds: 30));
    expect(await _pixel(tester), [255, 0, 0, 255]);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
