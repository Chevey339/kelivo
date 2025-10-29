import 'dart:io' show Platform;
import 'tts_interface.dart';
import 'tts_stub.dart';

/// Factory for IO platforms (Android, iOS, Windows, etc.)
TtsInterface createTtsImpl() {
  // Use stub for Windows, real implementation for mobile platforms
  return TtsStub();
}
