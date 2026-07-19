typedef BusinessEntityRowIds = Map<String, List<String>>;

typedef BusinessSettingsExport = ({
  Map<String, Object> settings,
  BusinessEntityRowIds entityRowIds,
});

enum BusinessEntityKind {
  assistant(sourceKey: 'assistants_v1', tableName: 'assistant_rows'),
  provider(sourceKey: 'provider_configs_v1', tableName: 'provider_rows'),
  providerGroup(
    sourceKey: 'provider_groups_v1',
    tableName: 'provider_group_rows',
  ),
  mcpServer(sourceKey: 'mcp_servers_v1', tableName: 'mcp_server_rows'),
  worldBook(sourceKey: 'world_books_v1', tableName: 'world_book_rows'),
  assistantMemory(
    sourceKey: 'assistant_memories_v1',
    tableName: 'assistant_memory_rows',
  ),
  quickPhrase(sourceKey: 'quick_phrases_v1', tableName: 'quick_phrase_rows'),
  searchService(
    sourceKey: 'search_services_v1',
    tableName: 'search_service_rows',
  ),
  ttsService(sourceKey: 'tts_services_v1', tableName: 'tts_service_rows'),
  instructionInjection(
    sourceKey: 'instruction_injections_v1',
    tableName: 'instruction_injection_rows',
  ),
  assistantTag(sourceKey: 'assistant_tags_v1', tableName: 'assistant_tag_rows');

  const BusinessEntityKind({required this.sourceKey, required this.tableName});

  final String sourceKey;
  final String tableName;

  String get idColumn => this == provider ? 'provider_key' : 'id';
}

final class BusinessEntityValue {
  const BusinessEntityValue({
    required this.id,
    required this.sortOrder,
    required this.payload,
    this.assistantId,
  });

  final String id;
  final int sortOrder;
  final String payload;
  final String? assistantId;

  BusinessEntityValue copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    String? assistantId,
  }) => BusinessEntityValue(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    assistantId: assistantId ?? this.assistantId,
  );
}

final class BusinessSnapshot {
  BusinessSnapshot({
    required Map<BusinessEntityKind, List<BusinessEntityValue>> entities,
    required Map<String, Object> preferences,
  }) : entities = {
         for (final kind in BusinessEntityKind.values)
           kind: List<BusinessEntityValue>.unmodifiable(
             entities[kind] ?? const <BusinessEntityValue>[],
           ),
       },
       preferences = Map<String, Object>.unmodifiable(preferences);

  final Map<BusinessEntityKind, List<BusinessEntityValue>> entities;
  final Map<String, Object> preferences;

  int entityCount(BusinessEntityKind kind) => entities[kind]!.length;
}
