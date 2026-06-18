// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_database.dart';

// ignore_for_file: type=lint
class $ChatConversationsTable extends ChatConversations
    with TableInfo<$ChatConversationsTable, ChatConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMsMeta =
      const VerificationMeta('createdAtMs');
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
      'created_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMsMeta =
      const VerificationMeta('updatedAtMs');
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
      'updated_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _mcpServerIdsJsonMeta =
      const VerificationMeta('mcpServerIdsJson');
  @override
  late final GeneratedColumn<String> mcpServerIdsJson = GeneratedColumn<String>(
      'mcp_server_ids_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _assistantIdMeta =
      const VerificationMeta('assistantId');
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
      'assistant_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _truncateIndexMeta =
      const VerificationMeta('truncateIndex');
  @override
  late final GeneratedColumn<int> truncateIndex = GeneratedColumn<int>(
      'truncate_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(-1));
  static const VerificationMeta _versionSelectionsJsonMeta =
      const VerificationMeta('versionSelectionsJson');
  @override
  late final GeneratedColumn<String> versionSelectionsJson =
      GeneratedColumn<String>('version_selections_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('{}'));
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastSummarizedMessageCountMeta =
      const VerificationMeta('lastSummarizedMessageCount');
  @override
  late final GeneratedColumn<int> lastSummarizedMessageCount =
      GeneratedColumn<int>('last_summarized_message_count', aliasedName, false,
          type: DriftSqlType.int,
          requiredDuringInsert: false,
          defaultValue: const Constant(0));
  static const VerificationMeta _chatSuggestionsJsonMeta =
      const VerificationMeta('chatSuggestionsJson');
  @override
  late final GeneratedColumn<String> chatSuggestionsJson =
      GeneratedColumn<String>('chat_suggestions_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        createdAtMs,
        updatedAtMs,
        isPinned,
        mcpServerIdsJson,
        assistantId,
        truncateIndex,
        versionSelectionsJson,
        summary,
        lastSummarizedMessageCount,
        chatSuggestionsJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_conversations';
  @override
  VerificationContext validateIntegrity(Insertable<ChatConversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
          _createdAtMsMeta,
          createdAtMs.isAcceptableOrUnknown(
              data['created_at_ms']!, _createdAtMsMeta));
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
          _updatedAtMsMeta,
          updatedAtMs.isAcceptableOrUnknown(
              data['updated_at_ms']!, _updatedAtMsMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('mcp_server_ids_json')) {
      context.handle(
          _mcpServerIdsJsonMeta,
          mcpServerIdsJson.isAcceptableOrUnknown(
              data['mcp_server_ids_json']!, _mcpServerIdsJsonMeta));
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
          _assistantIdMeta,
          assistantId.isAcceptableOrUnknown(
              data['assistant_id']!, _assistantIdMeta));
    }
    if (data.containsKey('truncate_index')) {
      context.handle(
          _truncateIndexMeta,
          truncateIndex.isAcceptableOrUnknown(
              data['truncate_index']!, _truncateIndexMeta));
    }
    if (data.containsKey('version_selections_json')) {
      context.handle(
          _versionSelectionsJsonMeta,
          versionSelectionsJson.isAcceptableOrUnknown(
              data['version_selections_json']!, _versionSelectionsJsonMeta));
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    }
    if (data.containsKey('last_summarized_message_count')) {
      context.handle(
          _lastSummarizedMessageCountMeta,
          lastSummarizedMessageCount.isAcceptableOrUnknown(
              data['last_summarized_message_count']!,
              _lastSummarizedMessageCountMeta));
    }
    if (data.containsKey('chat_suggestions_json')) {
      context.handle(
          _chatSuggestionsJsonMeta,
          chatSuggestionsJson.isAcceptableOrUnknown(
              data['chat_suggestions_json']!, _chatSuggestionsJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatConversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      createdAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at_ms'])!,
      updatedAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at_ms'])!,
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      mcpServerIdsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}mcp_server_ids_json'])!,
      assistantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}assistant_id']),
      truncateIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}truncate_index'])!,
      versionSelectionsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}version_selections_json'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary']),
      lastSummarizedMessageCount: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_summarized_message_count'])!,
      chatSuggestionsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}chat_suggestions_json'])!,
    );
  }

  @override
  $ChatConversationsTable createAlias(String alias) {
    return $ChatConversationsTable(attachedDatabase, alias);
  }
}

class ChatConversation extends DataClass
    implements Insertable<ChatConversation> {
  final String id;
  final String title;
  final int createdAtMs;
  final int updatedAtMs;
  final bool isPinned;
  final String mcpServerIdsJson;
  final String? assistantId;
  final int truncateIndex;
  final String versionSelectionsJson;
  final String? summary;
  final int lastSummarizedMessageCount;
  final String chatSuggestionsJson;
  const ChatConversation(
      {required this.id,
      required this.title,
      required this.createdAtMs,
      required this.updatedAtMs,
      required this.isPinned,
      required this.mcpServerIdsJson,
      this.assistantId,
      required this.truncateIndex,
      required this.versionSelectionsJson,
      this.summary,
      required this.lastSummarizedMessageCount,
      required this.chatSuggestionsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['mcp_server_ids_json'] = Variable<String>(mcpServerIdsJson);
    if (!nullToAbsent || assistantId != null) {
      map['assistant_id'] = Variable<String>(assistantId);
    }
    map['truncate_index'] = Variable<int>(truncateIndex);
    map['version_selections_json'] = Variable<String>(versionSelectionsJson);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['last_summarized_message_count'] =
        Variable<int>(lastSummarizedMessageCount);
    map['chat_suggestions_json'] = Variable<String>(chatSuggestionsJson);
    return map;
  }

  ChatConversationsCompanion toCompanion(bool nullToAbsent) {
    return ChatConversationsCompanion(
      id: Value(id),
      title: Value(title),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
      isPinned: Value(isPinned),
      mcpServerIdsJson: Value(mcpServerIdsJson),
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

  factory ChatConversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatConversation(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      mcpServerIdsJson: serializer.fromJson<String>(json['mcpServerIdsJson']),
      assistantId: serializer.fromJson<String?>(json['assistantId']),
      truncateIndex: serializer.fromJson<int>(json['truncateIndex']),
      versionSelectionsJson:
          serializer.fromJson<String>(json['versionSelectionsJson']),
      summary: serializer.fromJson<String?>(json['summary']),
      lastSummarizedMessageCount:
          serializer.fromJson<int>(json['lastSummarizedMessageCount']),
      chatSuggestionsJson:
          serializer.fromJson<String>(json['chatSuggestionsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'isPinned': serializer.toJson<bool>(isPinned),
      'mcpServerIdsJson': serializer.toJson<String>(mcpServerIdsJson),
      'assistantId': serializer.toJson<String?>(assistantId),
      'truncateIndex': serializer.toJson<int>(truncateIndex),
      'versionSelectionsJson': serializer.toJson<String>(versionSelectionsJson),
      'summary': serializer.toJson<String?>(summary),
      'lastSummarizedMessageCount':
          serializer.toJson<int>(lastSummarizedMessageCount),
      'chatSuggestionsJson': serializer.toJson<String>(chatSuggestionsJson),
    };
  }

  ChatConversation copyWith(
          {String? id,
          String? title,
          int? createdAtMs,
          int? updatedAtMs,
          bool? isPinned,
          String? mcpServerIdsJson,
          Value<String?> assistantId = const Value.absent(),
          int? truncateIndex,
          String? versionSelectionsJson,
          Value<String?> summary = const Value.absent(),
          int? lastSummarizedMessageCount,
          String? chatSuggestionsJson}) =>
      ChatConversation(
        id: id ?? this.id,
        title: title ?? this.title,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        isPinned: isPinned ?? this.isPinned,
        mcpServerIdsJson: mcpServerIdsJson ?? this.mcpServerIdsJson,
        assistantId: assistantId.present ? assistantId.value : this.assistantId,
        truncateIndex: truncateIndex ?? this.truncateIndex,
        versionSelectionsJson:
            versionSelectionsJson ?? this.versionSelectionsJson,
        summary: summary.present ? summary.value : this.summary,
        lastSummarizedMessageCount:
            lastSummarizedMessageCount ?? this.lastSummarizedMessageCount,
        chatSuggestionsJson: chatSuggestionsJson ?? this.chatSuggestionsJson,
      );
  ChatConversation copyWithCompanion(ChatConversationsCompanion data) {
    return ChatConversation(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAtMs:
          data.createdAtMs.present ? data.createdAtMs.value : this.createdAtMs,
      updatedAtMs:
          data.updatedAtMs.present ? data.updatedAtMs.value : this.updatedAtMs,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      mcpServerIdsJson: data.mcpServerIdsJson.present
          ? data.mcpServerIdsJson.value
          : this.mcpServerIdsJson,
      assistantId:
          data.assistantId.present ? data.assistantId.value : this.assistantId,
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
    return (StringBuffer('ChatConversation(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('isPinned: $isPinned, ')
          ..write('mcpServerIdsJson: $mcpServerIdsJson, ')
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
      createdAtMs,
      updatedAtMs,
      isPinned,
      mcpServerIdsJson,
      assistantId,
      truncateIndex,
      versionSelectionsJson,
      summary,
      lastSummarizedMessageCount,
      chatSuggestionsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatConversation &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs &&
          other.isPinned == this.isPinned &&
          other.mcpServerIdsJson == this.mcpServerIdsJson &&
          other.assistantId == this.assistantId &&
          other.truncateIndex == this.truncateIndex &&
          other.versionSelectionsJson == this.versionSelectionsJson &&
          other.summary == this.summary &&
          other.lastSummarizedMessageCount == this.lastSummarizedMessageCount &&
          other.chatSuggestionsJson == this.chatSuggestionsJson);
}

class ChatConversationsCompanion extends UpdateCompanion<ChatConversation> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<bool> isPinned;
  final Value<String> mcpServerIdsJson;
  final Value<String?> assistantId;
  final Value<int> truncateIndex;
  final Value<String> versionSelectionsJson;
  final Value<String?> summary;
  final Value<int> lastSummarizedMessageCount;
  final Value<String> chatSuggestionsJson;
  final Value<int> rowid;
  const ChatConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.mcpServerIdsJson = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.truncateIndex = const Value.absent(),
    this.versionSelectionsJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.lastSummarizedMessageCount = const Value.absent(),
    this.chatSuggestionsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatConversationsCompanion.insert({
    required String id,
    required String title,
    required int createdAtMs,
    required int updatedAtMs,
    this.isPinned = const Value.absent(),
    this.mcpServerIdsJson = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.truncateIndex = const Value.absent(),
    this.versionSelectionsJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.lastSummarizedMessageCount = const Value.absent(),
    this.chatSuggestionsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        createdAtMs = Value(createdAtMs),
        updatedAtMs = Value(updatedAtMs);
  static Insertable<ChatConversation> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<bool>? isPinned,
    Expression<String>? mcpServerIdsJson,
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
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (isPinned != null) 'is_pinned': isPinned,
      if (mcpServerIdsJson != null) 'mcp_server_ids_json': mcpServerIdsJson,
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

  ChatConversationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<int>? createdAtMs,
      Value<int>? updatedAtMs,
      Value<bool>? isPinned,
      Value<String>? mcpServerIdsJson,
      Value<String?>? assistantId,
      Value<int>? truncateIndex,
      Value<String>? versionSelectionsJson,
      Value<String?>? summary,
      Value<int>? lastSummarizedMessageCount,
      Value<String>? chatSuggestionsJson,
      Value<int>? rowid}) {
    return ChatConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      isPinned: isPinned ?? this.isPinned,
      mcpServerIdsJson: mcpServerIdsJson ?? this.mcpServerIdsJson,
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
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (mcpServerIdsJson.present) {
      map['mcp_server_ids_json'] = Variable<String>(mcpServerIdsJson.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (truncateIndex.present) {
      map['truncate_index'] = Variable<int>(truncateIndex.value);
    }
    if (versionSelectionsJson.present) {
      map['version_selections_json'] =
          Variable<String>(versionSelectionsJson.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (lastSummarizedMessageCount.present) {
      map['last_summarized_message_count'] =
          Variable<int>(lastSummarizedMessageCount.value);
    }
    if (chatSuggestionsJson.present) {
      map['chat_suggestions_json'] =
          Variable<String>(chatSuggestionsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('isPinned: $isPinned, ')
          ..write('mcpServerIdsJson: $mcpServerIdsJson, ')
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

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES chat_conversations (id) ON DELETE CASCADE'));
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMsMeta =
      const VerificationMeta('timestampMs');
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
      'timestamp_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _modelIdMeta =
      const VerificationMeta('modelId');
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
      'model_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _totalTokensMeta =
      const VerificationMeta('totalTokens');
  @override
  late final GeneratedColumn<int> totalTokens = GeneratedColumn<int>(
      'total_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isStreamingMeta =
      const VerificationMeta('isStreaming');
  @override
  late final GeneratedColumn<bool> isStreaming = GeneratedColumn<bool>(
      'is_streaming', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_streaming" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _reasoningTextMeta =
      const VerificationMeta('reasoningText');
  @override
  late final GeneratedColumn<String> reasoningText = GeneratedColumn<String>(
      'reasoning_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reasoningStartAtMsMeta =
      const VerificationMeta('reasoningStartAtMs');
  @override
  late final GeneratedColumn<int> reasoningStartAtMs = GeneratedColumn<int>(
      'reasoning_start_at_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reasoningFinishedAtMsMeta =
      const VerificationMeta('reasoningFinishedAtMs');
  @override
  late final GeneratedColumn<int> reasoningFinishedAtMs = GeneratedColumn<int>(
      'reasoning_finished_at_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _translationMeta =
      const VerificationMeta('translation');
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
      'translation', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reasoningSegmentsJsonMeta =
      const VerificationMeta('reasoningSegmentsJson');
  @override
  late final GeneratedColumn<String> reasoningSegmentsJson =
      GeneratedColumn<String>('reasoning_segments_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _promptTokensMeta =
      const VerificationMeta('promptTokens');
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
      'prompt_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _completionTokensMeta =
      const VerificationMeta('completionTokens');
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
      'completion_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _cachedTokensMeta =
      const VerificationMeta('cachedTokens');
  @override
  late final GeneratedColumn<int> cachedTokens = GeneratedColumn<int>(
      'cached_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _messageOrderMeta =
      const VerificationMeta('messageOrder');
  @override
  late final GeneratedColumn<int> messageOrder = GeneratedColumn<int>(
      'message_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        role,
        content,
        timestampMs,
        modelId,
        providerId,
        totalTokens,
        isStreaming,
        reasoningText,
        reasoningStartAtMs,
        reasoningFinishedAtMs,
        translation,
        reasoningSegmentsJson,
        groupId,
        version,
        promptTokens,
        completionTokens,
        cachedTokens,
        durationMs,
        messageOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(Insertable<ChatMessage> instance,
      {bool isInserting = false}) {
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
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
          _timestampMsMeta,
          timestampMs.isAcceptableOrUnknown(
              data['timestamp_ms']!, _timestampMsMeta));
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(_modelIdMeta,
          modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    }
    if (data.containsKey('total_tokens')) {
      context.handle(
          _totalTokensMeta,
          totalTokens.isAcceptableOrUnknown(
              data['total_tokens']!, _totalTokensMeta));
    }
    if (data.containsKey('is_streaming')) {
      context.handle(
          _isStreamingMeta,
          isStreaming.isAcceptableOrUnknown(
              data['is_streaming']!, _isStreamingMeta));
    }
    if (data.containsKey('reasoning_text')) {
      context.handle(
          _reasoningTextMeta,
          reasoningText.isAcceptableOrUnknown(
              data['reasoning_text']!, _reasoningTextMeta));
    }
    if (data.containsKey('reasoning_start_at_ms')) {
      context.handle(
          _reasoningStartAtMsMeta,
          reasoningStartAtMs.isAcceptableOrUnknown(
              data['reasoning_start_at_ms']!, _reasoningStartAtMsMeta));
    }
    if (data.containsKey('reasoning_finished_at_ms')) {
      context.handle(
          _reasoningFinishedAtMsMeta,
          reasoningFinishedAtMs.isAcceptableOrUnknown(
              data['reasoning_finished_at_ms']!, _reasoningFinishedAtMsMeta));
    }
    if (data.containsKey('translation')) {
      context.handle(
          _translationMeta,
          translation.isAcceptableOrUnknown(
              data['translation']!, _translationMeta));
    }
    if (data.containsKey('reasoning_segments_json')) {
      context.handle(
          _reasoningSegmentsJsonMeta,
          reasoningSegmentsJson.isAcceptableOrUnknown(
              data['reasoning_segments_json']!, _reasoningSegmentsJsonMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
          _promptTokensMeta,
          promptTokens.isAcceptableOrUnknown(
              data['prompt_tokens']!, _promptTokensMeta));
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
          _completionTokensMeta,
          completionTokens.isAcceptableOrUnknown(
              data['completion_tokens']!, _completionTokensMeta));
    }
    if (data.containsKey('cached_tokens')) {
      context.handle(
          _cachedTokensMeta,
          cachedTokens.isAcceptableOrUnknown(
              data['cached_tokens']!, _cachedTokensMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('message_order')) {
      context.handle(
          _messageOrderMeta,
          messageOrder.isAcceptableOrUnknown(
              data['message_order']!, _messageOrderMeta));
    } else if (isInserting) {
      context.missing(_messageOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      timestampMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}timestamp_ms'])!,
      modelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_id']),
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id']),
      totalTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_tokens']),
      isStreaming: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_streaming'])!,
      reasoningText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reasoning_text']),
      reasoningStartAtMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}reasoning_start_at_ms']),
      reasoningFinishedAtMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}reasoning_finished_at_ms']),
      translation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}translation']),
      reasoningSegmentsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reasoning_segments_json']),
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      promptTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}prompt_tokens']),
      completionTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completion_tokens']),
      cachedTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_tokens']),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      messageOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}message_order'])!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final int timestampMs;
  final String? modelId;
  final String? providerId;
  final int? totalTokens;
  final bool isStreaming;
  final String? reasoningText;
  final int? reasoningStartAtMs;
  final int? reasoningFinishedAtMs;
  final String? translation;
  final String? reasoningSegmentsJson;
  final String? groupId;
  final int version;
  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? durationMs;
  final int messageOrder;
  const ChatMessage(
      {required this.id,
      required this.conversationId,
      required this.role,
      required this.content,
      required this.timestampMs,
      this.modelId,
      this.providerId,
      this.totalTokens,
      required this.isStreaming,
      this.reasoningText,
      this.reasoningStartAtMs,
      this.reasoningFinishedAtMs,
      this.translation,
      this.reasoningSegmentsJson,
      this.groupId,
      required this.version,
      this.promptTokens,
      this.completionTokens,
      this.cachedTokens,
      this.durationMs,
      required this.messageOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['timestamp_ms'] = Variable<int>(timestampMs);
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
    if (!nullToAbsent || reasoningStartAtMs != null) {
      map['reasoning_start_at_ms'] = Variable<int>(reasoningStartAtMs);
    }
    if (!nullToAbsent || reasoningFinishedAtMs != null) {
      map['reasoning_finished_at_ms'] = Variable<int>(reasoningFinishedAtMs);
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

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      timestampMs: Value(timestampMs),
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
      reasoningStartAtMs: reasoningStartAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningStartAtMs),
      reasoningFinishedAtMs: reasoningFinishedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningFinishedAtMs),
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

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      providerId: serializer.fromJson<String?>(json['providerId']),
      totalTokens: serializer.fromJson<int?>(json['totalTokens']),
      isStreaming: serializer.fromJson<bool>(json['isStreaming']),
      reasoningText: serializer.fromJson<String?>(json['reasoningText']),
      reasoningStartAtMs: serializer.fromJson<int?>(json['reasoningStartAtMs']),
      reasoningFinishedAtMs:
          serializer.fromJson<int?>(json['reasoningFinishedAtMs']),
      translation: serializer.fromJson<String?>(json['translation']),
      reasoningSegmentsJson:
          serializer.fromJson<String?>(json['reasoningSegmentsJson']),
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
      'timestampMs': serializer.toJson<int>(timestampMs),
      'modelId': serializer.toJson<String?>(modelId),
      'providerId': serializer.toJson<String?>(providerId),
      'totalTokens': serializer.toJson<int?>(totalTokens),
      'isStreaming': serializer.toJson<bool>(isStreaming),
      'reasoningText': serializer.toJson<String?>(reasoningText),
      'reasoningStartAtMs': serializer.toJson<int?>(reasoningStartAtMs),
      'reasoningFinishedAtMs': serializer.toJson<int?>(reasoningFinishedAtMs),
      'translation': serializer.toJson<String?>(translation),
      'reasoningSegmentsJson':
          serializer.toJson<String?>(reasoningSegmentsJson),
      'groupId': serializer.toJson<String?>(groupId),
      'version': serializer.toJson<int>(version),
      'promptTokens': serializer.toJson<int?>(promptTokens),
      'completionTokens': serializer.toJson<int?>(completionTokens),
      'cachedTokens': serializer.toJson<int?>(cachedTokens),
      'durationMs': serializer.toJson<int?>(durationMs),
      'messageOrder': serializer.toJson<int>(messageOrder),
    };
  }

  ChatMessage copyWith(
          {String? id,
          String? conversationId,
          String? role,
          String? content,
          int? timestampMs,
          Value<String?> modelId = const Value.absent(),
          Value<String?> providerId = const Value.absent(),
          Value<int?> totalTokens = const Value.absent(),
          bool? isStreaming,
          Value<String?> reasoningText = const Value.absent(),
          Value<int?> reasoningStartAtMs = const Value.absent(),
          Value<int?> reasoningFinishedAtMs = const Value.absent(),
          Value<String?> translation = const Value.absent(),
          Value<String?> reasoningSegmentsJson = const Value.absent(),
          Value<String?> groupId = const Value.absent(),
          int? version,
          Value<int?> promptTokens = const Value.absent(),
          Value<int?> completionTokens = const Value.absent(),
          Value<int?> cachedTokens = const Value.absent(),
          Value<int?> durationMs = const Value.absent(),
          int? messageOrder}) =>
      ChatMessage(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        role: role ?? this.role,
        content: content ?? this.content,
        timestampMs: timestampMs ?? this.timestampMs,
        modelId: modelId.present ? modelId.value : this.modelId,
        providerId: providerId.present ? providerId.value : this.providerId,
        totalTokens: totalTokens.present ? totalTokens.value : this.totalTokens,
        isStreaming: isStreaming ?? this.isStreaming,
        reasoningText:
            reasoningText.present ? reasoningText.value : this.reasoningText,
        reasoningStartAtMs: reasoningStartAtMs.present
            ? reasoningStartAtMs.value
            : this.reasoningStartAtMs,
        reasoningFinishedAtMs: reasoningFinishedAtMs.present
            ? reasoningFinishedAtMs.value
            : this.reasoningFinishedAtMs,
        translation: translation.present ? translation.value : this.translation,
        reasoningSegmentsJson: reasoningSegmentsJson.present
            ? reasoningSegmentsJson.value
            : this.reasoningSegmentsJson,
        groupId: groupId.present ? groupId.value : this.groupId,
        version: version ?? this.version,
        promptTokens:
            promptTokens.present ? promptTokens.value : this.promptTokens,
        completionTokens: completionTokens.present
            ? completionTokens.value
            : this.completionTokens,
        cachedTokens:
            cachedTokens.present ? cachedTokens.value : this.cachedTokens,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        messageOrder: messageOrder ?? this.messageOrder,
      );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      timestampMs:
          data.timestampMs.present ? data.timestampMs.value : this.timestampMs,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      totalTokens:
          data.totalTokens.present ? data.totalTokens.value : this.totalTokens,
      isStreaming:
          data.isStreaming.present ? data.isStreaming.value : this.isStreaming,
      reasoningText: data.reasoningText.present
          ? data.reasoningText.value
          : this.reasoningText,
      reasoningStartAtMs: data.reasoningStartAtMs.present
          ? data.reasoningStartAtMs.value
          : this.reasoningStartAtMs,
      reasoningFinishedAtMs: data.reasoningFinishedAtMs.present
          ? data.reasoningFinishedAtMs.value
          : this.reasoningFinishedAtMs,
      translation:
          data.translation.present ? data.translation.value : this.translation,
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
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      messageOrder: data.messageOrder.present
          ? data.messageOrder.value
          : this.messageOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('modelId: $modelId, ')
          ..write('providerId: $providerId, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('reasoningText: $reasoningText, ')
          ..write('reasoningStartAtMs: $reasoningStartAtMs, ')
          ..write('reasoningFinishedAtMs: $reasoningFinishedAtMs, ')
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
        timestampMs,
        modelId,
        providerId,
        totalTokens,
        isStreaming,
        reasoningText,
        reasoningStartAtMs,
        reasoningFinishedAtMs,
        translation,
        reasoningSegmentsJson,
        groupId,
        version,
        promptTokens,
        completionTokens,
        cachedTokens,
        durationMs,
        messageOrder
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.timestampMs == this.timestampMs &&
          other.modelId == this.modelId &&
          other.providerId == this.providerId &&
          other.totalTokens == this.totalTokens &&
          other.isStreaming == this.isStreaming &&
          other.reasoningText == this.reasoningText &&
          other.reasoningStartAtMs == this.reasoningStartAtMs &&
          other.reasoningFinishedAtMs == this.reasoningFinishedAtMs &&
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

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<int> timestampMs;
  final Value<String?> modelId;
  final Value<String?> providerId;
  final Value<int?> totalTokens;
  final Value<bool> isStreaming;
  final Value<String?> reasoningText;
  final Value<int?> reasoningStartAtMs;
  final Value<int?> reasoningFinishedAtMs;
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
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.modelId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.isStreaming = const Value.absent(),
    this.reasoningText = const Value.absent(),
    this.reasoningStartAtMs = const Value.absent(),
    this.reasoningFinishedAtMs = const Value.absent(),
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
  ChatMessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String role,
    required String content,
    required int timestampMs,
    this.modelId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.isStreaming = const Value.absent(),
    this.reasoningText = const Value.absent(),
    this.reasoningStartAtMs = const Value.absent(),
    this.reasoningFinishedAtMs = const Value.absent(),
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
  })  : id = Value(id),
        conversationId = Value(conversationId),
        role = Value(role),
        content = Value(content),
        timestampMs = Value(timestampMs),
        messageOrder = Value(messageOrder);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<int>? timestampMs,
    Expression<String>? modelId,
    Expression<String>? providerId,
    Expression<int>? totalTokens,
    Expression<bool>? isStreaming,
    Expression<String>? reasoningText,
    Expression<int>? reasoningStartAtMs,
    Expression<int>? reasoningFinishedAtMs,
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
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (modelId != null) 'model_id': modelId,
      if (providerId != null) 'provider_id': providerId,
      if (totalTokens != null) 'total_tokens': totalTokens,
      if (isStreaming != null) 'is_streaming': isStreaming,
      if (reasoningText != null) 'reasoning_text': reasoningText,
      if (reasoningStartAtMs != null)
        'reasoning_start_at_ms': reasoningStartAtMs,
      if (reasoningFinishedAtMs != null)
        'reasoning_finished_at_ms': reasoningFinishedAtMs,
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

  ChatMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? conversationId,
      Value<String>? role,
      Value<String>? content,
      Value<int>? timestampMs,
      Value<String?>? modelId,
      Value<String?>? providerId,
      Value<int?>? totalTokens,
      Value<bool>? isStreaming,
      Value<String?>? reasoningText,
      Value<int?>? reasoningStartAtMs,
      Value<int?>? reasoningFinishedAtMs,
      Value<String?>? translation,
      Value<String?>? reasoningSegmentsJson,
      Value<String?>? groupId,
      Value<int>? version,
      Value<int?>? promptTokens,
      Value<int?>? completionTokens,
      Value<int?>? cachedTokens,
      Value<int?>? durationMs,
      Value<int>? messageOrder,
      Value<int>? rowid}) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestampMs: timestampMs ?? this.timestampMs,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      totalTokens: totalTokens ?? this.totalTokens,
      isStreaming: isStreaming ?? this.isStreaming,
      reasoningText: reasoningText ?? this.reasoningText,
      reasoningStartAtMs: reasoningStartAtMs ?? this.reasoningStartAtMs,
      reasoningFinishedAtMs:
          reasoningFinishedAtMs ?? this.reasoningFinishedAtMs,
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
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
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
    if (reasoningStartAtMs.present) {
      map['reasoning_start_at_ms'] = Variable<int>(reasoningStartAtMs.value);
    }
    if (reasoningFinishedAtMs.present) {
      map['reasoning_finished_at_ms'] =
          Variable<int>(reasoningFinishedAtMs.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (reasoningSegmentsJson.present) {
      map['reasoning_segments_json'] =
          Variable<String>(reasoningSegmentsJson.value);
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
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('modelId: $modelId, ')
          ..write('providerId: $providerId, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('reasoningText: $reasoningText, ')
          ..write('reasoningStartAtMs: $reasoningStartAtMs, ')
          ..write('reasoningFinishedAtMs: $reasoningFinishedAtMs, ')
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

class $ChatToolEventsTable extends ChatToolEvents
    with TableInfo<$ChatToolEventsTable, ChatToolEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatToolEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES chat_messages (id) ON DELETE CASCADE'));
  static const VerificationMeta _eventsJsonMeta =
      const VerificationMeta('eventsJson');
  @override
  late final GeneratedColumn<String> eventsJson = GeneratedColumn<String>(
      'events_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [messageId, eventsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_tool_events';
  @override
  VerificationContext validateIntegrity(Insertable<ChatToolEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('events_json')) {
      context.handle(
          _eventsJsonMeta,
          eventsJson.isAcceptableOrUnknown(
              data['events_json']!, _eventsJsonMeta));
    } else if (isInserting) {
      context.missing(_eventsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  ChatToolEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatToolEvent(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      eventsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}events_json'])!,
    );
  }

  @override
  $ChatToolEventsTable createAlias(String alias) {
    return $ChatToolEventsTable(attachedDatabase, alias);
  }
}

class ChatToolEvent extends DataClass implements Insertable<ChatToolEvent> {
  final String messageId;
  final String eventsJson;
  const ChatToolEvent({required this.messageId, required this.eventsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['events_json'] = Variable<String>(eventsJson);
    return map;
  }

  ChatToolEventsCompanion toCompanion(bool nullToAbsent) {
    return ChatToolEventsCompanion(
      messageId: Value(messageId),
      eventsJson: Value(eventsJson),
    );
  }

  factory ChatToolEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatToolEvent(
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

  ChatToolEvent copyWith({String? messageId, String? eventsJson}) =>
      ChatToolEvent(
        messageId: messageId ?? this.messageId,
        eventsJson: eventsJson ?? this.eventsJson,
      );
  ChatToolEvent copyWithCompanion(ChatToolEventsCompanion data) {
    return ChatToolEvent(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      eventsJson:
          data.eventsJson.present ? data.eventsJson.value : this.eventsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatToolEvent(')
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
      (other is ChatToolEvent &&
          other.messageId == this.messageId &&
          other.eventsJson == this.eventsJson);
}

class ChatToolEventsCompanion extends UpdateCompanion<ChatToolEvent> {
  final Value<String> messageId;
  final Value<String> eventsJson;
  final Value<int> rowid;
  const ChatToolEventsCompanion({
    this.messageId = const Value.absent(),
    this.eventsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatToolEventsCompanion.insert({
    required String messageId,
    required String eventsJson,
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        eventsJson = Value(eventsJson);
  static Insertable<ChatToolEvent> custom({
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

  ChatToolEventsCompanion copyWith(
      {Value<String>? messageId,
      Value<String>? eventsJson,
      Value<int>? rowid}) {
    return ChatToolEventsCompanion(
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
    return (StringBuffer('ChatToolEventsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('eventsJson: $eventsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatGeminiThoughtSignaturesTable extends ChatGeminiThoughtSignatures
    with
        TableInfo<$ChatGeminiThoughtSignaturesTable,
            ChatGeminiThoughtSignature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatGeminiThoughtSignaturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES chat_messages (id) ON DELETE CASCADE'));
  static const VerificationMeta _signatureMeta =
      const VerificationMeta('signature');
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
      'signature', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [messageId, signature];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_gemini_thought_signatures';
  @override
  VerificationContext validateIntegrity(
      Insertable<ChatGeminiThoughtSignature> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(_signatureMeta,
          signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta));
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  ChatGeminiThoughtSignature map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatGeminiThoughtSignature(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      signature: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}signature'])!,
    );
  }

  @override
  $ChatGeminiThoughtSignaturesTable createAlias(String alias) {
    return $ChatGeminiThoughtSignaturesTable(attachedDatabase, alias);
  }
}

class ChatGeminiThoughtSignature extends DataClass
    implements Insertable<ChatGeminiThoughtSignature> {
  final String messageId;
  final String signature;
  const ChatGeminiThoughtSignature(
      {required this.messageId, required this.signature});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['signature'] = Variable<String>(signature);
    return map;
  }

  ChatGeminiThoughtSignaturesCompanion toCompanion(bool nullToAbsent) {
    return ChatGeminiThoughtSignaturesCompanion(
      messageId: Value(messageId),
      signature: Value(signature),
    );
  }

  factory ChatGeminiThoughtSignature.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatGeminiThoughtSignature(
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

  ChatGeminiThoughtSignature copyWith({String? messageId, String? signature}) =>
      ChatGeminiThoughtSignature(
        messageId: messageId ?? this.messageId,
        signature: signature ?? this.signature,
      );
  ChatGeminiThoughtSignature copyWithCompanion(
      ChatGeminiThoughtSignaturesCompanion data) {
    return ChatGeminiThoughtSignature(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      signature: data.signature.present ? data.signature.value : this.signature,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatGeminiThoughtSignature(')
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
      (other is ChatGeminiThoughtSignature &&
          other.messageId == this.messageId &&
          other.signature == this.signature);
}

class ChatGeminiThoughtSignaturesCompanion
    extends UpdateCompanion<ChatGeminiThoughtSignature> {
  final Value<String> messageId;
  final Value<String> signature;
  final Value<int> rowid;
  const ChatGeminiThoughtSignaturesCompanion({
    this.messageId = const Value.absent(),
    this.signature = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatGeminiThoughtSignaturesCompanion.insert({
    required String messageId,
    required String signature,
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        signature = Value(signature);
  static Insertable<ChatGeminiThoughtSignature> custom({
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

  ChatGeminiThoughtSignaturesCompanion copyWith(
      {Value<String>? messageId, Value<String>? signature, Value<int>? rowid}) {
    return ChatGeminiThoughtSignaturesCompanion(
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
    return (StringBuffer('ChatGeminiThoughtSignaturesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('signature: $signature, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMetaTable extends ChatMeta
    with TableInfo<$ChatMetaTable, ChatMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_meta';
  @override
  VerificationContext validateIntegrity(Insertable<ChatMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ChatMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMetaData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $ChatMetaTable createAlias(String alias) {
    return $ChatMetaTable(attachedDatabase, alias);
  }
}

class ChatMetaData extends DataClass implements Insertable<ChatMetaData> {
  final String key;
  final String value;
  const ChatMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ChatMetaCompanion toCompanion(bool nullToAbsent) {
    return ChatMetaCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory ChatMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMetaData(
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

  ChatMetaData copyWith({String? key, String? value}) => ChatMetaData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  ChatMetaData copyWithCompanion(ChatMetaCompanion data) {
    return ChatMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMetaData(')
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
      (other is ChatMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class ChatMetaCompanion extends UpdateCompanion<ChatMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ChatMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<ChatMetaData> custom({
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

  ChatMetaCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return ChatMetaCompanion(
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
    return (StringBuffer('ChatMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChatDatabase extends GeneratedDatabase {
  _$ChatDatabase(QueryExecutor e) : super(e);
  late final $ChatConversationsTable chatConversations =
      $ChatConversationsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $ChatToolEventsTable chatToolEvents = $ChatToolEventsTable(this);
  late final $ChatGeminiThoughtSignaturesTable chatGeminiThoughtSignatures =
      $ChatGeminiThoughtSignaturesTable(this);
  late final $ChatMetaTable chatMeta = $ChatMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        chatConversations,
        chatMessages,
        chatToolEvents,
        chatGeminiThoughtSignatures,
        chatMeta
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('chat_conversations',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('chat_messages', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('chat_messages',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('chat_tool_events', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('chat_messages',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('chat_gemini_thought_signatures',
                  kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}
