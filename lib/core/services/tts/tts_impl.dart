import 'package:flutter_tts/flutter_tts.dart';
import 'tts_interface.dart';

/// Real implementation using flutter_tts for mobile platforms.
class TtsImpl implements TtsInterface {
  late FlutterTts _tts;

  TtsImpl() {
    _tts = FlutterTts();
  }

  @override
  Future<void> init() async {
    // Initialization handled in constructor
  }

  @override
  void setCompletionHandler(void Function() handler) {
    _tts.setCompletionHandler(handler);
  }

  @override
  void setStartHandler(void Function() handler) {
    _tts.setStartHandler(handler);
  }

  @override
  void setCancelHandler(void Function() handler) {
    _tts.setCancelHandler(handler);
  }

  @override
  void setPauseHandler(void Function() handler) {
    _tts.setPauseHandler(handler);
  }

  @override
  void setContinueHandler(void Function() handler) {
    _tts.setContinueHandler(handler);
  }

  @override
  void setErrorHandler(void Function(dynamic) handler) {
    _tts.setErrorHandler(handler);
  }

  @override
  Future<dynamic> getLanguages() async {
    return await _tts.getLanguages;
  }

  @override
  Future<dynamic> getEngines() async {
    return await _tts.getEngines;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  @override
  Future<void> setEngine(String engine) async {
    await _tts.setEngine(engine);
  }

  @override
  Future<dynamic> isLanguageAvailable(String languageTag) async {
    return await _tts.isLanguageAvailable(languageTag);
  }

  @override
  Future<void> setLanguage(String languageTag) async {
    await _tts.setLanguage(languageTag);
  }

  @override
  Future<void> awaitSpeakCompletion(bool shouldAwait) async {
    await _tts.awaitSpeakCompletion(shouldAwait);
  }

  @override
  Future<void> awaitSynthCompletion(bool shouldAwait) async {
    await _tts.awaitSynthCompletion(shouldAwait);
  }

  @override
  Future<void> setQueueMode(int mode) async {
    await _tts.setQueueMode(mode);
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    return await _tts.speak(text);
  }

  @override
  Future<void> pause() async {
    await _tts.pause();
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Create a new FlutterTts instance (for recreation)
  void recreate() {
    _tts = FlutterTts();
  }

  /// Get the underlying FlutterTts instance (if needed for advanced operations)
  FlutterTts get underlying => _tts;
}
