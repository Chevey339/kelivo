import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/services/logging/flutter_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'logs Flutter exception and stack without diagnostic toString',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_flutter_logs_',
      );
      final previousPaths = PathProviderPlatform.instance;
      final previousFlutterHandler = FlutterError.onError;
      final previousPlatformHandler = ui.PlatformDispatcher.instance.onError;
      PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
      addTearDown(() async {
        FlutterError.onError = previousFlutterHandler;
        ui.PlatformDispatcher.instance.onError = previousPlatformHandler;
        await FlutterLogger.setEnabled(false);
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      final forwarded = <FlutterErrorDetails>[];
      FlutterError.onError = forwarded.add;
      FlutterLogger.installGlobalHandlers();
      await FlutterLogger.setEnabled(true);
      final withStack = _ReleaseStyleFlutterErrorDetails(
        exception: StateError('synthesis failed'),
        stack: StackTrace.fromString('tts_stack_marker'),
      );
      final withoutStack = _ReleaseStyleFlutterErrorDetails(
        exception: StateError('error without a stack'),
      );
      FlutterError.onError!(withStack);
      FlutterError.onError!(withoutStack);
      FlutterLogger.log('logger_test_end');

      final logFile = File('${directory.path}/logs/flutter_logs.txt');
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      var content = '';
      while (!content.contains('logger_test_end')) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for Flutter log');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (await logFile.exists()) content = await logFile.readAsString();
      }
      expect(content, contains('[FlutterError] Bad state: synthesis failed'));
      expect(content, contains('[FlutterError] tts_stack_marker'));
      expect(
        content,
        contains('[FlutterError] Bad state: error without a stack'),
      );
      expect(content, isNot(contains("Instance of 'FlutterErrorDetails'")));
      expect(content, isNot(contains('[FlutterError] null')));
      expect(forwarded, [withStack, withoutStack]);
    },
  );
}

// Flutter's release build removes framework toString overrides.
class _ReleaseStyleFlutterErrorDetails extends FlutterErrorDetails {
  _ReleaseStyleFlutterErrorDetails({required super.exception, super.stack});

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      "Instance of 'FlutterErrorDetails'";
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
