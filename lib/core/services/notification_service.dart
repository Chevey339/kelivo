import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'kelivo_bg_chat_v2',
    'Chat Background',
    description: 'Notifications for chat generation status',
    importance: Importance.high,
    playSound: true,
  );
  static const AndroidNotificationChannel _proactiveCareChannel =
      AndroidNotificationChannel(
        'kelivo_proactive_care',
        'Proactive Care',
        description: 'Proactive care messages from assistants',
        importance: Importance.high,
        playSound: true,
      );

  static Future<void> ensureInitialized() async {
    if (!Platform.isAndroid) return;
    if (_inited) return;

    // Android initialization
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings init = InitializationSettings(
      android: androidInit,
    );
    await _plugin.initialize(init);

    // Create channel
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(_channel);
      await android.createNotificationChannel(_proactiveCareChannel);
      // Runtime notification permission (Android 13+) should be requested by app UI if needed
    }
    _inited = true;
  }

  /// Ensure Android 13+ notifications permission is granted (no-op on lower versions/other platforms).
  static Future<bool> ensureAndroidNotificationsPermission() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    try {
      final enabled = await android.areNotificationsEnabled();
      if (enabled == true) return true;
    } catch (_) {}
    try {
      final ok = await android.requestNotificationsPermission();
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows a proactive care notification on behalf of an assistant.
  ///
  /// [id] should be stable per assistant (e.g. derived from the assistant id)
  /// so a newer notification replaces the previous one instead of piling up.
  /// [title] is the assistant name, [body] the message text (later the LLM
  /// reply), and [largeIconPath] an optional local image file shown as the
  /// notification's large icon.
  static Future<void> showProactiveCare({
    required int id,
    required String title,
    required String body,
    String? largeIconPath,
  }) async {
    if (!Platform.isAndroid) return;
    await ensureInitialized();
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _proactiveCareChannel.id,
          _proactiveCareChannel.name,
          channelDescription: _proactiveCareChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          ticker: 'Kelivo',
          largeIcon: largeIconPath == null
              ? null
              : FilePathAndroidBitmap(largeIconPath),
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  static Future<void> showChatCompleted({String? title, String? body}) async {
    if (!Platform.isAndroid) return;
    await ensureInitialized();
    await _plugin.show(
      2001, // id
      title ?? 'Generation complete',
      body ?? 'Assistant reply has been generated',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          ticker: 'Kelivo',
          styleInformation: const DefaultStyleInformation(true, true),
        ),
      ),
    );
  }
}
