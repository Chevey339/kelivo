import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/chat/widgets/weather_tool_ui.dart';

void main() {
  test('parses weather payload and keeps WeatherKit attribution', () {
    final result = WeatherToolResult.tryParse(
      jsonEncode({
        'latitude': 37.33,
        'longitude': -122.03,
        'current': {
          'condition': 'Clear',
          'temperature_c': 21.5,
          'apparent_temperature_c': 20.0,
          'precipitation_chance': 0.1,
        },
        'attribution': {
          'service_name': 'Apple Weather',
          'legal_page_url':
              'https://weatherkit.apple.com/legal-attribution.html',
          'display_text': 'Weather data from Apple Weather',
          'combined_mark_light_url':
              'https://weatherkit.apple.com/mark-light.png',
          'combined_mark_dark_url':
              'https://weatherkit.apple.com/mark-dark.png',
          'square_mark_url': 'https://weatherkit.apple.com/mark-square.png',
          'square_mark_light_url':
              'https://weatherkit.apple.com/mark-square-light.png',
          'square_mark_dark_url':
              'https://weatherkit.apple.com/mark-square-dark.png',
        },
      }),
    );

    expect(result, isNotNull);
    expect(result!.hasCurrent, isTrue);
    expect(result.isError, isFalse);
    expect(result.temperatureC, 21.5);
    expect(result.attribution.serviceName, 'Apple Weather');
    expect(
      result.attribution.legalPageUrl,
      'https://weatherkit.apple.com/legal-attribution.html',
    );
    expect(result.attribution.label, 'Weather data from Apple Weather');
    expect(
      result.attribution.combinedMarkLightUrl,
      'https://weatherkit.apple.com/mark-light.png',
    );
    expect(
      result.attribution.combinedMarkDarkUrl,
      'https://weatherkit.apple.com/mark-dark.png',
    );
    expect(
      result.attribution.squareMarkUrl,
      'https://weatherkit.apple.com/mark-square.png',
    );
    expect(
      result.attribution.markUrlForBrightness(Brightness.light),
      'https://weatherkit.apple.com/mark-light.png',
    );
    expect(
      result.attribution.markUrlForBrightness(Brightness.dark),
      'https://weatherkit.apple.com/mark-dark.png',
    );
  });

  test(
    'falls back to square WeatherKit marks when combined marks are missing',
    () {
      final attribution = WeatherAttribution.tryParse({
        'service_name': 'Apple Weather',
        'legal_page_url': 'https://weatherkit.apple.com/legal-attribution.html',
        'square_mark_url': 'https://weatherkit.apple.com/mark-square.png',
      });

      expect(attribution, isNotNull);
      expect(
        attribution!.markUrlForBrightness(Brightness.light),
        'https://weatherkit.apple.com/mark-square.png',
      );
      expect(
        attribution.markUrlForBrightness(Brightness.dark),
        'https://weatherkit.apple.com/mark-square.png',
      );
    },
  );

  test('missing attribution is not treated as a weather card', () {
    expect(WeatherToolResult.tryParse('{"error":"NO_PERMISSION"}'), isNull);
    expect(WeatherToolResult.tryParse('not-json'), isNull);
  });
}
