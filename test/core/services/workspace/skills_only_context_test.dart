import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

void main() {
  late Directory tmp;
  late Directory skillsDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_skills_only_');
    skillsDir = Directory(p.join(tmp.path, 'skills', 'pdf-tools'))
      ..createSync(recursive: true);
    File(p.join(skillsDir.path, 'SKILL.md')).writeAsStringSync('''
---
name: pdf-tools
description: Extract
---
body
''');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  WorkspaceToolContext context() {
    return WorkspaceToolContext.skillsOnly(
      skillsHostDir: p.join(tmp.path, 'skills'),
      conversationId: 'conv-1',
    );
  }

  Map<String, dynamic> jsonOf(Object? raw) {
    final result = ClientToolResult.fromHandler(raw);
    return Map<String, dynamic>.from(jsonDecode(result.content) as Map);
  }

  test('skills-only context exposes only read_file', () {
    final ctx = context();
    expect(ctx.skillsOnly, isTrue);
    final defs = WorkspaceToolsService().buildToolDefinitions(ctx);
    expect(defs, hasLength(1));
    expect((defs.single['function'] as Map)['name'], 'read_file');
    expect(
      (defs.single['function'] as Map)['description'] as String,
      contains('/skills'),
    );
  });

  test('buildPromptFragment emits no workspace block', () {
    final fragment = WorkspaceToolsService.buildPromptFragment(context());
    expect(fragment, isEmpty);
    expect(fragment, isNot(contains('<workspace>')));
  });

  test('handle rejects every tool except read_file', () async {
    final tools = WorkspaceToolsService();
    final ctx = context();
    for (final name in WorkspaceToolsService.toolNames) {
      if (name == 'read_file') continue;
      final payload = jsonOf(
        await tools.handle(ctx, name, const {}, toolCallId: 'x'),
      );
      expect(payload['error'], 'skills_only', reason: name);
    }
  });

  test('read_file outside /skills is rejected', () async {
    final payload = jsonOf(
      await WorkspaceToolsService().handle(context(), 'read_file', {
        'path': '/workspace/secret.txt',
      }, toolCallId: 'out'),
    );
    expect(payload['error'], 'path_outside_skills');
  });

  test(
    'read_file can open SKILL.md and reports useCount via callback',
    () async {
      final read = <String>[];
      final tools = WorkspaceToolsService(
        onSkillRead: (id) async {
          read.add(id);
          throw StateError('must not surface');
        },
      );
      final result = ClientToolResult.fromHandler(
        await tools.handle(context(), 'read_file', {
          'path': '/skills/pdf-tools/SKILL.md',
        }, toolCallId: 'read-skill'),
      );
      expect(result.content, contains('body'));
      expect(read, ['pdf-tools']);
    },
  );

  test('does not lock extras in skills-only mode', () async {
    var extrasCalls = 0;
    final tools = WorkspaceToolsService(
      updateConversationExtras: (id, update) async {
        extrasCalls++;
      },
    );
    await tools.handle(context(), 'read_file', {
      'path': '/skills/pdf-tools/SKILL.md',
    }, toolCallId: 'nolock');
    expect(extrasCalls, 0);
  });
}
