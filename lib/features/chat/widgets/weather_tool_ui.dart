import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_font_weights.dart';

/// Parsed result of the `get_weather` local tool, including WeatherKit attribution.
class WeatherToolResult {
  const WeatherToolResult({
    required this.attribution,
    this.condition,
    this.temperatureC,
    this.apparentTemperatureC,
    this.precipitationChance,
    this.placeLabel,
    this.error,
  });

  final WeatherAttribution attribution;
  final String? condition;
  final double? temperatureC;
  final double? apparentTemperatureC;
  final double? precipitationChance;
  final String? placeLabel;
  final String? error;

  bool get isError => error != null && error!.isNotEmpty;
  bool get hasCurrent =>
      temperatureC != null || (condition?.isNotEmpty ?? false);

  static WeatherToolResult? tryParse(String? content) {
    if (content == null || content.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['error'] != null) return null;
      final attribution = WeatherAttribution.tryParse(map['attribution']);
      if (attribution == null) return null;
      final current = map['current'] is Map
          ? Map<String, dynamic>.from(map['current'] as Map)
          : const <String, dynamic>{};
      return WeatherToolResult(
        attribution: attribution,
        condition: current['condition']?.toString(),
        temperatureC: _asDouble(current['temperature_c']),
        apparentTemperatureC: _asDouble(current['apparent_temperature_c']),
        precipitationChance: _asDouble(current['precipitation_chance']),
        placeLabel: _placeLabel(map),
        error: map['error']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class WeatherAttribution {
  const WeatherAttribution({
    required this.serviceName,
    required this.legalPageUrl,
    this.displayText,
    this.combinedMarkLightUrl,
    this.combinedMarkDarkUrl,
    this.squareMarkLightUrl,
    this.squareMarkDarkUrl,
    this.squareMarkUrl,
  });

  final String serviceName;
  final String legalPageUrl;
  final String? displayText;
  final String? combinedMarkLightUrl;
  final String? combinedMarkDarkUrl;
  final String? squareMarkLightUrl;
  final String? squareMarkDarkUrl;
  final String? squareMarkUrl;

  String get label => (displayText != null && displayText!.trim().isNotEmpty)
      ? displayText!.trim()
      : 'Weather data from $serviceName';

  String? markUrlForBrightness(Brightness brightness) {
    final combined = brightness == Brightness.dark
        ? combinedMarkDarkUrl
        : combinedMarkLightUrl;
    if (combined != null && combined.isNotEmpty) return combined;
    final squareThemed = brightness == Brightness.dark
        ? squareMarkDarkUrl
        : squareMarkLightUrl;
    if (squareThemed != null && squareThemed.isNotEmpty) return squareThemed;
    if (squareMarkUrl != null && squareMarkUrl!.isNotEmpty) {
      return squareMarkUrl;
    }
    final fallbackCombined = brightness == Brightness.dark
        ? combinedMarkLightUrl
        : combinedMarkDarkUrl;
    if (fallbackCombined != null && fallbackCombined.isNotEmpty) {
      return fallbackCombined;
    }
    return null;
  }

  static WeatherAttribution? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final url = (map['legal_page_url'] ?? '').toString().trim();
    final name = (map['service_name'] ?? '').toString().trim();
    if (url.isEmpty && name.isEmpty) return null;
    return WeatherAttribution(
      serviceName: name.isEmpty ? 'Apple Weather' : name,
      legalPageUrl: url.isEmpty
          ? 'https://weatherkit.apple.com/legal-attribution.html'
          : url,
      displayText: map['display_text']?.toString(),
      combinedMarkLightUrl: _optionalUrl(map['combined_mark_light_url']),
      combinedMarkDarkUrl: _optionalUrl(map['combined_mark_dark_url']),
      squareMarkLightUrl: _optionalUrl(map['square_mark_light_url']),
      squareMarkDarkUrl: _optionalUrl(map['square_mark_dark_url']),
      squareMarkUrl: _optionalUrl(map['square_mark_url']),
    );
  }
}

/// Compact weather summary for the timeline tool card.
///
/// WeatherKit attribution is not shown here; it belongs on the tool
/// detail sheet via [WeatherAttributionLabel].
class WeatherToolSummary extends StatelessWidget {
  const WeatherToolSummary({
    super.key,
    required this.result,
    this.textColor,
    this.errorColor,
  });

  final WeatherToolResult result;
  final Color? textColor;
  final Color? errorColor;

  @override
  Widget build(BuildContext context) {
    if (!result.hasCurrent) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final primary = textColor ?? cs.onPrimaryContainer;

    return Text(
      _currentLine(result),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: AppFontWeights.medium,
        color: primary,
      ),
    );
  }
}

class WeatherAttributionLabel extends StatelessWidget {
  const WeatherAttributionLabel({
    super.key,
    required this.attribution,
    this.color,
  });

  final WeatherAttribution attribution;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = color ?? cs.onSurface.withValues(alpha: 0.62);
    final markUrl = attribution.markUrlForBrightness(
      Theme.of(context).brightness,
    );
    return InkWell(
      onTap: () => _openLegalPage(attribution.legalPageUrl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (markUrl != null) ...[
            Image.network(
              markUrl,
              height: 14,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              attribution.label,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: textColor,
                decoration: TextDecoration.underline,
                decorationColor: textColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _currentLine(WeatherToolResult result) {
  final parts = <String>[];
  if (result.placeLabel != null && result.placeLabel!.isNotEmpty) {
    parts.add(result.placeLabel!);
  }
  if (result.condition != null && result.condition!.isNotEmpty) {
    parts.add(result.condition!);
  }
  if (result.temperatureC != null) {
    parts.add('${_formatTemp(result.temperatureC!)}°C');
  }
  if (result.apparentTemperatureC != null) {
    parts.add('feels ${_formatTemp(result.apparentTemperatureC!)}°C');
  }
  if (result.precipitationChance != null) {
    parts.add('${(result.precipitationChance! * 100).round()}% precip');
  }
  return parts.join(' · ');
}

String _formatTemp(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String? _optionalUrl(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String? _placeLabel(Map<String, dynamic> map) {
  final lat = _asDouble(map['latitude']);
  final lon = _asDouble(map['longitude']);
  if (lat == null || lon == null) return null;
  return '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Future<void> _openLegalPage(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
