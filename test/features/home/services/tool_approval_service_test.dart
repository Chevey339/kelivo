import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> expectStillPending(Future<dynamic> future) async {
  var completed = false;
  future.whenComplete(() {
    completed = true;
  });
  await Future<void>.delayed(Duration.zero);
  expect(completed, isFalse);
}

void main() {
  test(
    'session grant releases only matching workspace shell requests',
    () async {
      final service = ToolApprovalService();
      addTearDown(service.dispose);
      final requests = [
        for (final (chat, workspace, tool, id)
            in <(String?, String?, String, String)>[
              ('a', 'ws1', 'shell', 'first'),
              ('a', 'ws1', 'shell', 'second'),
              ('b', 'ws1', 'shell', 'first'),
              ('a', 'ws2', 'shell', 'other-workspace'),
              ('a', 'ws1', 'write_file', 'outside-write'),
              ('a', null, 'mcp_tool', 'mcp'),
              (null, 'ws1', 'shell', 'unscoped'),
            ])
          service.requestApproval(
            toolCallId: id,
            toolName: tool,
            arguments: const {},
            conversationId: chat,
            workspaceId: workspace,
          ),
      ];

      service.approveWorkspaceShells(conversationId: 'a', workspaceId: 'ws1');
      expect((await requests[0]).approved, isTrue);
      expect((await requests[1]).approved, isTrue);
      expect(service.pendingRequests, hasLength(5));
      for (final request in requests.skip(2)) {
        await expectStillPending(request);
      }
      service.cancelAll();
      for (final request in requests.skip(2)) {
        expect((await request).approved, isFalse);
      }
    },
  );

  test(
    'two conversations sharing a placeholder id keep both Completers',
    () async {
      final service = ToolApprovalService();
      final futureA = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'a'},
        conversationId: 'conversation-a',
      );
      final futureB = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'b'},
        conversationId: 'conversation-b',
      );

      expect(service.pendingRequests, hasLength(2));
      expect(
        service.pendingFor(
          toolCallId: 'round-0:tool-1',
          conversationId: 'conversation-a',
        ),
        isNotNull,
      );
      expect(
        service.pendingFor(
          toolCallId: 'round-0:tool-1',
          conversationId: 'conversation-b',
        ),
        isNotNull,
      );

      service.approve('round-0:tool-1', conversationId: 'conversation-a');
      final resultA = await futureA;
      expect(resultA.approved, isTrue);
      await expectStillPending(futureB);
      expect(
        service.isPending('round-0:tool-1', conversationId: 'conversation-b'),
        isTrue,
      );
      expect(
        service.isPending('round-0:tool-1', conversationId: 'conversation-a'),
        isFalse,
      );

      service.approve('round-0:tool-1', conversationId: 'conversation-b');
      final resultB = await futureB;
      expect(resultB.approved, isTrue);
      expect(service.hasPending, isFalse);
    },
  );

  test(
    'requestApproval does not overwrite an existing Completer for the same key',
    () async {
      final service = ToolApprovalService();
      final first = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'first'},
        conversationId: 'conversation-a',
      );
      final second = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'second'},
        conversationId: 'conversation-a',
      );

      expect(service.pendingRequests, hasLength(1));
      service.approve('round-0:tool-1', conversationId: 'conversation-a');
      expect((await first).approved, isTrue);
      expect((await second).approved, isTrue);
    },
  );

  test('unscoped requests with the same toolCallId do not overwrite', () async {
    final service = ToolApprovalService();
    final first = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {'q': 'first'},
    );
    final second = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {'q': 'second'},
    );

    expect(service.pendingRequests, hasLength(2));
    await expectStillPending(first);
    await expectStillPending(second);

    service.cancelAll();
    expect((await first).approved, isFalse);
    expect((await second).approved, isFalse);
  });

  test('cancelForConversation leaves the other chat waiting', () async {
    final service = ToolApprovalService();
    final futureA = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {},
      conversationId: 'conversation-a',
    );
    final futureB = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {},
      conversationId: 'conversation-b',
    );

    service.cancelForConversation('conversation-a');
    expect((await futureA).approved, isFalse);
    await expectStillPending(futureB);
    expect(
      service.pendingFor(
        toolCallId: 'round-0:tool-1',
        conversationId: 'conversation-b',
      ),
      isNotNull,
    );
  });
}
