import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_service.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_settings.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalSnapshotService', () {
    late Directory root;
    late AppDatabase database;
    late BusinessPreferences businessPreferences;
    late LocalSnapshotPreferences preferences;
    late File liveDatabase;
    var packCount = 0;
    Object? packError;
    var messageCount = 100;

    Future<void> Function()? duringPack;

    Future<PreparedBackupArchive> buildArchive({
      BackupProgressSink? onProgress,
      BackupCancelToken? cancelToken,
    }) async {
      packCount++;
      final error = packError;
      if (error != null) throw error;
      await duringPack?.call();
      final file = File(
        p.join(root.path, 'packed_${DateTime.now().microsecondsSinceEpoch}'),
      );
      await file.writeAsString('archive');
      return (
        file: file,
        info: (
          schemaVersion: AppDatabase.currentSchemaVersion,
          conversationCount: 4,
          messageCount: messageCount,
        ),
        appVersion: '1.2.4+1',
      );
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_snapshot_service_');
      database = AppDatabase(NativeDatabase.memory());
      businessPreferences = BusinessPreferences(BusinessRepository(database));
      await businessPreferences.load();
      preferences = LocalSnapshotPreferences(businessPreferences);
      liveDatabase = File(p.join(root.path, AppDatabase.databaseFileName));
      await liveDatabase.writeAsString('live database contents');
      packCount = 0;
      packError = null;
      messageCount = 100;
      duringPack = null;
      // The grace period is a first-run concern; every other test wants the
      // schedule to behave as it does on an install that has already settled.
      await preferences.recordFirstObserved(DateTime.utc(2020));
    });

    tearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    LocalSnapshotService build({
      LocalSnapshotBusyCheck? isBusy,
      Future<int?> Function()? freeBytes,
    }) => LocalSnapshotService(
      appDataDirectory: root,
      preferences: preferences,
      buildArchive: buildArchive,
      isBusy: isBusy,
      freeBytes: freeBytes ?? () async => null,
    );

    /// Forces the next run to see a database that has changed.
    Future<void> touchDatabase() async {
      await liveDatabase.writeAsString(
        'live database contents ${DateTime.now().microsecondsSinceEpoch}',
      );
    }

    test('升级后的第一次启动不立刻开跑，只是记下时间', () async {
      // 装了这个版本的所有用户都没有备份记录。若不给宽限期，每个人都会在
      // 更新后第一次启动的第 8 秒吃一次完整 vacuum + 打包——大库上就是几分钟。
      await businessPreferences.remove(
        LocalSnapshotPreferences.firstObservedAtKey,
      );
      final service = build();

      final first = await service.runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(
        (first as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.notDue,
      );
      expect(packCount, 0);
      expect(preferences.readState().firstObservedAt, isNotNull);

      // 宽限期内再检查也不动手。
      final second = await service.runIfDue(
        now: DateTime.utc(2026, 5, 1, 0, 5),
      );
      expect(
        (second as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.notDue,
      );
      expect(packCount, 0);

      // 过了就正常备份。
      final third = await service.runIfDue(now: DateTime.utc(2026, 5, 1, 1));
      expect(third, isA<LocalSnapshotCreated>());
      expect(packCount, 1);
    });

    test('宽限期只管第一次，之后按周期走', () async {
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));
      expect(packCount, 1);
      await touchDatabase();

      final result = await service.runIfDue(now: DateTime.utc(2026, 5, 2, 1));

      expect(result, isA<LocalSnapshotCreated>());
      expect(packCount, 2);
    });

    test('被占用时也把原因记下来', () async {
      await build(
        isBusy: () => LocalSnapshotSkipReason.generating,
      ).runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(
        preferences.readState().lastSkipReason,
        LocalSnapshotSkipReason.generating,
      );
    });

    test('首次运行就产一份副本', () async {
      final result = await build().runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(result, isA<LocalSnapshotCreated>());
      expect(packCount, 1);
      final entry = (result as LocalSnapshotCreated).entry;
      expect(entry.messageCount, 100);
      expect(entry.origin, LocalSnapshotOrigin.automatic);
      expect(await entry.file.exists(), isTrue);
    });

    test('未到周期不重复产', () async {
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));
      await touchDatabase();

      final result = await service.runIfDue(now: DateTime.utc(2026, 5, 1, 6));

      expect(result, isA<LocalSnapshotSkipped>());
      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.notDue,
      );
      expect(packCount, 1);
    });

    test('数据没变就整轮跳过，不做任何打包', () async {
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));

      final result = await service.runIfDue(now: DateTime.utc(2026, 5, 3));

      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.unchanged,
      );
      expect(packCount, 1);
    });

    test('跳过"没变"不推进上次成功时间，改动后立刻就能产', () async {
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));
      await service.runIfDue(now: DateTime.utc(2026, 5, 3));

      await touchDatabase();
      final result = await service.runIfDue(now: DateTime.utc(2026, 5, 3, 1));

      expect(result, isA<LocalSnapshotCreated>());
      expect(packCount, 2);
    });

    test('关闭后不跑', () async {
      await preferences.writeSettings(
        const LocalSnapshotSettings(enabled: false),
      );

      final result = await build().runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.disabled,
      );
      expect(packCount, 0);
    });

    test('正在生成时让路，不与用户抢 IO', () async {
      final result = await build(
        isBusy: () => LocalSnapshotSkipReason.generating,
      ).runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.generating,
      );
      expect(packCount, 0);
    });

    test('剩余空间不足时不动手', () async {
      final result = await build(
        freeBytes: () async => LocalSnapshotSchedule.freeSpaceFloor,
      ).runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.insufficientSpace,
      );
      expect(packCount, 0);
      expect(
        preferences.readState().lastSkipReason,
        LocalSnapshotSkipReason.insufficientSpace,
      );
    });

    test('探测不到剩余空间时照常进行', () async {
      final result = await build(
        freeBytes: () async => null,
      ).runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(result, isA<LocalSnapshotCreated>());
    });

    test('打包失败被记录下来，且不抛给调用方', () async {
      packError = StateError('disk on fire');

      final result = await build().runIfDue(now: DateTime.utc(2026, 5, 1));

      expect(result, isA<LocalSnapshotFailed>());
      final state = preferences.readState();
      expect(state.failureStreak, 1);
      expect(state.lastFailureMessage, contains('disk on fire'));
      expect(state.lastSuccessAt, isNull);
    });

    test('连续失败退避越来越久，不是每次 resume 都白跑', () async {
      packError = StateError('nope');
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));

      // 一小时内不重试。
      var result = await service.runIfDue(now: DateTime.utc(2026, 5, 1, 0, 30));
      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.backoff,
      );
      expect(packCount, 1);

      // 退避窗口过后重试，再失败一次窗口翻倍。
      result = await service.runIfDue(now: DateTime.utc(2026, 5, 1, 2));
      expect(result, isA<LocalSnapshotFailed>());
      expect(preferences.readState().failureStreak, 2);

      result = await service.runIfDue(now: DateTime.utc(2026, 5, 1, 3, 30));
      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.backoff,
      );
    });

    test('成功后清空失败计数', () async {
      packError = StateError('nope');
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));
      packError = null;

      await service.runIfDue(now: DateTime.utc(2026, 5, 1, 2));

      final state = preferences.readState();
      expect(state.failureStreak, 0);
      expect(state.lastFailureAt, isNull);
      expect(state.lastSuccessAt, isNotNull);
    });

    test('产完顺带按策略清理，但不碰最新一份有内容的', () async {
      await preferences.writeSettings(
        const LocalSnapshotSettings(
          keepRecent: 1,
          keepWeekly: false,
          keepMonthly: false,
        ),
      );
      final service = build();

      await service.runIfDue(now: DateTime.utc(2026, 5, 1));
      await touchDatabase();
      await service.runIfDue(now: DateTime.utc(2026, 5, 3));
      await touchDatabase();
      messageCount = 0;
      final result = await service.runIfDue(now: DateTime.utc(2026, 5, 5));

      expect(result, isA<LocalSnapshotCreated>());
      final remaining = await service.store.list();
      // 最新的那份是空的，所以最后一份有内容的必须留着。
      expect(remaining, hasLength(2));
      expect(remaining.first.messageCount, 0);
      expect(remaining.last.messageCount, greaterThan(0));
    });

    test('大库默认拉长周期', () async {
      expect(
        LocalSnapshotSchedule.defaultIntervalFor(10 * 1024 * 1024),
        const Duration(days: 1),
      );
      expect(
        LocalSnapshotSchedule.defaultIntervalFor(500 * 1024 * 1024),
        const Duration(days: 3),
      );
      expect(
        LocalSnapshotSchedule.defaultIntervalFor(2 * 1024 * 1024 * 1024),
        const Duration(days: 7),
      );
    });

    test('用户设定的周期覆盖自适应默认值', () async {
      await preferences.writeSettings(
        const LocalSnapshotSettings(intervalDays: 7),
      );
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));
      await touchDatabase();

      final result = await service.runIfDue(now: DateTime.utc(2026, 5, 4));

      expect(
        (result as LocalSnapshotSkipped).reason,
        LocalSnapshotSkipReason.notDue,
      );
    });

    test('备份进行当中写入的数据，下一轮仍会被当作有改动', () async {
      // 记录的指纹必须描述"这份副本装的是哪个状态"，也就是备份开始之前那个。
      // 若记成备份结束后的状态，备份进行期间写进去的数据会被"没变化"这道闸
      // 永远挡在外面——除非之后又恰好有别的改动，否则再也不会被备份到。
      final service = build();
      duringPack = touchDatabase;
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));
      expect(packCount, 1);
      duringPack = null;

      final result = await service.runIfDue(now: DateTime.utc(2026, 5, 3));

      expect(result, isA<LocalSnapshotCreated>());
      expect(packCount, 2);
    });

    test('手动备份失败也要留下记录，否则转后台失败就无声无息', () async {
      // 转到后台之后弹窗已经卸载，异步错误被消费掉只用于释放资源。
      // 若这里不记，用户只会看到"正在后台备份"，然后再无下文。
      packError = StateError('device is full');
      final service = build();

      await expectLater(
        service.take(origin: LocalSnapshotOrigin.manual),
        throwsA(isA<StateError>()),
      );

      // 服务层只负责抛；记录发生在 provider 层（见 local_snapshot_provider）。
      expect(await service.store.list(), isEmpty);
    });

    test('手动一份标成 manual，且不受周期限制', () async {
      final service = build();
      await service.runIfDue(now: DateTime.utc(2026, 5, 1));

      final entry = await service.take(origin: LocalSnapshotOrigin.manual);

      expect(entry.origin, LocalSnapshotOrigin.manual);
      expect(await service.store.list(), hasLength(2));
    });

    test('打包产物在发布后不残留在临时位置', () async {
      final service = build();
      await service.take(origin: LocalSnapshotOrigin.manual);

      final strays = await root
          .list()
          .where((entity) => p.basename(entity.path).startsWith('packed_'))
          .toList();
      expect(strays, isEmpty);
    });
  });
}
