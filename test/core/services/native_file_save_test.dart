import 'dart:async';

import 'package:Kelivo/core/services/native_file_save.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.file_save');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    NativeFileSave.debugForceAndroidForTest = true;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    NativeFileSave.debugForceAndroidForTest = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('$platform requests external folders only for iOS backups', () async {
      debugDefaultTargetPlatformOverride = platform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveFileFromPath');
            expect(call.arguments, {
              'sourcePath': '/tmp/backup.zip',
              'fileName': 'backup.zip',
              if (platform == TargetPlatform.iOS)
                'requireOutsideAppContainer': true,
              'dialogTitle': 'Choose a backup folder',
            });
            return false;
          });
      expect(
        await NativeFileSave.saveFileFromPath(
          sourcePath: '/tmp/backup.zip',
          fileName: 'backup.zip',
          requireOutsideAppContainer: true,
          dialogTitle: 'Choose a backup folder',
        ),
        isFalse,
      );
    });
  }

  test(
    'routes save progress and cancellation only to the active request',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final started = Completer<int>(),
          stop = Completer<void>(),
          replied = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancelSave') {
          expect(call.arguments, await started.future);
          replied.complete(false);
          return null;
        }
        started.complete(call.arguments['progressId'] as int);
        return replied.future;
      });
      final updates = <(int, int)>[];
      final saving = NativeFileSave.saveFileFromPath(
        sourcePath: '/tmp/sample.zip',
        onProgress: (done, total) => updates.add((done, total)),
        whenCancelled: stop.future,
      );
      final id = await started.future;
      Future<void> report(int key) => messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('saveProgress', [key, 3, 10]),
        ),
        (_) {},
      );
      await report(id + 1);
      await report(id);
      stop.complete();
      expect(await saving, isFalse);
      await report(id);
      expect(updates, [(3, 10)]);
    },
  );

  test('direct writer streams chunks and completes the destination', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'createWritableFile') return true;
          return true;
        });

    final saved = await NativeFileSave.saveFileWithWriter(
      fileName: 'backup.zip',
      write: (writeChunk) async {
        await writeChunk(Uint8List.fromList(const <int>[4, 2]));
      },
    );

    expect(saved, isTrue);
    expect(calls.map((call) => call.method), <String>[
      'createWritableFile',
      'writeWritableFileChunk',
      'completeWritableFile',
    ]);
    expect(calls[1].arguments, isA<Uint8List>());
    expect((calls[1].arguments as Uint8List).toList(), <int>[4, 2]);
  });

  test('native chunk failure aborts and discards the destination', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'createWritableFile') return true;
          if (call.method == 'writeWritableFileChunk') {
            throw PlatformException(code: 'write_failed', message: 'disk full');
          }
          return true;
        });

    await expectLater(
      NativeFileSave.saveFileWithWriter(
        fileName: 'backup.zip',
        write: (writeChunk) => writeChunk(Uint8List(16)),
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'write_failed',
        ),
      ),
    );

    expect(calls.map((call) => call.method), <String>[
      'createWritableFile',
      'writeWritableFileChunk',
      'abortWritableFile',
    ]);
  });

  test('close failure also aborts the destination', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'createWritableFile':
              return true;
            case 'completeWritableFile':
              throw PlatformException(
                code: 'close_failed',
                message: 'flush failed',
              );
            case 'abortWritableFile':
              return true;
          }
          return null;
        });

    await expectLater(
      NativeFileSave.saveFileWithWriter(
        fileName: 'backup.zip',
        write: (_) async {},
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'close_failed',
        ),
      ),
    );

    expect(calls.map((call) => call.method), <String>[
      'createWritableFile',
      'completeWritableFile',
      'abortWritableFile',
    ]);
  });

  test('abort failure does not replace the original write error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'createWritableFile') return true;
          throw PlatformException(
            code: 'discard_failed',
            message: 'provider refused deletion',
          );
        });

    await expectLater(
      NativeFileSave.saveFileWithWriter(
        fileName: 'backup.zip',
        write: (_) async => throw StateError('source read failed'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'source read failed',
        ),
      ),
    );

    expect(calls.map((call) => call.method), <String>[
      'createWritableFile',
      'abortWritableFile',
    ]);
  });
}
