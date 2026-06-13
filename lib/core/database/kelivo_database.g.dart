// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kelivo_database.dart';

// ignore_for_file: type=lint
class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdsMeta = const VerificationMeta(
    'messageIds',
  );
  @override
  late final GeneratedColumn<String> messageIds = GeneratedColumn<String>(
    'message_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _mcpServerIdsMeta = const VerificationMeta(
    'mcpServerIds',
  );
  @override
  late final GeneratedColumn<String> mcpServerIds = GeneratedColumn<String>(
    'mcp_server_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _versionSelectionsMeta = const VerificationMeta(
    'versionSelections',
  );
  @override
  late final GeneratedColumn<String> versionSelections =
      GeneratedColumn<String>(
        'version_selections',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
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
  static const VerificationMeta _chatSuggestionsMeta = const VerificationMeta(
    'chatSuggestions',
  );
  @override
  late final GeneratedColumn<String> chatSuggestions = GeneratedColumn<String>(
    'chat_suggestions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    updatedAt,
    messageIds,
    isPinned,
    mcpServerIds,
    assistantId,
    truncateIndex,
    versionSelections,
    summary,
    lastSummarizedMessageCount,
    chatSuggestions,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
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
    if (data.containsKey('message_ids')) {
      context.handle(
        _messageIdsMeta,
        messageIds.isAcceptableOrUnknown(data['message_ids']!, _messageIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdsMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('mcp_server_ids')) {
      context.handle(
        _mcpServerIdsMeta,
        mcpServerIds.isAcceptableOrUnknown(
          data['mcp_server_ids']!,
          _mcpServerIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mcpServerIdsMeta);
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
    if (data.containsKey('version_selections')) {
      context.handle(
        _versionSelectionsMeta,
        versionSelections.isAcceptableOrUnknown(
          data['version_selections']!,
          _versionSelectionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionSelectionsMeta);
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
    if (data.containsKey('chat_suggestions')) {
      context.handle(
        _chatSuggestionsMeta,
        chatSuggestions.isAcceptableOrUnknown(
          data['chat_suggestions']!,
          _chatSuggestionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chatSuggestionsMeta);
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
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      messageIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_ids'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      mcpServerIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mcp_server_ids'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      ),
      truncateIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}truncate_index'],
      )!,
      versionSelections: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_selections'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      lastSummarizedMessageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_summarized_message_count'],
      )!,
      chatSuggestions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_suggestions'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final String messageIds;
  final bool isPinned;
  final String mcpServerIds;
  final String? assistantId;
  final int truncateIndex;
  final String versionSelections;
  final String? summary;
  final int lastSummarizedMessageCount;
  final String chatSuggestions;
  const ConversationRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageIds,
    required this.isPinned,
    required this.mcpServerIds,
    this.assistantId,
    required this.truncateIndex,
    required this.versionSelections,
    this.summary,
    required this.lastSummarizedMessageCount,
    required this.chatSuggestions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['message_ids'] = Variable<String>(messageIds);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['mcp_server_ids'] = Variable<String>(mcpServerIds);
    if (!nullToAbsent || assistantId != null) {
      map['assistant_id'] = Variable<String>(assistantId);
    }
    map['truncate_index'] = Variable<int>(truncateIndex);
    map['version_selections'] = Variable<String>(versionSelections);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['last_summarized_message_count'] = Variable<int>(
      lastSummarizedMessageCount,
    );
    map['chat_suggestions'] = Variable<String>(chatSuggestions);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      messageIds: Value(messageIds),
      isPinned: Value(isPinned),
      mcpServerIds: Value(mcpServerIds),
      assistantId: assistantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantId),
      truncateIndex: Value(truncateIndex),
      versionSelections: Value(versionSelections),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      lastSummarizedMessageCount: Value(lastSummarizedMessageCount),
      chatSuggestions: Value(chatSuggestions),
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
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      messageIds: serializer.fromJson<String>(json['messageIds']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      mcpServerIds: serializer.fromJson<String>(json['mcpServerIds']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      truncateIndex: serializer.fromJson<int>(json['truncateIndex']),
      versionSelections: serializer.fromJson<String>(json['versionSelections']),
      summary: serializer.fromJson<String?>(json['summary']),
      lastSummarizedMessageCount: serializer.fromJson<int>(
        json['lastSummarizedMessageCount'],
      ),
      chatSuggestions: serializer.fromJson<String>(json['chatSuggestions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'messageIds': serializer.toJson<String>(messageIds),
      'isPinned': serializer.toJson<bool>(isPinned),
      'mcpServerIds': serializer.toJson<String>(mcpServerIds),
      'assistantId': serializer.toJson<String?>(assistantId),
      'truncateIndex': serializer.toJson<int>(truncateIndex),
      'versionSelections': serializer.toJson<String>(versionSelections),
      'summary': serializer.toJson<String?>(summary),
      'lastSummarizedMessageCount': serializer.toJson<int>(
        lastSummarizedMessageCount,
      ),
      'chatSuggestions': serializer.toJson<String>(chatSuggestions),
    };
  }

  ConversationRow copyWith({
    String? id,
    String? title,
    int? createdAt,
    int? updatedAt,
    String? messageIds,
    bool? isPinned,
    String? mcpServerIds,
    Value<String?> assistantId = const Value.absent(),
    int? truncateIndex,
    String? versionSelections,
    Value<String?> summary = const Value.absent(),
    int? lastSummarizedMessageCount,
    String? chatSuggestions,
  }) => ConversationRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messageIds: messageIds ?? this.messageIds,
    isPinned: isPinned ?? this.isPinned,
    mcpServerIds: mcpServerIds ?? this.mcpServerIds,
    assistantId: assistantId.present ? assistantId.value : this.assistantId,
    truncateIndex: truncateIndex ?? this.truncateIndex,
    versionSelections: versionSelections ?? this.versionSelections,
    summary: summary.present ? summary.value : this.summary,
    lastSummarizedMessageCount:
        lastSummarizedMessageCount ?? this.lastSummarizedMessageCount,
    chatSuggestions: chatSuggestions ?? this.chatSuggestions,
  );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      messageIds: data.messageIds.present
          ? data.messageIds.value
          : this.messageIds,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      mcpServerIds: data.mcpServerIds.present
          ? data.mcpServerIds.value
          : this.mcpServerIds,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      truncateIndex: data.truncateIndex.present
          ? data.truncateIndex.value
          : this.truncateIndex,
      versionSelections: data.versionSelections.present
          ? data.versionSelections.value
          : this.versionSelections,
      summary: data.summary.present ? data.summary.value : this.summary,
      lastSummarizedMessageCount: data.lastSummarizedMessageCount.present
          ? data.lastSummarizedMessageCount.value
          : this.lastSummarizedMessageCount,
      chatSuggestions: data.chatSuggestions.present
          ? data.chatSuggestions.value
          : this.chatSuggestions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messageIds: $messageIds, ')
          ..write('isPinned: $isPinned, ')
          ..write('mcpServerIds: $mcpServerIds, ')
          ..write('assistantId: $assistantId, ')
          ..write('truncateIndex: $truncateIndex, ')
          ..write('versionSelections: $versionSelections, ')
          ..write('summary: $summary, ')
          ..write('lastSummarizedMessageCount: $lastSummarizedMessageCount, ')
          ..write('chatSuggestions: $chatSuggestions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    updatedAt,
    messageIds,
    isPinned,
    mcpServerIds,
    assistantId,
    truncateIndex,
    versionSelections,
    summary,
    lastSummarizedMessageCount,
    chatSuggestions,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.messageIds == this.messageIds &&
          other.isPinned == this.isPinned &&
          other.mcpServerIds == this.mcpServerIds &&
          other.assistantId == this.assistantId &&
          other.truncateIndex == this.truncateIndex &&
          other.versionSelections == this.versionSelections &&
          other.summary == this.summary &&
          other.lastSummarizedMessageCount == this.lastSummarizedMessageCount &&
          other.chatSuggestions == this.chatSuggestions);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> messageIds;
  final Value<bool> isPinned;
  final Value<String> mcpServerIds;
  final Value<String?> assistantId;
  final Value<int> truncateIndex;
  final Value<String> versionSelections;
  final Value<String?> summary;
  final Value<int> lastSummarizedMessageCount;
  final Value<String> chatSuggestions;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.messageIds = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.mcpServerIds = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.truncateIndex = const Value.absent(),
    this.versionSelections = const Value.absent(),
    this.summary = const Value.absent(),
    this.lastSummarizedMessageCount = const Value.absent(),
    this.chatSuggestions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String title,
    required int createdAt,
    required int updatedAt,
    required String messageIds,
    this.isPinned = const Value.absent(),
    required String mcpServerIds,
    this.assistantId = const Value.absent(),
    this.truncateIndex = const Value.absent(),
    required String versionSelections,
    this.summary = const Value.absent(),
    this.lastSummarizedMessageCount = const Value.absent(),
    required String chatSuggestions,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       messageIds = Value(messageIds),
       mcpServerIds = Value(mcpServerIds),
       versionSelections = Value(versionSelections),
       chatSuggestions = Value(chatSuggestions);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? messageIds,
    Expression<bool>? isPinned,
    Expression<String>? mcpServerIds,
    Expression<String>? assistantId,
    Expression<int>? truncateIndex,
    Expression<String>? versionSelections,
    Expression<String>? summary,
    Expression<int>? lastSummarizedMessageCount,
    Expression<String>? chatSuggestions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (messageIds != null) 'message_ids': messageIds,
      if (isPinned != null) 'is_pinned': isPinned,
      if (mcpServerIds != null) 'mcp_server_ids': mcpServerIds,
      if (assistantId != null) 'assistant_id': assistantId,
      if (truncateIndex != null) 'truncate_index': truncateIndex,
      if (versionSelections != null) 'version_selections': versionSelections,
      if (summary != null) 'summary': summary,
      if (lastSummarizedMessageCount != null)
        'last_summarized_message_count': lastSummarizedMessageCount,
      if (chatSuggestions != null) 'chat_suggestions': chatSuggestions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? messageIds,
    Value<bool>? isPinned,
    Value<String>? mcpServerIds,
    Value<String?>? assistantId,
    Value<int>? truncateIndex,
    Value<String>? versionSelections,
    Value<String?>? summary,
    Value<int>? lastSummarizedMessageCount,
    Value<String>? chatSuggestions,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageIds: messageIds ?? this.messageIds,
      isPinned: isPinned ?? this.isPinned,
      mcpServerIds: mcpServerIds ?? this.mcpServerIds,
      assistantId: assistantId ?? this.assistantId,
      truncateIndex: truncateIndex ?? this.truncateIndex,
      versionSelections: versionSelections ?? this.versionSelections,
      summary: summary ?? this.summary,
      lastSummarizedMessageCount:
          lastSummarizedMessageCount ?? this.lastSummarizedMessageCount,
      chatSuggestions: chatSuggestions ?? this.chatSuggestions,
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
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (messageIds.present) {
      map['message_ids'] = Variable<String>(messageIds.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (mcpServerIds.present) {
      map['mcp_server_ids'] = Variable<String>(mcpServerIds.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (truncateIndex.present) {
      map['truncate_index'] = Variable<int>(truncateIndex.value);
    }
    if (versionSelections.present) {
      map['version_selections'] = Variable<String>(versionSelections.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (lastSummarizedMessageCount.present) {
      map['last_summarized_message_count'] = Variable<int>(
        lastSummarizedMessageCount.value,
      );
    }
    if (chatSuggestions.present) {
      map['chat_suggestions'] = Variable<String>(chatSuggestions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messageIds: $messageIds, ')
          ..write('isPinned: $isPinned, ')
          ..write('mcpServerIds: $mcpServerIds, ')
          ..write('assistantId: $assistantId, ')
          ..write('truncateIndex: $truncateIndex, ')
          ..write('versionSelections: $versionSelections, ')
          ..write('summary: $summary, ')
          ..write('lastSummarizedMessageCount: $lastSummarizedMessageCount, ')
          ..write('chatSuggestions: $chatSuggestions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
      'REFERENCES conversations (id) ON DELETE CASCADE',
    ),
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
  late final GeneratedColumn<int> reasoningStartAt = GeneratedColumn<int>(
    'reasoning_start_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasoningFinishedAtMeta =
      const VerificationMeta('reasoningFinishedAt');
  @override
  late final GeneratedColumn<int> reasoningFinishedAt = GeneratedColumn<int>(
    'reasoning_finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    role,
    content,
    timestamp,
    modelId,
    providerId,
    totalTokens,
    conversationId,
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
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
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
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      isStreaming: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_streaming'],
      )!,
      reasoningText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning_text'],
      ),
      reasoningStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reasoning_start_at'],
      ),
      reasoningFinishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String role;
  final String content;
  final int timestamp;
  final String? modelId;
  final String? providerId;
  final int? totalTokens;
  final String conversationId;
  final bool isStreaming;
  final String? reasoningText;
  final int? reasoningStartAt;
  final int? reasoningFinishedAt;
  final String? translation;
  final String? reasoningSegmentsJson;
  final String? groupId;
  final int version;
  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? durationMs;
  const MessageRow({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.modelId,
    this.providerId,
    this.totalTokens,
    required this.conversationId,
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
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['timestamp'] = Variable<int>(timestamp);
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<String>(providerId);
    }
    if (!nullToAbsent || totalTokens != null) {
      map['total_tokens'] = Variable<int>(totalTokens);
    }
    map['conversation_id'] = Variable<String>(conversationId);
    map['is_streaming'] = Variable<bool>(isStreaming);
    if (!nullToAbsent || reasoningText != null) {
      map['reasoning_text'] = Variable<String>(reasoningText);
    }
    if (!nullToAbsent || reasoningStartAt != null) {
      map['reasoning_start_at'] = Variable<int>(reasoningStartAt);
    }
    if (!nullToAbsent || reasoningFinishedAt != null) {
      map['reasoning_finished_at'] = Variable<int>(reasoningFinishedAt);
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
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
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
      conversationId: Value(conversationId),
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
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      providerId: serializer.fromJson<String?>(json['providerId']),
      totalTokens: serializer.fromJson<int?>(json['totalTokens']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      isStreaming: serializer.fromJson<bool>(json['isStreaming']),
      reasoningText: serializer.fromJson<String?>(json['reasoningText']),
      reasoningStartAt: serializer.fromJson<int?>(json['reasoningStartAt']),
      reasoningFinishedAt: serializer.fromJson<int?>(
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'timestamp': serializer.toJson<int>(timestamp),
      'modelId': serializer.toJson<String?>(modelId),
      'providerId': serializer.toJson<String?>(providerId),
      'totalTokens': serializer.toJson<int?>(totalTokens),
      'conversationId': serializer.toJson<String>(conversationId),
      'isStreaming': serializer.toJson<bool>(isStreaming),
      'reasoningText': serializer.toJson<String?>(reasoningText),
      'reasoningStartAt': serializer.toJson<int?>(reasoningStartAt),
      'reasoningFinishedAt': serializer.toJson<int?>(reasoningFinishedAt),
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
    };
  }

  MessageRow copyWith({
    String? id,
    String? role,
    String? content,
    int? timestamp,
    Value<String?> modelId = const Value.absent(),
    Value<String?> providerId = const Value.absent(),
    Value<int?> totalTokens = const Value.absent(),
    String? conversationId,
    bool? isStreaming,
    Value<String?> reasoningText = const Value.absent(),
    Value<int?> reasoningStartAt = const Value.absent(),
    Value<int?> reasoningFinishedAt = const Value.absent(),
    Value<String?> translation = const Value.absent(),
    Value<String?> reasoningSegmentsJson = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    int? version,
    Value<int?> promptTokens = const Value.absent(),
    Value<int?> completionTokens = const Value.absent(),
    Value<int?> cachedTokens = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
  }) => MessageRow(
    id: id ?? this.id,
    role: role ?? this.role,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    modelId: modelId.present ? modelId.value : this.modelId,
    providerId: providerId.present ? providerId.value : this.providerId,
    totalTokens: totalTokens.present ? totalTokens.value : this.totalTokens,
    conversationId: conversationId ?? this.conversationId,
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
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
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
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('modelId: $modelId, ')
          ..write('providerId: $providerId, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('conversationId: $conversationId, ')
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
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    role,
    content,
    timestamp,
    modelId,
    providerId,
    totalTokens,
    conversationId,
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
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.role == this.role &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.modelId == this.modelId &&
          other.providerId == this.providerId &&
          other.totalTokens == this.totalTokens &&
          other.conversationId == this.conversationId &&
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
          other.durationMs == this.durationMs);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> role;
  final Value<String> content;
  final Value<int> timestamp;
  final Value<String?> modelId;
  final Value<String?> providerId;
  final Value<int?> totalTokens;
  final Value<String> conversationId;
  final Value<bool> isStreaming;
  final Value<String?> reasoningText;
  final Value<int?> reasoningStartAt;
  final Value<int?> reasoningFinishedAt;
  final Value<String?> translation;
  final Value<String?> reasoningSegmentsJson;
  final Value<String?> groupId;
  final Value<int> version;
  final Value<int?> promptTokens;
  final Value<int?> completionTokens;
  final Value<int?> cachedTokens;
  final Value<int?> durationMs;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.modelId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.conversationId = const Value.absent(),
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
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String role,
    required String content,
    required int timestamp,
    this.modelId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.totalTokens = const Value.absent(),
    required String conversationId,
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
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       content = Value(content),
       timestamp = Value(timestamp),
       conversationId = Value(conversationId);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? content,
    Expression<int>? timestamp,
    Expression<String>? modelId,
    Expression<String>? providerId,
    Expression<int>? totalTokens,
    Expression<String>? conversationId,
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (modelId != null) 'model_id': modelId,
      if (providerId != null) 'provider_id': providerId,
      if (totalTokens != null) 'total_tokens': totalTokens,
      if (conversationId != null) 'conversation_id': conversationId,
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
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? role,
    Value<String>? content,
    Value<int>? timestamp,
    Value<String?>? modelId,
    Value<String?>? providerId,
    Value<int?>? totalTokens,
    Value<String>? conversationId,
    Value<bool>? isStreaming,
    Value<String?>? reasoningText,
    Value<int?>? reasoningStartAt,
    Value<int?>? reasoningFinishedAt,
    Value<String?>? translation,
    Value<String?>? reasoningSegmentsJson,
    Value<String?>? groupId,
    Value<int>? version,
    Value<int?>? promptTokens,
    Value<int?>? completionTokens,
    Value<int?>? cachedTokens,
    Value<int?>? durationMs,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      totalTokens: totalTokens ?? this.totalTokens,
      conversationId: conversationId ?? this.conversationId,
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
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
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (isStreaming.present) {
      map['is_streaming'] = Variable<bool>(isStreaming.value);
    }
    if (reasoningText.present) {
      map['reasoning_text'] = Variable<String>(reasoningText.value);
    }
    if (reasoningStartAt.present) {
      map['reasoning_start_at'] = Variable<int>(reasoningStartAt.value);
    }
    if (reasoningFinishedAt.present) {
      map['reasoning_finished_at'] = Variable<int>(reasoningFinishedAt.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('modelId: $modelId, ')
          ..write('providerId: $providerId, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('conversationId: $conversationId, ')
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
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ToolEventsTable extends ToolEvents
    with TableInfo<$ToolEventsTable, ToolEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ToolEventsTable(this.attachedDatabase, [this._alias]);
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
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geminiThoughtSigMeta = const VerificationMeta(
    'geminiThoughtSig',
  );
  @override
  late final GeneratedColumn<String> geminiThoughtSig = GeneratedColumn<String>(
    'gemini_thought_sig',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [messageId, data, geminiThoughtSig];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tool_events';
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
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('gemini_thought_sig')) {
      context.handle(
        _geminiThoughtSigMeta,
        geminiThoughtSig.isAcceptableOrUnknown(
          data['gemini_thought_sig']!,
          _geminiThoughtSigMeta,
        ),
      );
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
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      geminiThoughtSig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gemini_thought_sig'],
      ),
    );
  }

  @override
  $ToolEventsTable createAlias(String alias) {
    return $ToolEventsTable(attachedDatabase, alias);
  }
}

class ToolEventRow extends DataClass implements Insertable<ToolEventRow> {
  final String messageId;
  final String data;
  final String? geminiThoughtSig;
  const ToolEventRow({
    required this.messageId,
    required this.data,
    this.geminiThoughtSig,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || geminiThoughtSig != null) {
      map['gemini_thought_sig'] = Variable<String>(geminiThoughtSig);
    }
    return map;
  }

  ToolEventsCompanion toCompanion(bool nullToAbsent) {
    return ToolEventsCompanion(
      messageId: Value(messageId),
      data: Value(data),
      geminiThoughtSig: geminiThoughtSig == null && nullToAbsent
          ? const Value.absent()
          : Value(geminiThoughtSig),
    );
  }

  factory ToolEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ToolEventRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      data: serializer.fromJson<String>(json['data']),
      geminiThoughtSig: serializer.fromJson<String?>(json['geminiThoughtSig']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'data': serializer.toJson<String>(data),
      'geminiThoughtSig': serializer.toJson<String?>(geminiThoughtSig),
    };
  }

  ToolEventRow copyWith({
    String? messageId,
    String? data,
    Value<String?> geminiThoughtSig = const Value.absent(),
  }) => ToolEventRow(
    messageId: messageId ?? this.messageId,
    data: data ?? this.data,
    geminiThoughtSig: geminiThoughtSig.present
        ? geminiThoughtSig.value
        : this.geminiThoughtSig,
  );
  ToolEventRow copyWithCompanion(ToolEventsCompanion data) {
    return ToolEventRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      data: data.data.present ? data.data.value : this.data,
      geminiThoughtSig: data.geminiThoughtSig.present
          ? data.geminiThoughtSig.value
          : this.geminiThoughtSig,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ToolEventRow(')
          ..write('messageId: $messageId, ')
          ..write('data: $data, ')
          ..write('geminiThoughtSig: $geminiThoughtSig')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, data, geminiThoughtSig);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolEventRow &&
          other.messageId == this.messageId &&
          other.data == this.data &&
          other.geminiThoughtSig == this.geminiThoughtSig);
}

class ToolEventsCompanion extends UpdateCompanion<ToolEventRow> {
  final Value<String> messageId;
  final Value<String> data;
  final Value<String?> geminiThoughtSig;
  final Value<int> rowid;
  const ToolEventsCompanion({
    this.messageId = const Value.absent(),
    this.data = const Value.absent(),
    this.geminiThoughtSig = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ToolEventsCompanion.insert({
    required String messageId,
    required String data,
    this.geminiThoughtSig = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       data = Value(data);
  static Insertable<ToolEventRow> custom({
    Expression<String>? messageId,
    Expression<String>? data,
    Expression<String>? geminiThoughtSig,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (data != null) 'data': data,
      if (geminiThoughtSig != null) 'gemini_thought_sig': geminiThoughtSig,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ToolEventsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? data,
    Value<String?>? geminiThoughtSig,
    Value<int>? rowid,
  }) {
    return ToolEventsCompanion(
      messageId: messageId ?? this.messageId,
      data: data ?? this.data,
      geminiThoughtSig: geminiThoughtSig ?? this.geminiThoughtSig,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (geminiThoughtSig.present) {
      map['gemini_thought_sig'] = Variable<String>(geminiThoughtSig.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ToolEventsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('data: $data, ')
          ..write('geminiThoughtSig: $geminiThoughtSig, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MigrationMetaTable extends MigrationMeta
    with TableInfo<$MigrationMetaTable, MigrationMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MigrationMetaTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'migration_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigrationMetaRow> instance, {
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
  MigrationMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigrationMetaRow(
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
  $MigrationMetaTable createAlias(String alias) {
    return $MigrationMetaTable(attachedDatabase, alias);
  }
}

class MigrationMetaRow extends DataClass
    implements Insertable<MigrationMetaRow> {
  final String key;
  final String value;
  const MigrationMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MigrationMetaCompanion toCompanion(bool nullToAbsent) {
    return MigrationMetaCompanion(key: Value(key), value: Value(value));
  }

  factory MigrationMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigrationMetaRow(
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

  MigrationMetaRow copyWith({String? key, String? value}) =>
      MigrationMetaRow(key: key ?? this.key, value: value ?? this.value);
  MigrationMetaRow copyWithCompanion(MigrationMetaCompanion data) {
    return MigrationMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MigrationMetaRow(')
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
      (other is MigrationMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class MigrationMetaCompanion extends UpdateCompanion<MigrationMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MigrationMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MigrationMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MigrationMetaRow> custom({
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

  MigrationMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MigrationMetaCompanion(
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
    return (StringBuffer('MigrationMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KelivoDatabase extends GeneratedDatabase {
  _$KelivoDatabase(QueryExecutor e) : super(e);
  $KelivoDatabaseManager get managers => $KelivoDatabaseManager(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ToolEventsTable toolEvents = $ToolEventsTable(this);
  late final $MigrationMetaTable migrationMeta = $MigrationMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversations,
    messages,
    toolEvents,
    migrationMeta,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tool_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      required String title,
      required int createdAt,
      required int updatedAt,
      required String messageIds,
      Value<bool> isPinned,
      required String mcpServerIds,
      Value<String?> assistantId,
      Value<int> truncateIndex,
      required String versionSelections,
      Value<String?> summary,
      Value<int> lastSummarizedMessageCount,
      required String chatSuggestions,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> messageIds,
      Value<bool> isPinned,
      Value<String> mcpServerIds,
      Value<String?> assistantId,
      Value<int> truncateIndex,
      Value<String> versionSelections,
      Value<String?> summary,
      Value<int> lastSummarizedMessageCount,
      Value<String> chatSuggestions,
      Value<int> rowid,
    });

final class $$ConversationsTableReferences
    extends
        BaseReferences<_$KelivoDatabase, $ConversationsTable, ConversationRow> {
  $$ConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MessagesTable, List<MessageRow>>
  _messagesRefsTable(_$KelivoDatabase db) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'conversations__id__messages__conversation_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$KelivoDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageIds => $composableBuilder(
    column: $table.messageIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mcpServerIds => $composableBuilder(
    column: $table.mcpServerIds,
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

  ColumnFilters<String> get versionSelections => $composableBuilder(
    column: $table.versionSelections,
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

  ColumnFilters<String> get chatSuggestions => $composableBuilder(
    column: $table.chatSuggestions,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$KelivoDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
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

  ColumnOrderings<String> get messageIds => $composableBuilder(
    column: $table.messageIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mcpServerIds => $composableBuilder(
    column: $table.mcpServerIds,
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

  ColumnOrderings<String> get versionSelections => $composableBuilder(
    column: $table.versionSelections,
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

  ColumnOrderings<String> get chatSuggestions => $composableBuilder(
    column: $table.chatSuggestions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$KelivoDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
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

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get messageIds => $composableBuilder(
    column: $table.messageIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<String> get mcpServerIds => $composableBuilder(
    column: $table.mcpServerIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get truncateIndex => $composableBuilder(
    column: $table.truncateIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get versionSelections => $composableBuilder(
    column: $table.versionSelections,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get lastSummarizedMessageCount => $composableBuilder(
    column: $table.lastSummarizedMessageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chatSuggestions => $composableBuilder(
    column: $table.chatSuggestions,
    builder: (column) => column,
  );

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$KelivoDatabase,
          $ConversationsTable,
          ConversationRow,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (ConversationRow, $$ConversationsTableReferences),
          ConversationRow,
          PrefetchHooks Function({bool messagesRefs})
        > {
  $$ConversationsTableTableManager(
    _$KelivoDatabase db,
    $ConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> messageIds = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String> mcpServerIds = const Value.absent(),
                Value<String?> assistantId = const Value.absent(),
                Value<int> truncateIndex = const Value.absent(),
                Value<String> versionSelections = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int> lastSummarizedMessageCount = const Value.absent(),
                Value<String> chatSuggestions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                messageIds: messageIds,
                isPinned: isPinned,
                mcpServerIds: mcpServerIds,
                assistantId: assistantId,
                truncateIndex: truncateIndex,
                versionSelections: versionSelections,
                summary: summary,
                lastSummarizedMessageCount: lastSummarizedMessageCount,
                chatSuggestions: chatSuggestions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int createdAt,
                required int updatedAt,
                required String messageIds,
                Value<bool> isPinned = const Value.absent(),
                required String mcpServerIds,
                Value<String?> assistantId = const Value.absent(),
                Value<int> truncateIndex = const Value.absent(),
                required String versionSelections,
                Value<String?> summary = const Value.absent(),
                Value<int> lastSummarizedMessageCount = const Value.absent(),
                required String chatSuggestions,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                messageIds: messageIds,
                isPinned: isPinned,
                mcpServerIds: mcpServerIds,
                assistantId: assistantId,
                truncateIndex: truncateIndex,
                versionSelections: versionSelections,
                summary: summary,
                lastSummarizedMessageCount: lastSummarizedMessageCount,
                chatSuggestions: chatSuggestions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedData<
                      ConversationRow,
                      $ConversationsTable,
                      MessageRow
                    >(
                      currentTable: table,
                      referencedTable: $$ConversationsTableReferences
                          ._messagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ConversationsTableReferences(
                            db,
                            table,
                            p0,
                          ).messagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
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

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$KelivoDatabase,
      $ConversationsTable,
      ConversationRow,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (ConversationRow, $$ConversationsTableReferences),
      ConversationRow,
      PrefetchHooks Function({bool messagesRefs})
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String role,
      required String content,
      required int timestamp,
      Value<String?> modelId,
      Value<String?> providerId,
      Value<int?> totalTokens,
      required String conversationId,
      Value<bool> isStreaming,
      Value<String?> reasoningText,
      Value<int?> reasoningStartAt,
      Value<int?> reasoningFinishedAt,
      Value<String?> translation,
      Value<String?> reasoningSegmentsJson,
      Value<String?> groupId,
      Value<int> version,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      Value<int?> cachedTokens,
      Value<int?> durationMs,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> role,
      Value<String> content,
      Value<int> timestamp,
      Value<String?> modelId,
      Value<String?> providerId,
      Value<int?> totalTokens,
      Value<String> conversationId,
      Value<bool> isStreaming,
      Value<String?> reasoningText,
      Value<int?> reasoningStartAt,
      Value<int?> reasoningFinishedAt,
      Value<String?> translation,
      Value<String?> reasoningSegmentsJson,
      Value<String?> groupId,
      Value<int> version,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      Value<int?> cachedTokens,
      Value<int?> durationMs,
      Value<int> rowid,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$KelivoDatabase, $MessagesTable, MessageRow> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$KelivoDatabase db) => db
      .conversations
      .createAlias('messages__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ToolEventsTable, List<ToolEventRow>>
  _toolEventsRefsTable(_$KelivoDatabase db) => MultiTypedResultKey.fromTable(
    db.toolEvents,
    aliasName: 'messages__id__tool_events__message_id',
  );

  $$ToolEventsTableProcessedTableManager get toolEventsRefs {
    final manager = $$ToolEventsTableTableManager(
      $_db,
      $_db.toolEvents,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_toolEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$KelivoDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<int> get timestamp => $composableBuilder(
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

  ColumnFilters<int> get reasoningStartAt => $composableBuilder(
    column: $table.reasoningStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reasoningFinishedAt => $composableBuilder(
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

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> toolEventsRefs(
    Expression<bool> Function($$ToolEventsTableFilterComposer f) f,
  ) {
    final $$ToolEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.toolEvents,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ToolEventsTableFilterComposer(
            $db: $db,
            $table: $db.toolEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$KelivoDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$KelivoDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
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

  GeneratedColumn<int> get timestamp =>
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

  GeneratedColumn<int> get reasoningStartAt => $composableBuilder(
    column: $table.reasoningStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reasoningFinishedAt => $composableBuilder(
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

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> toolEventsRefs<T extends Object>(
    Expression<T> Function($$ToolEventsTableAnnotationComposer a) f,
  ) {
    final $$ToolEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.toolEvents,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ToolEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.toolEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$KelivoDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (MessageRow, $$MessagesTableReferences),
          MessageRow,
          PrefetchHooks Function({bool conversationId, bool toolEventsRefs})
        > {
  $$MessagesTableTableManager(_$KelivoDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<int?> totalTokens = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<bool> isStreaming = const Value.absent(),
                Value<String?> reasoningText = const Value.absent(),
                Value<int?> reasoningStartAt = const Value.absent(),
                Value<int?> reasoningFinishedAt = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<String?> reasoningSegmentsJson = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                Value<int?> cachedTokens = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                role: role,
                content: content,
                timestamp: timestamp,
                modelId: modelId,
                providerId: providerId,
                totalTokens: totalTokens,
                conversationId: conversationId,
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
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String role,
                required String content,
                required int timestamp,
                Value<String?> modelId = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<int?> totalTokens = const Value.absent(),
                required String conversationId,
                Value<bool> isStreaming = const Value.absent(),
                Value<String?> reasoningText = const Value.absent(),
                Value<int?> reasoningStartAt = const Value.absent(),
                Value<int?> reasoningFinishedAt = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<String?> reasoningSegmentsJson = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                Value<int?> cachedTokens = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                role: role,
                content: content,
                timestamp: timestamp,
                modelId: modelId,
                providerId: providerId,
                totalTokens: totalTokens,
                conversationId: conversationId,
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
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({conversationId = false, toolEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (toolEventsRefs) db.toolEvents],
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
                                    referencedTable: $$MessagesTableReferences
                                        ._conversationIdTable(db),
                                    referencedColumn: $$MessagesTableReferences
                                        ._conversationIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (toolEventsRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          ToolEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._toolEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).toolEventsRefs,
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

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$KelivoDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, $$MessagesTableReferences),
      MessageRow,
      PrefetchHooks Function({bool conversationId, bool toolEventsRefs})
    >;
typedef $$ToolEventsTableCreateCompanionBuilder =
    ToolEventsCompanion Function({
      required String messageId,
      required String data,
      Value<String?> geminiThoughtSig,
      Value<int> rowid,
    });
typedef $$ToolEventsTableUpdateCompanionBuilder =
    ToolEventsCompanion Function({
      Value<String> messageId,
      Value<String> data,
      Value<String?> geminiThoughtSig,
      Value<int> rowid,
    });

final class $$ToolEventsTableReferences
    extends BaseReferences<_$KelivoDatabase, $ToolEventsTable, ToolEventRow> {
  $$ToolEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MessagesTable _messageIdTable(_$KelivoDatabase db) =>
      db.messages.createAlias('tool_events__message_id__messages__id');

  $$MessagesTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('message_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ToolEventsTableFilterComposer
    extends Composer<_$KelivoDatabase, $ToolEventsTable> {
  $$ToolEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geminiThoughtSig => $composableBuilder(
    column: $table.geminiThoughtSig,
    builder: (column) => ColumnFilters(column),
  );

  $$MessagesTableFilterComposer get messageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolEventsTableOrderingComposer
    extends Composer<_$KelivoDatabase, $ToolEventsTable> {
  $$ToolEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geminiThoughtSig => $composableBuilder(
    column: $table.geminiThoughtSig,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get messageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolEventsTableAnnotationComposer
    extends Composer<_$KelivoDatabase, $ToolEventsTable> {
  $$ToolEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get geminiThoughtSig => $composableBuilder(
    column: $table.geminiThoughtSig,
    builder: (column) => column,
  );

  $$MessagesTableAnnotationComposer get messageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ToolEventsTableTableManager
    extends
        RootTableManager<
          _$KelivoDatabase,
          $ToolEventsTable,
          ToolEventRow,
          $$ToolEventsTableFilterComposer,
          $$ToolEventsTableOrderingComposer,
          $$ToolEventsTableAnnotationComposer,
          $$ToolEventsTableCreateCompanionBuilder,
          $$ToolEventsTableUpdateCompanionBuilder,
          (ToolEventRow, $$ToolEventsTableReferences),
          ToolEventRow,
          PrefetchHooks Function({bool messageId})
        > {
  $$ToolEventsTableTableManager(_$KelivoDatabase db, $ToolEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ToolEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ToolEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ToolEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> geminiThoughtSig = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ToolEventsCompanion(
                messageId: messageId,
                data: data,
                geminiThoughtSig: geminiThoughtSig,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String data,
                Value<String?> geminiThoughtSig = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ToolEventsCompanion.insert(
                messageId: messageId,
                data: data,
                geminiThoughtSig: geminiThoughtSig,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ToolEventsTableReferences(db, table, e),
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
                                referencedTable: $$ToolEventsTableReferences
                                    ._messageIdTable(db),
                                referencedColumn: $$ToolEventsTableReferences
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

typedef $$ToolEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$KelivoDatabase,
      $ToolEventsTable,
      ToolEventRow,
      $$ToolEventsTableFilterComposer,
      $$ToolEventsTableOrderingComposer,
      $$ToolEventsTableAnnotationComposer,
      $$ToolEventsTableCreateCompanionBuilder,
      $$ToolEventsTableUpdateCompanionBuilder,
      (ToolEventRow, $$ToolEventsTableReferences),
      ToolEventRow,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$MigrationMetaTableCreateCompanionBuilder =
    MigrationMetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MigrationMetaTableUpdateCompanionBuilder =
    MigrationMetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MigrationMetaTableFilterComposer
    extends Composer<_$KelivoDatabase, $MigrationMetaTable> {
  $$MigrationMetaTableFilterComposer({
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

class $$MigrationMetaTableOrderingComposer
    extends Composer<_$KelivoDatabase, $MigrationMetaTable> {
  $$MigrationMetaTableOrderingComposer({
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

class $$MigrationMetaTableAnnotationComposer
    extends Composer<_$KelivoDatabase, $MigrationMetaTable> {
  $$MigrationMetaTableAnnotationComposer({
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

class $$MigrationMetaTableTableManager
    extends
        RootTableManager<
          _$KelivoDatabase,
          $MigrationMetaTable,
          MigrationMetaRow,
          $$MigrationMetaTableFilterComposer,
          $$MigrationMetaTableOrderingComposer,
          $$MigrationMetaTableAnnotationComposer,
          $$MigrationMetaTableCreateCompanionBuilder,
          $$MigrationMetaTableUpdateCompanionBuilder,
          (
            MigrationMetaRow,
            BaseReferences<
              _$KelivoDatabase,
              $MigrationMetaTable,
              MigrationMetaRow
            >,
          ),
          MigrationMetaRow,
          PrefetchHooks Function()
        > {
  $$MigrationMetaTableTableManager(
    _$KelivoDatabase db,
    $MigrationMetaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MigrationMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MigrationMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MigrationMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  MigrationMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MigrationMetaCompanion.insert(
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

typedef $$MigrationMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$KelivoDatabase,
      $MigrationMetaTable,
      MigrationMetaRow,
      $$MigrationMetaTableFilterComposer,
      $$MigrationMetaTableOrderingComposer,
      $$MigrationMetaTableAnnotationComposer,
      $$MigrationMetaTableCreateCompanionBuilder,
      $$MigrationMetaTableUpdateCompanionBuilder,
      (
        MigrationMetaRow,
        BaseReferences<_$KelivoDatabase, $MigrationMetaTable, MigrationMetaRow>,
      ),
      MigrationMetaRow,
      PrefetchHooks Function()
    >;

class $KelivoDatabaseManager {
  final _$KelivoDatabase _db;
  $KelivoDatabaseManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ToolEventsTableTableManager get toolEvents =>
      $$ToolEventsTableTableManager(_db, _db.toolEvents);
  $$MigrationMetaTableTableManager get migrationMeta =>
      $$MigrationMetaTableTableManager(_db, _db.migrationMeta);
}
