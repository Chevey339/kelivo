import 'dart:io' show File, Platform;
import 'dart:math' as math;
import 'dart:ui' show IsolateNameServer;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../../utils/app_directories.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../models/assistant.dart';
import 'logging/flutter_logger.dart';
import 'notification_service.dart';
import 'proactive_care_message_flow.dart';

/// Name of the main-isolate port that handles proactive care triggers while
/// the app process is alive. Registered by HomePageController on Android;
/// the alarm background isolate forwards the assistantId to it.
const String proactiveCareMainPortName = 'kelivo_proactive_care_main_port';

// User-visible only in the first-run edge where no l10n snapshot was saved
// yet (the snapshot is written on every app start, before any alarm can be
// scheduled through the UI).
const String _failureBodyFallback =
    'Failed to generate the proactive care message. Open Kelivo for details.';
const String _conversationTitleFallback = 'New Chat';

/// Background entrypoint invoked by android_alarm_manager_plus when a
/// proactive care alarm fires. It runs in a dedicated background isolate and
/// wakes the app whether it is in foreground, background, or killed.
@pragma('vm:entry-point')
Future<void> proactiveCareAlarmCallback(
  int id,
  Map<String, dynamic> params,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final assistantId = params['assistantId'] as String?;
  debugPrint('[ProactiveCare] Alarm fired (id=$id, assistantId=$assistantId)');
  if (assistantId == null || assistantId.isEmpty) return;

  // App alive (foreground or background): the main isolate owns the Hive
  // boxes and the provider stack, so hand the trigger over and let it run
  // the full pipeline.
  if (_forwardToMainIsolate(assistantId)) return;

  final assistant = await ProactiveCareMessageFlow.loadAssistantFromPrefs(
    assistantId,
  );
  if (assistant == null) {
    debugPrint('[ProactiveCare] Assistant $assistantId not found, skipping');
    return;
  }
  // The alarm and the toggle live in different processes, so a stale alarm
  // may still fire after the feature was switched off. Re-check here.
  if (!assistant.enableProactiveCare) {
    debugPrint(
      '[ProactiveCare] Proactive care disabled for $assistantId, skipping',
    );
    return;
  }

  await _runHeadlessCareFlow(assistant, id);
}

bool _forwardToMainIsolate(String assistantId) {
  final port = IsolateNameServer.lookupPortByName(proactiveCareMainPortName);
  if (port == null) return false;
  debugPrint('[ProactiveCare] App alive, forwarding $assistantId to main');
  port.send(assistantId);
  return true;
}

/// Killed-process path: builds the full context from SharedPreferences and
/// Hive, requests the care reply, appends it to the assistant's most recent
/// conversation, shows the notification, and asks the model for the next
/// care time to re-schedule the alarm.
Future<void> _runHeadlessCareFlow(Assistant assistant, int alarmId) async {
  final snapshot = await ProactiveCareL10nSnapshot.load();
  final failureBody = (snapshot?.failureNotificationBody.isNotEmpty ?? false)
      ? snapshot!.failureNotificationBody
      : _failureBodyFallback;

  String body;
  try {
    final modelCfg = await ProactiveCareMessageFlow.loadModelConfigFromPrefs(
      assistant,
    );
    if (modelCfg == null) {
      throw StateError('no chat model configured');
    }

    // Narrow the race where the user launches the app while this isolate is
    // running: re-check the main port right before touching Hive.
    if (_forwardToMainIsolate(assistant.id)) return;

    final recent =
        await ProactiveCareHeadlessChatStore.loadRecentConversationFor(
          assistant.id,
        );
    final history = recent.conversation == null
        ? const <Map<String, dynamic>>[]
        : ProactiveCareMessageFlow.buildHistory(
            conversation: recent.conversation!,
            messages: recent.messages,
          );

    final carePrompt = assistant.proactiveCarePrompt.trim().isNotEmpty
        ? assistant.proactiveCarePrompt
        : (snapshot?.carePromptDefault ?? '');
    final apiMessages = await ProactiveCareMessageFlow.buildCareApiMessages(
      assistant: assistant,
      userNickname: await ProactiveCareMessageFlow.loadUserNicknameFromPrefs(),
      modelId: modelCfg.modelId,
      history: history,
      carePrompt: carePrompt,
      now: DateTime.now(),
    );

    final reply = await ProactiveCareMessageFlow.requestCareReply(
      config: modelCfg.config,
      modelId: modelCfg.modelId,
      assistant: assistant,
      apiMessages: apiMessages,
    );
    if (reply.isEmpty) {
      throw StateError('model returned an empty proactive care reply');
    }

    await ProactiveCareHeadlessChatStore.appendAssistantReply(
      assistantId: assistant.id,
      conversation: recent.conversation,
      content: reply,
      fallbackTitle: (snapshot?.defaultConversationTitle.isNotEmpty ?? false)
          ? snapshot!.defaultConversationTitle
          : _conversationTitleFallback,
      modelId: modelCfg.modelId,
      providerId: modelCfg.providerKey,
    );
    body = reply;

    // Ask the assistant for the next care time (continuous care). A failure
    // here must not hide the reply that was already produced.
    try {
      final decisionPrompt =
          assistant.proactiveCareDecisionPrompt.trim().isNotEmpty
          ? assistant.proactiveCareDecisionPrompt
          : (snapshot?.decisionPromptDefault ?? '');
      final newTime = await ProactiveCareMessageFlow.decideNextCareTime(
        config: modelCfg.config,
        modelId: modelCfg.modelId,
        assistant: assistant,
        userNickname:
            await ProactiveCareMessageFlow.loadUserNicknameFromPrefs(),
        history: <Map<String, dynamic>>[
          ...history,
          {'role': 'assistant', 'content': reply},
        ],
        decisionPrompt: decisionPrompt,
      );
      if (newTime != null) {
        final persisted =
            await ProactiveCareMessageFlow.updateAssistantNextCareTimeInPrefs(
              assistant.id,
              newTime,
            );
        if (persisted) {
          await ProactiveCareAlarmService.initialize();
          await ProactiveCareAlarmService.sync(
            assistant.copyWith(proactiveCareNextMessageAt: newTime),
          );
        }
      }
    } catch (e) {
      debugPrint('[ProactiveCare] Next-time decision failed: $e');
    }
  } catch (e) {
    debugPrint('[ProactiveCare] Headless care flow failed: $e');
    body = failureBody;
  } finally {
    await ProactiveCareHeadlessChatStore.close();
  }

  final iconPath = await resolveProactiveCareNotificationIconPath(
    assistant,
    alarmId,
  );
  try {
    await NotificationService.showProactiveCare(
      id: alarmId,
      title: assistant.name,
      body: body,
      largeIconPath: iconPath,
    );
    debugPrint(
      '[ProactiveCare] Notification shown for ${assistant.id} '
      '(icon=${iconPath ?? 'none'})',
    );
  } catch (e) {
    debugPrint('[ProactiveCare] Failed to show notification: $e');
  }
}

/// Resolves the assistant avatar to a local PNG usable as the notification
/// large icon. Returns null for emoji/initial avatars or on failure (the
/// notification then falls back to the app's default icon).
Future<String?> resolveProactiveCareNotificationIconPath(
  Assistant assistant,
  int alarmId,
) async {
  final avatar = assistant.avatar?.trim() ?? '';
  if (avatar.isEmpty) return null;

  String? sourcePath;
  try {
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      sourcePath = await AvatarCache.getPath(avatar);
    } else if (avatar.startsWith('/') || avatar.contains(':')) {
      await SandboxPathResolver.init();
      final fixed = SandboxPathResolver.fix(avatar);
      if (File(fixed).existsSync()) sourcePath = fixed;
    } else {
      // Emoji or initial-letter avatar: no bitmap to show.
      return null;
    }
  } catch (e) {
    debugPrint('[ProactiveCare] Avatar resolve failed: $e');
    return null;
  }
  if (sourcePath == null) {
    debugPrint('[ProactiveCare] Avatar file unavailable for $avatar');
    return null;
  }

  try {
    final bytes = await File(sourcePath).readAsBytes();
    final png = cropAvatarForNotification(bytes);
    if (png == null) {
      debugPrint('[ProactiveCare] Avatar decode failed for $sourcePath');
      return null;
    }
    final dir = await AppDirectories.getCacheDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final out = File('${dir.path}/proactive_care_icon_$alarmId.png');
    await out.writeAsBytes(png, flush: true);
    return out.path;
  } catch (e) {
    debugPrint('[ProactiveCare] Avatar crop failed: $e');
    return null;
  }
}

/// Center-crops [bytes] to a square (no stretching), resizes it down to at
/// most [maxSize] px, applies a circular mask, and returns the PNG bytes.
/// Returns null when the input cannot be decoded as an image.
@visibleForTesting
Uint8List? cropAvatarForNotification(Uint8List bytes, {int maxSize = 256}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // image 4.x can throw (e.g. RangeError in format probing) on corrupt
    // bytes instead of returning null; treat both as "not decodable".
    return null;
  }
  if (decoded == null) return null;
  final side = math.min(decoded.width, decoded.height);
  var square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  if (side > maxSize) {
    square = img.copyResize(
      square,
      width: maxSize,
      height: maxSize,
      interpolation: img.Interpolation.average,
    );
  }
  // Circular mask needs an alpha channel for the transparent corners.
  final circled = img.copyCropCircle(square.convert(numChannels: 4));
  return img.encodePng(circled);
}

/// Result of the proactive care permission check on Android.
typedef ProactiveCarePermissions = ({bool exactAlarm, bool notifications});

/// Schedules Android exact alarms ("setExactAndAllowWhileIdle") that wake the
/// app when an assistant's proactive care time arrives.
///
/// All methods are no-ops on non-Android platforms.
class ProactiveCareAlarmService {
  const ProactiveCareAlarmService._();

  static const String _logTag = 'ProactiveCareAlarm';

  /// Whether proactive care (exact alarms + wake-up) is available on this device.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static bool get _isAndroid => isSupported;

  /// Starts the AlarmManager service. Must be called once before scheduling
  /// alarms (done in `main()` before `runApp`).
  static Future<void> initialize() async {
    if (!_isAndroid) return;
    try {
      final ok = await AndroidAlarmManager.initialize();
      if (!ok) {
        FlutterLogger.log(
          'AndroidAlarmManager.initialize returned false',
          tag: _logTag,
        );
      }
    } catch (e) {
      FlutterLogger.log('AlarmManager initialize failed: $e', tag: _logTag);
    }
  }

  /// Derives a stable 31-bit positive alarm id from [assistantId] using
  /// FNV-1a. `String.hashCode` is not guaranteed to be stable across runs,
  /// while the id must stay identical to cancel/replace a pending alarm.
  static int alarmIdFor(String assistantId) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5; // FNV offset basis
    for (final unit in assistantId.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Schedules or cancels the exact alarm so it matches the assistant's
  /// proactive care settings.
  static Future<void> sync(Assistant assistant) async {
    if (!_isAndroid) return;
    final at = assistant.proactiveCareNextMessageAt;
    final id = alarmIdFor(assistant.id);
    try {
      if (!assistant.enableProactiveCare ||
          at == null ||
          !at.isAfter(DateTime.now())) {
        await AndroidAlarmManager.cancel(id);
        return;
      }
      final ok = await AndroidAlarmManager.oneShotAt(
        at,
        id,
        proactiveCareAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
        params: <String, dynamic>{'assistantId': assistant.id},
      );
      FlutterLogger.log(
        'Alarm ${ok ? 'scheduled' : 'schedule FAILED'} for assistant '
        '${assistant.id} at ${at.toIso8601String()} (id=$id)',
        tag: _logTag,
      );
    } catch (e) {
      FlutterLogger.log(
        'Alarm sync failed for assistant ${assistant.id}: $e',
        tag: _logTag,
      );
    }
  }

  /// Cancels the pending alarm for [assistantId], if any.
  static Future<void> cancelFor(String assistantId) async {
    if (!_isAndroid) return;
    try {
      await AndroidAlarmManager.cancel(alarmIdFor(assistantId));
    } catch (e) {
      FlutterLogger.log(
        'Alarm cancel failed for assistant $assistantId: $e',
        tag: _logTag,
      );
    }
  }

  /// Ensures the exact alarm permission (Android 12+) and the notification
  /// permission (Android 13+) are granted, requesting them when missing.
  /// Requesting the exact alarm permission opens the system
  /// "Alarms & reminders" settings page.
  static Future<ProactiveCarePermissions> ensurePermissions() async {
    if (!_isAndroid) return (exactAlarm: true, notifications: true);

    bool exactAlarm;
    try {
      var status = await Permission.scheduleExactAlarm.status;
      if (!status.isGranted) {
        status = await Permission.scheduleExactAlarm.request();
      }
      exactAlarm = status.isGranted;
    } catch (e) {
      FlutterLogger.log(
        'Exact alarm permission request failed: $e',
        tag: _logTag,
      );
      exactAlarm = false;
    }

    final notifications =
        await NotificationService.ensureAndroidNotificationsPermission();

    return (exactAlarm: exactAlarm, notifications: notifications);
  }
}
