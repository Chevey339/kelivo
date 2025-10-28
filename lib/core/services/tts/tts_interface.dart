/// Platform-agnostic TTS interface.
/// This allows conditional implementation per platform.
abstract class TtsInterface {
  /// Initialize the TTS engine
  Future<void> init();

  /// Set completion handler
  void setCompletionHandler(void Function() handler);

  /// Set start handler
  void setStartHandler(void Function() handler);

  /// Set cancel handler
  void setCancelHandler(void Function() handler);

  /// Set pause handler
  void setPauseHandler(void Function() handler);

  /// Set continue handler
  void setContinueHandler(void Function() handler);

  /// Set error handler
  void setErrorHandler(void Function(dynamic) handler);

  /// Get available languages
  Future<dynamic> getLanguages();

  /// Get available engines
  Future<dynamic> getEngines();

  /// Set speech rate (0.0 - 1.0)
  Future<void> setSpeechRate(double rate);

  /// Set pitch (0.5 - 2.0)
  Future<void> setPitch(double pitch);

  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume);

  /// Set engine
  Future<void> setEngine(String engine);

  /// Check if language is available
  Future<dynamic> isLanguageAvailable(String languageTag);

  /// Set language
  Future<void> setLanguage(String languageTag);

  /// Await speak completion
  Future<void> awaitSpeakCompletion(bool shouldAwait);

  /// Await synth completion
  Future<void> awaitSynthCompletion(bool shouldAwait);

  /// Set queue mode
  Future<void> setQueueMode(int mode);

  /// Speak text
  Future<dynamic> speak(String text, {bool focus = false});

  /// Pause speaking
  Future<void> pause();

  /// Stop speaking
  Future<void> stop();
}
