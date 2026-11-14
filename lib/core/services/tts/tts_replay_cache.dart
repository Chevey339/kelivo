import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'network_tts.dart';

/// A complete audio file can be reused by any playback of the same request.
class TtsReplayCache {
  final _pending = <String, _PendingAudio>{};

  static Future<String> serviceKey(TtsServiceOptions service) => compute(
    _hashSettings,
    service.toJson()
      ..remove('id')
      ..remove('name')
      ..remove('enabled'),
  );

  // A voice-cloning profile can contain up to 10 MB of reference audio.
  static String _hashSettings(Map<String, dynamic> settings) =>
      sha256.convert(utf8.encode(jsonEncode(settings))).toString();

  void retain(Set<String> keys) {
    _pending.removeWhere((key, pending) {
      if (keys.contains(key)) return false;
      pending.cancel();
      return true;
    });
  }

  static String chunkKey(String serviceKey, String text) => '$serviceKey:$text';

  Future<File> audioFile({
    required String key,
    required Future<File> Function(
      String pathWithoutExtension,
      http.Client client,
      bool Function() cancelled,
    )
    generate,
  }) {
    final existing = _pending[key];
    if (existing != null) return existing.file;
    final pending = _pending[key] = _PendingAudio();
    pending.file = _load(key, pending, generate).whenComplete(() {
      if (identical(_pending[key], pending)) _pending.remove(key);
      pending.cancel();
    });
    return pending.file;
  }

  Future<File> _load(
    String key,
    _PendingAudio pending,
    Future<File> Function(String, http.Client, bool Function()) generate,
  ) async {
    final root = await getApplicationCacheDirectory();
    final digest = sha256.convert(utf8.encode(key)).toString();
    final entry = Directory(p.join(root.path, 'tts_replay', digest));
    if (await entry.exists()) {
      await for (final file in entry.list(followLinks: false)) {
        if (file is File &&
            p.basenameWithoutExtension(file.path) == 'audio' &&
            await file.length() > 0) {
          return file;
        }
      }
    }
    await entry.create(recursive: true);
    if (pending.cancelled) throw StateError('TTS playback stopped.');
    final staging = await generate(
      p.join(entry.path, const Uuid().v4()),
      pending.client = http.Client(),
      () => pending.cancelled,
    );
    final target = p.join(entry.path, 'audio${p.extension(staging.path)}');
    try {
      if (pending.cancelled) throw StateError('TTS playback stopped.');
      return await staging.rename(target);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }
}

class _PendingAudio {
  late final Future<File> file;
  http.Client? client;
  bool cancelled = false;

  void cancel() {
    cancelled = true;
    client?.close();
    client = null;
  }
}
