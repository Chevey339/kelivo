import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/mcp/mcp_tool_service.dart';
import '../../../core/services/memory_doc_store.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../search/services/global_session_search_service.dart';
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

  static String _toolError({
    required String error,
    required String message,
    required String tool,
    String? instruction,
  }) {
    return jsonEncode({
      'type': 'tool_error',
      'error': error,
      'message': message,
      'tool': tool,
      if (instruction != null) 'instruction': instruction,
    });
  }

  // ============================================================================
  // Tool Definitions Builder
  // ============================================================================

  /// Build tool definitions for API call.
  ///
  /// Returns a list of tool definitions including:
  /// - Search tool (if enabled and model supports tools)
  /// - Memory tools (if assistant has memory enabled)
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
    if (assistant?.searchEnabled == true &&
        !hasBuiltInSearch &&
        supportsTools) {
      toolDefs.add(SearchToolService.getToolDefinition());
    }

    // Memory tools
    if (assistant?.enableMemory == true && supportsTools) {
      toolDefs.addAll(_buildMemoryToolDefinitions());
      toolDefs.addAll(_buildMemoryArchiveToolDefinitions());
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

  /// Build memory archive tool definitions (past-chat search/read + long docs).
  ///
  /// These implement the catalog-then-fetch pattern: the system prompt only
  /// carries titles/summaries, and the model pulls full text on demand.
  List<Map<String, dynamic>> _buildMemoryArchiveToolDefinitions() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'search_past_chats',
          'description':
              'Search all past conversations on this device by keywords. '
              'Returns a catalog of matches (title, date, snippet, conversationId). '
              'Follow up with read_chat before quoting any detail.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description':
                    'Space-separated keywords. All keywords must appear in a conversation for it to match.',
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_chat',
          'description':
              'Read the original messages of one past conversation by conversationId '
              '(from search_past_chats). Returns the last part of the conversation.',
          'parameters': {
            'type': 'object',
            'properties': {
              'conversation_id': {
                'type': 'string',
                'description': 'The conversationId returned by search_past_chats',
              },
              'max_messages': {
                'type': 'integer',
                'description':
                    'Maximum number of messages to return, counted from the end. Default 30.',
              },
            },
            'required': ['conversation_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_memory_doc',
          'description':
              'Read the full text of one long-term memory doc listed in the '
              '<memory_docs> catalog. Never pretend to know doc content from the catalog alone.',
          'parameters': {
            'type': 'object',
            'properties': {
              'id': {
                'type': 'integer',
                'description': 'The doc id from the <memory_docs> catalog',
              },
            },
            'required': ['id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'write_memory_doc',
          'description':
              'Save a long text as a long-term memory doc. Use when the user asks to '
              'archive long content (notes, settings, excerpts). Only the title and summary '
              'will appear in future context; full text stays retrievable via read_memory_doc.',
          'parameters': {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'A short distinctive title',
              },
              'summary': {
                'type': 'string',
                'description': 'One-sentence summary shown in the catalog',
              },
              'content': {
                'type': 'string',
                'description': 'The full text to archive',
              },
            },
            'required': ['title', 'summary', 'content'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_memory_doc',
          'description': 'Delete an outdated long-term memory doc by id.',
          'parameters': {
            'type': 'object',
            'properties': {
              'id': {
                'type': 'integer',
                'description': 'The doc id from the <memory_docs> catalog',
              },
            },
            'required': ['id'],
          },
        },
      },
    ];
  }

  /// Build MCP tool definitions from connected servers.
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
    // Capture AssistantProvider reference before async gap to avoid
    // use_build_context_synchronously warning
    final assistantProvider = contextProvider.read<AssistantProvider>();

    return (name, args, {toolCallId}) async {
      try {
        // Search tool
        if (name == SearchToolService.toolName &&
            assistant?.searchEnabled == true) {
          final q = (args['query'] ?? '').toString();
          return await SearchToolService.executeSearch(q, settings);
        }

        // Memory tools
        final memoryResult = await _handleMemoryToolCall(name, args, assistant);
        if (memoryResult != null) {
          return memoryResult;
        }

        // Memory archive tools (past-chat search/read + long docs)
        final archiveResult = await _handleMemoryArchiveToolCall(
          name,
          args,
          assistant,
        );
        if (archiveResult != null) {
          return archiveResult;
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
            return _toolError(
              error: 'ask_user_unavailable',
              message: 'Ask user interaction service is unavailable.',
              tool: name,
            );
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
            return _toolError(
              error: 'invalid_ask_user_request',
              message: e.message,
              tool: name,
            );
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
            return _toolError(
              error: 'approval_denied',
              message: result.denyReason ?? 'User denied the tool call',
              tool: name,
            );
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
        return _toolError(
          error: 'execution_error',
          message: e.toString(),
          tool: name,
          instruction:
              'The tool execution failed unexpectedly. You may try again with different parameters or inform the user about the issue.',
        );
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
    if (name != 'create_memory' &&
        name != 'edit_memory' &&
        name != 'delete_memory') {
      return null;
    }

    try {
      final mp = contextProvider.read<MemoryProvider>();

      if (name == 'create_memory') {
        final content = (args['content'] ?? '').toString();
        if (content.isEmpty) {
          return _toolError(
            error: 'invalid_memory_content',
            message: 'Memory content must not be empty.',
            tool: name,
          );
        }
        final m = await mp.add(assistantId: assistant!.id, content: content);
        return m.content;
      } else if (name == 'edit_memory') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        final content = (args['content'] ?? '').toString();
        if (id <= 0) {
          return _toolError(
            error: 'invalid_memory_id',
            message: 'Memory id must be a positive integer.',
            tool: name,
          );
        }
        if (content.isEmpty) {
          return _toolError(
            error: 'invalid_memory_content',
            message: 'Memory content must not be empty.',
            tool: name,
          );
        }
        final m = await mp.update(id: id, content: content);
        if (m == null) {
          return _toolError(
            error: 'memory_not_found',
            message: 'No memory record was found for id $id.',
            tool: name,
            instruction:
                'Use the available memory records shown in context, or create a new memory instead of editing a missing one.',
          );
        }
        return m.content;
      } else if (name == 'delete_memory') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        if (id <= 0) {
          return _toolError(
            error: 'invalid_memory_id',
            message: 'Memory id must be a positive integer.',
            tool: name,
          );
        }
        final ok = await mp.delete(id: id);
        if (!ok) {
          return _toolError(
            error: 'memory_not_found',
            message: 'No memory record was found for id $id.',
            tool: name,
            instruction:
                'Use the available memory records shown in context, or skip deleting a missing memory.',
          );
        }
        return 'deleted';
      }
    } catch (e) {
      return _toolError(
        error: 'memory_execution_error',
        message: e.toString(),
        tool: name,
        instruction:
            'The memory tool failed. Retry only after correcting the parameters, or inform the user about the issue.',
      );
    }

    return null;
  }

  static const Set<String> _memoryArchiveToolNames = {
    'search_past_chats',
    'read_chat',
    'read_memory_doc',
    'write_memory_doc',
    'delete_memory_doc',
  };

  /// Handle memory archive tool calls (past-chat search/read + long docs).
  ///
  /// Returns null if the tool is not an archive tool or memory is not enabled.
  Future<String?> _handleMemoryArchiveToolCall(
    String name,
    Map<String, dynamic> args,
    Assistant? assistant,
  ) async {
    if (assistant?.enableMemory != true) return null;
    if (!_memoryArchiveToolNames.contains(name)) return null;

    try {
      if (name == 'search_past_chats') {
        final query = (args['query'] ?? '').toString().trim();
        if (query.isEmpty) {
          return _toolError(
            error: 'invalid_query',
            message: 'query must not be empty.',
            tool: name,
          );
        }
        final chatService = contextProvider.read<ChatService>();
        final results = GlobalSessionSearchService.search(
          chatService: chatService,
          query: query,
          limit: 8,
        );
        return jsonEncode({
          'results': [
            for (final r in results)
              {
                'conversation_id': r.conversationId,
                'title': r.conversationTitle,
                'date': r.updatedAt.toIso8601String().substring(0, 10),
                'snippet': r.snippet,
              },
          ],
          'note': results.isEmpty
              ? 'No past conversation matched all keywords. Try fewer or different keywords.'
              : 'Catalog entries only. Call read_chat with a conversation_id before quoting details.',
        });
      } else if (name == 'read_chat') {
        final id = (args['conversation_id'] ?? '').toString().trim();
        if (id.isEmpty) {
          return _toolError(
            error: 'invalid_conversation_id',
            message: 'conversation_id must not be empty.',
            tool: name,
          );
        }
        final chatService = contextProvider.read<ChatService>();
        final convo = chatService.getConversation(id);
        if (convo == null) {
          return _toolError(
            error: 'conversation_not_found',
            message: 'No conversation was found for id $id.',
            tool: name,
            instruction:
                'Use a conversation_id returned by search_past_chats.',
          );
        }
        final maxMessages = ((args['max_messages'] as num?)?.toInt() ?? 30)
            .clamp(1, 100);
        final visible = [
          for (final m in chatService.getMessages(id))
            if ((m.role == 'user' || m.role == 'assistant') &&
                m.content.trim().isNotEmpty)
              m,
        ];
        // Take messages from the end, bounded by count and a character budget.
        const charBudget = 12000;
        var used = 0;
        final lines = <String>[];
        for (final m in visible.reversed) {
          if (lines.length >= maxMessages) break;
          final line = '[${m.role}] ${m.content.trim()}';
          if (lines.isNotEmpty && used + line.length > charBudget) break;
          used += line.length;
          lines.add(line);
        }
        final buf = StringBuffer()
          ..writeln('Conversation: ${convo.title}')
          ..writeln(
            visible.length > lines.length
                ? '(showing last ${lines.length} of ${visible.length} messages)'
                : '(${lines.length} messages)',
          );
        for (final line in lines.reversed) {
          buf.writeln(line);
        }
        return buf.toString();
      } else if (name == 'read_memory_doc') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        if (id <= 0) {
          return _toolError(
            error: 'invalid_doc_id',
            message: 'Doc id must be a positive integer.',
            tool: name,
          );
        }
        final doc = await MemoryDocStore.getById(id);
        if (doc == null || doc.assistantId != assistant!.id) {
          return _toolError(
            error: 'doc_not_found',
            message: 'No memory doc was found for id $id.',
            tool: name,
            instruction: 'Use an id listed in the <memory_docs> catalog.',
          );
        }
        return '# ${doc.title}\n\n${doc.content}';
      } else if (name == 'write_memory_doc') {
        final title = (args['title'] ?? '').toString().trim();
        final summary = (args['summary'] ?? '').toString().trim();
        final content = (args['content'] ?? '').toString();
        if (title.isEmpty || summary.isEmpty || content.trim().isEmpty) {
          return _toolError(
            error: 'invalid_doc_fields',
            message: 'title, summary and content must all be non-empty.',
            tool: name,
          );
        }
        final doc = await MemoryDocStore.add(
          assistantId: assistant!.id,
          title: title,
          summary: summary,
          content: content,
        );
        return jsonEncode({
          'id': doc.id,
          'title': doc.title,
          'chars': doc.content.length,
        });
      } else if (name == 'delete_memory_doc') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        if (id <= 0) {
          return _toolError(
            error: 'invalid_doc_id',
            message: 'Doc id must be a positive integer.',
            tool: name,
          );
        }
        final doc = await MemoryDocStore.getById(id);
        if (doc == null || doc.assistantId != assistant!.id) {
          return _toolError(
            error: 'doc_not_found',
            message: 'No memory doc was found for id $id.',
            tool: name,
            instruction: 'Use an id listed in the <memory_docs> catalog.',
          );
        }
        await MemoryDocStore.delete(id: id);
        return 'deleted';
      }
    } catch (e) {
      return _toolError(
        error: 'memory_archive_execution_error',
        message: e.toString(),
        tool: name,
        instruction:
            'The memory archive tool failed. Retry only after correcting the parameters, or inform the user about the issue.',
      );
    }

    return null;
  }
}
