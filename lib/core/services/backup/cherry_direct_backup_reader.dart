import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class CherryDirectBackupReader {
  CherryDirectBackupReader._();

  static Map<String, dynamic>? readArchive(Archive archive) {
    final metadata = _readJsonObjectEntry(archive, 'metadata.json');
    final version = (metadata?['version'] as num?)?.toInt();
    if (version == null || version < 6) return null;

    final persist = _readPersistState(archive);
    if (persist == null || persist.isEmpty) return null;

    final indexedDB = _readIndexedDb(archive);
    return <String, dynamic>{
      'version': version,
      'localStorage': <String, dynamic>{'persist:cherry-studio': persist},
      'indexedDB': indexedDB,
    };
  }

  static Map<String, dynamic>? _readJsonObjectEntry(
    Archive archive,
    String name,
  ) {
    final entry = archive.findFile(name);
    if (entry == null || !entry.isFile) return null;
    try {
      final decoded = jsonDecode(utf8.decode(_entryBytes(entry)));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  static String? _readPersistState(Archive archive) {
    String? best;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = entry.name.replaceAll('\\', '/').toLowerCase();
      if (!normalized.startsWith('local storage/leveldb/')) continue;
      if (!normalized.endsWith('.ldb') && !normalized.endsWith('.log')) {
        continue;
      }

      final bytes = _entryBytes(entry);
      final candidates = normalized.endsWith('.log')
          ? _extractPersistFromLevelDbLog(
              bytes,
            ).followedBy(_extractPersistCandidates(bytes))
          : _extractPersistCandidates(bytes);
      for (final candidate in candidates) {
        if (best == null || candidate.length > best.length) {
          best = candidate;
        }
      }
    }
    return best;
  }

  static Map<String, dynamic> _readIndexedDb(Archive archive) {
    final topicsById = <String, Map<String, dynamic>>{};
    final blocksById = <String, Map<String, dynamic>>{};
    final filesById = <String, Map<String, dynamic>>{};
    final messagesByTopicId = <String, Map<String, Map<String, dynamic>>>{};

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = entry.name.replaceAll('\\', '/').toLowerCase();
      if (!normalized.startsWith('indexeddb/') ||
          !normalized.contains('.indexeddb.leveldb/')) {
        continue;
      }
      if (!normalized.endsWith('.ldb') && !normalized.endsWith('.log')) {
        continue;
      }

      final bytes = _entryBytes(entry);
      for (final payload in _readLevelDbPayloads(
        bytes,
        isLog: normalized.endsWith('.log'),
      )) {
        for (final value in _V8ValueScanner.scan(payload)) {
          if (value is! Map) continue;
          final object = value.map((k, v) => MapEntry(k.toString(), v));
          final id = (object['id'] ?? '').toString();
          if (id.isEmpty) continue;

          if (object['messages'] is List) {
            _putBetterTopic(topicsById, id, object);
            continue;
          }

          if (_looksLikeMessage(object)) {
            final topicId = (object['topicId'] ?? '').toString();
            final messagesById = messagesByTopicId[topicId] ??=
                <String, Map<String, dynamic>>{};
            _putBetterMessage(messagesById, id, object);
            continue;
          }

          if ((object['messageId'] ?? '').toString().isNotEmpty &&
              (object['type'] ?? '').toString().isNotEmpty) {
            _putBetterBlock(blocksById, id, object);
            continue;
          }

          if (_looksLikeFileMetadata(object)) {
            filesById[id] = object;
          }
        }
      }
    }

    for (final entry in messagesByTopicId.entries) {
      final topicId = entry.key;
      final standaloneMessages = entry.value.values.toList()
        ..sort(_compareMessagesByDate);
      final existingTopic = topicsById[topicId];
      if (existingTopic == null) {
        topicsById[topicId] = <String, dynamic>{
          'id': topicId,
          'messages': standaloneMessages,
        };
        continue;
      }

      final existingMessages =
          (existingTopic['messages'] as List?)
              ?.whereType<Map>()
              .map((message) => message.map((k, v) => MapEntry('$k', v)))
              .toList() ??
          <Map<String, dynamic>>[];
      final existingIds = {
        for (final message in existingMessages)
          if ((message['id'] ?? '').toString().isNotEmpty)
            (message['id'] ?? '').toString(),
      };
      for (final message in standaloneMessages) {
        final id = (message['id'] ?? '').toString();
        if (id.isNotEmpty && !existingIds.contains(id)) {
          existingMessages.add(message);
        }
      }
      existingTopic['messages'] = existingMessages;
    }

    final referencedMessageIds = <String>{};
    final referencedBlockIds = <String>{};
    for (final topic in topicsById.values) {
      final messages = topic['messages'];
      if (messages is! List) continue;
      for (final message in messages) {
        if (message is! Map) continue;
        final messageId = (message['id'] ?? '').toString();
        if (messageId.isNotEmpty) referencedMessageIds.add(messageId);
        final blocks = message['blocks'];
        if (blocks is List) {
          for (final blockId in blocks) {
            final id = (blockId ?? '').toString();
            if (id.isNotEmpty) referencedBlockIds.add(id);
          }
        }
      }
    }

    final filteredBlocks = blocksById.values.where((block) {
      final id = (block['id'] ?? '').toString();
      final messageId = (block['messageId'] ?? '').toString();
      return referencedBlockIds.contains(id) ||
          referencedMessageIds.contains(messageId);
    }).toList();

    return <String, dynamic>{
      'topics': topicsById.values.toList(),
      'message_blocks': filteredBlocks,
      'files': filesById.values.toList(),
    };
  }

  static void _putBetterTopic(
    Map<String, Map<String, dynamic>> topicsById,
    String id,
    Map<String, dynamic> candidate,
  ) {
    final current = topicsById[id];
    if (current == null || _topicScore(candidate) >= _topicScore(current)) {
      topicsById[id] = candidate;
    }
  }

  static int _topicScore(Map<String, dynamic> topic) {
    final messages = topic['messages'];
    if (messages is! List) return 0;
    var latest = 0;
    for (final message in messages) {
      if (message is! Map) continue;
      final createdAt = DateTime.tryParse(
        (message['updatedAt'] ?? message['createdAt'] ?? '').toString(),
      );
      if (createdAt != null && createdAt.millisecondsSinceEpoch > latest) {
        latest = createdAt.millisecondsSinceEpoch;
      }
    }
    return messages.length * 10000000000000 + latest;
  }

  static void _putBetterBlock(
    Map<String, Map<String, dynamic>> blocksById,
    String id,
    Map<String, dynamic> candidate,
  ) {
    final current = blocksById[id];
    if (current == null || _blockScore(candidate) >= _blockScore(current)) {
      blocksById[id] = candidate;
    }
  }

  static int _blockScore(Map<String, dynamic> block) {
    final status = (block['status'] ?? '').toString();
    final statusScore = switch (status) {
      'success' => 4,
      'paused' => 3,
      'streaming' => 2,
      'processing' || 'pending' => 1,
      _ => 0,
    };
    final date = DateTime.tryParse(
      (block['updatedAt'] ?? block['createdAt'] ?? '').toString(),
    );
    final dateScore = date?.millisecondsSinceEpoch ?? 0;
    final contentScore = (block['content'] ?? '').toString().length;
    return statusScore * 1000000000000000 + dateScore * 1000 + contentScore;
  }

  static bool _looksLikeFileMetadata(Map<String, dynamic> object) {
    final hasName =
        object.containsKey('name') ||
        object.containsKey('origin_name') ||
        object.containsKey('path');
    final hasFileShape =
        object.containsKey('ext') ||
        object.containsKey('type') ||
        object.containsKey('size') ||
        object.containsKey('created_at');
    return hasName && hasFileShape;
  }

  static bool _looksLikeMessage(Map<String, dynamic> object) {
    final topicId = (object['topicId'] ?? '').toString();
    final role = (object['role'] ?? '').toString();
    return topicId.isNotEmpty &&
        (role == 'user' || role == 'assistant' || role == 'system');
  }

  static void _putBetterMessage(
    Map<String, Map<String, dynamic>> messagesById,
    String id,
    Map<String, dynamic> candidate,
  ) {
    final current = messagesById[id];
    if (current == null || _messageScore(candidate) >= _messageScore(current)) {
      messagesById[id] = candidate;
    }
  }

  static int _messageScore(Map<String, dynamic> message) {
    final date = DateTime.tryParse(
      (message['updatedAt'] ?? message['createdAt'] ?? '').toString(),
    );
    final dateScore = date?.millisecondsSinceEpoch ?? 0;
    final blocks = message['blocks'];
    final blockScore = blocks is List ? blocks.length : 0;
    final contentScore = (message['content'] ?? '').toString().length;
    return dateScore * 1000 + blockScore * 100 + contentScore;
  }

  static int _compareMessagesByDate(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aDate =
        DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bDate =
        DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return aDate.compareTo(bDate);
  }

  static Iterable<String> _extractPersistFromLevelDbLog(List<int> bytes) sync* {
    for (final entry in _extractLevelDbLogWriteBatchEntries(bytes)) {
      if (_containsAscii(value: entry.$1, needle: 'persist:cherry-studio')) {
        final decoded = _decodeLocalStorageValue(entry.$2);
        if (_isValidPersistJson(decoded)) yield decoded;
      }
    }
  }

  static Iterable<List<int>> _readLevelDbPayloads(
    List<int> bytes, {
    required bool isLog,
  }) sync* {
    var yieldedStructuredPayload = false;
    if (isLog) {
      for (final payload in _extractLevelDbLogValues(bytes)) {
        yieldedStructuredPayload = true;
        yield payload;
      }
    } else {
      for (final payload in _extractLevelDbTableValues(bytes)) {
        yieldedStructuredPayload = true;
        yield payload;
      }
    }

    // Keep the raw scan as a compatibility fallback for unusual LevelDB files
    // or partially-copied backups where structured parsing cannot finish.
    if (!yieldedStructuredPayload) yield bytes;
  }

  static Iterable<List<int>> _extractLevelDbLogValues(List<int> bytes) sync* {
    for (final entry in _extractLevelDbLogWriteBatchEntries(bytes)) {
      yield entry.$2;
    }
  }

  static Iterable<(List<int>, List<int>)> _extractLevelDbLogWriteBatchEntries(
    List<int> bytes,
  ) sync* {
    for (final payload in _extractLevelDbLogWriteBatches(bytes)) {
      yield* _extractWriteBatchEntries(payload);
    }
  }

  static Iterable<List<int>> _extractLevelDbLogWriteBatches(
    List<int> bytes,
  ) sync* {
    const blockSize = 32768;
    var offset = 0;
    List<int>? fragmented;

    while (offset + 7 <= bytes.length) {
      final blockOffset = offset % blockSize;
      final remainingInBlock = blockSize - blockOffset;
      if (remainingInBlock < 7) {
        offset += remainingInBlock;
        continue;
      }

      final length = bytes[offset + 4] | (bytes[offset + 5] << 8);
      final type = bytes[offset + 6];
      offset += 7;

      if (length == 0 && type == 0) {
        offset += blockSize - (offset % blockSize);
        continue;
      }
      if (offset + length > bytes.length) break;

      final payload = bytes.sublist(offset, offset + length);
      offset += length;

      switch (type) {
        case 1:
          fragmented = null;
          yield payload;
          break;
        case 2:
          fragmented = <int>[...payload];
          break;
        case 3:
          fragmented?.addAll(payload);
          break;
        case 4:
          final combined = fragmented;
          if (combined != null) {
            combined.addAll(payload);
            yield combined;
          }
          fragmented = null;
          break;
      }
    }
  }

  static Iterable<(List<int>, List<int>)> _extractWriteBatchEntries(
    List<int> payload,
  ) sync* {
    if (payload.length < 12) return;
    var offset = 12; // 8-byte sequence number + 4-byte record count.
    final count =
        payload[8] |
        (payload[9] << 8) |
        (payload[10] << 16) |
        (payload[11] << 24);

    for (var i = 0; i < count && offset < payload.length; i++) {
      final tag = payload[offset++];
      if (tag == 0) {
        final key = _readLengthPrefixedBytes(payload, offset);
        if (key == null) break;
        offset = key.$2;
        continue;
      }
      if (tag != 1) break;

      final key = _readLengthPrefixedBytes(payload, offset);
      if (key == null) break;
      offset = key.$2;

      final value = _readLengthPrefixedBytes(payload, offset);
      if (value == null) break;
      offset = value.$2;

      yield (key.$1, value.$1);
    }
  }

  static Iterable<List<int>> _extractLevelDbTableValues(List<int> bytes) sync* {
    if (bytes.length < 48 || !_hasLevelDbTableMagic(bytes)) return;

    final footerOffset = bytes.length - 48;
    final metaIndexHandle = _readLevelDbBlockHandle(bytes, footerOffset);
    if (metaIndexHandle == null) return;
    final indexHandle = _readLevelDbBlockHandle(bytes, metaIndexHandle.next);
    if (indexHandle == null) return;

    final indexBlock = _readLevelDbPhysicalBlock(
      bytes,
      indexHandle.offset,
      indexHandle.size,
    );
    if (indexBlock == null) return;

    for (final indexEntry in _readLevelDbBlockEntries(indexBlock)) {
      final dataHandle = _readLevelDbBlockHandle(indexEntry.$2, 0);
      if (dataHandle == null) continue;
      final dataBlock = _readLevelDbPhysicalBlock(
        bytes,
        dataHandle.offset,
        dataHandle.size,
      );
      if (dataBlock == null) continue;

      for (final dataEntry in _readLevelDbBlockEntries(dataBlock)) {
        yield dataEntry.$2;
      }
    }
  }

  static bool _hasLevelDbTableMagic(List<int> bytes) {
    const magic = <int>[0x57, 0xfb, 0x80, 0x8b, 0x24, 0x75, 0x47, 0xdb];
    final offset = bytes.length - magic.length;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  static ({int offset, int size, int next})? _readLevelDbBlockHandle(
    List<int> bytes,
    int offset,
  ) {
    final blockOffset = _readVarint64(bytes, offset);
    if (blockOffset == null) return null;
    final blockSize = _readVarint64(bytes, blockOffset.$2);
    if (blockSize == null) return null;
    return (offset: blockOffset.$1, size: blockSize.$1, next: blockSize.$2);
  }

  static List<int>? _readLevelDbPhysicalBlock(
    List<int> bytes,
    int offset,
    int size,
  ) {
    if (offset < 0 || size < 0 || offset + size + 5 > bytes.length) {
      return null;
    }

    final payload = bytes.sublist(offset, offset + size);
    final compressionType = bytes[offset + size];
    return switch (compressionType) {
      0 => payload,
      1 => _decodeSnappyBlock(payload),
      _ => null,
    };
  }

  static Iterable<(List<int>, List<int>)> _readLevelDbBlockEntries(
    List<int> block,
  ) sync* {
    if (block.length < 8) return;
    final restartCount = _readFixed32(block, block.length - 4);
    final restartOffset = block.length - 4 - restartCount * 4;
    if (restartCount <= 0 ||
        restartOffset < 0 ||
        restartOffset > block.length) {
      return;
    }

    var offset = 0;
    var previousKey = <int>[];
    while (offset < restartOffset) {
      final shared = _readVarint32(block, offset);
      if (shared == null) return;
      offset = shared.$2;
      final nonShared = _readVarint32(block, offset);
      if (nonShared == null) return;
      offset = nonShared.$2;
      final valueLength = _readVarint32(block, offset);
      if (valueLength == null) return;
      offset = valueLength.$2;

      final keyEnd = offset + nonShared.$1;
      final valueEnd = keyEnd + valueLength.$1;
      if (shared.$1 > previousKey.length || valueEnd > restartOffset) {
        return;
      }

      final key = <int>[
        ...previousKey.take(shared.$1),
        ...block.sublist(offset, keyEnd),
      ];
      final value = block.sublist(keyEnd, valueEnd);
      previousKey = key;
      offset = valueEnd;
      yield (key, value);
    }
  }

  static int _readFixed32(List<int> bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) return -1;
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static List<int>? _decodeSnappyBlock(List<int> bytes) {
    final decodedLength = _readVarint32(bytes, 0);
    if (decodedLength == null) return null;

    var offset = decodedLength.$2;
    final out = <int>[];

    while (offset < bytes.length) {
      final tag = bytes[offset++];
      final type = tag & 0x03;
      if (type == 0) {
        var length = tag >> 2;
        if (length < 60) {
          length += 1;
        } else {
          final bytesForLength = length - 59;
          if (offset + bytesForLength > bytes.length) return null;
          var rawLength = 0;
          for (var i = 0; i < bytesForLength; i++) {
            rawLength |= bytes[offset++] << (8 * i);
          }
          length = rawLength + 1;
        }
        if (offset + length > bytes.length) return null;
        out.addAll(bytes.sublist(offset, offset + length));
        offset += length;
        continue;
      }

      late int length;
      late int copyOffset;
      if (type == 1) {
        if (offset >= bytes.length) return null;
        length = ((tag >> 2) & 0x07) + 4;
        copyOffset = ((tag & 0xe0) << 3) | bytes[offset++];
      } else if (type == 2) {
        if (offset + 2 > bytes.length) return null;
        length = (tag >> 2) + 1;
        copyOffset = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
      } else {
        if (offset + 4 > bytes.length) return null;
        length = (tag >> 2) + 1;
        copyOffset =
            bytes[offset] |
            (bytes[offset + 1] << 8) |
            (bytes[offset + 2] << 16) |
            (bytes[offset + 3] << 24);
        offset += 4;
      }

      if (copyOffset <= 0 || copyOffset > out.length) return null;
      for (var i = 0; i < length; i++) {
        out.add(out[out.length - copyOffset]);
      }
    }

    if (out.length != decodedLength.$1) return null;
    return out;
  }

  static (List<int>, int)? _readLengthPrefixedBytes(
    List<int> bytes,
    int offset,
  ) {
    final length = _readVarint32(bytes, offset);
    if (length == null) return null;
    offset = length.$2;
    final end = offset + length.$1;
    if (end > bytes.length) return null;
    return (bytes.sublist(offset, end), end);
  }

  static (int, int)? _readVarint32(List<int> bytes, int offset) {
    var result = 0;
    var shift = 0;
    while (offset < bytes.length && shift <= 28) {
      final byte = bytes[offset++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return (result, offset);
      shift += 7;
    }
    return null;
  }

  static (int, int)? _readVarint64(List<int> bytes, int offset) {
    var result = 0;
    var shift = 0;
    while (offset < bytes.length && shift <= 63) {
      final byte = bytes[offset++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return (result, offset);
      shift += 7;
    }
    return null;
  }

  static bool _containsAscii({
    required List<int> value,
    required String needle,
  }) {
    return _indexOfBytes(value, ascii.encode(needle), 0) >= 0;
  }

  static String _decodeLocalStorageValue(List<int> bytes) {
    if (bytes.isNotEmpty) {
      if (bytes.first == 0 && (bytes.length - 1).isEven) {
        final utf16 = _decodeUtf16Le(bytes.sublist(1));
        if (_isValidPersistJson(utf16)) return utf16;
      }
      if (bytes.first == 1) {
        final utf8Text = utf8.decode(bytes.sublist(1), allowMalformed: true);
        if (_isValidPersistJson(utf8Text)) return utf8Text;
      }
    }
    final utf16 = _decodeUtf16Le(bytes);
    if (_isValidPersistJson(utf16)) return utf16;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _decodeUtf16Le(List<int> bytes) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return String.fromCharCodes(units);
  }

  static Iterable<String> _extractPersistCandidates(List<int> bytes) sync* {
    const key = 'persist:cherry-studio';
    final keyBytes = ascii.encode(key);
    var index = 0;
    while (index <= bytes.length - keyBytes.length) {
      final found = _indexOfBytes(bytes, keyBytes, index);
      if (found < 0) break;
      final searchStart = found + keyBytes.length;

      yield* _extractUtf16JsonObjects(
        bytes,
        searchStart,
      ).where(_isValidPersistJson);
      yield* _extractUtf8JsonObjects(
        bytes,
        searchStart,
      ).where(_isValidPersistJson);

      index = searchStart;
    }
  }

  static bool _isValidPersistJson(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map &&
          (decoded.containsKey('assistants') || decoded.containsKey('llm'));
    } catch (_) {
      return false;
    }
  }

  static Iterable<String> _extractUtf16JsonObjects(
    List<int> bytes,
    int start,
  ) sync* {
    for (var i = start; i + 1 < bytes.length; i++) {
      if (bytes[i] != 0x7b || bytes[i + 1] != 0x00) continue;
      final json = _readBalancedJson(
        readUnit: (offset) {
          final byteOffset = i + offset * 2;
          if (byteOffset + 1 >= bytes.length) return null;
          return bytes[byteOffset] | (bytes[byteOffset + 1] << 8);
        },
      );
      if (json != null) yield json;
    }
  }

  static Iterable<String> _extractUtf8JsonObjects(
    List<int> bytes,
    int start,
  ) sync* {
    for (var i = start; i < bytes.length; i++) {
      if (bytes[i] != 0x7b) continue;
      final json = _readBalancedJson(
        readUnit: (offset) {
          final byteOffset = i + offset;
          if (byteOffset >= bytes.length) return null;
          return bytes[byteOffset];
        },
      );
      if (json != null) yield json;
    }
  }

  static String? _readBalancedJson({required int? Function(int) readUnit}) {
    final buffer = StringBuffer();
    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var offset = 0; ; offset++) {
      final unit = readUnit(offset);
      if (unit == null) return null;
      final char = String.fromCharCode(unit);
      buffer.write(char);

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == 0x5c) {
          escaped = true;
        } else if (unit == 0x22) {
          inString = false;
        }
        continue;
      }

      if (unit == 0x22) {
        inString = true;
      } else if (unit == 0x7b || unit == 0x5b) {
        depth++;
      } else if (unit == 0x7d || unit == 0x5d) {
        depth--;
        if (depth == 0) return buffer.toString();
        if (depth < 0) return null;
      }
    }
  }

  static int _indexOfBytes(List<int> bytes, List<int> pattern, int start) {
    for (var i = start; i <= bytes.length - pattern.length; i++) {
      var matched = true;
      for (var j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i;
    }
    return -1;
  }

  static List<int> _entryBytes(ArchiveFile entry) {
    return entry.content;
  }
}

class _V8ValueScanner {
  _V8ValueScanner._();

  static List<dynamic> scan(List<int> bytes) {
    final values = <dynamic>[];
    for (var i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] != 0xff) continue;
      final versionByte = bytes[i + 1];
      if ((versionByte & 0x80) != 0 ||
          versionByte < 0x0d ||
          versionByte > 0x20) {
        continue;
      }

      try {
        final reader = _V8ValueReader(bytes, i);
        final value = reader.readValue();
        values.add(value);
      } catch (_) {
        // Wrong offsets are expected while scanning raw LevelDB bytes.
      }
    }
    return values;
  }
}

class _V8ValueReader {
  _V8ValueReader(this._bytes, this._offset);

  final List<int> _bytes;
  int _offset;
  final List<dynamic> _objects = <dynamic>[];

  dynamic readValue() {
    final tag = _readByte();
    switch (tag) {
      case 0x00:
        return readValue();
      case 0xff:
        _readVarint();
        return readValue();
      case 0x5f:
        return null;
      case 0x30:
        return null;
      case 0x54:
        return true;
      case 0x46:
        return false;
      case 0x49:
        return _decodeZigZag(_readVarint());
      case 0x55:
        return _readVarint();
      case 0x4e:
        return _readFloat64();
      case 0x22:
        return _readOneByteString();
      case 0x53:
        return _readUtf8String();
      case 0x63:
        return _readTwoByteString();
      case 0x6f:
        return _readObject();
      case 0x41:
        return _readDenseArray();
      case 0x61:
        return _readSparseArray();
      case 0x5e:
        return _readObjectReference();
      case 0x44:
        return DateTime.fromMillisecondsSinceEpoch(
          _readFloat64().round(),
          isUtc: true,
        ).toIso8601String();
      default:
        throw FormatException('Unsupported V8 value tag: $tag');
    }
  }

  Map<String, dynamic> _readObject() {
    final result = <String, dynamic>{};
    _objects.add(result);

    while (_peekByte() != 0x7b) {
      final key = readValue();
      final value = readValue();
      if (key != null) result[key.toString()] = value;
    }
    _readByte();
    _readVarint();
    return result;
  }

  List<dynamic> _readDenseArray() {
    final length = _readCollectionLength();
    final result = List<dynamic>.filled(length, null, growable: true);
    _objects.add(result);

    for (var i = 0; i < length; i++) {
      result[i] = readValue();
    }

    while (_peekByte() != 0x24) {
      final key = readValue();
      final value = readValue();
      if (key is int && key >= 0) {
        while (result.length <= key) {
          result.add(null);
        }
        result[key] = value;
      }
    }
    _readByte();
    _readVarint();
    _readVarint();
    return result;
  }

  List<dynamic> _readSparseArray() {
    final length = _readCollectionLength();
    final result = List<dynamic>.filled(length, null, growable: true);
    _objects.add(result);

    while (_peekByte() != 0x40) {
      final key = readValue();
      final value = readValue();
      if (key is int && key >= 0) {
        while (result.length <= key) {
          result.add(null);
        }
        result[key] = value;
      }
    }
    _readByte();
    _readVarint();
    _readVarint();
    return result;
  }

  dynamic _readObjectReference() {
    final id = _readVarint();
    if (id < 0 || id >= _objects.length) {
      throw FormatException('Invalid V8 object reference: $id');
    }
    return _objects[id];
  }

  String _readOneByteString() {
    final length = _readStringLength();
    _ensureAvailable(length);
    final start = _offset;
    _offset += length;
    return latin1.decode(_bytes.sublist(start, start + length));
  }

  String _readUtf8String() {
    final length = _readStringLength();
    _ensureAvailable(length);
    final start = _offset;
    _offset += length;
    return utf8.decode(_bytes.sublist(start, start + length));
  }

  String _readTwoByteString() {
    final byteLength = _readStringLength();
    if (byteLength.isOdd) {
      throw const FormatException('Invalid V8 two-byte string length');
    }
    _ensureAvailable(byteLength);
    final start = _offset;
    _offset += byteLength;
    return String.fromCharCodes(
      Iterable<int>.generate(
        byteLength ~/ 2,
        (index) =>
            _bytes[start + index * 2] | (_bytes[start + index * 2 + 1] << 8),
      ),
    );
  }

  int _readCollectionLength() {
    final length = _readVarint();
    if (length > 200000) {
      throw FormatException('V8 collection is too large: $length');
    }
    return length;
  }

  int _readStringLength() {
    final length = _readVarint();
    _ensureAvailable(length);
    return length;
  }

  int _decodeZigZag(int value) {
    return (value >> 1) ^ -(value & 1);
  }

  double _readFloat64() {
    _ensureAvailable(8);
    final data = ByteData.sublistView(
      Uint8List.fromList(_bytes.sublist(_offset, _offset + 8)),
    );
    _offset += 8;
    return data.getFloat64(0, Endian.little);
  }

  int _readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = _readByte();
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
      if (shift > 63) {
        throw const FormatException('Invalid V8 varint');
      }
    }
  }

  int _peekByte() {
    _ensureAvailable(1);
    return _bytes[_offset];
  }

  int _readByte() {
    _ensureAvailable(1);
    return _bytes[_offset++];
  }

  void _ensureAvailable(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const FormatException('Unexpected end of V8 value');
    }
  }
}
