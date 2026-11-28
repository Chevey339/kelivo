import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/storage/storage_image_source.dart';
import 'package:Kelivo/utils/app_directories.dart';

import '../../../support/storage_images_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageImagesFixture fixture;
  late ChatDatabaseRepository repo;
  late File photo;
  const uri = 'kelivo-file:///images/shot.png';
  setUp(() async {
    fixture = await StorageImagesFixture.create();
    repo = ChatDatabaseRepository(fixture.database);
    photo = await fixture.file('images/shot.png');
    for (final id in ['chat', 'other']) {
      await repo.putConversation(Conversation(id: id, title: id));
    }
  });
  tearDown(() => fixture.dispose());

  Future<void> add(
    String id,
    int order,
    List<MessagePart> parts, {
    String chat = 'chat',
    String? group,
    int version = 0,
    bool streaming = false,
  }) => repo.putMessage(
    ChatMessage(
      id: id,
      conversationId: chat,
      role: 'assistant',
      groupId: group,
      version: version,
      isStreaming: streaming,
      parts: parts,
    ),
    messageOrder: order,
  );
  Future<StorageImageSource> lookup({
    String chat = 'chat',
    bool Function()? current,
  }) => findStorageImageSource(
    path: photo.path,
    conversationId: chat,
    isCurrent: current ?? () => true,
  );

  test(
    'only a real use in the chosen chat and its selected revision can win',
    () async {
      await add('foreign', 0, [ImagePart(uri: photo.path)], chat: 'other');
      await add('code', 0, const [TextPart('`![code]($uri)`')]);
      await add('same-name', 1, const [
        ImagePart(uri: 'kelivo-file:///upload/shot.png'),
      ]);
      await add('missing', 2, const [ImagePart(uri: uri, unavailable: true)]);
      await add('first', 3, const [ImagePart(uri: uri)]);
      await add(
        'first-v2',
        4,
        const [TextPart('the current answer')],
        group: 'first',
        version: 1,
      );
      await add('inline', 5, const [TextPart('An image ![shot]($uri)')]);
      await add('again', 6, [ImagePart(uri: photo.path)]);
      final db = BusinessRepository(fixture.database);
      final before = await db.readStorageChangeVersion();
      expect((await lookup()).messageId, 'inline');
      expect((await lookup(chat: 'other')).messageId, 'foreign');
      expect(await db.readStorageChangeVersion(), before);
      await repo.setSelectedVersion(
        conversationId: 'chat',
        groupId: 'first',
        version: 0,
      );
      expect((await lookup()).messageId, 'first');
    },
  );

  test(
    'a rendered local file URI matches regardless of scheme capitalization',
    () async {
      final fileUri = photo.uri.toString().replaceFirst('file:', 'FILE:');
      await add('linked', 0, [TextPart('![shot]($fileUri)')]);
      expect((await lookup()).messageId, 'linked');
    },
  );

  test(
    'an image exclusive to a hidden revision does not open or switch versions',
    () async {
      await add('first', 0, const [ImagePart(uri: uri)]);
      await add(
        'second',
        1,
        const [TextPart('current')],
        group: 'first',
        version: 1,
      );
      expect(await lookup(), (messageId: null, busy: false));
      expect((await repo.getConversation('chat'))!.versionSelections, isEmpty);
    },
  );

  test(
    'tool screenshots and attachment files match rendered sources rather than tool arguments',
    () async {
      await add('args', 0, [
        ToolCallPart(
          jsonEncode({
            'name': 'tool',
            'arguments': {'path': uri},
          }),
        ),
      ]);
      await add('typed-text-only', 1, [
        ToolCallPart(
          jsonEncode({
            'content': '![not an attachment]($uri)',
            'metadata': {
              'mcpResult': {'version': 1, 'imageUris': []},
            },
          }),
        ),
      ]);
      await add('untyped-example', 2, [
        ToolCallPart(jsonEncode({'content': 'Example: ![inline]($uri)'})),
      ]);
      await add('preview', 3, [
        ToolCallPart(
          jsonEncode({
            'name': 'browser',
            'metadata': {
              'browser': {'previewImage': photo.uri.toString()},
            },
          }),
        ),
      ]);
      expect((await lookup()).messageId, 'preview');
      await add('tool', 0, [
        ToolCallPart(
          jsonEncode({
            'metadata': {
              'mcpResult': {
                'version': 1,
                'imageUris': [uri],
              },
            },
          }),
        ),
      ], chat: 'other');
      expect((await lookup(chat: 'other')).messageId, 'tool');
      await repo.deleteMessage('tool');
      await add('rendered-tool-line', 1, [
        ToolCallPart(jsonEncode({'content': 'A screenshot\n![]($uri)'})),
      ], chat: 'other');
      expect((await lookup(chat: 'other')).messageId, 'rendered-tool-line');
    },
  );

  test(
    'lookup yields to a reply anywhere and resumes only on an explicit retry',
    () async {
      await add('source', 0, const [FilePart(uri: uri, name: 'shot.png')]);
      await add(
        'reply',
        0,
        const [TextPart('Streaming')],
        chat: 'other',
        streaming: true,
      );
      expect(await lookup(), (messageId: null, busy: true));
      await repo.updateMessageFields('reply', isStreaming: false);
      expect(await lookup(), (messageId: 'source', busy: false));
    },
  );

  test(
    'a cancelled lookup stops between pages and a lookup can continue in the middle of one message',
    () async {
      await add('long', 0, [
        ...List.filled(1100, const TextPart('plain text')),
        const ImagePart(uri: uri),
      ]);
      var checks = 0;
      expect((await lookup(current: () => ++checks == 1)).messageId, isNull);
      expect(checks, 2);
      expect((await lookup()).messageId, 'long');
      // Start a fresh persisted reply after the worker has released page one.
      await add('new-reply', 0, const [TextPart('Waiting')], chat: 'other');
      final directory = await AppDirectories.getAppDataDirectory();
      final writer = sqlite3.open(
        p.join(directory.path, AppDatabase.databaseFileName),
      );
      try {
        checks = 0;
        final result = await lookup(
          current: () {
            if (++checks == 2) {
              writer.execute(
                "UPDATE message_rows SET is_streaming=1 WHERE id='new-reply'",
              );
            }
            return true;
          },
        );
        expect(result, (messageId: null, busy: true));
      } finally {
        writer.close();
      }
    },
  );
}
