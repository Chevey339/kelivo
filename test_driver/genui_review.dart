import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final directory = Directory(
      Platform.environment['GENUI_REVIEW_OUTPUT'] ??
          'build/genui/c28-native-review',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return true; // Capture succeeded; this is not a visual comparison verdict.
  },
);
