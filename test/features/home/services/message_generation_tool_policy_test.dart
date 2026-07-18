import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multi-model policy exposes search but removes side-effect tools', () {
    Map<String, dynamic> tool(String name) => <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{'name': name},
    };

    final safe = MessageGenerationService.multiModelSafeToolDefinitions([
      tool('search_web'),
      tool('ask_user'),
      tool('memory_write'),
      tool('local_shell'),
      tool('mcp__filesystem__write_file'),
      <String, dynamic>{'type': 'function'},
    ]);

    expect(safe, [tool('search_web')]);
  });
}
