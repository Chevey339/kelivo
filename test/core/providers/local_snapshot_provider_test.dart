import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/local_snapshot_provider.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_service.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_settings.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_store.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalSnapshotProvider', () {
    late Directory root;
    late AppDatabase database;
    late BusinessPreferences businessPreferences;
    late LocalSnapshotPreferences snapshotPreferences;
    Object? packError;
    var packCount = 0;

    Future<PreparedBackupArchive> buildArchive({
      BackupProgressSink? onProgress,
      BackupCancelToken? cancelToken,
    }) async {
      packCount++;
      final error = packError;
      if (error != null) throw error;
      final file = File(
        p.join(root.path, 'packed_${DateTime.now().microsecondsSinceEpoch}'),
      );
      await file.writeAsString('archive');
      return (
        file: file,
        info: (
          schemaVersion: AppDatabase.currentSchemaVersion,
          conversationCount: 1,
          messageCount: 9,
        ),
        appVersion: '1.2.4+1',
      );
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_snapshot_provider_');
      database = AppDatabase(NativeDatabase.memory());
      businessPreferences = BusinessPreferences(BusinessRepository(database));
      await businessPreferences.load();
      snapshotPreferences = LocalSnapshotPreferences(businessPreferences);
      packError = null;
      packCount = 0;
    });

    tearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    LocalSnapshotProvider build() => LocalSnapshotProvider(
      appDataDirectory: root,
      chatService: ChatService(),
      businessRepository: BusinessRepository(database),
      businessPreferences: businessPreferences,
      autoLoad: false,
      debugBuildArchive: buildArchive,
    );

    test('手动备份失败会被记录，转到后台也留得下痕迹', () async {
      // 用户点了"转到后台继续"之后，弹窗已经卸载，异步错误只被用于释放资源。
      // 不记的话用户只看到"正在后台备份"，之后既无成功也无失败。
      packError = StateError('device is full');
      final vm = build();

      await expectLater(vm.takeNow(), throwsA(isA<StateError>()));

      final state = snapshotPreferences.readState();
      expect(state.failureStreak, 1);
      expect(state.lastFailureMessage, contains('device is full'));
    });

    test('用户主动取消不算失败', () async {
      packError = const BackupCancelledException();
      final vm = build();

      await expectLater(vm.takeNow(), throwsA(isA<BackupCancelledException>()));

      expect(snapshotPreferences.readState().failureStreak, 0);
      expect(snapshotPreferences.readState().lastFailureMessage, isNull);
    });

    test('正在恢复副本时，定时任务让路而不是去剪枝', () async {
      final vm = build();
      await vm.takeNow();
      expect(packCount, 1);

      // 模拟恢复期间：副本正被按路径读取。
      final gate = Completer<void>();
      final holding = vm.whileHoldingCopies(() => gate.future);

      final result = await vm.runIfDue();
      expect(result, isA<LocalSnapshotSkipped>());
      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.busy,
      );
      expect(packCount, 1);

      gate.complete();
      await holding;
    });

    test('恢复前那份副本可以取消保留', () async {
      final vm = build();
      final entry = await vm.takeNow(
        origin: LocalSnapshotOrigin.beforeRestore,
        pinned: true,
        prune: false,
      );
      await vm.refresh();
      expect(vm.copies.single.pinned, isTrue);

      await vm.setPinned(vm.copies.single, false);

      expect(vm.copies.single.pinned, isFalse);
      expect(entry.origin, LocalSnapshotOrigin.beforeRestore);
    });
  });
}
