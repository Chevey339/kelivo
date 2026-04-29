import 'dart:convert';

import 'terminal_native_bridge.dart';

class TerminalAiToolService {
  TerminalAiToolService({TerminalNativeBridge? bridge})
    : _bridge = bridge ?? TerminalNativeBridge();

  final TerminalNativeBridge _bridge;

  static const String readToolName = 'terminal_read';
  static const String execToolName = 'terminal_exec';
  static const String editToolName = 'terminal_edit';
  static const String writeToolName = 'terminal_write';

  static const int _defaultMaxOutputBytes = 65536;
  static const int _maxFileEditBytes = 512 * 1024;
  static const int _maxTimeoutSeconds = 120;

  static final List<Map<String, dynamic>> toolDefinitions =
      <Map<String, dynamic>>[
        _functionTool(
          name: readToolName,
          description:
              'Read a UTF-8 text file from the local iOS terminal runtime. '
              'Use offset and limit for line-based paging.',
          properties: {
            'path': {
              'type': 'string',
              'description': 'Absolute or shell-relative path to read.',
            },
            'offset': {
              'type': 'integer',
              'description': 'Optional zero-based line offset.',
            },
            'limit': {
              'type': 'integer',
              'description': 'Optional maximum number of lines to return.',
            },
          },
          required: ['path'],
        ),
        _functionTool(
          name: execToolName,
          description:
              'Execute a shell command inside the local iOS terminal runtime '
              'and return stdout/stderr plus exit code.',
          properties: {
            'command': {
              'type': 'string',
              'description': 'Shell command to execute with /bin/sh.',
            },
            'timeout': {
              'type': 'integer',
              'description': 'Timeout in seconds. Defaults to 20, max 120.',
            },
          },
          required: ['command'],
        ),
        _functionTool(
          name: editToolName,
          description:
              'Edit a UTF-8 text file in the local iOS terminal runtime. '
              'Each oldText must match exactly once.',
          properties: {
            'path': {
              'type': 'string',
              'description': 'Absolute or shell-relative path to edit.',
            },
            'edits': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'oldText': {'type': 'string'},
                  'newText': {'type': 'string'},
                },
                'required': ['oldText', 'newText'],
              },
            },
            'oldText': {
              'type': 'string',
              'description': 'Legacy single-edit old text.',
            },
            'newText': {
              'type': 'string',
              'description': 'Legacy single-edit replacement text.',
            },
          },
          required: ['path'],
        ),
        _functionTool(
          name: writeToolName,
          description:
              'Create or overwrite a UTF-8 text file in the local iOS '
              'terminal runtime, creating parent directories as needed.',
          properties: {
            'path': {
              'type': 'string',
              'description': 'Absolute or shell-relative path to write.',
            },
            'content': {
              'type': 'string',
              'description': 'Full file content to write.',
            },
          },
          required: ['path', 'content'],
        ),
      ];

  static bool canHandle(String name) {
    return name == readToolName ||
        name == execToolName ||
        name == editToolName ||
        name == writeToolName;
  }

  Future<String> handleToolCall(String name, Map<String, dynamic> args) async {
    try {
      return switch (name) {
        readToolName => await _read(args),
        execToolName => await _exec(args),
        editToolName => await _edit(args),
        writeToolName => await _write(args),
        _ => _toolError(name, 'unknown_tool', 'Unknown terminal tool.'),
      };
    } on TerminalNativeBridgeException catch (error) {
      return _toolError(name, error.code, error.message);
    } catch (error) {
      return _toolError(name, 'execution_error', error.toString());
    }
  }

  Future<String> _exec(Map<String, dynamic> args) async {
    final command = _requiredString(args, 'command');
    final timeoutSeconds = _boundedInt(
      args['timeout'],
      defaultValue: 20,
      min: 1,
      max: _maxTimeoutSeconds,
    );
    final result = await _bridge.runCommand(
      command: command,
      timeout: Duration(seconds: timeoutSeconds),
      maxOutputBytes: _defaultMaxOutputBytes,
    );
    return jsonEncode({
      'type': 'terminal_exec_result',
      'exitCode': result.exitCode,
      'timedOut': result.timedOut,
      'truncated': result.truncated,
      'output': result.output,
    });
  }

  Future<String> _read(Map<String, dynamic> args) async {
    final path = _requiredString(args, 'path');
    final offset = _optionalNonNegativeInt(args['offset']);
    final limit = _optionalPositiveInt(args['limit'], max: 5000);
    final quotedPath = _shellQuote(path);
    final command = offset == null && limit == null
        ? 'cat -- $quotedPath'
        : 'tail -n +${(offset ?? 0) + 1} -- $quotedPath'
              '${limit == null ? '' : ' | head -n $limit'}';
    final result = await _bridge.runCommand(
      command: command,
      maxOutputBytes: _defaultMaxOutputBytes,
    );
    if (result.exitCode != 0) {
      return _toolError(readToolName, 'read_failed', result.output);
    }
    return jsonEncode({
      'type': 'terminal_read_result',
      'path': path,
      'offset': offset ?? 0,
      'limit': limit,
      'truncated': result.truncated,
      'content': result.output,
    });
  }

  Future<String> _write(Map<String, dynamic> args) async {
    final path = _requiredString(args, 'path');
    final content = _requiredString(args, 'content', allowEmpty: true);
    final result = await _writeContent(path, content);
    if (result.exitCode != 0) {
      return _toolError(writeToolName, 'write_failed', result.output);
    }
    return jsonEncode({
      'type': 'terminal_write_result',
      'path': path,
      'bytes': utf8.encode(content).length,
    });
  }

  Future<String> _edit(Map<String, dynamic> args) async {
    final path = _requiredString(args, 'path');
    final edits = _parseEdits(args);
    if (edits.isEmpty) {
      return _toolError(
        editToolName,
        'invalid_args',
        'No edits were provided.',
      );
    }
    final read = await _bridge.runCommand(
      command: 'cat -- ${_shellQuote(path)}',
      maxOutputBytes: _maxFileEditBytes,
    );
    if (read.exitCode != 0) {
      return _toolError(editToolName, 'read_failed', read.output);
    }
    if (read.truncated) {
      return _toolError(
        editToolName,
        'file_too_large',
        'File is larger than $_maxFileEditBytes bytes.',
      );
    }

    var content = read.output;
    var applied = 0;
    for (final edit in edits) {
      final oldText = edit.oldText;
      final matches = _countOccurrences(content, oldText);
      if (matches != 1) {
        return _toolError(
          editToolName,
          'old_text_not_unique',
          'oldText must match exactly once, but matched $matches times.',
        );
      }
      content = content.replaceFirst(oldText, edit.newText);
      applied++;
    }

    final write = await _writeContent(path, content);
    if (write.exitCode != 0) {
      return _toolError(editToolName, 'write_failed', write.output);
    }
    return jsonEncode({
      'type': 'terminal_edit_result',
      'path': path,
      'editsApplied': applied,
    });
  }

  Future<TerminalCommandResult> _writeContent(
    String path,
    String content,
  ) async {
    final encoded = base64Encode(utf8.encode(content));
    final quotedPath = _shellQuote(path);
    final command =
        'mkdir -p -- "\$(dirname -- $quotedPath)" && '
        'base64 -d > $quotedPath <<\'__KELIVO_CONTENT__\'\n'
        '$encoded\n'
        '__KELIVO_CONTENT__';
    return _bridge.runCommand(
      command: command,
      timeout: const Duration(seconds: 20),
      maxOutputBytes: _defaultMaxOutputBytes,
    );
  }

  static Map<String, dynamic> _functionTool({
    required String name,
    required String description,
    required Map<String, dynamic> properties,
    required List<String> required,
  }) {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': properties,
          'required': required,
        },
      },
    };
  }

  static String _requiredString(
    Map<String, dynamic> args,
    String key, {
    bool allowEmpty = false,
  }) {
    final value = args[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw ArgumentError('$key must be a non-empty string.');
    }
    return value;
  }

  static int _boundedInt(
    Object? value, {
    required int defaultValue,
    required int min,
    required int max,
  }) {
    final parsed = value is num ? value.toInt() : defaultValue;
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null) return null;
    if (value is! num || value < 0) {
      throw ArgumentError('offset must be a non-negative integer.');
    }
    return value.toInt();
  }

  static int? _optionalPositiveInt(Object? value, {required int max}) {
    if (value == null) return null;
    if (value is! num || value <= 0) {
      throw ArgumentError('limit must be a positive integer.');
    }
    final parsed = value.toInt();
    return parsed > max ? max : parsed;
  }

  static List<_TerminalEdit> _parseEdits(Map<String, dynamic> args) {
    final edits = <_TerminalEdit>[];
    final rawEdits = args['edits'];
    if (rawEdits is List) {
      for (final rawEdit in rawEdits) {
        if (rawEdit is! Map) continue;
        final oldText = rawEdit['oldText'];
        final newText = rawEdit['newText'];
        if (oldText is String && newText is String) {
          edits.add(_TerminalEdit(oldText: oldText, newText: newText));
        }
      }
    }
    final oldText = args['oldText'];
    final newText = args['newText'];
    if (edits.isEmpty && oldText is String && newText is String) {
      edits.add(_TerminalEdit(oldText: oldText, newText: newText));
    }
    return edits;
  }

  static int _countOccurrences(String source, String pattern) {
    if (pattern.isEmpty) return 0;
    var count = 0;
    var index = 0;
    while (true) {
      index = source.indexOf(pattern, index);
      if (index < 0) return count;
      count++;
      index += pattern.length;
    }
  }

  static String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  static String _toolError(String tool, String code, String message) {
    return jsonEncode({
      'type': 'tool_error',
      'tool': tool,
      'error': code,
      'message': message,
    });
  }
}

class _TerminalEdit {
  const _TerminalEdit({required this.oldText, required this.newText});

  final String oldText;
  final String newText;
}
