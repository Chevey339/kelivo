import '../../models/native_compaction.dart';
import 'dart:async';
import 'request_image_context.dart';
import '../../models/compress_context_options.dart';
import '../../models/token_usage.dart';

const historySourceKey = '_kelivo_history_source';
const toolSourceKey = '_kelivo_tool_source';

enum HistoryWireFormat { chatCompletions, responses, claude, google }

/// A generation-local source map for replacing the initial history. Native
/// protocol blocks appended by the running tool loop always remain untouched.
/// The caller alone owns continuation; this object never sends a request.
class RequestHistoryContext {
  RequestHistoryContext({
    required this.currentUserId,
    required this.targetMessageId,
    required this.beforeRequest,
    required this.isCancelled,
    this.nativeCompression = false,
    this.onUsage,
  });
  final String currentUserId;
  final String targetMessageId;
  final bool Function() isCancelled;
  final bool nativeCompression;
  final void Function(Map<String, dynamic> body, TokenUsage usage)? onUsage;
  final Future<List<Map<String, dynamic>>?> Function(
    Map<String, dynamic> body,
    Map<String, dynamic> Function(List<Map<String, dynamic>>) projectCandidate,
    bool overflow,
  )
  beforeRequest;
  HistoryWireFormat? format;
  Future<Map<String, String>> Function(Set<String>)? referenceResults;
  Map<String, String> _toolReferences = {};
  void Function()? onDispose;
  int lastEstimatedTokens = 0;
  double calibration = 1;
  void recordUsage(TokenUsage usage) {
    final body = _lastBody;
    if (body != null) {
      onUsage?.call(
        _replacement == null ? body : projectCandidate(body, _replacement!),
        usage,
      );
    }
    if (usage.promptTokens > 0 && lastEstimatedTokens > 0) {
      calibration = usage.promptTokens / lastEstimatedTokens;
    }
  }

  void dispose() => onDispose?.call();
  List<Map<String, dynamic>>? _replacement;
  Map<String, dynamic>? _lastBody;
  bool _recoveryAttempted = false;
  final consumedToolCalls = <String>{};
  Set<String> _pendingToolCalls = {};

  static final _zoneKey = Object();
  static RequestHistoryContext? get current =>
      Zone.current[_zoneKey] as RequestHistoryContext?;

  Stream<T> run<T>(Stream<T> Function() action) => _run(this, action);
  static Stream<T> without<T>(Stream<T> Function() action) =>
      _run(null, action);
  static Stream<T> _run<T>(
    RequestHistoryContext? context,
    Stream<T> Function() action,
  ) => Stream<T>.multi((controller) {
    late Zone zone;
    final subscription = runZoned(() {
      zone = Zone.current;
      return action().listen(
        controller.addSync,
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
    }, zoneValues: {_zoneKey: context});
    controller.onPause = () => zone.run(subscription.pause);
    controller.onResume = () => zone.run(subscription.resume);
    controller.onCancel = () => zone.run(subscription.cancel);
  });

  static List<Map<String, dynamic>> identify(
    List<Map<String, dynamic>> messages,
  ) => [
    for (var i = 0; i < messages.length; i++)
      {
        ...messages[i],
        historySourceKey: messages[i][imageContextOwnerKey] ?? 'reference:$i',
      },
  ];

  static void mark(Map source, Iterable<Map<String, dynamic>> output) {
    final id = source[historySourceKey];
    if (id == null) return;
    for (final item in output) {
      item.putIfAbsent(historySourceKey, () => id);
    }
  }

  String get _listKey => switch (format!) {
    HistoryWireFormat.responses => 'input',
    HistoryWireFormat.google => 'contents',
    _ => 'messages',
  };

  Map<String, dynamic> _textMessage(Map<String, dynamic> source) {
    final role = source['role'] as String? ?? 'user';
    final text = source['content']?.toString() ?? '';
    return switch (format!) {
      HistoryWireFormat.google => {
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': text},
        ],
      },
      HistoryWireFormat.responses => {
        'role': role,
        'content': [
          {
            'type': role == 'assistant' ? 'output_text' : 'input_text',
            'text': text,
          },
        ],
      },
      HistoryWireFormat.claude => {
        'role': role,
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
      HistoryWireFormat.chatCompletions => {'role': role, 'content': text},
    };
  }

  Map<String, dynamic> projectCandidate(
    Map<String, dynamic> body,
    List<Map<String, dynamic>> replacement,
  ) {
    if (format == null || body[_listKey] is! List) {
      throw StateError('compression_protocol_unavailable');
    }
    final original = (body[_listKey] as List).cast<Map>();
    final groups = <String, List<Map<String, dynamic>>>{};
    final suffix = <Map<String, dynamic>>[];
    for (final item in original) {
      final source = item[historySourceKey];
      if (source is String) {
        groups
            .putIfAbsent(source, () => [])
            .add(Map<String, dynamic>.from(item));
      } else {
        suffix.add(Map<String, dynamic>.from(item));
      }
    }
    // Without the explicit user boundary we cannot safely replace a prefix.
    if (!groups.containsKey(currentUserId)) {
      throw StateError('compression_protocol_unavailable');
    }
    final next = <Map<String, dynamic>>[];
    final emitted = <String>{};
    final system = <String>[];
    for (final message in replacement) {
      final owner = message[imageContextOwnerKey]?.toString();
      if (message['role'] == 'system' &&
          format != HistoryWireFormat.chatCompletions) {
        system.add(message['content']?.toString() ?? '');
      } else if (message[nativeCompactionMessageKey] case final Map value) {
        if (format != HistoryWireFormat.responses) {
          throw StateError('compression_protocol_unavailable');
        }
        final native = NativeCompactionPayload.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (owner == null || emitted.add(owner)) {
          next.addAll([
            for (final item in native.output)
              {
                ...item,
                nativeCompactionWireKey: true,
                if (owner != null) historySourceKey: owner,
              },
          ]);
        }
      } else if (owner != null && groups.containsKey(owner)) {
        if (emitted.add(owner)) next.addAll(groups[owner]!);
      } else if (owner == null || owner.startsWith('context-summary:')) {
        next.add(_textMessage(message));
      } else {
        throw StateError('compression_protocol_source_missing');
      }
    }
    for (final owner in [currentUserId, targetMessageId]) {
      if (emitted.add(owner)) next.addAll(groups[owner] ?? const []);
    }
    next.addAll(suffix);
    final projected = <String, dynamic>{...body, _listKey: next};
    switch (format!) {
      case HistoryWireFormat.responses:
        projected.remove('previous_response_id');
        projected.remove('conversation');
        projected['instructions'] = system.join('\n\n');
      case HistoryWireFormat.claude:
        final existing = body['system'];
        // Keep the provider's cache-control policy while replacing the text.
        projected['system'] = existing is List
            ? [
                {
                  'type': 'text',
                  'text': system.join('\n\n'),
                  if (existing.isNotEmpty &&
                      existing.last is Map &&
                      existing.last['cache_control'] != null)
                    'cache_control': existing.last['cache_control'],
                },
              ]
            : system.join('\n\n');
      case HistoryWireFormat.google:
        final key = body.containsKey('system_instruction')
            ? 'system_instruction'
            : 'systemInstruction';
        projected[key] = {
          'parts': [
            {'text': system.join('\n\n')},
          ],
        };
      case HistoryWireFormat.chatCompletions:
        break;
    }
    return projected;
  }

  Future<Map<String, dynamic>> prepare(Map<String, dynamic> body) async {
    if (isCancelled()) throw StateError('cancelled');
    _lastBody = body;
    try {
      _toolReferences = await referenceResults?.call(consumedToolCalls) ?? {};
    } catch (_) {
      _toolReferences = {};
    }
    var projected = _replacement == null
        ? body
        : projectCandidate(body, _replacement!);
    projected = projectToolResults(projected, _toolReferences);
    List<Map<String, dynamic>>? replacement;
    try {
      replacement = await beforeRequest(
        projected,
        (messages) => projectToolResults(
          projectCandidate(body, messages),
          _toolReferences,
        ),
        false,
      );
    } catch (_) {
      if (isCancelled()) rethrow;
    }
    if (isCancelled()) throw StateError('cancelled');
    if (replacement != null) {
      _replacement = replacement;
      projected = projectToolResults(
        projectCandidate(body, replacement),
        _toolReferences,
      );
    }
    _pendingToolCalls = toolResultIds(projected);
    return projected;
  }

  void roundCompleted() {
    if (!isCancelled()) consumedToolCalls.addAll(_pendingToolCalls);
  }

  /// Retry only the rejected model round. Nested provider loops consume the
  /// recovery before an error can reach the outer generation retry wrapper.
  Stream<T> recoverOverflow<T>(Stream<T> Function() sendRound) async* {
    try {
      await for (final item in sendRound()) {
        yield item;
      }
    } catch (error) {
      if (!isContextLengthError(error) ||
          _recoveryAttempted ||
          isCancelled() ||
          _lastBody == null) {
        rethrow;
      }
      _recoveryAttempted = true;
      final original = _lastBody!;
      final body = _replacement == null
          ? original
          : projectCandidate(original, _replacement!);
      final replacement = await beforeRequest(
        body,
        (messages) => projectCandidate(original, messages),
        true,
      );
      if (replacement == null || isCancelled()) rethrow;
      _replacement = replacement;
      yield* sendRound();
    }
  }

  static Set<String> toolResultIds(Map<String, dynamic> body) {
    final ids = <String>{};
    for (final key in ['messages', 'input', 'contents']) {
      if (body[key] is! List) continue;
      for (final item in (body[key] as List).whereType<Map>()) {
        if (item['role'] == 'tool' && item['tool_call_id'] is String) {
          ids.add(item['tool_call_id'] as String);
        }
        if (item['type'] == 'function_call_output' &&
            item['call_id'] is String) {
          ids.add(item['call_id'] as String);
        }
        for (final part
            in (item['parts'] ?? item['content']) is List
                ? ((item['parts'] ?? item['content']) as List).whereType<Map>()
                : <Map>[]) {
          if (part['type'] == 'tool_result') {
            ids.add(part['tool_use_id'].toString());
          }
          if (part['functionResponse'] is Map) {
            if (part[toolSourceKey] is String) {
              ids.add(part[toolSourceKey] as String);
            }
          }
        }
      }
    }
    return ids;
  }

  static Map<String, dynamic> projectToolResults(
    Map<String, dynamic> body,
    Map<String, String> replacements,
  ) {
    var referenced = false;
    dynamic replaceContent(dynamic value, String replacement) => value is List
        ? [
            {'type': 'text', 'text': replacement},
            ...value.where((p) => p is Map && p['type'] != 'text'),
          ]
        : replacement;
    final result = <String, dynamic>{...body};
    for (final key in ['messages', 'input', 'contents']) {
      if (body[key] is! List) continue;
      result[key] = [
        for (final raw in body[key] as List)
          if (raw is Map)
            (() {
              final message = Map<String, dynamic>.from(raw);
              if (message[nativeCompactionWireKey] == true) return message;
              final id = message['tool_call_id'] ?? message['call_id'];
              if ((message['role'] == 'tool' ||
                      message['type'] == 'function_call_output') &&
                  replacements[id] != null) {
                final field = message['role'] == 'tool' ? 'content' : 'output';
                message[field] = replaceContent(
                  message[field],
                  replacements[id]!,
                );
                referenced = true;
              }
              for (final field in ['content', 'parts']) {
                if (message[field] is! List) continue;
                message[field] = [
                  for (final rawPart in message[field] as List)
                    if (rawPart is Map)
                      (() {
                        final part = Map<String, dynamic>.from(rawPart);
                        final replacement =
                            replacements[part['type'] == 'tool_result'
                                ? part['tool_use_id']
                                : part[toolSourceKey]];
                        if (replacement != null &&
                            part['type'] == 'tool_result') {
                          part['content'] = replaceContent(
                            part['content'],
                            replacement,
                          );
                          referenced = true;
                        } else if (replacement != null &&
                            part['functionResponse'] is Map) {
                          part['functionResponse'] = {
                            ...part['functionResponse'] as Map,
                            'response': {'result': replacement},
                          };
                          referenced = true;
                        }
                        return part;
                      })()
                    else
                      rawPart,
                ];
              }
              return message;
            })()
          else
            raw,
      ];
    }
    if (!referenced && result['tools'] is List) {
      result['tools'] = [
        for (final raw in result['tools'] as List)
          if (raw is Map)
            (() {
              if (raw['name'] == 'read_chat_context' ||
                  (raw['function'] as Map?)?['name'] == 'read_chat_context') {
                return null;
              }
              final tool = Map<String, dynamic>.from(raw);
              for (final key in [
                'functionDeclarations',
                'function_declarations',
              ]) {
                if (tool[key] is List) {
                  tool[key] = (tool[key] as List)
                      .where(
                        (f) => f is! Map || f['name'] != 'read_chat_context',
                      )
                      .toList();
                  if ((tool[key] as List).isEmpty) tool.remove(key);
                }
              }
              return tool.isEmpty ? null : tool;
            })()
          else
            raw,
      ]..removeWhere((t) => t == null);
      if ((result['tools'] as List).isEmpty) {
        result.remove('tools');
        result.remove('tool_choice');
        result.remove('toolConfig');
      }
    }
    return result;
  }

  static Map<String, dynamic> stripSources(Map<String, dynamic> body) {
    final result = <String, dynamic>{...body};
    for (final key in ['messages', 'input', 'contents']) {
      if (body[key] is! List) continue;
      result[key] = [
        for (final raw in body[key] as List)
          if (raw is Map)
            (() {
              final item = Map<String, dynamic>.from(raw)
                ..remove(historySourceKey)
                ..remove(nativeCompactionWireKey);
              if (raw[nativeCompactionWireKey] == true) return item;
              for (final field in ['content', 'parts']) {
                if (item[field] is List) {
                  item[field] = [
                    for (final part in item[field] as List)
                      if (part is Map)
                        Map<String, dynamic>.from(part)..remove(toolSourceKey)
                      else
                        part,
                  ];
                }
              }
              return item;
            })()
          else
            raw,
      ];
    }
    return result;
  }
}
