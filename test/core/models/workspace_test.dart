import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/workspace.dart';

void main() {
  group('Workspace', () {
    final createdAt = DateTime.utc(2026, 9, 2, 12);
    final updatedAt = DateTime.utc(2026, 9, 2, 13);
    final lastUsedAt = DateTime.utc(2026, 9, 2, 14);

    Workspace sample() => Workspace(
      id: 'ws-1',
      name: 'Project',
      kind: WorkspaceKind.linked,
      hostPath: '/tmp/project',
      shellNeedsApproval: true,
      defaultCwd: 'src',
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastUsedAt: lastUsedAt,
    );

    test('defaults shellNeedsApproval and defaultCwd', () {
      final workspace = Workspace(
        id: 'ws-2',
        name: 'Managed',
        kind: WorkspaceKind.managed,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      expect(workspace.shellNeedsApproval, isFalse);
      expect(workspace.defaultCwd, isEmpty);
      expect(workspace.hostPath, isNull);
      expect(workspace.lastUsedAt, isNull);
    });

    test('JSON round trip', () {
      final workspace = sample();
      final decoded = Workspace.fromJson(workspace.toJson());
      expect(decoded, workspace);
    });

    test('tool choices round trip independently and survive other edits', () {
      final original = sample();
      final disabled = original.copyWith(
        disabledTools: {'shell', 'write_file'},
      );
      final reloaded = Workspace.fromJson(disabled.toJson());
      expect(reloaded.isToolEnabled('shell'), isFalse);
      expect(reloaded.isToolEnabled('read_file'), isTrue);
      expect(original.isToolEnabled('shell'), isTrue);
      expect(reloaded.copyWith(name: 'Renamed').disabledTools, {
        'shell',
        'write_file',
      });
      final reordered = original.copyWith(
        disabledTools: {'write_file', 'shell'},
      );
      expect(reordered, reloaded);
      expect(reordered.hashCode, reloaded.hashCode);
      expect(
        reloaded.copyWith(disabledTools: {}).isToolEnabled('shell'),
        isTrue,
      );
    });

    test('equality and copyWith', () {
      final workspace = sample();
      expect(workspace, workspace.copyWith());
      expect(
        workspace.copyWith(name: 'Other', clearHostPath: true),
        Workspace(
          id: 'ws-1',
          name: 'Other',
          kind: WorkspaceKind.linked,
          shellNeedsApproval: true,
          defaultCwd: 'src',
          createdAt: createdAt,
          updatedAt: updatedAt,
          lastUsedAt: lastUsedAt,
        ),
      );
    });
  });
}
