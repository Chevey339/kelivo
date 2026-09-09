import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';

void main() {
  final official = Uri.parse('https://official.example/file');
  final fast = Uri.parse('https://fast.example/file');
  final slow = Uri.parse('https://slow.example/file');
  final dead = Uri.parse('https://dead.example/file');

  test('pickFastest prefers official within 20%', () {
    final picked = MirrorSpeedTest.pickFastest([
      MirrorProbe(uri: official, latency: const Duration(milliseconds: 110)),
      MirrorProbe(uri: fast, latency: const Duration(milliseconds: 100)),
    ], official: official);
    expect(picked, official);
  });

  test('pickFastest uses fastest when official is slower than 20%', () {
    final picked = MirrorSpeedTest.pickFastest([
      MirrorProbe(uri: official, latency: const Duration(milliseconds: 200)),
      MirrorProbe(uri: fast, latency: const Duration(milliseconds: 100)),
    ], official: official);
    expect(picked, fast);
  });

  test('pickFastest falls back to official when every probe fails', () {
    expect(
      MirrorSpeedTest.pickFastest([
        MirrorProbe(uri: dead, error: 'timeout'),
      ], official: official),
      official,
    );
  });

  test('probe records latency and failures', () async {
    final client = MockClient((request) async {
      if (request.url == dead) {
        throw TimeoutException('nope');
      }
      if (request.url == slow) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(
        request.headers['range'] ?? request.headers['Range'],
        'bytes=0-1023',
      );
      return http.Response.bytes(List<int>.filled(64, 1), 206);
    });
    final results = await MirrorSpeedTest(
      client: client,
    ).probe([fast, slow, dead], timeout: const Duration(seconds: 2));
    expect(results, hasLength(3));
    expect(results[0].uri, fast);
    expect(results[0].ok, isTrue);
    expect(results[1].ok, isTrue);
    expect(results[1].latency! > results[0].latency!, isTrue);
    expect(results[2].ok, isFalse);
  });

  test('probe times out a hung candidate', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      return http.Response.bytes(const <int>[1], 200);
    });
    final results = await MirrorSpeedTest(
      client: client,
    ).probe([dead], timeout: const Duration(milliseconds: 20));
    expect(results.single.ok, isFalse);
  });
}
