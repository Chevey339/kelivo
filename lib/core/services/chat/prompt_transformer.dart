import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../models/assistant.dart';

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
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dt = '$date $time';
    final os = Platform.operatingSystem;
    final osv = Platform.operatingSystemVersion;
    final device =
        os; // Simple fallback; can be extended with device_info plugins
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
      '{assistant_name}': assistant.name,
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
  static String applyMessageTemplate(
    String template, {
    required String role,
    required String message,
    required DateTime now,
  }) {
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final vars = <String, String>{
      'role': role,
      'message': message,
      'time': time,
      'date': date,
    };

    return template.replaceAllMapped(RegExp(r'{{\s*(\w+)\s*}}'), (match) {
      final key = match.group(1);
      return key != null && vars.containsKey(key)
          ? vars[key]!
          : match.group(0) ?? '';
    });
  }
}
