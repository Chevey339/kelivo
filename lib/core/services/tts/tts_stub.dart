import 'tts_interface.dart';

/// Factory function for stub implementation
TtsInterface createTtsImpl() {
  return TtsStub();
}

/// Stub implementation for Windows platform where flutter_tts is not supported.
/// All methods are no-ops or return default values.
class TtsStub implements TtsInterface {
  @override
  Future<void> init() async {
    // No-op for Windows
  }

  @override
  void setCompletionHandler(void Function() handler) {
    // No-op
  }

  @override
  void setStartHandler(void Function() handler) {
    // No-op
  }

  @override
  void setCancelHandler(void Function() handler) {
    // No-op
  }

  @override
  void setPauseHandler(void Function() handler) {
    // No-op
  }

  @override
  void setContinueHandler(void Function() handler) {
    // No-op
  }

  @override
  void setErrorHandler(void Function(dynamic) handler) {
    // No-op
  }

  @override
  Future<dynamic> getLanguages() async {
    return <String>[];
  }

  @override
  Future<dynamic> getEngines() async {
    return <String>[];
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    // No-op
  }

  @override
  Future<void> setPitch(double pitch) async {
    // No-op
  }

  @override
  Future<void> setVolume(double volume) async {
    // No-op
  }

  @override
  Future<void> setEngine(String engine) async {
    // No-op
  }

  @override
  Future<dynamic> isLanguageAvailable(String languageTag) async {
    return false;
  }

  @override
  Future<void> setLanguage(String languageTag) async {
    // No-op
  }

  @override
  Future<void> awaitSpeakCompletion(bool shouldAwait) async {
    // No-op
  }

  @override
  Future<void> awaitSynthCompletion(bool shouldAwait) async {
    // No-op
  }

  @override
  Future<void> setQueueMode(int mode) async {
    // No-op
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    return 0; // Return failure code
  }

  @override
  Future<void> pause() async {
    // No-op
  }

  @override
  Future<void> stop() async {
    // No-op
  }
}
