import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/services/background_icon_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late BackgroundIconStore store;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'kelivo-background-icon-',
    );
    store = BackgroundIconStore(supportDirectory: () async => temporary);
  });
  tearDown(() async => temporary.delete(recursive: true));

  test(
    'import owns a bounded thumbnail that survives deletion of the source',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1024, 512),
        ui.Paint()..color = const ui.Color(0xffee33aa),
      );
      final picture = recorder.endRecording();
      final original = await picture.toImage(1024, 512);
      final data = await original.toByteData(format: ui.ImageByteFormat.png);
      original.dispose();
      picture.dispose();
      final source = File(p.join(temporary.path, 'picker.png'));
      await source.writeAsBytes(data!.buffer.asUint8List());
      final imported = await store.importImage(source.path);
      expect(await source.exists(), isTrue);
      expect(p.dirname(imported), p.join(temporary.path, 'background-icons'));
      await source.delete();
      final codec = await ui.instantiateImageCodec(
        await File(imported).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 256);
      expect(frame.image.height, 256);
      frame.image.dispose();
      codec.dispose();
      await store.deleteOwnedImage(imported);
      expect(await File(imported).exists(), isFalse);
    },
  );

  test('cleanup preserves foreign files and symlinks', () async {
    final outside = File(p.join(temporary.path, 'icon-outside.png'));
    await outside.writeAsString('user data');
    final directory = await Directory(
      p.join(temporary.path, 'background-icons'),
    ).create();
    final foreign = File(p.join(directory.path, 'user.png'));
    await foreign.writeAsString('not imported');
    final link = Link(p.join(directory.path, 'icon-linked.png'));
    await link.create(outside.path);
    await store.deleteOwnedImage(outside.path);
    await store.deleteOwnedImage(foreign.path);
    await store.deleteOwnedImage(link.path);
    expect(await outside.readAsString(), 'user data');
    expect(await foreign.exists(), isTrue);
    expect(await link.exists(), isTrue);
  });

  test('invalid input does not create a broken replacement', () async {
    final source = File(p.join(temporary.path, 'invalid.jpg'));
    await source.writeAsString('invalid image');
    await expectLater(store.importImage(source.path), throwsA(anything));
    expect(await source.readAsString(), 'invalid image');
    expect(
      await Directory(p.join(temporary.path, 'background-icons')).exists(),
      isFalse,
    );
  });
}
