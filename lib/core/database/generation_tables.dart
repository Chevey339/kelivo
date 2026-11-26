part of 'app_database.dart';

@TableIndex(name: 'idx_generation_topics_updated', columns: {#updatedAt})
class GenerationTopicRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get titleSource => textEnum<GenerationTitleSource>()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_generation_batches_topic_created',
  columns: {#topicId, #createdAt},
)
@TableIndex(name: 'idx_generation_batches_created', columns: {#createdAt})
@TableIndex(name: 'idx_generation_batches_status', columns: {#status})
class GenerationBatchRows extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text().nullable().references(
    GenerationTopicRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get providerId => text()();
  TextColumn get modelId => text()();
  TextColumn get mode => textEnum<MediaMode>()();
  TextColumn get prompt => text()();
  TextColumn get negativePrompt => text().nullable()();
  TextColumn get paramsJson => text()();
  TextColumn get referencesJson => text()();
  TextColumn get status => textEnum<GenerationStatus>()();
  TextColumn get errorJson => text().nullable()();
  TextColumn get source => textEnum<GenerationSource>()();
  TextColumn get parentItemId => text().nullable()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get messageId => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get startedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get finishedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_generation_items_batch_ordinal',
  columns: {#batchId, #ordinal},
  unique: true,
)
@TableIndex(name: 'idx_generation_items_favorite', columns: {#favorite})
@TableIndex(
  name: 'idx_generation_items_mode_created',
  columns: {#mode, #createdAt},
)
class GenerationItemRows extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(
    GenerationBatchRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get ordinal => integer()();
  TextColumn get mode => textEnum<MediaMode>()();
  TextColumn get path => text()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get mime => text()();
  IntColumn get byteSize => integer()();
  TextColumn get revisedPrompt => text().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get status => textEnum<GenerationItemStatus>()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
