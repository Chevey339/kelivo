import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/workspace_binding.dart';

void main() {
  group('WorkspaceBinding', () {
    test('fromExtras reads feature-prefixed keys', () {
      final binding = WorkspaceBinding.fromExtras({
        WorkspaceBinding.keyId: 'ws-1',
        WorkspaceBinding.keyCwd: 'lib',
        WorkspaceBinding.keyToolsUsed: true,
        WorkspaceBinding.keyAllowAll: true,
        'other.flag': true,
      });
      expect(binding.workspaceId, 'ws-1');
      expect(binding.cwd, 'lib');
      expect(binding.toolsUsed, isTrue);
      expect(binding.allowAll, isTrue);
      expect(binding.isBound, isTrue);
    });

    test('applyTo writes binding keys without mutating the source', () {
      final extras = <String, dynamic>{'other.flag': true};
      final next = const WorkspaceBinding(
        workspaceId: 'ws-1',
        cwd: 'src',
        toolsUsed: true,
        allowAll: false,
      ).applyTo(extras);

      expect(extras.containsKey(WorkspaceBinding.keyId), isFalse);
      expect(next[WorkspaceBinding.keyId], 'ws-1');
      expect(next[WorkspaceBinding.keyCwd], 'src');
      expect(next[WorkspaceBinding.keyToolsUsed], isTrue);
      expect(next[WorkspaceBinding.keyAllowAll], isFalse);
      expect(next['other.flag'], isTrue);
    });

    test('applyTo removes keys when unbound', () {
      final extras = <String, dynamic>{
        WorkspaceBinding.keyId: 'ws-1',
        WorkspaceBinding.keyCwd: 'src',
        WorkspaceBinding.keyToolsUsed: true,
        WorkspaceBinding.keyAllowAll: true,
        'other.flag': true,
      };
      final next = const WorkspaceBinding().applyTo(extras);
      expect(next.containsKey(WorkspaceBinding.keyId), isFalse);
      expect(next.containsKey(WorkspaceBinding.keyCwd), isFalse);
      expect(next.containsKey(WorkspaceBinding.keyToolsUsed), isFalse);
      expect(next.containsKey(WorkspaceBinding.keyAllowAll), isFalse);
      expect(next['other.flag'], isTrue);
      expect(const WorkspaceBinding().isBound, isFalse);
    });
  });
}
