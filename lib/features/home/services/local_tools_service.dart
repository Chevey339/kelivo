import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/health_data_type.dart';

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
  static const String currentLocation = 'get_current_location';
  static const String weather = 'get_weather';
  static const String healthSummary = 'get_health_summary';
  static const String remindersQuery = 'reminders_query';
  static const String remindersCreate = 'reminders_create';
  static const String remindersComplete = 'reminders_complete';

  static const List<String> all = [
    timeInfo,
    clipboard,
    textToSpeech,
    askUser,
    calculate,
    screenTime,
    calendarQuery,
    calendarCreate,
    currentLocation,
    weather,
    healthSummary,
    remindersQuery,
    remindersCreate,
    remindersComplete,
  ];

  static const List<String> requiresUserApproval = [
    calendarCreate,
    remindersCreate,
    remindersComplete,
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

  static bool get iosDeviceToolsSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get locationSupported => iosDeviceToolsSupported;

  /// WeatherKit is iOS 16+. Defaults false until [prefetchIosCapabilities].
  static bool? _weatherKitAvailable;

  /// HealthKit may be absent on older iPads. Defaults false until prefetch.
  static bool? _healthDataAvailable;
  static List<String>? _availableHealthTypeIds;
  static Future<bool>? _prefetchFuture;
  static int _capabilityEpoch = 0;

  static bool get weatherSupported =>
      iosDeviceToolsSupported && (_weatherKitAvailable ?? false);

  static bool get healthSupported =>
      iosDeviceToolsSupported && (_healthDataAvailable ?? false);

  /// HealthKit type IDs the current OS can query. Until prefetch finishes,
  /// version-gated types (daylight) are omitted.
  static List<String> get availableHealthTypeIds {
    if (!iosDeviceToolsSupported) return const [];
    return List<String>.unmodifiable(
      _availableHealthTypeIds ?? HealthDataTypeIds.withoutOsVersionGate,
    );
  }

  static bool get remindersSupported => iosDeviceToolsSupported;

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

  static Future<bool> hasLocationPermission() async {
    if (!locationSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasLocationPermission');
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestLocationPermission() async {
    if (!locationSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestLocationPermission',
      );
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> hasRemindersPermission() async {
    if (!remindersSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'hasRemindersPermission',
      );
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestRemindersPermission() async {
    if (!remindersSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestRemindersPermission',
      );
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Warms WeatherKit and HealthKit availability caches used by the sync
  /// [weatherSupported] / [healthSupported] getters.
  static Future<bool> prefetchIosCapabilities() {
    final existing = _prefetchFuture;
    if (existing != null) return existing;
    final epoch = _capabilityEpoch;
    final future = _queryIosCapabilities(epoch);
    _prefetchFuture = future;
    return future;
  }

  static Future<bool> _queryIosCapabilities(int epoch) async {
    if (!iosDeviceToolsSupported) {
      if (epoch == _capabilityEpoch) {
        _weatherKitAvailable = false;
        _healthDataAvailable = false;
        _availableHealthTypeIds = const [];
      }
      return false;
    }
    final results = await Future.wait([
      _invokeCapabilityFlag('isWeatherKitAvailable'),
      _invokeCapabilityFlag('isHealthDataAvailable'),
    ]);
    final weatherAvailable = results[0];
    final healthAvailable = results[1];
    final typeIds = healthAvailable
        ? await _invokeHealthTypeIds()
        : const <String>[];
    if (epoch == _capabilityEpoch) {
      _weatherKitAvailable = weatherAvailable;
      _healthDataAvailable = healthAvailable;
      _availableHealthTypeIds = typeIds;
    }
    return _weatherKitAvailable ?? weatherAvailable;
  }

  static Future<bool> _invokeCapabilityFlag(String method) async {
    try {
      final result = await _channel.invokeMethod<bool>(method);
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<String>> _invokeHealthTypeIds() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'availableHealthTypes',
      );
      if (result == null) {
        return List<String>.from(HealthDataTypeIds.withoutOsVersionGate);
      }
      return HealthDataTypeIds.knownOnly(result.whereType<String>());
    } on MissingPluginException {
      return List<String>.from(HealthDataTypeIds.withoutOsVersionGate);
    } on PlatformException {
      return List<String>.from(HealthDataTypeIds.withoutOsVersionGate);
    }
  }

  @visibleForTesting
  static void debugResetIosCapabilities() {
    _capabilityEpoch++;
    _weatherKitAvailable = null;
    _healthDataAvailable = null;
    _availableHealthTypeIds = null;
    _prefetchFuture = null;
  }

  @visibleForTesting
  static void debugSetWeatherKitAvailable(bool? value) {
    _capabilityEpoch++;
    _weatherKitAvailable = value;
    _prefetchFuture = value == null ? null : Future<bool>.value(value);
  }

  @visibleForTesting
  static void debugSetHealthDataAvailable(bool? value) {
    _capabilityEpoch++;
    _healthDataAvailable = value;
    _availableHealthTypeIds = value == true
        ? List<String>.from(HealthDataTypeIds.all)
        : (value == false ? const <String>[] : null);
    _prefetchFuture = value == null
        ? null
        : Future<bool>.value(_weatherKitAvailable ?? false);
  }

  @visibleForTesting
  static void debugSetAvailableHealthTypeIds(List<String>? ids) {
    _availableHealthTypeIds = ids == null
        ? null
        : HealthDataTypeIds.knownOnly(ids);
  }

  /// Presents the HealthKit read sheet for [types] only. The returned flag is
  /// only that the request completed; iOS does not reveal per-type read grants.
  static Future<bool> requestHealthPermission({
    List<String> types = const [],
  }) async {
    if (!healthSupported) return false;
    final filtered = HealthDataTypeIds.intersectAvailable(
      types,
      availableHealthTypeIds,
    );
    if (filtered.isEmpty) return true;
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestHealthPermission',
        jsonEncode({'types': filtered}),
      );
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the iOS Settings page for this app (Health read access is managed
  /// there / in the Health app).
  static Future<void> openAppSettings() async {
    if (!iosDeviceToolsSupported) return;
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // Unsupported host.
    } on PlatformException {
      // Settings unavailable.
    }
  }
}

class LocalToolsService {
  const LocalToolsService._();

  /// Whether this local tool is offered on the current platform, matching the
  /// assistant "Local tools" tab.
  static bool isAvailableOnThisPlatform(String name) {
    switch (name) {
      case LocalToolNames.screenTime:
        return DeviceLocalTools.screenTimeSupported;
      case LocalToolNames.calendarQuery:
      case LocalToolNames.calendarCreate:
        return DeviceLocalTools.calendarSupported;
      case LocalToolNames.currentLocation:
        return DeviceLocalTools.locationSupported;
      case LocalToolNames.weather:
        return DeviceLocalTools.weatherSupported;
      case LocalToolNames.healthSummary:
        return DeviceLocalTools.healthSupported;
      case LocalToolNames.remindersQuery:
      case LocalToolNames.remindersCreate:
      case LocalToolNames.remindersComplete:
        return DeviceLocalTools.remindersSupported;
      default:
        return true;
    }
  }

  /// Default schemas keyed by tool name. Timezone-dependent descriptions are
  /// rebuilt on each read so they stay current.
  static Map<String, Map<String, dynamic>> get definitions => {
    for (final name in LocalToolNames.all) name: definitionFor(name),
  };

  static Map<String, dynamic> definitionFor(String name) {
    switch (name) {
      case LocalToolNames.timeInfo:
        return _timeInfoDefinition;
      case LocalToolNames.clipboard:
        return _clipboardDefinition;
      case LocalToolNames.textToSpeech:
        return _textToSpeechDefinition;
      case LocalToolNames.askUser:
        return _askUserDefinition;
      case LocalToolNames.calculate:
        return _calculateDefinition;
      case LocalToolNames.screenTime:
        return _screenTimeDefinition();
      case LocalToolNames.calendarQuery:
        return _calendarQueryDefinition();
      case LocalToolNames.calendarCreate:
        return _calendarCreateDefinition();
      case LocalToolNames.currentLocation:
        return _currentLocationDefinition;
      case LocalToolNames.weather:
        return _weatherDefinition();
      case LocalToolNames.healthSummary:
        return _healthSummaryDefinition();
      case LocalToolNames.remindersQuery:
        return _remindersQueryDefinition();
      case LocalToolNames.remindersCreate:
        return _remindersCreateDefinition();
      case LocalToolNames.remindersComplete:
        return _remindersCompleteDefinition;
      default:
        throw ArgumentError.value(name, 'name', 'Unknown local tool');
    }
  }

  static List<Map<String, dynamic>> buildToolDefinitions({
    required Assistant? assistant,
    required bool supportsTools,
  }) {
    if (!supportsTools || assistant == null) {
      return const <Map<String, dynamic>>[];
    }

    if (DeviceLocalTools.iosDeviceToolsSupported) {
      unawaited(DeviceLocalTools.prefetchIosCapabilities());
    }

    final tools = <Map<String, dynamic>>[];
    for (final id in LocalToolNames.all) {
      if (!assistant.localToolIds.contains(id)) continue;
      if (!isAvailableOnThisPlatform(id)) continue;
      if (id == LocalToolNames.healthSummary) {
        tools.add(
          _healthSummaryDefinition(
            HealthDataTypeIds.intersectAvailable(
              assistant.healthDataTypeIds,
              DeviceLocalTools.availableHealthTypeIds,
            ),
          ),
        );
      } else {
        tools.add(definitionFor(id));
      }
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
    if (name == LocalToolNames.currentLocation &&
        DeviceLocalTools.locationSupported) {
      return _invokeDeviceTool('getCurrentLocation', args);
    }
    if (name == LocalToolNames.weather &&
        DeviceLocalTools.iosDeviceToolsSupported) {
      await DeviceLocalTools.prefetchIosCapabilities();
      if (!DeviceLocalTools.weatherSupported) {
        return jsonEncode({
          'error': 'unsupported_os',
          'message': 'Weather requires iOS 16 or later.',
        });
      }
      return _invokeDeviceTool('getWeather', args);
    }
    if (name == LocalToolNames.healthSummary &&
        DeviceLocalTools.iosDeviceToolsSupported) {
      await DeviceLocalTools.prefetchIosCapabilities();
      if (!DeviceLocalTools.healthSupported) {
        return jsonEncode({
          'error': 'unsupported_os',
          'message': 'Health data is not available on this device.',
        });
      }
      // Always send the collaborator's configured types. Ignore any `types`
      // the model may have passed so unselected metrics cannot be queried.
      final types = HealthDataTypeIds.intersectAvailable(
        assistant.healthDataTypeIds,
        DeviceLocalTools.availableHealthTypeIds,
      );
      return _invokeDeviceTool('getHealthSummary', {'types': types});
    }
    if (name == LocalToolNames.remindersQuery &&
        DeviceLocalTools.remindersSupported) {
      return _invokeDeviceTool('queryReminders', args);
    }
    if (name == LocalToolNames.remindersCreate &&
        DeviceLocalTools.remindersSupported) {
      return _invokeDeviceTool('createReminder', args);
    }
    if (name == LocalToolNames.remindersComplete &&
        DeviceLocalTools.remindersSupported) {
      return _invokeDeviceTool('completeReminder', args);
    }
    return null;
  }

  static const MethodChannel _deviceToolsChannel = DeviceLocalTools._channel;

  static const Map<String, dynamic> _timeInfoDefinition = {
    'type': 'function',
    'function': {
      'name': LocalToolNames.timeInfo,
      'description':
          'Get the current local date and time info from the device. Returns year, month, day, weekday, ISO date and time strings, timezone, UTC offset, and timestamp.',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  };

  static const Map<String, dynamic> _clipboardDefinition = {
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
  };

  static const Map<String, dynamic> _textToSpeechDefinition = {
    'type': 'function',
    'function': {
      'name': LocalToolNames.textToSpeech,
      'description':
          'Speak text aloud to the user using the configured text-to-speech playback. Use this when the user asks you to read something aloud, or when audio output is appropriate. The tool returns after playback has been requested; audio may continue in the background. Provide natural, readable text without markdown formatting.',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': 'The text to speak aloud.'},
        },
        'required': ['text'],
      },
    },
  };

  static const Map<String, dynamic> _askUserDefinition = {
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
                  'description': 'Unique stable identifier for this question.',
                },
                'question': {
                  'type': 'string',
                  'description': 'The full question text shown to the user.',
                },
                'type': {
                  'type': 'string',
                  'enum': ['single', 'multi'],
                  'description': 'Answer type: single choice or multi choice.',
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
  };

  static const Map<String, dynamic> _calculateDefinition = {
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
  };

  static const Map<String, dynamic> _currentLocationDefinition = {
    'type': 'function',
    'function': {
      'name': LocalToolNames.currentLocation,
      'description':
          "Get the user's current location from the device (one-shot, When In Use). "
          'Returns latitude, longitude, accuracy in meters, timestamp, and optional '
          'city/region/country from reverse geocoding. Do not request this unless the '
          'user asked for their location or it is needed for weather. '
          'Requires the Location permission; if it is not granted, an error is returned.',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  };

  static Map<String, dynamic> _healthSummaryDefinition([
    List<String>? typeIds,
  ]) {
    final ids =
        typeIds ??
        HealthDataTypeIds.intersectAvailable(
          HealthDataTypeIds.defaultSelected,
          DeviceLocalTools.availableHealthTypeIds.isEmpty
              ? HealthDataTypeIds.defaultSelected
              : DeviceLocalTools.availableHealthTypeIds,
        );
    final labels = [for (final id in ids) HealthDataTypeIds.toolLabel(id)];
    final listed = labels.isEmpty ? 'none' : labels.join(', ');
    final sleepDescription = ids.contains(HealthDataTypeIds.sleep)
        ? ' Sleep covers the past 24 hours, including naps and daytime sleep. '
              'Asleep, in_bed, awake and each stage have separate recorded durations '
              'and merged intervals clipped to the query window. In-bed time is not '
              'actual sleep. Missing states are unavailable, not zero. Awake means '
              'recorded wakefulness within sleep tracking, not all waking time in '
              'the day. Stages from different sources may overlap; use asleep for '
              'the total instead of adding stages or states. A query_error means '
              'the query failed. Sleep schedules are not recorded sleep.'
        : '';
    final menstrualDescription = ids.contains(HealthDataTypeIds.menstrualFlow)
        ? ' Menstrual flow returns up to 180 recorded samples overlapping the past '
              '90 days, newest first, with original dates, flow, and cycle-start '
              'markers when available. A sample is not necessarily a whole period; '
              'multiple samples or sources may overlap. These are records, not '
              'predictions. Missing records do not mean no menstruation, and '
              'truncated means older records were omitted. A query_error means '
              'the query failed, not that no data exists.'
        : '';
    return {
      'type': 'function',
      'function': {
        'name': LocalToolNames.healthSummary,
        'description':
            'Get a privacy-preserving health activity summary from the device. '
            'Currently enabled metrics: $listed. '
            'Each metric includes its time interval. '
            'A metric with status "unavailable" means there is no authorized or recorded '
            'data — never treat unavailable as 0. Do not request metrics that are not in '
            'the enabled list. '
            'Requires Health access.$sleepDescription$menstrualDescription',
        'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
      },
    };
  }

  static const Map<String, dynamic> _remindersCompleteDefinition = {
    'type': 'function',
    'function': {
      'name': LocalToolNames.remindersComplete,
      'description':
          'Mark a reminder as completed. Requires the reminder id returned by '
          'reminders_query or reminders_create. The user will be asked to confirm '
          'before the reminder is updated. '
          'Requires the Reminders permission; if it is not granted, an error is returned.',
      'parameters': {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description':
                'Reminder id from reminders_query or reminders_create.',
          },
        },
        'required': ['id'],
      },
    },
  };

  static Map<String, dynamic> _screenTimeDefinition() => {
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
  };

  static Map<String, dynamic> _calendarQueryDefinition() => {
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
            'description': 'Maximum number of events to return. Default 20.',
          },
        },
      },
    },
  };

  static Map<String, dynamic> _calendarCreateDefinition() => {
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
            'description': 'Whether this is an all-day event. Default false.',
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
  };

  static Map<String, dynamic> _weatherDefinition() => {
    'type': 'function',
    'function': {
      'name': LocalToolNames.weather,
      'description':
          'Get current weather, hourly forecast, and daily forecast from Apple Weather. '
          'Omit coordinates to use the current device location; or pass latitude and '
          'longitude to query a specific place. '
          'Returns temperature, apparent temperature, precipitation chance, and forecasts. '
          'Always mention that weather data is from Apple Weather when presenting results. '
          '${_deviceTimezoneHint()} '
          'Requires Location permission when coordinates are omitted.',
      'parameters': {
        'type': 'object',
        'properties': {
          'latitude': {
            'type': 'number',
            'description':
                'Latitude in decimal degrees. Required together with longitude '
                'when querying a specific place.',
          },
          'longitude': {
            'type': 'number',
            'description':
                'Longitude in decimal degrees. Required together with latitude '
                'when querying a specific place.',
          },
        },
      },
    },
  };

  static Map<String, dynamic> _remindersQueryDefinition() => {
    'type': 'function',
    'function': {
      'name': LocalToolNames.remindersQuery,
      'description':
          "Query reminders on the user's device. Filter by date range, completion "
          'status, and an optional keyword. Reminders without a due date are included '
          'unless an explicit begin time is provided. '
          '${_deviceTimezoneHint()} '
          'Requires the Reminders permission; if it is not granted, an error is returned.',
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
          'completed': {
            'type': 'string',
            'enum': ['all', 'true', 'false'],
            'description':
                'Filter by completion: all, true (completed only), or false (incomplete only). Default all.',
          },
          'query': {
            'type': 'string',
            'description':
                'Optional keyword to filter reminders by title or notes (case-insensitive substring).',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of reminders to return. Default 20.',
          },
        },
      },
    },
  };

  static Map<String, dynamic> _remindersCreateDefinition() => {
    'type': 'function',
    'function': {
      'name': LocalToolNames.remindersCreate,
      'description':
          "Create a reminder on the user's device. Requires a title. "
          'The user will be asked to confirm before the reminder is created. '
          '${_deviceTimezoneHint()} '
          'Requires the Reminders permission; if it is not granted, an error is returned.',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Reminder title.'},
          'notes': {
            'type': 'string',
            'description': 'Optional notes or description.',
          },
          'due': {
            'type': 'string',
            'description':
                "Optional due time. Accepts an ISO-8601 date 'yyyy-MM-dd', a local "
                "date-time 'yyyy-MM-ddTHH:mm:ss', an offset date-time, or epoch milliseconds.",
          },
          'priority': {
            'type': 'string',
            'description':
                'Optional priority: none, high, medium, low, or an EventKit integer 0-9 '
                '(0 none, 1 high, 5 medium, 9 low).',
          },
        },
        'required': ['title'],
      },
    },
  };

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
