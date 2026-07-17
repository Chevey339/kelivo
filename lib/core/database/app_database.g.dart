// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ConversationRowsTable extends ConversationRows
    with TableInfo<$ConversationRowsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _assistantIdMeta = const VerificationMeta(
    'assistantId',
  );
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
    'assistant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _truncateIndexMeta = const VerificationMeta(
    'truncateIndex',
  );
  @override
  late final GeneratedColumn<int> truncateIndex = GeneratedColumn<int>(
    'truncate_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _versionSelectionsJsonMeta =
      const VerificationMeta('versionSelectionsJson');
  @override
  late final GeneratedColumn<String> versionSelectionsJson =
      GeneratedColumn<String>(
        'version_selections_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSummarizedMessageCountMeta =
      const VerificationMeta('lastSummarizedMessageCount');
  @override
  late final GeneratedColumn<int> lastSummarizedMessageCount =
      GeneratedColumn<int>(
        'last_summarized_message_count',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _chatSuggestionsJsonMeta =
      const VerificationMeta('chatSuggestionsJson');
  @override
  late final GeneratedColumn<String> chatSuggestionsJson =
      GeneratedColumn<String>(
        'chat_suggestions_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    updatedAt,
    isPinned,
    assistantId,
    truncateIndex,
    versionSelectionsJson,
    summary,
    lastSummarizedMessageCount,
    chatSuggestionsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
        _assistantIdMeta,
        assistantId.isAcceptableOrUnknown(
          data['assistant_id']!,
          _assistantIdMeta,
        ),
      );
    }
    if (data.containsKey('truncate_index')) {
      context.handle(
        _truncateIndexMeta,
        truncateIndex.isAcceptableOrUnknown(
          data['truncate_index']!,
          _truncateIndexMeta,
        ),
      );
    }
    if (data.containsKey('version_selections_json')) {
      context.handle(
        _versionSelectionsJsonMeta,
        versionSelectionsJson.isAcceptableOrUnknown(
          data['version_selections_json']!,
          _versionSelectionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('last_summarized_message_count')) {
      context.handle(
        _lastSummarizedMessageCountMeta,
        lastSummarizedMessageCount.isAcceptableOrUnknown(
          data['last_summarized_message_count']!,
          _lastSummarizedMessageCountMeta,
        ),
      );
    }
    if (data.containsKey('chat_suggestions_json')) {
      context.handle(
        _chatSuggestionsJsonMeta,
        chatSuggestionsJson.isAcceptableOrUnknown(
          data['chat_suggestions_json']!,
          _chatSuggestionsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      ),
      truncateIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}truncate_index'],
      )!,
      versionSelectionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_selections_json'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      lastSummarizedMessageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_summarized_message_count'],
      )!,
      chatSuggestionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_suggestions_json'],
      )!,
    );
  }

  @override
  $ConversationRowsTable createAlias(String alias) {
    return $ConversationRowsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final String? assistantId;
  final int truncateIndex;
  final String versionSelectionsJson;
  final String? summary;
  final int lastSummarizedMessageCount;
  final String chatSuggestionsJson;
  const ConversationRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    this.assistantId,
    required this.truncateIndex,
    required this.versionSelectionsJson,
    this.summary,
    required this.lastSummarizedMessageCount,
    required this.chatSuggestionsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || assistantId != null) {
      map['assistant_id'] = Variable<String>(assistantId);
    }
    map['truncate_index'] = Variable<int>(truncateIndex);
    map['version_selections_json'] = Variable<String>(versionSelectionsJson);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['last_summarized_message_count'] = Variable<int>(
      lastSummarizedMessageCount,
    );
    map['chat_suggestions_json'] = Variable<String>(chatSuggestionsJson);
    return map;
  }

  ConversationRowsCompanion toCompanion(bool nullToAbsent) {
    return ConversationRowsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isPinned: Value(isPinned),
      assistantId: assistantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantId),
      truncateIndex: Value(truncateIndex),
      versionSelectionsJson: Value(versionSelectionsJson),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      lastSummarizedMessageCount: Value(lastSummarizedMessageCount),
      chatSuggestionsJson: Value(chatSuggestionsJson),
    );
  }

  factory ConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      truncateIndex: serializer.fromJson<int>(json['truncateIndex']),
      versionSelectionsJson: serializer.fromJson<String>(
        json['versionSelectionsJson'],
      ),
      summary: serializer.fromJson<String?>(json['summary']),
      lastSummarizedMessageCount: serializer.fromJson<int>(
        json['lastSummarizedMessageCount'],
      ),
      chatSuggestionsJson: serializer.fromJson<String>(
        json['chatSuggestionsJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'assistantId': serializer.toJson<String?>(assistantId),
      'truncateIndex': serializer.toJson<int>(truncateIndex),
      'versionSelectionsJson': serializer.toJson<String>(versionSelectionsJson),
      'summary': serializer.toJson<String?>(summary),
      'lastSummarizedMessageCount': serializer.toJson<int>(
        lastSummarizedMessageCount,
      ),
      'chatSuggestionsJson': serializer.toJson<String>(chatSuggestionsJson),
    };
  }

  ConversationRow copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    Value<String?> assistantId = const Value.absent(),
    int? truncateIndex,
    String? versionSelectionsJson,
    Value<String?> summary = const Value.absent(),
    int? lastSummarizedMessageCount,
    String? chatSuggestionsJson,
  }) => ConversationRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPinned: isPinned ?? this.isPinned,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    truncateIndex: truncateIndex ?? this.truncateIndex,
    versionSelectionsJson: versionSelectionsJson ?? this.versionSelectionsJson,
    summary: summary.present ? summary.value : this.summary,
    lastSummarizedMessageCount:
        lastSummarizedMessageCount ?? this.lastSummarizedMessageCount,
    chatSuggestionsJson: chatSuggestionsJson ?? this.chatSuggestionsJson,
  );
  ConversationRow copyWithCompanion(ConversationRowsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      truncateIndex: data.truncateIndex.present
          ? data.truncateIndex.value
          : this.truncateIndex,
      versionSelectionsJson: data.versionSelectionsJson.present
          ? data.versionSelectionsJson.value
          : this.versionSelectionsJson,
      summary: data.summary.present ? data.summary.value : this.summary,
      lastSummarizedMessageCount: data.lastSummarizedMessageCount.present
          ? data.lastSummarizedMessageCount.value
          : this.lastSummarizedMessageCount,
      chatSuggestionsJson: data.chatSuggestionsJson.present
          ? data.chatSuggestionsJson.value
          : this.chatSuggestionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('assistantId: $assistantId, ')
          ..write('truncateIndex: $truncateIndex, ')
          ..write('versionSelectionsJson: $versionSelectionsJson, ')
          ..write('summary: $summary, ')
          ..write('lastSummarizedMessageCount: $lastSummarizedMessageCount, ')
          ..write('chatSuggestionsJson: $chatSuggestionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    updatedAt,
    isPinned,
    assistantId,
    truncateIndex,
    versionSelectionsJson,
    summary,
    lastSummarizedMessageCount,
    chatSuggestionsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isPinned == this.isPinned &&
          other.assistantId == this.assistantId &&
          other.truncateIndex == this.truncateIndex &&
          other.versionSelectionsJson == this.versionSelectionsJson &&
          other.summary == this.summary &&
          other.lastSummarizedMessageCount == this.lastSummarizedMessageCount &&
          other.chatSuggestionsJson == this.chatSuggestionsJson);
}

class ConversationRowsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isPinned;
  final Value<String?> assistantId;
  final Value<int> truncateIndex;
  final Value<String> versionSelectionsJson;
  final Value<String?> summary;
  final Value<int> lastSummarizedMessageCount;
  final Value<String> chatSuggestionsJson;
  final Value<int> rowid;
  const ConversationRowsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.truncateIndex = const Value.absent(),
    this.versionSelectionsJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.lastSummarizedMessageCount = const Value.absent(),
    this.chatSuggestionsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationRowsCompanion.insert({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isPinned = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.truncateIndex = const Value.absent(),
    this.versionSelectionsJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.lastSummarizedMessageCount = const Value.absent(),
    this.chatSuggestionsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isPinned,
    Expression<String>? assistantId,
    Expression<int>? truncateIndex,
    Expression<String>? versionSelectionsJson,
    Expression<String>? summary,
    Expression<int>? lastSummarizedMessageCount,
    Expression<String>? chatSuggestionsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (assistantId != null) 'assistant_id': assistantId,
      if (truncateIndex != null) 'truncate_index': truncateIndex,
      if (versionSelectionsJson != null)
        'version_selections_json': versionSelectionsJson,
      if (summary != null) 'summary': summary,
      if (lastSummarizedMessageCount != null)
        'last_summarized_message_count': lastSummarizedMessageCount,
      if (chatSuggestionsJson != null)
        'chat_suggestions_json': chatSuggestionsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isPinned,
    Value<String?>? assistantId,
    Value<int>? truncateIndex,
    Value<String>? versionSelectionsJson,
    Value<String?>? summary,
    Value<int>? lastSummarizedMessageCount,
    Value<String>? chatSuggestionsJson,
    Value<int>? rowid,
  }) {
    return ConversationRowsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      assistantId: assistantId ?? this.assistantId,
      truncateIndex: truncateIndex ?? this.truncateIndex,
      versionSelectionsJson:
          versionSelectionsJson ?? this.versionSelectionsJson,
      summary: summary ?? this.summary,
      lastSummarizedMessageCount:
          lastSummarizedMessageCount ?? this.lastSummarizedMessageCount,
      chatSuggestionsJson: chatSuggestionsJson ?? this.chatSuggestionsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (truncateIndex.present) {
      map['truncate_index'] = Variable<int>(truncateIndex.value);
    }
    if (versionSelectionsJson.present) {
      map['version_selections_json'] = Variable<String>(
        versionSelectionsJson.value,
      );
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (lastSummarizedMessageCount.present) {
      map['last_summarized_message_count'] = Variable<int>(
        lastSummarizedMessageCount.value,
      );
    }
    if (chatSuggestionsJson.present) {
      map['chat_suggestions_json'] = Variable<String>(
        chatSuggestionsJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRowsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('assistantId: $assistantId, ')
          ..write('truncateIndex: $truncateIndex, ')
          ..write('versionSelectionsJson: $versionSelectionsJson, ')
          ..write('summary: $summary, ')
          ..write('lastSummarizedMessageCount: $lastSummarizedMessageCount, ')
          ..write('chatSuggestionsJson: $chatSuggestionsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageRowsTable extends MessageRows
    with TableInfo<$MessageRowsTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalTokensMeta = const VerificationMeta(
    'totalTokens',
  );
  @override
  late final GeneratedColumn<int> totalTokens = GeneratedColumn<int>(
    'total_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isStreamingMeta = const VerificationMeta(
    'isStreaming',
  );
  @override
  late final GeneratedColumn<bool> isStreaming = GeneratedColumn<bool>(
    'is_streaming',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_streaming" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reasoningTextMeta = const VerificationMeta(
    'reasoningText',
  );
  @override
  late final GeneratedColumn<String> reasoningText = GeneratedColumn<String>(
    'reasoning_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasoningStartAtMeta = const VerificationMeta(
    'reasoningStartAt',
  );
  @override
  late final GeneratedColumn<DateTime> reasoningStartAt =
      GeneratedColumn<DateTime>(
        'reasoning_start_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reasoningFinishedAtMeta =
      const VerificationMeta('reasoningFinishedAt');
  @override
  late final GeneratedColumn<DateTime> reasoningFinishedAt =
      GeneratedColumn<DateTime>(
        'reasoning_finished_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasoningSegmentsJsonMeta =
      const VerificationMeta('reasoningSegmentsJson');
  @override
  late final GeneratedColumn<String> reasoningSegmentsJson =
      GeneratedColumn<String>(
        'reasoning_segments_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subgroupIdMeta = const VerificationMeta(
    'subgroupId',
  );
  @override
  late final GeneratedColumn<String> subgroupId = GeneratedColumn<String>(
    'subgroup_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _promptTokensMeta = const VerificationMeta(
    'promptTokens',
  );
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
    'prompt_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionTokensMeta = const VerificationMeta(
    'completionTokens',
  );
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
    'completion_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedTokensMeta = const VerificationMeta(
    'cachedTokens',
  );
  @override
  late final GeneratedColumn<int> cachedTokens = GeneratedColumn<int>(
    'cached_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageOrderMeta = const VerificationMeta(
    'messageOrder',
  );
  @override
  late final GeneratedColumn<int> messageOrder = GeneratedColumn<int>(
    'message_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    role,
    content,
    timestamp,
    modelId,
    providerId,
    totalTokens,
    isStreaming,
    reasoningText,
    reasoningStartAt,
    reasoningFinishedAt,
    translation,
    reasoningSegmentsJson,
    groupId,
    subgroupId,
    version,
    promptTokens,
    completionTokens,
    cachedTokens,
    durationMs,
    messageOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    }
    if (data.containsKey('total_tokens')) {
      context.handle(
        _totalTokensMeta,
        totalTokens.isAcceptableOrUnknown(
          data['total_tokens']!,
          _totalTokensMeta,
        ),
      );
    }
    if (data.containsKey('is_streaming')) {
      context.handle(
        _isStreamingMeta,
        isStreaming.isAcceptableOrUnknown(
          data['is_streaming']!,
          _isStreamingMeta,
        ),
      );
    }
    if (data.containsKey('reasoning_text')) {
      context.handle(
        _reasoningTextMeta,
        reasoningText.isAcceptableOrUnknown(
          data['reasoning_text']!,
          _reasoningTextMeta,
        ),
      );
    }
    if (data.containsKey('reasoning_start_at')) {
      context.handle(
        _reasoningStartAtMeta,
        reasoningStartAt.isAcceptableOrUnknown(
          data['reasoning_start_at']!,
          _reasoningStartAtMeta,
        ),
      );
    }
    if (data.containsKey('reasoning_finished_at')) {
      context.handle(
        _reasoningFinishedAtMeta,
        reasoningFinishedAt.isAcceptableOrUnknown(
          data['reasoning_finished_at']!,
          _reasoningFinishedAtMeta,
        ),
      );
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    }
    if (data.containsKey('reasoning_segments_json')) {
      context.handle(
        _reasoningSegmentsJsonMeta,
        reasoningSegmentsJson.isAcceptableOrUnknown(
          data['reasoning_segments_json']!,
          _reasoningSegmentsJsonMeta,
        ),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('subgroup_id')) {
      context.handle(
        _subgroupIdMeta,
        subgroupId.isAcceptableOrUnknown(data['subgroup_id']!, _subgroupIdMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
        _promptTokensMeta,
        promptTokens.isAcceptableOrUnknown(
          data['prompt_tokens']!,
          _promptTokensMeta,
        ),
      );
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
        _completionTokensMeta,
        completionTokens.isAcceptableOrUnknown(
          data['completion_tokens']!,
          _completionTokensMeta,
        ),
      );
    }
    if (data.containsKey('cached_tokens')) {
      context.handle(
        _cachedTokensMeta,
        cachedTokens.isAcceptableOrUnknown(
          data['cached_tokens']!,
          _cachedTokensMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('message_order')) {
      context.handle(
        _messageOrderMeta,
        messageOrder.isAcceptableOrUnknown(
          data['message_order']!,
          _messageOrderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      ),
      totalTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_tokens'],
      ),
      isStreaming: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_streaming'],
      )!,
      reasoningText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning_text'],
      ),
      reasoningStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reasoning_start_at'],
      ),
      reasoningFinishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reasoning_finished_at'],
      ),
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      ),
      reasoningSegmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning_segments_json'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      subgroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subgroup_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      promptTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prompt_tokens'],
      ),
      completionTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_tokens'],
      ),
      cachedTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_tokens'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      messageOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_order'],
      )!,
    );
  }

  @override
  $MessageRowsTable createAlias(String alias) {
    return $MessageRowsTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? modelId;
  final String? providerId;
  final int? totalTokens;
  final bool isStreaming;
  final String? reasoningText;
  final DateTime? reasoningStartAt;
  final DateTime? reasoningFinishedAt;
  final String? translation;
  final String? reasoningSegmentsJson;
  final String? groupId;
  final String? subgroupId;
  final int version;
  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? durationMs;
  final int messageOrder;
  const MessageRow({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.modelId,
    this.providerId,
    this.totalTokens,
    required this.isStreaming,
    this.reasoningText,
    this.reasoningStartAt,
    this.reasoningFinishedAt,
    this.translation,
    this.reasoningSegmentsJson,
    this.groupId,
    this.subgroupId,
    required this.version,
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.durationMs,
    required this.messageOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<String>(providerId);
    }
    if (!nullToAbsent || totalTokens != null) {
      map['total_tokens'] = Variable<int>(totalTokens);
    }
    map['is_streaming'] = Variable<bool>(isStreaming);
    if (!nullToAbsent || reasoningText != null) {
      map['reasoning_text'] = Variable<String>(reasoningText);
    }
    if (!nullToAbsent || reasoningStartAt != null) {
      map['reasoning_start_at'] = Variable<DateTime>(reasoningStartAt);
    }
    if (!nullToAbsent || reasoningFinishedAt != null) {
      map['reasoning_finished_at'] = Variable<DateTime>(reasoningFinishedAt);
    }
    if (!nullToAbsent || translation != null) {
      map['translation'] = Variable<String>(translation);
    }
    if (!nullToAbsent || reasoningSegmentsJson != null) {
      map['reasoning_segments_json'] = Variable<String>(reasoningSegmentsJson);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || subgroupId != null) {
      map['subgroup_id'] = Variable<String>(subgroupId);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || promptTokens != null) {
      map['prompt_tokens'] = Variable<int>(promptTokens);
    }
    if (!nullToAbsent || completionTokens != null) {
      map['completion_tokens'] = Variable<int>(completionTokens);
    }
    if (!nullToAbsent || cachedTokens != null) {
      map['cached_tokens'] = Variable<int>(cachedTokens);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['message_order'] = Variable<int>(messageOrder);
    return map;
  }

  MessageRowsCompanion toCompanion(bool nullToAbsent) {
    return MessageRowsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      timestamp: Value(timestamp),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      providerId: providerId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerId),
      totalTokens: totalTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(totalTokens),
      isStreaming: Value(isStreaming),
      reasoningText: reasoningText == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningText),
      reasoningStartAt: reasoningStartAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningStartAt),
      reasoningFinishedAt: reasoningFinishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningFinishedAt),
      translation: translation == null && nullToAbsent
          ? const Value.absent()
          : Value(translation),
      reasoningSegmentsJson: reasoningSegmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningSegmentsJson),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      subgroupId: subgroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(subgroupId),
      version: Value(version),
      promptTokens: promptTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(promptTokens),
      completionTokens: completionTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(completionTokens),
      cachedTokens: cachedTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedTokens),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      messageOrder: Value(messageOrder),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      providerId: serializer.fromJson<String?>(json['providerId']),
      totalTokens: serializer.fromJson<int?>(json['totalTokens']),
      isStreaming: serializer.fromJson<bool>(json['isStreaming']),
      reasoningText: serializer.fromJson<String?>(json['reasoningText']),
      reasoningStartAt: serializer.fromJson<DateTime?>(
        json['reasoningStartAt'],
      ),
      reasoningFinishedAt: serializer.fromJson<DateTime?>(
        json['reasoningFinishedAt'],
      ),
      translation: serializer.fromJson<String?>(json['translation']),
      reasoningSegmentsJson: serializer.fromJson<String?>(
        json['reasoningSegmentsJson'],
      ),
      groupId: serializer.fromJson<String?>(json['groupId']),
      subgroupId: serializer.fromJson<String?>(json['subgroupId']),
      version: serializer.fromJson<int>(json['version']),
      promptTokens: serializer.fromJson<int?>(json['promptTokens']),
      completionTokens: serializer.fromJson<int?>(json['completionTokens']),
      cachedTokens: serializer.fromJson<int?>(json['cachedTokens']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      messageOrder: serializer.fromJson<int>(json['messageOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'modelId': serializer.toJson<String?>(modelId),
      'providerId': serializer.toJson<String?>(providerId),
      'totalTokens': serializer.toJson<int?>(totalTokens),
      'isStreaming': serializer.toJson<bool>(isStreaming),
      'reasoningText': serializer.toJson<String?>(reasoningText),
      'reasoningStartAt': serializer.toJson<DateTime?>(reasoningStartAt),
      'reasoningFinishedAt': serializer.toJson<DateTime?>(reasoningFinishedAt),
      'translation': serializer.toJson<String?>(translation),
      'reasoningSegmentsJson': serializer.toJson<String?>(
        reasoningSegmentsJson,
      ),
      'groupId': serializer.toJson<String?>(groupId),
      'subgroupId': serializer.toJson<String?>(subgroupId),
      'version': serializer.toJson<int>(version),
      'promptTokens': serializer.toJson<int?>(promptTokens),
      'completionTokens': serializer.toJson<int?>(completionTokens),
      'cachedTokens': serializer.toJson<int?>(cachedTokens),
      'durationMs': serializer.toJson<int?>(durationMs),
      'messageOrder': serializer.toJson<int>(messageOrder),
    };
  }

  MessageRow copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    DateTime? timestamp,
    Value<String?> modelId = const Value.absent(),
    Value<String?> providerId = const Value.absent(),
    Value<int?> totalTokens = const Value.absent(),
    bool? isStreaming,
    Value<String?> reasoningText = const Value.absent(),
    Value<DateTime?> reasoningStartAt = const Value.absent(),
    Value<DateTime?> reasoningFinishedAt = const Value.absent(),
    Value<String?> translation = const Value.absent(),
    Value<String?> reasoningSegmentsJson = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    Value<String?> subgroupId = const Value.absent(),
    int? version,
    Value<int?> promptTokens = const Value.absent(),
    Value<int?> completionTokens = const Value.absent(),
    Value<int?> cachedTokens = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? messageOrder,
  }) => MessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    modelId: modelId.present ? modelId.value : this.modelId,
    providerId: providerId.present ? providerId.value : this.providerId,
    totalTokens: totalTokens.present ? totalTokens.value : this.totalTokens,
    isStreaming: isStreaming ?? this.isStreaming,
    reasoningText: reasoningText.present
        ? reasoningText.value
        : this.reasoningText,
    reasoningStartAt: reasoningStartAt.present
        ? reasoningStartAt.value
        : this.reasoningStartAt,
    reasoningFinishedAt: reasoningFinishedAt.present
        ? reasoningFinishedAt.value
        : this.reasoningFinishedAt,
    translation: translation.present ? translation.value : this.translation,
    reasoningSegmentsJson: reasoningSegmentsJson.present
        ? reasoningSegmentsJson.value
        : this.reasoningSegmentsJson,
    groupId: groupId.present ? groupId.value : this.groupId,
    subgroupId: subgroupId.present ? subgroupId.value : this.subgroupId,
    version: version ?? this.version,
    promptTokens: promptTokens.present ? promptTokens.value : this.promptTokens,
    completionTokens: completionTokens.present
        ? completionTokens.value
        : this.completionTokens,
    cachedTokens: cachedTokens.present ? cachedTokens.value : this.cachedTokens,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    messageOrder: messageOrder ?? this.messageOrder,
  );
  MessageRow copyWithCompanion(MessageRowsCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      totalTokens: data.totalTokens.present
          ? data.totalTokens.value
          : this.totalTokens,
      isStreaming: data.isStreaming.present
          ? data.isStreaming.value
          : this.isStreaming,
      reasoningText: data.reasoningText.present
          ? data.reasoningText.value
          : this.reasoningText,
      reasoningStartAt: data.reasoningStartAt.present
          ? data.reasoningStartAt.value
          : this.reasoningStartAt,
      reasoningFinishedAt: data.reasoningFinishedAt.present
          ? data.reasoningFinishedAt.value
          : this.reasoningFinishedAt,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      reasoningSegmentsJson: data.reasoningSegmentsJson.present
          ? data.reasoningSegmentsJson.value
          : this.reasoningSegmentsJson,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      subgroupId: data.subgroupId.present
          ? data.subgroupId.value
          : this.subgroupId,
      version: data.version.present ? data.version.value : this.version,
      promptTokens: data.promptTokens.present
          ? data.promptTokens.value
          : this.promptTokens,
      completionTokens: data.completionTokens.present
          ? data.completionTokens.value
          : this.completionTokens,
      cachedTokens: data.cachedTokens.present
          ? data.cachedTokens.value
          : this.cachedTokens,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      messageOrder: data.messageOrder.present
          ? data.messageOrder.value
          : this.messageOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('modelId: $modelId, ')
          ..write('providerId: $providerId, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('reasoningText: $reasoningText, ')
          ..write('reasoningStartAt: $reasoningStartAt, ')
          ..write('reasoningFinishedAt: $reasoningFinishedAt, ')
          ..write('translation: $translation, ')
          ..write('reasoningSegmentsJson: $reasoningSegmentsJson, ')
          ..write('groupId: $groupId, ')
          ..write('subgroupId: $subgroupId, ')
          ..write('version: $version, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('cachedTokens: $cachedTokens, ')
          ..write('durationMs: $durationMs, ')
          ..write('messageOrder: $messageOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    conversationId,
    role,
    content,
    timestamp,
    modelId,
    providerId,
    totalTokens,
    isStreaming,
    reasoningText,
    reasoningStartAt,
    reasoningFinishedAt,
    translation,
    reasoningSegmentsJson,
    groupId,
    subgroupId,
    version,
    promptTokens,
    completionTokens,
    cachedTokens,
    durationMs,
    messageOrder,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.modelId == this.modelId &&
          other.providerId == this.providerId &&
          other.totalTokens == this.totalTokens &&
          other.isStreaming == this.isStreaming &&
          other.reasoningText == this.reasoningText &&
          other.reasoningStartAt == this.reasoningStartAt &&
          other.reasoningFinishedAt == this.reasoningFinishedAt &&
          other.translation == this.translation &&
          other.reasoningSegmentsJson == this.reasoningSegmentsJson &&
          other.groupId == this.groupId &&
          other.subgroupId == this.subgroupId &&
          other.version == this.version &&
          other.promptTokens == this.promptTokens &&
          other.completionTokens == this.completionTokens &&
          other.cachedTokens == this.cachedTokens &&
          other.durationMs == this.durationMs &&
          other.messageOrder == this.messageOrder);
}

class MessageRowsCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<DateTime> timestamp;
  final Value<String?> modelId;
  final Value<String?> providerId;
  final Value<int?> totalTokens;
  final Value<bool> isStreaming;
  final Value<String?> reasoningText;
  final Value<DateTime?> reasoningStartAt;
  final Value<DateTime?> reasoningFinishedAt;
  final Value<String?> translation;
  final Value<String?> reasoningSegmentsJson;
  final Value<String?> groupId;
  final Value<String?> subgroupId;
  final Value<int> version;
  final Value<int?> promptTokens;
  final Value<int?> completionTokens;
  final Value<int?> cachedTokens;
  final Value<int?> durationMs;
  final Value<int> messageOrder;
  final Value<int> rowid;
  const MessageRowsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.modelId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.isStreaming = const Value.absent(),
    this.reasoningText = const Value.absent(),
    this.reasoningStartAt = const Value.absent(),
    this.reasoningFinishedAt = const Value.absent(),
    this.translation = const Value.absent(),
    this.reasoningSegmentsJson = const Value.absent(),
    this.groupId = const Value.absent(),
    this.subgroupId = const Value.absent(),
    this.version = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.cachedTokens = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.messageOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageRowsCompanion.insert({
    required String id,
    required String conversationId,
    required String role,
    required String content,
    required DateTime timestamp,
    this.modelId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.isStreaming = const Value.absent(),
    this.reasoningText = const Value.absent(),
    this.reasoningStartAt = const Value.absent(),
    this.reasoningFinishedAt = const Value.absent(),
    this.translation = const Value.absent(),
    this.reasoningSegmentsJson = const Value.absent(),
    this.groupId = const Value.absent(),
    this.subgroupId = const Value.absent(),
    this.version = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.cachedTokens = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int messageOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       role = Value(role),
       content = Value(content),
       timestamp = Value(timestamp),
       messageOrder = Value(messageOrder);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<DateTime>? timestamp,
    Expression<String>? modelId,
    Expression<String>? providerId,
    Expression<int>? totalTokens,
    Expression<bool>? isStreaming,
    Expression<String>? reasoningText,
    Expression<DateTime>? reasoningStartAt,
    Expression<DateTime>? reasoningFinishedAt,
    Expression<String>? translation,
    Expression<String>? reasoningSegmentsJson,
    Expression<String>? groupId,
    Expression<String>? subgroupId,
    Expression<int>? version,
    Expression<int>? promptTokens,
    Expression<int>? completionTokens,
    Expression<int>? cachedTokens,
    Expression<int>? durationMs,
    Expression<int>? messageOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (modelId != null) 'model_id': modelId,
      if (providerId != null) 'provider_id': providerId,
      if (totalTokens != null) 'total_tokens': totalTokens,
      if (isStreaming != null) 'is_streaming': isStreaming,
      if (reasoningText != null) 'reasoning_text': reasoningText,
      if (reasoningStartAt != null) 'reasoning_start_at': reasoningStartAt,
      if (reasoningFinishedAt != null)
        'reasoning_finished_at': reasoningFinishedAt,
      if (translation != null) 'translation': translation,
      if (reasoningSegmentsJson != null)
        'reasoning_segments_json': reasoningSegmentsJson,
      if (groupId != null) 'group_id': groupId,
      if (subgroupId != null) 'subgroup_id': subgroupId,
      if (version != null) 'version': version,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (cachedTokens != null) 'cached_tokens': cachedTokens,
      if (durationMs != null) 'duration_ms': durationMs,
      if (messageOrder != null) 'message_order': messageOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? role,
    Value<String>? content,
    Value<DateTime>? timestamp,
    Value<String?>? modelId,
    Value<String?>? providerId,
    Value<int?>? totalTokens,
    Value<bool>? isStreaming,
    Value<String?>? reasoningText,
    Value<DateTime?>? reasoningStartAt,
    Value<DateTime?>? reasoningFinishedAt,
    Value<String?>? translation,
    Value<String?>? reasoningSegmentsJson,
    Value<String?>? groupId,
    Value<String?>? subgroupId,
    Value<int>? version,
    Value<int?>? promptTokens,
    Value<int?>? completionTokens,
    Value<int?>? cachedTokens,
    Value<int?>? durationMs,
    Value<int>? messageOrder,
    Value<int>? rowid,
  }) {
    return MessageRowsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      totalTokens: totalTokens ?? this.totalTokens,
      isStreaming: isStreaming ?? this.isStreaming,
      reasoningText: reasoningText ?? this.reasoningText,
      reasoningStartAt: reasoningStartAt ?? this.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? this.reasoningFinishedAt,
      translation: translation ?? this.translation,
      reasoningSegmentsJson:
          reasoningSegmentsJson ?? this.reasoningSegmentsJson,
      groupId: groupId ?? this.groupId,
      subgroupId: subgroupId ?? this.subgroupId,
      version: version ?? this.version,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      durationMs: durationMs ?? this.durationMs,
      messageOrder: messageOrder ?? this.messageOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (totalTokens.present) {
      map['total_tokens'] = Variable<int>(totalTokens.value);
    }
    if (isStreaming.present) {
      map['is_streaming'] = Variable<bool>(isStreaming.value);
    }
    if (reasoningText.present) {
      map['reasoning_text'] = Variable<String>(reasoningText.value);
    }
    if (reasoningStartAt.present) {
      map['reasoning_start_at'] = Variable<DateTime>(reasoningStartAt.value);
    }
    if (reasoningFinishedAt.present) {
      map['reasoning_finished_at'] = Variable<DateTime>(
        reasoningFinishedAt.value,
      );
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (reasoningSegmentsJson.present) {
      map['reasoning_segments_json'] = Variable<String>(
        reasoningSegmentsJson.value,
      );
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (subgroupId.present) {
      map['subgroup_id'] = Variable<String>(subgroupId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (promptTokens.present) {
      map['prompt_tokens'] = Variable<int>(promptTokens.value);
    }
    if (completionTokens.present) {
      map['completion_tokens'] = Variable<int>(completionTokens.value);
    }
    if (cachedTokens.present) {
      map['cached_tokens'] = Variable<int>(cachedTokens.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (messageOrder.present) {
      map['message_order'] = Variable<int>(messageOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageRowsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('modelId: $modelId, ')
          ..write('providerId: $providerId, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('reasoningText: $reasoningText, ')
          ..write('reasoningStartAt: $reasoningStartAt, ')
          ..write('reasoningFinishedAt: $reasoningFinishedAt, ')
          ..write('translation: $translation, ')
          ..write('reasoningSegmentsJson: $reasoningSegmentsJson, ')
          ..write('groupId: $groupId, ')
          ..write('subgroupId: $subgroupId, ')
          ..write('version: $version, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('cachedTokens: $cachedTokens, ')
          ..write('durationMs: $durationMs, ')
          ..write('messageOrder: $messageOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantRowsTable extends AssistantRows
    with TableInfo<$AssistantRowsTable, AssistantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
    'avatar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useAssistantAvatarMeta =
      const VerificationMeta('useAssistantAvatar');
  @override
  late final GeneratedColumn<bool> useAssistantAvatar = GeneratedColumn<bool>(
    'use_assistant_avatar',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_assistant_avatar" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _useAssistantNameMeta = const VerificationMeta(
    'useAssistantName',
  );
  @override
  late final GeneratedColumn<bool> useAssistantName = GeneratedColumn<bool>(
    'use_assistant_name',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_assistant_name" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _backgroundMeta = const VerificationMeta(
    'background',
  );
  @override
  late final GeneratedColumn<String> background = GeneratedColumn<String>(
    'background',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chatModelProviderMeta = const VerificationMeta(
    'chatModelProvider',
  );
  @override
  late final GeneratedColumn<String> chatModelProvider =
      GeneratedColumn<String>(
        'chat_model_provider',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _chatModelIdMeta = const VerificationMeta(
    'chatModelId',
  );
  @override
  late final GeneratedColumn<String> chatModelId = GeneratedColumn<String>(
    'chat_model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topPMeta = const VerificationMeta('topP');
  @override
  late final GeneratedColumn<double> topP = GeneratedColumn<double>(
    'top_p',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextMessageSizeMeta =
      const VerificationMeta('contextMessageSize');
  @override
  late final GeneratedColumn<int> contextMessageSize = GeneratedColumn<int>(
    'context_message_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(64),
  );
  static const VerificationMeta _limitContextMessagesMeta =
      const VerificationMeta('limitContextMessages');
  @override
  late final GeneratedColumn<bool> limitContextMessages = GeneratedColumn<bool>(
    'limit_context_messages',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("limit_context_messages" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _streamOutputMeta = const VerificationMeta(
    'streamOutput',
  );
  @override
  late final GeneratedColumn<bool> streamOutput = GeneratedColumn<bool>(
    'stream_output',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("stream_output" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _thinkingBudgetMeta = const VerificationMeta(
    'thinkingBudget',
  );
  @override
  late final GeneratedColumn<int> thinkingBudget = GeneratedColumn<int>(
    'thinking_budget',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxTokensMeta = const VerificationMeta(
    'maxTokens',
  );
  @override
  late final GeneratedColumn<int> maxTokens = GeneratedColumn<int>(
    'max_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customHeadersJsonMeta = const VerificationMeta(
    'customHeadersJson',
  );
  @override
  late final GeneratedColumn<String> customHeadersJson =
      GeneratedColumn<String>(
        'custom_headers_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _customBodyJsonMeta = const VerificationMeta(
    'customBodyJson',
  );
  @override
  late final GeneratedColumn<String> customBodyJson = GeneratedColumn<String>(
    'custom_body_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _messageTemplateMeta = const VerificationMeta(
    'messageTemplate',
  );
  @override
  late final GeneratedColumn<String> messageTemplate = GeneratedColumn<String>(
    'message_template',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{{ message }}'),
  );
  static const VerificationMeta _presetMessagesJsonMeta =
      const VerificationMeta('presetMessagesJson');
  @override
  late final GeneratedColumn<String> presetMessagesJson =
      GeneratedColumn<String>(
        'preset_messages_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _searchEnabledMeta = const VerificationMeta(
    'searchEnabled',
  );
  @override
  late final GeneratedColumn<bool> searchEnabled = GeneratedColumn<bool>(
    'search_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("search_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mcpServerIdsJsonMeta = const VerificationMeta(
    'mcpServerIdsJson',
  );
  @override
  late final GeneratedColumn<String> mcpServerIdsJson = GeneratedColumn<String>(
    'mcp_server_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _localToolIdsJsonMeta = const VerificationMeta(
    'localToolIdsJson',
  );
  @override
  late final GeneratedColumn<String> localToolIdsJson = GeneratedColumn<String>(
    'local_tool_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _regexRulesJsonMeta = const VerificationMeta(
    'regexRulesJson',
  );
  @override
  late final GeneratedColumn<String> regexRulesJson = GeneratedColumn<String>(
    'regex_rules_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _enableMemoryMeta = const VerificationMeta(
    'enableMemory',
  );
  @override
  late final GeneratedColumn<bool> enableMemory = GeneratedColumn<bool>(
    'enable_memory',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enable_memory" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _memoryModeMeta = const VerificationMeta(
    'memoryMode',
  );
  @override
  late final GeneratedColumn<String> memoryMode = GeneratedColumn<String>(
    'memory_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('injection'),
  );
  static const VerificationMeta _enableRecentChatsReferenceMeta =
      const VerificationMeta('enableRecentChatsReference');
  @override
  late final GeneratedColumn<bool> enableRecentChatsReference =
      GeneratedColumn<bool>(
        'enable_recent_chats_reference',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enable_recent_chats_reference" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _recentChatsSummaryMessageCountMeta =
      const VerificationMeta('recentChatsSummaryMessageCount');
  @override
  late final GeneratedColumn<int> recentChatsSummaryMessageCount =
      GeneratedColumn<int>(
        'recent_chats_summary_message_count',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(5),
      );
  static const VerificationMeta _memoryRecordPromptMeta =
      const VerificationMeta('memoryRecordPrompt');
  @override
  late final GeneratedColumn<String> memoryRecordPrompt =
      GeneratedColumn<String>(
        'memory_record_prompt',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _docxModeMeta = const VerificationMeta(
    'docxMode',
  );
  @override
  late final GeneratedColumn<String> docxMode = GeneratedColumn<String>(
    'docx_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('extract'),
  );
  static const VerificationMeta _pdfModeMeta = const VerificationMeta(
    'pdfMode',
  );
  @override
  late final GeneratedColumn<String> pdfMode = GeneratedColumn<String>(
    'pdf_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('extract'),
  );
  static const VerificationMeta _otherOfficeModeMeta = const VerificationMeta(
    'otherOfficeMode',
  );
  @override
  late final GeneratedColumn<String> otherOfficeMode = GeneratedColumn<String>(
    'other_office_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('direct'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    avatar,
    useAssistantAvatar,
    useAssistantName,
    background,
    chatModelProvider,
    chatModelId,
    temperature,
    topP,
    contextMessageSize,
    limitContextMessages,
    streamOutput,
    thinkingBudget,
    maxTokens,
    customHeadersJson,
    customBodyJson,
    systemPrompt,
    messageTemplate,
    presetMessagesJson,
    searchEnabled,
    mcpServerIdsJson,
    localToolIdsJson,
    regexRulesJson,
    enableMemory,
    memoryMode,
    enableRecentChatsReference,
    recentChatsSummaryMessageCount,
    memoryRecordPrompt,
    docxMode,
    pdfMode,
    otherOfficeMode,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar')) {
      context.handle(
        _avatarMeta,
        avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta),
      );
    }
    if (data.containsKey('use_assistant_avatar')) {
      context.handle(
        _useAssistantAvatarMeta,
        useAssistantAvatar.isAcceptableOrUnknown(
          data['use_assistant_avatar']!,
          _useAssistantAvatarMeta,
        ),
      );
    }
    if (data.containsKey('use_assistant_name')) {
      context.handle(
        _useAssistantNameMeta,
        useAssistantName.isAcceptableOrUnknown(
          data['use_assistant_name']!,
          _useAssistantNameMeta,
        ),
      );
    }
    if (data.containsKey('background')) {
      context.handle(
        _backgroundMeta,
        background.isAcceptableOrUnknown(data['background']!, _backgroundMeta),
      );
    }
    if (data.containsKey('chat_model_provider')) {
      context.handle(
        _chatModelProviderMeta,
        chatModelProvider.isAcceptableOrUnknown(
          data['chat_model_provider']!,
          _chatModelProviderMeta,
        ),
      );
    }
    if (data.containsKey('chat_model_id')) {
      context.handle(
        _chatModelIdMeta,
        chatModelId.isAcceptableOrUnknown(
          data['chat_model_id']!,
          _chatModelIdMeta,
        ),
      );
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('top_p')) {
      context.handle(
        _topPMeta,
        topP.isAcceptableOrUnknown(data['top_p']!, _topPMeta),
      );
    }
    if (data.containsKey('context_message_size')) {
      context.handle(
        _contextMessageSizeMeta,
        contextMessageSize.isAcceptableOrUnknown(
          data['context_message_size']!,
          _contextMessageSizeMeta,
        ),
      );
    }
    if (data.containsKey('limit_context_messages')) {
      context.handle(
        _limitContextMessagesMeta,
        limitContextMessages.isAcceptableOrUnknown(
          data['limit_context_messages']!,
          _limitContextMessagesMeta,
        ),
      );
    }
    if (data.containsKey('stream_output')) {
      context.handle(
        _streamOutputMeta,
        streamOutput.isAcceptableOrUnknown(
          data['stream_output']!,
          _streamOutputMeta,
        ),
      );
    }
    if (data.containsKey('thinking_budget')) {
      context.handle(
        _thinkingBudgetMeta,
        thinkingBudget.isAcceptableOrUnknown(
          data['thinking_budget']!,
          _thinkingBudgetMeta,
        ),
      );
    }
    if (data.containsKey('max_tokens')) {
      context.handle(
        _maxTokensMeta,
        maxTokens.isAcceptableOrUnknown(data['max_tokens']!, _maxTokensMeta),
      );
    }
    if (data.containsKey('custom_headers_json')) {
      context.handle(
        _customHeadersJsonMeta,
        customHeadersJson.isAcceptableOrUnknown(
          data['custom_headers_json']!,
          _customHeadersJsonMeta,
        ),
      );
    }
    if (data.containsKey('custom_body_json')) {
      context.handle(
        _customBodyJsonMeta,
        customBodyJson.isAcceptableOrUnknown(
          data['custom_body_json']!,
          _customBodyJsonMeta,
        ),
      );
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    }
    if (data.containsKey('message_template')) {
      context.handle(
        _messageTemplateMeta,
        messageTemplate.isAcceptableOrUnknown(
          data['message_template']!,
          _messageTemplateMeta,
        ),
      );
    }
    if (data.containsKey('preset_messages_json')) {
      context.handle(
        _presetMessagesJsonMeta,
        presetMessagesJson.isAcceptableOrUnknown(
          data['preset_messages_json']!,
          _presetMessagesJsonMeta,
        ),
      );
    }
    if (data.containsKey('search_enabled')) {
      context.handle(
        _searchEnabledMeta,
        searchEnabled.isAcceptableOrUnknown(
          data['search_enabled']!,
          _searchEnabledMeta,
        ),
      );
    }
    if (data.containsKey('mcp_server_ids_json')) {
      context.handle(
        _mcpServerIdsJsonMeta,
        mcpServerIdsJson.isAcceptableOrUnknown(
          data['mcp_server_ids_json']!,
          _mcpServerIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('local_tool_ids_json')) {
      context.handle(
        _localToolIdsJsonMeta,
        localToolIdsJson.isAcceptableOrUnknown(
          data['local_tool_ids_json']!,
          _localToolIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('regex_rules_json')) {
      context.handle(
        _regexRulesJsonMeta,
        regexRulesJson.isAcceptableOrUnknown(
          data['regex_rules_json']!,
          _regexRulesJsonMeta,
        ),
      );
    }
    if (data.containsKey('enable_memory')) {
      context.handle(
        _enableMemoryMeta,
        enableMemory.isAcceptableOrUnknown(
          data['enable_memory']!,
          _enableMemoryMeta,
        ),
      );
    }
    if (data.containsKey('memory_mode')) {
      context.handle(
        _memoryModeMeta,
        memoryMode.isAcceptableOrUnknown(data['memory_mode']!, _memoryModeMeta),
      );
    }
    if (data.containsKey('enable_recent_chats_reference')) {
      context.handle(
        _enableRecentChatsReferenceMeta,
        enableRecentChatsReference.isAcceptableOrUnknown(
          data['enable_recent_chats_reference']!,
          _enableRecentChatsReferenceMeta,
        ),
      );
    }
    if (data.containsKey('recent_chats_summary_message_count')) {
      context.handle(
        _recentChatsSummaryMessageCountMeta,
        recentChatsSummaryMessageCount.isAcceptableOrUnknown(
          data['recent_chats_summary_message_count']!,
          _recentChatsSummaryMessageCountMeta,
        ),
      );
    }
    if (data.containsKey('memory_record_prompt')) {
      context.handle(
        _memoryRecordPromptMeta,
        memoryRecordPrompt.isAcceptableOrUnknown(
          data['memory_record_prompt']!,
          _memoryRecordPromptMeta,
        ),
      );
    }
    if (data.containsKey('docx_mode')) {
      context.handle(
        _docxModeMeta,
        docxMode.isAcceptableOrUnknown(data['docx_mode']!, _docxModeMeta),
      );
    }
    if (data.containsKey('pdf_mode')) {
      context.handle(
        _pdfModeMeta,
        pdfMode.isAcceptableOrUnknown(data['pdf_mode']!, _pdfModeMeta),
      );
    }
    if (data.containsKey('other_office_mode')) {
      context.handle(
        _otherOfficeModeMeta,
        otherOfficeMode.isAcceptableOrUnknown(
          data['other_office_mode']!,
          _otherOfficeModeMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar'],
      ),
      useAssistantAvatar: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_assistant_avatar'],
      )!,
      useAssistantName: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_assistant_name'],
      )!,
      background: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background'],
      ),
      chatModelProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_model_provider'],
      ),
      chatModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_model_id'],
      ),
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      ),
      topP: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top_p'],
      ),
      contextMessageSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context_message_size'],
      )!,
      limitContextMessages: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}limit_context_messages'],
      )!,
      streamOutput: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stream_output'],
      )!,
      thinkingBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thinking_budget'],
      ),
      maxTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_tokens'],
      ),
      customHeadersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_headers_json'],
      )!,
      customBodyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_body_json'],
      )!,
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      )!,
      messageTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_template'],
      )!,
      presetMessagesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_messages_json'],
      )!,
      searchEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}search_enabled'],
      )!,
      mcpServerIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mcp_server_ids_json'],
      )!,
      localToolIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_tool_ids_json'],
      )!,
      regexRulesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}regex_rules_json'],
      )!,
      enableMemory: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enable_memory'],
      )!,
      memoryMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_mode'],
      )!,
      enableRecentChatsReference: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enable_recent_chats_reference'],
      )!,
      recentChatsSummaryMessageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recent_chats_summary_message_count'],
      )!,
      memoryRecordPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_record_prompt'],
      )!,
      docxMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}docx_mode'],
      )!,
      pdfMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_mode'],
      )!,
      otherOfficeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_office_mode'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AssistantRowsTable createAlias(String alias) {
    return $AssistantRowsTable(attachedDatabase, alias);
  }
}

class AssistantRow extends DataClass implements Insertable<AssistantRow> {
  final String id;
  final String name;
  final String? avatar;
  final bool useAssistantAvatar;
  final bool useAssistantName;
  final String? background;
  final String? chatModelProvider;
  final String? chatModelId;
  final double? temperature;
  final double? topP;
  final int contextMessageSize;
  final bool limitContextMessages;
  final bool streamOutput;
  final int? thinkingBudget;
  final int? maxTokens;
  final String customHeadersJson;
  final String customBodyJson;
  final String systemPrompt;
  final String messageTemplate;
  final String presetMessagesJson;
  final bool searchEnabled;
  final String mcpServerIdsJson;
  final String localToolIdsJson;
  final String regexRulesJson;
  final bool enableMemory;
  final String memoryMode;
  final bool enableRecentChatsReference;
  final int recentChatsSummaryMessageCount;
  final String memoryRecordPrompt;
  final String docxMode;
  final String pdfMode;
  final String otherOfficeMode;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AssistantRow({
    required this.id,
    required this.name,
    this.avatar,
    required this.useAssistantAvatar,
    required this.useAssistantName,
    this.background,
    this.chatModelProvider,
    this.chatModelId,
    this.temperature,
    this.topP,
    required this.contextMessageSize,
    required this.limitContextMessages,
    required this.streamOutput,
    this.thinkingBudget,
    this.maxTokens,
    required this.customHeadersJson,
    required this.customBodyJson,
    required this.systemPrompt,
    required this.messageTemplate,
    required this.presetMessagesJson,
    required this.searchEnabled,
    required this.mcpServerIdsJson,
    required this.localToolIdsJson,
    required this.regexRulesJson,
    required this.enableMemory,
    required this.memoryMode,
    required this.enableRecentChatsReference,
    required this.recentChatsSummaryMessageCount,
    required this.memoryRecordPrompt,
    required this.docxMode,
    required this.pdfMode,
    required this.otherOfficeMode,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || avatar != null) {
      map['avatar'] = Variable<String>(avatar);
    }
    map['use_assistant_avatar'] = Variable<bool>(useAssistantAvatar);
    map['use_assistant_name'] = Variable<bool>(useAssistantName);
    if (!nullToAbsent || background != null) {
      map['background'] = Variable<String>(background);
    }
    if (!nullToAbsent || chatModelProvider != null) {
      map['chat_model_provider'] = Variable<String>(chatModelProvider);
    }
    if (!nullToAbsent || chatModelId != null) {
      map['chat_model_id'] = Variable<String>(chatModelId);
    }
    if (!nullToAbsent || temperature != null) {
      map['temperature'] = Variable<double>(temperature);
    }
    if (!nullToAbsent || topP != null) {
      map['top_p'] = Variable<double>(topP);
    }
    map['context_message_size'] = Variable<int>(contextMessageSize);
    map['limit_context_messages'] = Variable<bool>(limitContextMessages);
    map['stream_output'] = Variable<bool>(streamOutput);
    if (!nullToAbsent || thinkingBudget != null) {
      map['thinking_budget'] = Variable<int>(thinkingBudget);
    }
    if (!nullToAbsent || maxTokens != null) {
      map['max_tokens'] = Variable<int>(maxTokens);
    }
    map['custom_headers_json'] = Variable<String>(customHeadersJson);
    map['custom_body_json'] = Variable<String>(customBodyJson);
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['message_template'] = Variable<String>(messageTemplate);
    map['preset_messages_json'] = Variable<String>(presetMessagesJson);
    map['search_enabled'] = Variable<bool>(searchEnabled);
    map['mcp_server_ids_json'] = Variable<String>(mcpServerIdsJson);
    map['local_tool_ids_json'] = Variable<String>(localToolIdsJson);
    map['regex_rules_json'] = Variable<String>(regexRulesJson);
    map['enable_memory'] = Variable<bool>(enableMemory);
    map['memory_mode'] = Variable<String>(memoryMode);
    map['enable_recent_chats_reference'] = Variable<bool>(
      enableRecentChatsReference,
    );
    map['recent_chats_summary_message_count'] = Variable<int>(
      recentChatsSummaryMessageCount,
    );
    map['memory_record_prompt'] = Variable<String>(memoryRecordPrompt);
    map['docx_mode'] = Variable<String>(docxMode);
    map['pdf_mode'] = Variable<String>(pdfMode);
    map['other_office_mode'] = Variable<String>(otherOfficeMode);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AssistantRowsCompanion toCompanion(bool nullToAbsent) {
    return AssistantRowsCompanion(
      id: Value(id),
      name: Value(name),
      avatar: avatar == null && nullToAbsent
          ? const Value.absent()
          : Value(avatar),
      useAssistantAvatar: Value(useAssistantAvatar),
      useAssistantName: Value(useAssistantName),
      background: background == null && nullToAbsent
          ? const Value.absent()
          : Value(background),
      chatModelProvider: chatModelProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(chatModelProvider),
      chatModelId: chatModelId == null && nullToAbsent
          ? const Value.absent()
          : Value(chatModelId),
      temperature: temperature == null && nullToAbsent
          ? const Value.absent()
          : Value(temperature),
      topP: topP == null && nullToAbsent ? const Value.absent() : Value(topP),
      contextMessageSize: Value(contextMessageSize),
      limitContextMessages: Value(limitContextMessages),
      streamOutput: Value(streamOutput),
      thinkingBudget: thinkingBudget == null && nullToAbsent
          ? const Value.absent()
          : Value(thinkingBudget),
      maxTokens: maxTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxTokens),
      customHeadersJson: Value(customHeadersJson),
      customBodyJson: Value(customBodyJson),
      systemPrompt: Value(systemPrompt),
      messageTemplate: Value(messageTemplate),
      presetMessagesJson: Value(presetMessagesJson),
      searchEnabled: Value(searchEnabled),
      mcpServerIdsJson: Value(mcpServerIdsJson),
      localToolIdsJson: Value(localToolIdsJson),
      regexRulesJson: Value(regexRulesJson),
      enableMemory: Value(enableMemory),
      memoryMode: Value(memoryMode),
      enableRecentChatsReference: Value(enableRecentChatsReference),
      recentChatsSummaryMessageCount: Value(recentChatsSummaryMessageCount),
      memoryRecordPrompt: Value(memoryRecordPrompt),
      docxMode: Value(docxMode),
      pdfMode: Value(pdfMode),
      otherOfficeMode: Value(otherOfficeMode),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AssistantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatar: serializer.fromJson<String?>(json['avatar']),
      useAssistantAvatar: serializer.fromJson<bool>(json['useAssistantAvatar']),
      useAssistantName: serializer.fromJson<bool>(json['useAssistantName']),
      background: serializer.fromJson<String?>(json['background']),
      chatModelProvider: serializer.fromJson<String?>(
        json['chatModelProvider'],
      ),
      chatModelId: serializer.fromJson<String?>(json['chatModelId']),
      temperature: serializer.fromJson<double?>(json['temperature']),
      topP: serializer.fromJson<double?>(json['topP']),
      contextMessageSize: serializer.fromJson<int>(json['contextMessageSize']),
      limitContextMessages: serializer.fromJson<bool>(
        json['limitContextMessages'],
      ),
      streamOutput: serializer.fromJson<bool>(json['streamOutput']),
      thinkingBudget: serializer.fromJson<int?>(json['thinkingBudget']),
      maxTokens: serializer.fromJson<int?>(json['maxTokens']),
      customHeadersJson: serializer.fromJson<String>(json['customHeadersJson']),
      customBodyJson: serializer.fromJson<String>(json['customBodyJson']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      messageTemplate: serializer.fromJson<String>(json['messageTemplate']),
      presetMessagesJson: serializer.fromJson<String>(
        json['presetMessagesJson'],
      ),
      searchEnabled: serializer.fromJson<bool>(json['searchEnabled']),
      mcpServerIdsJson: serializer.fromJson<String>(json['mcpServerIdsJson']),
      localToolIdsJson: serializer.fromJson<String>(json['localToolIdsJson']),
      regexRulesJson: serializer.fromJson<String>(json['regexRulesJson']),
      enableMemory: serializer.fromJson<bool>(json['enableMemory']),
      memoryMode: serializer.fromJson<String>(json['memoryMode']),
      enableRecentChatsReference: serializer.fromJson<bool>(
        json['enableRecentChatsReference'],
      ),
      recentChatsSummaryMessageCount: serializer.fromJson<int>(
        json['recentChatsSummaryMessageCount'],
      ),
      memoryRecordPrompt: serializer.fromJson<String>(
        json['memoryRecordPrompt'],
      ),
      docxMode: serializer.fromJson<String>(json['docxMode']),
      pdfMode: serializer.fromJson<String>(json['pdfMode']),
      otherOfficeMode: serializer.fromJson<String>(json['otherOfficeMode']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'avatar': serializer.toJson<String?>(avatar),
      'useAssistantAvatar': serializer.toJson<bool>(useAssistantAvatar),
      'useAssistantName': serializer.toJson<bool>(useAssistantName),
      'background': serializer.toJson<String?>(background),
      'chatModelProvider': serializer.toJson<String?>(chatModelProvider),
      'chatModelId': serializer.toJson<String?>(chatModelId),
      'temperature': serializer.toJson<double?>(temperature),
      'topP': serializer.toJson<double?>(topP),
      'contextMessageSize': serializer.toJson<int>(contextMessageSize),
      'limitContextMessages': serializer.toJson<bool>(limitContextMessages),
      'streamOutput': serializer.toJson<bool>(streamOutput),
      'thinkingBudget': serializer.toJson<int?>(thinkingBudget),
      'maxTokens': serializer.toJson<int?>(maxTokens),
      'customHeadersJson': serializer.toJson<String>(customHeadersJson),
      'customBodyJson': serializer.toJson<String>(customBodyJson),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'messageTemplate': serializer.toJson<String>(messageTemplate),
      'presetMessagesJson': serializer.toJson<String>(presetMessagesJson),
      'searchEnabled': serializer.toJson<bool>(searchEnabled),
      'mcpServerIdsJson': serializer.toJson<String>(mcpServerIdsJson),
      'localToolIdsJson': serializer.toJson<String>(localToolIdsJson),
      'regexRulesJson': serializer.toJson<String>(regexRulesJson),
      'enableMemory': serializer.toJson<bool>(enableMemory),
      'memoryMode': serializer.toJson<String>(memoryMode),
      'enableRecentChatsReference': serializer.toJson<bool>(
        enableRecentChatsReference,
      ),
      'recentChatsSummaryMessageCount': serializer.toJson<int>(
        recentChatsSummaryMessageCount,
      ),
      'memoryRecordPrompt': serializer.toJson<String>(memoryRecordPrompt),
      'docxMode': serializer.toJson<String>(docxMode),
      'pdfMode': serializer.toJson<String>(pdfMode),
      'otherOfficeMode': serializer.toJson<String>(otherOfficeMode),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssistantRow copyWith({
    String? id,
    String? name,
    Value<String?> avatar = const Value.absent(),
    bool? useAssistantAvatar,
    bool? useAssistantName,
    Value<String?> background = const Value.absent(),
    Value<String?> chatModelProvider = const Value.absent(),
    Value<String?> chatModelId = const Value.absent(),
    Value<double?> temperature = const Value.absent(),
    Value<double?> topP = const Value.absent(),
    int? contextMessageSize,
    bool? limitContextMessages,
    bool? streamOutput,
    Value<int?> thinkingBudget = const Value.absent(),
    Value<int?> maxTokens = const Value.absent(),
    String? customHeadersJson,
    String? customBodyJson,
    String? systemPrompt,
    String? messageTemplate,
    String? presetMessagesJson,
    bool? searchEnabled,
    String? mcpServerIdsJson,
    String? localToolIdsJson,
    String? regexRulesJson,
    bool? enableMemory,
    String? memoryMode,
    bool? enableRecentChatsReference,
    int? recentChatsSummaryMessageCount,
    String? memoryRecordPrompt,
    String? docxMode,
    String? pdfMode,
    String? otherOfficeMode,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AssistantRow(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar.present ? avatar.value : this.avatar,
    useAssistantAvatar: useAssistantAvatar ?? this.useAssistantAvatar,
    useAssistantName: useAssistantName ?? this.useAssistantName,
    background: background.present ? background.value : this.background,
    chatModelProvider: chatModelProvider.present
        ? chatModelProvider.value
        : this.chatModelProvider,
    chatModelId: chatModelId.present ? chatModelId.value : this.chatModelId,
    temperature: temperature.present ? temperature.value : this.temperature,
    topP: topP.present ? topP.value : this.topP,
    contextMessageSize: contextMessageSize ?? this.contextMessageSize,
    limitContextMessages: limitContextMessages ?? this.limitContextMessages,
    streamOutput: streamOutput ?? this.streamOutput,
    thinkingBudget: thinkingBudget.present
        ? thinkingBudget.value
        : this.thinkingBudget,
    maxTokens: maxTokens.present ? maxTokens.value : this.maxTokens,
    customHeadersJson: customHeadersJson ?? this.customHeadersJson,
    customBodyJson: customBodyJson ?? this.customBodyJson,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    messageTemplate: messageTemplate ?? this.messageTemplate,
    presetMessagesJson: presetMessagesJson ?? this.presetMessagesJson,
    searchEnabled: searchEnabled ?? this.searchEnabled,
    mcpServerIdsJson: mcpServerIdsJson ?? this.mcpServerIdsJson,
    localToolIdsJson: localToolIdsJson ?? this.localToolIdsJson,
    regexRulesJson: regexRulesJson ?? this.regexRulesJson,
    enableMemory: enableMemory ?? this.enableMemory,
    memoryMode: memoryMode ?? this.memoryMode,
    enableRecentChatsReference:
        enableRecentChatsReference ?? this.enableRecentChatsReference,
    recentChatsSummaryMessageCount:
        recentChatsSummaryMessageCount ?? this.recentChatsSummaryMessageCount,
    memoryRecordPrompt: memoryRecordPrompt ?? this.memoryRecordPrompt,
    docxMode: docxMode ?? this.docxMode,
    pdfMode: pdfMode ?? this.pdfMode,
    otherOfficeMode: otherOfficeMode ?? this.otherOfficeMode,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AssistantRow copyWithCompanion(AssistantRowsCompanion data) {
    return AssistantRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      useAssistantAvatar: data.useAssistantAvatar.present
          ? data.useAssistantAvatar.value
          : this.useAssistantAvatar,
      useAssistantName: data.useAssistantName.present
          ? data.useAssistantName.value
          : this.useAssistantName,
      background: data.background.present
          ? data.background.value
          : this.background,
      chatModelProvider: data.chatModelProvider.present
          ? data.chatModelProvider.value
          : this.chatModelProvider,
      chatModelId: data.chatModelId.present
          ? data.chatModelId.value
          : this.chatModelId,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      topP: data.topP.present ? data.topP.value : this.topP,
      contextMessageSize: data.contextMessageSize.present
          ? data.contextMessageSize.value
          : this.contextMessageSize,
      limitContextMessages: data.limitContextMessages.present
          ? data.limitContextMessages.value
          : this.limitContextMessages,
      streamOutput: data.streamOutput.present
          ? data.streamOutput.value
          : this.streamOutput,
      thinkingBudget: data.thinkingBudget.present
          ? data.thinkingBudget.value
          : this.thinkingBudget,
      maxTokens: data.maxTokens.present ? data.maxTokens.value : this.maxTokens,
      customHeadersJson: data.customHeadersJson.present
          ? data.customHeadersJson.value
          : this.customHeadersJson,
      customBodyJson: data.customBodyJson.present
          ? data.customBodyJson.value
          : this.customBodyJson,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      messageTemplate: data.messageTemplate.present
          ? data.messageTemplate.value
          : this.messageTemplate,
      presetMessagesJson: data.presetMessagesJson.present
          ? data.presetMessagesJson.value
          : this.presetMessagesJson,
      searchEnabled: data.searchEnabled.present
          ? data.searchEnabled.value
          : this.searchEnabled,
      mcpServerIdsJson: data.mcpServerIdsJson.present
          ? data.mcpServerIdsJson.value
          : this.mcpServerIdsJson,
      localToolIdsJson: data.localToolIdsJson.present
          ? data.localToolIdsJson.value
          : this.localToolIdsJson,
      regexRulesJson: data.regexRulesJson.present
          ? data.regexRulesJson.value
          : this.regexRulesJson,
      enableMemory: data.enableMemory.present
          ? data.enableMemory.value
          : this.enableMemory,
      memoryMode: data.memoryMode.present
          ? data.memoryMode.value
          : this.memoryMode,
      enableRecentChatsReference: data.enableRecentChatsReference.present
          ? data.enableRecentChatsReference.value
          : this.enableRecentChatsReference,
      recentChatsSummaryMessageCount:
          data.recentChatsSummaryMessageCount.present
          ? data.recentChatsSummaryMessageCount.value
          : this.recentChatsSummaryMessageCount,
      memoryRecordPrompt: data.memoryRecordPrompt.present
          ? data.memoryRecordPrompt.value
          : this.memoryRecordPrompt,
      docxMode: data.docxMode.present ? data.docxMode.value : this.docxMode,
      pdfMode: data.pdfMode.present ? data.pdfMode.value : this.pdfMode,
      otherOfficeMode: data.otherOfficeMode.present
          ? data.otherOfficeMode.value
          : this.otherOfficeMode,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('useAssistantAvatar: $useAssistantAvatar, ')
          ..write('useAssistantName: $useAssistantName, ')
          ..write('background: $background, ')
          ..write('chatModelProvider: $chatModelProvider, ')
          ..write('chatModelId: $chatModelId, ')
          ..write('temperature: $temperature, ')
          ..write('topP: $topP, ')
          ..write('contextMessageSize: $contextMessageSize, ')
          ..write('limitContextMessages: $limitContextMessages, ')
          ..write('streamOutput: $streamOutput, ')
          ..write('thinkingBudget: $thinkingBudget, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('customHeadersJson: $customHeadersJson, ')
          ..write('customBodyJson: $customBodyJson, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('messageTemplate: $messageTemplate, ')
          ..write('presetMessagesJson: $presetMessagesJson, ')
          ..write('searchEnabled: $searchEnabled, ')
          ..write('mcpServerIdsJson: $mcpServerIdsJson, ')
          ..write('localToolIdsJson: $localToolIdsJson, ')
          ..write('regexRulesJson: $regexRulesJson, ')
          ..write('enableMemory: $enableMemory, ')
          ..write('memoryMode: $memoryMode, ')
          ..write('enableRecentChatsReference: $enableRecentChatsReference, ')
          ..write(
            'recentChatsSummaryMessageCount: $recentChatsSummaryMessageCount, ',
          )
          ..write('memoryRecordPrompt: $memoryRecordPrompt, ')
          ..write('docxMode: $docxMode, ')
          ..write('pdfMode: $pdfMode, ')
          ..write('otherOfficeMode: $otherOfficeMode, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    avatar,
    useAssistantAvatar,
    useAssistantName,
    background,
    chatModelProvider,
    chatModelId,
    temperature,
    topP,
    contextMessageSize,
    limitContextMessages,
    streamOutput,
    thinkingBudget,
    maxTokens,
    customHeadersJson,
    customBodyJson,
    systemPrompt,
    messageTemplate,
    presetMessagesJson,
    searchEnabled,
    mcpServerIdsJson,
    localToolIdsJson,
    regexRulesJson,
    enableMemory,
    memoryMode,
    enableRecentChatsReference,
    recentChatsSummaryMessageCount,
    memoryRecordPrompt,
    docxMode,
    pdfMode,
    otherOfficeMode,
    sortOrder,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatar == this.avatar &&
          other.useAssistantAvatar == this.useAssistantAvatar &&
          other.useAssistantName == this.useAssistantName &&
          other.background == this.background &&
          other.chatModelProvider == this.chatModelProvider &&
          other.chatModelId == this.chatModelId &&
          other.temperature == this.temperature &&
          other.topP == this.topP &&
          other.contextMessageSize == this.contextMessageSize &&
          other.limitContextMessages == this.limitContextMessages &&
          other.streamOutput == this.streamOutput &&
          other.thinkingBudget == this.thinkingBudget &&
          other.maxTokens == this.maxTokens &&
          other.customHeadersJson == this.customHeadersJson &&
          other.customBodyJson == this.customBodyJson &&
          other.systemPrompt == this.systemPrompt &&
          other.messageTemplate == this.messageTemplate &&
          other.presetMessagesJson == this.presetMessagesJson &&
          other.searchEnabled == this.searchEnabled &&
          other.mcpServerIdsJson == this.mcpServerIdsJson &&
          other.localToolIdsJson == this.localToolIdsJson &&
          other.regexRulesJson == this.regexRulesJson &&
          other.enableMemory == this.enableMemory &&
          other.memoryMode == this.memoryMode &&
          other.enableRecentChatsReference == this.enableRecentChatsReference &&
          other.recentChatsSummaryMessageCount ==
              this.recentChatsSummaryMessageCount &&
          other.memoryRecordPrompt == this.memoryRecordPrompt &&
          other.docxMode == this.docxMode &&
          other.pdfMode == this.pdfMode &&
          other.otherOfficeMode == this.otherOfficeMode &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AssistantRowsCompanion extends UpdateCompanion<AssistantRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> avatar;
  final Value<bool> useAssistantAvatar;
  final Value<bool> useAssistantName;
  final Value<String?> background;
  final Value<String?> chatModelProvider;
  final Value<String?> chatModelId;
  final Value<double?> temperature;
  final Value<double?> topP;
  final Value<int> contextMessageSize;
  final Value<bool> limitContextMessages;
  final Value<bool> streamOutput;
  final Value<int?> thinkingBudget;
  final Value<int?> maxTokens;
  final Value<String> customHeadersJson;
  final Value<String> customBodyJson;
  final Value<String> systemPrompt;
  final Value<String> messageTemplate;
  final Value<String> presetMessagesJson;
  final Value<bool> searchEnabled;
  final Value<String> mcpServerIdsJson;
  final Value<String> localToolIdsJson;
  final Value<String> regexRulesJson;
  final Value<bool> enableMemory;
  final Value<String> memoryMode;
  final Value<bool> enableRecentChatsReference;
  final Value<int> recentChatsSummaryMessageCount;
  final Value<String> memoryRecordPrompt;
  final Value<String> docxMode;
  final Value<String> pdfMode;
  final Value<String> otherOfficeMode;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AssistantRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatar = const Value.absent(),
    this.useAssistantAvatar = const Value.absent(),
    this.useAssistantName = const Value.absent(),
    this.background = const Value.absent(),
    this.chatModelProvider = const Value.absent(),
    this.chatModelId = const Value.absent(),
    this.temperature = const Value.absent(),
    this.topP = const Value.absent(),
    this.contextMessageSize = const Value.absent(),
    this.limitContextMessages = const Value.absent(),
    this.streamOutput = const Value.absent(),
    this.thinkingBudget = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.customHeadersJson = const Value.absent(),
    this.customBodyJson = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.messageTemplate = const Value.absent(),
    this.presetMessagesJson = const Value.absent(),
    this.searchEnabled = const Value.absent(),
    this.mcpServerIdsJson = const Value.absent(),
    this.localToolIdsJson = const Value.absent(),
    this.regexRulesJson = const Value.absent(),
    this.enableMemory = const Value.absent(),
    this.memoryMode = const Value.absent(),
    this.enableRecentChatsReference = const Value.absent(),
    this.recentChatsSummaryMessageCount = const Value.absent(),
    this.memoryRecordPrompt = const Value.absent(),
    this.docxMode = const Value.absent(),
    this.pdfMode = const Value.absent(),
    this.otherOfficeMode = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantRowsCompanion.insert({
    required String id,
    required String name,
    this.avatar = const Value.absent(),
    this.useAssistantAvatar = const Value.absent(),
    this.useAssistantName = const Value.absent(),
    this.background = const Value.absent(),
    this.chatModelProvider = const Value.absent(),
    this.chatModelId = const Value.absent(),
    this.temperature = const Value.absent(),
    this.topP = const Value.absent(),
    this.contextMessageSize = const Value.absent(),
    this.limitContextMessages = const Value.absent(),
    this.streamOutput = const Value.absent(),
    this.thinkingBudget = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.customHeadersJson = const Value.absent(),
    this.customBodyJson = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.messageTemplate = const Value.absent(),
    this.presetMessagesJson = const Value.absent(),
    this.searchEnabled = const Value.absent(),
    this.mcpServerIdsJson = const Value.absent(),
    this.localToolIdsJson = const Value.absent(),
    this.regexRulesJson = const Value.absent(),
    this.enableMemory = const Value.absent(),
    this.memoryMode = const Value.absent(),
    this.enableRecentChatsReference = const Value.absent(),
    this.recentChatsSummaryMessageCount = const Value.absent(),
    this.memoryRecordPrompt = const Value.absent(),
    this.docxMode = const Value.absent(),
    this.pdfMode = const Value.absent(),
    this.otherOfficeMode = const Value.absent(),
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AssistantRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? avatar,
    Expression<bool>? useAssistantAvatar,
    Expression<bool>? useAssistantName,
    Expression<String>? background,
    Expression<String>? chatModelProvider,
    Expression<String>? chatModelId,
    Expression<double>? temperature,
    Expression<double>? topP,
    Expression<int>? contextMessageSize,
    Expression<bool>? limitContextMessages,
    Expression<bool>? streamOutput,
    Expression<int>? thinkingBudget,
    Expression<int>? maxTokens,
    Expression<String>? customHeadersJson,
    Expression<String>? customBodyJson,
    Expression<String>? systemPrompt,
    Expression<String>? messageTemplate,
    Expression<String>? presetMessagesJson,
    Expression<bool>? searchEnabled,
    Expression<String>? mcpServerIdsJson,
    Expression<String>? localToolIdsJson,
    Expression<String>? regexRulesJson,
    Expression<bool>? enableMemory,
    Expression<String>? memoryMode,
    Expression<bool>? enableRecentChatsReference,
    Expression<int>? recentChatsSummaryMessageCount,
    Expression<String>? memoryRecordPrompt,
    Expression<String>? docxMode,
    Expression<String>? pdfMode,
    Expression<String>? otherOfficeMode,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatar != null) 'avatar': avatar,
      if (useAssistantAvatar != null)
        'use_assistant_avatar': useAssistantAvatar,
      if (useAssistantName != null) 'use_assistant_name': useAssistantName,
      if (background != null) 'background': background,
      if (chatModelProvider != null) 'chat_model_provider': chatModelProvider,
      if (chatModelId != null) 'chat_model_id': chatModelId,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (contextMessageSize != null)
        'context_message_size': contextMessageSize,
      if (limitContextMessages != null)
        'limit_context_messages': limitContextMessages,
      if (streamOutput != null) 'stream_output': streamOutput,
      if (thinkingBudget != null) 'thinking_budget': thinkingBudget,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (customHeadersJson != null) 'custom_headers_json': customHeadersJson,
      if (customBodyJson != null) 'custom_body_json': customBodyJson,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (messageTemplate != null) 'message_template': messageTemplate,
      if (presetMessagesJson != null)
        'preset_messages_json': presetMessagesJson,
      if (searchEnabled != null) 'search_enabled': searchEnabled,
      if (mcpServerIdsJson != null) 'mcp_server_ids_json': mcpServerIdsJson,
      if (localToolIdsJson != null) 'local_tool_ids_json': localToolIdsJson,
      if (regexRulesJson != null) 'regex_rules_json': regexRulesJson,
      if (enableMemory != null) 'enable_memory': enableMemory,
      if (memoryMode != null) 'memory_mode': memoryMode,
      if (enableRecentChatsReference != null)
        'enable_recent_chats_reference': enableRecentChatsReference,
      if (recentChatsSummaryMessageCount != null)
        'recent_chats_summary_message_count': recentChatsSummaryMessageCount,
      if (memoryRecordPrompt != null)
        'memory_record_prompt': memoryRecordPrompt,
      if (docxMode != null) 'docx_mode': docxMode,
      if (pdfMode != null) 'pdf_mode': pdfMode,
      if (otherOfficeMode != null) 'other_office_mode': otherOfficeMode,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? avatar,
    Value<bool>? useAssistantAvatar,
    Value<bool>? useAssistantName,
    Value<String?>? background,
    Value<String?>? chatModelProvider,
    Value<String?>? chatModelId,
    Value<double?>? temperature,
    Value<double?>? topP,
    Value<int>? contextMessageSize,
    Value<bool>? limitContextMessages,
    Value<bool>? streamOutput,
    Value<int?>? thinkingBudget,
    Value<int?>? maxTokens,
    Value<String>? customHeadersJson,
    Value<String>? customBodyJson,
    Value<String>? systemPrompt,
    Value<String>? messageTemplate,
    Value<String>? presetMessagesJson,
    Value<bool>? searchEnabled,
    Value<String>? mcpServerIdsJson,
    Value<String>? localToolIdsJson,
    Value<String>? regexRulesJson,
    Value<bool>? enableMemory,
    Value<String>? memoryMode,
    Value<bool>? enableRecentChatsReference,
    Value<int>? recentChatsSummaryMessageCount,
    Value<String>? memoryRecordPrompt,
    Value<String>? docxMode,
    Value<String>? pdfMode,
    Value<String>? otherOfficeMode,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AssistantRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      useAssistantAvatar: useAssistantAvatar ?? this.useAssistantAvatar,
      useAssistantName: useAssistantName ?? this.useAssistantName,
      background: background ?? this.background,
      chatModelProvider: chatModelProvider ?? this.chatModelProvider,
      chatModelId: chatModelId ?? this.chatModelId,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      contextMessageSize: contextMessageSize ?? this.contextMessageSize,
      limitContextMessages: limitContextMessages ?? this.limitContextMessages,
      streamOutput: streamOutput ?? this.streamOutput,
      thinkingBudget: thinkingBudget ?? this.thinkingBudget,
      maxTokens: maxTokens ?? this.maxTokens,
      customHeadersJson: customHeadersJson ?? this.customHeadersJson,
      customBodyJson: customBodyJson ?? this.customBodyJson,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      presetMessagesJson: presetMessagesJson ?? this.presetMessagesJson,
      searchEnabled: searchEnabled ?? this.searchEnabled,
      mcpServerIdsJson: mcpServerIdsJson ?? this.mcpServerIdsJson,
      localToolIdsJson: localToolIdsJson ?? this.localToolIdsJson,
      regexRulesJson: regexRulesJson ?? this.regexRulesJson,
      enableMemory: enableMemory ?? this.enableMemory,
      memoryMode: memoryMode ?? this.memoryMode,
      enableRecentChatsReference:
          enableRecentChatsReference ?? this.enableRecentChatsReference,
      recentChatsSummaryMessageCount:
          recentChatsSummaryMessageCount ?? this.recentChatsSummaryMessageCount,
      memoryRecordPrompt: memoryRecordPrompt ?? this.memoryRecordPrompt,
      docxMode: docxMode ?? this.docxMode,
      pdfMode: pdfMode ?? this.pdfMode,
      otherOfficeMode: otherOfficeMode ?? this.otherOfficeMode,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (useAssistantAvatar.present) {
      map['use_assistant_avatar'] = Variable<bool>(useAssistantAvatar.value);
    }
    if (useAssistantName.present) {
      map['use_assistant_name'] = Variable<bool>(useAssistantName.value);
    }
    if (background.present) {
      map['background'] = Variable<String>(background.value);
    }
    if (chatModelProvider.present) {
      map['chat_model_provider'] = Variable<String>(chatModelProvider.value);
    }
    if (chatModelId.present) {
      map['chat_model_id'] = Variable<String>(chatModelId.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (topP.present) {
      map['top_p'] = Variable<double>(topP.value);
    }
    if (contextMessageSize.present) {
      map['context_message_size'] = Variable<int>(contextMessageSize.value);
    }
    if (limitContextMessages.present) {
      map['limit_context_messages'] = Variable<bool>(
        limitContextMessages.value,
      );
    }
    if (streamOutput.present) {
      map['stream_output'] = Variable<bool>(streamOutput.value);
    }
    if (thinkingBudget.present) {
      map['thinking_budget'] = Variable<int>(thinkingBudget.value);
    }
    if (maxTokens.present) {
      map['max_tokens'] = Variable<int>(maxTokens.value);
    }
    if (customHeadersJson.present) {
      map['custom_headers_json'] = Variable<String>(customHeadersJson.value);
    }
    if (customBodyJson.present) {
      map['custom_body_json'] = Variable<String>(customBodyJson.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (messageTemplate.present) {
      map['message_template'] = Variable<String>(messageTemplate.value);
    }
    if (presetMessagesJson.present) {
      map['preset_messages_json'] = Variable<String>(presetMessagesJson.value);
    }
    if (searchEnabled.present) {
      map['search_enabled'] = Variable<bool>(searchEnabled.value);
    }
    if (mcpServerIdsJson.present) {
      map['mcp_server_ids_json'] = Variable<String>(mcpServerIdsJson.value);
    }
    if (localToolIdsJson.present) {
      map['local_tool_ids_json'] = Variable<String>(localToolIdsJson.value);
    }
    if (regexRulesJson.present) {
      map['regex_rules_json'] = Variable<String>(regexRulesJson.value);
    }
    if (enableMemory.present) {
      map['enable_memory'] = Variable<bool>(enableMemory.value);
    }
    if (memoryMode.present) {
      map['memory_mode'] = Variable<String>(memoryMode.value);
    }
    if (enableRecentChatsReference.present) {
      map['enable_recent_chats_reference'] = Variable<bool>(
        enableRecentChatsReference.value,
      );
    }
    if (recentChatsSummaryMessageCount.present) {
      map['recent_chats_summary_message_count'] = Variable<int>(
        recentChatsSummaryMessageCount.value,
      );
    }
    if (memoryRecordPrompt.present) {
      map['memory_record_prompt'] = Variable<String>(memoryRecordPrompt.value);
    }
    if (docxMode.present) {
      map['docx_mode'] = Variable<String>(docxMode.value);
    }
    if (pdfMode.present) {
      map['pdf_mode'] = Variable<String>(pdfMode.value);
    }
    if (otherOfficeMode.present) {
      map['other_office_mode'] = Variable<String>(otherOfficeMode.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('useAssistantAvatar: $useAssistantAvatar, ')
          ..write('useAssistantName: $useAssistantName, ')
          ..write('background: $background, ')
          ..write('chatModelProvider: $chatModelProvider, ')
          ..write('chatModelId: $chatModelId, ')
          ..write('temperature: $temperature, ')
          ..write('topP: $topP, ')
          ..write('contextMessageSize: $contextMessageSize, ')
          ..write('limitContextMessages: $limitContextMessages, ')
          ..write('streamOutput: $streamOutput, ')
          ..write('thinkingBudget: $thinkingBudget, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('customHeadersJson: $customHeadersJson, ')
          ..write('customBodyJson: $customBodyJson, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('messageTemplate: $messageTemplate, ')
          ..write('presetMessagesJson: $presetMessagesJson, ')
          ..write('searchEnabled: $searchEnabled, ')
          ..write('mcpServerIdsJson: $mcpServerIdsJson, ')
          ..write('localToolIdsJson: $localToolIdsJson, ')
          ..write('regexRulesJson: $regexRulesJson, ')
          ..write('enableMemory: $enableMemory, ')
          ..write('memoryMode: $memoryMode, ')
          ..write('enableRecentChatsReference: $enableRecentChatsReference, ')
          ..write(
            'recentChatsSummaryMessageCount: $recentChatsSummaryMessageCount, ',
          )
          ..write('memoryRecordPrompt: $memoryRecordPrompt, ')
          ..write('docxMode: $docxMode, ')
          ..write('pdfMode: $pdfMode, ')
          ..write('otherOfficeMode: $otherOfficeMode, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationMcpServerRowsTable extends ConversationMcpServerRows
    with TableInfo<$ConversationMcpServerRowsTable, ConversationMcpServerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMcpServerRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [conversationId, serverId, ordinal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_mcp_server_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationMcpServerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, serverId};
  @override
  ConversationMcpServerRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMcpServerRow(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
    );
  }

  @override
  $ConversationMcpServerRowsTable createAlias(String alias) {
    return $ConversationMcpServerRowsTable(attachedDatabase, alias);
  }
}

class ConversationMcpServerRow extends DataClass
    implements Insertable<ConversationMcpServerRow> {
  final String conversationId;
  final String serverId;
  final int ordinal;
  const ConversationMcpServerRow({
    required this.conversationId,
    required this.serverId,
    required this.ordinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['server_id'] = Variable<String>(serverId);
    map['ordinal'] = Variable<int>(ordinal);
    return map;
  }

  ConversationMcpServerRowsCompanion toCompanion(bool nullToAbsent) {
    return ConversationMcpServerRowsCompanion(
      conversationId: Value(conversationId),
      serverId: Value(serverId),
      ordinal: Value(ordinal),
    );
  }

  factory ConversationMcpServerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMcpServerRow(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      serverId: serializer.fromJson<String>(json['serverId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'serverId': serializer.toJson<String>(serverId),
      'ordinal': serializer.toJson<int>(ordinal),
    };
  }

  ConversationMcpServerRow copyWith({
    String? conversationId,
    String? serverId,
    int? ordinal,
  }) => ConversationMcpServerRow(
    conversationId: conversationId ?? this.conversationId,
    serverId: serverId ?? this.serverId,
    ordinal: ordinal ?? this.ordinal,
  );
  ConversationMcpServerRow copyWithCompanion(
    ConversationMcpServerRowsCompanion data,
  ) {
    return ConversationMcpServerRow(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMcpServerRow(')
          ..write('conversationId: $conversationId, ')
          ..write('serverId: $serverId, ')
          ..write('ordinal: $ordinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conversationId, serverId, ordinal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMcpServerRow &&
          other.conversationId == this.conversationId &&
          other.serverId == this.serverId &&
          other.ordinal == this.ordinal);
}

class ConversationMcpServerRowsCompanion
    extends UpdateCompanion<ConversationMcpServerRow> {
  final Value<String> conversationId;
  final Value<String> serverId;
  final Value<int> ordinal;
  final Value<int> rowid;
  const ConversationMcpServerRowsCompanion({
    this.conversationId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationMcpServerRowsCompanion.insert({
    required String conversationId,
    required String serverId,
    required int ordinal,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       serverId = Value(serverId),
       ordinal = Value(ordinal);
  static Insertable<ConversationMcpServerRow> custom({
    Expression<String>? conversationId,
    Expression<String>? serverId,
    Expression<int>? ordinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (serverId != null) 'server_id': serverId,
      if (ordinal != null) 'ordinal': ordinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationMcpServerRowsCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? serverId,
    Value<int>? ordinal,
    Value<int>? rowid,
  }) {
    return ConversationMcpServerRowsCompanion(
      conversationId: conversationId ?? this.conversationId,
      serverId: serverId ?? this.serverId,
      ordinal: ordinal ?? this.ordinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMcpServerRowsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('serverId: $serverId, ')
          ..write('ordinal: $ordinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ToolEventRowsTable extends ToolEventRows
    with TableInfo<$ToolEventRowsTable, ToolEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ToolEventRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES message_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventsJsonMeta = const VerificationMeta(
    'eventsJson',
  );
  @override
  late final GeneratedColumn<String> eventsJson = GeneratedColumn<String>(
    'events_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [messageId, eventsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tool_event_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ToolEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('events_json')) {
      context.handle(
        _eventsJsonMeta,
        eventsJson.isAcceptableOrUnknown(data['events_json']!, _eventsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_eventsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  ToolEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ToolEventRow(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      eventsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}events_json'],
      )!,
    );
  }

  @override
  $ToolEventRowsTable createAlias(String alias) {
    return $ToolEventRowsTable(attachedDatabase, alias);
  }
}

class ToolEventRow extends DataClass implements Insertable<ToolEventRow> {
  final String messageId;
  final String eventsJson;
  const ToolEventRow({required this.messageId, required this.eventsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['events_json'] = Variable<String>(eventsJson);
    return map;
  }

  ToolEventRowsCompanion toCompanion(bool nullToAbsent) {
    return ToolEventRowsCompanion(
      messageId: Value(messageId),
      eventsJson: Value(eventsJson),
    );
  }

  factory ToolEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ToolEventRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      eventsJson: serializer.fromJson<String>(json['eventsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'eventsJson': serializer.toJson<String>(eventsJson),
    };
  }

  ToolEventRow copyWith({String? messageId, String? eventsJson}) =>
      ToolEventRow(
        messageId: messageId ?? this.messageId,
        eventsJson: eventsJson ?? this.eventsJson,
      );
  ToolEventRow copyWithCompanion(ToolEventRowsCompanion data) {
    return ToolEventRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      eventsJson: data.eventsJson.present
          ? data.eventsJson.value
          : this.eventsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ToolEventRow(')
          ..write('messageId: $messageId, ')
          ..write('eventsJson: $eventsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, eventsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolEventRow &&
          other.messageId == this.messageId &&
          other.eventsJson == this.eventsJson);
}

class ToolEventRowsCompanion extends UpdateCompanion<ToolEventRow> {
  final Value<String> messageId;
  final Value<String> eventsJson;
  final Value<int> rowid;
  const ToolEventRowsCompanion({
    this.messageId = const Value.absent(),
    this.eventsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ToolEventRowsCompanion.insert({
    required String messageId,
    required String eventsJson,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       eventsJson = Value(eventsJson);
  static Insertable<ToolEventRow> custom({
    Expression<String>? messageId,
    Expression<String>? eventsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (eventsJson != null) 'events_json': eventsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ToolEventRowsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? eventsJson,
    Value<int>? rowid,
  }) {
    return ToolEventRowsCompanion(
      messageId: messageId ?? this.messageId,
      eventsJson: eventsJson ?? this.eventsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (eventsJson.present) {
      map['events_json'] = Variable<String>(eventsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ToolEventRowsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('eventsJson: $eventsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GeminiThoughtSignatureRowsTable extends GeminiThoughtSignatureRows
    with
        TableInfo<$GeminiThoughtSignatureRowsTable, GeminiThoughtSignatureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GeminiThoughtSignatureRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES message_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [messageId, signature];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gemini_thought_signature_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<GeminiThoughtSignatureRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  GeminiThoughtSignatureRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GeminiThoughtSignatureRow(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
    );
  }

  @override
  $GeminiThoughtSignatureRowsTable createAlias(String alias) {
    return $GeminiThoughtSignatureRowsTable(attachedDatabase, alias);
  }
}

class GeminiThoughtSignatureRow extends DataClass
    implements Insertable<GeminiThoughtSignatureRow> {
  final String messageId;
  final String signature;
  const GeminiThoughtSignatureRow({
    required this.messageId,
    required this.signature,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['signature'] = Variable<String>(signature);
    return map;
  }

  GeminiThoughtSignatureRowsCompanion toCompanion(bool nullToAbsent) {
    return GeminiThoughtSignatureRowsCompanion(
      messageId: Value(messageId),
      signature: Value(signature),
    );
  }

  factory GeminiThoughtSignatureRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GeminiThoughtSignatureRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      signature: serializer.fromJson<String>(json['signature']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'signature': serializer.toJson<String>(signature),
    };
  }

  GeminiThoughtSignatureRow copyWith({String? messageId, String? signature}) =>
      GeminiThoughtSignatureRow(
        messageId: messageId ?? this.messageId,
        signature: signature ?? this.signature,
      );
  GeminiThoughtSignatureRow copyWithCompanion(
    GeminiThoughtSignatureRowsCompanion data,
  ) {
    return GeminiThoughtSignatureRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      signature: data.signature.present ? data.signature.value : this.signature,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GeminiThoughtSignatureRow(')
          ..write('messageId: $messageId, ')
          ..write('signature: $signature')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, signature);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeminiThoughtSignatureRow &&
          other.messageId == this.messageId &&
          other.signature == this.signature);
}

class GeminiThoughtSignatureRowsCompanion
    extends UpdateCompanion<GeminiThoughtSignatureRow> {
  final Value<String> messageId;
  final Value<String> signature;
  final Value<int> rowid;
  const GeminiThoughtSignatureRowsCompanion({
    this.messageId = const Value.absent(),
    this.signature = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GeminiThoughtSignatureRowsCompanion.insert({
    required String messageId,
    required String signature,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       signature = Value(signature);
  static Insertable<GeminiThoughtSignatureRow> custom({
    Expression<String>? messageId,
    Expression<String>? signature,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (signature != null) 'signature': signature,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GeminiThoughtSignatureRowsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? signature,
    Value<int>? rowid,
  }) {
    return GeminiThoughtSignatureRowsCompanion(
      messageId: messageId ?? this.messageId,
      signature: signature ?? this.signature,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GeminiThoughtSignatureRowsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('signature: $signature, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheRowsTable extends CacheRows
    with TableInfo<$CacheRowsTable, CacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [type, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {type, key};
  @override
  CacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheRow(
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheRowsTable createAlias(String alias) {
    return $CacheRowsTable(attachedDatabase, alias);
  }
}

class CacheRow extends DataClass implements Insertable<CacheRow> {
  final String type;
  final String key;
  final String value;
  final DateTime updatedAt;
  const CacheRow({
    required this.type,
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type'] = Variable<String>(type);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheRowsCompanion toCompanion(bool nullToAbsent) {
    return CacheRowsCompanion(
      type: Value(type),
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheRow(
      type: serializer.fromJson<String>(json['type']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'type': serializer.toJson<String>(type),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheRow copyWith({
    String? type,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => CacheRow(
    type: type ?? this.type,
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheRow copyWithCompanion(CacheRowsCompanion data) {
    return CacheRow(
      type: data.type.present ? data.type.value : this.type,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheRow(')
          ..write('type: $type, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(type, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheRow &&
          other.type == this.type &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class CacheRowsCompanion extends UpdateCompanion<CacheRow> {
  final Value<String> type;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheRowsCompanion({
    this.type = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheRowsCompanion.insert({
    required String type,
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : type = Value(type),
       key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<CacheRow> custom({
    Expression<String>? type,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (type != null) 'type': type,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheRowsCompanion copyWith({
    Value<String>? type,
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheRowsCompanion(
      type: type ?? this.type,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheRowsCompanion(')
          ..write('type: $type, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatStorageMetaRowsTable extends ChatStorageMetaRows
    with TableInfo<$ChatStorageMetaRowsTable, ChatStorageMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatStorageMetaRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_storage_meta_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatStorageMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ChatStorageMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatStorageMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ChatStorageMetaRowsTable createAlias(String alias) {
    return $ChatStorageMetaRowsTable(attachedDatabase, alias);
  }
}

class ChatStorageMetaRow extends DataClass
    implements Insertable<ChatStorageMetaRow> {
  final String key;
  final String value;
  const ChatStorageMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ChatStorageMetaRowsCompanion toCompanion(bool nullToAbsent) {
    return ChatStorageMetaRowsCompanion(key: Value(key), value: Value(value));
  }

  factory ChatStorageMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatStorageMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ChatStorageMetaRow copyWith({String? key, String? value}) =>
      ChatStorageMetaRow(key: key ?? this.key, value: value ?? this.value);
  ChatStorageMetaRow copyWithCompanion(ChatStorageMetaRowsCompanion data) {
    return ChatStorageMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatStorageMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatStorageMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class ChatStorageMetaRowsCompanion extends UpdateCompanion<ChatStorageMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ChatStorageMetaRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatStorageMetaRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<ChatStorageMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatStorageMetaRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ChatStorageMetaRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatStorageMetaRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConversationRowsTable conversationRows = $ConversationRowsTable(
    this,
  );
  late final $MessageRowsTable messageRows = $MessageRowsTable(this);
  late final $AssistantRowsTable assistantRows = $AssistantRowsTable(this);
  late final $ConversationMcpServerRowsTable conversationMcpServerRows =
      $ConversationMcpServerRowsTable(this);
  late final $ToolEventRowsTable toolEventRows = $ToolEventRowsTable(this);
  late final $GeminiThoughtSignatureRowsTable geminiThoughtSignatureRows =
      $GeminiThoughtSignatureRowsTable(this);
  late final $CacheRowsTable cacheRows = $CacheRowsTable(this);
  late final $ChatStorageMetaRowsTable chatStorageMetaRows =
      $ChatStorageMetaRowsTable(this);
  late final Index idxConversationsUpdatedAt = Index(
    'idx_conversations_updated_at',
    'CREATE INDEX idx_conversations_updated_at ON conversation_rows (updated_at)',
  );
  late final Index idxConversationsAssistant = Index(
    'idx_conversations_assistant',
    'CREATE INDEX idx_conversations_assistant ON conversation_rows (assistant_id)',
  );
  late final Index idxMessagesConversationOrder = Index(
    'idx_messages_conversation_order',
    'CREATE INDEX idx_messages_conversation_order ON message_rows (conversation_id, message_order)',
  );
  late final Index idxMessagesConversationTimestamp = Index(
    'idx_messages_conversation_timestamp',
    'CREATE INDEX idx_messages_conversation_timestamp ON message_rows (conversation_id, timestamp)',
  );
  late final Index idxMessagesGroup = Index(
    'idx_messages_group',
    'CREATE INDEX idx_messages_group ON message_rows (group_id)',
  );
  late final Index idxMessagesSubgroup = Index(
    'idx_messages_subgroup',
    'CREATE INDEX idx_messages_subgroup ON message_rows (subgroup_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversationRows,
    messageRows,
    assistantRows,
    conversationMcpServerRows,
    toolEventRows,
    geminiThoughtSignatureRows,
    cacheRows,
    chatStorageMetaRows,
    idxConversationsUpdatedAt,
    idxConversationsAssistant,
    idxMessagesConversationOrder,
    idxMessagesConversationTimestamp,
    idxMessagesGroup,
    idxMessagesSubgroup,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('conversation_mcp_server_rows', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'message_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tool_event_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'message_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('gemini_thought_signature_rows', kind: UpdateKind.delete),
      ],
    ),
  ]);
}

typedef $$ConversationRowsTableCreateCompanionBuilder =
    ConversationRowsCompanion Function({
      required String id,
      required String title,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isPinned,
      Value<String?> assistantId,
      Value<int> truncateIndex,
      Value<String> versionSelectionsJson,
      Value<String?> summary,
      Value<int> lastSummarizedMessageCount,
      Value<String> chatSuggestionsJson,
      Value<int> rowid,
    });
typedef $$ConversationRowsTableUpdateCompanionBuilder =
    ConversationRowsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isPinned,
      Value<String?> assistantId,
      Value<int> truncateIndex,
      Value<String> versionSelectionsJson,
      Value<String?> summary,
      Value<int> lastSummarizedMessageCount,
      Value<String> chatSuggestionsJson,
      Value<int> rowid,
    });

final class $$ConversationRowsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ConversationRowsTable, ConversationRow> {
  $$ConversationRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MessageRowsTable, List<MessageRow>>
  _messageRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messageRows,
    aliasName: 'conversation_rows__id__message_rows__conversation_id',
  );

  $$MessageRowsTableProcessedTableManager get messageRowsRefs {
    final manager = $$MessageRowsTableTableManager(
      $_db,
      $_db.messageRows,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messageRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ConversationMcpServerRowsTable,
    List<ConversationMcpServerRow>
  >
  _conversationMcpServerRowsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.conversationMcpServerRows,
    aliasName:
        'conversation_rows__id__conversation_mcp_server_rows__conversation_id',
  );

  $$ConversationMcpServerRowsTableProcessedTableManager
  get conversationMcpServerRowsRefs {
    final manager = $$ConversationMcpServerRowsTableTableManager(
      $_db,
      $_db.conversationMcpServerRows,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _conversationMcpServerRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationRowsTable> {
  $$ConversationRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get truncateIndex => $composableBuilder(
    column: $table.truncateIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionSelectionsJson => $composableBuilder(
    column: $table.versionSelectionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSummarizedMessageCount => $composableBuilder(
    column: $table.lastSummarizedMessageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatSuggestionsJson => $composableBuilder(
    column: $table.chatSuggestionsJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> messageRowsRefs(
    Expression<bool> Function($$MessageRowsTableFilterComposer f) f,
  ) {
    final $$MessageRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableFilterComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> conversationMcpServerRowsRefs(
    Expression<bool> Function($$ConversationMcpServerRowsTableFilterComposer f)
    f,
  ) {
    final $$ConversationMcpServerRowsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationMcpServerRows,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationMcpServerRowsTableFilterComposer(
                $db: $db,
                $table: $db.conversationMcpServerRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ConversationRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationRowsTable> {
  $$ConversationRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get truncateIndex => $composableBuilder(
    column: $table.truncateIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionSelectionsJson => $composableBuilder(
    column: $table.versionSelectionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSummarizedMessageCount => $composableBuilder(
    column: $table.lastSummarizedMessageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatSuggestionsJson => $composableBuilder(
    column: $table.chatSuggestionsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationRowsTable> {
  $$ConversationRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get truncateIndex => $composableBuilder(
    column: $table.truncateIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get versionSelectionsJson => $composableBuilder(
    column: $table.versionSelectionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get lastSummarizedMessageCount => $composableBuilder(
    column: $table.lastSummarizedMessageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chatSuggestionsJson => $composableBuilder(
    column: $table.chatSuggestionsJson,
    builder: (column) => column,
  );

  Expression<T> messageRowsRefs<T extends Object>(
    Expression<T> Function($$MessageRowsTableAnnotationComposer a) f,
  ) {
    final $$MessageRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> conversationMcpServerRowsRefs<T extends Object>(
    Expression<T> Function($$ConversationMcpServerRowsTableAnnotationComposer a)
    f,
  ) {
    final $$ConversationMcpServerRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationMcpServerRows,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationMcpServerRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationMcpServerRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ConversationRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationRowsTable,
          ConversationRow,
          $$ConversationRowsTableFilterComposer,
          $$ConversationRowsTableOrderingComposer,
          $$ConversationRowsTableAnnotationComposer,
          $$ConversationRowsTableCreateCompanionBuilder,
          $$ConversationRowsTableUpdateCompanionBuilder,
          (ConversationRow, $$ConversationRowsTableReferences),
          ConversationRow,
          PrefetchHooks Function({
            bool messageRowsRefs,
            bool conversationMcpServerRowsRefs,
          })
        > {
  $$ConversationRowsTableTableManager(
    _$AppDatabase db,
    $ConversationRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String?> assistantId = const Value.absent(),
                Value<int> truncateIndex = const Value.absent(),
                Value<String> versionSelectionsJson = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int> lastSummarizedMessageCount = const Value.absent(),
                Value<String> chatSuggestionsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationRowsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                assistantId: assistantId,
                truncateIndex: truncateIndex,
                versionSelectionsJson: versionSelectionsJson,
                summary: summary,
                lastSummarizedMessageCount: lastSummarizedMessageCount,
                chatSuggestionsJson: chatSuggestionsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> isPinned = const Value.absent(),
                Value<String?> assistantId = const Value.absent(),
                Value<int> truncateIndex = const Value.absent(),
                Value<String> versionSelectionsJson = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int> lastSummarizedMessageCount = const Value.absent(),
                Value<String> chatSuggestionsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationRowsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                assistantId: assistantId,
                truncateIndex: truncateIndex,
                versionSelectionsJson: versionSelectionsJson,
                summary: summary,
                lastSummarizedMessageCount: lastSummarizedMessageCount,
                chatSuggestionsJson: chatSuggestionsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                messageRowsRefs = false,
                conversationMcpServerRowsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messageRowsRefs) db.messageRows,
                    if (conversationMcpServerRowsRefs)
                      db.conversationMcpServerRows,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messageRowsRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationRowsTable,
                          MessageRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationRowsTableReferences
                              ._messageRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).messageRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (conversationMcpServerRowsRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationRowsTable,
                          ConversationMcpServerRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationRowsTableReferences
                              ._conversationMcpServerRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationMcpServerRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConversationRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationRowsTable,
      ConversationRow,
      $$ConversationRowsTableFilterComposer,
      $$ConversationRowsTableOrderingComposer,
      $$ConversationRowsTableAnnotationComposer,
      $$ConversationRowsTableCreateCompanionBuilder,
      $$ConversationRowsTableUpdateCompanionBuilder,
      (ConversationRow, $$ConversationRowsTableReferences),
      ConversationRow,
      PrefetchHooks Function({
        bool messageRowsRefs,
        bool conversationMcpServerRowsRefs,
      })
    >;
typedef $$MessageRowsTableCreateCompanionBuilder =
    MessageRowsCompanion Function({
      required String id,
      required String conversationId,
      required String role,
      required String content,
      required DateTime timestamp,
      Value<String?> modelId,
      Value<String?> providerId,
      Value<int?> totalTokens,
      Value<bool> isStreaming,
      Value<String?> reasoningText,
      Value<DateTime?> reasoningStartAt,
      Value<DateTime?> reasoningFinishedAt,
      Value<String?> translation,
      Value<String?> reasoningSegmentsJson,
      Value<String?> groupId,
      Value<String?> subgroupId,
      Value<int> version,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      Value<int?> cachedTokens,
      Value<int?> durationMs,
      required int messageOrder,
      Value<int> rowid,
    });
typedef $$MessageRowsTableUpdateCompanionBuilder =
    MessageRowsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> role,
      Value<String> content,
      Value<DateTime> timestamp,
      Value<String?> modelId,
      Value<String?> providerId,
      Value<int?> totalTokens,
      Value<bool> isStreaming,
      Value<String?> reasoningText,
      Value<DateTime?> reasoningStartAt,
      Value<DateTime?> reasoningFinishedAt,
      Value<String?> translation,
      Value<String?> reasoningSegmentsJson,
      Value<String?> groupId,
      Value<String?> subgroupId,
      Value<int> version,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      Value<int?> cachedTokens,
      Value<int?> durationMs,
      Value<int> messageOrder,
      Value<int> rowid,
    });

final class $$MessageRowsTableReferences
    extends BaseReferences<_$AppDatabase, $MessageRowsTable, MessageRow> {
  $$MessageRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationRowsTable _conversationIdTable(_$AppDatabase db) => db
      .conversationRows
      .createAlias('message_rows__conversation_id__conversation_rows__id');

  $$ConversationRowsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationRowsTableTableManager(
      $_db,
      $_db.conversationRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ToolEventRowsTable, List<ToolEventRow>>
  _toolEventRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.toolEventRows,
    aliasName: 'message_rows__id__tool_event_rows__message_id',
  );

  $$ToolEventRowsTableProcessedTableManager get toolEventRowsRefs {
    final manager = $$ToolEventRowsTableTableManager(
      $_db,
      $_db.toolEventRows,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_toolEventRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $GeminiThoughtSignatureRowsTable,
    List<GeminiThoughtSignatureRow>
  >
  _geminiThoughtSignatureRowsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.geminiThoughtSignatureRows,
        aliasName:
            'message_rows__id__gemini_thought_signature_rows__message_id',
      );

  $$GeminiThoughtSignatureRowsTableProcessedTableManager
  get geminiThoughtSignatureRowsRefs {
    final manager = $$GeminiThoughtSignatureRowsTableTableManager(
      $_db,
      $_db.geminiThoughtSignatureRows,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _geminiThoughtSignatureRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MessageRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageRowsTable> {
  $$MessageRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTokens => $composableBuilder(
    column: $table.totalTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isStreaming => $composableBuilder(
    column: $table.isStreaming,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoningText => $composableBuilder(
    column: $table.reasoningText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reasoningStartAt => $composableBuilder(
    column: $table.reasoningStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reasoningFinishedAt => $composableBuilder(
    column: $table.reasoningFinishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoningSegmentsJson => $composableBuilder(
    column: $table.reasoningSegmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subgroupId => $composableBuilder(
    column: $table.subgroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedTokens => $composableBuilder(
    column: $table.cachedTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageOrder => $composableBuilder(
    column: $table.messageOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationRowsTableFilterComposer get conversationId {
    final $$ConversationRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationRowsTableFilterComposer(
            $db: $db,
            $table: $db.conversationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> toolEventRowsRefs(
    Expression<bool> Function($$ToolEventRowsTableFilterComposer f) f,
  ) {
    final $$ToolEventRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.toolEventRows,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ToolEventRowsTableFilterComposer(
            $db: $db,
            $table: $db.toolEventRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> geminiThoughtSignatureRowsRefs(
    Expression<bool> Function($$GeminiThoughtSignatureRowsTableFilterComposer f)
    f,
  ) {
    final $$GeminiThoughtSignatureRowsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.geminiThoughtSignatureRows,
          getReferencedColumn: (t) => t.messageId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GeminiThoughtSignatureRowsTableFilterComposer(
                $db: $db,
                $table: $db.geminiThoughtSignatureRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MessageRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageRowsTable> {
  $$MessageRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTokens => $composableBuilder(
    column: $table.totalTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isStreaming => $composableBuilder(
    column: $table.isStreaming,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoningText => $composableBuilder(
    column: $table.reasoningText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reasoningStartAt => $composableBuilder(
    column: $table.reasoningStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reasoningFinishedAt => $composableBuilder(
    column: $table.reasoningFinishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoningSegmentsJson => $composableBuilder(
    column: $table.reasoningSegmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subgroupId => $composableBuilder(
    column: $table.subgroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedTokens => $composableBuilder(
    column: $table.cachedTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageOrder => $composableBuilder(
    column: $table.messageOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationRowsTableOrderingComposer get conversationId {
    final $$ConversationRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationRowsTableOrderingComposer(
            $db: $db,
            $table: $db.conversationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageRowsTable> {
  $$MessageRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalTokens => $composableBuilder(
    column: $table.totalTokens,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isStreaming => $composableBuilder(
    column: $table.isStreaming,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reasoningText => $composableBuilder(
    column: $table.reasoningText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reasoningStartAt => $composableBuilder(
    column: $table.reasoningStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reasoningFinishedAt => $composableBuilder(
    column: $table.reasoningFinishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reasoningSegmentsJson => $composableBuilder(
    column: $table.reasoningSegmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get subgroupId => $composableBuilder(
    column: $table.subgroupId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedTokens => $composableBuilder(
    column: $table.cachedTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get messageOrder => $composableBuilder(
    column: $table.messageOrder,
    builder: (column) => column,
  );

  $$ConversationRowsTableAnnotationComposer get conversationId {
    final $$ConversationRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> toolEventRowsRefs<T extends Object>(
    Expression<T> Function($$ToolEventRowsTableAnnotationComposer a) f,
  ) {
    final $$ToolEventRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.toolEventRows,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ToolEventRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.toolEventRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> geminiThoughtSignatureRowsRefs<T extends Object>(
    Expression<T> Function(
      $$GeminiThoughtSignatureRowsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$GeminiThoughtSignatureRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.geminiThoughtSignatureRows,
          getReferencedColumn: (t) => t.messageId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GeminiThoughtSignatureRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.geminiThoughtSignatureRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MessageRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageRowsTable,
          MessageRow,
          $$MessageRowsTableFilterComposer,
          $$MessageRowsTableOrderingComposer,
          $$MessageRowsTableAnnotationComposer,
          $$MessageRowsTableCreateCompanionBuilder,
          $$MessageRowsTableUpdateCompanionBuilder,
          (MessageRow, $$MessageRowsTableReferences),
          MessageRow,
          PrefetchHooks Function({
            bool conversationId,
            bool toolEventRowsRefs,
            bool geminiThoughtSignatureRowsRefs,
          })
        > {
  $$MessageRowsTableTableManager(_$AppDatabase db, $MessageRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<int?> totalTokens = const Value.absent(),
                Value<bool> isStreaming = const Value.absent(),
                Value<String?> reasoningText = const Value.absent(),
                Value<DateTime?> reasoningStartAt = const Value.absent(),
                Value<DateTime?> reasoningFinishedAt = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<String?> reasoningSegmentsJson = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> subgroupId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                Value<int?> cachedTokens = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> messageOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageRowsCompanion(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                timestamp: timestamp,
                modelId: modelId,
                providerId: providerId,
                totalTokens: totalTokens,
                isStreaming: isStreaming,
                reasoningText: reasoningText,
                reasoningStartAt: reasoningStartAt,
                reasoningFinishedAt: reasoningFinishedAt,
                translation: translation,
                reasoningSegmentsJson: reasoningSegmentsJson,
                groupId: groupId,
                subgroupId: subgroupId,
                version: version,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                cachedTokens: cachedTokens,
                durationMs: durationMs,
                messageOrder: messageOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String role,
                required String content,
                required DateTime timestamp,
                Value<String?> modelId = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<int?> totalTokens = const Value.absent(),
                Value<bool> isStreaming = const Value.absent(),
                Value<String?> reasoningText = const Value.absent(),
                Value<DateTime?> reasoningStartAt = const Value.absent(),
                Value<DateTime?> reasoningFinishedAt = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<String?> reasoningSegmentsJson = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> subgroupId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                Value<int?> cachedTokens = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int messageOrder,
                Value<int> rowid = const Value.absent(),
              }) => MessageRowsCompanion.insert(
                id: id,
                conversationId: conversationId,
                role: role,
                content: content,
                timestamp: timestamp,
                modelId: modelId,
                providerId: providerId,
                totalTokens: totalTokens,
                isStreaming: isStreaming,
                reasoningText: reasoningText,
                reasoningStartAt: reasoningStartAt,
                reasoningFinishedAt: reasoningFinishedAt,
                translation: translation,
                reasoningSegmentsJson: reasoningSegmentsJson,
                groupId: groupId,
                subgroupId: subgroupId,
                version: version,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                cachedTokens: cachedTokens,
                durationMs: durationMs,
                messageOrder: messageOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessageRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                conversationId = false,
                toolEventRowsRefs = false,
                geminiThoughtSignatureRowsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (toolEventRowsRefs) db.toolEventRows,
                    if (geminiThoughtSignatureRowsRefs)
                      db.geminiThoughtSignatureRows,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (conversationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.conversationId,
                                    referencedTable:
                                        $$MessageRowsTableReferences
                                            ._conversationIdTable(db),
                                    referencedColumn:
                                        $$MessageRowsTableReferences
                                            ._conversationIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (toolEventRowsRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessageRowsTable,
                          ToolEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$MessageRowsTableReferences
                              ._toolEventRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessageRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).toolEventRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (geminiThoughtSignatureRowsRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessageRowsTable,
                          GeminiThoughtSignatureRow
                        >(
                          currentTable: table,
                          referencedTable: $$MessageRowsTableReferences
                              ._geminiThoughtSignatureRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessageRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).geminiThoughtSignatureRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MessageRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageRowsTable,
      MessageRow,
      $$MessageRowsTableFilterComposer,
      $$MessageRowsTableOrderingComposer,
      $$MessageRowsTableAnnotationComposer,
      $$MessageRowsTableCreateCompanionBuilder,
      $$MessageRowsTableUpdateCompanionBuilder,
      (MessageRow, $$MessageRowsTableReferences),
      MessageRow,
      PrefetchHooks Function({
        bool conversationId,
        bool toolEventRowsRefs,
        bool geminiThoughtSignatureRowsRefs,
      })
    >;
typedef $$AssistantRowsTableCreateCompanionBuilder =
    AssistantRowsCompanion Function({
      required String id,
      required String name,
      Value<String?> avatar,
      Value<bool> useAssistantAvatar,
      Value<bool> useAssistantName,
      Value<String?> background,
      Value<String?> chatModelProvider,
      Value<String?> chatModelId,
      Value<double?> temperature,
      Value<double?> topP,
      Value<int> contextMessageSize,
      Value<bool> limitContextMessages,
      Value<bool> streamOutput,
      Value<int?> thinkingBudget,
      Value<int?> maxTokens,
      Value<String> customHeadersJson,
      Value<String> customBodyJson,
      Value<String> systemPrompt,
      Value<String> messageTemplate,
      Value<String> presetMessagesJson,
      Value<bool> searchEnabled,
      Value<String> mcpServerIdsJson,
      Value<String> localToolIdsJson,
      Value<String> regexRulesJson,
      Value<bool> enableMemory,
      Value<String> memoryMode,
      Value<bool> enableRecentChatsReference,
      Value<int> recentChatsSummaryMessageCount,
      Value<String> memoryRecordPrompt,
      Value<String> docxMode,
      Value<String> pdfMode,
      Value<String> otherOfficeMode,
      required int sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AssistantRowsTableUpdateCompanionBuilder =
    AssistantRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> avatar,
      Value<bool> useAssistantAvatar,
      Value<bool> useAssistantName,
      Value<String?> background,
      Value<String?> chatModelProvider,
      Value<String?> chatModelId,
      Value<double?> temperature,
      Value<double?> topP,
      Value<int> contextMessageSize,
      Value<bool> limitContextMessages,
      Value<bool> streamOutput,
      Value<int?> thinkingBudget,
      Value<int?> maxTokens,
      Value<String> customHeadersJson,
      Value<String> customBodyJson,
      Value<String> systemPrompt,
      Value<String> messageTemplate,
      Value<String> presetMessagesJson,
      Value<bool> searchEnabled,
      Value<String> mcpServerIdsJson,
      Value<String> localToolIdsJson,
      Value<String> regexRulesJson,
      Value<bool> enableMemory,
      Value<String> memoryMode,
      Value<bool> enableRecentChatsReference,
      Value<int> recentChatsSummaryMessageCount,
      Value<String> memoryRecordPrompt,
      Value<String> docxMode,
      Value<String> pdfMode,
      Value<String> otherOfficeMode,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AssistantRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantRowsTable> {
  $$AssistantRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useAssistantAvatar => $composableBuilder(
    column: $table.useAssistantAvatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useAssistantName => $composableBuilder(
    column: $table.useAssistantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatModelProvider => $composableBuilder(
    column: $table.chatModelProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatModelId => $composableBuilder(
    column: $table.chatModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get topP => $composableBuilder(
    column: $table.topP,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contextMessageSize => $composableBuilder(
    column: $table.contextMessageSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get limitContextMessages => $composableBuilder(
    column: $table.limitContextMessages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get streamOutput => $composableBuilder(
    column: $table.streamOutput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thinkingBudget => $composableBuilder(
    column: $table.thinkingBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customHeadersJson => $composableBuilder(
    column: $table.customHeadersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customBodyJson => $composableBuilder(
    column: $table.customBodyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageTemplate => $composableBuilder(
    column: $table.messageTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetMessagesJson => $composableBuilder(
    column: $table.presetMessagesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get searchEnabled => $composableBuilder(
    column: $table.searchEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mcpServerIdsJson => $composableBuilder(
    column: $table.mcpServerIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localToolIdsJson => $composableBuilder(
    column: $table.localToolIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regexRulesJson => $composableBuilder(
    column: $table.regexRulesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enableMemory => $composableBuilder(
    column: $table.enableMemory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoryMode => $composableBuilder(
    column: $table.memoryMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enableRecentChatsReference => $composableBuilder(
    column: $table.enableRecentChatsReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recentChatsSummaryMessageCount => $composableBuilder(
    column: $table.recentChatsSummaryMessageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoryRecordPrompt => $composableBuilder(
    column: $table.memoryRecordPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docxMode => $composableBuilder(
    column: $table.docxMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfMode => $composableBuilder(
    column: $table.pdfMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherOfficeMode => $composableBuilder(
    column: $table.otherOfficeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssistantRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantRowsTable> {
  $$AssistantRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useAssistantAvatar => $composableBuilder(
    column: $table.useAssistantAvatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useAssistantName => $composableBuilder(
    column: $table.useAssistantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatModelProvider => $composableBuilder(
    column: $table.chatModelProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatModelId => $composableBuilder(
    column: $table.chatModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get topP => $composableBuilder(
    column: $table.topP,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contextMessageSize => $composableBuilder(
    column: $table.contextMessageSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get limitContextMessages => $composableBuilder(
    column: $table.limitContextMessages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get streamOutput => $composableBuilder(
    column: $table.streamOutput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thinkingBudget => $composableBuilder(
    column: $table.thinkingBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customHeadersJson => $composableBuilder(
    column: $table.customHeadersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customBodyJson => $composableBuilder(
    column: $table.customBodyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageTemplate => $composableBuilder(
    column: $table.messageTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetMessagesJson => $composableBuilder(
    column: $table.presetMessagesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get searchEnabled => $composableBuilder(
    column: $table.searchEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mcpServerIdsJson => $composableBuilder(
    column: $table.mcpServerIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localToolIdsJson => $composableBuilder(
    column: $table.localToolIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regexRulesJson => $composableBuilder(
    column: $table.regexRulesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enableMemory => $composableBuilder(
    column: $table.enableMemory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoryMode => $composableBuilder(
    column: $table.memoryMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enableRecentChatsReference => $composableBuilder(
    column: $table.enableRecentChatsReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recentChatsSummaryMessageCount => $composableBuilder(
    column: $table.recentChatsSummaryMessageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoryRecordPrompt => $composableBuilder(
    column: $table.memoryRecordPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docxMode => $composableBuilder(
    column: $table.docxMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfMode => $composableBuilder(
    column: $table.pdfMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherOfficeMode => $composableBuilder(
    column: $table.otherOfficeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssistantRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantRowsTable> {
  $$AssistantRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<bool> get useAssistantAvatar => $composableBuilder(
    column: $table.useAssistantAvatar,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useAssistantName => $composableBuilder(
    column: $table.useAssistantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chatModelProvider => $composableBuilder(
    column: $table.chatModelProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chatModelId => $composableBuilder(
    column: $table.chatModelId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<double> get topP =>
      $composableBuilder(column: $table.topP, builder: (column) => column);

  GeneratedColumn<int> get contextMessageSize => $composableBuilder(
    column: $table.contextMessageSize,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get limitContextMessages => $composableBuilder(
    column: $table.limitContextMessages,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get streamOutput => $composableBuilder(
    column: $table.streamOutput,
    builder: (column) => column,
  );

  GeneratedColumn<int> get thinkingBudget => $composableBuilder(
    column: $table.thinkingBudget,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxTokens =>
      $composableBuilder(column: $table.maxTokens, builder: (column) => column);

  GeneratedColumn<String> get customHeadersJson => $composableBuilder(
    column: $table.customHeadersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customBodyJson => $composableBuilder(
    column: $table.customBodyJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageTemplate => $composableBuilder(
    column: $table.messageTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get presetMessagesJson => $composableBuilder(
    column: $table.presetMessagesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get searchEnabled => $composableBuilder(
    column: $table.searchEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mcpServerIdsJson => $composableBuilder(
    column: $table.mcpServerIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localToolIdsJson => $composableBuilder(
    column: $table.localToolIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get regexRulesJson => $composableBuilder(
    column: $table.regexRulesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enableMemory => $composableBuilder(
    column: $table.enableMemory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memoryMode => $composableBuilder(
    column: $table.memoryMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enableRecentChatsReference => $composableBuilder(
    column: $table.enableRecentChatsReference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recentChatsSummaryMessageCount => $composableBuilder(
    column: $table.recentChatsSummaryMessageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memoryRecordPrompt => $composableBuilder(
    column: $table.memoryRecordPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get docxMode =>
      $composableBuilder(column: $table.docxMode, builder: (column) => column);

  GeneratedColumn<String> get pdfMode =>
      $composableBuilder(column: $table.pdfMode, builder: (column) => column);

  GeneratedColumn<String> get otherOfficeMode => $composableBuilder(
    column: $table.otherOfficeMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AssistantRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantRowsTable,
          AssistantRow,
          $$AssistantRowsTableFilterComposer,
          $$AssistantRowsTableOrderingComposer,
          $$AssistantRowsTableAnnotationComposer,
          $$AssistantRowsTableCreateCompanionBuilder,
          $$AssistantRowsTableUpdateCompanionBuilder,
          (
            AssistantRow,
            BaseReferences<_$AppDatabase, $AssistantRowsTable, AssistantRow>,
          ),
          AssistantRow,
          PrefetchHooks Function()
        > {
  $$AssistantRowsTableTableManager(_$AppDatabase db, $AssistantRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssistantRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> avatar = const Value.absent(),
                Value<bool> useAssistantAvatar = const Value.absent(),
                Value<bool> useAssistantName = const Value.absent(),
                Value<String?> background = const Value.absent(),
                Value<String?> chatModelProvider = const Value.absent(),
                Value<String?> chatModelId = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<double?> topP = const Value.absent(),
                Value<int> contextMessageSize = const Value.absent(),
                Value<bool> limitContextMessages = const Value.absent(),
                Value<bool> streamOutput = const Value.absent(),
                Value<int?> thinkingBudget = const Value.absent(),
                Value<int?> maxTokens = const Value.absent(),
                Value<String> customHeadersJson = const Value.absent(),
                Value<String> customBodyJson = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<String> messageTemplate = const Value.absent(),
                Value<String> presetMessagesJson = const Value.absent(),
                Value<bool> searchEnabled = const Value.absent(),
                Value<String> mcpServerIdsJson = const Value.absent(),
                Value<String> localToolIdsJson = const Value.absent(),
                Value<String> regexRulesJson = const Value.absent(),
                Value<bool> enableMemory = const Value.absent(),
                Value<String> memoryMode = const Value.absent(),
                Value<bool> enableRecentChatsReference = const Value.absent(),
                Value<int> recentChatsSummaryMessageCount =
                    const Value.absent(),
                Value<String> memoryRecordPrompt = const Value.absent(),
                Value<String> docxMode = const Value.absent(),
                Value<String> pdfMode = const Value.absent(),
                Value<String> otherOfficeMode = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantRowsCompanion(
                id: id,
                name: name,
                avatar: avatar,
                useAssistantAvatar: useAssistantAvatar,
                useAssistantName: useAssistantName,
                background: background,
                chatModelProvider: chatModelProvider,
                chatModelId: chatModelId,
                temperature: temperature,
                topP: topP,
                contextMessageSize: contextMessageSize,
                limitContextMessages: limitContextMessages,
                streamOutput: streamOutput,
                thinkingBudget: thinkingBudget,
                maxTokens: maxTokens,
                customHeadersJson: customHeadersJson,
                customBodyJson: customBodyJson,
                systemPrompt: systemPrompt,
                messageTemplate: messageTemplate,
                presetMessagesJson: presetMessagesJson,
                searchEnabled: searchEnabled,
                mcpServerIdsJson: mcpServerIdsJson,
                localToolIdsJson: localToolIdsJson,
                regexRulesJson: regexRulesJson,
                enableMemory: enableMemory,
                memoryMode: memoryMode,
                enableRecentChatsReference: enableRecentChatsReference,
                recentChatsSummaryMessageCount: recentChatsSummaryMessageCount,
                memoryRecordPrompt: memoryRecordPrompt,
                docxMode: docxMode,
                pdfMode: pdfMode,
                otherOfficeMode: otherOfficeMode,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> avatar = const Value.absent(),
                Value<bool> useAssistantAvatar = const Value.absent(),
                Value<bool> useAssistantName = const Value.absent(),
                Value<String?> background = const Value.absent(),
                Value<String?> chatModelProvider = const Value.absent(),
                Value<String?> chatModelId = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<double?> topP = const Value.absent(),
                Value<int> contextMessageSize = const Value.absent(),
                Value<bool> limitContextMessages = const Value.absent(),
                Value<bool> streamOutput = const Value.absent(),
                Value<int?> thinkingBudget = const Value.absent(),
                Value<int?> maxTokens = const Value.absent(),
                Value<String> customHeadersJson = const Value.absent(),
                Value<String> customBodyJson = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<String> messageTemplate = const Value.absent(),
                Value<String> presetMessagesJson = const Value.absent(),
                Value<bool> searchEnabled = const Value.absent(),
                Value<String> mcpServerIdsJson = const Value.absent(),
                Value<String> localToolIdsJson = const Value.absent(),
                Value<String> regexRulesJson = const Value.absent(),
                Value<bool> enableMemory = const Value.absent(),
                Value<String> memoryMode = const Value.absent(),
                Value<bool> enableRecentChatsReference = const Value.absent(),
                Value<int> recentChatsSummaryMessageCount =
                    const Value.absent(),
                Value<String> memoryRecordPrompt = const Value.absent(),
                Value<String> docxMode = const Value.absent(),
                Value<String> pdfMode = const Value.absent(),
                Value<String> otherOfficeMode = const Value.absent(),
                required int sortOrder,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantRowsCompanion.insert(
                id: id,
                name: name,
                avatar: avatar,
                useAssistantAvatar: useAssistantAvatar,
                useAssistantName: useAssistantName,
                background: background,
                chatModelProvider: chatModelProvider,
                chatModelId: chatModelId,
                temperature: temperature,
                topP: topP,
                contextMessageSize: contextMessageSize,
                limitContextMessages: limitContextMessages,
                streamOutput: streamOutput,
                thinkingBudget: thinkingBudget,
                maxTokens: maxTokens,
                customHeadersJson: customHeadersJson,
                customBodyJson: customBodyJson,
                systemPrompt: systemPrompt,
                messageTemplate: messageTemplate,
                presetMessagesJson: presetMessagesJson,
                searchEnabled: searchEnabled,
                mcpServerIdsJson: mcpServerIdsJson,
                localToolIdsJson: localToolIdsJson,
                regexRulesJson: regexRulesJson,
                enableMemory: enableMemory,
                memoryMode: memoryMode,
                enableRecentChatsReference: enableRecentChatsReference,
                recentChatsSummaryMessageCount: recentChatsSummaryMessageCount,
                memoryRecordPrompt: memoryRecordPrompt,
                docxMode: docxMode,
                pdfMode: pdfMode,
                otherOfficeMode: otherOfficeMode,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssistantRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantRowsTable,
      AssistantRow,
      $$AssistantRowsTableFilterComposer,
      $$AssistantRowsTableOrderingComposer,
      $$AssistantRowsTableAnnotationComposer,
      $$AssistantRowsTableCreateCompanionBuilder,
      $$AssistantRowsTableUpdateCompanionBuilder,
      (
        AssistantRow,
        BaseReferences<_$AppDatabase, $AssistantRowsTable, AssistantRow>,
      ),
      AssistantRow,
      PrefetchHooks Function()
    >;
typedef $$ConversationMcpServerRowsTableCreateCompanionBuilder =
    ConversationMcpServerRowsCompanion Function({
      required String conversationId,
      required String serverId,
      required int ordinal,
      Value<int> rowid,
    });
typedef $$ConversationMcpServerRowsTableUpdateCompanionBuilder =
    ConversationMcpServerRowsCompanion Function({
      Value<String> conversationId,
      Value<String> serverId,
      Value<int> ordinal,
      Value<int> rowid,
    });

final class $$ConversationMcpServerRowsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ConversationMcpServerRowsTable,
          ConversationMcpServerRow
        > {
  $$ConversationMcpServerRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationRowsTable _conversationIdTable(_$AppDatabase db) =>
      db.conversationRows.createAlias(
        'conversation_mcp_server_rows__conversation_id__conversation_rows__id',
      );

  $$ConversationRowsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationRowsTableTableManager(
      $_db,
      $_db.conversationRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ConversationMcpServerRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationMcpServerRowsTable> {
  $$ConversationMcpServerRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationRowsTableFilterComposer get conversationId {
    final $$ConversationRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationRowsTableFilterComposer(
            $db: $db,
            $table: $db.conversationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationMcpServerRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationMcpServerRowsTable> {
  $$ConversationMcpServerRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationRowsTableOrderingComposer get conversationId {
    final $$ConversationRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationRowsTableOrderingComposer(
            $db: $db,
            $table: $db.conversationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationMcpServerRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationMcpServerRowsTable> {
  $$ConversationMcpServerRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  $$ConversationRowsTableAnnotationComposer get conversationId {
    final $$ConversationRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationMcpServerRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationMcpServerRowsTable,
          ConversationMcpServerRow,
          $$ConversationMcpServerRowsTableFilterComposer,
          $$ConversationMcpServerRowsTableOrderingComposer,
          $$ConversationMcpServerRowsTableAnnotationComposer,
          $$ConversationMcpServerRowsTableCreateCompanionBuilder,
          $$ConversationMcpServerRowsTableUpdateCompanionBuilder,
          (
            ConversationMcpServerRow,
            $$ConversationMcpServerRowsTableReferences,
          ),
          ConversationMcpServerRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$ConversationMcpServerRowsTableTableManager(
    _$AppDatabase db,
    $ConversationMcpServerRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMcpServerRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ConversationMcpServerRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationMcpServerRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationMcpServerRowsCompanion(
                conversationId: conversationId,
                serverId: serverId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String serverId,
                required int ordinal,
                Value<int> rowid = const Value.absent(),
              }) => ConversationMcpServerRowsCompanion.insert(
                conversationId: conversationId,
                serverId: serverId,
                ordinal: ordinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationMcpServerRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable:
                                    $$ConversationMcpServerRowsTableReferences
                                        ._conversationIdTable(db),
                                referencedColumn:
                                    $$ConversationMcpServerRowsTableReferences
                                        ._conversationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ConversationMcpServerRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationMcpServerRowsTable,
      ConversationMcpServerRow,
      $$ConversationMcpServerRowsTableFilterComposer,
      $$ConversationMcpServerRowsTableOrderingComposer,
      $$ConversationMcpServerRowsTableAnnotationComposer,
      $$ConversationMcpServerRowsTableCreateCompanionBuilder,
      $$ConversationMcpServerRowsTableUpdateCompanionBuilder,
      (ConversationMcpServerRow, $$ConversationMcpServerRowsTableReferences),
      ConversationMcpServerRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$ToolEventRowsTableCreateCompanionBuilder =
    ToolEventRowsCompanion Function({
      required String messageId,
      required String eventsJson,
      Value<int> rowid,
    });
typedef $$ToolEventRowsTableUpdateCompanionBuilder =
    ToolEventRowsCompanion Function({
      Value<String> messageId,
      Value<String> eventsJson,
      Value<int> rowid,
    });

final class $$ToolEventRowsTableReferences
    extends BaseReferences<_$AppDatabase, $ToolEventRowsTable, ToolEventRow> {
  $$ToolEventRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessageRowsTable _messageIdTable(_$AppDatabase db) => db.messageRows
      .createAlias('tool_event_rows__message_id__message_rows__id');

  $$MessageRowsTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('message_id')!;

    final manager = $$MessageRowsTableTableManager(
      $_db,
      $_db.messageRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ToolEventRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ToolEventRowsTable> {
  $$ToolEventRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventsJson => $composableBuilder(
    column: $table.eventsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$MessageRowsTableFilterComposer get messageId {
    final $$MessageRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableFilterComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolEventRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ToolEventRowsTable> {
  $$ToolEventRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventsJson => $composableBuilder(
    column: $table.eventsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessageRowsTableOrderingComposer get messageId {
    final $$MessageRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableOrderingComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolEventRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ToolEventRowsTable> {
  $$ToolEventRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventsJson => $composableBuilder(
    column: $table.eventsJson,
    builder: (column) => column,
  );

  $$MessageRowsTableAnnotationComposer get messageId {
    final $$MessageRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolEventRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ToolEventRowsTable,
          ToolEventRow,
          $$ToolEventRowsTableFilterComposer,
          $$ToolEventRowsTableOrderingComposer,
          $$ToolEventRowsTableAnnotationComposer,
          $$ToolEventRowsTableCreateCompanionBuilder,
          $$ToolEventRowsTableUpdateCompanionBuilder,
          (ToolEventRow, $$ToolEventRowsTableReferences),
          ToolEventRow,
          PrefetchHooks Function({bool messageId})
        > {
  $$ToolEventRowsTableTableManager(_$AppDatabase db, $ToolEventRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ToolEventRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ToolEventRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ToolEventRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> eventsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ToolEventRowsCompanion(
                messageId: messageId,
                eventsJson: eventsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String eventsJson,
                Value<int> rowid = const Value.absent(),
              }) => ToolEventRowsCompanion.insert(
                messageId: messageId,
                eventsJson: eventsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ToolEventRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable: $$ToolEventRowsTableReferences
                                    ._messageIdTable(db),
                                referencedColumn: $$ToolEventRowsTableReferences
                                    ._messageIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ToolEventRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ToolEventRowsTable,
      ToolEventRow,
      $$ToolEventRowsTableFilterComposer,
      $$ToolEventRowsTableOrderingComposer,
      $$ToolEventRowsTableAnnotationComposer,
      $$ToolEventRowsTableCreateCompanionBuilder,
      $$ToolEventRowsTableUpdateCompanionBuilder,
      (ToolEventRow, $$ToolEventRowsTableReferences),
      ToolEventRow,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$GeminiThoughtSignatureRowsTableCreateCompanionBuilder =
    GeminiThoughtSignatureRowsCompanion Function({
      required String messageId,
      required String signature,
      Value<int> rowid,
    });
typedef $$GeminiThoughtSignatureRowsTableUpdateCompanionBuilder =
    GeminiThoughtSignatureRowsCompanion Function({
      Value<String> messageId,
      Value<String> signature,
      Value<int> rowid,
    });

final class $$GeminiThoughtSignatureRowsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GeminiThoughtSignatureRowsTable,
          GeminiThoughtSignatureRow
        > {
  $$GeminiThoughtSignatureRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessageRowsTable _messageIdTable(_$AppDatabase db) =>
      db.messageRows.createAlias(
        'gemini_thought_signature_rows__message_id__message_rows__id',
      );

  $$MessageRowsTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('message_id')!;

    final manager = $$MessageRowsTableTableManager(
      $_db,
      $_db.messageRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GeminiThoughtSignatureRowsTableFilterComposer
    extends Composer<_$AppDatabase, $GeminiThoughtSignatureRowsTable> {
  $$GeminiThoughtSignatureRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  $$MessageRowsTableFilterComposer get messageId {
    final $$MessageRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableFilterComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GeminiThoughtSignatureRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $GeminiThoughtSignatureRowsTable> {
  $$GeminiThoughtSignatureRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessageRowsTableOrderingComposer get messageId {
    final $$MessageRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableOrderingComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GeminiThoughtSignatureRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GeminiThoughtSignatureRowsTable> {
  $$GeminiThoughtSignatureRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  $$MessageRowsTableAnnotationComposer get messageId {
    final $$MessageRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.messageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GeminiThoughtSignatureRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GeminiThoughtSignatureRowsTable,
          GeminiThoughtSignatureRow,
          $$GeminiThoughtSignatureRowsTableFilterComposer,
          $$GeminiThoughtSignatureRowsTableOrderingComposer,
          $$GeminiThoughtSignatureRowsTableAnnotationComposer,
          $$GeminiThoughtSignatureRowsTableCreateCompanionBuilder,
          $$GeminiThoughtSignatureRowsTableUpdateCompanionBuilder,
          (
            GeminiThoughtSignatureRow,
            $$GeminiThoughtSignatureRowsTableReferences,
          ),
          GeminiThoughtSignatureRow,
          PrefetchHooks Function({bool messageId})
        > {
  $$GeminiThoughtSignatureRowsTableTableManager(
    _$AppDatabase db,
    $GeminiThoughtSignatureRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GeminiThoughtSignatureRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GeminiThoughtSignatureRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GeminiThoughtSignatureRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GeminiThoughtSignatureRowsCompanion(
                messageId: messageId,
                signature: signature,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String signature,
                Value<int> rowid = const Value.absent(),
              }) => GeminiThoughtSignatureRowsCompanion.insert(
                messageId: messageId,
                signature: signature,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GeminiThoughtSignatureRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable:
                                    $$GeminiThoughtSignatureRowsTableReferences
                                        ._messageIdTable(db),
                                referencedColumn:
                                    $$GeminiThoughtSignatureRowsTableReferences
                                        ._messageIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GeminiThoughtSignatureRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GeminiThoughtSignatureRowsTable,
      GeminiThoughtSignatureRow,
      $$GeminiThoughtSignatureRowsTableFilterComposer,
      $$GeminiThoughtSignatureRowsTableOrderingComposer,
      $$GeminiThoughtSignatureRowsTableAnnotationComposer,
      $$GeminiThoughtSignatureRowsTableCreateCompanionBuilder,
      $$GeminiThoughtSignatureRowsTableUpdateCompanionBuilder,
      (GeminiThoughtSignatureRow, $$GeminiThoughtSignatureRowsTableReferences),
      GeminiThoughtSignatureRow,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$CacheRowsTableCreateCompanionBuilder =
    CacheRowsCompanion Function({
      required String type,
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CacheRowsTableUpdateCompanionBuilder =
    CacheRowsCompanion Function({
      Value<String> type,
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CacheRowsTableFilterComposer
    extends Composer<_$AppDatabase, $CacheRowsTable> {
  $$CacheRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheRowsTable> {
  $$CacheRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheRowsTable> {
  $$CacheRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CacheRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheRowsTable,
          CacheRow,
          $$CacheRowsTableFilterComposer,
          $$CacheRowsTableOrderingComposer,
          $$CacheRowsTableAnnotationComposer,
          $$CacheRowsTableCreateCompanionBuilder,
          $$CacheRowsTableUpdateCompanionBuilder,
          (CacheRow, BaseReferences<_$AppDatabase, $CacheRowsTable, CacheRow>),
          CacheRow,
          PrefetchHooks Function()
        > {
  $$CacheRowsTableTableManager(_$AppDatabase db, $CacheRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> type = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheRowsCompanion(
                type: type,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String type,
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CacheRowsCompanion.insert(
                type: type,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheRowsTable,
      CacheRow,
      $$CacheRowsTableFilterComposer,
      $$CacheRowsTableOrderingComposer,
      $$CacheRowsTableAnnotationComposer,
      $$CacheRowsTableCreateCompanionBuilder,
      $$CacheRowsTableUpdateCompanionBuilder,
      (CacheRow, BaseReferences<_$AppDatabase, $CacheRowsTable, CacheRow>),
      CacheRow,
      PrefetchHooks Function()
    >;
typedef $$ChatStorageMetaRowsTableCreateCompanionBuilder =
    ChatStorageMetaRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$ChatStorageMetaRowsTableUpdateCompanionBuilder =
    ChatStorageMetaRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$ChatStorageMetaRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ChatStorageMetaRowsTable> {
  $$ChatStorageMetaRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatStorageMetaRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatStorageMetaRowsTable> {
  $$ChatStorageMetaRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatStorageMetaRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatStorageMetaRowsTable> {
  $$ChatStorageMetaRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ChatStorageMetaRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatStorageMetaRowsTable,
          ChatStorageMetaRow,
          $$ChatStorageMetaRowsTableFilterComposer,
          $$ChatStorageMetaRowsTableOrderingComposer,
          $$ChatStorageMetaRowsTableAnnotationComposer,
          $$ChatStorageMetaRowsTableCreateCompanionBuilder,
          $$ChatStorageMetaRowsTableUpdateCompanionBuilder,
          (
            ChatStorageMetaRow,
            BaseReferences<
              _$AppDatabase,
              $ChatStorageMetaRowsTable,
              ChatStorageMetaRow
            >,
          ),
          ChatStorageMetaRow,
          PrefetchHooks Function()
        > {
  $$ChatStorageMetaRowsTableTableManager(
    _$AppDatabase db,
    $ChatStorageMetaRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatStorageMetaRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatStorageMetaRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ChatStorageMetaRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatStorageMetaRowsCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ChatStorageMetaRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatStorageMetaRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatStorageMetaRowsTable,
      ChatStorageMetaRow,
      $$ChatStorageMetaRowsTableFilterComposer,
      $$ChatStorageMetaRowsTableOrderingComposer,
      $$ChatStorageMetaRowsTableAnnotationComposer,
      $$ChatStorageMetaRowsTableCreateCompanionBuilder,
      $$ChatStorageMetaRowsTableUpdateCompanionBuilder,
      (
        ChatStorageMetaRow,
        BaseReferences<
          _$AppDatabase,
          $ChatStorageMetaRowsTable,
          ChatStorageMetaRow
        >,
      ),
      ChatStorageMetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationRowsTableTableManager get conversationRows =>
      $$ConversationRowsTableTableManager(_db, _db.conversationRows);
  $$MessageRowsTableTableManager get messageRows =>
      $$MessageRowsTableTableManager(_db, _db.messageRows);
  $$AssistantRowsTableTableManager get assistantRows =>
      $$AssistantRowsTableTableManager(_db, _db.assistantRows);
  $$ConversationMcpServerRowsTableTableManager get conversationMcpServerRows =>
      $$ConversationMcpServerRowsTableTableManager(
        _db,
        _db.conversationMcpServerRows,
      );
  $$ToolEventRowsTableTableManager get toolEventRows =>
      $$ToolEventRowsTableTableManager(_db, _db.toolEventRows);
  $$GeminiThoughtSignatureRowsTableTableManager
  get geminiThoughtSignatureRows =>
      $$GeminiThoughtSignatureRowsTableTableManager(
        _db,
        _db.geminiThoughtSignatureRows,
      );
  $$CacheRowsTableTableManager get cacheRows =>
      $$CacheRowsTableTableManager(_db, _db.cacheRows);
  $$ChatStorageMetaRowsTableTableManager get chatStorageMetaRows =>
      $$ChatStorageMetaRowsTableTableManager(_db, _db.chatStorageMetaRows);
}
