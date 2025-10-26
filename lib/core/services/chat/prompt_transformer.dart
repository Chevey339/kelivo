import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/assistant.dart';
import '../../providers/settings_provider.dart';

class PromptTransformer {
  static Map<String, String> buildPlaceholders({
    required BuildContext context,
    required Assistant assistant,
    required String? modelId,
    required String? modelName,
    required String userNickname,
  }) {
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tz = now.timeZoneName;
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dt = '$date $time';
    final os = kIsWeb ? 'web' : Platform.operatingSystem;
    final osv = kIsWeb ? 'unknown' : Platform.operatingSystemVersion;
    final device = os; // Simple fallback; can be extended with device_info plugins
    final battery = 'unknown';

    return <String, String>{
      '{cur_date}': date,
      '{cur_time}': time,
      '{cur_datetime}': dt,
      '{model_id}': modelId ?? '',
      '{model_name}': modelName ?? (modelId ?? ''),
      '{locale}': locale,
      '{timezone}': tz,
      '{system_version}': '$os $osv',
      '{device_info}': device,
      '{battery_level}': battery,
      '{nickname}': userNickname,
    };
  }

  static String replacePlaceholders(String text, Map<String, String> vars) {
    var out = text;
    vars.forEach((k, v) {
      out = out.replaceAll(k, v);
    });
    return out;
  }

  // Very simple mustache-like replacement for message template variables
  // Supported: {{ role }}, {{ message }}, {{ time }}, {{ date }}
  static String applyMessageTemplate(String template, {
    required String role,
    required String message,
    required DateTime now,
  }) {
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return template
        .replaceAll('{{ role }}', role)
        .replaceAll('{{ message }}', message)
        .replaceAll('{{ time }}', time)
        .replaceAll('{{ date }}', date);
  }
}

