import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/skill_provider.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/mcp/mcp_tool_service.dart';
import '../../../core/services/search/search_tool_service.dart';
import 'ask_user_interaction_service.dart';
import 'local_tools_service.dart';
import 'tool_approval_service.dart';

/// 工具调用处理服务
///
/// 处理各类工具调用：
/// - MCP 工具
/// - Memory 工具 (create/edit/delete)
/// - Search 工具
class ToolHandlerService {
  ToolHandlerService({required this.contextProvider});

  /// Build context (used for accessing providers)
  final BuildContext contextProvider;

  // ============================================================================
  // Tool Schema Sanitization
  // ============================================================================

  /// Sanitize/translate JSON Schema to each provider's accepted subset.
  ///
  /// Different providers (Google, OpenAI, Claude) have different requirements
  /// for tool parameter schemas. This method normalizes schemas to work across
  /// all providers.
  static Map<String, dynamic> sanitizeToolParametersForProvider(
    Map<String, dynamic> schema,
    ProviderKind kind,
  ) {
    Map<String, dynamic> clone = _deepCloneMap(schema);
    clone = _sanitizeNode(clone, kind) as Map<String, dynamic>;
    return clone;
  }

  static dynamic _sanitizeNode(dynamic node, ProviderKind kind) {
    if (node is List) {
      return node.map((e) => _sanitizeNode(e, kind)).toList();
    }
    if (node is! Map) return node;

    final m = Map<String, dynamic>.from(node);
    // Remove $schema as it's not needed for tool definitions
    m.remove(r'$schema');

    // Convert 'const' to 'enum' for compatibility
    if (m.containsKey('const')) {
      final v = m['const'];
      if (v is String || v is num || v is bool) {
        m['enum'] = [v];
      }
      m.remove('const');
    }

    // Flatten anyOf/oneOf/allOf to first variant for simplicity
    for (final key in [
      'anyOf',
      'oneOf',
      'allOf',
      'any_of',
      'one_of',
      'all_of',
    ]) {
      if (m[key] is List && (m[key] as List).isNotEmpty) {
        final first = (m[key] as List).first;
        final flattened = _sanitizeNode(first, kind);
        m.remove(key);
        if (flattened is Map<String, dynamic>) {
          m
            ..remove('type')
            ..remove('properties')
            ..remove('items');
          m.addAll(flattened);
        }
      }
    }

    // Normalize type array to single type
    final t = m['type'];
    if (t is List && t.isNotEmpty) m['type'] = t.first.toString();

    // Normalize items array to single item
    final items = m['items'];
    if (items is List && items.isNotEmpty) m['items'] = items.first;
    if (m['items'] is Map) m['items'] = _sanitizeNode(m['items'], kind);

    // Recursively sanitize properties
    if (m['properties'] is Map) {
      final props = Map<String, dynamic>.from(m['properties']);
      final norm = <String, dynamic>{};
      props.forEach((k, v) {
        norm[k] = _sanitizeNode(v, kind);
      });
      m['properties'] = norm;
    }

    // Keep only allowed keys based on provider
    Set<String> allowed;
    switch (kind) {
      case ProviderKind.google:
        allowed = {
          'type',
          'description',
          'properties',
          'required',
          'items',
          'enum',
        };
        break;
      case ProviderKind.openai:
      case ProviderKind.claude:
        allowed = {
          'type',
          'description',
          'properties',
          'required',
          'items',
          'enum',
        };
        break;
    }
    m.removeWhere((k, v) => !allowed.contains(k));
    return m;
  }

  static Map<String, dynamic> _deepCloneMap(Map<String, dynamic> input) {
    return jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  }

  // ============================================================================
  // Tool Definitions Builder
  // ============================================================================

  /// Build tool definitions for API call.
  ///
  /// Returns a list of tool definitions including:
  /// - Search tool (if enabled and model supports tools)
  /// - Memory tools (if assistant has memory enabled)
  /// - Skill tools (use_skill, if assistant has enabled skills)
  /// - Local tools
  /// - MCP tools (from selected servers for the assistant)
  List<Map<String, dynamic>> buildToolDefinitions(
    SettingsProvider settings,
    Assistant? assistant,
    String providerKey,
    String modelId,
    bool hasBuiltInSearch, {
    required bool Function(String providerKey, String modelId) isToolModel,
  }) {
    final List<Map<String, dynamic>> toolDefs = <Map<String, dynamic>>[];
    final supportsTools = isToolModel(providerKey, modelId);

    // Search tool (skip when Gemini built-in search is active)
    if (settings.searchEnabled && !hasBuiltInSearch && supportsTools) {
      toolDefs.add(SearchToolService.getToolDefinition());
    }

    // Memory tools
    if (assistant?.enableMemory == true && supportsTools) {
      toolDefs.addAll(_buildMemoryToolDefinitions());
    }

    // Skill tool (use_skill)
    if (supportsTools && assistant != null && assistant.enabledSkills.isNotEmpty) {
      final skillDefs = _buildSkillToolDefinitions(assistant);
      toolDefs.addAll(skillDefs);
    }

    // Local tools
    toolDefs.addAll(
      LocalToolsService.buildToolDefinitions(
        assistant: assistant,
        supportsTools: supportsTools,
      ),
    );

    // MCP tools
    final mcpTools = _buildMcpToolDefinitions(
      settings: settings,
      assistant: assistant,
      providerKey: providerKey,
      supportsTools: supportsTools,
    );
    toolDefs.addAll(mcpTools);

    return toolDefs;
  }

  /// Build memory tool definitions (create/edit/delete).
  List<Map<String, dynamic>> _buildMemoryToolDefinitions() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'create_memory',
          'description': 'create a memory record',
          'parameters': {
            'type': 'object',
            'properties': {
              'content': {
                'type': 'string',
                'description': 'The content of the memory record',
              },
            },
            'required': ['content'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'edit_memory',
          'description': 'update a memory record',
          'parameters': {
            'type': 'object',
            'properties': {
              'id': {
                'type': 'integer',
                'description': 'The id of the memory record',
              },
              'content': {
                'type': 'string',
                'description': 'The content of the memory record',
              },
            },
            'required': ['id', 'content'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_memory',
          'description': 'delete a memory record',
          'parameters': {
            'type': 'object',
            'properties': {
              'id': {
                'type': 'integer',
                'description': 'The id of the memory record',
              },
            },
            'required': ['id'],
          },
        },
      },
    ];
  }

  /// Build use_skill tool definition.
  ///
  /// The `use_skill` tool lets the AI load skill content on-demand.
  /// Skills are listed in the system prompt; AI decides when to invoke.
  List<Map<String, dynamic>> _buildSkillToolDefinitions(Assistant assistant) {
    final skillProvider = contextProvider.read<SkillProvider>();
    final enabledSkills = skillProvider.listEnabledMetadata(
      assistant.enabledSkills.toSet(),
    );

    if (enabledSkills.isEmpty) return [];

    // Build a description listing all available skills
    final skillsDesc = StringBuffer();
    skillsDesc.writeln(
      'Load and apply a skill to get specialized instructions or capabilities. '
      'Call this tool when the user request matches one of the available skills.',
    );
    skillsDesc.writeln();
    skillsDesc.writeln('<available_skills>');
    for (final s in enabledSkills) {
      skillsDesc.writeln('  <skill>');
      skillsDesc.writeln('    <name>${s.name}</name>');
      if (s.description.isNotEmpty) {
        skillsDesc.writeln('    <description>${s.description}</description>');
      }
      skillsDesc.writeln('  </skill>');
    }
    skillsDesc.write('</available_skills>');

    return [
      {
        'type': 'function',
        'function': {
          'name': 'use_skill',
          'description': skillsDesc.toString(),
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'The name of the skill to use',
              },
              'path': {
                'type': 'string',
                'description':
                    'Optional relative path to a file inside the skill directory. '
                    'Omit to read the default SKILL.md instructions. '
                    'Only use paths explicitly listed in the SKILL.md content.',
              },
            },
            'required': ['name'],
          },
        },
      },
    ];
  }
  List<Map<String, dynamic>> _buildMcpToolDefinitions({
    required SettingsProvider settings,
    required Assistant? assistant,
    required String providerKey,
    required bool supportsTools,
  }) {
    if (!supportsTools) return [];

    final mcp = contextProvider.read<McpProvider>();
    final toolSvc = contextProvider.read<McpToolService>();
    final tools = toolSvc.listAvailableToolsForAssistant(
      mcp,
      contextProvider.read<AssistantProvider>(),
      assistant?.id,
    );

    if (tools.isEmpty) return [];

    final providerCfg = settings.getProviderConfig(providerKey);
    final providerKind = ProviderConfig.classify(
      providerCfg.id,
      explicitType: providerCfg.providerType,
    );

    return tools.map((t) {
      Map<String, dynamic> baseSchema;
      if (t.schema != null && t.schema!.isNotEmpty) {
        baseSchema = Map<String, dynamic>.from(t.schema!);
      } else {
        final props = <String, dynamic>{
          for (final p in t.params) p.name: {'type': (p.type ?? 'string')},
        };
        final required = [
          for (final p in t.params.where((e) => e.required)) p.name,
        ];
        baseSchema = {
          'type': 'object',
          'properties': props,
          if (required.isNotEmpty) 'required': required,
        };
      }
      final sanitized = sanitizeToolParametersForProvider(
        baseSchema,
        providerKind,
      );
      return {
        'type': 'function',
        'function': {
          'name': t.name,
          if ((t.description ?? '').isNotEmpty) 'description': t.description,
          'parameters': sanitized,
        },
      };
    }).toList();
  }

  // ============================================================================
  // Tool Call Handler
  // ============================================================================

  /// Build tool call handler function.
  ///
  /// Returns a function that handles tool calls by name and arguments.
  /// Supports:
  /// - Search tool calls
  /// - Memory tool calls (create/edit/delete)
  /// - MCP tool calls
  ToolCallHandler? buildToolCallHandler(
    SettingsProvider settings,
    Assistant? assistant, {
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
  }) {
    final mcp = contextProvider.read<McpProvider>();
    final toolSvc = contextProvider.read<McpToolService>();
    final skillProvider = contextProvider.read<SkillProvider>();
    // Capture AssistantProvider reference before async gap to avoid
    // use_build_context_synchronously warning
    final assistantProvider = contextProvider.read<AssistantProvider>();

    return (name, args, {toolCallId}) async {
      try {
        // Search tool
        if (name == SearchToolService.toolName && settings.searchEnabled) {
          final q = (args['query'] ?? '').toString();
          return await SearchToolService.executeSearch(q, settings);
        }

        // Skill tool (use_skill)
        if (name == 'use_skill') {
          if (assistant == null) {
            return jsonEncode({'error': 'No assistant configured'});
          }
          final skillName = (args['name'] ?? '').toString().trim();
          if (skillName.isEmpty) {
            return jsonEncode({'error': 'skill name is required'});
          }
          if (!assistant.enabledSkills.contains(skillName)) {
            return jsonEncode({
              'error': 'skill "$skillName" is not enabled',
              'instruction':
                  'Only enabled skills can be used. Available: ${assistant.enabledSkills.join(", ")}',
            });
          }
          final path = (args['path'] ?? '').toString().trim();
          final content = path.isEmpty
              ? skillProvider.readSkillBody(skillName)
              : skillProvider.readSkillFile(skillName, path);
          if (content == null) {
            return jsonEncode({'error': 'skill "$skillName"${path.isNotEmpty ? '/$path' : ''} not found'});
          }
          return content;
        }

        // Memory tools
        final memoryResult = await _handleMemoryToolCall(name, args, assistant);
        if (memoryResult != null) {
          return memoryResult;
        }

        // Local tools
        final localResult = await LocalToolsService.tryHandleToolCall(
          name,
          args,
          assistant,
          onSpeakText: (text) async {
            final tts = contextProvider.read<TtsProvider>();
            if (!tts.isAvailable) {
              throw StateError('Text-to-speech is unavailable.');
            }
            unawaited(
              tts.speak(text).catchError((Object error, StackTrace stack) {
                FlutterError.reportError(
                  FlutterErrorDetails(
                    exception: error,
                    stack: stack,
                    library: 'Kelivo local tools',
                    context: ErrorDescription('while playing text-to-speech'),
                  ),
                );
              }),
            );
          },
        );
        if (localResult != null) {
          return localResult;
        }

        if (name == LocalToolNames.askUser &&
            assistant != null &&
            assistant.localToolIds.contains(LocalToolNames.askUser)) {
          if (askUserService == null) {
            return jsonEncode({
              'type': 'tool_error',
              'error': 'ask_user_unavailable',
              'message': 'Ask user interaction service is unavailable.',
              'tool': name,
            });
          }
          try {
            final result = await askUserService.requestAnswer(
              toolCallId: (toolCallId?.trim().isNotEmpty == true)
                  ? toolCallId!.trim()
                  : '${name}_${DateTime.now().microsecondsSinceEpoch}',
              arguments: args,
            );
            return result.toJsonString();
          } on AskUserInvalidRequestException catch (e) {
            return jsonEncode({
              'type': 'tool_error',
              'error': 'invalid_ask_user_request',
              'message': e.message,
              'tool': name,
            });
          }
        }

        // Approval gate for MCP tools
        if (approvalService != null && mcp.toolNeedsApproval(name)) {
          // Generate a unique id for this tool call approval request
          final toolCallId = '${name}_${DateTime.now().microsecondsSinceEpoch}';
          final result = await approvalService.requestApproval(
            toolCallId: toolCallId,
            toolName: name,
            arguments: args,
          );
          if (!result.approved) {
            return jsonEncode({
              'type': 'tool_error',
              'error': 'approval_denied',
              'message': result.denyReason ?? 'User denied the tool call',
              'tool': name,
            });
          }
        }

        // MCP tools
        final text = await toolSvc.callToolTextForAssistant(
          mcp,
          assistantProvider,
          assistantId: assistant?.id,
          toolName: name,
          arguments: args,
        );
        return text;
      } catch (e) {
        // Catch unexpected exceptions and return error JSON to LLM
        // This prevents tool failures from terminating the chat flow
        return jsonEncode({
          'type': 'tool_error',
          'error': 'execution_error',
          'message': e.toString(),
          'tool': name,
          'instruction':
              'The tool execution failed unexpectedly. You may try again with different parameters or inform the user about the issue.',
        });
      }
    };
  }

  /// Handle memory tool calls (create/edit/delete).
  ///
  /// Returns null if the tool is not a memory tool or memory is not enabled.
  Future<String?> _handleMemoryToolCall(
    String name,
    Map<String, dynamic> args,
    Assistant? assistant,
  ) async {
    if (assistant?.enableMemory != true) return null;

    try {
      final mp = contextProvider.read<MemoryProvider>();

      if (name == 'create_memory') {
        final content = (args['content'] ?? '').toString();
        if (content.isEmpty) return '';
        final m = await mp.add(assistantId: assistant!.id, content: content);
        return m.content;
      } else if (name == 'edit_memory') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        final content = (args['content'] ?? '').toString();
        if (id <= 0 || content.isEmpty) return '';
        final m = await mp.update(id: id, content: content);
        return m?.content ?? '';
      } else if (name == 'delete_memory') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        if (id <= 0) return '';
        final ok = await mp.delete(id: id);
        return ok ? 'deleted' : '';
      }
    } catch (_) {
      // Ignore memory operation errors
    }

    return null;
  }
}
