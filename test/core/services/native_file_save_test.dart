import 'package:Kelivo/core/services/native_file_save.dart';
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
    NativeFileSave.debugForceAndroidForTest = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

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
