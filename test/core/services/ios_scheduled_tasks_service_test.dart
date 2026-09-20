import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS management binds local persistence and notifications, never the desktop scheduler or Android channel',
    () async {
      final storage = await createBusinessTestHarness();
      final methods = <String>[];
      const notifications = MethodChannel('app.scheduled_notifications');
      const android = MethodChannel('app.scheduled_tasks');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(notifications, (call) async {
        methods.add(call.method);
        if (call.method == 'pending') return <String>[];
        return true;
      });
      messenger.setMockMethodCallHandler(android, (call) async {
        fail('Android method called on iOS: ${call.method}');
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        ScheduledTasksService.instance.dispose();
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(notifications, null);
        messenger.setMockMethodCallHandler(android, null);
      });
      ScheduledTasksService.configureDevice(storage.preferences);
      final service = ScheduledTasksService.instance;
      expect(ScheduledTasksService.supported, isTrue);
      expect(service.isIOS, isTrue);
      expect(service.isDesktop, isFalse);
      await service.refresh();
      expect(service.loaded, isTrue);
      expect(service.error, isNull);
      expect(methods, ['pending']);
    },
  );
}
