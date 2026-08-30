import 'package:Kelivo/core/services/backup/backup_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(BackupActivity.debugReset);
  tearDown(BackupActivity.debugReset);

  group('BackupActivity', () {
    test('闲置时不阻塞后台工作', () {
      expect(BackupActivity.isActive, isFalse);
    });

    test('begin/end 成对后回到闲置', () {
      BackupActivity.begin();
      expect(BackupActivity.isActive, isTrue);
      BackupActivity.end();
      expect(BackupActivity.isActive, isFalse);
    });

    test('嵌套任务全部结束前一直算忙', () {
      BackupActivity.begin();
      BackupActivity.begin();
      BackupActivity.end();
      // 转到后台的任务比启动它的弹窗活得久，所以只数到零才算闲。
      expect(BackupActivity.isActive, isTrue);
      BackupActivity.end();
      expect(BackupActivity.isActive, isFalse);
    });

    test('多余的 end 不会把计数压到负数', () {
      BackupActivity.end();
      BackupActivity.end();
      expect(BackupActivity.isActive, isFalse);
      BackupActivity.begin();
      expect(BackupActivity.isActive, isTrue);
    });
  });
}
