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
  late final $ConversationMcpServerRowsTable conversationMcpServerRows =
      $ConversationMcpServerRowsTable(this);
  late final $ToolEventRowsTable toolEventRows = $ToolEventRowsTable(this);
  late final $GeminiThoughtSignatureRowsTable geminiThoughtSignatureRows =
      $GeminiThoughtSignatureRowsTable(this);
  late final $ChatStorageMetaRowsTable chatStorageMetaRows =
      $ChatStorageMetaRowsTable(this);
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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversationRows,
    messageRows,
    conversationMcpServerRows,
    toolEventRows,
    geminiThoughtSignatureRows,
    chatStorageMetaRows,
    idxConversationsUpdatedAt,
    idxConversationsAssistant,
    idxMessagesConversationOrder,
    idxMessagesConversationTimestamp,
    idxMessagesGroup,
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
  $$ChatStorageMetaRowsTableTableManager get chatStorageMetaRows =>
      $$ChatStorageMetaRowsTableTableManager(_db, _db.chatStorageMetaRows);
}
