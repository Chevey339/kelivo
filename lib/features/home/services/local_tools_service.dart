import 'dart:convert';

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
              'Get the current local date and time from the user\'s device. Use when the user asks "what time is it", "what\'s the date", "what day is it", "what\'s the timezone", or any question depending on the current wall-clock time. Do NOT use for time differences, durations, or scheduling logic — this tool only returns the current instant.',
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
              'Read or write plain text from/to the device clipboard. Use only when the user explicitly asks to read, copy, or paste clipboard content. CRITICAL: Do NOT write to the clipboard unless the user has explicitly requested it. Never read the clipboard speculatively — clipboard content is private. For write operations, confirm the text content with the user first if there is any ambiguity.',
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
              'Ask the user one or more short choice questions when you need clarification, additional information, or a decision before you can continue. Use when the request is ambiguous, the user must pick between options, or you need specific information they have not provided. IMPORTANT: The UI automatically provides "Other" and "Skip" options, so do NOT include those as explicit options. Do NOT use for yes/no questions answerable inline — reserve this for structured choices. Do NOT use when you can infer the answer from conversation context. Limit to at most 4 questions at a time.',
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
    return null;
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
        'message': 'Expression is empty. Please provide a mathematical expression in standard notation, e.g. "(15 + 3) * 2".',
      });
    }

    try {
      final parsed = GrammarParser().parse(expression);
      final result = parsed.evaluate(EvaluationType.REAL, ContextModel());
      if (!result.isFinite) {
        return jsonEncode({
          'error': 'math_error',
          'message': 'The result is not a finite number. Please check your expression (e.g. division by zero).',
        });
      }
      return jsonEncode({
        'expression': expression,
        'result': result.toString(),
      });
    } catch (e) {
      return jsonEncode({
        'error': 'parse_error',
        'message': 'Could not parse the expression. Use standard notation, e.g. "(15 + 3) * 2".',
        'detail': e.toString(),
      });
    }
  }
}
