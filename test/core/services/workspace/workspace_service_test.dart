import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/workspace/workspace_service.dart';

void main() {
  test('rejects conversation IDs that are path traversal segments', () async {
    await expectLater(
      WorkspaceService.getWorkspaceRoot('../escape'),
      throwsArgumentError,
    );
  });
}
