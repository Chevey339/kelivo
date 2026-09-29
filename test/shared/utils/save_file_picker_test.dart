import 'dart:io';

import 'package:Kelivo/shared/utils/save_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _SavePicker extends FilePicker {
  String? destination;
  String? suggestedName;
  List<String>? extensions;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    expect(bytes, isNull, reason: 'Existing files must not be buffered');
    suggestedName = fileName;
    extensions = allowedExtensions;
    return destination;
  }
}

// Fail immediately if exporting regresses to reading the entire source.
class _UnbufferedFile implements File {
  _UnbufferedFile(this.file);

  final File file;

  @override
  String get path => file.path;

  @override
  Future<File> copy(String newPath) => file.copy(newPath);

  @override
  Future<Uint8List> readAsBytes() => throw StateError('Whole-file read');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.file_save');
  late Directory temp;
  late File source;
  late _SavePicker picker;
  FilePicker? originalPicker;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('save_file_picker_test_');
    source = await File(p.join(temp.path, '报告.txt')).writeAsString('hello 世界');
    try {
      originalPicker = FilePicker.platform;
    } catch (_) {
      originalPicker = null;
    }
    picker = _SavePicker();
    FilePicker.platform = picker;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    if (originalPicker != null) FilePicker.platform = originalPicker!;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  test('desktop copies an existing file without reading its bytes', () async {
    picker.destination = p.join(temp.path, 'saved', 'copy.txt');
    final saved = await saveHostFileWithPicker(file: _UnbufferedFile(source));
    expect(saved, picker.destination);
    expect(await File(saved!).readAsString(), 'hello 世界');
    expect(await source.readAsString(), 'hello 世界');
    expect(picker.suggestedName, '报告.txt');
    expect(picker.extensions, ['txt']);
  });

  test('desktop cancellation does not read or modify the source', () async {
    expect(await saveHostFileWithPicker(file: _UnbufferedFile(source)), isNull);
    expect(await source.readAsString(), 'hello 世界');
  });

  test('saving onto the source preserves its contents', () async {
    picker.destination = source.path;
    expect(await saveHostFileWithPicker(file: source), source.path);
    expect(await source.readAsString(), 'hello 世界');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform sends the source path without a byte payload', () async {
      debugDefaultTargetPlatformOverride = platform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveFileFromPath');
            expect(call.arguments, {
              'sourcePath': source.path,
              'fileName': '报告.txt',
            });
            return true;
          });
      expect(
        await saveHostFileWithPicker(file: _UnbufferedFile(source)),
        '报告.txt',
      );
      expect(picker.suggestedName, isNull);
    });

    test(
      '$platform preserves trailing spaces in the source and name',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final selected = await File(
          '${source.path} ',
        ).writeAsString('selected');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.arguments, {
                'sourcePath': selected.path,
                'fileName': '报告.txt ',
              });
              expect(
                await File(
                  call.arguments['sourcePath'] as String,
                ).readAsString(),
                'selected',
              );
              return true;
            });
        expect(
          await saveHostFileWithPicker(file: _UnbufferedFile(selected)),
          '报告.txt ',
        );
        expect(await source.readAsString(), 'hello 世界');
      },
    );
  }

  for (final outcome in ['saved', 'cancelled', 'failed']) {
    test('iOS custom name stages a file and cleans up when $outcome', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late String stagedPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            stagedPath = call.arguments['sourcePath'] as String;
            expect(p.basename(stagedPath), '重命名.txt');
            expect(stagedPath, isNot(source.path));
            expect(await File(stagedPath).readAsString(), 'hello 世界');
            if (outcome == 'failed') {
              throw PlatformException(code: 'save_failed');
            }
            return outcome == 'saved';
          });
      final save = saveHostFileWithPicker(
        file: _UnbufferedFile(source),
        fileName: '重命名.txt',
      );
      if (outcome == 'failed') {
        await expectLater(save, throwsA(isA<PlatformException>()));
      } else {
        expect(await save, outcome == 'saved' ? '重命名.txt' : null);
      }
      expect(await Directory(p.dirname(stagedPath)).exists(), isFalse);
      expect(await source.readAsString(), 'hello 世界');
    });
  }
}
