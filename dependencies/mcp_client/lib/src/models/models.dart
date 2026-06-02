import 'package:meta/meta.dart';

/// Base content type enum for MCP
enum MessageRole { user, assistant, system }

enum MCPContentType { text, image, resource }

/// Log levels for MCP protocol
enum McpLogLevel {
  debug, // 0
  info, // 1
  notice, // 2
  warning, // 3
  error, // 4
  critical, // 5
  alert, // 6
  emergency, // 7
}

/// Base class for all MCP content types (2025-03-26 compliant)
@immutable
abstract class Content {
  const Content();

  Map<String, dynamic> toJson();

  factory Content.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'text' => TextContent.fromJson(json),
      'image' => ImageContent.fromJson(json),
      'audio' => AudioContent.fromJson(json),
      'resource' => ResourceContent.fromJson(json),
      'resource_link' => ResourceLinkContent.fromJson(json),
      _ => throw ArgumentError('Unknown content type: $type'),
    };
  }
}

/// Audio content (spec 2025-03-26+).
@immutable
class AudioContent extends Content {
  final String data;
  final String mimeType;
  final Map<String, dynamic>? annotations;

  const AudioContent({
    required this.data,
    required this.mimeType,
    this.annotations,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': 'audio',
      'data': data,
      'mimeType': mimeType,
    };
    if (annotations != null) json['annotations'] = annotations!;
    return json;
  }

  factory AudioContent.fromJson(Map<String, dynamic> json) {
    return AudioContent(
      data: json['data'] as String,
      mimeType: json['mimeType'] as String,
      annotations: json['annotations'] as Map<String, dynamic>?,
    );
  }
}

/// Resource link content (spec 2025-06-18+).
@immutable
class ResourceLinkContent extends Content {
  final String uri;
  final String? name;
  final String? description;
  final String? mimeType;
  final Map<String, dynamic>? annotations;
  final Map<String, dynamic>? meta;

  const ResourceLinkContent({
    required this.uri,
    this.name,
    this.description,
    this.mimeType,
    this.annotations,
    this.meta,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': 'resource_link', 'uri': uri};
    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;
    if (mimeType != null) json['mimeType'] = mimeType;
    if (annotations != null) json['annotations'] = annotations;
    if (meta != null) json['_meta'] = meta;
    return json;
  }

  factory ResourceLinkContent.fromJson(Map<String, dynamic> json) {
    return ResourceLinkContent(
      uri: json['uri'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
      annotations: json['annotations'] as Map<String, dynamic>?,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }
}

/// Text content representation
@immutable
class TextContent extends Content {
  final String text;
  final Map<String, dynamic>? annotations;

  const TextContent({required this.text, this.annotations});

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': 'text', 'text': text};
    if (annotations != null) json['annotations'] = annotations!;
    return json;
  }

  factory TextContent.fromJson(Map<String, dynamic> json) {
    return TextContent(
      text: json['text'] as String,
      annotations: json['annotations'] as Map<String, dynamic>?,
    );
  }
}

/// Image content representation
@immutable
class ImageContent extends Content {
  final String? url;
  final String? data;
  final String mimeType;
  final Map<String, dynamic>? annotations;

  const ImageContent({
    this.url,
    this.data,
    required this.mimeType,
    this.annotations,
  });

  factory ImageContent.fromBase64({
    required String data,
    required String mimeType,
  }) {
    return ImageContent(data: data, mimeType: mimeType);
  }

  factory ImageContent.fromJson(Map<String, dynamic> json) {
    return ImageContent(
      url: json['url'] as String?,
      data: json['data'] as String?,
      mimeType: json['mimeType'] as String,
      annotations: json['annotations'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': 'image', 'mimeType': mimeType};

    // 2025 spec uses 'data' for base64, but maintain 'url' for compatibility
    if (data != null) {
      json['data'] = data!;
    } else if (url != null) {
      json['url'] = url!;
    }

    if (annotations != null) json['annotations'] = annotations!;
    return json;
  }
}

/// Resource content representation
@immutable
class ResourceContent extends Content {
  final String uri;
  final String? text;
  final String? blob;
  final String? mimeType;
  final Map<String, dynamic>? annotations;

  const ResourceContent({
    required this.uri,
    this.text,
    this.blob,
    this.mimeType,
    this.annotations,
  });

  @override
  Map<String, dynamic> toJson() {
    final resource = <String, dynamic>{'uri': uri};
    if (text != null) resource['text'] = text!;
    if (blob != null) resource['blob'] = blob!;
    if (mimeType != null) resource['mimeType'] = mimeType!;

    final json = <String, dynamic>{'type': 'resource', 'resource': resource};
    if (annotations != null) json['annotations'] = annotations!;
    return json;
  }

  factory ResourceContent.fromJson(Map<String, dynamic> json) {
    // Handle both 2025 format (nested) and older format (flat)
    final resource = json['resource'] as Map<String, dynamic>?;
    if (resource != null) {
      // 2025 format with nested resource
      return ResourceContent(
        uri: resource['uri'] as String,
        text: resource['text'] as String?,
        blob: resource['blob'] as String?,
        mimeType: resource['mimeType'] as String?,
        annotations: json['annotations'] as Map<String, dynamic>?,
      );
    } else {
      // Older flat format
      return ResourceContent(
        uri: json['uri'] as String,
        text: json['text'] as String?,
        blob: json['blob'] as String?,
        mimeType: json['mimeType'] as String?,
        annotations: json['annotations'] as Map<String, dynamic>?,
      );
    }
  }
}

/// Tool definition. Spec 2025-06-18+ added `outputSchema`, `_meta`,
/// and the `title` display name (separate from programmatic `name`).
/// Spec 2025-11-25+ added `icons`.
@immutable
class Tool {
  final String name;

  /// Spec 2025-06-18+: human-readable display name; falls back to [name]
  /// when null.
  final String? title;
  final String description;
  final Map<String, dynamic> inputSchema;

  /// Spec 2025-06-18+: optional JSON Schema describing the structured
  /// result this tool produces.
  final Map<String, dynamic>? outputSchema;

  /// Spec 2025-11-25+: visual metadata (icon objects with `src`,
  /// optional `sizes` and `mimeType`).
  final List<Map<String, dynamic>>? icons;

  /// Spec 2025-06-18+: free-form metadata.
  final Map<String, dynamic>? meta;

  final bool? supportsProgress;
  final bool? supportsCancellation;
  final Map<String, dynamic>? metadata;

  const Tool({
    required this.name,
    this.title,
    required this.description,
    required this.inputSchema,
    this.outputSchema,
    this.icons,
    this.meta,
    this.supportsProgress,
    this.supportsCancellation,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
    if (title != null) json['title'] = title;
    if (outputSchema != null) json['outputSchema'] = outputSchema;
    if (icons != null) json['icons'] = icons;
    if (meta != null) json['_meta'] = meta;
    if (supportsProgress == true) {
      json['supportsProgress'] = supportsProgress;
    }
    if (supportsCancellation == true) {
      json['supportsCancellation'] = supportsCancellation;
    }
    if (metadata != null) json['metadata'] = metadata!;
    return json;
  }

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      name: json['name'] as String,
      title: json['title'] as String?,
      description: json['description'] as String? ?? '',
      inputSchema: json['inputSchema'] as Map<String, dynamic>,
      outputSchema: json['outputSchema'] as Map<String, dynamic>?,
      icons:
          (json['icons'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      meta: json['_meta'] as Map<String, dynamic>?,
      supportsProgress: json['supportsProgress'] as bool?,
      supportsCancellation: json['supportsCancellation'] as bool?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Tool call result. Spec 2025-06-18 added `structuredContent`
/// (paired with `Tool.outputSchema`).
@immutable
class CallToolResult {
  final List<Content> content;
  final Map<String, dynamic>? structuredContent;
  final bool isStreaming;
  final bool? isError;

  const CallToolResult(
    this.content, {
    this.structuredContent,
    this.isStreaming = false,
    this.isError,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content.map((c) => c.toJson()).toList(),
      if (structuredContent != null) 'structuredContent': structuredContent,
      'isStreaming': isStreaming,
      if (isError != null) 'isError': isError,
    };
  }

  factory CallToolResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> contentList = json['content'] as List<dynamic>? ?? [];
    final List<Content> contents =
        contentList.map((contentData) {
          final contentMap = contentData as Map<String, dynamic>;
          return Content.fromJson(contentMap);
        }).toList();

    return CallToolResult(
      contents,
      structuredContent: json['structuredContent'] as Map<String, dynamic>?,
      isStreaming: json['isStreaming'] as bool? ?? false,
      isError: json['isError'] as bool?,
    );
  }
}

/// Resource definition
@immutable
class Resource {
  final String uri;
  final String name;

  /// Spec 2025-06-18+: human-readable display name. Falls back to [name].
  final String? title;
  final String description;
  final String? mimeType;

  /// Spec 2025-11-25+: visual metadata (icon objects).
  final List<Map<String, dynamic>>? icons;

  /// Spec 2025-06-18+: free-form `_meta` map.
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? metadata;

  const Resource({
    required this.uri,
    required this.name,
    this.title,
    required this.description,
    this.mimeType,
    this.icons,
    this.meta,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'uri': uri,
      'name': name,
      'description': description,
    };
    if (title != null) json['title'] = title;
    if (mimeType != null) json['mimeType'] = mimeType;
    if (icons != null) json['icons'] = icons;
    if (meta != null) json['_meta'] = meta;
    if (metadata != null) json['metadata'] = metadata!;
    return json;
  }

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      uri: json['uri'] as String,
      name: json['name'] as String,
      title: json['title'] as String?,
      description: json['description'] as String,
      mimeType: json['mimeType'] as String?,
      icons:
          (json['icons'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      meta: json['_meta'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Resource template definition
@immutable
class ResourceTemplate {
  final String uriTemplate;
  final String name;
  final String description;
  final String? mimeType;

  const ResourceTemplate({
    required this.uriTemplate,
    required this.name,
    required this.description,
    this.mimeType,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'uriTemplate': uriTemplate,
      'name': name,
      'description': description,
    };
    if (mimeType != null) {
      result['mimeType'] = mimeType;
    }
    return result;
  }

  factory ResourceTemplate.fromJson(Map<String, dynamic> json) {
    return ResourceTemplate(
      uriTemplate: json['uriTemplate'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// Resource content
@immutable
class ResourceContentInfo {
  final String uri;
  final String? mimeType;
  final String? text;
  final String? blob;

  const ResourceContentInfo({
    required this.uri,
    this.mimeType,
    this.text,
    this.blob,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'uri': uri};
    if (mimeType != null) result['mimeType'] = mimeType;
    if (text != null) result['text'] = text;
    if (blob != null) result['blob'] = blob;
    return result;
  }

  factory ResourceContentInfo.fromJson(Map<String, dynamic> json) {
    return ResourceContentInfo(
      uri: json['uri'] as String,
      mimeType: json['mimeType'] as String?,
      text: json['text'] as String?,
      blob: json['blob'] as String?,
    );
  }
}

/// Resource read result
@immutable
class ReadResourceResult {
  final List<ResourceContentInfo> contents;

  const ReadResourceResult({required this.contents});

  Map<String, dynamic> toJson() {
    return {'contents': contents.map((c) => c.toJson()).toList()};
  }

  factory ReadResourceResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> contentsList = json['contents'] as List<dynamic>? ?? [];
    final contents =
        contentsList
            .map(
              (content) =>
                  ResourceContentInfo.fromJson(content as Map<String, dynamic>),
            )
            .toList();

    return ReadResourceResult(contents: contents);
  }
}

/// Prompt argument definition
@immutable
class PromptArgument {
  final String name;
  final String? description;
  final bool required;
  final String? defaultValue;

  const PromptArgument({
    required this.name,
    this.description,
    this.required = false,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'name': name, 'required': required};
    if (description != null) {
      result['description'] = description!;
    }
    if (defaultValue != null) {
      result['default'] = defaultValue as Object;
    }
    return result;
  }

  factory PromptArgument.fromJson(Map<String, dynamic> json) {
    return PromptArgument(
      name: json['name'] as String,
      description: json['description'] as String?,
      required: json['required'] as bool? ?? false,
      defaultValue: json['default'] as String?,
    );
  }
}

/// Prompt definition
@immutable
class Prompt {
  final String name;

  /// Spec 2025-06-18+: human-readable display name.
  final String? title;
  final String? description;
  final List<PromptArgument> arguments;

  /// Spec 2025-11-25+: visual metadata.
  final List<Map<String, dynamic>>? icons;

  /// Spec 2025-06-18+: `_meta` map.
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? metadata;

  const Prompt({
    required this.name,
    this.title,
    this.description,
    required this.arguments,
    this.icons,
    this.meta,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'arguments': arguments.map((arg) => arg.toJson()).toList(),
    };
    if (title != null) json['title'] = title!;
    if (description != null) json['description'] = description!;
    if (icons != null) json['icons'] = icons!;
    if (meta != null) json['_meta'] = meta!;
    if (metadata != null) json['metadata'] = metadata!;
    return json;
  }

  factory Prompt.fromJson(Map<String, dynamic> json) {
    final List<dynamic> argsList = json['arguments'] as List<dynamic>? ?? [];
    final arguments =
        argsList
            .map((arg) => PromptArgument.fromJson(arg as Map<String, dynamic>))
            .toList();

    return Prompt(
      name: json['name'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      arguments: arguments,
      icons:
          (json['icons'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      meta: json['_meta'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Message model for prompt system
@immutable
class Message {
  final String role;
  final Content content;

  const Message({required this.role, required this.content});

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content.toJson()};
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final contentMap = json['content'] as Map<String, dynamic>;

    return Message(
      role: json['role'] as String,
      content: Content.fromJson(contentMap),
    );
  }
}

/// Get prompt result
@immutable
class GetPromptResult {
  final String? description;
  final List<Message> messages;

  const GetPromptResult({this.description, required this.messages});

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    if (description != null) result['description'] = description!;
    return result;
  }

  factory GetPromptResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> messagesList = json['messages'] as List<dynamic>? ?? [];
    final messages =
        messagesList
            .map((message) => Message.fromJson(message as Map<String, dynamic>))
            .toList();

    return GetPromptResult(
      description: json['description'] as String?,
      messages: messages,
    );
  }
}

/// Model hint for sampling
@immutable
class ModelHint {
  final String name;
  final double? weight;

  const ModelHint({required this.name, this.weight});

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'name': name};
    if (weight != null) {
      result['weight'] = weight;
    }
    return result;
  }

  factory ModelHint.fromJson(Map<String, dynamic> json) {
    return ModelHint(
      name: json['name'] as String,
      weight:
          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    );
  }
}

/// Model preferences for sampling
@immutable
class ModelPreferences {
  final List<ModelHint>? hints;
  final double? costPriority;
  final double? speedPriority;
  final double? intelligencePriority;

  const ModelPreferences({
    this.hints,
    this.costPriority,
    this.speedPriority,
    this.intelligencePriority,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (hints != null && hints!.isNotEmpty) {
      result['hints'] = hints!.map((h) => h.toJson()).toList();
    }
    if (costPriority != null) {
      result['costPriority'] = costPriority;
    }
    if (speedPriority != null) {
      result['speedPriority'] = speedPriority;
    }
    if (intelligencePriority != null) {
      result['intelligencePriority'] = intelligencePriority;
    }
    return result;
  }

  factory ModelPreferences.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? hintsList = json['hints'] as List<dynamic>?;
    final hints =
        hintsList
            ?.map((hint) => ModelHint.fromJson(hint as Map<String, dynamic>))
            .toList();

    return ModelPreferences(
      hints: hints,
      costPriority:
          json['costPriority'] != null
              ? (json['costPriority'] as num).toDouble()
              : null,
      speedPriority:
          json['speedPriority'] != null
              ? (json['speedPriority'] as num).toDouble()
              : null,
      intelligencePriority:
          json['intelligencePriority'] != null
              ? (json['intelligencePriority'] as num).toDouble()
              : null,
    );
  }
}

/// Create message request for sampling
@immutable
class CreateMessageRequest {
  final List<Message> messages;
  final ModelPreferences? modelPreferences;
  final String? systemPrompt;
  final String? includeContext;
  final int? maxTokens;
  final double? temperature;
  final List<String>? stopSequences;
  final Map<String, dynamic>? metadata;

  const CreateMessageRequest({
    required this.messages,
    this.modelPreferences,
    this.systemPrompt,
    this.includeContext,
    this.maxTokens,
    this.temperature,
    this.stopSequences,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    if (modelPreferences != null) {
      result['modelPreferences'] = modelPreferences!.toJson();
    }
    if (systemPrompt != null) {
      result['systemPrompt'] = systemPrompt;
    }
    if (includeContext != null) {
      result['includeContext'] = includeContext;
    }
    if (maxTokens != null) {
      result['maxTokens'] = maxTokens;
    }
    if (temperature != null) {
      result['temperature'] = temperature;
    }
    if (stopSequences != null && stopSequences!.isNotEmpty) {
      result['stopSequences'] = stopSequences;
    }
    if (metadata != null && metadata!.isNotEmpty) {
      result['metadata'] = Map<String, dynamic>.from(metadata!);
    }
    return result;
  }

  factory CreateMessageRequest.fromJson(Map<String, dynamic> json) {
    final List<dynamic> messagesList = json['messages'] as List<dynamic>? ?? [];
    final messages =
        messagesList
            .map((message) => Message.fromJson(message as Map<String, dynamic>))
            .toList();

    final List<dynamic>? stopSequencesList =
        json['stopSequences'] as List<dynamic>?;
    final stopSequences =
        stopSequencesList?.map((sequence) => sequence as String).toList();

    return CreateMessageRequest(
      messages: messages,
      modelPreferences:
          json['modelPreferences'] != null
              ? ModelPreferences.fromJson(
                json['modelPreferences'] as Map<String, dynamic>,
              )
              : null,
      systemPrompt: json['systemPrompt'] as String?,
      includeContext: json['includeContext'] as String?,
      maxTokens: json['maxTokens'] as int?,
      temperature:
          json['temperature'] != null
              ? (json['temperature'] as num).toDouble()
              : null,
      stopSequences: stopSequences,
      metadata:
          json['metadata'] != null
              ? (json['metadata'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>()
              : null,
    );
  }
}

/// Create message result from sampling
@immutable
class CreateMessageResult {
  final String model;
  final String? stopReason;
  final String role;
  final Content content;

  const CreateMessageResult({
    required this.model,
    this.stopReason,
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'model': model,
      'role': role,
      'content': content.toJson(),
    };
    if (stopReason != null) {
      result['stopReason'] = stopReason;
    }
    return result;
  }

  factory CreateMessageResult.fromJson(Map<String, dynamic> json) {
    final contentMap = json['content'] as Map<String, dynamic>;

    return CreateMessageResult(
      model: json['model'] as String,
      stopReason: json['stopReason'] as String?,
      role: json['role'] as String,
      content: Content.fromJson(contentMap),
    );
  }
}

/// Root definition for filesystem access
@immutable
class Root {
  final String uri;
  final String name;
  final String? description;

  const Root({required this.uri, required this.name, this.description});

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'uri': uri, 'name': name};
    if (description != null) {
      result['description'] = description;
    }
    return result;
  }

  factory Root.fromJson(Map<String, dynamic> json) {
    return Root(
      uri: json['uri'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

/// Error class for MCP-related errors
@immutable
class McpError implements Exception {
  final String message;
  final int? code;

  const McpError(this.message, {this.code});

  @override
  String toString() => 'McpError ${code != null ? '($code)' : ''}: $message';
}

/// JSON-RPC message
@immutable
class JsonRpcMessage {
  final String jsonrpc;
  final dynamic id;
  final String? method;
  final Map<String, dynamic>? params;
  final dynamic result;
  final Map<String, dynamic>? error;

  bool get isNotification => id == null && method != null;
  bool get isRequest => id != null && method != null;
  bool get isResponse => id != null && (result != null || error != null);

  const JsonRpcMessage({
    required this.jsonrpc,
    this.id,
    this.method,
    this.params,
    this.result,
    this.error,
  });

  factory JsonRpcMessage.fromJson(Map<String, dynamic> json) {
    // Ensure params is properly typed as Map<String, dynamic>
    Map<String, dynamic>? params;
    if (json['params'] != null) {
      if (json['params'] is Map) {
        params =
            (json['params'] as Map<dynamic, dynamic>).cast<String, dynamic>();
      } else {
        throw FormatException(
          'Invalid params: expected a Map, got ${json['params'].runtimeType}',
        );
      }
    }

    // Ensure error is properly typed as Map<String, dynamic>
    Map<String, dynamic>? error;
    if (json['error'] != null) {
      if (json['error'] is Map) {
        error =
            (json['error'] as Map<dynamic, dynamic>).cast<String, dynamic>();
      } else {
        throw FormatException(
          'Invalid error: expected a Map, got ${json['error'].runtimeType}',
        );
      }
    }

    return JsonRpcMessage(
      jsonrpc: json['jsonrpc'] as String,
      id: json['id'],
      method: json['method'] as String?,
      params: params,
      result: json['result'],
      error: error,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'jsonrpc': jsonrpc};
    if (id != null) json['id'] = id;
    if (method != null) json['method'] = method!;
    if (params != null) json['params'] = params!;
    if (result != null) json['result'] = result;
    if (error != null) json['error'] = error!;
    return json;
  }
}

/// Server health information
@immutable
class ServerHealth {
  /// Health status (e.g., 'healthy', 'degraded', 'unhealthy')
  final String status;

  /// Server version
  final String? version;

  /// Number of active connections
  final int connections;

  /// Whether the server is running
  final bool isRunning;

  /// Number of connected client sessions
  final int connectedSessions;

  /// Number of registered tools
  final int registeredTools;

  /// Number of registered resources
  final int registeredResources;

  /// Number of registered prompts
  final int registeredPrompts;

  /// When the server started
  final DateTime startTime;

  /// How long the server has been running
  final Duration uptime;

  /// Detailed performance metrics
  final Map<String, dynamic> metrics;

  const ServerHealth({
    this.status = 'healthy',
    this.version,
    this.connections = 0,
    required this.isRunning,
    required this.connectedSessions,
    required this.registeredTools,
    required this.registeredResources,
    required this.registeredPrompts,
    required this.startTime,
    required this.uptime,
    required this.metrics,
  });

  factory ServerHealth.fromJson(Map<String, dynamic> json) {
    return ServerHealth(
      status: json['status'] as String? ?? 'healthy',
      version: json['version'] as String?,
      connections: json['connections'] as int? ?? 0,
      isRunning: json['isRunning'] as bool? ?? true,
      connectedSessions: json['connectedSessions'] as int? ?? 0,
      registeredTools: json['registeredTools'] as int? ?? 0,
      registeredResources: json['registeredResources'] as int? ?? 0,
      registeredPrompts: json['registeredPrompts'] as int? ?? 0,
      startTime:
          json['startTime'] != null
              ? DateTime.parse(json['startTime'] as String)
              : DateTime.now(),
      uptime:
          json['uptimeSeconds'] != null
              ? Duration(seconds: json['uptimeSeconds'] as int)
              : Duration.zero,
      metrics: json['metrics'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'connectedSessions': connectedSessions,
      'registeredTools': registeredTools,
      'registeredResources': registeredResources,
      'registeredPrompts': registeredPrompts,
      'startTime': startTime.toIso8601String(),
      'uptimeSeconds': uptime.inSeconds,
      'metrics': metrics,
    };
  }
}

/// Pending operation for cancellation support
class PendingOperation {
  /// Unique identifier for this operation
  final String id;

  /// Session ID where this operation is running
  final String sessionId;

  /// Type of the operation (e.g., "tool:calculator")
  final String type;

  /// When the operation was created
  final DateTime createdAt;

  /// Optional ID of the request that initiated this operation
  final String? requestId;

  /// Whether this operation has been cancelled
  bool isCancelled = false;

  PendingOperation({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.createdAt,
    this.requestId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'isCancelled': isCancelled,
      if (requestId != null) 'requestId': requestId,
    };
  }

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    final operation = PendingOperation(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      requestId: json['requestId'] as String?,
    );
    operation.isCancelled = json['isCancelled'] as bool? ?? false;
    return operation;
  }
}

/// Progress update for long-running operations
@immutable
class ProgressUpdate {
  /// ID of the request this progress relates to
  final String requestId;

  /// Progress value between 0.0 and 1.0
  final double progress;

  /// Optional message describing the current status
  final String message;

  const ProgressUpdate({
    required this.requestId,
    required this.progress,
    required this.message,
  });

  factory ProgressUpdate.fromJson(Map<String, dynamic> json) {
    return ProgressUpdate(
      requestId: json['requestId'] as String,
      progress: (json['progress'] as num).toDouble(),
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'requestId': requestId, 'progress': progress, 'message': message};
  }
}

/// Cached resource item for performance optimization
@immutable
class CachedResource {
  /// URI of the cached resource
  final String uri;

  /// Content of the resource
  final ReadResourceResult content;

  /// When the resource was cached
  final DateTime cachedAt;

  /// How long the cache should be valid
  final Duration maxAge;

  const CachedResource({
    required this.uri,
    required this.content,
    required this.cachedAt,
    required this.maxAge,
  });

  /// Check if the cache entry has expired
  bool get isExpired {
    final now = DateTime.now();
    final expiresAt = cachedAt.add(maxAge);
    return now.isAfter(expiresAt);
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'content': content.toJson(),
      'cachedAt': cachedAt.toIso8601String(),
      'maxAgeSeconds': maxAge.inSeconds,
    };
  }
}

/// Server information (2025-03-26 compliant)
@immutable
class ServerInfo {
  final String name;
  final String version;
  final String? protocolVersion;
  final Map<String, dynamic>? capabilities;
  final Map<String, dynamic>? metadata;

  const ServerInfo({
    required this.name,
    required this.version,
    this.protocolVersion,
    this.capabilities,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name, 'version': version};
    if (protocolVersion != null) json['protocolVersion'] = protocolVersion!;
    if (capabilities != null) json['capabilities'] = capabilities!;
    if (metadata != null) json['metadata'] = metadata!;
    return json;
  }

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      name: json['name'] as String,
      version: json['version'] as String,
      protocolVersion: json['protocolVersion'] as String?,
      capabilities: json['capabilities'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Client information (2025-03-26 compliant)
@immutable
class ClientInfo {
  final String name;
  final String version;
  final Map<String, dynamic>? capabilities;
  final Map<String, dynamic>? metadata;

  const ClientInfo({
    required this.name,
    required this.version,
    this.capabilities,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name, 'version': version};
    if (capabilities != null) json['capabilities'] = capabilities!;
    if (metadata != null) json['metadata'] = metadata!;
    return json;
  }

  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      name: json['name'] as String,
      version: json['version'] as String,
      capabilities: json['capabilities'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Client capabilities configuration
@immutable
class ClientCapabilities {
  /// Root management support — server may request `roots/list` and the
  /// client responds with [Client.roots].
  final bool roots;

  /// Whether roots list changes are sent as notifications
  final bool rootsListChanged;

  /// Sampling support — host's LLM is reachable through this client (the
  /// server can ask for completions via `sampling/createMessage`).
  final bool sampling;

  /// Elicitation support — server can request user input via
  /// `elicitation/create` (spec 2025-06-18+).
  final bool elicitation;

  /// Create a capabilities object with specified settings
  const ClientCapabilities({
    this.roots = false,
    this.rootsListChanged = false,
    this.sampling = false,
    this.elicitation = false,
  });

  /// Convert capabilities to JSON
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (roots) {
      result['roots'] = {'listChanged': rootsListChanged};
    }

    if (sampling) {
      result['sampling'] = {};
    }

    if (elicitation) {
      result['elicitation'] = {};
    }

    return result;
  }

  factory ClientCapabilities.fromJson(Map<String, dynamic> json) {
    final rootsConfig = json['roots'] as Map<String, dynamic>?;
    final samplingConfig = json['sampling'] as Map<String, dynamic>?;
    final elicitationConfig = json['elicitation'] as Map<String, dynamic>?;

    return ClientCapabilities(
      roots: rootsConfig != null,
      rootsListChanged: rootsConfig?['listChanged'] as bool? ?? false,
      sampling: samplingConfig != null,
      elicitation: elicitationConfig != null,
    );
  }
}

/// Server capabilities
@immutable
class ServerCapabilities {
  /// Tool support
  final bool tools;

  /// Whether tools list changes are sent as notifications
  final bool toolsListChanged;

  /// Resource support
  final bool resources;

  /// Whether resources list changes are sent as notifications
  final bool resourcesListChanged;

  /// Prompt support
  final bool prompts;

  /// Whether prompts list changes are sent as notifications
  final bool promptsListChanged;

  /// Logging support
  final bool logging;

  /// Sampling support
  final bool sampling;

  /// Create a capabilities object with specified settings
  const ServerCapabilities({
    this.tools = false,
    this.toolsListChanged = false,
    this.resources = false,
    this.resourcesListChanged = false,
    this.prompts = false,
    this.promptsListChanged = false,
    this.logging = false,
    this.sampling = false,
  });

  /// Create capabilities from JSON
  factory ServerCapabilities.fromJson(Map<String, dynamic> json) {
    final toolsConfig =
        json['tools'] != null
            ? Map<String, dynamic>.from(json['tools'] as Map)
            : null;
    final resourcesConfig =
        json['resources'] != null
            ? Map<String, dynamic>.from(json['resources'] as Map)
            : null;
    final promptsConfig =
        json['prompts'] != null
            ? Map<String, dynamic>.from(json['prompts'] as Map)
            : null;
    final loggingConfig =
        json['logging'] != null
            ? Map<String, dynamic>.from(json['logging'] as Map)
            : null;
    final samplingConfig =
        json['sampling'] != null
            ? Map<String, dynamic>.from(json['sampling'] as Map)
            : null;

    return ServerCapabilities(
      tools: toolsConfig != null,
      toolsListChanged: toolsConfig?['listChanged'] as bool? ?? false,
      resources: resourcesConfig != null,
      resourcesListChanged: resourcesConfig?['listChanged'] as bool? ?? false,
      prompts: promptsConfig != null,
      promptsListChanged: promptsConfig?['listChanged'] as bool? ?? false,
      logging: loggingConfig != null,
      sampling: samplingConfig != null,
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (tools) {
      result['tools'] = {'listChanged': toolsListChanged};
    }

    if (resources) {
      result['resources'] = {'listChanged': resourcesListChanged};
    }

    if (prompts) {
      result['prompts'] = {'listChanged': promptsListChanged};
    }

    if (logging) {
      result['logging'] = {};
    }

    if (sampling) {
      result['sampling'] = {};
    }

    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerCapabilities &&
          tools == other.tools &&
          toolsListChanged == other.toolsListChanged &&
          resources == other.resources &&
          resourcesListChanged == other.resourcesListChanged &&
          prompts == other.prompts &&
          promptsListChanged == other.promptsListChanged &&
          logging == other.logging &&
          sampling == other.sampling;

  @override
  int get hashCode => Object.hash(
    tools,
    toolsListChanged,
    resources,
    resourcesListChanged,
    prompts,
    promptsListChanged,
    logging,
    sampling,
  );

  @override
  String toString() =>
      'ServerCapabilities('
      'tools: $tools, '
      'toolsListChanged: $toolsListChanged, '
      'resources: $resources, '
      'resourcesListChanged: $resourcesListChanged, '
      'prompts: $prompts, '
      'promptsListChanged: $promptsListChanged, '
      'logging: $logging, '
      'sampling: $sampling)';
}

/// Initialize request
@immutable
class InitializeRequest {
  final ClientInfo clientInfo;
  final String protocolVersion;

  const InitializeRequest({
    required this.clientInfo,
    required this.protocolVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientInfo': clientInfo.toJson(),
      'protocolVersion': protocolVersion,
    };
  }

  factory InitializeRequest.fromJson(Map<String, dynamic> json) {
    return InitializeRequest(
      clientInfo: ClientInfo.fromJson(
        json['clientInfo'] as Map<String, dynamic>,
      ),
      protocolVersion: json['protocolVersion'] as String,
    );
  }
}

/// Initialize result
@immutable
class InitializeResult {
  final ServerInfo serverInfo;
  final String protocolVersion;
  final Map<String, dynamic>? capabilities;

  const InitializeResult({
    required this.serverInfo,
    required this.protocolVersion,
    this.capabilities,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'serverInfo': serverInfo.toJson(),
      'protocolVersion': protocolVersion,
    };
    if (capabilities != null) json['capabilities'] = capabilities!;
    return json;
  }

  factory InitializeResult.fromJson(Map<String, dynamic> json) {
    return InitializeResult(
      serverInfo: ServerInfo.fromJson(
        json['serverInfo'] as Map<String, dynamic>,
      ),
      protocolVersion: json['protocolVersion'] as String,
      capabilities: json['capabilities'] as Map<String, dynamic>?,
    );
  }
}

/// Tools list changed notification
@immutable
class ToolsListChangedNotification {
  const ToolsListChangedNotification();

  Map<String, dynamic> toJson() => {};

  factory ToolsListChangedNotification.fromJson(Map<String, dynamic> json) {
    return const ToolsListChangedNotification();
  }
}

/// Resources list changed notification
@immutable
class ResourcesListChangedNotification {
  const ResourcesListChangedNotification();

  Map<String, dynamic> toJson() => {};

  factory ResourcesListChangedNotification.fromJson(Map<String, dynamic> json) {
    return const ResourcesListChangedNotification();
  }
}

/// Prompts list changed notification
@immutable
class PromptsListChangedNotification {
  const PromptsListChangedNotification();

  Map<String, dynamic> toJson() => {};

  factory PromptsListChangedNotification.fromJson(Map<String, dynamic> json) {
    return const PromptsListChangedNotification();
  }
}

/// Resource updated notification
@immutable
class ResourceUpdatedNotification {
  final String uri;

  const ResourceUpdatedNotification({required this.uri});

  Map<String, dynamic> toJson() => {'uri': uri};

  factory ResourceUpdatedNotification.fromJson(Map<String, dynamic> json) {
    return ResourceUpdatedNotification(uri: json['uri'] as String);
  }
}

/// List tools result
@immutable
class ListToolsResult {
  final List<Tool> tools;

  const ListToolsResult({required this.tools});

  Map<String, dynamic> toJson() {
    return {'tools': tools.map((t) => t.toJson()).toList()};
  }

  factory ListToolsResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> toolsList = json['tools'] as List<dynamic>? ?? [];
    final tools =
        toolsList
            .map((tool) => Tool.fromJson(tool as Map<String, dynamic>))
            .toList();
    return ListToolsResult(tools: tools);
  }
}

/// List resources result
@immutable
class ListResourcesResult {
  final List<Resource> resources;

  const ListResourcesResult({required this.resources});

  Map<String, dynamic> toJson() {
    return {'resources': resources.map((r) => r.toJson()).toList()};
  }

  factory ListResourcesResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> resourcesList =
        json['resources'] as List<dynamic>? ?? [];
    final resources =
        resourcesList
            .map(
              (resource) => Resource.fromJson(resource as Map<String, dynamic>),
            )
            .toList();
    return ListResourcesResult(resources: resources);
  }
}

/// List prompts result
@immutable
class ListPromptsResult {
  final List<Prompt> prompts;

  const ListPromptsResult({required this.prompts});

  Map<String, dynamic> toJson() {
    return {'prompts': prompts.map((p) => p.toJson()).toList()};
  }

  factory ListPromptsResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> promptsList = json['prompts'] as List<dynamic>? ?? [];
    final prompts =
        promptsList
            .map((prompt) => Prompt.fromJson(prompt as Map<String, dynamic>))
            .toList();
    return ListPromptsResult(prompts: prompts);
  }
}

/// Call tool request
@immutable
class CallToolRequest {
  final String name;
  final Map<String, dynamic>? arguments;

  const CallToolRequest({required this.name, this.arguments});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name};
    if (arguments != null) json['arguments'] = arguments!;
    return json;
  }

  factory CallToolRequest.fromJson(Map<String, dynamic> json) {
    return CallToolRequest(
      name: json['name'] as String,
      arguments: json['arguments'] as Map<String, dynamic>?,
    );
  }
}

/// Read resource request
@immutable
class ReadResourceRequest {
  final String uri;

  const ReadResourceRequest({required this.uri});

  Map<String, dynamic> toJson() => {'uri': uri};

  factory ReadResourceRequest.fromJson(Map<String, dynamic> json) {
    return ReadResourceRequest(uri: json['uri'] as String);
  }
}

/// Get prompt request
@immutable
class GetPromptRequest {
  final String name;
  final Map<String, dynamic>? arguments;

  const GetPromptRequest({required this.name, this.arguments});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name};
    if (arguments != null) json['arguments'] = arguments!;
    return json;
  }

  factory GetPromptRequest.fromJson(Map<String, dynamic> json) {
    return GetPromptRequest(
      name: json['name'] as String,
      arguments: json['arguments'] as Map<String, dynamic>?,
    );
  }
}

/// Completion request
@immutable
class CompletionRequest {
  final Map<String, dynamic> ref;
  final Map<String, dynamic>? argument;

  const CompletionRequest({required this.ref, this.argument});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'ref': ref};
    if (argument != null) json['argument'] = argument!;
    return json;
  }

  factory CompletionRequest.fromJson(Map<String, dynamic> json) {
    return CompletionRequest(
      ref: json['ref'] as Map<String, dynamic>,
      argument: json['argument'] as Map<String, dynamic>?,
    );
  }
}

/// Completion result
@immutable
class CompletionResult {
  final Map<String, dynamic> completion;

  const CompletionResult({required this.completion});

  Map<String, dynamic> toJson() => {'completion': completion};

  factory CompletionResult.fromJson(Map<String, dynamic> json) {
    return CompletionResult(
      completion: json['completion'] as Map<String, dynamic>,
    );
  }
}

/// Log message notification
@immutable
class LogMessageNotification {
  final McpLogLevel level;
  final String message;
  final String? logger;
  final Map<String, dynamic>? data;

  const LogMessageNotification({
    required this.level,
    required this.message,
    this.logger,
    this.data,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'level': level.name, 'message': message};
    if (logger != null) json['logger'] = logger!;
    if (data != null) json['data'] = data!;
    return json;
  }

  factory LogMessageNotification.fromJson(Map<String, dynamic> json) {
    return LogMessageNotification(
      level: McpLogLevel.values.firstWhere((e) => e.name == json['level']),
      message: json['message'] as String,
      logger: json['logger'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Cancel request notification
@immutable
class CancelRequestNotification {
  final dynamic requestId;
  final String? reason;

  const CancelRequestNotification({required this.requestId, this.reason});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'requestId': requestId};
    if (reason != null) json['reason'] = reason!;
    return json;
  }

  factory CancelRequestNotification.fromJson(Map<String, dynamic> json) {
    return CancelRequestNotification(
      requestId: json['requestId'],
      reason: json['reason'] as String?,
    );
  }
}

/// Progress notification
@immutable
class ProgressNotification {
  final dynamic requestId;
  final double progress;
  final double? total;

  const ProgressNotification({
    required this.requestId,
    required this.progress,
    this.total,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'requestId': requestId,
      'progress': progress,
    };
    if (total != null) json['total'] = total!;
    return json;
  }

  factory ProgressNotification.fromJson(Map<String, dynamic> json) {
    return ProgressNotification(
      requestId: json['requestId'],
      progress: (json['progress'] as num).toDouble(),
      total: json['total'] != null ? (json['total'] as num).toDouble() : null,
    );
  }
}

// ============================================================================
// Deferred Loading Support (Progressive Tool Disclosure)
// ============================================================================

/// Lightweight tool metadata (name + description only)
/// Used for token-efficient LLM context in deferred loading mode
@immutable
class ToolMetadata {
  final String name;
  final String description;

  const ToolMetadata({required this.name, required this.description});

  /// Create from Tool object
  factory ToolMetadata.fromTool(Tool tool) =>
      ToolMetadata(name: tool.name, description: tool.description);

  /// Create from Map (for compatibility with McpClientManager.getTools())
  factory ToolMetadata.fromMap(Map<String, dynamic> map) => ToolMetadata(
    name: map['name'] as String,
    description: map['description'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'name': name, 'description': description};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolMetadata &&
          name == other.name &&
          description == other.description;

  @override
  int get hashCode => Object.hash(name, description);

  @override
  String toString() => 'ToolMetadata(name: $name, description: $description)';
}

/// Cache layer for tool definitions
/// Provides metadata extraction and full schema lookup
/// LLM-agnostic: can be used without mcp_llm
class ToolRegistry {
  final Map<String, ToolMetadata> _metadata = {};
  final Map<String, Map<String, dynamic>> _schemas = {};
  bool _initialized = false;

  /// Cache tools from Map list (McpClientManager.getTools() result)
  void cacheFromMaps(List<Map<String, dynamic>> tools) {
    _metadata.clear();
    _schemas.clear();
    for (final tool in tools) {
      final name = tool['name'] as String;
      _metadata[name] = ToolMetadata.fromMap(tool);
      _schemas[name] = Map<String, dynamic>.from(tool);
    }
    _initialized = true;
  }

  /// Cache tools from Tool list (Client.listTools() result)
  void cacheFromTools(List<Tool> tools) {
    _metadata.clear();
    _schemas.clear();
    for (final tool in tools) {
      _metadata[tool.name] = ToolMetadata.fromTool(tool);
      _schemas[tool.name] = tool.toJson();
    }
    _initialized = true;
  }

  /// Check if registry is initialized
  bool get isInitialized => _initialized;

  /// Get all metadata (lightweight, for LLM context)
  List<ToolMetadata> getAllMetadata() => _metadata.values.toList();

  /// Get metadata for specific tool
  ToolMetadata? getMetadata(String toolName) => _metadata[toolName];

  /// Get full tool schema as Map (for execution/validation)
  Map<String, dynamic>? getSchema(String toolName) => _schemas[toolName];

  /// Check if tool exists
  bool hasTool(String toolName) => _schemas.containsKey(toolName);

  /// Get all tool names
  List<String> get toolNames => _schemas.keys.toList();

  /// Clear cache (call on tools/list_changed notification)
  void invalidateAll() {
    _metadata.clear();
    _schemas.clear();
    _initialized = false;
  }

  /// Get tool count
  int get count => _schemas.length;
}
