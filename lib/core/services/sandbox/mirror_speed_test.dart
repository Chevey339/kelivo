import 'dart:async';

import 'package:http/http.dart' as http;

class MirrorProbe {
  const MirrorProbe({required this.uri, this.latency, this.error});

  final Uri uri;
  final Duration? latency;
  final Object? error;

  bool get ok => error == null && latency != null;
}

class MirrorSpeedTest {
  MirrorSpeedTest({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<MirrorProbe>> probe(
    List<Uri> candidates, {
    Duration timeout = const Duration(seconds: 5),
    int concurrency = 4,
  }) async {
    if (candidates.isEmpty) return const <MirrorProbe>[];
    final limit = concurrency < 1 ? 1 : concurrency;
    final results = List<MirrorProbe?>.filled(candidates.length, null);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= candidates.length) return;
        results[index] = await _probeOne(candidates[index], timeout);
      }
    }

    await Future.wait<void>([
      for (var i = 0; i < limit && i < candidates.length; i++) worker(),
    ]);
    return [for (final item in results) item!];
  }

  Future<MirrorProbe> _probeOne(Uri uri, Duration timeout) async {
    final request = http.Request('GET', uri);
    request.headers['range'] = 'bytes=0-1023';
    request.headers['Range'] = 'bytes=0-1023';
    final sw = Stopwatch()..start();
    try {
      final response = await _client.send(request).timeout(timeout);
      await _firstByte(response.stream).timeout(timeout);
      sw.stop();
      if (response.statusCode >= 400) {
        return MirrorProbe(uri: uri, error: 'HTTP ${response.statusCode}');
      }
      return MirrorProbe(uri: uri, latency: sw.elapsed);
    } catch (error) {
      sw.stop();
      return MirrorProbe(uri: uri, error: error);
    }
  }

  static Future<void> _firstByte(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      if (chunk.isNotEmpty) return;
    }
  }

  /// Prefers [official] when it succeeded and is within 20% of the fastest.
  static Uri pickFastest(List<MirrorProbe> results, {required Uri official}) {
    final ok = results.where((item) => item.ok).toList();
    if (ok.isEmpty) return official;
    ok.sort((a, b) => a.latency!.compareTo(b.latency!));
    final fastest = ok.first;
    MirrorProbe? officialHit;
    for (final item in ok) {
      if (item.uri == official) {
        officialHit = item;
        break;
      }
    }
    if (officialHit == null) return fastest.uri;
    final cap = Duration(
      microseconds: (fastest.latency!.inMicroseconds * 1.2).round(),
    );
    if (officialHit.latency! <= cap) return official;
    return fastest.uri;
  }
}
