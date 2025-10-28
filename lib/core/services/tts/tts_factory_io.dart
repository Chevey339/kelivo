import 'dart:io' show Platform;
import 'tts_interface.dart';
import 'tts_stub.dart';
import 'tts_impl.dart';

/// Factory for IO platforms (Android, iOS, Windows, etc.)
TtsInterface createTtsImpl() {
  // Use stub for Windows, real implementation for mobile platforms
  if (Platform.isWindows) {
    return TtsStub();
  } else {
    return TtsImpl();
  }
}
