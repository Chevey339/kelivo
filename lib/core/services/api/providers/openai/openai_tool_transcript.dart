part of '../../chat_api_service.dart';

List<EmitToolCall> clientToolCallsFromChatAcc(Map<dynamic, dynamic> toolAcc) {
  final calls = <EmitToolCall>[];
  final keys = toolAcc.keys.toList()
    ..sort((a, b) {
      final ai = a is int ? a : int.tryParse(a.toString()) ?? 0;
      final bi = b is int ? b : int.tryParse(b.toString()) ?? 0;
      return ai.compareTo(bi);
    });
  for (final key in keys) {
    final raw = toolAcc[key];
    if (raw is! Map) continue;
    final id = _effectiveToolCallId(raw['id'], 'call', key);
    final name = (raw['name'] ?? '').toString();
    Map<String, dynamic> arguments;
    try {
      arguments = (jsonDecode((raw['args'] ?? '{}').toString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      arguments = <String, dynamic>{};
    }
    calls.add(emitToolCall(id: id, name: name, arguments: arguments));
  }
  return calls;
}

List<Map<String, dynamic>> openaiToolCallMaps(List<EmitToolCall> calls) {
  return [
    for (final call in calls)
      <String, dynamic>{
        'id': call.id,
        'type': 'function',
        'function': <String, dynamic>{
          'name': call.name,
          'arguments': jsonEncode(call.arguments),
        },
      },
  ];
}

List<Map<String, dynamic>> openaiToolResultMessages(
  List<ExecutedClientTool> executed,
) {
  return [
    for (final item in executed)
      <String, dynamic>{
        'role': 'tool',
        'tool_call_id': item.call.id,
        'name': item.call.name,
        'content': item.content,
      },
  ];
}
