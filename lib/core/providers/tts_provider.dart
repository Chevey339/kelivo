import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// System TTS provider using flutter_tts.
/// Keeps minimal state and simple chunked speaking for long text.
class TtsProvider extends ChangeNotifier {
  static const String _rateKey = 'tts_speech_rate_v1';
  static const String _pitchKey = 'tts_pitch_v1';
  static const String _engineKey = 'tts_engine_v1';
  static const String _langKey = 'tts_language_v1';

  late FlutterTts _tts;

  bool _initialized = false;
  bool _engineReady = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  String? _error;

  // Settings
  double _speechRate = 0.5; // 0.0 - 1.0 (Android)
  double _pitch = 1.0; // 0.5 - 2.0
  String? _engineId; // Android engine package
  String? _languageTag; // e.g., en-US or zh-CN

  // Chunk playback
  final List<String> _chunks = <String>[];
  int _currentChunkIndex = 0;
  Completer<void>? _speakingCompleter;

  // Consider available once provider is initialized; engine readiness is handled internally
  bool get isAvailable => _initialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  String? get error => _error;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String? get engineId => _engineId;
  String? get languageTag => _languageTag;

  TtsProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      // Windows 平台暂不实现 TTS，直接返回可用但提示未实现
      if (defaultTargetPlatform == TargetPlatform.windows) {
        _initialized = true;
        _error = 'Windows 平台暂未实现 TTS 功能';
        notifyListeners();
        return;
      }
      _tts = FlutterTts();
      // Load settings
      final prefs = await SharedPreferences.getInstance();
      _speechRate = (prefs.getDouble(_rateKey) ?? 0.5).clamp(0.1, 1.0);
      _pitch = (prefs.getDouble(_pitchKey) ?? 1.0).clamp(0.5, 2.0);
      _engineId = prefs.getString(_engineKey);
      _languageTag = prefs.getString(_langKey);
      
      // Event handlers
      _tts.setStartHandler(() {
        _isSpeaking = true;
        _isPaused = false;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _advanceOrFinish();
      });
      _tts.setCancelHandler(() {
        _stopInternal(updateState: true);
      });
      _tts.setPauseHandler(() {
        _isPaused = true;
        notifyListeners();
      });
      _tts.setContinueHandler(() {
        _isPaused = false;
        notifyListeners();
      });
      _tts.setErrorHandler((msg) {
        _error = msg;
        _stopInternal(updateState: true);
      });

      // Nudge engine to bind and wait (with timeout)
      await _kickEngine();
      await _ensureBound(timeout: const Duration(seconds: 5));
      await _selectEngine();

      await _applyConfig();

      _initialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _initialized = false;
      notifyListeners();
    }
  }

  Future<void> _applyConfig() async {
    // Configure engine
    try { await _tts.setSpeechRate(_speechRate); } catch (_) {}
    try { await _tts.setPitch(_pitch); } catch (_) {}
    try { await _tts.setVolume(1.0); } catch (_) {}
    // Try to set device locale language
    final loc = ui.PlatformDispatcher.instance.locale;
    final defaultTag = _localeToTag(loc);
    try {
      if (_engineId != null && _engineId!.isNotEmpty) {
        try { await _tts.setEngine(_engineId!); } catch (_) {}
      }
      final tag = (_languageTag == null || _languageTag!.isEmpty) ? defaultTag : _languageTag!;
      final res = await _tts.isLanguageAvailable(tag);
      if (res == true) {
        await _tts.setLanguage(tag);
      } else {
        // Fallbacks
        final zh = loc.languageCode.toLowerCase().startsWith('zh');
        final fb = zh ? 'zh-CN' : 'en-US';
        final ok = await _tts.isLanguageAvailable(fb);
        if (ok == true) {
          await _tts.setLanguage(fb);
        }
      }
    } catch (_) {
      // Ignore language config failures; engine may still speak
    }
    // Better UX: await completion callbacks to sequence chunks
    try { await _tts.awaitSpeakCompletion(true); } catch (_) {}
    try { await _tts.awaitSynthCompletion(true); } catch (_) {}
    try { await _tts.setQueueMode(1); } catch (_) {}
  }

  Future<void> _recreateEngine() async {
    try { await _tts.stop(); } catch (_) {}
    _engineReady = false;
    _tts = FlutterTts();
    // Rebind event handlers
    _tts.setStartHandler(() {
      _isSpeaking = true;
      _isPaused = false;
      notifyListeners();
    });
    _tts.setCompletionHandler(() {
      _advanceOrFinish();
    });
    _tts.setCancelHandler(() {
      _stopInternal(updateState: true);
    });
    _tts.setPauseHandler(() {
      _isPaused = true;
      notifyListeners();
    });
    _tts.setContinueHandler(() {
      _isPaused = false;
      notifyListeners();
    });
    _tts.setErrorHandler((msg) {
      _error = msg;
      _stopInternal(updateState: true);
    });
    await _kickEngine();
    await _ensureBound(timeout: const Duration(seconds: 2));
    await _selectEngine();
    await _applyConfig();
  }

  Future<void> _kickEngine() async {
    // Querying languages/engines tends to trigger binding on Android.
    try { await _tts.getLanguages; } catch (_) {}
    try { await _tts.getEngines; } catch (_) {}
  }

  Future<void> _ensureBound({Duration timeout = const Duration(seconds: 3)}) async {
    if (_engineReady) return;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final langs = await _tts.getLanguages;
        if (langs != null) {
          _engineReady = true;
          notifyListeners();
          return;
        }
      } catch (_) {
        // ignore and retry
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _selectEngine() async {
    // Android only: choose Google engine if present, otherwise first available
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.isNotEmpty) {
        String? chosen;
        for (final e in engines) {
          final s = e.toString();
          if (s.toLowerCase().contains('google')) { chosen = s; break; }
        }
        chosen ??= engines.first.toString();
        try { await _tts.setEngine(chosen); } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> setSpeechRate(double rate) async {
    final r = rate.clamp(0.1, 1.0);
    if (_speechRate == r) return;
    _speechRate = r;
    try {
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {}
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, _speechRate);
  }

  Future<void> setPitch(double v) async {
    final p = v.clamp(0.5, 2.0);
    if (_pitch == p) return;
    _pitch = p;
    try {
      await _tts.setPitch(_pitch);
    } catch (_) {}
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pitchKey, _pitch);
  }

  Future<List<String>> listEngines() async {
    try {
      final res = await _tts.getEngines;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  Future<List<String>> listLanguages() async {
    try {
      final res = await _tts.getLanguages;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  Future<void> setEngineId(String id) async {
    _engineId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, id);
    try { await _tts.setEngine(id); } catch (_) {}
    await _applyConfig();
    notifyListeners();
  }

  Future<void> setLanguageTag(String tag) async {
    _languageTag = tag;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, tag);
    try { await _tts.setLanguage(tag); } catch (_) {}
    notifyListeners();
  }

  /// Speak text via System TTS. If [flush] is true, stop current playback first.
  Future<void> speak(String text, {bool flush = true}) async {
    if (!_initialized) return;
    await _ensureBound();
    if (flush) {
      try { await _tts.stop(); } catch (_) {}
      _stopInternal(updateState: false);
    }
    final content = _stripMarkdown(text).trim();
    if (content.isEmpty) return;
    _chunks
      ..clear()
      ..addAll(_chunkText(content, maxLen: 450));
    _currentChunkIndex = 0;
    _speakingCompleter = Completer<void>();
    await _speakNext();
    return _speakingCompleter!.future;
  }

  static String _localeToTag(ui.Locale l) {
    final lang = l.languageCode;
    final country = l.countryCode;
    if (country != null && country.isNotEmpty) return '$lang-$country';
    return lang;
  }

  Future<void> pause() async {
    await _ensureBound();
    try {
      await _tts.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!_initialized) return;
    await _ensureBound();
    if (!_isPaused) return;
    final hasChunk = _currentChunkIndex < _chunks.length;
    if (hasChunk) {
      final s = _chunks[_currentChunkIndex];
      final ok = await _trySpeak(s);
      if (ok) {
        _isPaused = false;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    await _ensureBound();
    try {
      await _tts.stop();
    } catch (_) {}
    _stopInternal(updateState: true);
  }

  void _stopInternal({bool updateState = false}) {
    _chunks.clear();
    _currentChunkIndex = 0;
    _isSpeaking = false;
    _isPaused = false;
    if (_speakingCompleter != null && !_speakingCompleter!.isCompleted) {
      _speakingCompleter!.complete();
    }
    _speakingCompleter = null;
    if (updateState) notifyListeners();
  }

  Future<void> _speakNext() async {
    if (_currentChunkIndex >= _chunks.length) {
      // Finished
      _isSpeaking = false;
      _isPaused = false;
      if (_speakingCompleter != null && !_speakingCompleter!.isCompleted) {
        _speakingCompleter!.complete();
      }
      _speakingCompleter = null;
      notifyListeners();
      return;
    }
    final s = _chunks[_currentChunkIndex];
    final ok = await _trySpeak(s);
    if (!ok) {
      _error = 'TTS speak failed';
      _stopInternal(updateState: true);
    }
  }

  Future<bool> _trySpeak(String text) async {
    await _ensureBound();
    dynamic res;
    try { res = await _tts.speak(text, focus: true); } catch (_) {}
    if (_speakOk(res)) return true;
    // Try picking engine and retry a few times to accommodate late binding
    await _selectEngine();
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 180));
      try { res = await _tts.speak(text, focus: true); } catch (_) {}
      if (_speakOk(res)) return true;
    }
    // Recreate engine once and re-try
    await _recreateEngine();
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      try { res = await _tts.speak(text, focus: true); } catch (_) {}
      if (_speakOk(res)) return true;
    }
    return false;
  }

  bool _speakOk(dynamic res) {
    if (res == null) return false;
    if (res is int) return res == 1;
    if (res is bool) return res == true;
    final s = res.toString();
    return s == '1' || s.toLowerCase() == 'true' || s.toLowerCase() == 'success';
  }

  void _advanceOrFinish() {
    if (_currentChunkIndex < _chunks.length - 1) {
      _currentChunkIndex += 1;
      _speakNext();
    } else {
      _stopInternal(updateState: true);
    }
  }

  // Very lightweight markdown stripper for TTS purposes.
  static String _stripMarkdown(String input) {
    var s = input;
    // Remove code blocks
    s = s.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), ' ');
    // Remove inline code
    s = s.replaceAll(RegExp(r'`[^`]*`'), ' ');
    // Links: keep link text
    s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1) ?? '');
    // Images: remove
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]*\)'), ' ');
    // Headings and emphasis markers
    s = s.replaceAll(RegExp(r'^[#>\-\*\+]+\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'[*_~]{1,3}'), '');
    // Tables/pipes
    s = s.replaceAll('|', ' ');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  // Simple sentence chunker with max length.
  static List<String> _chunkText(String text, {int maxLen = 450}) {
    final List<String> out = <String>[];
    final parts = text
        .split(RegExp(r'(?<=[。！？!?.;；])'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final buf = StringBuffer();
    for (final p in parts) {
      if ((buf.length + p.length) > maxLen && buf.isNotEmpty) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      buf.write(p);
      if (buf.length >= maxLen) {
        out.add(buf.toString().trim());
        buf.clear();
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    if (out.isEmpty) out.add(text.length > maxLen ? text.substring(0, maxLen) : text);
    return out;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
