import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';

import '../../../core/models/assistant.dart';

typedef TextToSpeechStarter = Future<void> Function(String text);

class LocalToolNames {
  const LocalToolNames._();

  static const String timeInfo = 'get_time_info';
  static const String clipboard = 'clipboard_tool';
  static const String textToSpeech = 'text_to_speech';
  static const String askUser = 'ask_user_input_v0';
  static const String calculate = 'calculate';
  static const String screenTime = 'get_screen_time';
  static const String calendarQuery = 'calendar_query';
  static const String calendarCreate = 'calendar_create';

  static const List<String> all = [
    timeInfo,
    clipboard,
    textToSpeech,
    askUser,
    calculate,
    screenTime,
    calendarQuery,
    calendarCreate,
  ];
}

/// Platform availability of the device-backed local tools (implemented over
/// a MethodChannel in the Android/iOS host apps).
class DeviceLocalTools {
  const DeviceLocalTools._();

  static const MethodChannel _channel = MethodChannel('app.device_tools');

  static bool get screenTimeSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get calendarSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether Android Usage Access (PACKAGE_USAGE_STATS) is granted.
  static Future<bool> hasUsageStatsPermission() async {
    if (!screenTimeSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'hasUsageStatsPermission',
      );
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system Usage Access settings page (Android).
  static Future<void> openUsageAccessSettings() async {
    if (!screenTimeSupported) return;
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on MissingPluginException {
      // Unsupported host.
    } on PlatformException {
      // Settings unavailable.
    }
  }

  /// Returns true when calendar full access is already granted.
  /// Uses the native EventKit / Android calendar permission path (not
  /// permission_handler), so it works without iOS PERMISSION_EVENTS macros.
  static Future<bool> hasCalendarPermission() async {
    if (!calendarSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasCalendarPermission');
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Requests calendar full access via the native channel.
  /// Returns true only when granted. On iOS, permanently denied / restricted
  /// states open the app Settings page.
  static Future<bool> requestCalendarPermission() async {
    if (!calendarSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestCalendarPermission',
      );
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

class LocalToolsService {
  const LocalToolsService._();

  static List<Map<String, dynamic>> buildToolDefinitions({
    required Assistant? assistant,
    required bool supportsTools,
  }) {
    if (!supportsTools || assistant == null) {
      return const <Map<String, dynamic>>[];
    }

    final tools = <Map<String, dynamic>>[];
    if (assistant.localToolIds.contains(LocalToolNames.timeInfo)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.timeInfo,
          'description':
              'Get the current local date and time info from the device. Returns year, month, day, weekday, ISO date and time strings, timezone, UTC offset, and timestamp.',
          'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.clipboard)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.clipboard,
          'description':
              'Read or write plain text from the device clipboard. Use action: read or write. For write, provide text. Do NOT write to the clipboard unless the user has explicitly requested it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['read', 'write'],
                'description': 'Operation to perform: read or write',
              },
              'text': {
                'type': 'string',
                'description':
                    'Text to write to the clipboard. Required for write.',
              },
            },
            'required': ['action'],
          },
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.textToSpeech)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.textToSpeech,
          'description':
              'Speak text aloud to the user using the configured text-to-speech playback. Use this when the user asks you to read something aloud, or when audio output is appropriate. The tool returns after playback has been requested; audio may continue in the background. Provide natural, readable text without markdown formatting.',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description': 'The text to speak aloud.',
              },
            },
            'required': ['text'],
          },
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.askUser)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.askUser,
          'description':
              'Ask the user one or more short choice questions when you need clarification, additional information, or a decision before continuing. Supports single-choice and multi-choice questions. The UI will provide Other and Skip options automatically, so do not include those options yourself.',
          'parameters': {
            'type': 'object',
            'properties': {
              'questions': {
                'type': 'array',
                'description': 'One to four questions to ask the user.',
                'items': {
                  'type': 'object',
                  'properties': {
                    'id': {
                      'type': 'string',
                      'description':
                          'Unique stable identifier for this question.',
                    },
                    'question': {
                      'type': 'string',
                      'description':
                          'The full question text shown to the user.',
                    },
                    'type': {
                      'type': 'string',
                      'enum': ['single', 'multi'],
                      'description':
                          'Answer type: single choice or multi choice.',
                    },
                    'options': {
                      'type': 'array',
                      'description':
                          'Suggested options for the user to choose from.',
                      'items': {'type': 'string'},
                    },
                  },
                  'required': ['id', 'question'],
                },
              },
            },
            'required': ['questions'],
          },
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.calculate)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.calculate,
          'description':
              'Evaluate a mathematical expression. Supports: + - * / ^ % !, sin() cos() tan() sqrt() ln() abs() floor() ceil() sgn(), log(base, value), constants pi e. Example: "5!", "sin(pi/4)", "log(2, 8)", "floor(3.7)"',
          'parameters': {
            'type': 'object',
            'properties': {
              'expression': {
                'type': 'string',
                'description':
                    'A mathematical expression in standard notation, e.g. "(15 + 3) * 2", "2^10", "sqrt(144)"',
              },
            },
            'required': ['expression'],
          },
        },
      });
    }
    if (DeviceLocalTools.screenTimeSupported &&
        assistant.localToolIds.contains(LocalToolNames.screenTime)) {
      tools.add({
        'type': 'function',
        'function': {
          'name': LocalToolNames.screenTime,
          'description':
              "Get the user's app screen usage (screen time) over a time range. "
              "Specify a custom interval with 'begin'/'end', or use the 'range' preset (today/week). "
              'Returns the total foreground time and a per-app breakdown sorted by usage time (descending). '
              '${_deviceTimezoneHint()} '
              "Requires the 'Usage access' special permission; if it is not granted, the device's usage "
              'access settings page is opened automatically and an error is returned.',
          'parameters': {
            'type': 'object',
            'properties': {
              'begin': {
                'type': 'string',
                'description':
                    "Start time (inclusive). Accepts an ISO-8601 date 'yyyy-MM-dd', a local "
                    "date-time 'yyyy-MM-ddTHH:mm:ss', an offset date-time, or epoch milliseconds. "
                    "When provided, 'range' is ignored.",
              },
              'end': {
                'type': 'string',
                'description':
                    "End time (exclusive), same formats as 'begin'. Defaults to now.",
              },
              'range': {
                'type': 'string',
                'enum': ['today', 'week'],
                'description':
                    "Convenience preset, used only when 'begin' is omitted: today or week. Default today.",
              },
              'top': {
                'type': 'integer',
                'description':
                    'Maximum number of top apps to return, sorted by usage time. Default 10.',
              },
            },
          },
        },
      });
    }
    if (DeviceLocalTools.calendarSupported &&
        assistant.localToolIds.contains(LocalToolNames.calendarQuery)) {
      tools.add({
        'type': 'function',
        'function': {
          'name': LocalToolNames.calendarQuery,
          'description':
              "Query calendar events on the user's device within a time range. "
              "Specify a custom interval with 'begin'/'end', or use the 'range' preset (today/week/month). "
              'Returns a list of events with title, description, location, start/end times, and calendar info. '
              '${_deviceTimezoneHint()} '
              "Requires the 'Calendar' permission; if it is not granted, an error is returned.",
          'parameters': {
            'type': 'object',
            'properties': {
              'begin': {
                'type': 'string',
                'description':
                    "Start time (inclusive). Accepts an ISO-8601 date 'yyyy-MM-dd', a local "
                    "date-time 'yyyy-MM-ddTHH:mm:ss', an offset date-time, or epoch milliseconds. "
                    "When provided, 'range' is ignored.",
              },
              'end': {
                'type': 'string',
                'description': "End time (exclusive), same formats as 'begin'.",
              },
              'range': {
                'type': 'string',
                'enum': ['today', 'week', 'month'],
                'description':
                    "Convenience preset, used only when 'begin' is omitted: today, week, or month. Default today.",
              },
              'query': {
                'type': 'string',
                'description':
                    'Optional keyword to filter events by title (case-insensitive substring match).',
              },
              'limit': {
                'type': 'integer',
                'description':
                    'Maximum number of events to return. Default 20.',
              },
            },
          },
        },
      });
    }
    if (DeviceLocalTools.calendarSupported &&
        assistant.localToolIds.contains(LocalToolNames.calendarCreate)) {
      tools.add({
        'type': 'function',
        'function': {
          'name': LocalToolNames.calendarCreate,
          'description':
              "Create a new calendar event on the user's device. "
              'Requires title and start time at minimum. End time defaults to 1 hour after start. '
              "Use 'reminders' to attach notification alerts ahead of the event. "
              'The user will be asked to confirm before the event is created. '
              '${_deviceTimezoneHint()} '
              "Requires the 'Calendar' permission; if it is not granted, an error is returned.",
          'parameters': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'description': 'Event title.'},
              'description': {
                'type': 'string',
                'description': 'Event description or notes.',
              },
              'location': {'type': 'string', 'description': 'Event location.'},
              'start': {
                'type': 'string',
                'description':
                    "Start time. Accepts an ISO-8601 date 'yyyy-MM-dd', a local "
                    "date-time 'yyyy-MM-ddTHH:mm:ss', an offset date-time, or epoch milliseconds.",
              },
              'end': {
                'type': 'string',
                'description':
                    "End time, same formats as 'start'. Defaults to 1 hour after start.",
              },
              'all_day': {
                'type': 'boolean',
                'description':
                    'Whether this is an all-day event. Default false.',
              },
              'reminders': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description':
                    'Optional notification reminders, as minutes before the event start '
                    '(e.g. [10] for 10 minutes before, [0] for exactly at the start time, '
                    '[30, 1440] for 30 minutes and 1 day before). For all-day events the '
                    'offset counts back from the start of the day. No reminder is attached '
                    'unless you pass this, so include one whenever the user expects to be '
                    'notified. At most 5 reminders; values are clamped to 0-40320 minutes '
                    '(4 weeks) and de-duplicated, and the result reports what was actually '
                    'saved.',
              },
            },
            'required': ['title', 'start'],
          },
        },
      });
    }
    return tools;
  }

  static Future<String?> tryHandleToolCall(
    String name,
    Map<String, dynamic> args,
    Assistant? assistant, {
    TextToSpeechStarter? onSpeakText,
  }) async {
    if (assistant == null || !assistant.localToolIds.contains(name)) {
      return null;
    }
    if (name == LocalToolNames.timeInfo) {
      return jsonEncode(_buildTimeInfoPayload(DateTime.now()));
    }
    if (name == LocalToolNames.clipboard) {
      return _handleClipboardTool(args);
    }
    if (name == LocalToolNames.textToSpeech) {
      return _handleTextToSpeechTool(args, onSpeakText);
    }
    if (name == LocalToolNames.calculate) {
      return _handleCalculateTool(args);
    }
    if (name == LocalToolNames.screenTime &&
        DeviceLocalTools.screenTimeSupported) {
      return _invokeDeviceTool('getScreenTime', args);
    }
    if (name == LocalToolNames.calendarQuery &&
        DeviceLocalTools.calendarSupported) {
      return _invokeDeviceTool('queryCalendar', args);
    }
    if (name == LocalToolNames.calendarCreate &&
        DeviceLocalTools.calendarSupported) {
      return _invokeDeviceTool('createCalendarEvent', args);
    }
    return null;
  }

  static const MethodChannel _deviceToolsChannel = DeviceLocalTools._channel;

  static String _deviceTimezoneHint() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hh = abs.inHours.toString().padLeft(2, '0');
    final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return "The device timezone is '${now.timeZoneName}' (UTC offset $sign$hh:$mm); "
        'times without an explicit offset are interpreted in this timezone.';
  }

  /// Invokes a native device tool over the MethodChannel. The native side
  /// returns a JSON string payload (including structured error payloads that
  /// the model can act on, e.g. missing permissions).
  static Future<String> _invokeDeviceTool(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      final result = await _deviceToolsChannel.invokeMethod<String>(
        method,
        jsonEncode(args),
      );
      if (result == null || result.isEmpty) {
        return jsonEncode({
          'error': 'no_result',
          'message': 'The device tool returned no result.',
        });
      }
      return result;
    } on MissingPluginException {
      return jsonEncode({
        'error': 'unsupported_platform',
        'message': 'This tool is not available on the current platform.',
      });
    } on PlatformException catch (e) {
      return jsonEncode({
        'error': e.code,
        'message': e.message ?? 'The device tool failed.',
      });
    }
  }

  static Future<String> _handleClipboardTool(Map<String, dynamic> args) async {
    final action = (args['action'] ?? '').toString();
    switch (action) {
      case 'read':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        return jsonEncode({'text': data?.text ?? ''});
      case 'write':
        final text = args['text']?.toString();
        if (text == null) {
          throw ArgumentError('text is required for clipboard write');
        }
        await Clipboard.setData(ClipboardData(text: text));
        return jsonEncode({'success': true, 'text': text});
      default:
        throw ArgumentError('unknown clipboard action: $action');
    }
  }

  static Future<String> _handleTextToSpeechTool(
    Map<String, dynamic> args,
    TextToSpeechStarter? onSpeakText,
  ) async {
    final text = args['text']?.toString().trim();
    if (text == null || text.isEmpty) {
      throw ArgumentError('text is required for text_to_speech');
    }
    if (onSpeakText == null) {
      throw StateError('text-to-speech executor is unavailable');
    }
    await onSpeakText(text);
    return jsonEncode({'success': true});
  }

  static Map<String, dynamic> _buildTimeInfoPayload(DateTime now) {
    final offset = now.timeZoneOffset;
    final offsetSign = offset.isNegative ? '-' : '+';
    final offsetAbs = offset.abs();
    final offsetHours = offsetAbs.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (offsetAbs.inMinutes % 60).toString().padLeft(2, '0');

    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final weekdayEn = _englishWeekdayName(now.weekday);

    return <String, dynamic>{
      'year': now.year,
      'month': now.month,
      'day': now.day,
      'weekday': weekdayEn,
      'weekday_en': weekdayEn,
      'weekday_index': now.weekday,
      'date': '$year-$month-$day',
      'time': '$hour:$minute:$second',
      'datetime': now.toIso8601String(),
      'timezone': now.timeZoneName,
      'utc_offset': '$offsetSign$offsetHours:$offsetMinutes',
      'timestamp_ms': now.millisecondsSinceEpoch,
    };
  }

  static String _englishWeekdayName(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Unknown',
    };
  }

  static String _handleCalculateTool(Map<String, dynamic> args) {
    final expression = (args['expression'] ?? '').toString().trim();
    if (expression.isEmpty) {
      return jsonEncode({
        'error': 'empty_expression',
        'message':
            'Expression is empty. Please provide a mathematical expression in standard notation, e.g. "(15 + 3) * 2".',
      });
    }

    try {
      final parsed = GrammarParser().parse(expression);
      final result = parsed.evaluate(EvaluationType.REAL, ContextModel());
      if (!result.isFinite) {
        return jsonEncode({
          'error': 'math_error',
          'message':
              'The result is not a finite number. Please check your expression (e.g. division by zero).',
        });
      }
      return jsonEncode({
        'expression': expression,
        'result': result.toString(),
      });
    } catch (e) {
      return jsonEncode({
        'error': 'parse_error',
        'message':
            'Could not parse the expression. Use standard notation, e.g. "(15 + 3) * 2".',
        'detail': e.toString(),
      });
    }
  }
}
