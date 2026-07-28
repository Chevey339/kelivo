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
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ConversationRowsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ConversationRowsTable.$converterupdatedAt);
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
    check: () => ComparableExpr(truncateIndex).isBiggerOrEqualValue(-1),
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
        check: () =>
            ComparableExpr(lastSummarizedMessageCount).isBiggerOrEqualValue(0),
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
      createdAt: $ConversationRowsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ConversationRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
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

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
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
    {
      map['created_at'] = Variable<int>(
        $ConversationRowsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $ConversationRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
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
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
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
      map['created_at'] = Variable<int>(
        $ConversationRowsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ConversationRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
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
    check: () => role.isNotValue(''),
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
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> timestamp =
      GeneratedColumn<int>(
        'timestamp',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MessageRowsTable.$convertertimestamp);
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
    check: () => ComparableExpr(totalTokens).isBiggerOrEqualValue(0),
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
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> reasoningStartAt =
      GeneratedColumn<int>(
        'reasoning_start_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MessageRowsTable.$converterreasoningStartAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int>
  reasoningFinishedAt = GeneratedColumn<int>(
    'reasoning_finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($MessageRowsTable.$converterreasoningFinishedAtn);
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
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => ComparableExpr(version).isBiggerOrEqualValue(0),
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
    check: () => ComparableExpr(promptTokens).isBiggerOrEqualValue(0),
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
    check: () => ComparableExpr(completionTokens).isBiggerOrEqualValue(0),
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
    check: () => ComparableExpr(cachedTokens).isBiggerOrEqualValue(0),
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
    check: () => ComparableExpr(durationMs).isBiggerOrEqualValue(0),
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
    check: () => ComparableExpr(messageOrder).isBiggerOrEqualValue(0),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {conversationId, messageOrder},
    {conversationId, groupId, version},
  ];
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
      timestamp: $MessageRowsTable.$convertertimestamp.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}timestamp'],
        )!,
      ),
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
      reasoningStartAt: $MessageRowsTable.$converterreasoningStartAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}reasoning_start_at'],
        ),
      ),
      reasoningFinishedAt: $MessageRowsTable.$converterreasoningFinishedAtn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}reasoning_finished_at'],
            ),
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

  static TypeConverter<DateTime, int> $convertertimestamp =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterreasoningStartAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterreasoningStartAtn =
      NullAwareTypeConverter.wrap($converterreasoningStartAt);
  static TypeConverter<DateTime, int> $converterreasoningFinishedAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterreasoningFinishedAtn =
      NullAwareTypeConverter.wrap($converterreasoningFinishedAt);
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
    {
      map['timestamp'] = Variable<int>(
        $MessageRowsTable.$convertertimestamp.toSql(timestamp),
      );
    }
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
      map['reasoning_start_at'] = Variable<int>(
        $MessageRowsTable.$converterreasoningStartAtn.toSql(reasoningStartAt),
      );
    }
    if (!nullToAbsent || reasoningFinishedAt != null) {
      map['reasoning_finished_at'] = Variable<int>(
        $MessageRowsTable.$converterreasoningFinishedAtn.toSql(
          reasoningFinishedAt,
        ),
      );
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
    Expression<int>? timestamp,
    Expression<String>? modelId,
    Expression<String>? providerId,
    Expression<int>? totalTokens,
    Expression<bool>? isStreaming,
    Expression<String>? reasoningText,
    Expression<int>? reasoningStartAt,
    Expression<int>? reasoningFinishedAt,
    Expression<String>? translation,
    Expression<String>? reasoningSegmentsJson,
    Expression<String>? groupId,
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
      map['timestamp'] = Variable<int>(
        $MessageRowsTable.$convertertimestamp.toSql(timestamp.value),
      );
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
      map['reasoning_start_at'] = Variable<int>(
        $MessageRowsTable.$converterreasoningStartAtn.toSql(
          reasoningStartAt.value,
        ),
      );
    }
    if (reasoningFinishedAt.present) {
      map['reasoning_finished_at'] = Variable<int>(
        $MessageRowsTable.$converterreasoningFinishedAtn.toSql(
          reasoningFinishedAt.value,
        ),
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
    check: () => ComparableExpr(ordinal).isBiggerOrEqualValue(0),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {conversationId, ordinal},
  ];
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

class $MessagePartRowsTable extends MessagePartRows
    with TableInfo<$MessagePartRowsTable, MessagePartRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagePartRowsTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _revisionIdMeta = const VerificationMeta(
    'revisionId',
  );
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
    'revision_id',
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
    check: () => ComparableExpr(ordinal).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    check: () =>
        kind.isIn(const ['text', 'reasoning', 'tool_call', 'tool_result']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MessagePartRowsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MessagePartRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    revisionId,
    ordinal,
    kind,
    payload,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_part_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessagePartRow> instance, {
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
    if (data.containsKey('revision_id')) {
      context.handle(
        _revisionIdMeta,
        revisionId.isAcceptableOrUnknown(data['revision_id']!, _revisionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId, ordinal};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {conversationId, revisionId, ordinal},
  ];
  @override
  MessagePartRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessagePartRow(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      revisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: $MessagePartRowsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $MessagePartRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $MessagePartRowsTable createAlias(String alias) {
    return $MessagePartRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class MessagePartRow extends DataClass implements Insertable<MessagePartRow> {
  final String conversationId;
  final String revisionId;
  final int ordinal;
  final String kind;
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MessagePartRow({
    required this.conversationId,
    required this.revisionId,
    required this.ordinal,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['revision_id'] = Variable<String>(revisionId);
    map['ordinal'] = Variable<int>(ordinal);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    {
      map['created_at'] = Variable<int>(
        $MessagePartRowsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $MessagePartRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  MessagePartRowsCompanion toCompanion(bool nullToAbsent) {
    return MessagePartRowsCompanion(
      conversationId: Value(conversationId),
      revisionId: Value(revisionId),
      ordinal: Value(ordinal),
      kind: Value(kind),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MessagePartRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessagePartRow(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      revisionId: serializer.fromJson<String>(json['revisionId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'revisionId': serializer.toJson<String>(revisionId),
      'ordinal': serializer.toJson<int>(ordinal),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MessagePartRow copyWith({
    String? conversationId,
    String? revisionId,
    int? ordinal,
    String? kind,
    String? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MessagePartRow(
    conversationId: conversationId ?? this.conversationId,
    revisionId: revisionId ?? this.revisionId,
    ordinal: ordinal ?? this.ordinal,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MessagePartRow copyWithCompanion(MessagePartRowsCompanion data) {
    return MessagePartRow(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      revisionId: data.revisionId.present
          ? data.revisionId.value
          : this.revisionId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessagePartRow(')
          ..write('conversationId: $conversationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conversationId,
    revisionId,
    ordinal,
    kind,
    payload,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessagePartRow &&
          other.conversationId == this.conversationId &&
          other.revisionId == this.revisionId &&
          other.ordinal == this.ordinal &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MessagePartRowsCompanion extends UpdateCompanion<MessagePartRow> {
  final Value<String> conversationId;
  final Value<String> revisionId;
  final Value<int> ordinal;
  final Value<String> kind;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MessagePartRowsCompanion({
    this.conversationId = const Value.absent(),
    this.revisionId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagePartRowsCompanion.insert({
    required String conversationId,
    required String revisionId,
    required int ordinal,
    required String kind,
    required String payload,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       revisionId = Value(revisionId),
       ordinal = Value(ordinal),
       kind = Value(kind),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MessagePartRow> custom({
    Expression<String>? conversationId,
    Expression<String>? revisionId,
    Expression<int>? ordinal,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (revisionId != null) 'revision_id': revisionId,
      if (ordinal != null) 'ordinal': ordinal,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagePartRowsCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? revisionId,
    Value<int>? ordinal,
    Value<String>? kind,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MessagePartRowsCompanion(
      conversationId: conversationId ?? this.conversationId,
      revisionId: revisionId ?? this.revisionId,
      ordinal: ordinal ?? this.ordinal,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $MessagePartRowsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $MessagePartRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagePartRowsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderArtifactRowsTable extends ProviderArtifactRows
    with TableInfo<$ProviderArtifactRowsTable, ProviderArtifactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderArtifactRowsTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _revisionIdMeta = const VerificationMeta(
    'revisionId',
  );
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
    'revision_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    check: () => kind.isNotValue(''),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProviderArtifactRowsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProviderArtifactRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    revisionId,
    kind,
    payload,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_artifact_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderArtifactRow> instance, {
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
    if (data.containsKey('revision_id')) {
      context.handle(
        _revisionIdMeta,
        revisionId.isAcceptableOrUnknown(data['revision_id']!, _revisionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId, kind};
  @override
  ProviderArtifactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderArtifactRow(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      revisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: $ProviderArtifactRowsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ProviderArtifactRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ProviderArtifactRowsTable createAlias(String alias) {
    return $ProviderArtifactRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class ProviderArtifactRow extends DataClass
    implements Insertable<ProviderArtifactRow> {
  final String conversationId;
  final String revisionId;
  final String kind;
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProviderArtifactRow({
    required this.conversationId,
    required this.revisionId,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['revision_id'] = Variable<String>(revisionId);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    {
      map['created_at'] = Variable<int>(
        $ProviderArtifactRowsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $ProviderArtifactRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ProviderArtifactRowsCompanion toCompanion(bool nullToAbsent) {
    return ProviderArtifactRowsCompanion(
      conversationId: Value(conversationId),
      revisionId: Value(revisionId),
      kind: Value(kind),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderArtifactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderArtifactRow(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      revisionId: serializer.fromJson<String>(json['revisionId']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'revisionId': serializer.toJson<String>(revisionId),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderArtifactRow copyWith({
    String? conversationId,
    String? revisionId,
    String? kind,
    String? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProviderArtifactRow(
    conversationId: conversationId ?? this.conversationId,
    revisionId: revisionId ?? this.revisionId,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderArtifactRow copyWithCompanion(ProviderArtifactRowsCompanion data) {
    return ProviderArtifactRow(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      revisionId: data.revisionId.present
          ? data.revisionId.value
          : this.revisionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderArtifactRow(')
          ..write('conversationId: $conversationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conversationId,
    revisionId,
    kind,
    payload,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderArtifactRow &&
          other.conversationId == this.conversationId &&
          other.revisionId == this.revisionId &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProviderArtifactRowsCompanion
    extends UpdateCompanion<ProviderArtifactRow> {
  final Value<String> conversationId;
  final Value<String> revisionId;
  final Value<String> kind;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderArtifactRowsCompanion({
    this.conversationId = const Value.absent(),
    this.revisionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderArtifactRowsCompanion.insert({
    required String conversationId,
    required String revisionId,
    required String kind,
    required String payload,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       revisionId = Value(revisionId),
       kind = Value(kind),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProviderArtifactRow> custom({
    Expression<String>? conversationId,
    Expression<String>? revisionId,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (revisionId != null) 'revision_id': revisionId,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderArtifactRowsCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? revisionId,
    Value<String>? kind,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderArtifactRowsCompanion(
      conversationId: conversationId ?? this.conversationId,
      revisionId: revisionId ?? this.revisionId,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ProviderArtifactRowsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ProviderArtifactRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderArtifactRowsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssetRowsTable extends AssetRows
    with TableInfo<$AssetRowsTable, AssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    check: () => ComparableExpr(byteSize).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    check: () => ComparableExpr(width).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    check: () => ComparableExpr(height).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AssetRowsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> lastReferencedAt =
      GeneratedColumn<int>(
        'last_referenced_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AssetRowsTable.$converterlastReferencedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contentHash,
    path,
    byteSize,
    width,
    height,
    thumbnailPath,
    createdAt,
    lastReferencedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      createdAt: $AssetRowsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      lastReferencedAt: $AssetRowsTable.$converterlastReferencedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_referenced_at'],
        )!,
      ),
    );
  }

  @override
  $AssetRowsTable createAlias(String alias) {
    return $AssetRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterlastReferencedAt =
      const MicrosecondDateTimeConverter();
}

class AssetRow extends DataClass implements Insertable<AssetRow> {
  final String id;
  final String contentHash;
  final String path;
  final int byteSize;
  final int? width;
  final int? height;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime lastReferencedAt;
  const AssetRow({
    required this.id,
    required this.contentHash,
    required this.path,
    required this.byteSize,
    this.width,
    this.height,
    this.thumbnailPath,
    required this.createdAt,
    required this.lastReferencedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content_hash'] = Variable<String>(contentHash);
    map['path'] = Variable<String>(path);
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    {
      map['created_at'] = Variable<int>(
        $AssetRowsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['last_referenced_at'] = Variable<int>(
        $AssetRowsTable.$converterlastReferencedAt.toSql(lastReferencedAt),
      );
    }
    return map;
  }

  AssetRowsCompanion toCompanion(bool nullToAbsent) {
    return AssetRowsCompanion(
      id: Value(id),
      contentHash: Value(contentHash),
      path: Value(path),
      byteSize: Value(byteSize),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      createdAt: Value(createdAt),
      lastReferencedAt: Value(lastReferencedAt),
    );
  }

  factory AssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetRow(
      id: serializer.fromJson<String>(json['id']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      path: serializer.fromJson<String>(json['path']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastReferencedAt: serializer.fromJson<DateTime>(json['lastReferencedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'contentHash': serializer.toJson<String>(contentHash),
      'path': serializer.toJson<String>(path),
      'byteSize': serializer.toJson<int>(byteSize),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastReferencedAt': serializer.toJson<DateTime>(lastReferencedAt),
    };
  }

  AssetRow copyWith({
    String? id,
    String? contentHash,
    String? path,
    int? byteSize,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    DateTime? createdAt,
    DateTime? lastReferencedAt,
  }) => AssetRow(
    id: id ?? this.id,
    contentHash: contentHash ?? this.contentHash,
    path: path ?? this.path,
    byteSize: byteSize ?? this.byteSize,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    createdAt: createdAt ?? this.createdAt,
    lastReferencedAt: lastReferencedAt ?? this.lastReferencedAt,
  );
  AssetRow copyWithCompanion(AssetRowsCompanion data) {
    return AssetRow(
      id: data.id.present ? data.id.value : this.id,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      path: data.path.present ? data.path.value : this.path,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastReferencedAt: data.lastReferencedAt.present
          ? data.lastReferencedAt.value
          : this.lastReferencedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetRow(')
          ..write('id: $id, ')
          ..write('contentHash: $contentHash, ')
          ..write('path: $path, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastReferencedAt: $lastReferencedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contentHash,
    path,
    byteSize,
    width,
    height,
    thumbnailPath,
    createdAt,
    lastReferencedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetRow &&
          other.id == this.id &&
          other.contentHash == this.contentHash &&
          other.path == this.path &&
          other.byteSize == this.byteSize &&
          other.width == this.width &&
          other.height == this.height &&
          other.thumbnailPath == this.thumbnailPath &&
          other.createdAt == this.createdAt &&
          other.lastReferencedAt == this.lastReferencedAt);
}

class AssetRowsCompanion extends UpdateCompanion<AssetRow> {
  final Value<String> id;
  final Value<String> contentHash;
  final Value<String> path;
  final Value<int> byteSize;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> thumbnailPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastReferencedAt;
  final Value<int> rowid;
  const AssetRowsCompanion({
    this.id = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.path = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastReferencedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetRowsCompanion.insert({
    required String id,
    required String contentHash,
    required String path,
    required int byteSize,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastReferencedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       contentHash = Value(contentHash),
       path = Value(path),
       byteSize = Value(byteSize),
       createdAt = Value(createdAt),
       lastReferencedAt = Value(lastReferencedAt);
  static Insertable<AssetRow> custom({
    Expression<String>? id,
    Expression<String>? contentHash,
    Expression<String>? path,
    Expression<int>? byteSize,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? thumbnailPath,
    Expression<int>? createdAt,
    Expression<int>? lastReferencedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentHash != null) 'content_hash': contentHash,
      if (path != null) 'path': path,
      if (byteSize != null) 'byte_size': byteSize,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (createdAt != null) 'created_at': createdAt,
      if (lastReferencedAt != null) 'last_referenced_at': lastReferencedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? contentHash,
    Value<String>? path,
    Value<int>? byteSize,
    Value<int?>? width,
    Value<int?>? height,
    Value<String?>? thumbnailPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastReferencedAt,
    Value<int>? rowid,
  }) {
    return AssetRowsCompanion(
      id: id ?? this.id,
      contentHash: contentHash ?? this.contentHash,
      path: path ?? this.path,
      byteSize: byteSize ?? this.byteSize,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      lastReferencedAt: lastReferencedAt ?? this.lastReferencedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $AssetRowsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (lastReferencedAt.present) {
      map['last_referenced_at'] = Variable<int>(
        $AssetRowsTable.$converterlastReferencedAt.toSql(
          lastReferencedAt.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetRowsCompanion(')
          ..write('id: $id, ')
          ..write('contentHash: $contentHash, ')
          ..write('path: $path, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastReferencedAt: $lastReferencedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageAssetRowsTable extends MessageAssetRows
    with TableInfo<$MessageAssetRowsTable, MessageAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageAssetRowsTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _revisionIdMeta = const VerificationMeta(
    'revisionId',
  );
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
    'revision_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES message_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES asset_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    check: () => kind.isNotValue(''),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    revisionId,
    assetId,
    kind,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_asset_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageAssetRow> instance, {
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
    if (data.containsKey('revision_id')) {
      context.handle(
        _revisionIdMeta,
        revisionId.isAcceptableOrUnknown(data['revision_id']!, _revisionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId, assetId, kind};
  @override
  MessageAssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageAssetRow(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      revisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $MessageAssetRowsTable createAlias(String alias) {
    return $MessageAssetRowsTable(attachedDatabase, alias);
  }
}

class MessageAssetRow extends DataClass implements Insertable<MessageAssetRow> {
  final String conversationId;
  final String revisionId;
  final String assetId;
  final String kind;
  const MessageAssetRow({
    required this.conversationId,
    required this.revisionId,
    required this.assetId,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['revision_id'] = Variable<String>(revisionId);
    map['asset_id'] = Variable<String>(assetId);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  MessageAssetRowsCompanion toCompanion(bool nullToAbsent) {
    return MessageAssetRowsCompanion(
      conversationId: Value(conversationId),
      revisionId: Value(revisionId),
      assetId: Value(assetId),
      kind: Value(kind),
    );
  }

  factory MessageAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageAssetRow(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      revisionId: serializer.fromJson<String>(json['revisionId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'revisionId': serializer.toJson<String>(revisionId),
      'assetId': serializer.toJson<String>(assetId),
      'kind': serializer.toJson<String>(kind),
    };
  }

  MessageAssetRow copyWith({
    String? conversationId,
    String? revisionId,
    String? assetId,
    String? kind,
  }) => MessageAssetRow(
    conversationId: conversationId ?? this.conversationId,
    revisionId: revisionId ?? this.revisionId,
    assetId: assetId ?? this.assetId,
    kind: kind ?? this.kind,
  );
  MessageAssetRow copyWithCompanion(MessageAssetRowsCompanion data) {
    return MessageAssetRow(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      revisionId: data.revisionId.present
          ? data.revisionId.value
          : this.revisionId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageAssetRow(')
          ..write('conversationId: $conversationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('assetId: $assetId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conversationId, revisionId, assetId, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageAssetRow &&
          other.conversationId == this.conversationId &&
          other.revisionId == this.revisionId &&
          other.assetId == this.assetId &&
          other.kind == this.kind);
}

class MessageAssetRowsCompanion extends UpdateCompanion<MessageAssetRow> {
  final Value<String> conversationId;
  final Value<String> revisionId;
  final Value<String> assetId;
  final Value<String> kind;
  final Value<int> rowid;
  const MessageAssetRowsCompanion({
    this.conversationId = const Value.absent(),
    this.revisionId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageAssetRowsCompanion.insert({
    required String conversationId,
    required String revisionId,
    required String assetId,
    required String kind,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       revisionId = Value(revisionId),
       assetId = Value(assetId),
       kind = Value(kind);
  static Insertable<MessageAssetRow> custom({
    Expression<String>? conversationId,
    Expression<String>? revisionId,
    Expression<String>? assetId,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (revisionId != null) 'revision_id': revisionId,
      if (assetId != null) 'asset_id': assetId,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageAssetRowsCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? revisionId,
    Value<String>? assetId,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return MessageAssetRowsCompanion(
      conversationId: conversationId ?? this.conversationId,
      revisionId: revisionId ?? this.revisionId,
      assetId: assetId ?? this.assetId,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageAssetRowsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('assetId: $assetId, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssetGcRowsTable extends AssetGcRows
    with TableInfo<$AssetGcRowsTable, AssetGcRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetGcRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES asset_rows (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> notBefore =
      GeneratedColumn<int>(
        'not_before',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AssetGcRowsTable.$converternotBefore);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    check: () => ComparableExpr(attempts).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    check: () => ComparableExpr(generation).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetId,
    notBefore,
    attempts,
    generation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_gc_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetGcRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  AssetGcRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetGcRow(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      notBefore: $AssetGcRowsTable.$converternotBefore.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}not_before'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
    );
  }

  @override
  $AssetGcRowsTable createAlias(String alias) {
    return $AssetGcRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converternotBefore =
      const MicrosecondDateTimeConverter();
}

class AssetGcRow extends DataClass implements Insertable<AssetGcRow> {
  final String assetId;
  final DateTime notBefore;
  final int attempts;
  final int generation;
  const AssetGcRow({
    required this.assetId,
    required this.notBefore,
    required this.attempts,
    required this.generation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    {
      map['not_before'] = Variable<int>(
        $AssetGcRowsTable.$converternotBefore.toSql(notBefore),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    map['generation'] = Variable<int>(generation);
    return map;
  }

  AssetGcRowsCompanion toCompanion(bool nullToAbsent) {
    return AssetGcRowsCompanion(
      assetId: Value(assetId),
      notBefore: Value(notBefore),
      attempts: Value(attempts),
      generation: Value(generation),
    );
  }

  factory AssetGcRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetGcRow(
      assetId: serializer.fromJson<String>(json['assetId']),
      notBefore: serializer.fromJson<DateTime>(json['notBefore']),
      attempts: serializer.fromJson<int>(json['attempts']),
      generation: serializer.fromJson<int>(json['generation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'notBefore': serializer.toJson<DateTime>(notBefore),
      'attempts': serializer.toJson<int>(attempts),
      'generation': serializer.toJson<int>(generation),
    };
  }

  AssetGcRow copyWith({
    String? assetId,
    DateTime? notBefore,
    int? attempts,
    int? generation,
  }) => AssetGcRow(
    assetId: assetId ?? this.assetId,
    notBefore: notBefore ?? this.notBefore,
    attempts: attempts ?? this.attempts,
    generation: generation ?? this.generation,
  );
  AssetGcRow copyWithCompanion(AssetGcRowsCompanion data) {
    return AssetGcRow(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      notBefore: data.notBefore.present ? data.notBefore.value : this.notBefore,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetGcRow(')
          ..write('assetId: $assetId, ')
          ..write('notBefore: $notBefore, ')
          ..write('attempts: $attempts, ')
          ..write('generation: $generation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, notBefore, attempts, generation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetGcRow &&
          other.assetId == this.assetId &&
          other.notBefore == this.notBefore &&
          other.attempts == this.attempts &&
          other.generation == this.generation);
}

class AssetGcRowsCompanion extends UpdateCompanion<AssetGcRow> {
  final Value<String> assetId;
  final Value<DateTime> notBefore;
  final Value<int> attempts;
  final Value<int> generation;
  final Value<int> rowid;
  const AssetGcRowsCompanion({
    this.assetId = const Value.absent(),
    this.notBefore = const Value.absent(),
    this.attempts = const Value.absent(),
    this.generation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetGcRowsCompanion.insert({
    required String assetId,
    required DateTime notBefore,
    this.attempts = const Value.absent(),
    this.generation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       notBefore = Value(notBefore);
  static Insertable<AssetGcRow> custom({
    Expression<String>? assetId,
    Expression<int>? notBefore,
    Expression<int>? attempts,
    Expression<int>? generation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (notBefore != null) 'not_before': notBefore,
      if (attempts != null) 'attempts': attempts,
      if (generation != null) 'generation': generation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetGcRowsCompanion copyWith({
    Value<String>? assetId,
    Value<DateTime>? notBefore,
    Value<int>? attempts,
    Value<int>? generation,
    Value<int>? rowid,
  }) {
    return AssetGcRowsCompanion(
      assetId: assetId ?? this.assetId,
      notBefore: notBefore ?? this.notBefore,
      attempts: attempts ?? this.attempts,
      generation: generation ?? this.generation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (notBefore.present) {
      map['not_before'] = Variable<int>(
        $AssetGcRowsTable.$converternotBefore.toSql(notBefore.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetGcRowsCompanion(')
          ..write('assetId: $assetId, ')
          ..write('notBefore: $notBefore, ')
          ..write('attempts: $attempts, ')
          ..write('generation: $generation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GcAuditRowsTable extends GcAuditRows
    with TableInfo<$GcAuditRowsTable, GcAuditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GcAuditRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> completedAt =
      GeneratedColumn<int>(
        'completed_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($GcAuditRowsTable.$convertercompletedAt);
  @override
  List<GeneratedColumn> get $columns => [id, kind, entityId, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gc_audit_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<GcAuditRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GcAuditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GcAuditRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      completedAt: $GcAuditRowsTable.$convertercompletedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}completed_at'],
        )!,
      ),
    );
  }

  @override
  $GcAuditRowsTable createAlias(String alias) {
    return $GcAuditRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercompletedAt =
      const MicrosecondDateTimeConverter();
}

class GcAuditRow extends DataClass implements Insertable<GcAuditRow> {
  final int id;
  final String kind;
  final String entityId;
  final DateTime completedAt;
  const GcAuditRow({
    required this.id,
    required this.kind,
    required this.entityId,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    {
      map['completed_at'] = Variable<int>(
        $GcAuditRowsTable.$convertercompletedAt.toSql(completedAt),
      );
    }
    return map;
  }

  GcAuditRowsCompanion toCompanion(bool nullToAbsent) {
    return GcAuditRowsCompanion(
      id: Value(id),
      kind: Value(kind),
      entityId: Value(entityId),
      completedAt: Value(completedAt),
    );
  }

  factory GcAuditRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GcAuditRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'entityId': serializer.toJson<String>(entityId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  GcAuditRow copyWith({
    int? id,
    String? kind,
    String? entityId,
    DateTime? completedAt,
  }) => GcAuditRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    completedAt: completedAt ?? this.completedAt,
  );
  GcAuditRow copyWithCompanion(GcAuditRowsCompanion data) {
    return GcAuditRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GcAuditRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, entityId, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GcAuditRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.completedAt == this.completedAt);
}

class GcAuditRowsCompanion extends UpdateCompanion<GcAuditRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> entityId;
  final Value<DateTime> completedAt;
  const GcAuditRowsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  GcAuditRowsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String entityId,
    required DateTime completedAt,
  }) : kind = Value(kind),
       entityId = Value(entityId),
       completedAt = Value(completedAt);
  static Insertable<GcAuditRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<int>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  GcAuditRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? entityId,
    Value<DateTime>? completedAt,
  }) {
    return GcAuditRowsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(
        $GcAuditRowsTable.$convertercompletedAt.toSql(completedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GcAuditRowsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $AssetReferenceDirtyRowsTable extends AssetReferenceDirtyRows
    with TableInfo<$AssetReferenceDirtyRowsTable, AssetReferenceDirtyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetReferenceDirtyRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _revisionIdMeta = const VerificationMeta(
    'revisionId',
  );
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
    'revision_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES message_rows (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [revisionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_reference_dirty_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetReferenceDirtyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('revision_id')) {
      context.handle(
        _revisionIdMeta,
        revisionId.isAcceptableOrUnknown(data['revision_id']!, _revisionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId};
  @override
  AssetReferenceDirtyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetReferenceDirtyRow(
      revisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision_id'],
      )!,
    );
  }

  @override
  $AssetReferenceDirtyRowsTable createAlias(String alias) {
    return $AssetReferenceDirtyRowsTable(attachedDatabase, alias);
  }
}

class AssetReferenceDirtyRow extends DataClass
    implements Insertable<AssetReferenceDirtyRow> {
  final String revisionId;
  const AssetReferenceDirtyRow({required this.revisionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['revision_id'] = Variable<String>(revisionId);
    return map;
  }

  AssetReferenceDirtyRowsCompanion toCompanion(bool nullToAbsent) {
    return AssetReferenceDirtyRowsCompanion(revisionId: Value(revisionId));
  }

  factory AssetReferenceDirtyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetReferenceDirtyRow(
      revisionId: serializer.fromJson<String>(json['revisionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'revisionId': serializer.toJson<String>(revisionId),
    };
  }

  AssetReferenceDirtyRow copyWith({String? revisionId}) =>
      AssetReferenceDirtyRow(revisionId: revisionId ?? this.revisionId);
  AssetReferenceDirtyRow copyWithCompanion(
    AssetReferenceDirtyRowsCompanion data,
  ) {
    return AssetReferenceDirtyRow(
      revisionId: data.revisionId.present
          ? data.revisionId.value
          : this.revisionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetReferenceDirtyRow(')
          ..write('revisionId: $revisionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => revisionId.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetReferenceDirtyRow && other.revisionId == this.revisionId);
}

class AssetReferenceDirtyRowsCompanion
    extends UpdateCompanion<AssetReferenceDirtyRow> {
  final Value<String> revisionId;
  final Value<int> rowid;
  const AssetReferenceDirtyRowsCompanion({
    this.revisionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetReferenceDirtyRowsCompanion.insert({
    required String revisionId,
    this.rowid = const Value.absent(),
  }) : revisionId = Value(revisionId);
  static Insertable<AssetReferenceDirtyRow> custom({
    Expression<String>? revisionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (revisionId != null) 'revision_id': revisionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetReferenceDirtyRowsCompanion copyWith({
    Value<String>? revisionId,
    Value<int>? rowid,
  }) {
    return AssetReferenceDirtyRowsCompanion(
      revisionId: revisionId ?? this.revisionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetReferenceDirtyRowsCompanion(')
          ..write('revisionId: $revisionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GenerationRunRowsTable extends GenerationRunRows
    with TableInfo<$GenerationRunRowsTable, GenerationRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GenerationRunRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _targetRevisionIdMeta = const VerificationMeta(
    'targetRevisionId',
  );
  @override
  late final GeneratedColumn<String> targetRevisionId = GeneratedColumn<String>(
    'target_revision_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    check: () => state.isIn(const [
      'preparing',
      'requesting',
      'streaming',
      'waiting_tool',
      'completed',
      'failed',
      'cancelled',
      'interrupted',
    ]),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateRevisionMeta = const VerificationMeta(
    'stateRevision',
  );
  @override
  late final GeneratedColumn<int> stateRevision = GeneratedColumn<int>(
    'state_revision',
    aliasedName,
    false,
    check: () => ComparableExpr(stateRevision).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _checkpointSeqMeta = const VerificationMeta(
    'checkpointSeq',
  );
  @override
  late final GeneratedColumn<int> checkpointSeq = GeneratedColumn<int>(
    'checkpoint_seq',
    aliasedName,
    false,
    check: () => ComparableExpr(checkpointSeq).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($GenerationRunRowsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($GenerationRunRowsTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> terminalAt =
      GeneratedColumn<int>(
        'terminal_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($GenerationRunRowsTable.$converterterminalAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    targetRevisionId,
    state,
    stateRevision,
    checkpointSeq,
    errorCode,
    createdAt,
    updatedAt,
    terminalAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'generation_run_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<GenerationRunRow> instance, {
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
    if (data.containsKey('target_revision_id')) {
      context.handle(
        _targetRevisionIdMeta,
        targetRevisionId.isAcceptableOrUnknown(
          data['target_revision_id']!,
          _targetRevisionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetRevisionIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('state_revision')) {
      context.handle(
        _stateRevisionMeta,
        stateRevision.isAcceptableOrUnknown(
          data['state_revision']!,
          _stateRevisionMeta,
        ),
      );
    }
    if (data.containsKey('checkpoint_seq')) {
      context.handle(
        _checkpointSeqMeta,
        checkpointSeq.isAcceptableOrUnknown(
          data['checkpoint_seq']!,
          _checkpointSeqMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GenerationRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GenerationRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      targetRevisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_revision_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      stateRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state_revision'],
      )!,
      checkpointSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checkpoint_seq'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: $GenerationRunRowsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $GenerationRunRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      terminalAt: $GenerationRunRowsTable.$converterterminalAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}terminal_at'],
        ),
      ),
    );
  }

  @override
  $GenerationRunRowsTable createAlias(String alias) {
    return $GenerationRunRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterterminalAt =
      const MicrosecondDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterterminalAtn =
      NullAwareTypeConverter.wrap($converterterminalAt);
}

class GenerationRunRow extends DataClass
    implements Insertable<GenerationRunRow> {
  final String id;
  final String conversationId;
  final String targetRevisionId;
  final String state;
  final int stateRevision;
  final int checkpointSeq;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? terminalAt;
  const GenerationRunRow({
    required this.id,
    required this.conversationId,
    required this.targetRevisionId,
    required this.state,
    required this.stateRevision,
    required this.checkpointSeq,
    this.errorCode,
    required this.createdAt,
    required this.updatedAt,
    this.terminalAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['target_revision_id'] = Variable<String>(targetRevisionId);
    map['state'] = Variable<String>(state);
    map['state_revision'] = Variable<int>(stateRevision);
    map['checkpoint_seq'] = Variable<int>(checkpointSeq);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    {
      map['created_at'] = Variable<int>(
        $GenerationRunRowsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $GenerationRunRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || terminalAt != null) {
      map['terminal_at'] = Variable<int>(
        $GenerationRunRowsTable.$converterterminalAtn.toSql(terminalAt),
      );
    }
    return map;
  }

  GenerationRunRowsCompanion toCompanion(bool nullToAbsent) {
    return GenerationRunRowsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      targetRevisionId: Value(targetRevisionId),
      state: Value(state),
      stateRevision: Value(stateRevision),
      checkpointSeq: Value(checkpointSeq),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      terminalAt: terminalAt == null && nullToAbsent
          ? const Value.absent()
          : Value(terminalAt),
    );
  }

  factory GenerationRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GenerationRunRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      targetRevisionId: serializer.fromJson<String>(json['targetRevisionId']),
      state: serializer.fromJson<String>(json['state']),
      stateRevision: serializer.fromJson<int>(json['stateRevision']),
      checkpointSeq: serializer.fromJson<int>(json['checkpointSeq']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      terminalAt: serializer.fromJson<DateTime?>(json['terminalAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'targetRevisionId': serializer.toJson<String>(targetRevisionId),
      'state': serializer.toJson<String>(state),
      'stateRevision': serializer.toJson<int>(stateRevision),
      'checkpointSeq': serializer.toJson<int>(checkpointSeq),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'terminalAt': serializer.toJson<DateTime?>(terminalAt),
    };
  }

  GenerationRunRow copyWith({
    String? id,
    String? conversationId,
    String? targetRevisionId,
    String? state,
    int? stateRevision,
    int? checkpointSeq,
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> terminalAt = const Value.absent(),
  }) => GenerationRunRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    targetRevisionId: targetRevisionId ?? this.targetRevisionId,
    state: state ?? this.state,
    stateRevision: stateRevision ?? this.stateRevision,
    checkpointSeq: checkpointSeq ?? this.checkpointSeq,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    terminalAt: terminalAt.present ? terminalAt.value : this.terminalAt,
  );
  GenerationRunRow copyWithCompanion(GenerationRunRowsCompanion data) {
    return GenerationRunRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      targetRevisionId: data.targetRevisionId.present
          ? data.targetRevisionId.value
          : this.targetRevisionId,
      state: data.state.present ? data.state.value : this.state,
      stateRevision: data.stateRevision.present
          ? data.stateRevision.value
          : this.stateRevision,
      checkpointSeq: data.checkpointSeq.present
          ? data.checkpointSeq.value
          : this.checkpointSeq,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      terminalAt: data.terminalAt.present
          ? data.terminalAt.value
          : this.terminalAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GenerationRunRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('targetRevisionId: $targetRevisionId, ')
          ..write('state: $state, ')
          ..write('stateRevision: $stateRevision, ')
          ..write('checkpointSeq: $checkpointSeq, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('terminalAt: $terminalAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    targetRevisionId,
    state,
    stateRevision,
    checkpointSeq,
    errorCode,
    createdAt,
    updatedAt,
    terminalAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GenerationRunRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.targetRevisionId == this.targetRevisionId &&
          other.state == this.state &&
          other.stateRevision == this.stateRevision &&
          other.checkpointSeq == this.checkpointSeq &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.terminalAt == this.terminalAt);
}

class GenerationRunRowsCompanion extends UpdateCompanion<GenerationRunRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> targetRevisionId;
  final Value<String> state;
  final Value<int> stateRevision;
  final Value<int> checkpointSeq;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> terminalAt;
  final Value<int> rowid;
  const GenerationRunRowsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.targetRevisionId = const Value.absent(),
    this.state = const Value.absent(),
    this.stateRevision = const Value.absent(),
    this.checkpointSeq = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.terminalAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GenerationRunRowsCompanion.insert({
    required String id,
    required String conversationId,
    required String targetRevisionId,
    required String state,
    this.stateRevision = const Value.absent(),
    this.checkpointSeq = const Value.absent(),
    this.errorCode = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.terminalAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       targetRevisionId = Value(targetRevisionId),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GenerationRunRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? targetRevisionId,
    Expression<String>? state,
    Expression<int>? stateRevision,
    Expression<int>? checkpointSeq,
    Expression<String>? errorCode,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? terminalAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (targetRevisionId != null) 'target_revision_id': targetRevisionId,
      if (state != null) 'state': state,
      if (stateRevision != null) 'state_revision': stateRevision,
      if (checkpointSeq != null) 'checkpoint_seq': checkpointSeq,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (terminalAt != null) 'terminal_at': terminalAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GenerationRunRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? targetRevisionId,
    Value<String>? state,
    Value<int>? stateRevision,
    Value<int>? checkpointSeq,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? terminalAt,
    Value<int>? rowid,
  }) {
    return GenerationRunRowsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      targetRevisionId: targetRevisionId ?? this.targetRevisionId,
      state: state ?? this.state,
      stateRevision: stateRevision ?? this.stateRevision,
      checkpointSeq: checkpointSeq ?? this.checkpointSeq,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      terminalAt: terminalAt ?? this.terminalAt,
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
    if (targetRevisionId.present) {
      map['target_revision_id'] = Variable<String>(targetRevisionId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (stateRevision.present) {
      map['state_revision'] = Variable<int>(stateRevision.value);
    }
    if (checkpointSeq.present) {
      map['checkpoint_seq'] = Variable<int>(checkpointSeq.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $GenerationRunRowsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $GenerationRunRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (terminalAt.present) {
      map['terminal_at'] = Variable<int>(
        $GenerationRunRowsTable.$converterterminalAtn.toSql(terminalAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GenerationRunRowsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('targetRevisionId: $targetRevisionId, ')
          ..write('state: $state, ')
          ..write('stateRevision: $stateRevision, ')
          ..write('checkpointSeq: $checkpointSeq, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('terminalAt: $terminalAt, ')
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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AssistantRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
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
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
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
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $AssistantRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $AssistantRowsTable createAlias(String alias) {
    return $AssistantRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class AssistantRow extends DataClass implements Insertable<AssistantRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const AssistantRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $AssistantRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  AssistantRowsCompanion toCompanion(bool nullToAbsent) {
    return AssistantRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
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
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssistantRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => AssistantRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AssistantRow copyWithCompanion(AssistantRowsCompanion data) {
    return AssistantRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class AssistantRowsCompanion extends UpdateCompanion<AssistantRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AssistantRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<AssistantRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AssistantRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $AssistantRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
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
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderRowsTable extends ProviderRows
    with TableInfo<$ProviderRowsTable, ProviderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerKeyMeta = const VerificationMeta(
    'providerKey',
  );
  @override
  late final GeneratedColumn<String> providerKey = GeneratedColumn<String>(
    'provider_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProviderRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    providerKey,
    sortOrder,
    payload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider_key')) {
      context.handle(
        _providerKeyMeta,
        providerKey.isAcceptableOrUnknown(
          data['provider_key']!,
          _providerKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerKeyMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {providerKey};
  @override
  ProviderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderRow(
      providerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_key'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $ProviderRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ProviderRowsTable createAlias(String alias) {
    return $ProviderRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class ProviderRow extends DataClass implements Insertable<ProviderRow> {
  final String providerKey;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const ProviderRow({
    required this.providerKey,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider_key'] = Variable<String>(providerKey);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $ProviderRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ProviderRowsCompanion toCompanion(bool nullToAbsent) {
    return ProviderRowsCompanion(
      providerKey: Value(providerKey),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderRow(
      providerKey: serializer.fromJson<String>(json['providerKey']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'providerKey': serializer.toJson<String>(providerKey),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderRow copyWith({
    String? providerKey,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => ProviderRow(
    providerKey: providerKey ?? this.providerKey,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderRow copyWithCompanion(ProviderRowsCompanion data) {
    return ProviderRow(
      providerKey: data.providerKey.present
          ? data.providerKey.value
          : this.providerKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderRow(')
          ..write('providerKey: $providerKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(providerKey, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderRow &&
          other.providerKey == this.providerKey &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class ProviderRowsCompanion extends UpdateCompanion<ProviderRow> {
  final Value<String> providerKey;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderRowsCompanion({
    this.providerKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderRowsCompanion.insert({
    required String providerKey,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : providerKey = Value(providerKey),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<ProviderRow> custom({
    Expression<String>? providerKey,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (providerKey != null) 'provider_key': providerKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderRowsCompanion copyWith({
    Value<String>? providerKey,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderRowsCompanion(
      providerKey: providerKey ?? this.providerKey,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (providerKey.present) {
      map['provider_key'] = Variable<String>(providerKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ProviderRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderRowsCompanion(')
          ..write('providerKey: $providerKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderGroupRowsTable extends ProviderGroupRows
    with TableInfo<$ProviderGroupRowsTable, ProviderGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderGroupRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProviderGroupRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_group_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $ProviderGroupRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ProviderGroupRowsTable createAlias(String alias) {
    return $ProviderGroupRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class ProviderGroupRow extends DataClass
    implements Insertable<ProviderGroupRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const ProviderGroupRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $ProviderGroupRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ProviderGroupRowsCompanion toCompanion(bool nullToAbsent) {
    return ProviderGroupRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderGroupRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderGroupRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => ProviderGroupRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderGroupRow copyWithCompanion(ProviderGroupRowsCompanion data) {
    return ProviderGroupRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderGroupRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderGroupRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class ProviderGroupRowsCompanion extends UpdateCompanion<ProviderGroupRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderGroupRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderGroupRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<ProviderGroupRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderGroupRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderGroupRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ProviderGroupRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderGroupRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $McpServerRowsTable extends McpServerRows
    with TableInfo<$McpServerRowsTable, McpServerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McpServerRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($McpServerRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mcp_server_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<McpServerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McpServerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McpServerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $McpServerRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $McpServerRowsTable createAlias(String alias) {
    return $McpServerRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class McpServerRow extends DataClass implements Insertable<McpServerRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const McpServerRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $McpServerRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  McpServerRowsCompanion toCompanion(bool nullToAbsent) {
    return McpServerRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory McpServerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McpServerRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  McpServerRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => McpServerRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  McpServerRow copyWithCompanion(McpServerRowsCompanion data) {
    return McpServerRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McpServerRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpServerRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class McpServerRowsCompanion extends UpdateCompanion<McpServerRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const McpServerRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  McpServerRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<McpServerRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  McpServerRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return McpServerRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $McpServerRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McpServerRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorldBookRowsTable extends WorldBookRows
    with TableInfo<$WorldBookRowsTable, WorldBookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorldBookRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($WorldBookRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'world_book_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorldBookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorldBookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorldBookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $WorldBookRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $WorldBookRowsTable createAlias(String alias) {
    return $WorldBookRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class WorldBookRow extends DataClass implements Insertable<WorldBookRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const WorldBookRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $WorldBookRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  WorldBookRowsCompanion toCompanion(bool nullToAbsent) {
    return WorldBookRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorldBookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorldBookRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorldBookRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => WorldBookRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorldBookRow copyWithCompanion(WorldBookRowsCompanion data) {
    return WorldBookRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorldBookRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorldBookRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class WorldBookRowsCompanion extends UpdateCompanion<WorldBookRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorldBookRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorldBookRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<WorldBookRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorldBookRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorldBookRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $WorldBookRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorldBookRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantMemoryRowsTable extends AssistantMemoryRows
    with TableInfo<$AssistantMemoryRowsTable, AssistantMemoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantMemoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assistantIdMeta = const VerificationMeta(
    'assistantId',
  );
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
    'assistant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AssistantMemoryRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sortOrder,
    assistantId,
    payload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_memory_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantMemoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
        _assistantIdMeta,
        assistantId.isAcceptableOrUnknown(
          data['assistant_id']!,
          _assistantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assistantIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantMemoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantMemoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $AssistantMemoryRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $AssistantMemoryRowsTable createAlias(String alias) {
    return $AssistantMemoryRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class AssistantMemoryRow extends DataClass
    implements Insertable<AssistantMemoryRow> {
  final String id;
  final int sortOrder;
  final String assistantId;
  final String payload;
  final DateTime updatedAt;
  const AssistantMemoryRow({
    required this.id,
    required this.sortOrder,
    required this.assistantId,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['assistant_id'] = Variable<String>(assistantId);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $AssistantMemoryRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  AssistantMemoryRowsCompanion toCompanion(bool nullToAbsent) {
    return AssistantMemoryRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      assistantId: Value(assistantId),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory AssistantMemoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantMemoryRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      assistantId: serializer.fromJson<String>(json['assistantId']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'assistantId': serializer.toJson<String>(assistantId),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssistantMemoryRow copyWith({
    String? id,
    int? sortOrder,
    String? assistantId,
    String? payload,
    DateTime? updatedAt,
  }) => AssistantMemoryRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    assistantId: assistantId ?? this.assistantId,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AssistantMemoryRow copyWithCompanion(AssistantMemoryRowsCompanion data) {
    return AssistantMemoryRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantMemoryRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('assistantId: $assistantId, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sortOrder, assistantId, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMemoryRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.assistantId == this.assistantId &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class AssistantMemoryRowsCompanion extends UpdateCompanion<AssistantMemoryRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> assistantId;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AssistantMemoryRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantMemoryRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String assistantId,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       assistantId = Value(assistantId),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<AssistantMemoryRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? assistantId,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (assistantId != null) 'assistant_id': assistantId,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantMemoryRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? assistantId,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AssistantMemoryRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      assistantId: assistantId ?? this.assistantId,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $AssistantMemoryRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantMemoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('assistantId: $assistantId, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuickPhraseRowsTable extends QuickPhraseRows
    with TableInfo<$QuickPhraseRowsTable, QuickPhraseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuickPhraseRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($QuickPhraseRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quick_phrase_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuickPhraseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuickPhraseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuickPhraseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $QuickPhraseRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $QuickPhraseRowsTable createAlias(String alias) {
    return $QuickPhraseRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class QuickPhraseRow extends DataClass implements Insertable<QuickPhraseRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const QuickPhraseRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $QuickPhraseRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  QuickPhraseRowsCompanion toCompanion(bool nullToAbsent) {
    return QuickPhraseRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory QuickPhraseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuickPhraseRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  QuickPhraseRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => QuickPhraseRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  QuickPhraseRow copyWithCompanion(QuickPhraseRowsCompanion data) {
    return QuickPhraseRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuickPhraseRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuickPhraseRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class QuickPhraseRowsCompanion extends UpdateCompanion<QuickPhraseRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const QuickPhraseRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuickPhraseRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<QuickPhraseRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuickPhraseRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return QuickPhraseRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $QuickPhraseRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuickPhraseRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchServiceRowsTable extends SearchServiceRows
    with TableInfo<$SearchServiceRowsTable, SearchServiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchServiceRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SearchServiceRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_service_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchServiceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchServiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchServiceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $SearchServiceRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $SearchServiceRowsTable createAlias(String alias) {
    return $SearchServiceRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class SearchServiceRow extends DataClass
    implements Insertable<SearchServiceRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const SearchServiceRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $SearchServiceRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  SearchServiceRowsCompanion toCompanion(bool nullToAbsent) {
    return SearchServiceRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory SearchServiceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchServiceRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SearchServiceRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => SearchServiceRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SearchServiceRow copyWithCompanion(SearchServiceRowsCompanion data) {
    return SearchServiceRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchServiceRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchServiceRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class SearchServiceRowsCompanion extends UpdateCompanion<SearchServiceRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SearchServiceRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchServiceRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<SearchServiceRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchServiceRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SearchServiceRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $SearchServiceRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchServiceRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TtsServiceRowsTable extends TtsServiceRows
    with TableInfo<$TtsServiceRowsTable, TtsServiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TtsServiceRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TtsServiceRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tts_service_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<TtsServiceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TtsServiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TtsServiceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $TtsServiceRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $TtsServiceRowsTable createAlias(String alias) {
    return $TtsServiceRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class TtsServiceRow extends DataClass implements Insertable<TtsServiceRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const TtsServiceRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $TtsServiceRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  TtsServiceRowsCompanion toCompanion(bool nullToAbsent) {
    return TtsServiceRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory TtsServiceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TtsServiceRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TtsServiceRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => TtsServiceRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TtsServiceRow copyWithCompanion(TtsServiceRowsCompanion data) {
    return TtsServiceRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TtsServiceRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsServiceRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class TtsServiceRowsCompanion extends UpdateCompanion<TtsServiceRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TtsServiceRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TtsServiceRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<TtsServiceRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TtsServiceRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TtsServiceRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $TtsServiceRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TtsServiceRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstructionInjectionRowsTable extends InstructionInjectionRows
    with TableInfo<$InstructionInjectionRowsTable, InstructionInjectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstructionInjectionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>(
        $InstructionInjectionRowsTable.$converterupdatedAt,
      );
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'instruction_injection_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstructionInjectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstructionInjectionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstructionInjectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $InstructionInjectionRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $InstructionInjectionRowsTable createAlias(String alias) {
    return $InstructionInjectionRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class InstructionInjectionRow extends DataClass
    implements Insertable<InstructionInjectionRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const InstructionInjectionRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $InstructionInjectionRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  InstructionInjectionRowsCompanion toCompanion(bool nullToAbsent) {
    return InstructionInjectionRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory InstructionInjectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstructionInjectionRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InstructionInjectionRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => InstructionInjectionRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InstructionInjectionRow copyWithCompanion(
    InstructionInjectionRowsCompanion data,
  ) {
    return InstructionInjectionRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstructionInjectionRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstructionInjectionRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class InstructionInjectionRowsCompanion
    extends UpdateCompanion<InstructionInjectionRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InstructionInjectionRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstructionInjectionRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<InstructionInjectionRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstructionInjectionRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InstructionInjectionRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $InstructionInjectionRowsTable.$converterupdatedAt.toSql(
          updatedAt.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstructionInjectionRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantTagRowsTable extends AssistantTagRows
    with TableInfo<$AssistantTagRowsTable, AssistantTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantTagRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => ComparableExpr(sortOrder).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AssistantTagRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_tag_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantTagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: $AssistantTagRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $AssistantTagRowsTable createAlias(String alias) {
    return $AssistantTagRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class AssistantTagRow extends DataClass implements Insertable<AssistantTagRow> {
  final String id;
  final int sortOrder;
  final String payload;
  final DateTime updatedAt;
  const AssistantTagRow({
    required this.id,
    required this.sortOrder,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    map['payload'] = Variable<String>(payload);
    {
      map['updated_at'] = Variable<int>(
        $AssistantTagRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  AssistantTagRowsCompanion toCompanion(bool nullToAbsent) {
    return AssistantTagRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory AssistantTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantTagRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssistantTagRow copyWith({
    String? id,
    int? sortOrder,
    String? payload,
    DateTime? updatedAt,
  }) => AssistantTagRow(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AssistantTagRow copyWithCompanion(AssistantTagRowsCompanion data) {
    return AssistantTagRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantTagRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantTagRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class AssistantTagRowsCompanion extends UpdateCompanion<AssistantTagRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AssistantTagRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantTagRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<AssistantTagRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantTagRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AssistantTagRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      payload: payload ?? this.payload,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $AssistantTagRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantTagRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferenceRowsTable extends PreferenceRows
    with TableInfo<$PreferenceRowsTable, PreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferenceRowsTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PreferenceRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preference_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferenceRow> instance, {
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
  PreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferenceRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: $PreferenceRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $PreferenceRowsTable createAlias(String alias) {
    return $PreferenceRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MicrosecondDateTimeConverter();
}

class PreferenceRow extends DataClass implements Insertable<PreferenceRow> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const PreferenceRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    {
      map['updated_at'] = Variable<int>(
        $PreferenceRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  PreferenceRowsCompanion toCompanion(bool nullToAbsent) {
    return PreferenceRowsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory PreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PreferenceRow copyWith({String? key, String? value, DateTime? updatedAt}) =>
      PreferenceRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PreferenceRow copyWithCompanion(PreferenceRowsCompanion data) {
    return PreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferenceRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class PreferenceRowsCompanion extends UpdateCompanion<PreferenceRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PreferenceRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferenceRowsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<PreferenceRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferenceRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PreferenceRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $PreferenceRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $ConversationMcpServerRowsTable conversationMcpServerRows =
      $ConversationMcpServerRowsTable(this);
  late final $ChatStorageMetaRowsTable chatStorageMetaRows =
      $ChatStorageMetaRowsTable(this);
  late final $MessagePartRowsTable messagePartRows = $MessagePartRowsTable(
    this,
  );
  late final $ProviderArtifactRowsTable providerArtifactRows =
      $ProviderArtifactRowsTable(this);
  late final $AssetRowsTable assetRows = $AssetRowsTable(this);
  late final $MessageAssetRowsTable messageAssetRows = $MessageAssetRowsTable(
    this,
  );
  late final $AssetGcRowsTable assetGcRows = $AssetGcRowsTable(this);
  late final $GcAuditRowsTable gcAuditRows = $GcAuditRowsTable(this);
  late final $AssetReferenceDirtyRowsTable assetReferenceDirtyRows =
      $AssetReferenceDirtyRowsTable(this);
  late final $GenerationRunRowsTable generationRunRows =
      $GenerationRunRowsTable(this);
  late final $AssistantRowsTable assistantRows = $AssistantRowsTable(this);
  late final $ProviderRowsTable providerRows = $ProviderRowsTable(this);
  late final $ProviderGroupRowsTable providerGroupRows =
      $ProviderGroupRowsTable(this);
  late final $McpServerRowsTable mcpServerRows = $McpServerRowsTable(this);
  late final $WorldBookRowsTable worldBookRows = $WorldBookRowsTable(this);
  late final $AssistantMemoryRowsTable assistantMemoryRows =
      $AssistantMemoryRowsTable(this);
  late final $QuickPhraseRowsTable quickPhraseRows = $QuickPhraseRowsTable(
    this,
  );
  late final $SearchServiceRowsTable searchServiceRows =
      $SearchServiceRowsTable(this);
  late final $TtsServiceRowsTable ttsServiceRows = $TtsServiceRowsTable(this);
  late final $InstructionInjectionRowsTable instructionInjectionRows =
      $InstructionInjectionRowsTable(this);
  late final $AssistantTagRowsTable assistantTagRows = $AssistantTagRowsTable(
    this,
  );
  late final $PreferenceRowsTable preferenceRows = $PreferenceRowsTable(this);
  late final Index idxConversationsUpdatedAt = Index(
    'idx_conversations_updated_at',
    'CREATE INDEX idx_conversations_updated_at ON conversation_rows (updated_at DESC, id ASC)',
  );
  late final Index idxConversationsAssistant = Index(
    'idx_conversations_assistant',
    'CREATE INDEX idx_conversations_assistant ON conversation_rows (assistant_id)',
  );
  late final Index idxMessagesConversationOrder = Index(
    'idx_messages_conversation_order',
    'CREATE INDEX idx_messages_conversation_order ON message_rows (conversation_id, message_order, id)',
  );
  late final Index idxMessagesConversationTimestamp = Index(
    'idx_messages_conversation_timestamp',
    'CREATE INDEX idx_messages_conversation_timestamp ON message_rows (conversation_id, timestamp, id)',
  );
  late final Index idxMessagesGroup = Index(
    'idx_messages_group',
    'CREATE INDEX idx_messages_group ON message_rows (conversation_id, group_id, version, id)',
  );
  late final Index idxMessagePartsRevisionOrdinal = Index(
    'idx_message_parts_revision_ordinal',
    'CREATE INDEX idx_message_parts_revision_ordinal ON message_part_rows (conversation_id, revision_id, ordinal)',
  );
  late final Index idxProviderArtifactsRevisionKind = Index(
    'idx_provider_artifacts_revision_kind',
    'CREATE INDEX idx_provider_artifacts_revision_kind ON provider_artifact_rows (conversation_id, revision_id, kind)',
  );
  late final Index idxMessageAssetsAsset = Index(
    'idx_message_assets_asset',
    'CREATE INDEX idx_message_assets_asset ON message_asset_rows (asset_id, revision_id)',
  );
  late final Index idxGenerationRunsActiveTarget = Index(
    'idx_generation_runs_active_target',
    'CREATE UNIQUE INDEX idx_generation_runs_active_target ON generation_run_rows (conversation_id, target_revision_id) WHERE state IN (\'preparing\', \'requesting\', \'streaming\', \'waiting_tool\')',
  );
  late final Index idxGenerationRunsStateUpdated = Index(
    'idx_generation_runs_state_updated',
    'CREATE INDEX idx_generation_runs_state_updated ON generation_run_rows (state, updated_at, id)',
  );
  late final Index idxAssistantMemoriesAssistant = Index(
    'idx_assistant_memories_assistant',
    'CREATE INDEX idx_assistant_memories_assistant ON assistant_memory_rows (assistant_id, id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversationRows,
    messageRows,
    conversationMcpServerRows,
    chatStorageMetaRows,
    messagePartRows,
    providerArtifactRows,
    assetRows,
    messageAssetRows,
    assetGcRows,
    gcAuditRows,
    assetReferenceDirtyRows,
    generationRunRows,
    assistantRows,
    providerRows,
    providerGroupRows,
    mcpServerRows,
    worldBookRows,
    assistantMemoryRows,
    quickPhraseRows,
    searchServiceRows,
    ttsServiceRows,
    instructionInjectionRows,
    assistantTagRows,
    preferenceRows,
    idxConversationsUpdatedAt,
    idxConversationsAssistant,
    idxMessagesConversationOrder,
    idxMessagesConversationTimestamp,
    idxMessagesGroup,
    idxMessagePartsRevisionOrdinal,
    idxProviderArtifactsRevisionKind,
    idxMessageAssetsAsset,
    idxGenerationRunsActiveTarget,
    idxGenerationRunsStateUpdated,
    idxAssistantMemoriesAssistant,
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
      result: [TableUpdate('message_asset_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'asset_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_asset_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'asset_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('asset_gc_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'message_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('asset_reference_dirty_rows', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('generation_run_rows', kind: UpdateKind.delete)],
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

  static MultiTypedResultKey<$GenerationRunRowsTable, List<GenerationRunRow>>
  _generationRunRowsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.generationRunRows,
        aliasName:
            'conversation_rows__id__generation_run_rows__conversation_id',
      );

  $$GenerationRunRowsTableProcessedTableManager get generationRunRowsRefs {
    final manager = $$GenerationRunRowsTableTableManager(
      $_db,
      $_db.generationRunRows,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _generationRunRowsRefsTable($_db),
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

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
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

  Expression<bool> generationRunRowsRefs(
    Expression<bool> Function($$GenerationRunRowsTableFilterComposer f) f,
  ) {
    final $$GenerationRunRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.generationRunRows,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GenerationRunRowsTableFilterComposer(
            $db: $db,
            $table: $db.generationRunRows,
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
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

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
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

  Expression<T> generationRunRowsRefs<T extends Object>(
    Expression<T> Function($$GenerationRunRowsTableAnnotationComposer a) f,
  ) {
    final $$GenerationRunRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.generationRunRows,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GenerationRunRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.generationRunRows,
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
            bool generationRunRowsRefs,
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
                generationRunRowsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messageRowsRefs) db.messageRows,
                    if (conversationMcpServerRowsRefs)
                      db.conversationMcpServerRows,
                    if (generationRunRowsRefs) db.generationRunRows,
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
                      if (generationRunRowsRefs)
                        await $_getPrefetchedData<
                          ConversationRow,
                          $ConversationRowsTable,
                          GenerationRunRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationRowsTableReferences
                              ._generationRunRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).generationRunRowsRefs,
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
        bool generationRunRowsRefs,
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

  static MultiTypedResultKey<$MessageAssetRowsTable, List<MessageAssetRow>>
  _messageAssetRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messageAssetRows,
    aliasName: 'message_rows__id__message_asset_rows__revision_id',
  );

  $$MessageAssetRowsTableProcessedTableManager get messageAssetRowsRefs {
    final manager = $$MessageAssetRowsTableTableManager(
      $_db,
      $_db.messageAssetRows,
    ).filter((f) => f.revisionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _messageAssetRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $AssetReferenceDirtyRowsTable,
    List<AssetReferenceDirtyRow>
  >
  _assetReferenceDirtyRowsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.assetReferenceDirtyRows,
        aliasName: 'message_rows__id__asset_reference_dirty_rows__revision_id',
      );

  $$AssetReferenceDirtyRowsTableProcessedTableManager
  get assetReferenceDirtyRowsRefs {
    final manager = $$AssetReferenceDirtyRowsTableTableManager(
      $_db,
      $_db.assetReferenceDirtyRows,
    ).filter((f) => f.revisionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _assetReferenceDirtyRowsRefsTable($_db),
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

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get timestamp =>
      $composableBuilder(
        column: $table.timestamp,
        builder: (column) => ColumnWithTypeConverterFilters(column),
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

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get reasoningStartAt => $composableBuilder(
    column: $table.reasoningStartAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get reasoningFinishedAt => $composableBuilder(
    column: $table.reasoningFinishedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
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

  Expression<bool> messageAssetRowsRefs(
    Expression<bool> Function($$MessageAssetRowsTableFilterComposer f) f,
  ) {
    final $$MessageAssetRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageAssetRows,
      getReferencedColumn: (t) => t.revisionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageAssetRowsTableFilterComposer(
            $db: $db,
            $table: $db.messageAssetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> assetReferenceDirtyRowsRefs(
    Expression<bool> Function($$AssetReferenceDirtyRowsTableFilterComposer f) f,
  ) {
    final $$AssetReferenceDirtyRowsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assetReferenceDirtyRows,
          getReferencedColumn: (t) => t.revisionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssetReferenceDirtyRowsTableFilterComposer(
                $db: $db,
                $table: $db.assetReferenceDirtyRows,
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

  ColumnOrderings<int> get timestamp => $composableBuilder(
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

  ColumnOrderings<int> get reasoningStartAt => $composableBuilder(
    column: $table.reasoningStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reasoningFinishedAt => $composableBuilder(
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

  GeneratedColumnWithTypeConverter<DateTime, int> get timestamp =>
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

  GeneratedColumnWithTypeConverter<DateTime?, int> get reasoningStartAt =>
      $composableBuilder(
        column: $table.reasoningStartAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get reasoningFinishedAt =>
      $composableBuilder(
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

  Expression<T> messageAssetRowsRefs<T extends Object>(
    Expression<T> Function($$MessageAssetRowsTableAnnotationComposer a) f,
  ) {
    final $$MessageAssetRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageAssetRows,
      getReferencedColumn: (t) => t.revisionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageAssetRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.messageAssetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> assetReferenceDirtyRowsRefs<T extends Object>(
    Expression<T> Function($$AssetReferenceDirtyRowsTableAnnotationComposer a)
    f,
  ) {
    final $$AssetReferenceDirtyRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assetReferenceDirtyRows,
          getReferencedColumn: (t) => t.revisionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssetReferenceDirtyRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.assetReferenceDirtyRows,
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
            bool messageAssetRowsRefs,
            bool assetReferenceDirtyRowsRefs,
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
                messageAssetRowsRefs = false,
                assetReferenceDirtyRowsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messageAssetRowsRefs) db.messageAssetRows,
                    if (assetReferenceDirtyRowsRefs) db.assetReferenceDirtyRows,
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
                      if (messageAssetRowsRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessageRowsTable,
                          MessageAssetRow
                        >(
                          currentTable: table,
                          referencedTable: $$MessageRowsTableReferences
                              ._messageAssetRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessageRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).messageAssetRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.revisionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (assetReferenceDirtyRowsRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessageRowsTable,
                          AssetReferenceDirtyRow
                        >(
                          currentTable: table,
                          referencedTable: $$MessageRowsTableReferences
                              ._assetReferenceDirtyRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessageRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).assetReferenceDirtyRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.revisionId == item.id,
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
        bool messageAssetRowsRefs,
        bool assetReferenceDirtyRowsRefs,
      })
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
typedef $$MessagePartRowsTableCreateCompanionBuilder =
    MessagePartRowsCompanion Function({
      required String conversationId,
      required String revisionId,
      required int ordinal,
      required String kind,
      required String payload,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MessagePartRowsTableUpdateCompanionBuilder =
    MessagePartRowsCompanion Function({
      Value<String> conversationId,
      Value<String> revisionId,
      Value<int> ordinal,
      Value<String> kind,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MessagePartRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MessagePartRowsTable> {
  $$MessagePartRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revisionId => $composableBuilder(
    column: $table.revisionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$MessagePartRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagePartRowsTable> {
  $$MessagePartRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revisionId => $composableBuilder(
    column: $table.revisionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagePartRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagePartRowsTable> {
  $$MessagePartRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get revisionId => $composableBuilder(
    column: $table.revisionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MessagePartRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagePartRowsTable,
          MessagePartRow,
          $$MessagePartRowsTableFilterComposer,
          $$MessagePartRowsTableOrderingComposer,
          $$MessagePartRowsTableAnnotationComposer,
          $$MessagePartRowsTableCreateCompanionBuilder,
          $$MessagePartRowsTableUpdateCompanionBuilder,
          (
            MessagePartRow,
            BaseReferences<
              _$AppDatabase,
              $MessagePartRowsTable,
              MessagePartRow
            >,
          ),
          MessagePartRow,
          PrefetchHooks Function()
        > {
  $$MessagePartRowsTableTableManager(
    _$AppDatabase db,
    $MessagePartRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagePartRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagePartRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagePartRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> revisionId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagePartRowsCompanion(
                conversationId: conversationId,
                revisionId: revisionId,
                ordinal: ordinal,
                kind: kind,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String revisionId,
                required int ordinal,
                required String kind,
                required String payload,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagePartRowsCompanion.insert(
                conversationId: conversationId,
                revisionId: revisionId,
                ordinal: ordinal,
                kind: kind,
                payload: payload,
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

typedef $$MessagePartRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagePartRowsTable,
      MessagePartRow,
      $$MessagePartRowsTableFilterComposer,
      $$MessagePartRowsTableOrderingComposer,
      $$MessagePartRowsTableAnnotationComposer,
      $$MessagePartRowsTableCreateCompanionBuilder,
      $$MessagePartRowsTableUpdateCompanionBuilder,
      (
        MessagePartRow,
        BaseReferences<_$AppDatabase, $MessagePartRowsTable, MessagePartRow>,
      ),
      MessagePartRow,
      PrefetchHooks Function()
    >;
typedef $$ProviderArtifactRowsTableCreateCompanionBuilder =
    ProviderArtifactRowsCompanion Function({
      required String conversationId,
      required String revisionId,
      required String kind,
      required String payload,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderArtifactRowsTableUpdateCompanionBuilder =
    ProviderArtifactRowsCompanion Function({
      Value<String> conversationId,
      Value<String> revisionId,
      Value<String> kind,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProviderArtifactRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderArtifactRowsTable> {
  $$ProviderArtifactRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revisionId => $composableBuilder(
    column: $table.revisionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ProviderArtifactRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderArtifactRowsTable> {
  $$ProviderArtifactRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revisionId => $composableBuilder(
    column: $table.revisionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderArtifactRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderArtifactRowsTable> {
  $$ProviderArtifactRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get revisionId => $composableBuilder(
    column: $table.revisionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProviderArtifactRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderArtifactRowsTable,
          ProviderArtifactRow,
          $$ProviderArtifactRowsTableFilterComposer,
          $$ProviderArtifactRowsTableOrderingComposer,
          $$ProviderArtifactRowsTableAnnotationComposer,
          $$ProviderArtifactRowsTableCreateCompanionBuilder,
          $$ProviderArtifactRowsTableUpdateCompanionBuilder,
          (
            ProviderArtifactRow,
            BaseReferences<
              _$AppDatabase,
              $ProviderArtifactRowsTable,
              ProviderArtifactRow
            >,
          ),
          ProviderArtifactRow,
          PrefetchHooks Function()
        > {
  $$ProviderArtifactRowsTableTableManager(
    _$AppDatabase db,
    $ProviderArtifactRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderArtifactRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderArtifactRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProviderArtifactRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> revisionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderArtifactRowsCompanion(
                conversationId: conversationId,
                revisionId: revisionId,
                kind: kind,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String revisionId,
                required String kind,
                required String payload,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderArtifactRowsCompanion.insert(
                conversationId: conversationId,
                revisionId: revisionId,
                kind: kind,
                payload: payload,
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

typedef $$ProviderArtifactRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderArtifactRowsTable,
      ProviderArtifactRow,
      $$ProviderArtifactRowsTableFilterComposer,
      $$ProviderArtifactRowsTableOrderingComposer,
      $$ProviderArtifactRowsTableAnnotationComposer,
      $$ProviderArtifactRowsTableCreateCompanionBuilder,
      $$ProviderArtifactRowsTableUpdateCompanionBuilder,
      (
        ProviderArtifactRow,
        BaseReferences<
          _$AppDatabase,
          $ProviderArtifactRowsTable,
          ProviderArtifactRow
        >,
      ),
      ProviderArtifactRow,
      PrefetchHooks Function()
    >;
typedef $$AssetRowsTableCreateCompanionBuilder =
    AssetRowsCompanion Function({
      required String id,
      required String contentHash,
      required String path,
      required int byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<String?> thumbnailPath,
      required DateTime createdAt,
      required DateTime lastReferencedAt,
      Value<int> rowid,
    });
typedef $$AssetRowsTableUpdateCompanionBuilder =
    AssetRowsCompanion Function({
      Value<String> id,
      Value<String> contentHash,
      Value<String> path,
      Value<int> byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<String?> thumbnailPath,
      Value<DateTime> createdAt,
      Value<DateTime> lastReferencedAt,
      Value<int> rowid,
    });

final class $$AssetRowsTableReferences
    extends BaseReferences<_$AppDatabase, $AssetRowsTable, AssetRow> {
  $$AssetRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MessageAssetRowsTable, List<MessageAssetRow>>
  _messageAssetRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messageAssetRows,
    aliasName: 'asset_rows__id__message_asset_rows__asset_id',
  );

  $$MessageAssetRowsTableProcessedTableManager get messageAssetRowsRefs {
    final manager = $$MessageAssetRowsTableTableManager(
      $_db,
      $_db.messageAssetRows,
    ).filter((f) => f.assetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _messageAssetRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AssetGcRowsTable, List<AssetGcRow>>
  _assetGcRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.assetGcRows,
    aliasName: 'asset_rows__id__asset_gc_rows__asset_id',
  );

  $$AssetGcRowsTableProcessedTableManager get assetGcRowsRefs {
    final manager = $$AssetGcRowsTableTableManager(
      $_db,
      $_db.assetGcRows,
    ).filter((f) => f.assetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_assetGcRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AssetRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetRowsTable> {
  $$AssetRowsTableFilterComposer({
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

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int>
  get lastReferencedAt => $composableBuilder(
    column: $table.lastReferencedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  Expression<bool> messageAssetRowsRefs(
    Expression<bool> Function($$MessageAssetRowsTableFilterComposer f) f,
  ) {
    final $$MessageAssetRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageAssetRows,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageAssetRowsTableFilterComposer(
            $db: $db,
            $table: $db.messageAssetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> assetGcRowsRefs(
    Expression<bool> Function($$AssetGcRowsTableFilterComposer f) f,
  ) {
    final $$AssetGcRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assetGcRows,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetGcRowsTableFilterComposer(
            $db: $db,
            $table: $db.assetGcRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AssetRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetRowsTable> {
  $$AssetRowsTableOrderingComposer({
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

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReferencedAt => $composableBuilder(
    column: $table.lastReferencedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssetRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetRowsTable> {
  $$AssetRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get lastReferencedAt =>
      $composableBuilder(
        column: $table.lastReferencedAt,
        builder: (column) => column,
      );

  Expression<T> messageAssetRowsRefs<T extends Object>(
    Expression<T> Function($$MessageAssetRowsTableAnnotationComposer a) f,
  ) {
    final $$MessageAssetRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageAssetRows,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageAssetRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.messageAssetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> assetGcRowsRefs<T extends Object>(
    Expression<T> Function($$AssetGcRowsTableAnnotationComposer a) f,
  ) {
    final $$AssetGcRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assetGcRows,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetGcRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.assetGcRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AssetRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetRowsTable,
          AssetRow,
          $$AssetRowsTableFilterComposer,
          $$AssetRowsTableOrderingComposer,
          $$AssetRowsTableAnnotationComposer,
          $$AssetRowsTableCreateCompanionBuilder,
          $$AssetRowsTableUpdateCompanionBuilder,
          (AssetRow, $$AssetRowsTableReferences),
          AssetRow,
          PrefetchHooks Function({
            bool messageAssetRowsRefs,
            bool assetGcRowsRefs,
          })
        > {
  $$AssetRowsTableTableManager(_$AppDatabase db, $AssetRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastReferencedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetRowsCompanion(
                id: id,
                contentHash: contentHash,
                path: path,
                byteSize: byteSize,
                width: width,
                height: height,
                thumbnailPath: thumbnailPath,
                createdAt: createdAt,
                lastReferencedAt: lastReferencedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String contentHash,
                required String path,
                required int byteSize,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastReferencedAt,
                Value<int> rowid = const Value.absent(),
              }) => AssetRowsCompanion.insert(
                id: id,
                contentHash: contentHash,
                path: path,
                byteSize: byteSize,
                width: width,
                height: height,
                thumbnailPath: thumbnailPath,
                createdAt: createdAt,
                lastReferencedAt: lastReferencedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssetRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({messageAssetRowsRefs = false, assetGcRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messageAssetRowsRefs) db.messageAssetRows,
                    if (assetGcRowsRefs) db.assetGcRows,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messageAssetRowsRefs)
                        await $_getPrefetchedData<
                          AssetRow,
                          $AssetRowsTable,
                          MessageAssetRow
                        >(
                          currentTable: table,
                          referencedTable: $$AssetRowsTableReferences
                              ._messageAssetRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AssetRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).messageAssetRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (assetGcRowsRefs)
                        await $_getPrefetchedData<
                          AssetRow,
                          $AssetRowsTable,
                          AssetGcRow
                        >(
                          currentTable: table,
                          referencedTable: $$AssetRowsTableReferences
                              ._assetGcRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AssetRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).assetGcRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.id,
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

typedef $$AssetRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetRowsTable,
      AssetRow,
      $$AssetRowsTableFilterComposer,
      $$AssetRowsTableOrderingComposer,
      $$AssetRowsTableAnnotationComposer,
      $$AssetRowsTableCreateCompanionBuilder,
      $$AssetRowsTableUpdateCompanionBuilder,
      (AssetRow, $$AssetRowsTableReferences),
      AssetRow,
      PrefetchHooks Function({bool messageAssetRowsRefs, bool assetGcRowsRefs})
    >;
typedef $$MessageAssetRowsTableCreateCompanionBuilder =
    MessageAssetRowsCompanion Function({
      required String conversationId,
      required String revisionId,
      required String assetId,
      required String kind,
      Value<int> rowid,
    });
typedef $$MessageAssetRowsTableUpdateCompanionBuilder =
    MessageAssetRowsCompanion Function({
      Value<String> conversationId,
      Value<String> revisionId,
      Value<String> assetId,
      Value<String> kind,
      Value<int> rowid,
    });

final class $$MessageAssetRowsTableReferences
    extends
        BaseReferences<_$AppDatabase, $MessageAssetRowsTable, MessageAssetRow> {
  $$MessageAssetRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessageRowsTable _revisionIdTable(_$AppDatabase db) => db.messageRows
      .createAlias('message_asset_rows__revision_id__message_rows__id');

  $$MessageRowsTableProcessedTableManager get revisionId {
    final $_column = $_itemColumn<String>('revision_id')!;

    final manager = $$MessageRowsTableTableManager(
      $_db,
      $_db.messageRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_revisionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AssetRowsTable _assetIdTable(_$AppDatabase db) =>
      db.assetRows.createAlias('message_asset_rows__asset_id__asset_rows__id');

  $$AssetRowsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<String>('asset_id')!;

    final manager = $$AssetRowsTableTableManager(
      $_db,
      $_db.assetRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessageAssetRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageAssetRowsTable> {
  $$MessageAssetRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  $$MessageRowsTableFilterComposer get revisionId {
    final $$MessageRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.revisionId,
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

  $$AssetRowsTableFilterComposer get assetId {
    final $$AssetRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assetRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetRowsTableFilterComposer(
            $db: $db,
            $table: $db.assetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageAssetRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageAssetRowsTable> {
  $$MessageAssetRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessageRowsTableOrderingComposer get revisionId {
    final $$MessageRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.revisionId,
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

  $$AssetRowsTableOrderingComposer get assetId {
    final $$AssetRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assetRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetRowsTableOrderingComposer(
            $db: $db,
            $table: $db.assetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageAssetRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageAssetRowsTable> {
  $$MessageAssetRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  $$MessageRowsTableAnnotationComposer get revisionId {
    final $$MessageRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.revisionId,
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

  $$AssetRowsTableAnnotationComposer get assetId {
    final $$AssetRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assetRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.assetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageAssetRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageAssetRowsTable,
          MessageAssetRow,
          $$MessageAssetRowsTableFilterComposer,
          $$MessageAssetRowsTableOrderingComposer,
          $$MessageAssetRowsTableAnnotationComposer,
          $$MessageAssetRowsTableCreateCompanionBuilder,
          $$MessageAssetRowsTableUpdateCompanionBuilder,
          (MessageAssetRow, $$MessageAssetRowsTableReferences),
          MessageAssetRow,
          PrefetchHooks Function({bool revisionId, bool assetId})
        > {
  $$MessageAssetRowsTableTableManager(
    _$AppDatabase db,
    $MessageAssetRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageAssetRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageAssetRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageAssetRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> revisionId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageAssetRowsCompanion(
                conversationId: conversationId,
                revisionId: revisionId,
                assetId: assetId,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String revisionId,
                required String assetId,
                required String kind,
                Value<int> rowid = const Value.absent(),
              }) => MessageAssetRowsCompanion.insert(
                conversationId: conversationId,
                revisionId: revisionId,
                assetId: assetId,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessageAssetRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({revisionId = false, assetId = false}) {
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
                    if (revisionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.revisionId,
                                referencedTable:
                                    $$MessageAssetRowsTableReferences
                                        ._revisionIdTable(db),
                                referencedColumn:
                                    $$MessageAssetRowsTableReferences
                                        ._revisionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable:
                                    $$MessageAssetRowsTableReferences
                                        ._assetIdTable(db),
                                referencedColumn:
                                    $$MessageAssetRowsTableReferences
                                        ._assetIdTable(db)
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

typedef $$MessageAssetRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageAssetRowsTable,
      MessageAssetRow,
      $$MessageAssetRowsTableFilterComposer,
      $$MessageAssetRowsTableOrderingComposer,
      $$MessageAssetRowsTableAnnotationComposer,
      $$MessageAssetRowsTableCreateCompanionBuilder,
      $$MessageAssetRowsTableUpdateCompanionBuilder,
      (MessageAssetRow, $$MessageAssetRowsTableReferences),
      MessageAssetRow,
      PrefetchHooks Function({bool revisionId, bool assetId})
    >;
typedef $$AssetGcRowsTableCreateCompanionBuilder =
    AssetGcRowsCompanion Function({
      required String assetId,
      required DateTime notBefore,
      Value<int> attempts,
      Value<int> generation,
      Value<int> rowid,
    });
typedef $$AssetGcRowsTableUpdateCompanionBuilder =
    AssetGcRowsCompanion Function({
      Value<String> assetId,
      Value<DateTime> notBefore,
      Value<int> attempts,
      Value<int> generation,
      Value<int> rowid,
    });

final class $$AssetGcRowsTableReferences
    extends BaseReferences<_$AppDatabase, $AssetGcRowsTable, AssetGcRow> {
  $$AssetGcRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AssetRowsTable _assetIdTable(_$AppDatabase db) =>
      db.assetRows.createAlias('asset_gc_rows__asset_id__asset_rows__id');

  $$AssetRowsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<String>('asset_id')!;

    final manager = $$AssetRowsTableTableManager(
      $_db,
      $_db.assetRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssetGcRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetGcRowsTable> {
  $$AssetGcRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get notBefore =>
      $composableBuilder(
        column: $table.notBefore,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  $$AssetRowsTableFilterComposer get assetId {
    final $$AssetRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assetRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetRowsTableFilterComposer(
            $db: $db,
            $table: $db.assetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetGcRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetGcRowsTable> {
  $$AssetGcRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get notBefore => $composableBuilder(
    column: $table.notBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  $$AssetRowsTableOrderingComposer get assetId {
    final $$AssetRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assetRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetRowsTableOrderingComposer(
            $db: $db,
            $table: $db.assetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetGcRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetGcRowsTable> {
  $$AssetGcRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get notBefore =>
      $composableBuilder(column: $table.notBefore, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  $$AssetRowsTableAnnotationComposer get assetId {
    final $$AssetRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assetRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.assetRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetGcRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetGcRowsTable,
          AssetGcRow,
          $$AssetGcRowsTableFilterComposer,
          $$AssetGcRowsTableOrderingComposer,
          $$AssetGcRowsTableAnnotationComposer,
          $$AssetGcRowsTableCreateCompanionBuilder,
          $$AssetGcRowsTableUpdateCompanionBuilder,
          (AssetGcRow, $$AssetGcRowsTableReferences),
          AssetGcRow,
          PrefetchHooks Function({bool assetId})
        > {
  $$AssetGcRowsTableTableManager(_$AppDatabase db, $AssetGcRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetGcRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetGcRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetGcRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<DateTime> notBefore = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetGcRowsCompanion(
                assetId: assetId,
                notBefore: notBefore,
                attempts: attempts,
                generation: generation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required DateTime notBefore,
                Value<int> attempts = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetGcRowsCompanion.insert(
                assetId: assetId,
                notBefore: notBefore,
                attempts: attempts,
                generation: generation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssetGcRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
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
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable: $$AssetGcRowsTableReferences
                                    ._assetIdTable(db),
                                referencedColumn: $$AssetGcRowsTableReferences
                                    ._assetIdTable(db)
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

typedef $$AssetGcRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetGcRowsTable,
      AssetGcRow,
      $$AssetGcRowsTableFilterComposer,
      $$AssetGcRowsTableOrderingComposer,
      $$AssetGcRowsTableAnnotationComposer,
      $$AssetGcRowsTableCreateCompanionBuilder,
      $$AssetGcRowsTableUpdateCompanionBuilder,
      (AssetGcRow, $$AssetGcRowsTableReferences),
      AssetGcRow,
      PrefetchHooks Function({bool assetId})
    >;
typedef $$GcAuditRowsTableCreateCompanionBuilder =
    GcAuditRowsCompanion Function({
      Value<int> id,
      required String kind,
      required String entityId,
      required DateTime completedAt,
    });
typedef $$GcAuditRowsTableUpdateCompanionBuilder =
    GcAuditRowsCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> entityId,
      Value<DateTime> completedAt,
    });

class $$GcAuditRowsTableFilterComposer
    extends Composer<_$AppDatabase, $GcAuditRowsTable> {
  $$GcAuditRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get completedAt =>
      $composableBuilder(
        column: $table.completedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$GcAuditRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $GcAuditRowsTable> {
  $$GcAuditRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GcAuditRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GcAuditRowsTable> {
  $$GcAuditRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get completedAt =>
      $composableBuilder(
        column: $table.completedAt,
        builder: (column) => column,
      );
}

class $$GcAuditRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GcAuditRowsTable,
          GcAuditRow,
          $$GcAuditRowsTableFilterComposer,
          $$GcAuditRowsTableOrderingComposer,
          $$GcAuditRowsTableAnnotationComposer,
          $$GcAuditRowsTableCreateCompanionBuilder,
          $$GcAuditRowsTableUpdateCompanionBuilder,
          (
            GcAuditRow,
            BaseReferences<_$AppDatabase, $GcAuditRowsTable, GcAuditRow>,
          ),
          GcAuditRow,
          PrefetchHooks Function()
        > {
  $$GcAuditRowsTableTableManager(_$AppDatabase db, $GcAuditRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GcAuditRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GcAuditRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GcAuditRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
              }) => GcAuditRowsCompanion(
                id: id,
                kind: kind,
                entityId: entityId,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String entityId,
                required DateTime completedAt,
              }) => GcAuditRowsCompanion.insert(
                id: id,
                kind: kind,
                entityId: entityId,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GcAuditRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GcAuditRowsTable,
      GcAuditRow,
      $$GcAuditRowsTableFilterComposer,
      $$GcAuditRowsTableOrderingComposer,
      $$GcAuditRowsTableAnnotationComposer,
      $$GcAuditRowsTableCreateCompanionBuilder,
      $$GcAuditRowsTableUpdateCompanionBuilder,
      (
        GcAuditRow,
        BaseReferences<_$AppDatabase, $GcAuditRowsTable, GcAuditRow>,
      ),
      GcAuditRow,
      PrefetchHooks Function()
    >;
typedef $$AssetReferenceDirtyRowsTableCreateCompanionBuilder =
    AssetReferenceDirtyRowsCompanion Function({
      required String revisionId,
      Value<int> rowid,
    });
typedef $$AssetReferenceDirtyRowsTableUpdateCompanionBuilder =
    AssetReferenceDirtyRowsCompanion Function({
      Value<String> revisionId,
      Value<int> rowid,
    });

final class $$AssetReferenceDirtyRowsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AssetReferenceDirtyRowsTable,
          AssetReferenceDirtyRow
        > {
  $$AssetReferenceDirtyRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessageRowsTable _revisionIdTable(_$AppDatabase db) => db.messageRows
      .createAlias('asset_reference_dirty_rows__revision_id__message_rows__id');

  $$MessageRowsTableProcessedTableManager get revisionId {
    final $_column = $_itemColumn<String>('revision_id')!;

    final manager = $$MessageRowsTableTableManager(
      $_db,
      $_db.messageRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_revisionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssetReferenceDirtyRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetReferenceDirtyRowsTable> {
  $$AssetReferenceDirtyRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MessageRowsTableFilterComposer get revisionId {
    final $$MessageRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.revisionId,
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

class $$AssetReferenceDirtyRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetReferenceDirtyRowsTable> {
  $$AssetReferenceDirtyRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MessageRowsTableOrderingComposer get revisionId {
    final $$MessageRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.revisionId,
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

class $$AssetReferenceDirtyRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetReferenceDirtyRowsTable> {
  $$AssetReferenceDirtyRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MessageRowsTableAnnotationComposer get revisionId {
    final $$MessageRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.revisionId,
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

class $$AssetReferenceDirtyRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetReferenceDirtyRowsTable,
          AssetReferenceDirtyRow,
          $$AssetReferenceDirtyRowsTableFilterComposer,
          $$AssetReferenceDirtyRowsTableOrderingComposer,
          $$AssetReferenceDirtyRowsTableAnnotationComposer,
          $$AssetReferenceDirtyRowsTableCreateCompanionBuilder,
          $$AssetReferenceDirtyRowsTableUpdateCompanionBuilder,
          (AssetReferenceDirtyRow, $$AssetReferenceDirtyRowsTableReferences),
          AssetReferenceDirtyRow,
          PrefetchHooks Function({bool revisionId})
        > {
  $$AssetReferenceDirtyRowsTableTableManager(
    _$AppDatabase db,
    $AssetReferenceDirtyRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetReferenceDirtyRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AssetReferenceDirtyRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AssetReferenceDirtyRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> revisionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetReferenceDirtyRowsCompanion(
                revisionId: revisionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String revisionId,
                Value<int> rowid = const Value.absent(),
              }) => AssetReferenceDirtyRowsCompanion.insert(
                revisionId: revisionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssetReferenceDirtyRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({revisionId = false}) {
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
                    if (revisionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.revisionId,
                                referencedTable:
                                    $$AssetReferenceDirtyRowsTableReferences
                                        ._revisionIdTable(db),
                                referencedColumn:
                                    $$AssetReferenceDirtyRowsTableReferences
                                        ._revisionIdTable(db)
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

typedef $$AssetReferenceDirtyRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetReferenceDirtyRowsTable,
      AssetReferenceDirtyRow,
      $$AssetReferenceDirtyRowsTableFilterComposer,
      $$AssetReferenceDirtyRowsTableOrderingComposer,
      $$AssetReferenceDirtyRowsTableAnnotationComposer,
      $$AssetReferenceDirtyRowsTableCreateCompanionBuilder,
      $$AssetReferenceDirtyRowsTableUpdateCompanionBuilder,
      (AssetReferenceDirtyRow, $$AssetReferenceDirtyRowsTableReferences),
      AssetReferenceDirtyRow,
      PrefetchHooks Function({bool revisionId})
    >;
typedef $$GenerationRunRowsTableCreateCompanionBuilder =
    GenerationRunRowsCompanion Function({
      required String id,
      required String conversationId,
      required String targetRevisionId,
      required String state,
      Value<int> stateRevision,
      Value<int> checkpointSeq,
      Value<String?> errorCode,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> terminalAt,
      Value<int> rowid,
    });
typedef $$GenerationRunRowsTableUpdateCompanionBuilder =
    GenerationRunRowsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> targetRevisionId,
      Value<String> state,
      Value<int> stateRevision,
      Value<int> checkpointSeq,
      Value<String?> errorCode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> terminalAt,
      Value<int> rowid,
    });

final class $$GenerationRunRowsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GenerationRunRowsTable,
          GenerationRunRow
        > {
  $$GenerationRunRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationRowsTable _conversationIdTable(_$AppDatabase db) =>
      db.conversationRows.createAlias(
        'generation_run_rows__conversation_id__conversation_rows__id',
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

class $$GenerationRunRowsTableFilterComposer
    extends Composer<_$AppDatabase, $GenerationRunRowsTable> {
  $$GenerationRunRowsTableFilterComposer({
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

  ColumnFilters<String> get targetRevisionId => $composableBuilder(
    column: $table.targetRevisionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stateRevision => $composableBuilder(
    column: $table.stateRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkpointSeq => $composableBuilder(
    column: $table.checkpointSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get terminalAt =>
      $composableBuilder(
        column: $table.terminalAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
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

class $$GenerationRunRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $GenerationRunRowsTable> {
  $$GenerationRunRowsTableOrderingComposer({
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

  ColumnOrderings<String> get targetRevisionId => $composableBuilder(
    column: $table.targetRevisionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stateRevision => $composableBuilder(
    column: $table.stateRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkpointSeq => $composableBuilder(
    column: $table.checkpointSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get terminalAt => $composableBuilder(
    column: $table.terminalAt,
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

class $$GenerationRunRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GenerationRunRowsTable> {
  $$GenerationRunRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetRevisionId => $composableBuilder(
    column: $table.targetRevisionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get stateRevision => $composableBuilder(
    column: $table.stateRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get checkpointSeq => $composableBuilder(
    column: $table.checkpointSeq,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get terminalAt =>
      $composableBuilder(
        column: $table.terminalAt,
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
}

class $$GenerationRunRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GenerationRunRowsTable,
          GenerationRunRow,
          $$GenerationRunRowsTableFilterComposer,
          $$GenerationRunRowsTableOrderingComposer,
          $$GenerationRunRowsTableAnnotationComposer,
          $$GenerationRunRowsTableCreateCompanionBuilder,
          $$GenerationRunRowsTableUpdateCompanionBuilder,
          (GenerationRunRow, $$GenerationRunRowsTableReferences),
          GenerationRunRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$GenerationRunRowsTableTableManager(
    _$AppDatabase db,
    $GenerationRunRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GenerationRunRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GenerationRunRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GenerationRunRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> targetRevisionId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> stateRevision = const Value.absent(),
                Value<int> checkpointSeq = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> terminalAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationRunRowsCompanion(
                id: id,
                conversationId: conversationId,
                targetRevisionId: targetRevisionId,
                state: state,
                stateRevision: stateRevision,
                checkpointSeq: checkpointSeq,
                errorCode: errorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                terminalAt: terminalAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String targetRevisionId,
                required String state,
                Value<int> stateRevision = const Value.absent(),
                Value<int> checkpointSeq = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> terminalAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationRunRowsCompanion.insert(
                id: id,
                conversationId: conversationId,
                targetRevisionId: targetRevisionId,
                state: state,
                stateRevision: stateRevision,
                checkpointSeq: checkpointSeq,
                errorCode: errorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                terminalAt: terminalAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GenerationRunRowsTableReferences(db, table, e),
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
                                    $$GenerationRunRowsTableReferences
                                        ._conversationIdTable(db),
                                referencedColumn:
                                    $$GenerationRunRowsTableReferences
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

typedef $$GenerationRunRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GenerationRunRowsTable,
      GenerationRunRow,
      $$GenerationRunRowsTableFilterComposer,
      $$GenerationRunRowsTableOrderingComposer,
      $$GenerationRunRowsTableAnnotationComposer,
      $$GenerationRunRowsTableCreateCompanionBuilder,
      $$GenerationRunRowsTableUpdateCompanionBuilder,
      (GenerationRunRow, $$GenerationRunRowsTableReferences),
      GenerationRunRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$AssistantRowsTableCreateCompanionBuilder =
    AssistantRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AssistantRowsTableUpdateCompanionBuilder =
    AssistantRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
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
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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
typedef $$ProviderRowsTableCreateCompanionBuilder =
    ProviderRowsCompanion Function({
      required String providerKey,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderRowsTableUpdateCompanionBuilder =
    ProviderRowsCompanion Function({
      Value<String> providerKey,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProviderRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderRowsTable> {
  $$ProviderRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get providerKey => $composableBuilder(
    column: $table.providerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ProviderRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderRowsTable> {
  $$ProviderRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get providerKey => $composableBuilder(
    column: $table.providerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderRowsTable> {
  $$ProviderRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get providerKey => $composableBuilder(
    column: $table.providerKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProviderRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderRowsTable,
          ProviderRow,
          $$ProviderRowsTableFilterComposer,
          $$ProviderRowsTableOrderingComposer,
          $$ProviderRowsTableAnnotationComposer,
          $$ProviderRowsTableCreateCompanionBuilder,
          $$ProviderRowsTableUpdateCompanionBuilder,
          (
            ProviderRow,
            BaseReferences<_$AppDatabase, $ProviderRowsTable, ProviderRow>,
          ),
          ProviderRow,
          PrefetchHooks Function()
        > {
  $$ProviderRowsTableTableManager(_$AppDatabase db, $ProviderRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> providerKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderRowsCompanion(
                providerKey: providerKey,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String providerKey,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderRowsCompanion.insert(
                providerKey: providerKey,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$ProviderRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderRowsTable,
      ProviderRow,
      $$ProviderRowsTableFilterComposer,
      $$ProviderRowsTableOrderingComposer,
      $$ProviderRowsTableAnnotationComposer,
      $$ProviderRowsTableCreateCompanionBuilder,
      $$ProviderRowsTableUpdateCompanionBuilder,
      (
        ProviderRow,
        BaseReferences<_$AppDatabase, $ProviderRowsTable, ProviderRow>,
      ),
      ProviderRow,
      PrefetchHooks Function()
    >;
typedef $$ProviderGroupRowsTableCreateCompanionBuilder =
    ProviderGroupRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderGroupRowsTableUpdateCompanionBuilder =
    ProviderGroupRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProviderGroupRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderGroupRowsTable> {
  $$ProviderGroupRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ProviderGroupRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderGroupRowsTable> {
  $$ProviderGroupRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderGroupRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderGroupRowsTable> {
  $$ProviderGroupRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProviderGroupRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderGroupRowsTable,
          ProviderGroupRow,
          $$ProviderGroupRowsTableFilterComposer,
          $$ProviderGroupRowsTableOrderingComposer,
          $$ProviderGroupRowsTableAnnotationComposer,
          $$ProviderGroupRowsTableCreateCompanionBuilder,
          $$ProviderGroupRowsTableUpdateCompanionBuilder,
          (
            ProviderGroupRow,
            BaseReferences<
              _$AppDatabase,
              $ProviderGroupRowsTable,
              ProviderGroupRow
            >,
          ),
          ProviderGroupRow,
          PrefetchHooks Function()
        > {
  $$ProviderGroupRowsTableTableManager(
    _$AppDatabase db,
    $ProviderGroupRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderGroupRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderGroupRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderGroupRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderGroupRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderGroupRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$ProviderGroupRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderGroupRowsTable,
      ProviderGroupRow,
      $$ProviderGroupRowsTableFilterComposer,
      $$ProviderGroupRowsTableOrderingComposer,
      $$ProviderGroupRowsTableAnnotationComposer,
      $$ProviderGroupRowsTableCreateCompanionBuilder,
      $$ProviderGroupRowsTableUpdateCompanionBuilder,
      (
        ProviderGroupRow,
        BaseReferences<
          _$AppDatabase,
          $ProviderGroupRowsTable,
          ProviderGroupRow
        >,
      ),
      ProviderGroupRow,
      PrefetchHooks Function()
    >;
typedef $$McpServerRowsTableCreateCompanionBuilder =
    McpServerRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$McpServerRowsTableUpdateCompanionBuilder =
    McpServerRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$McpServerRowsTableFilterComposer
    extends Composer<_$AppDatabase, $McpServerRowsTable> {
  $$McpServerRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$McpServerRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $McpServerRowsTable> {
  $$McpServerRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$McpServerRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $McpServerRowsTable> {
  $$McpServerRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$McpServerRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $McpServerRowsTable,
          McpServerRow,
          $$McpServerRowsTableFilterComposer,
          $$McpServerRowsTableOrderingComposer,
          $$McpServerRowsTableAnnotationComposer,
          $$McpServerRowsTableCreateCompanionBuilder,
          $$McpServerRowsTableUpdateCompanionBuilder,
          (
            McpServerRow,
            BaseReferences<_$AppDatabase, $McpServerRowsTable, McpServerRow>,
          ),
          McpServerRow,
          PrefetchHooks Function()
        > {
  $$McpServerRowsTableTableManager(_$AppDatabase db, $McpServerRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McpServerRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McpServerRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McpServerRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McpServerRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => McpServerRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$McpServerRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $McpServerRowsTable,
      McpServerRow,
      $$McpServerRowsTableFilterComposer,
      $$McpServerRowsTableOrderingComposer,
      $$McpServerRowsTableAnnotationComposer,
      $$McpServerRowsTableCreateCompanionBuilder,
      $$McpServerRowsTableUpdateCompanionBuilder,
      (
        McpServerRow,
        BaseReferences<_$AppDatabase, $McpServerRowsTable, McpServerRow>,
      ),
      McpServerRow,
      PrefetchHooks Function()
    >;
typedef $$WorldBookRowsTableCreateCompanionBuilder =
    WorldBookRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WorldBookRowsTableUpdateCompanionBuilder =
    WorldBookRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$WorldBookRowsTableFilterComposer
    extends Composer<_$AppDatabase, $WorldBookRowsTable> {
  $$WorldBookRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$WorldBookRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorldBookRowsTable> {
  $$WorldBookRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorldBookRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorldBookRowsTable> {
  $$WorldBookRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorldBookRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorldBookRowsTable,
          WorldBookRow,
          $$WorldBookRowsTableFilterComposer,
          $$WorldBookRowsTableOrderingComposer,
          $$WorldBookRowsTableAnnotationComposer,
          $$WorldBookRowsTableCreateCompanionBuilder,
          $$WorldBookRowsTableUpdateCompanionBuilder,
          (
            WorldBookRow,
            BaseReferences<_$AppDatabase, $WorldBookRowsTable, WorldBookRow>,
          ),
          WorldBookRow,
          PrefetchHooks Function()
        > {
  $$WorldBookRowsTableTableManager(_$AppDatabase db, $WorldBookRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorldBookRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorldBookRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorldBookRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldBookRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorldBookRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$WorldBookRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorldBookRowsTable,
      WorldBookRow,
      $$WorldBookRowsTableFilterComposer,
      $$WorldBookRowsTableOrderingComposer,
      $$WorldBookRowsTableAnnotationComposer,
      $$WorldBookRowsTableCreateCompanionBuilder,
      $$WorldBookRowsTableUpdateCompanionBuilder,
      (
        WorldBookRow,
        BaseReferences<_$AppDatabase, $WorldBookRowsTable, WorldBookRow>,
      ),
      WorldBookRow,
      PrefetchHooks Function()
    >;
typedef $$AssistantMemoryRowsTableCreateCompanionBuilder =
    AssistantMemoryRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String assistantId,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AssistantMemoryRowsTableUpdateCompanionBuilder =
    AssistantMemoryRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> assistantId,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AssistantMemoryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantMemoryRowsTable> {
  $$AssistantMemoryRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$AssistantMemoryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantMemoryRowsTable> {
  $$AssistantMemoryRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssistantMemoryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantMemoryRowsTable> {
  $$AssistantMemoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AssistantMemoryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantMemoryRowsTable,
          AssistantMemoryRow,
          $$AssistantMemoryRowsTableFilterComposer,
          $$AssistantMemoryRowsTableOrderingComposer,
          $$AssistantMemoryRowsTableAnnotationComposer,
          $$AssistantMemoryRowsTableCreateCompanionBuilder,
          $$AssistantMemoryRowsTableUpdateCompanionBuilder,
          (
            AssistantMemoryRow,
            BaseReferences<
              _$AppDatabase,
              $AssistantMemoryRowsTable,
              AssistantMemoryRow
            >,
          ),
          AssistantMemoryRow,
          PrefetchHooks Function()
        > {
  $$AssistantMemoryRowsTableTableManager(
    _$AppDatabase db,
    $AssistantMemoryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantMemoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantMemoryRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AssistantMemoryRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> assistantId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantMemoryRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                assistantId: assistantId,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String assistantId,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantMemoryRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                assistantId: assistantId,
                payload: payload,
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

typedef $$AssistantMemoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantMemoryRowsTable,
      AssistantMemoryRow,
      $$AssistantMemoryRowsTableFilterComposer,
      $$AssistantMemoryRowsTableOrderingComposer,
      $$AssistantMemoryRowsTableAnnotationComposer,
      $$AssistantMemoryRowsTableCreateCompanionBuilder,
      $$AssistantMemoryRowsTableUpdateCompanionBuilder,
      (
        AssistantMemoryRow,
        BaseReferences<
          _$AppDatabase,
          $AssistantMemoryRowsTable,
          AssistantMemoryRow
        >,
      ),
      AssistantMemoryRow,
      PrefetchHooks Function()
    >;
typedef $$QuickPhraseRowsTableCreateCompanionBuilder =
    QuickPhraseRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$QuickPhraseRowsTableUpdateCompanionBuilder =
    QuickPhraseRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$QuickPhraseRowsTableFilterComposer
    extends Composer<_$AppDatabase, $QuickPhraseRowsTable> {
  $$QuickPhraseRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$QuickPhraseRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuickPhraseRowsTable> {
  $$QuickPhraseRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuickPhraseRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuickPhraseRowsTable> {
  $$QuickPhraseRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$QuickPhraseRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuickPhraseRowsTable,
          QuickPhraseRow,
          $$QuickPhraseRowsTableFilterComposer,
          $$QuickPhraseRowsTableOrderingComposer,
          $$QuickPhraseRowsTableAnnotationComposer,
          $$QuickPhraseRowsTableCreateCompanionBuilder,
          $$QuickPhraseRowsTableUpdateCompanionBuilder,
          (
            QuickPhraseRow,
            BaseReferences<
              _$AppDatabase,
              $QuickPhraseRowsTable,
              QuickPhraseRow
            >,
          ),
          QuickPhraseRow,
          PrefetchHooks Function()
        > {
  $$QuickPhraseRowsTableTableManager(
    _$AppDatabase db,
    $QuickPhraseRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuickPhraseRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuickPhraseRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuickPhraseRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickPhraseRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => QuickPhraseRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$QuickPhraseRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuickPhraseRowsTable,
      QuickPhraseRow,
      $$QuickPhraseRowsTableFilterComposer,
      $$QuickPhraseRowsTableOrderingComposer,
      $$QuickPhraseRowsTableAnnotationComposer,
      $$QuickPhraseRowsTableCreateCompanionBuilder,
      $$QuickPhraseRowsTableUpdateCompanionBuilder,
      (
        QuickPhraseRow,
        BaseReferences<_$AppDatabase, $QuickPhraseRowsTable, QuickPhraseRow>,
      ),
      QuickPhraseRow,
      PrefetchHooks Function()
    >;
typedef $$SearchServiceRowsTableCreateCompanionBuilder =
    SearchServiceRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SearchServiceRowsTableUpdateCompanionBuilder =
    SearchServiceRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SearchServiceRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchServiceRowsTable> {
  $$SearchServiceRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$SearchServiceRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchServiceRowsTable> {
  $$SearchServiceRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchServiceRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchServiceRowsTable> {
  $$SearchServiceRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SearchServiceRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchServiceRowsTable,
          SearchServiceRow,
          $$SearchServiceRowsTableFilterComposer,
          $$SearchServiceRowsTableOrderingComposer,
          $$SearchServiceRowsTableAnnotationComposer,
          $$SearchServiceRowsTableCreateCompanionBuilder,
          $$SearchServiceRowsTableUpdateCompanionBuilder,
          (
            SearchServiceRow,
            BaseReferences<
              _$AppDatabase,
              $SearchServiceRowsTable,
              SearchServiceRow
            >,
          ),
          SearchServiceRow,
          PrefetchHooks Function()
        > {
  $$SearchServiceRowsTableTableManager(
    _$AppDatabase db,
    $SearchServiceRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchServiceRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchServiceRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchServiceRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchServiceRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SearchServiceRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$SearchServiceRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchServiceRowsTable,
      SearchServiceRow,
      $$SearchServiceRowsTableFilterComposer,
      $$SearchServiceRowsTableOrderingComposer,
      $$SearchServiceRowsTableAnnotationComposer,
      $$SearchServiceRowsTableCreateCompanionBuilder,
      $$SearchServiceRowsTableUpdateCompanionBuilder,
      (
        SearchServiceRow,
        BaseReferences<
          _$AppDatabase,
          $SearchServiceRowsTable,
          SearchServiceRow
        >,
      ),
      SearchServiceRow,
      PrefetchHooks Function()
    >;
typedef $$TtsServiceRowsTableCreateCompanionBuilder =
    TtsServiceRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TtsServiceRowsTableUpdateCompanionBuilder =
    TtsServiceRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TtsServiceRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TtsServiceRowsTable> {
  $$TtsServiceRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$TtsServiceRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TtsServiceRowsTable> {
  $$TtsServiceRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TtsServiceRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TtsServiceRowsTable> {
  $$TtsServiceRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TtsServiceRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TtsServiceRowsTable,
          TtsServiceRow,
          $$TtsServiceRowsTableFilterComposer,
          $$TtsServiceRowsTableOrderingComposer,
          $$TtsServiceRowsTableAnnotationComposer,
          $$TtsServiceRowsTableCreateCompanionBuilder,
          $$TtsServiceRowsTableUpdateCompanionBuilder,
          (
            TtsServiceRow,
            BaseReferences<_$AppDatabase, $TtsServiceRowsTable, TtsServiceRow>,
          ),
          TtsServiceRow,
          PrefetchHooks Function()
        > {
  $$TtsServiceRowsTableTableManager(
    _$AppDatabase db,
    $TtsServiceRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TtsServiceRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TtsServiceRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TtsServiceRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TtsServiceRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TtsServiceRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$TtsServiceRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TtsServiceRowsTable,
      TtsServiceRow,
      $$TtsServiceRowsTableFilterComposer,
      $$TtsServiceRowsTableOrderingComposer,
      $$TtsServiceRowsTableAnnotationComposer,
      $$TtsServiceRowsTableCreateCompanionBuilder,
      $$TtsServiceRowsTableUpdateCompanionBuilder,
      (
        TtsServiceRow,
        BaseReferences<_$AppDatabase, $TtsServiceRowsTable, TtsServiceRow>,
      ),
      TtsServiceRow,
      PrefetchHooks Function()
    >;
typedef $$InstructionInjectionRowsTableCreateCompanionBuilder =
    InstructionInjectionRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$InstructionInjectionRowsTableUpdateCompanionBuilder =
    InstructionInjectionRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$InstructionInjectionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $InstructionInjectionRowsTable> {
  $$InstructionInjectionRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$InstructionInjectionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $InstructionInjectionRowsTable> {
  $$InstructionInjectionRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstructionInjectionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstructionInjectionRowsTable> {
  $$InstructionInjectionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$InstructionInjectionRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstructionInjectionRowsTable,
          InstructionInjectionRow,
          $$InstructionInjectionRowsTableFilterComposer,
          $$InstructionInjectionRowsTableOrderingComposer,
          $$InstructionInjectionRowsTableAnnotationComposer,
          $$InstructionInjectionRowsTableCreateCompanionBuilder,
          $$InstructionInjectionRowsTableUpdateCompanionBuilder,
          (
            InstructionInjectionRow,
            BaseReferences<
              _$AppDatabase,
              $InstructionInjectionRowsTable,
              InstructionInjectionRow
            >,
          ),
          InstructionInjectionRow,
          PrefetchHooks Function()
        > {
  $$InstructionInjectionRowsTableTableManager(
    _$AppDatabase db,
    $InstructionInjectionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstructionInjectionRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InstructionInjectionRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InstructionInjectionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstructionInjectionRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => InstructionInjectionRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$InstructionInjectionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstructionInjectionRowsTable,
      InstructionInjectionRow,
      $$InstructionInjectionRowsTableFilterComposer,
      $$InstructionInjectionRowsTableOrderingComposer,
      $$InstructionInjectionRowsTableAnnotationComposer,
      $$InstructionInjectionRowsTableCreateCompanionBuilder,
      $$InstructionInjectionRowsTableUpdateCompanionBuilder,
      (
        InstructionInjectionRow,
        BaseReferences<
          _$AppDatabase,
          $InstructionInjectionRowsTable,
          InstructionInjectionRow
        >,
      ),
      InstructionInjectionRow,
      PrefetchHooks Function()
    >;
typedef $$AssistantTagRowsTableCreateCompanionBuilder =
    AssistantTagRowsCompanion Function({
      required String id,
      required int sortOrder,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AssistantTagRowsTableUpdateCompanionBuilder =
    AssistantTagRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AssistantTagRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantTagRowsTable> {
  $$AssistantTagRowsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$AssistantTagRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantTagRowsTable> {
  $$AssistantTagRowsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssistantTagRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantTagRowsTable> {
  $$AssistantTagRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AssistantTagRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantTagRowsTable,
          AssistantTagRow,
          $$AssistantTagRowsTableFilterComposer,
          $$AssistantTagRowsTableOrderingComposer,
          $$AssistantTagRowsTableAnnotationComposer,
          $$AssistantTagRowsTableCreateCompanionBuilder,
          $$AssistantTagRowsTableUpdateCompanionBuilder,
          (
            AssistantTagRow,
            BaseReferences<
              _$AppDatabase,
              $AssistantTagRowsTable,
              AssistantTagRow
            >,
          ),
          AssistantTagRow,
          PrefetchHooks Function()
        > {
  $$AssistantTagRowsTableTableManager(
    _$AppDatabase db,
    $AssistantTagRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantTagRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantTagRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssistantTagRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantTagRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantTagRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                payload: payload,
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

typedef $$AssistantTagRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantTagRowsTable,
      AssistantTagRow,
      $$AssistantTagRowsTableFilterComposer,
      $$AssistantTagRowsTableOrderingComposer,
      $$AssistantTagRowsTableAnnotationComposer,
      $$AssistantTagRowsTableCreateCompanionBuilder,
      $$AssistantTagRowsTableUpdateCompanionBuilder,
      (
        AssistantTagRow,
        BaseReferences<_$AppDatabase, $AssistantTagRowsTable, AssistantTagRow>,
      ),
      AssistantTagRow,
      PrefetchHooks Function()
    >;
typedef $$PreferenceRowsTableCreateCompanionBuilder =
    PreferenceRowsCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PreferenceRowsTableUpdateCompanionBuilder =
    PreferenceRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PreferenceRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PreferenceRowsTable> {
  $$PreferenceRowsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$PreferenceRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferenceRowsTable> {
  $$PreferenceRowsTableOrderingComposer({
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

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferenceRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferenceRowsTable> {
  $$PreferenceRowsTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PreferenceRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferenceRowsTable,
          PreferenceRow,
          $$PreferenceRowsTableFilterComposer,
          $$PreferenceRowsTableOrderingComposer,
          $$PreferenceRowsTableAnnotationComposer,
          $$PreferenceRowsTableCreateCompanionBuilder,
          $$PreferenceRowsTableUpdateCompanionBuilder,
          (
            PreferenceRow,
            BaseReferences<_$AppDatabase, $PreferenceRowsTable, PreferenceRow>,
          ),
          PreferenceRow,
          PrefetchHooks Function()
        > {
  $$PreferenceRowsTableTableManager(
    _$AppDatabase db,
    $PreferenceRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferenceRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferenceRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferenceRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferenceRowsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PreferenceRowsCompanion.insert(
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

typedef $$PreferenceRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferenceRowsTable,
      PreferenceRow,
      $$PreferenceRowsTableFilterComposer,
      $$PreferenceRowsTableOrderingComposer,
      $$PreferenceRowsTableAnnotationComposer,
      $$PreferenceRowsTableCreateCompanionBuilder,
      $$PreferenceRowsTableUpdateCompanionBuilder,
      (
        PreferenceRow,
        BaseReferences<_$AppDatabase, $PreferenceRowsTable, PreferenceRow>,
      ),
      PreferenceRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationRowsTableTableManager get conversationRows =>
      $$ConversationRowsTableTableManager(_db, _db.conversationRows);
  $$MessageRowsTableTableManager get messageRows =>
      $$MessageRowsTableTableManager(_db, _db.messageRows);
  $$ConversationMcpServerRowsTableTableManager get conversationMcpServerRows =>
      $$ConversationMcpServerRowsTableTableManager(
        _db,
        _db.conversationMcpServerRows,
      );
  $$ChatStorageMetaRowsTableTableManager get chatStorageMetaRows =>
      $$ChatStorageMetaRowsTableTableManager(_db, _db.chatStorageMetaRows);
  $$MessagePartRowsTableTableManager get messagePartRows =>
      $$MessagePartRowsTableTableManager(_db, _db.messagePartRows);
  $$ProviderArtifactRowsTableTableManager get providerArtifactRows =>
      $$ProviderArtifactRowsTableTableManager(_db, _db.providerArtifactRows);
  $$AssetRowsTableTableManager get assetRows =>
      $$AssetRowsTableTableManager(_db, _db.assetRows);
  $$MessageAssetRowsTableTableManager get messageAssetRows =>
      $$MessageAssetRowsTableTableManager(_db, _db.messageAssetRows);
  $$AssetGcRowsTableTableManager get assetGcRows =>
      $$AssetGcRowsTableTableManager(_db, _db.assetGcRows);
  $$GcAuditRowsTableTableManager get gcAuditRows =>
      $$GcAuditRowsTableTableManager(_db, _db.gcAuditRows);
  $$AssetReferenceDirtyRowsTableTableManager get assetReferenceDirtyRows =>
      $$AssetReferenceDirtyRowsTableTableManager(
        _db,
        _db.assetReferenceDirtyRows,
      );
  $$GenerationRunRowsTableTableManager get generationRunRows =>
      $$GenerationRunRowsTableTableManager(_db, _db.generationRunRows);
  $$AssistantRowsTableTableManager get assistantRows =>
      $$AssistantRowsTableTableManager(_db, _db.assistantRows);
  $$ProviderRowsTableTableManager get providerRows =>
      $$ProviderRowsTableTableManager(_db, _db.providerRows);
  $$ProviderGroupRowsTableTableManager get providerGroupRows =>
      $$ProviderGroupRowsTableTableManager(_db, _db.providerGroupRows);
  $$McpServerRowsTableTableManager get mcpServerRows =>
      $$McpServerRowsTableTableManager(_db, _db.mcpServerRows);
  $$WorldBookRowsTableTableManager get worldBookRows =>
      $$WorldBookRowsTableTableManager(_db, _db.worldBookRows);
  $$AssistantMemoryRowsTableTableManager get assistantMemoryRows =>
      $$AssistantMemoryRowsTableTableManager(_db, _db.assistantMemoryRows);
  $$QuickPhraseRowsTableTableManager get quickPhraseRows =>
      $$QuickPhraseRowsTableTableManager(_db, _db.quickPhraseRows);
  $$SearchServiceRowsTableTableManager get searchServiceRows =>
      $$SearchServiceRowsTableTableManager(_db, _db.searchServiceRows);
  $$TtsServiceRowsTableTableManager get ttsServiceRows =>
      $$TtsServiceRowsTableTableManager(_db, _db.ttsServiceRows);
  $$InstructionInjectionRowsTableTableManager get instructionInjectionRows =>
      $$InstructionInjectionRowsTableTableManager(
        _db,
        _db.instructionInjectionRows,
      );
  $$AssistantTagRowsTableTableManager get assistantTagRows =>
      $$AssistantTagRowsTableTableManager(_db, _db.assistantTagRows);
  $$PreferenceRowsTableTableManager get preferenceRows =>
      $$PreferenceRowsTableTableManager(_db, _db.preferenceRows);
}
