import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaults = AutoRetryOptions.defaults();

  test('defaults match the product spec', () {
    expect(defaults.enabled, isFalse);
    expect(defaults.maxRetries, 3);
    expect(defaults.initialDelayMs, 1000);
    expect(defaults.multiplier, 2.0);
    expect(defaults.maxDelayMs, 30000);
    expect(defaults.jitter, isTrue);
    expect(defaults.retryOnNetworkError, isTrue);
    expect(defaults.retryStatusCodes, {408, 425, 429, 500, 502, 503, 504, 529});
    expect(defaults.retryKeywords, contains('访问量过大'));
    expect(defaults.stopKeywords, contains('余额'));
  });

  test('toJson/fromJson round-trip', () {
    final original = defaults.copyWith(
      enabled: true,
      maxRetries: 5,
      initialDelayMs: 250,
      multiplier: 1.5,
      maxDelayMs: 8000,
      jitter: false,
      retryOnNetworkError: false,
      retryStatusCodes: {429, 503},
      retryKeywords: const ['busy'],
      stopKeywords: const ['quota'],
    );
    final parsed = AutoRetryOptions.fromJson(original.toJson());
    expect(parsed.enabled, original.enabled);
    expect(parsed.maxRetries, original.maxRetries);
    expect(parsed.initialDelayMs, original.initialDelayMs);
    expect(parsed.multiplier, original.multiplier);
    expect(parsed.maxDelayMs, original.maxDelayMs);
    expect(parsed.jitter, original.jitter);
    expect(parsed.retryOnNetworkError, original.retryOnNetworkError);
    expect(parsed.retryStatusCodes, original.retryStatusCodes);
    expect(parsed.retryKeywords, original.retryKeywords);
    expect(parsed.stopKeywords, original.stopKeywords);
  });

  test('fromJson fills missing fields from defaults', () {
    final parsed = AutoRetryOptions.fromJson(const {'enabled': true});
    expect(parsed.enabled, isTrue);
    expect(parsed.maxRetries, defaults.maxRetries);
    expect(parsed.initialDelayMs, defaults.initialDelayMs);
    expect(parsed.multiplier, defaults.multiplier);
    expect(parsed.maxDelayMs, defaults.maxDelayMs);
    expect(parsed.jitter, defaults.jitter);
    expect(parsed.retryOnNetworkError, defaults.retryOnNetworkError);
    expect(parsed.retryStatusCodes, defaults.retryStatusCodes);
    expect(parsed.retryKeywords, defaults.retryKeywords);
    expect(parsed.stopKeywords, defaults.stopKeywords);
  });

  test('fromJson keeps empty keyword lists when the key is present', () {
    final parsed = AutoRetryOptions.fromJson(const {
      'retryKeywords': <String>[],
      'stopKeywords': <String>[],
      'retryStatusCodes': <int>[],
    });
    expect(parsed.retryKeywords, isEmpty);
    expect(parsed.stopKeywords, isEmpty);
    expect(parsed.retryStatusCodes, isEmpty);
  });

  test('clamps negative maxRetries and delays', () {
    final parsed = AutoRetryOptions.fromJson(const {
      'maxRetries': -1,
      'initialDelayMs': -50,
      'maxDelayMs': -1,
    });
    expect(parsed.maxRetries, 0);
    expect(parsed.initialDelayMs, 0);
    expect(parsed.maxDelayMs, 0);
    expect(
      AutoRetryOptions(
        enabled: true,
        maxRetries: -1,
        initialDelayMs: -10,
        multiplier: 2,
        maxDelayMs: -5,
        jitter: false,
        retryOnNetworkError: true,
        retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
        retryKeywords: AutoRetryOptions.defaultRetryKeywords,
        stopKeywords: AutoRetryOptions.defaultStopKeywords,
      ).maxRetries,
      0,
    );
  });

  test('clamps maxRetries to 0–10', () {
    expect(defaults.copyWith(maxRetries: 99).maxRetries, 10);
    expect(defaults.copyWith(maxRetries: -4).maxRetries, 0);
  });

  test('NaN and Infinity multiplier fall back to a finite default', () {
    final parsed = AutoRetryOptions.fromJson(<String, dynamic>{
      'multiplier': double.nan,
    });
    expect(parsed.multiplier, defaults.multiplier);
    expect(parsed.multiplier.isFinite, isTrue);
    expect(
      defaults.copyWith(multiplier: double.infinity).multiplier,
      defaults.multiplier,
    );
    expect(
      defaults.copyWith(multiplier: double.negativeInfinity).multiplier,
      defaults.multiplier,
    );
    expect(defaults.copyWith(multiplier: 0).multiplier, defaults.multiplier);
    expect(defaults.copyWith(multiplier: -1.5).multiplier, defaults.multiplier);
  });

  test('clamps huge finite multipliers to a sane max', () {
    expect(
      defaults.copyWith(multiplier: 1e308).multiplier,
      AutoRetryOptions.maxMultiplier,
    );
    expect(
      defaults.copyWith(multiplier: 101).multiplier,
      AutoRetryOptions.maxMultiplier,
    );
    expect(defaults.copyWith(multiplier: 10).multiplier, 10);
  });

  test('fromJson uses safe defaults for missing and invalid values', () {
    final parsed = AutoRetryOptions.fromJson(const {
      'enabled': 'yes',
      'maxRetries': 'nope',
      'initialDelayMs': true,
      'multiplier': 'NaN',
      'maxDelayMs': <int>[],
      'jitter': 1,
      'retryOnNetworkError': 'true',
    });
    expect(parsed.enabled, defaults.enabled);
    expect(parsed.maxRetries, defaults.maxRetries);
    expect(parsed.initialDelayMs, defaults.initialDelayMs);
    expect(parsed.multiplier, defaults.multiplier);
    expect(parsed.maxDelayMs, defaults.maxDelayMs);
    expect(parsed.jitter, defaults.jitter);
    expect(parsed.retryOnNetworkError, defaults.retryOnNetworkError);
  });
}
