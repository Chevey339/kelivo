import '../../../core/services/api/request_image_context.dart';
import '../../../core/services/api/request_tool_declarations.dart';
import 'package:Kelivo/core/services/conversation_tool_permissions.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/reasoning_request.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/environment_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/memory_provider_v2.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/api/builtin_tools.dart' as native_tools;
import '../../../core/services/api/json_schema_utils.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/browser/browser_tools_service.dart';
import '../../../core/services/mcp/mcp_tool_service.dart';
import '../../../core/services/memory/memory_pipeline.dart';
import '../../../core/services/memory/memory_tools.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/services/search/web_fetch_service.dart';
import '../../../core/services/search/web_fetch_tool_service.dart';
import '../../../core/services/tools/tool_schema_overrides.dart';
import '../../../core/services/tools/view_image_tool.dart';
import '../../../core/services/skills/skills_service.dart';
import '../../../core/services/workspace/tool_run_registry.dart';
import '../../../core/services/workspace/workspace_runtime.dart';
import '../../../core/services/workspace/workspace_tools_service.dart';
import '../../../core/providers/workspace_provider.dart';
import 'ask_user_interaction_service.dart';
import 'built_in_tool_names.dart';
import 'local_tools_service.dart';
import 'tool_approval_service.dart';

/// 工具调用处理服务
///
/// 处理各类工具调用：
/// - MCP 工具
/// - Memory 工具 (§10)
/// - Search 工具
class ToolHandlerService {
  ToolHandlerService({required this.contextProvider});

  /// Build context (used for accessing providers)
  final BuildContext contextProvider;

  WorkspaceToolsService _workspaceTools() {
    try {
      final chat = contextProvider.read<ChatService>();
      final workspaces = contextProvider.read<WorkspaceProvider>();
      final skills = contextProvider.read<SkillsService?>();
      return WorkspaceToolsService(
        registry: contextProvider.read<ToolRunRegistry>(),
        runtimeProvider: contextProvider.read<WorkspaceRuntimeProvider>(),
        updateConversationExtras: chat.updateConversationExtras,
        readPermissionState: ConversationToolPermissions.forChat(chat).read,
        permissionChanges: chat,
        touchLastUsed: workspaces.touchLastUsed,
        onSkillRead: skills?.incrementUseCount,
        refreshSkills: skills?.rescan,
        isLinkedSkillEntrypoint: skills?.isLinkedEntrypointTarget,
        loadEnvironment: contextProvider
            .read<EnvironmentProvider?>()
            ?.loadExecutionConfig,
        isToolEnabled: (id, name) =>
            workspaces.byId(id)?.isToolEnabled(name) ?? false,
      );
    } catch (_) {
      return WorkspaceToolsService();
    }
  }

  // ============================================================================
  // Tool Schema Sanitization
  // ============================================================================

  // Match the model segment, including names such as databricks-gemini-3-pro.
  static final _geminiRelayId = RegExp(
    r'^gemini-|[-_:]gemini-\d',
    caseSensitive: false,
  );

  /// Sanitize/translate JSON Schema to each provider's accepted subset.
  ///
  /// Different providers (Google, OpenAI, Claude) have different requirements
  /// for tool parameter schemas. This method normalizes schemas to work across
  /// all providers.
  static Map<String, dynamic> sanitizeToolParametersForProvider(
    Map<String, dynamic> schema,
    ProviderKind kind, {
    String? upstreamModelId,
    String? upstreamModelFamily,
  }) {
    final native = kind == ProviderKind.google;
    final input = _deepCloneMap(schema);
    final resolved = resolveJsonSchemaRefs(input, preserveJsonSchema: !native);
    final family = upstreamModelFamily?.toLowerCase();
    final geminiRelay =
        kind == ProviderKind.openai &&
        (family == 'gemini' ||
            (family?.startsWith('gemini-') ?? false) ||
            _geminiRelayId.hasMatch(upstreamModelId?.split('/').last ?? ''));
    if (!native && !geminiRelay) return resolved;
    if (geminiRelay &&
        identical(input, resolved) &&
        hasJsonSchemaReferences(resolved)) {
      return resolved;
    }
    return _sanitizeGoogleNode(resolved, native: native, parameterRoot: true)
        as Map<String, dynamic>;
  }

  static dynamic _sanitizeGoogleNode(
    dynamic node, {
    required bool native,
    bool parameterRoot = false,
  }) {
    if (node is List) {
      return [
        for (final child in node) _sanitizeGoogleNode(child, native: native),
      ];
    }
    if (node is! Map) return node;

    final m = Map<String, dynamic>.from(node);
    // Function parameters themselves must remain an object on both transports.
    if (!parameterRoot) {
      final alternatives = geminiRequiredObjectAlternatives(m, native: native);
      if (alternatives != null) {
        return {
          'anyOf': [
            for (final option in alternatives)
              _sanitizeGoogleNode(option, native: native),
          ],
        };
      }
    }
    if (native) {
      // A wrapper can delegate to its selected branch. When other validation
      // keywords are present, they must be processed in their own scope.
      final selected = firstStandaloneGoogleBranch(m);
      if (selected != null) {
        return _sanitizeGoogleNode(
          selected,
          native: true,
          parameterRoot: parameterRoot,
        );
      }
      _simplifyNativeGoogleNode(m);
    }
    if (m['items'] is Map || m['items'] is List) {
      m['items'] = _sanitizeGoogleNode(m['items'], native: native);
    }
    if (m['properties'] is Map) {
      m['properties'] = <String, dynamic>{
        for (final entry in (m['properties'] as Map).entries)
          entry.key as String: _sanitizeGoogleNode(entry.value, native: native),
      };
    }
    if (!native) {
      for (final key in ['anyOf', 'oneOf', 'allOf']) {
        if (m[key] is List) m[key] = _sanitizeGoogleNode(m[key], native: false);
      }
    }
    return m;
  }

  static void _simplifyNativeGoogleNode(Map<String, dynamic> m) {
    // Remove $schema as it's not needed for tool definitions
    m.remove(r'$schema');

    // Google's native Schema does not have const.
    if (m.containsKey('const')) {
      final v = m['const'];
      if (v is String || v is num || v is bool) {
        m['enum'] = [v];
        // Keep the declared type in sync so a non-string const is not mistaken
        // for a string enum downstream.
        if (m['type'] == null) {
          if (v is bool) {
            m['type'] = 'boolean';
          } else if (v is int) {
            m['type'] = 'integer';
          } else if (v is num) {
            m['type'] = 'number';
          } else {
            m['type'] = 'string';
          }
        }
      }
      m.remove('const');
    }

    for (final key in jsonSchemaCompositionKeywords) {
      final variants = m.remove(key);
      if (variants is! List || variants.isEmpty || variants.first is! Map) {
        continue;
      }
      final first = Map<String, dynamic>.from(variants.first as Map);
      _simplifyNativeGoogleNode(first);
      m
        ..remove('type')
        ..remove('properties')
        ..remove('items')
        ..addAll(first);
    }

    // Google's native Schema needs a single type.
    final t = m['type'];
    if (t is List && t.isNotEmpty) {
      m['type'] = t.first.toString();
    }

    // Keep Google's existing conversion of tuple-form items.
    final items = m['items'];
    if (items is List && items.isNotEmpty) {
      m['items'] = items.first;
    }
    const allowed = {
      'type',
      'description',
      'properties',
      'required',
      'items',
      'enum',
      'pattern',
    };
    if (m['type'] != 'string' || m['pattern'] is! String) m.remove('pattern');
    m.removeWhere((k, v) => !allowed.contains(k));
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

  McpToolRouteSnapshot captureMcpToolRoutes(
    Assistant? assistant, {
    String? conversationId,
  }) {
    return contextProvider.read<McpToolService>().captureRoutesForAssistant(
      contextProvider.read<McpProvider>(),
      contextProvider.read<AssistantProvider>(),
      assistantId: assistant?.id,
      conversation: conversationId == null
          ? null
          : contextProvider.read<ChatService>().getConversation(conversationId),
      reservedNames: BuiltInToolNames.all,
    );
  }

  /// Build tool definitions for API call.
  ///
  /// Returns a list of tool definitions including:
  /// - Search tool (if enabled and model supports tools)
  /// - Memory tools (if assistant has memory / past-recall enabled)
  /// - MCP tools (from the effective conversation or assistant selection)
  /// Whether the chat being generated is a throwaway one.
  ///
  /// Scheduled sends can target a different conversation from the visible one.
  bool _isTemporaryConversation(String? conversationId) {
    try {
      final chatService = contextProvider.read<ChatService>();
      return chatService.isTemporaryConversation(
        conversationId ?? chatService.currentConversationId,
      );
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> buildToolDefinitions(
    SettingsProvider settings,
    Assistant? assistant,
    String providerKey,
    String modelId,
    bool hasBuiltInSearch, {
    required bool Function(String providerKey, String modelId) isToolModel,
    McpToolRouteSnapshot? mcpRouteSnapshot,
    WorkspaceToolContext? workspaceContext,
    String? conversationId,
  }) {
    final List<Map<String, dynamic>> toolDefs = <Map<String, dynamic>>[];
    final supportsTools = isToolModel(providerKey, modelId);
    final model = ModelSpecResolver.instance.resolve(
      settings.getProviderConfig(providerKey),
      modelId,
    );
    final canImageInput = model.spec.supportsImageInput;

    // Search tool (skip when Gemini built-in search is active)
    if (assistant?.searchEnabled == true &&
        !hasBuiltInSearch &&
        supportsTools) {
      toolDefs.add(SearchToolService.getToolDefinition());
      if (settings.webFetchMode != WebFetchMode.off &&
          !native_tools.BuiltInToolsHelper.isBuiltInFetchEnabled(
            cfg: settings.getProviderConfig(providerKey),
            modelId: modelId,
          )) {
        toolDefs.add(WebFetchToolService.getToolDefinition());
      }
    }

    // Memory tools (§10.1)
    if (settings.legacyMemoryMode) {
      if (assistant?.enableMemory == true && supportsTools) {
        toolDefs.addAll(
          MemoryTools.legacyDefinitions(settings.resolvedMemoryPromptLang),
        );
      }
    } else if (supportsTools && assistant != null) {
      toolDefs.addAll(
        MemoryTools.buildDefinitions(
          lang: settings.resolvedMemoryPromptLang,
          writeScope: assistant.memoryWriteScope,
          enableMemory: assistant.enableMemory,
          allowPastConversationRecall: assistant.allowPastConversationRecall,
          allowMemoryWrites: !_isTemporaryConversation(conversationId),
        ),
      );
    }

    // Local tools
    toolDefs.addAll(
      LocalToolsService.buildToolDefinitions(
        assistant: assistant,
        supportsTools: supportsTools,
      ).where(
        (definition) =>
            (definition['function'] as Map)['name'] !=
                BrowserToolsService.toolName ||
            conversationId != null,
      ),
    );

    // MCP tools
    final mcpTools = _buildMcpToolDefinitions(
      settings: settings,
      assistant: assistant,
      providerKey: providerKey,
      model: model,
      supportsTools: supportsTools,
      mcpRouteSnapshot: mcpRouteSnapshot,
      conversationId: conversationId,
    );
    toolDefs.addAll(mcpTools);

    if (supportsTools && workspaceContext != null) {
      toolDefs.addAll(
        _workspaceTools()
            .buildToolDefinitions(workspaceContext)
            .where(
              (definition) =>
                  canImageInput ||
                  (definition['function'] as Map)['name'] != 'view_image',
            ),
      );
    }

    // Keep one candidate for images returned later in the tool loop. Each
    // outgoing request gates conversation lookup independently of file access.
    if (supportsTools && canImageInput && conversationId != null) {
      final index = toolDefs.indexWhere(
        (tool) => (tool['function'] as Map?)?['name'] == ViewImageTool.name,
      );
      if (index < 0) {
        toolDefs.add(ViewImageTool.withHistory());
      } else {
        toolDefs[index] = ViewImageTool.withHistory(toolDefs[index]);
      }
    }

    final overrides = settings.toolSchemaOverrides;
    if (overrides.isEmpty) return toolDefs;
    return ToolSchemaOverrides.apply(toolDefs, overrides);
  }

  /// Build MCP tool definitions from connected servers.
  List<Map<String, dynamic>> _buildMcpToolDefinitions({
    required SettingsProvider settings,
    required Assistant? assistant,
    required String providerKey,
    required ResolvedModelSpec model,
    required bool supportsTools,
    McpToolRouteSnapshot? mcpRouteSnapshot,
    String? conversationId,
  }) {
    if (!supportsTools) return [];

    final mcp = contextProvider.read<McpProvider>();
    final toolSvc = contextProvider.read<McpToolService>();
    final tools = toolSvc.listAvailableToolsForAssistant(
      mcp,
      contextProvider.read<AssistantProvider>(),
      assistant?.id,
      conversation: conversationId == null
          ? null
          : contextProvider.read<ChatService>().getConversation(conversationId),
      routeSnapshot: mcpRouteSnapshot,
      reservedNames: BuiltInToolNames.all,
    );

    if (tools.isEmpty) return [];

    final providerCfg = settings.getProviderConfig(providerKey);
    final providerKind = ProviderConfig.classify(
      providerCfg.id,
      explicitType: providerCfg.providerType,
    );
    final upstreamId = model.spec.upstreamId;
    final catalog = model.catalog?.model;
    // A lookup can fall back to the display alias. Only use family metadata
    // from the model that will actually receive the tool declaration.
    final family =
        catalog != null &&
            catalog.id.split('/').last.toLowerCase() ==
                upstreamId.split('/').last.toLowerCase()
        ? catalog.family
        : null;

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
        upstreamModelId: upstreamId,
        upstreamModelFamily: family,
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
  /// - Memory tool calls (§10)
  /// - MCP tool calls
  ToolCallHandler? buildToolCallHandler(
    SettingsProvider settings,
    Assistant? assistant, {
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
    String? conversationId,
    McpToolRouteSnapshot? mcpRouteSnapshot,
    WorkspaceToolContext? workspaceContext,
  }) {
    final mcp = contextProvider.read<McpProvider>();
    final toolSvc = contextProvider.read<McpToolService>();
    // Capture AssistantProvider reference before async gap to avoid
    // use_build_context_synchronously warning
    final assistantProvider = contextProvider.read<AssistantProvider>();
    ChatService? permissionChat;
    try {
      permissionChat = contextProvider.read<ChatService>();
    } catch (_) {}
    final routes =
        mcpRouteSnapshot ??
        toolSvc.captureRoutesForAssistant(
          mcp,
          assistantProvider,
          assistantId: assistant?.id,
          conversation: conversationId == null
              ? null
              : permissionChat?.getConversation(conversationId),
          reservedNames: BuiltInToolNames.all,
        );

    String approvalIdFor(String name, String? toolCallId) {
      final trimmed = toolCallId?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      return '${name}_${DateTime.now().microsecondsSinceEpoch}';
    }

    ToolCallPermission permissionFor(String name, String? toolCallId) =>
        ToolCallPermission(
          toolName: name,
          toolCallId: approvalIdFor(name, toolCallId),
          conversationId: conversationId,
          assistantId: assistant?.id,
          approvals: approvalService,
          stateChanges: permissionChat,
          readState: () => permissionChat != null && conversationId != null
              ? ConversationToolPermissions.forChat(
                  permissionChat,
                ).read(conversationId)
              : ToolPermissionState(assistantId: assistant?.id),
        );
    Future<Object?> approveAndExecuteMcp(
      String name,
      Map<String, dynamic> args,
      ToolCallPermission permission,
    ) async {
      void checkEnabled() {
        if (!toolSvc.isToolEnabledForAssistant(
          mcp,
          assistantProvider,
          assistantId: assistant?.id,
          conversation: conversationId == null
              ? null
              : permissionChat?.getConversation(conversationId),
          toolName: name,
          routeSnapshot: routes,
        )) {
          throw const ToolPermissionException(
            'tool_disabled',
            'This MCP tool is disabled',
          );
        }
      }

      checkEnabled();
      await permission.authorize(
        needed: toolSvc.toolNeedsApprovalForAssistant(
          mcp,
          assistantProvider,
          assistantId: assistant?.id,
          conversation: conversationId == null
              ? null
              : permissionChat?.getConversation(conversationId),
          toolName: name,
          routeSnapshot: routes,
          reservedNames: BuiltInToolNames.all,
        ),
        arguments: args,
      );
      checkEnabled();
      return toolSvc.callToolForAssistant(
        mcp,
        assistantProvider,
        assistantId: assistant?.id,
        conversation: conversationId == null
            ? null
            : permissionChat?.getConversation(conversationId),
        toolName: name,
        arguments: args,
        routeSnapshot: routes,
        reservedNames: BuiltInToolNames.all,
      );
    }

    final workspaceTools = workspaceContext == null ? null : _workspaceTools();
    final askUserEnabled =
        assistant?.localToolIds.contains(LocalToolNames.askUser) ?? false;

    return (name, args, {toolCallId}) async {
      final permission = permissionFor(name, toolCallId);
      Future<Object?> execute() async {
        try {
          if (name == ViewImageTool.name &&
              (args['image_id'] != null || args['path'] == null)) {
            if (args['path'] != null && args['image_id'] != null) {
              return _toolError(
                error: 'invalid_arguments',
                message: 'Supply either image_id or path, never both.',
                tool: name,
              );
            }
            final imageContext = RequestImageContext.current;
            final chat = permissionChat;
            if (imageContext == null ||
                conversationId == null ||
                chat == null) {
              return const ClientToolResult(
                'Image is unavailable in the current conversation context.',
              );
            }
            final imageSettings = await chat.imageContextSettings(
              conversationId,
            );
            if (!imageSettings.allowRecall) {
              return const ClientToolResult(
                'Image recall is disabled for this conversation. Ask the user to attach the image again if needed.',
              );
            }
            final allowed = await chat.imageContextHistory(
              conversationId,
              throughMessageId: imageContext.targetMessageId,
            );
            return imageContext.readImage(
              (args['image_id'] ?? '').toString(),
              allowedMessages: allowed.map((m) => m.id).toSet(),
              excluded: imageSettings.excluded,
              offset: args['offset'] is int ? args['offset'] as int : 0,
            );
          }
          if (name == ViewImageTool.name && workspaceContext == null) {
            return _toolError(
              error: 'tool_disabled',
              message:
                  'File viewing requires an enabled workspace image viewer.',
              tool: name,
            );
          }
          if (name == BrowserToolsService.toolName) {
            final current = assistant == null
                ? null
                : assistantProvider.getById(assistant.id);
            if (current == null ||
                !current.localToolIds.contains(LocalToolNames.browser) ||
                conversationId == null) {
              return _toolError(
                error: 'permission_denied',
                message:
                    'Browser control is disabled for this assistant or conversation.',
                tool: name,
              );
            }
            return await BrowserToolsService().handle(
              conversationId,
              args,
              capturePreview: settings.showBrowserPageCards,
              temporary: _isTemporaryConversation(conversationId),
            );
          }
          if (workspaceContext != null &&
              workspaceTools != null &&
              WorkspaceToolsService.toolNames.contains(name)) {
            return await workspaceTools.handle(
              workspaceContext,
              name,
              args,
              toolCallId: toolCallId ?? '',
              approvalService: approvalService,
              conversationId: conversationId,
            );
          }

          if (routes.containsExposedName(name)) {
            return await approveAndExecuteMcp(name, args, permission);
          }

          // Search tool
          if (name == SearchToolService.toolName &&
              assistant?.searchEnabled == true) {
            final q = (args['query'] ?? '').toString();
            return await SearchToolService.executeSearch(q, settings);
          }
          if (name == WebFetchToolService.toolName &&
              assistant?.searchEnabled == true) {
            return await WebFetchToolService.executeFetch(args, settings);
          }

          // Memory tools
          final memoryResult = await _handleMemoryToolCall(
            name,
            args,
            assistant,
            conversationId: conversationId,
          );
          if (memoryResult != null) {
            return memoryResult;
          }

          // Full access skips only the ordinary execution prompt.
          if (LocalToolNames.requiresUserApproval.contains(name)) {
            final current = assistant == null
                ? null
                : assistantProvider.getById(assistant.id);
            if (current == null || !current.localToolIds.contains(name)) {
              return _toolError(
                error: 'tool_disabled',
                message: 'This tool is disabled',
                tool: name,
              );
            }
            await permission.authorize(needed: true, arguments: args);
            final latest = assistantProvider.getById(current.id);
            if (latest == null || !latest.localToolIds.contains(name)) {
              return _toolError(
                error: 'tool_disabled',
                message: 'This tool is disabled',
                tool: name,
              );
            }
          }

          // Re-read phone-control permission on every call so disabling it also
          // stops a tool loop that was built with an older assistant snapshot.
          if (name == LocalToolNames.phoneControl) {
            final current = assistant == null
                ? null
                : assistantProvider.getById(assistant.id);
            if (current == null || !current.localToolIds.contains(name)) {
              return _toolError(
                error: 'permission_denied',
                message: 'Phone control is disabled for this assistant.',
                tool: name,
              );
            }
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

          if (name == LocalToolNames.askUser && askUserEnabled) {
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
                conversationId: conversationId,
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

          if (BuiltInToolNames.functions.contains(name)) {
            throw const ToolPermissionException(
              'tool_disabled',
              'This built-in tool is unavailable for this request.',
            );
          }

          final retryName = name == 'ask_user_input' && askUserEnabled
              ? RequestToolDeclarations.current?.advertisedName(
                  LocalToolNames.askUser,
                )
              : null;
          return _toolError(
            error: 'unknown_tool',
            message: 'Unknown tool name.',
            tool: name,
            instruction: retryName == null
                ? null
                : 'Retry using the full tool name `$retryName`.',
          );
        } on ToolPermissionException catch (e) {
          permission.byFullAccess = false;
          return ClientToolResult(
            _toolError(error: e.code, message: e.message, tool: name),
            metadata: {'toolPermissionError': e.code},
          );
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
      }

      final result = await execute();
      if (!permission.byFullAccess) return result;
      final client = ClientToolResult.fromHandler(result);
      return ClientToolResult(
        client.content,
        metadata: {...?client.metadata, 'toolPermission': 'fullAccess'},
      );
    };
  }

  /// Handle memory tool calls (§10).
  ///
  /// Returns null if the tool is not a memory tool or the relevant gate is off.
  Future<String?> _handleMemoryToolCall(
    String name,
    Map<String, dynamic> args,
    Assistant? assistant, {
    String? conversationId,
  }) async {
    final settings = contextProvider.read<SettingsProvider>();
    if (settings.legacyMemoryMode) {
      if (MemoryTools.allToolNames.contains(name)) return null;
      return _handleLegacyMemoryToolCall(name, args, assistant);
    }

    if (assistant == null) return null;
    if (!MemoryTools.allToolNames.contains(name)) return null;

    final memoryV2 = contextProvider.read<MemoryProviderV2>();
    ChatService? chatService;
    try {
      chatService = contextProvider.read<ChatService>();
    } catch (_) {
      chatService = null;
    }

    MemoryPipelineService? pipeline;
    try {
      pipeline = contextProvider.read<MemoryPipelineService>();
    } catch (_) {
      pipeline = null;
    }

    Future<String> Function(String prompt)? memoryLlmCall;
    final provKey = settings.memoryModelProvider;
    final mdlId = settings.memoryModelId;
    if (provKey != null && mdlId != null) {
      final cfg = settings.getProviderConfig(provKey);
      final reasoning = settings.memoryModelThinkingEnabled
          ? (assistant.reasoning ?? ReasoningRequest.auto)
          : ReasoningRequest.off;
      memoryLlmCall = (prompt) => ChatApiService.generateText(
        conversationId: conversationId,
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
        reasoning: reasoning,
      );
    }

    final temporary =
        chatService?.isTemporaryConversation(conversationId) ?? false;
    return MemoryTools.handle(
      name: name,
      args: args,
      assistant: assistant,
      repository: memoryV2.repository,
      chatRepository: memoryV2.chatRepository,
      chatService: chatService,
      conversationId: conversationId,
      // Reload without changing which assistants the open memory UI is showing.
      onMutated: memoryV2.reloadCurrentScope,
      smartAdd: pipeline?.smartAdd,
      promptLang: settings.resolvedMemoryPromptLang,
      memoryLlmCall: memoryLlmCall,
      smartAddPromptZh: settings.memorySmartAddPromptZh,
      smartAddPromptEn: settings.memorySmartAddPromptEn,
      // Temporary chats are discarded on exit; their tool traces must not linger.
      traceRecorder: temporary ? null : pipeline?.traceRecorder,
      conversationTitle: conversationId == null
          ? null
          : chatService?.getConversation(conversationId)?.title,
    );
  }

  /// Handle legacy create/edit/delete_memory calls via [MemoryProvider].
  ///
  /// Returns null if memory is disabled or [name] is not a legacy memory tool.
  Future<String?> _handleLegacyMemoryToolCall(
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
}
