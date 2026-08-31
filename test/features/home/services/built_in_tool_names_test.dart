import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/memory/memory_tools.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/features/home/services/built_in_tool_names.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

void main() {
  test('BuiltInToolNames.all reserves search, memory, and local names', () {
    expect(
      BuiltInToolNames.all,
      containsAll(<String>[
        SearchToolService.toolName,
        'builtin_search',
        ...MemoryTools.allToolNames,
        ...MemoryTools.legacyToolNames,
        ...LocalToolNames.all,
      ]),
    );
    expect(SearchToolService.toolName, 'search_web');
    expect(
      BuiltInToolNames.all,
      containsAll(const ['create_memory', 'edit_memory', 'delete_memory']),
    );
    expect(LocalToolNames.all, [
      LocalToolNames.timeInfo,
      LocalToolNames.clipboard,
      LocalToolNames.textToSpeech,
      LocalToolNames.askUser,
      LocalToolNames.calculate,
      LocalToolNames.screenTime,
      LocalToolNames.calendarQuery,
      LocalToolNames.calendarCreate,
      LocalToolNames.currentLocation,
      LocalToolNames.weather,
      LocalToolNames.healthSummary,
      LocalToolNames.remindersQuery,
      LocalToolNames.remindersCreate,
      LocalToolNames.remindersComplete,
    ]);
  });
}
