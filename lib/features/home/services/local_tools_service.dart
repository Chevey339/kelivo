import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/assistant.dart';
import '../../../core/models/conversation.dart';
import '../../../core/services/skills/skill_service.dart';
import '../../../core/services/skills/skill_models.dart';
import '../../../core/services/workspace/workspace_service.dart';

typedef TextToSpeechStarter = Future<void> Function(String text);

class LocalToolNames {
  const LocalToolNames._();

  static const String timeInfo = 'get_time_info';
  static const String clipboard = 'clipboard_tool';
  static const String textToSpeech = 'text_to_speech';
  static const String askUser = 'ask_user_input_v0';
  static const String calculate = 'calculate';
  static const String workspaceFile = 'workspace_file';
  static const String gitClone = 'git_clone';
  static const String useSkill = 'use_skill';
  static const String readSkillResource = 'read_skill_resource';
}

class LocalToolsService {
  const LocalToolsService._();

  static Future<List<Map<String, dynamic>>> buildToolDefinitions({
    required Assistant? assistant,
    required bool supportsTools,
    Conversation? conversation,
  }) async {
    if (!supportsTools || assistant == null) {
      return const <Map<String, dynamic>>[];
    }

    final tools = <Map<String, dynamic>>[];
    if (assistant.localToolIds.contains(LocalToolNames.timeInfo)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.timeInfo,
          'description':
              'Get the current local date and time info from the device. Returns year, month, day, weekday, ISO date and time strings, timezone, UTC offset, and timestamp.',
          'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.clipboard)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.clipboard,
          'description':
              'Read or write plain text from the device clipboard. Use action: read or write. For write, provide text. Do NOT write to the clipboard unless the user has explicitly requested it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['read', 'write'],
                'description': 'Operation to perform: read or write',
              },
              'text': {
                'type': 'string',
                'description':
                    'Text to write to the clipboard. Required for write.',
              },
            },
            'required': ['action'],
          },
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.textToSpeech)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.textToSpeech,
          'description':
              'Speak text aloud to the user using the configured text-to-speech playback. Use this when the user asks you to read something aloud, or when audio output is appropriate. The tool returns after playback has been requested; audio may continue in the background. Provide natural, readable text without markdown formatting.',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description': 'The text to speak aloud.',
              },
            },
            'required': ['text'],
          },
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.askUser)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.askUser,
          'description':
              'Ask the user one or more short choice questions when you need clarification, additional information, or a decision before continuing. Supports single-choice and multi-choice questions. The UI will provide Other and Skip options automatically, so do not include those options yourself.',
          'parameters': {
            'type': 'object',
            'properties': {
              'questions': {
                'type': 'array',
                'description': 'One to four questions to ask the user.',
                'items': {
                  'type': 'object',
                  'properties': {
                    'id': {
                      'type': 'string',
                      'description':
                          'Unique stable identifier for this question.',
                    },
                    'question': {
                      'type': 'string',
                      'description':
                          'The full question text shown to the user.',
                    },
                    'type': {
                      'type': 'string',
                      'enum': ['single', 'multi'],
                      'description':
                          'Answer type: single choice or multi choice.',
                    },
                    'options': {
                      'type': 'array',
                      'description':
                          'Suggested options for the user to choose from.',
                      'items': {'type': 'string'},
                    },
                  },
                  'required': ['id', 'question'],
                },
              },
            },
            'required': ['questions'],
          },
        },
      });
    }
    if (assistant.localToolIds.contains(LocalToolNames.calculate)) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.calculate,
          'description':
              'Evaluate a mathematical expression. Supports: + - * / ^ % !, sin() cos() tan() sqrt() ln() abs() floor() ceil() sgn(), log(base, value), constants pi e. Example: "5!", "sin(pi/4)", "log(2, 8)", "floor(3.7)"',
          'parameters': {
            'type': 'object',
            'properties': {
              'expression': {
                'type': 'string',
                'description':
                    'A mathematical expression in standard notation, e.g. "(15 + 3) * 2", "2^10", "sqrt(144)"',
              },
            },
            'required': ['expression'],
          },
        },
      });
    }
    // Workspace tools are gated by conversation.workspaceEnabled, not by
    // assistant.localToolIds. They are injected only when the conversation
    // has a workspace, regardless of the assistant's local tool toggles.
    if (conversation?.workspaceEnabled == true) {
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.workspaceFile,
          'description':
              'Manage files in the conversation workspace. Actions: write (create/overwrite file), edit (string replace), create_dir, delete (recursive), move, read, list, search (grep file contents recursively). All paths are relative to the workspace root. Path traversal (..) is blocked.',
          'parameters': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': [
                  'write',
                  'edit',
                  'create_dir',
                  'delete',
                  'move',
                  'read',
                  'list',
                  'search',
                ],
              },
              'path': {
                'type': 'string',
                'description': 'Relative path. For move, this is the source.',
              },
              'content': {
                'type': 'string',
                'description': 'File content for write action.',
              },
              'old_string': {
                'type': 'string',
                'description': 'For edit: exact string to replace.',
              },
              'new_string': {
                'type': 'string',
                'description': 'For edit: replacement string.',
              },
              'from': {
                'type': 'string',
                'description': 'For move: source path.',
              },
              'to': {
                'type': 'string',
                'description': 'For move: destination path.',
              },
              'query': {
                'type': 'string',
                'description':
                    'For search: text to find (case-insensitive). Required for search action.',
              },
              'max_results': {
                'type': 'integer',
                'description':
                    'For search: max number of matches to return (default 50, max 200).',
              },
              'context_lines': {
                'type': 'integer',
                'description':
                    'For search: number of context lines to include before and after each match (default 0).',
              },
            },
            'required': ['action', 'path'],
          },
        },
      });
      tools.add(const {
        'type': 'function',
        'function': {
          'name': LocalToolNames.gitClone,
          'description':
              'Clone a public GitHub repository into the workspace by downloading the zipball of a branch. Returns the destination path and file count. Private repos and git history are not supported (use workspace_file for further file operations).',
          'parameters': {
            'type': 'object',
            'properties': {
              'repo': {
                'type': 'string',
                'description':
                    'Repository in owner/name format, e.g. "facebook/react".',
              },
              'branch': {
                'type': 'string',
                'description': 'Branch name (default: main).',
                'default': 'main',
              },
              'subdir': {
                'type': 'string',
                'description':
                    'Optional subdirectory to extract only that path.',
              },
            },
            'required': ['repo'],
          },
        },
      });
    }

    final activeSkills = await _getActiveSkillsForConversation(conversation);
    if (activeSkills.isNotEmpty) {
      tools.add({
        'type': 'function',
        'function': {
          'name': LocalToolNames.useSkill,
          'description':
              'Load the full SKILL.md of an available skill when the user\'s request matches the skill\'s purpose. Call this first before read_skill_resource.',
          'parameters': {
            'type': 'object',
            'properties': {
              'skill_name': {
                'type': 'string',
                'description': 'The skill name (kebab-case) to load.',
              },
            },
            'required': ['skill_name'],
          },
        },
      });
      tools.add({
        'type': 'function',
        'function': {
          'name': LocalToolNames.readSkillResource,
          'description':
              'Read an asset/reference file (e.g. references/*.md) from a skill directory whose SKILL.md has already been loaded. Paths under scripts/ are forbidden.',
          'parameters': {
            'type': 'object',
            'properties': {
              'skill_name': {
                'type': 'string',
                'description': 'The skill name.',
              },
              'path': {
                'type': 'string',
                'description':
                    'Relative path within the skill directory, e.g. references/style-guide.md',
              },
            },
            'required': ['skill_name', 'path'],
          },
        },
      });
    }
    return tools;
  }

  static Future<List<SkillMeta>> _getActiveSkillsForConversation(
    Conversation? conversation,
  ) async {
    final all = await SkillService.instance.listSkills();
    final enabled = all.where((s) => s.globalEnabled).toList();
    if (conversation == null || conversation.enabledSkillNames.isEmpty) {
      return enabled;
    }
    return enabled
        .where((s) => conversation.enabledSkillNames.contains(s.name))
        .toList();
  }

  static Future<String?> tryHandleToolCall(
    String name,
    Map<String, dynamic> args,
    Assistant? assistant, {
    TextToSpeechStarter? onSpeakText,
    Conversation? conversation,
  }) async {
    final conversationId = conversation?.id;
    // Workspace tools are gated by conversation.workspaceEnabled, NOT by
    // assistant.localToolIds. Dispatch them before the localToolIds guard.
    if (name == LocalToolNames.workspaceFile) {
      if (conversationId == null) return null;
      return _handleWorkspaceFileTool(conversationId, args);
    }
    if (name == LocalToolNames.gitClone) {
      if (conversationId == null) return null;
      return _handleGitCloneTool(conversationId, args);
    }
    if (name == LocalToolNames.useSkill) {
      if (conversation == null) return null;
      return _handleUseSkillTool(conversation, args);
    }
    if (name == LocalToolNames.readSkillResource) {
      if (conversation == null) return null;
      return _handleReadSkillResourceTool(conversation, args);
    }
    if (assistant == null || !assistant.localToolIds.contains(name)) {
      return null;
    }
    if (name == LocalToolNames.timeInfo) {
      return jsonEncode(_buildTimeInfoPayload(DateTime.now()));
    }
    if (name == LocalToolNames.clipboard) {
      return _handleClipboardTool(args);
    }
    if (name == LocalToolNames.textToSpeech) {
      return _handleTextToSpeechTool(args, onSpeakText);
    }
    if (name == LocalToolNames.calculate) {
      return _handleCalculateTool(args);
    }
    return null;
  }

  static Future<String> _handleUseSkillTool(
    Conversation conversation,
    Map<String, dynamic> args,
  ) async {
    final skillName = (args['skill_name'] ?? '').toString();
    if (skillName.isEmpty) {
      return jsonEncode({
        'error': 'missing_skill_name',
        'message': 'skill_name is required',
      });
    }
    final active = await _getActiveSkillsForConversation(conversation);
    if (!active.any((s) => s.name == skillName)) {
      return jsonEncode({
        'error': 'skill_not_enabled',
        'message': 'Skill "$skillName" is not enabled for this conversation',
      });
    }
    final content = await SkillService.instance.readSkillMd(skillName);
    if (content == null) {
      return jsonEncode({
        'error': 'skill_not_found',
        'message': 'Skill "$skillName" not found',
      });
    }
    return jsonEncode({'skill_name': skillName, 'content': content});
  }

  static Future<String> _handleReadSkillResourceTool(
    Conversation conversation,
    Map<String, dynamic> args,
  ) async {
    final skillName = (args['skill_name'] ?? '').toString();
    final path = (args['path'] ?? '').toString();
    if (skillName.isEmpty || path.isEmpty) {
      return jsonEncode({
        'error': 'missing_param',
        'message': 'skill_name and path are required',
      });
    }
    final active = await _getActiveSkillsForConversation(conversation);
    if (!active.any((s) => s.name == skillName)) {
      return jsonEncode({
        'error': 'skill_not_enabled',
        'message': 'Skill "$skillName" is not enabled',
      });
    }
    final content = await SkillService.instance.readSkillResource(
      skillName,
      path,
    );
    if (content == null) {
      return jsonEncode({
        'error': 'resource_not_found',
        'message': 'Resource "$path" not found or access denied',
      });
    }
    return jsonEncode({
      'skill_name': skillName,
      'path': path,
      'content': content,
    });
  }

  static Future<String> _handleClipboardTool(Map<String, dynamic> args) async {
    final action = (args['action'] ?? '').toString();
    switch (action) {
      case 'read':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        return jsonEncode({'text': data?.text ?? ''});
      case 'write':
        final text = args['text']?.toString();
        if (text == null) {
          throw ArgumentError('text is required for clipboard write');
        }
        await Clipboard.setData(ClipboardData(text: text));
        return jsonEncode({'success': true, 'text': text});
      default:
        throw ArgumentError('unknown clipboard action: $action');
    }
  }

  static Future<String> _handleTextToSpeechTool(
    Map<String, dynamic> args,
    TextToSpeechStarter? onSpeakText,
  ) async {
    final text = args['text']?.toString().trim();
    if (text == null || text.isEmpty) {
      throw ArgumentError('text is required for text_to_speech');
    }
    if (onSpeakText == null) {
      throw StateError('text-to-speech executor is unavailable');
    }
    await onSpeakText(text);
    return jsonEncode({'success': true});
  }

  static Map<String, dynamic> _buildTimeInfoPayload(DateTime now) {
    final offset = now.timeZoneOffset;
    final offsetSign = offset.isNegative ? '-' : '+';
    final offsetAbs = offset.abs();
    final offsetHours = offsetAbs.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (offsetAbs.inMinutes % 60).toString().padLeft(2, '0');

    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final weekdayEn = _englishWeekdayName(now.weekday);

    return <String, dynamic>{
      'year': now.year,
      'month': now.month,
      'day': now.day,
      'weekday': weekdayEn,
      'weekday_en': weekdayEn,
      'weekday_index': now.weekday,
      'date': '$year-$month-$day',
      'time': '$hour:$minute:$second',
      'datetime': now.toIso8601String(),
      'timezone': now.timeZoneName,
      'utc_offset': '$offsetSign$offsetHours:$offsetMinutes',
      'timestamp_ms': now.millisecondsSinceEpoch,
    };
  }

  static String _englishWeekdayName(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Unknown',
    };
  }

  static String _handleCalculateTool(Map<String, dynamic> args) {
    final expression = (args['expression'] ?? '').toString().trim();
    if (expression.isEmpty) {
      return jsonEncode({
        'error': 'empty_expression',
        'message':
            'Expression is empty. Please provide a mathematical expression in standard notation, e.g. "(15 + 3) * 2".',
      });
    }

    try {
      final parsed = GrammarParser().parse(expression);
      final result = parsed.evaluate(EvaluationType.REAL, ContextModel());
      if (!result.isFinite) {
        return jsonEncode({
          'error': 'math_error',
          'message':
              'The result is not a finite number. Please check your expression (e.g. division by zero).',
        });
      }
      return jsonEncode({
        'expression': expression,
        'result': result.toString(),
      });
    } catch (e) {
      return jsonEncode({
        'error': 'parse_error',
        'message':
            'Could not parse the expression. Use standard notation, e.g. "(15 + 3) * 2".',
        'detail': e.toString(),
      });
    }
  }

  // ==========================================================================
  // workspace_file tool
  // ==========================================================================

  static Future<String> _handleWorkspaceFileTool(
    String conversationId,
    Map<String, dynamic> args,
  ) async {
    final action = (args['action'] ?? '').toString();
    final path = (args['path'] ?? '').toString();
    switch (action) {
      case 'write':
        return _handleWorkspaceFileWrite(conversationId, path, args);
      case 'edit':
        return _handleWorkspaceFileEdit(conversationId, path, args);
      case 'create_dir':
        return _handleWorkspaceFileCreateDir(conversationId, path);
      case 'delete':
        return _handleWorkspaceFileDelete(conversationId, path);
      case 'move':
        return _handleWorkspaceFileMove(conversationId, path, args);
      case 'read':
        return _handleWorkspaceFileRead(conversationId, path);
      case 'list':
        return _handleWorkspaceFileList(conversationId, path);
      case 'search':
        return _handleWorkspaceFileSearch(conversationId, args);
      default:
        return jsonEncode({
          'error': 'unknown_action',
          'message': 'Unknown workspace_file action: $action',
        });
    }
  }

  static Future<String> _handleWorkspaceFileWrite(
    String conversationId,
    String path,
    Map<String, dynamic> args,
  ) async {
    if (path.isEmpty) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path is required for write',
      });
    }
    final content = args['content']?.toString() ?? '';
    final safePath = await WorkspaceService.resolveSafePath(
      conversationId,
      path,
    );
    if (safePath == null) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path escapes workspace root: $path',
      });
    }
    try {
      final file = File(safePath);
      await file.parent.create(recursive: true);
      final bytes = utf8.encode(content);
      await file.writeAsBytes(bytes);
      return jsonEncode({
        'path': path,
        'action': 'write',
        'bytes': bytes.length,
      });
    } catch (e) {
      return jsonEncode({
        'error': 'write_failed',
        'message': 'Failed to write file: $e',
      });
    }
  }

  static Future<String> _handleWorkspaceFileEdit(
    String conversationId,
    String path,
    Map<String, dynamic> args,
  ) async {
    if (path.isEmpty) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path is required for edit',
      });
    }
    final oldString = args['old_string']?.toString();
    final newString = args['new_string']?.toString();
    if (oldString == null || newString == null) {
      return jsonEncode({
        'error': 'invalid_params',
        'message': 'old_string and new_string are required for edit',
      });
    }
    final safePath = await WorkspaceService.resolveSafePath(
      conversationId,
      path,
    );
    if (safePath == null) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path escapes workspace root: $path',
      });
    }
    final file = File(safePath);
    if (!await file.exists()) {
      return jsonEncode({
        'error': 'not_found',
        'message': 'file does not exist: $path',
      });
    }
    try {
      final original = await file.readAsString();
      final occurrences = _countOccurrences(original, oldString);
      if (occurrences == 0) {
        return jsonEncode({
          'error': 'old_string_not_found',
          'message':
              'old_string was not found in $path. Ensure it matches exactly, including whitespace.',
        });
      }
      if (occurrences > 1) {
        return jsonEncode({
          'error': 'old_string_ambiguous',
          'message':
              'old_string occurs $occurrences times in $path. Provide more surrounding context so it is unique.',
          'occurrences': occurrences,
        });
      }
      final replaced = original.replaceFirst(oldString, newString);
      await file.writeAsString(replaced);
      return jsonEncode({'path': path, 'action': 'edit', 'replacements': 1});
    } catch (e) {
      return jsonEncode({
        'error': 'edit_failed',
        'message': 'Failed to edit file: $e',
      });
    }
  }

  static Future<String> _handleWorkspaceFileCreateDir(
    String conversationId,
    String path,
  ) async {
    if (path.isEmpty) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path is required for create_dir',
      });
    }
    final safePath = await WorkspaceService.resolveSafePath(
      conversationId,
      path,
    );
    if (safePath == null) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path escapes workspace root: $path',
      });
    }
    try {
      final dir = Directory(safePath);
      await dir.create(recursive: true);
      return jsonEncode({'path': path, 'action': 'create_dir'});
    } catch (e) {
      return jsonEncode({
        'error': 'create_dir_failed',
        'message': 'Failed to create directory: $e',
      });
    }
  }

  static Future<String> _handleWorkspaceFileDelete(
    String conversationId,
    String path,
  ) async {
    if (path.isEmpty) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path is required for delete',
      });
    }
    final safePath = await WorkspaceService.resolveSafePath(
      conversationId,
      path,
    );
    if (safePath == null) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path escapes workspace root: $path',
      });
    }
    final file = File(safePath);
    final dir = Directory(safePath);
    final fileExists = await file.exists();
    final dirExists = await dir.exists();
    if (!fileExists && !dirExists) {
      return jsonEncode({
        'error': 'not_found',
        'message': 'path does not exist: $path',
      });
    }
    try {
      if (fileExists) {
        await file.delete(recursive: false);
      } else {
        await dir.delete(recursive: true);
      }
      return jsonEncode({'path': path, 'action': 'delete'});
    } catch (e) {
      return jsonEncode({
        'error': 'delete_failed',
        'message': 'Failed to delete path: $e',
      });
    }
  }

  static Future<String> _handleWorkspaceFileMove(
    String conversationId,
    String path,
    Map<String, dynamic> args,
  ) async {
    final fromRaw = (args['from']?.toString() ?? '').isNotEmpty
        ? args['from'].toString()
        : path;
    final to = (args['to']?.toString() ?? '');
    if (fromRaw.isEmpty || to.isEmpty) {
      return jsonEncode({
        'error': 'invalid_params',
        'message': 'from and to are required for move',
      });
    }
    final fromSafe = await WorkspaceService.resolveSafePath(
      conversationId,
      fromRaw,
    );
    final toSafe = await WorkspaceService.resolveSafePath(conversationId, to);
    if (fromSafe == null || toSafe == null) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'from or to escapes workspace root',
      });
    }
    final fromFile = File(fromSafe);
    final fromDir = Directory(fromSafe);
    final fileExists = await fromFile.exists();
    final dirExists = await fromDir.exists();
    if (!fileExists && !dirExists) {
      return jsonEncode({
        'error': 'not_found',
        'message': 'source does not exist: $fromRaw',
      });
    }
    try {
      await Directory(toSafe).parent.create(recursive: true);
      if (fileExists) {
        await fromFile.rename(toSafe);
      } else {
        await fromDir.rename(toSafe);
      }
      return jsonEncode({'from': fromRaw, 'to': to, 'action': 'move'});
    } catch (e) {
      return jsonEncode({
        'error': 'move_failed',
        'message': 'Failed to move path: $e',
      });
    }
  }

  static Future<String> _handleWorkspaceFileRead(
    String conversationId,
    String path,
  ) async {
    if (path.isEmpty) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path is required for read',
      });
    }
    final safePath = await WorkspaceService.resolveSafePath(
      conversationId,
      path,
    );
    if (safePath == null) {
      return jsonEncode({
        'error': 'invalid_path',
        'message': 'path escapes workspace root: $path',
      });
    }
    final file = File(safePath);
    if (!await file.exists()) {
      return jsonEncode({
        'error': 'not_found',
        'message': 'file does not exist: $path',
      });
    }
    try {
      final bytes = await file.readAsBytes();
      return jsonEncode({
        'path': path,
        'content': utf8.decode(bytes, allowMalformed: true),
        'bytes': bytes.length,
      });
    } catch (e) {
      return jsonEncode({
        'error': 'read_failed',
        'message': 'Failed to read file: $e',
      });
    }
  }

  static Future<String> _handleWorkspaceFileList(
    String conversationId,
    String path,
  ) async {
    // Empty path lists the workspace root.
    final entries = await WorkspaceService.listFiles(
      conversationId,
      path.isEmpty ? null : path,
    );
    return jsonEncode({
      'path': path,
      'entries': entries
          .map(
            (e) => {
              'name': e.name,
              'relativePath': e.relativePath,
              'isDir': e.isDir,
              'size': e.size,
            },
          )
          .toList(),
    });
  }

  static Future<String> _handleWorkspaceFileSearch(
    String conversationId,
    Map<String, dynamic> args,
  ) async {
    final query = (args['query'] ?? '').toString().trim();
    if (query.isEmpty) {
      return jsonEncode({
        'error': 'invalid_query',
        'message': 'query is required for search action',
      });
    }
    var maxResults = 50;
    if (args['max_results'] != null) {
      maxResults = (args['max_results'] as num).toInt().clamp(1, 200);
    }
    var contextLines = 0;
    if (args['context_lines'] != null) {
      contextLines = (args['context_lines'] as num).toInt().clamp(0, 50);
    }
    final matches = await WorkspaceService.grep(
      conversationId,
      query,
      maxResults: maxResults,
      contextLines: contextLines,
    );
    return jsonEncode({
      'query': query,
      'matchCount': matches.length,
      'matches': matches
          .map(
            (m) => {
              'file': m.relativePath,
              'line': m.lineNumber,
              'content': m.lineContent,
              if (m.contextBefore.isNotEmpty)
                'contextBefore': m.contextBefore,
              if (m.contextAfter.isNotEmpty)
                'contextAfter': m.contextAfter,
            },
          )
          .toList(),
    });
  }

  /// Counts non-overlapping occurrences of [needle] in [haystack].
  static int _countOccurrences(String haystack, String needle) {
    if (needle.isEmpty) return 0;
    var count = 0;
    var idx = 0;
    while (true) {
      final found = haystack.indexOf(needle, idx);
      if (found < 0) break;
      count++;
      idx = found + needle.length;
    }
    return count;
  }

  // ==========================================================================
  // git_clone tool
  // ==========================================================================

  static const int _gitCloneMaxBytes = 200 * 1024 * 1024; // 200 MB

  static Future<String> _handleGitCloneTool(
    String conversationId,
    Map<String, dynamic> args,
  ) async {
    final repo = (args['repo'] ?? '').toString().trim();
    if (repo.isEmpty || !repo.contains('/')) {
      return jsonEncode({
        'error': 'invalid_repo',
        'message': 'repo must be in "owner/name" format',
      });
    }
    final parts = repo.split('/');
    if (parts.length != 2) {
      return jsonEncode({
        'error': 'invalid_repo',
        'message': 'repo must be in "owner/name" format',
      });
    }
    final owner = parts[0];
    final repoName = parts[1];
    final branch = (args['branch'] ?? 'main').toString().trim().isEmpty
        ? 'main'
        : (args['branch']!.toString());
    final subdirRaw = args['subdir']?.toString().trim();
    final subdir = (subdirRaw == null || subdirRaw.isEmpty) ? null : subdirRaw;

    final url =
        'https://codeload.github.com/$owner/$repoName/zip/refs/heads/$branch';

    // Ensure workspace exists; reject when destination already exists so we
    // never silently overwrite a previous clone.
    final String workspaceRoot;
    try {
      workspaceRoot = await WorkspaceService.ensureWorkspace(conversationId);
    } catch (e) {
      return jsonEncode({
        'error': 'workspace_unavailable',
        'message': 'Failed to ensure workspace: $e',
      });
    }
    final destDirPath = p.join(workspaceRoot, repoName);
    final destDir = Directory(destDirPath);
    if (await destDir.exists()) {
      return jsonEncode({
        'error': 'destination_exists',
        'message':
            'Target directory already exists in workspace: $repoName/. Move or delete it first.',
        'path': destDirPath,
      });
    }

    final Dio dio = Dio();
    final cancelToken = CancelToken();
    final tempDir = await Directory.systemTemp.createTemp('kelivo-git-clone-');
    final tmpZip = File(p.join(tempDir.path, 'repo.zip'));

    try {
      final response = await dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode != 200) {
        return jsonEncode({
          'error': 'http_error',
          'message': 'GitHub returned HTTP $statusCode for $url',
          'status': statusCode,
        });
      }
      final sink = tmpZip.openWrite();
      int received = 0;
      try {
        await for (final chunk in response.data!.stream) {
          received += chunk.length;
          if (received > _gitCloneMaxBytes) {
            cancelToken.cancel('exceeds 200MB limit');
            return jsonEncode({
              'error': 'too_large',
              'message':
                  'Downloaded data exceeds the 200MB limit ($received bytes). Aborted.',
              'bytes': received,
            });
          }
          sink.add(chunk);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final bytes = await tmpZip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Detect the common top-level directory codeload prepends to every file
      // (e.g. `<owner>-<repoName>-<shortSHA>/`). We strip it so the extracted
      // tree lands directly under workspace/<repoName>/.
      String? topPrefix;
      for (final file in archive.files) {
        final name = file.name;
        if (name.isEmpty) continue;
        final idx = name.indexOf('/');
        if (idx <= 0) {
          topPrefix = null;
          break;
        }
        final prefix = name.substring(0, idx);
        if (topPrefix == null) {
          topPrefix = prefix;
        } else if (topPrefix != prefix) {
          topPrefix = null;
          break;
        }
      }

      int fileCount = 0;
      int totalBytes = 0;
      for (final file in archive.files) {
        if (!file.isFile) continue;
        var relPath = file.name;
        if (topPrefix != null && relPath.startsWith('$topPrefix/')) {
          relPath = relPath.substring(topPrefix.length + 1);
        }
        if (relPath.isEmpty) continue;
        // Normalize separators: zip entries always use '/', but be defensive
        // on Windows where the host separator is '\'.
        relPath = relPath.replaceAll('\\', '/');
        if (subdir != null) {
          final sub = subdir.replaceAll('\\', '/');
          final subWithSlash = sub.endsWith('/') ? sub : '$sub/';
          if (relPath == sub) {
            relPath = '';
          } else if (relPath.startsWith(subWithSlash)) {
            relPath = relPath.substring(subWithSlash.length);
          } else {
            continue;
          }
        }
        if (relPath.isEmpty) continue;

        final dest = await WorkspaceService.resolveSafePath(
          conversationId,
          p.join(repoName, relPath),
        );
        if (dest == null) continue;
        final destFile = File(dest);
        await destFile.parent.create(recursive: true);
        final data = file.content; // Uint8List
        await destFile.writeAsBytes(data);
        fileCount++;
        totalBytes += data.length;
      }

      return jsonEncode({
        'repo': repo,
        'branch': branch,
        'path': destDirPath,
        'files': fileCount,
        'bytes': totalBytes,
      });
    } on DioException catch (e) {
      final reason = cancelToken.isCancelled ? 'cancelled' : e.type.toString();
      return jsonEncode({
        'error': 'download_failed',
        'message': 'Failed to download repo: $reason (${e.message ?? e})',
      });
    } catch (e) {
      // Best-effort cleanup of any partial destination directory.
      try {
        if (await destDir.exists()) {
          await destDir.delete(recursive: true);
        }
      } catch (_) {}
      return jsonEncode({
        'error': 'clone_failed',
        'message': 'Failed to clone repo: $e',
      });
    } finally {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
      try {
        dio.close();
      } catch (_) {}
    }
  }
}
