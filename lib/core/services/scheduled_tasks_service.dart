import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_task.dart';
import '../database/business_preferences.dart';
import 'desktop_scheduled_tasks.dart';
import 'scheduled_task_store.dart';

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
  }) : _channel = channel ?? const MethodChannel('app.scheduled_tasks'),
       _desktop = desktop {
    if (desktop == null) {
      _channel.setMethodCallHandler(_handle);
    } else {
      desktop.addListener(_desktopChanged);
    }
  }
  static bool get supported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
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
  static void configureDesktop(BusinessPreferences preferences) {
    if (!supported || defaultTargetPlatform == TargetPlatform.android) return;
    _instance.dispose();
    _instance = ScheduledTasksService(
      desktop: DesktopScheduledTasks(store: ScheduledTaskStore(preferences)),
    );
  }

  final MethodChannel _channel;
  final DesktopScheduledTasks? _desktop;
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
      if (_desktop case final desktop?) {
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
            _desktop?.updateRun(id, {'conversationId': conversationId}) ??
            _channel.invokeMethod<void>('conversation', {
              'runId': id,
              'conversationId': conversationId,
            }),
      );
      result = await (isDesktop
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
      if (_desktop case final desktop?) {
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
      if (_desktop case final desktop?) {
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
    if (_desktop case final desktop?) {
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
    if (_desktop case final desktop?) {
      await desktop.delete(id);
      return;
    }
    _apply(
      (await _channel.invokeMapMethod<Object?, Object?>('delete', {'id': id}))!,
    );
  }

  Future<void> runNow(String id) async {
    if (_desktop case final desktop?) {
      await desktop.runNow(id);
      return;
    }
    _apply(
      (await _channel.invokeMapMethod<Object?, Object?>('runNow', {'id': id}))!,
    );
  }

  Future<void> requestPermission() async {
    if (!isDesktop) await _channel.invokeMethod<void>('permission');
  }
}
