import '../../database/chat_database_repository.dart';
import '../../models/memory_entry.dart';
import 'memory_block_builder.dart';
import 'memory_prompts.dart';

typedef MemorySnapshotState = ({String prefix, String hash, bool isEmpty});

/// The same effective profile and memory blocks for requests and usage caches.
Future<MemorySnapshotState> readMemorySnapshot({
  required ChatDatabaseRepository repository,
  required String assistantId,
  required MemoryPromptLang lang,
  required int maxItems,
}) async {
  final data = await repository.readMemorySnapshotData(
    assistantId: assistantId,
  );
  final fields = data.profile;
  final visible = data.memories;
  final totals = <MemoryType, int>{};
  for (final entry in visible) {
    totals.update(entry.type, (count) => count + 1, ifAbsent: () => 1);
  }
  final profileBlock = MemoryBlockBuilder.buildProfileBlock(
    fields: fields,
    lang: lang,
  );
  final memoryBlock = MemoryBlockBuilder.buildMemoryBlock(
    visible: visible,
    totalByType: totals,
    lang: lang,
    maxItems: maxItems,
  );
  return (
    prefix: MemoryBlockBuilder.buildFullSnapshotPrefix(
      profileBlock,
      memoryBlock,
      lang,
    ),
    hash: MemoryBlockBuilder.hashBlocks(profileBlock, memoryBlock),
    isEmpty:
        visible.isEmpty && fields.every((field) => field.value.trim().isEmpty),
  );
}
