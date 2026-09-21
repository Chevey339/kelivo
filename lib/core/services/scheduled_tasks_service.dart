import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_task.dart';
import '../database/business_preferences.dart';
import 'desktop_scheduled_tasks.dart';
import 'scheduled_task_store.dart';
import 'prepared_scheduled_tasks.dart';
import 'scheduled_task_preparation.dart';
import 'scheduled_task_notifications.dart';
import 'notification_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

class ScheduledRunCancellation {
  bool cancelled = false;
  Future<void> Function()? onCancel;
  Future<void> cancel() async {
    cancelled = true;
    await onCancel?.call();
  }

  void check() {
    if (cancelled) throw StateError('cancelled');
  }
}

typedef ScheduledTaskExecutor =
    Future<Map<String, Object?>> Function(
      ScheduledTask task,
      ScheduledRunCancellation cancellation,
      Future<void> Function(String conversationId) onConversation,
    );

class ScheduledTasksService extends ChangeNotifier {
  ScheduledTasksService({
    MethodChannel? channel,
    DesktopScheduledTasks? desktop,
    PreparedScheduledTasks? prepared,
  }) : _channel = channel ?? const MethodChannel('app.scheduled_tasks'),
       _desktop = desktop,
       _prepared = prepared {
    if (prepared != null) {
      prepared.addListener(_preparedChanged);
    } else if (desktop == null) {
      _channel.setMethodCallHandler(_handle);
    } else {
      desktop.addListener(_desktopChanged);
    }
  }
  static bool get supported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.android ||
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };
  static ScheduledTasksService _instance = ScheduledTasksService();
  static ScheduledTasksService get instance => _instance;

  /// Bind the admitted database before mounting the app. Desktop task writes
  /// participate in the same restore fence and exit flush as other settings.
  static void configureDevice(BusinessPreferences preferences) {
    if (!supported || defaultTargetPlatform == TargetPlatform.android) return;
    _instance.dispose();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _instance = ScheduledTasksService(
        prepared: PreparedScheduledTasks(
          store: ScheduledTaskStore(preferences),
          notifications: IosScheduledTaskNotifications(
            reminderBody: () =>
                _instance.localizations.scheduledTasksReminderBody,
            resultBody: () => _instance.localizations.scheduledTasksResultBody,
          ),
        ),
      );
      return;
    }
    _instance = ScheduledTasksService(
      desktop: DesktopScheduledTasks(store: ScheduledTaskStore(preferences)),
    );
  }

  final MethodChannel _channel;
  final DesktopScheduledTasks? _desktop;
  final PreparedScheduledTasks? _prepared;
  bool get isIOS => _prepared != null;
  ScheduledTaskPreparationStatus? preparationStatus(ScheduledTask task) =>
      _prepared?.preparationStatus(task);

  Future<void> preparePendingTasks() async {
    try {
      await _prepared?.check(prepare: true);
    } catch (e) {
      _recordError(e);
    }
  }

  Future<ScheduledTaskPreparationStatus> prepareNow(String taskId) async {
    final prepared = _prepared;
    if (prepared == null) return ScheduledTaskPreparationStatus.disabled;
    return prepared.prepareNow(taskId);
  }

  AppLocalizations localizations = lookupAppLocalizations(const Locale('en'));
  StreamSubscription<String>? _scheduledTapSubscription;
  Future<void> configurePreparation(
    ScheduledTaskPreparation preparation,
  ) async {
    _prepared?.preparation = preparation;
  }

  Future<void> updateNotificationPrivacy(bool hideContent) async {
    final notifications = _prepared?.notifications;
    if (notifications is! IosScheduledTaskNotifications ||
        notifications.hideContent == hideContent) {
      return;
    }
    notifications.hideContent = hideContent;
    try {
      await _prepared?.check(retryNotifications: true);
    } catch (e) {
      _recordError(e);
    }
  }

  Future<void> reconcileBeforeSend() => _prepared?.check() ?? Future.value();
  Future<void> activityChanged() async {
    try {
      await _prepared?.activityChanged();
    } catch (e) {
      _recordError(e);
    }
  }

  Future<void> lifecycle(bool active) async {
    try {
      await _prepared?.lifecycle(active);
    } catch (e) {
      _recordError(e);
    }
  }

  Future<void> _openScheduledRun(String id) async {
    try {
      final conversationId = await _prepared?.notificationTapped(id);
      if (conversationId != null) {
        NotificationService.openConversation(
          conversationId,
          messageId: '$id:result',
        );
      }
    } catch (e) {
      _recordError(e);
    }
  }

  void _preparedChanged() {
    if (_disposed) return;
    tasks = _prepared!.tasks;
    loaded = _prepared.loaded;
    error = _prepared.error;
    exactAlarms = true;
    notifyListeners();
  }

  bool get isDesktop => _desktop != null;
  ScheduledTaskExecutor? _executor;
  final _active = <String, ScheduledRunCancellation>{};
  List<ScheduledTask> tasks = const [];
  bool exactAlarms = false;
  bool loaded = false;
  String? error;
  bool _disposed = false;

  Future<void> attach(ScheduledTaskExecutor executor) async {
    _executor = executor;
    try {
      if (_prepared case final prepared?) {
        await NotificationService.ensureInitialized();
        await prepared.start((id, task) {
          final cancellation = ScheduledRunCancellation();
          _active[id] = cancellation;
          unawaited(_execute(id, task, cancellation));
        });
        await _scheduledTapSubscription?.cancel();
        _scheduledTapSubscription = NotificationService.scheduledRunTaps.listen(
          (id) => unawaited(_openScheduledRun(id)),
        );
        final pending = NotificationService.takePendingScheduledRunId();
        if (pending != null) unawaited(_openScheduledRun(pending));
      } else if (_desktop case final desktop?) {
        await desktop.start((id, task) {
          final cancellation = ScheduledRunCancellation();
          _active[id] = cancellation;
          unawaited(_execute(id, task, cancellation));
        });
      } else {
        await _channel.invokeMethod<void>('ready');
      }
      await refresh();
    } catch (e) {
      _recordError(e);
    }
  }

  void detach(ScheduledTaskExecutor executor) {
    if (!identical(_executor, executor)) return;
    _executor = null;
    _desktop?.stop();
    _prepared?.stop();
    unawaited(_scheduledTapSubscription?.cancel());
    for (final cancellation in _active.values.toList()) {
      unawaited(cancellation.cancel().catchError(_recordError));
    }
  }

  void _desktopChanged() {
    if (_disposed) return;
    final desktop = _desktop!;
    tasks = desktop.tasks;
    exactAlarms = true;
    loaded = desktop.loaded;
    error = desktop.error;
    notifyListeners();
  }

  Future<void> _handle(MethodCall call) async {
    switch (call.method) {
      case 'changed':
        await refresh();
      case 'run':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final id = args['runId'] as String;
        if (_active.containsKey(id)) return;
        final cancellation = ScheduledRunCancellation();
        _active[id] = cancellation;
        unawaited(
          _execute(
            id,
            ScheduledTask.fromJson(
              jsonDecode(args['task'] as String) as Map<String, dynamic>,
            ),
            cancellation,
          ),
        );
      case 'cancel':
        await _active[call.arguments]?.cancel();
    }
  }

  Future<void> _execute(
    String id,
    ScheduledTask task,
    ScheduledRunCancellation cancellation,
  ) async {
    Map<String, Object?> result;
    try {
      final executor = _executor;
      cancellation.check();
      if (executor == null) throw StateError('runner_not_ready');
      final execution = executor(
        task,
        cancellation,
        (conversationId) =>
            _prepared?.updateRun(id, {'conversationId': conversationId}) ??
            _desktop?.updateRun(id, {'conversationId': conversationId}) ??
            _channel.invokeMethod<void>('conversation', {
              'runId': id,
              'conversationId': conversationId,
            }),
      );
      result = await (isDesktop || isIOS
          ? execution.timeout(
              const Duration(minutes: 10),
              onTimeout: () {
                throw TimeoutException('execution_timeout');
              },
            )
          : execution);
    } catch (e) {
      try {
        await cancellation.cancel();
      } catch (_) {
        // Still report the original execution failure if cleanup also fails.
      }
      result = {'status': 'failed', 'error': e.toString()};
    }
    try {
      if (_prepared case final prepared?) {
        await prepared.updateRun(id, result);
      } else if (_desktop case final desktop?) {
        await desktop.updateRun(id, result);
      } else {
        await _channel.invokeMethod<void>('finish', {'runId': id, ...result});
      }
    } catch (e) {
      _recordError(e);
    } finally {
      _active.remove(id);
      await refresh();
    }
  }

  void _apply(Map<Object?, Object?> data) {
    if (_disposed) return;
    tasks = (data['tasks'] as List)
        .map(
          (raw) => ScheduledTask.fromJson(
            jsonDecode(raw as String) as Map<String, dynamic>,
          ),
        )
        .toList();
    exactAlarms = data['exactAlarms'] == true;
    loaded = true;
    error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      if (_prepared case final prepared?) {
        await prepared.load();
        _preparedChanged();
      } else if (_desktop case final desktop?) {
        await desktop.load();
        _desktopChanged();
      } else {
        _apply((await _channel.invokeMapMethod<Object?, Object?>('list'))!);
      }
    } catch (e) {
      _recordError(e);
    }
  }

  void _recordError(Object e) {
    if (_disposed) return;
    error = e.toString();
    loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_scheduledTapSubscription?.cancel());
    if (_prepared case final prepared?) {
      prepared.removeListener(_preparedChanged);
      prepared.dispose();
      for (final cancellation in _active.values.toList()) {
        unawaited(cancellation.cancel().catchError(_recordError));
      }
    } else if (_desktop case final desktop?) {
      desktop.removeListener(_desktopChanged);
      desktop.dispose();
      for (final cancellation in _active.values.toList()) {
        unawaited(cancellation.cancel().catchError(_recordError));
      }
    } else {
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  Future<void> save(ScheduledTask task, {bool? enabled}) async {
    if (_prepared case final prepared?) {
      await prepared.save(task, enabled: enabled);
      return;
    }
    if (_desktop case final desktop?) {
      await desktop.save(task, enabled: enabled);
      return;
    }
    _apply(
      (await _channel.invokeMapMethod<Object?, Object?>(
        'save',
        task.toJson(enabled: enabled),
      ))!,
    );
  }

  Future<void> delete(String id) async {
    if (_prepared case final prepared?) {
      await prepared.delete(id);
      return;
    }
    if (_desktop case final desktop?) {
      await desktop.delete(id);
      return;
    }
    _apply(
      (await _channel.invokeMapMethod<Object?, Object?>('delete', {'id': id}))!,
    );
  }

  Future<void> runNow(String id) async {
    if (_prepared case final prepared?) {
      await prepared.runNow(id);
      return;
    }
    if (_desktop case final desktop?) {
      await desktop.runNow(id);
      return;
    }
    _apply(
      (await _channel.invokeMapMethod<Object?, Object?>('runNow', {'id': id}))!,
    );
  }

  Future<void> requestPermission() async {
    if (_prepared case final prepared?) {
      await prepared.notifications.requestPermission();
      // Permission changes refresh delivery without starting automatic work or
      // changing lifecycle state ahead of an explicit preparation request.
      await prepared.check(retryNotifications: true);
    } else if (!isDesktop) {
      await _channel.invokeMethod<void>('permission');
    }
  }
}
