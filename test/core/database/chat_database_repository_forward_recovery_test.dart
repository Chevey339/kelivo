import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';

void main() {
  final valid = <String, dynamic>{
    'author': 'Reviewer',
    'role': 'assistant',
    'timestamp': '2026-01-01T00:00:00.000Z',
    'parts': [
      {'kind': 'text', 'payload': 'Hello'},
    ],
  };
  final corruptPayloads = <String>[
    '{}',
    '{"messages":{}}',
    '{"messages":[{"author":7}]}',
    '{"messages":[7]}',
    for (final field in ['author', 'role', 'timestamp', 'parts'])
      for (final value in [null, 7, {}])
        jsonEncode({
          'messages': [
            {...valid, field: value},
          ],
        }),
    for (final field in ['authorId', 'authorAvatar'])
      jsonEncode({
        'messages': [
          {...valid, field: 7},
        ],
      }),
    jsonEncode({
      'messages': [
        {...valid, 'timestamp': 'not a date'},
      ],
    }),
    for (final entry in [
      null,
      7,
      {'kind': 7, 'payload': 'hello'},
      {'kind': 'text', 'payload': 7},
      {'kind': 'image', 'payload': '{}'},
      {'kind': 'forwarded_messages', 'payload': '{}'},
    ])
      jsonEncode({
        'messages': [
          {
            ...valid,
            'parts': [entry],
          },
        ],
      }),
  ];

  for (final payload in corruptPayloads) {
    test(
      'public repository preserves malformed forwarded payload $payload',
      () async {
        final dir = await Directory.systemTemp.createTemp('forward_malformed_');
        final file = File('${dir.path}/db.sqlite');
        var repo = ChatDatabaseRepository.open(file: file);
        try {
          await repo.ensureReady();
          await repo.putConversation(Conversation(id: 'c', title: 'Source'));
          await repo.putMessage(
            ChatMessage(
              id: 'm',
              conversationId: 'c',
              role: 'user',
              content: 'before',
            ),
          );
          await repo.close();
          final raw = sqlite.sqlite3.open(file.path);
          raw.execute(
            'UPDATE message_part_rows SET kind = ?, payload = ? WHERE revision_id = ?',
            ['forwarded_messages', payload, 'm'],
          );
          raw.close();
          repo = ChatDatabaseRepository.open(file: file);
          await repo.ensureReady();
          final loaded = (await repo.getMessage('m'))!;
          final malformed = loaded.parts.single as MalformedPart;
          expect(malformed.encodePayload(), payload);
          expect(malformed.parseError, isNotEmpty);
          expect(malformed.isAttachmentKind, isTrue);
          await repo.updateMessage(loaded);
          expect(
            (await repo.getMessage('m'))!.parts.single.encodePayload(),
            payload,
          );
        } finally {
          await repo.close();
          await dir.delete(recursive: true);
        }
      },
    );
  }

  test('unknown nested kinds survive repository reload unchanged', () async {
    final dir = await Directory.systemTemp.createTemp('forward_unknown_');
    final repo = ChatDatabaseRepository.open(
      file: File('${dir.path}/db.sqlite'),
    );
    try {
      await repo.ensureReady();
      await repo.putConversation(Conversation(id: 'c', title: 'Source'));
      await repo.putMessage(
        ChatMessage(
          id: 'm',
          conversationId: 'c',
          role: 'user',
          parts: [
            ForwardedMessagesPart(
              messages: [
                ForwardedMessageSnapshot(
                  author: 'Reviewer',
                  role: 'assistant',
                  timestamp: DateTime.utc(2026),
                  parts: const [
                    UnknownPart(rawKind: 'future_kind', payload: '{opaque}'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final loaded = (await repo.getMessage('m'))!;
      final nested = (loaded.parts.single as ForwardedMessagesPart)
          .messages
          .single
          .parts
          .single;
      expect(
        nested,
        const UnknownPart(rawKind: 'future_kind', payload: '{opaque}'),
      );
    } finally {
      await repo.close();
      await dir.delete(recursive: true);
    }
  });

  test(
    'chat-only availability recovery keeps malformed rows and processes later good rows',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'forward_old_contract_',
      );
      final file = File('${dir.path}/db.sqlite');
      var repo = ChatDatabaseRepository.open(file: file);
      try {
        await repo.ensureReady();
        await repo.putConversation(Conversation(id: 'c', title: 'Source'));
        await repo.putMessage(
          ChatMessage(
            id: 'm',
            conversationId: 'c',
            role: 'user',
            parts: const [
              MalformedPart(
                rawKind: 'image',
                rawPayload: '{}',
                parseError: 'missing_uri',
              ),
              MalformedPart(
                rawKind: 'forwarded_messages',
                rawPayload: '{}',
                parseError: 'invalid_messages',
              ),
              ImagePart(uri: 'kelivo-file:///images/missing.png'),
              ImagePart(uri: 'https://example.com/image.png'),
            ],
          ),
        );
        await repo.close();
        expect(
          await ChatDatabaseRepository.recomputeAttachmentAvailabilityOnDatabaseFile(
            databaseFile: file,
            filesRestored: false,
          ),
          1,
        );
        repo = ChatDatabaseRepository.open(file: file);
        await repo.ensureReady();
        final parts = (await repo.getMessage('m'))!.parts;
        expect(parts.take(2).every((part) => part is MalformedPart), isTrue);
        expect(parts[0].encodePayload(), '{}');
        expect(parts[1].encodePayload(), '{}');
        expect((parts[2] as ImagePart).unavailable, isTrue);
        expect((parts[3] as ImagePart).unavailable, isFalse);
      } finally {
        await repo.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
