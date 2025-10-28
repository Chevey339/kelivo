/// Platform-specific TTS factory using conditional imports.
/// This file exports the correct implementation based on the platform.
import 'tts_interface.dart';
export 'tts_interface.dart';

// Conditional imports based on platform
// Use stub by default, but override with IO implementation if dart:io is available
import 'tts_stub.dart' if (dart.library.io) 'tts_factory_io.dart' as tts_factory;

/// Factory function to create the appropriate TTS implementation
TtsInterface createTts() {
  return tts_factory.createTtsImpl();
}
