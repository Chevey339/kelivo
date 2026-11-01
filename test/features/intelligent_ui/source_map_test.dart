import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/utils/protected_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/message_part_snapshot.dart';
import 'package:Kelivo/features/chat/utils/thinking_tag_parser.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_source_map.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_generation_state.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';

const _body =
    'ui 1 catalog "kelivo.native/1"\nroot = Text(text="你好 😀 <think>literal</think>")';
const _fence = '```kelivo-ui\n$_body\n```';
const _web =
    '```kelivo-web\n{"version":1,"title":"<think>literal</think>","summary":"😀"}\n<b>Local</b>\n```';
void main() {
  const parser = MarkdownParser();
  for (final language in ['kelivo-ui', 'kelivo-web']) {
    test(
      '$language preserves a closed tail only when its body is unchanged',
      () {
        for (final marker in ['```', '~~~']) {
          final before = 'before\n\n$marker$language\n$_body\n$marker';
          final document = parser.parse(before, streaming: true);
          final node = document.children.whereType<CodeBlockNode>().single;
          expect(node.closed, isTrue);
          for (final suffix in [' ', '\t', ' \t\r\n', '$marker \n\n$_web']) {
            final text = '$before$suffix';
            final source = UiMessageSource.of([TextPart(text)])
                .sliceForPart(0, 0, text.length)!
                .withFirstMessageOrdinal(1, webOrdinal: 2);
            expect(source.resolve(document, node), isNull);
            final resolved = source.resolve(
              document,
              node,
              allowStreamingTail: true,
            );
            expect(resolved, same(source.fences.first.fence));
            expect(resolved!.node.closed, isTrue);
            expect(resolved.node.code, node.code);
            expect(
              source.messageOrdinalOf(resolved),
              language == 'kelivo-ui' ? 1 : 2,
            );
          }
          for (final text in [
            '${before}not a closer',
            '${before}not a closer\nnew body\n$marker',
            '${before.replaceFirst('你好', '您好')} ',
          ]) {
            final source = UiMessageSource.of([
              TextPart(text),
            ]).sliceForPart(0, 0, text.length)!;
            expect(
              source.resolve(document, node, allowStreamingTail: true),
              isNull,
              reason: text,
            );
          }
        }
      },
    );

    test(
      '$language resolves a coalesced open tail only for verified appends',
      () {
        final before = 'before\n\n```$language\n$_body';
        final document = parser.parse(before, streaming: true);
        final node = document.children.whereType<CodeBlockNode>().single;
        for (final suffix in [' continued', '\n```', '\n```\n\n$_web']) {
          final text = '$before$suffix';
          final source = UiMessageSource.of([TextPart(text)])
              .sliceForPart(0, 0, text.length)!
              .withFirstMessageOrdinal(1, webOrdinal: 2);
          expect(source.resolve(document, node), isNull);
          final resolved = source.resolve(
            document,
            node,
            allowStreamingTail: true,
          );
          expect(resolved, same(source.fences.first.fence));
          expect(resolved!.source, startsWith(node.span.slice(before)));
          expect(
            source.messageOrdinalOf(resolved),
            language == 'kelivo-ui' ? 1 : 2,
          );
        }

        for (final text in [
          '${before.replaceFirst('before', 'edited')} continued',
          '${before.replaceFirst('你好', '您好')} continued',
          before.substring(0, before.length - 1),
          '$before continued'.split('\n').map((line) => '> $line').join('\n'),
        ]) {
          final source = UiMessageSource.of([
            TextPart(text),
          ]).sliceForPart(0, 0, text.length)!;
          expect(
            source.resolve(document, node, allowStreamingTail: true),
            isNull,
            reason: text,
          );
        }

        final closed = '$before\n```';
        final closedDocument = parser.parse(closed, streaming: true);
        final reopened = '${closed}not a closing fence';
        final source = UiMessageSource.of([
          TextPart(reopened),
        ]).sliceForPart(0, 0, reopened.length)!;
        expect(
          source.resolve(
            closedDocument,
            closedDocument.children.whereType<CodeBlockNode>().single,
            allowStreamingTail: true,
          ),
          isNull,
        );
      },
    );

    test('cached negatives detect $language across edited empty parts', () {
      for (var cut = 1; cut < language.length; cut++) {
        final builder = MessagePartSnapshotBuilder();
        final parts = <MessagePart>[
          TextPart('```${language.substring(0, cut)}'),
          const TextPart('!'),
          TextPart('${language.substring(cut)}\n$_body\n```'),
        ];
        final previous = builder.update(parts);
        expect(UiMessageSource.of(previous).hasCandidate, isFalse);
        parts[1] = const TextPart('');
        final current = builder.update(parts, changed: {1});
        expect(current.sourceIdentity, same(previous.sourceIdentity));
        final source = UiMessageSource.of(current);
        expect(source.hasCandidate, isTrue, reason: 'cut=$cut');
        expect(source.runs.single.fences.single.node.info, language);
        expect(UiMessageSource.of(previous).hasCandidate, isFalse);
      }
    });

    test('cached negatives traverse short/empty $language prefix parts', () {
      final builder = MessagePartSnapshotBuilder();
      final parts = <MessagePart>[
        const TextPart('```'),
        for (final character
            in language.substring(0, language.length - 1).split('')) ...[
          TextPart(character),
          const TextPart(''),
        ],
        const TextPart('?'),
        const TextPart('\n$_body\n```'),
      ];
      final previous = builder.update(parts);
      expect(UiMessageSource.of(previous).hasCandidate, isFalse);
      final edited = parts.length - 2;
      parts[edited] = TextPart(language.substring(language.length - 1));
      expect(
        UiMessageSource.of(
          builder.update(parts, changed: {edited}),
        ).hasCandidate,
        isTrue,
      );
    });

    test(
      'cached negatives observe $language edits before the tail and removal',
      () {
        final builder = MessagePartSnapshotBuilder();
        final parts = <MessagePart>[
          const TextPart('```kelivx-'),
          TextPart('${language.substring(7)}\n$_body\n```'),
          const ToolCallPart('{}'),
          const TextPart('unrelated tail'),
        ];
        final previous = builder.update(parts);
        expect(UiMessageSource.of(previous).hasCandidate, isFalse);
        for (final prefix in ['```kelivo-', '```kelivx-', '```kelivo-']) {
          parts[0] = TextPart(prefix);
          expect(
            UiMessageSource.of(
              builder.update(parts, changed: {0}),
            ).hasCandidate,
            prefix == '```kelivo-',
          );
        }
      },
    );
  }

  test(
    'cached negatives keep non-text boundaries and recheck structural changes',
    () {
      for (final removeBoundary in [false, true]) {
        final builder = MessagePartSnapshotBuilder();
        final parts = <MessagePart>[
          const TextPart('```kelivo-'),
          const ToolCallPart('{}'),
          const TextPart('invalid'),
        ];
        final previous = builder.update(parts);
        expect(UiMessageSource.of(previous).hasCandidate, isFalse);
        parts[2] = const TextPart('ui\n$_body\n```');
        final stillSeparate = builder.update(parts, changed: {2});
        expect(UiMessageSource.of(stillSeparate).hasCandidate, isFalse);
        if (removeBoundary) {
          parts.removeAt(1);
        } else {
          parts[1] = const TextPart('');
        }
        final connected = builder.update(parts, changed: {1, 2});
        expect(
          connected.structureRevision,
          isNot(stillSeparate.structureRevision),
        );
        expect(UiMessageSource.of(connected).hasCandidate, isTrue);
      }
    },
  );

  test(
    'negative candidate cache falls back after journal expiry or many edits',
    () {
      final builder = MessagePartSnapshotBuilder();
      final previous = builder.update(const [TextPart('ordinary')]);
      expect(UiMessageSource.of(previous).hasCandidate, isFalse);
      for (var i = 0; i < 64; i++) {
        builder.update([TextPart('ordinary $i')], changed: {0});
      }
      final current = builder.update(const [TextPart(_fence)], changed: {0});
      expect(current.changesSince(previous), isNull);
      expect(UiMessageSource.of(current).hasCandidate, isTrue);

      final manyBuilder = MessagePartSnapshotBuilder();
      final manyBefore = manyBuilder.update(
        List.generate(20, (i) => TextPart('old $i')),
      );
      expect(UiMessageSource.of(manyBefore).hasCandidate, isFalse);
      final manyAfter = manyBuilder.update(
        List.generate(20, (i) => TextPart(i == 19 ? _web : 'new $i')),
        changed: {for (var i = 0; i < 20; i++) i},
      );
      expect(UiMessageSource.of(manyAfter).hasCandidate, isTrue);
    },
  );

  test('negative candidate cache never crosses snapshot source identities', () {
    final first = MessagePartSnapshotBuilder().update(const [
      TextPart('plain'),
    ]);
    expect(UiMessageSource.of(first).hasCandidate, isFalse);
    final other = MessagePartSnapshotBuilder().update(const [TextPart(_fence)]);
    expect(other.sourceIdentity, isNot(same(first.sourceIdentity)));
    expect(other.changesSince(first), isNull);
    expect(UiMessageSource.of(other).hasCandidate, isTrue);
    expect(UiMessageSource.of(first).hasCandidate, isFalse);
  });

  for (final language in ['kelivo-ui', 'kelivo-web']) {
    test('$language candidate spans short and empty adjacent text parts', () {
      final source = UiMessageSource.of([
        const TextPart('```'),
        for (final character in language.split('')) ...[
          const TextPart(''),
          TextPart(character),
        ],
        const TextPart(''),
        const TextPart('\n$_body\n```'),
      ]);
      expect(source.hasCandidate, isTrue);
      expect(source.runs.single.fences.single.node.info, language);
    });

    test('$language candidate never crosses a non-text part', () {
      for (final boundary in const <MessagePart>[
        FilePart(uri: '/file', name: 'file'),
        ImagePart(uri: '/image'),
        ReasoningPart('reasoning'),
        ToolCallPart('{}'),
        AssistantRoundEndPart(),
      ]) {
        final source = UiMessageSource.of([
          const TextPart('```kelivo-'),
          const TextPart(''),
          boundary,
          const TextPart(''),
          TextPart('${language.substring(7)}\n$_body\n```'),
        ]);
        expect(source.hasCandidate, isFalse, reason: boundary.kind);
      }
    });
  }
  test('web markers across every split preserve original authority', () {
    for (var cut = 0; cut <= _web.length; cut++) {
      final source = UiMessageSource.of([
        TextPart(_web.substring(0, cut)),
        TextPart(_web.substring(cut)),
      ]);
      final joined = source
          .sliceForPart(0, 0, cut)!
          .append(source.sliceForPart(1, 0, _web.length - cut)!)!;
      final changed = joined.transform((s) => s.replaceAll('literal', 'wrong'));
      final document = parser.parse(changed.text);
      final fence = changed.resolve(
        document,
        document.children.single as CodeBlockNode,
      )!;
      expect(fence.isWeb, isTrue);
      expect(fence.surfaceKey, 'web:0:0', reason: 'cut=$cut');
      expect(changed.text, _web);
    }
  });
  test('web and native ordinals and per-message caps are independent', () {
    const text = '$_web\n\n$_fence\n\n$_web\n\n$_fence';
    final source = UiMessageSource.of([const TextPart(text)]);
    final slice = source
        .sliceForPart(0, 0, text.length)!
        .withFirstMessageOrdinal(2, webOrdinal: 1);
    expect(slice.fences.map((f) => f.fence.surfaceKey), [
      'web:0:0',
      '0:0',
      'web:0:1',
      '0:1',
    ]);
    expect(slice.fences.map((f) => slice.messageOrdinalOf(f.fence)), [
      1,
      2,
      2,
      3,
    ]);
    expect(slice.topLevelFenceCount, 2);
    expect(slice.topLevelWebFenceCount, 2);
    for (final item in slice.fences) {
      final piece = slice.slice(item.span.start, item.span.end);
      expect(
        piece.messageOrdinalOf(item.fence),
        slice.messageOrdinalOf(item.fence),
      );
    }
  });
  test(
    'every UTF-16 split across adjacent original parts resolves the same fence owner',
    () {
      for (var cut = 0; cut <= _fence.length; cut++) {
        final source = UiMessageSource.of([
          TextPart(_fence.substring(0, cut)),
          TextPart(_fence.substring(cut)),
        ]);
        final a = source.sliceForPart(0, 0, cut)!;
        final b = source.sliceForPart(1, 0, _fence.length - cut)!;
        final joined = a.append(b)!;
        final transformed = joined.transform(
          (text) => text.replaceAll('literal', 'wrong'),
        );
        final document = parser.parse(transformed.text);
        final fence = transformed.resolve(
          document,
          document.children.single as CodeBlockNode,
        )!;
        expect(fence.surfaceKey, '0:0', reason: 'cut=$cut');
        expect(fence.body, '$_body\n');
        expect(fence.node.closed, isTrue);
        expect(transformed.text, _fence);
      }
    },
  );
  test(
    'all non-text parts are run boundaries, including an invisible file',
    () {
      final source = UiMessageSource.of([
        const TextPart('```kelivo-ui\n$_body'),
        const FilePart(uri: '/file', name: 'file'),
        const TextPart('\n```'),
      ]);
      expect(source.runs, hasLength(2));
      expect(source.runs.first.fences.single.node.closed, isFalse);
      expect(source.runs.first.fences.single.body, _body);
      expect(source.runs.last.firstPartOrdinal, 2);
      expect(
        source
            .sliceForPart(0, 0, source.runs.first.source.length)!
            .append(
              source.sliceForPart(2, 0, source.runs.last.source.length) ??
                  UiTextSlice.original(
                    source.runs.last,
                    0,
                    source.runs.last.source.length,
                  ),
            ),
        isNull,
      );
      final splitMarker = UiMessageSource.of([
        const TextPart('```kelivo-'),
        const FilePart(uri: '/file', name: 'file'),
        const TextPart('ui\n$_body\n```'),
      ]);
      expect(splitMarker.hasFences, isFalse);
    },
  );
  test(
    'identical fences keep distinct run ordinals after prose transforms and bubble slicing',
    () {
      const text = 'prefix\n\n$_fence\n\nmiddle\n\n$_fence';
      final source = UiMessageSource.of([
        const ImagePart(uri: '/image'),
        const TextPart(text),
      ]);
      final transformed = source
          .sliceForPart(1, 0, text.length)!
          .transform(
            (text) => text.replaceAll('prefix', 'A longer display prefix'),
          );
      expect(transformed.fences.map((f) => f.fence.surfaceKey), ['1:0', '1:1']);
      for (final item in transformed.fences) {
        final bubble = transformed.slice(item.span.start, item.span.end);
        final document = parser.parse(bubble.text);
        final node = document.children.single as CodeBlockNode;
        expect(node.span.start, 0);
        expect(bubble.resolve(document, node), same(item.fence));
      }
    },
  );
  test('a visual regex cannot create an authorized fence', () {
    const text = 'prefix\n\n$_fence';
    final source = UiMessageSource.of([const TextPart(text)]);
    final transformed = source
        .sliceForPart(0, 0, text.length)!
        .transform((text) => text.replaceAll('prefix', _fence));
    final document = parser.parse(transformed.text);
    expect(
      transformed.resolve(document, document.children.first as CodeBlockNode),
      isNull,
    );
    expect(
      transformed
          .resolve(document, document.children.last as CodeBlockNode)!
          .surfaceKey,
      '0:0',
    );
  });
  test(
    'quoted and list-nested native code can be protected but never resolved as a root card',
    () {
      for (final text in [
        _fence.split('\n').map((line) => '> $line').join('\n'),
        '- item\n\n${_fence.split('\n').map((line) => '  $line').join('\n')}',
      ]) {
        final source = UiMessageSource.of([TextPart(text)]);
        final fence = source.runs.single.fences.single;
        expect(fence.topLevel, isFalse);
        final slice = source.sliceForPart(0, 0, text.length)!;
        final document = parser.parse(text);
        expect(slice.resolve(document, fence.node), isNull);
      }
    },
  );
  test(
    'real CRLF terminators are retained and synthetic EOF terminators are omitted',
    () {
      final raw = _fence.replaceAll('\n', '\r\n');
      final source = UiMessageSource.of([TextPart(raw)]);
      expect(source.runs.single.fences.single.body, '$_body\n');
      final open = UiMessageSource.of([const TextPart('```kelivo-ui\n$_body')]);
      expect(open.runs.single.fences.single.body, _body);
      expect(open.runs.single.fences.single.node.closed, isFalse);
    },
  );
  test(
    'thinking extraction preserves native literals and original Unicode coordinates',
    () {
      const text = 'İ before\n\n<think>hidden</think>\n\n$_fence\n\nafter';
      final source = UiMessageSource.of([const TextPart(text)]);
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(
        text,
        protectedRanges: source.protectedJoinedRanges,
      );
      expect(parsed.thinkingTexts, ['hidden']);
      expect(parsed.visibleContent, contains(_fence));
      expect(parsed.visibleContent, startsWith('İ before'));
      const other =
          '<think>before\n\n```kelivo-ui\nui 1 catalog "kelivo.native/1"\nroot = Text(text="</think>")\n```\n\nafter</think>visible';
      final otherSource = UiMessageSource.of([const TextPart(other)]);
      final otherParsed = ThinkingTagParser.parseLegacyInlineBlocks(
        other,
        protectedRanges: otherSource.protectedJoinedRanges,
      );
      expect(otherParsed.visibleContent, 'visible');
      expect(otherParsed.thinkingTexts.single, endsWith('after'));
    },
  );
  test('only an authoritative completed host can unlock a closed fence', () {
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c',
      content: _fence,
    );
    expect(uiGenerationStatus(message), UiGenerationStatus.interrupted);
    for (final state in GenerationRunState.values) {
      message.hydrateGenerationState(state);
      expect(
        uiGenerationStatus(message),
        state == GenerationRunState.completed
            ? UiGenerationStatus.complete
            : state.isTerminal
            ? UiGenerationStatus.interrupted
            : UiGenerationStatus.generating,
        reason: state.name,
      );
    }
    expect(
      uiGenerationStatus(message.copyWith(isStreaming: true)),
      UiGenerationStatus.generating,
    );
  });
  test(
    'whole-text regex anchors preserve fences, newlines and exact mapped offsets',
    () {
      const text = 'prefix\n\n$_fence\n\nafter';
      final source = UiMessageSource.of([
        const TextPart(text),
      ]).sliceForPart(0, 0, text.length)!;
      final mapped = source.transform(
        (text) => text
            .replaceAll(RegExp(r'^'), 'HEADER\n')
            .replaceAll(RegExp(r'$'), '\nFOOTER')
            .replaceAll(RegExp(r'<think>.*?</think>'), 'bad'),
      );
      expect('HEADER'.allMatches(mapped.text), hasLength(1));
      expect(mapped.text, 'HEADER\nprefix\n\n$_fence\n\nafter\nFOOTER');
      final doc = parser.parse(mapped.text);
      final node = doc.children.whereType<CodeBlockNode>().single;
      expect(node.closed, isTrue);
      expect(mapped.resolve(doc, node), isNotNull);
      final protected = source.transform(
        (text) => text
            .replaceAll(RegExp(r'\n'), '')
            .replaceAll(RegExp(r'(?=```)'), 'BAD'),
      );
      final protectedDoc = parser.parse(protected.text);
      expect(
        protected.resolve(
          protectedDoc,
          protectedDoc.children.whereType<CodeBlockNode>().single,
        ),
        isNotNull,
      );
    },
  );
  test('historical splits keep chronology and transform whole source once', () {
    const text = 'before\n\n$_fence\n\nafter';
    final projected = projectAssistantTimeline(
      parts: const [ReasoningPart('plan'), TextPart(text)],
      liveTools: const [],
      reasoningSegments: const [TimelineReasoningRef(text: 'plan')],
      visualContent: 'a visual replacement with another length',
      contentSplitOffsets: const [8],
      reasoningCountAtSplit: const [1],
      toolCountAtSplit: const [0],
      transformProtectedText: (text) => text
          .replaceAll(RegExp(r'^'), 'HEADER\n')
          .replaceAll('after', 'longer after'),
    );
    expect(projected.fromParts, isFalse);
    expect(projected.blocks, hasLength(3));
    expect(projected.blocks.first.text, 'HEADER\nbefore\n\n');
    expect(projected.blocks[1].isThinking, isTrue);
    final last = projected.blocks.last;
    expect(last.text, '$_fence\n\nlonger after');
    expect(last.uiSource!.fences.single.fence.surfaceKey, '1:0');
    expect(
      last.uiSource!.messageOrdinalOf(last.uiSource!.fences.single.fence),
      0,
    );
    final doc = parser.parse(last.text!);
    expect(
      last.uiSource!.resolve(doc, doc.children.first as CodeBlockNode),
      isNotNull,
    );
  });
  test(
    'hidden thinking fences do not consume the visible native block budget',
    () {
      const text = '<think>\n\n$_fence\n\n</think>\n\n$_fence';
      final projected = projectAssistantTimeline(
        parts: const [TextPart(text)],
        liveTools: const [],
        reasoningSegments: const [],
        visualContent: text,
        parseInlineThinking: true,
      );
      final source = projected.blocks.where((b) => b.isText).single.uiSource!;
      expect(source.fences.single.fence.surfaceKey, '0:1');
      expect(source.messageOrdinalOf(source.fences.single.fence), 0);
    },
  );
  test(
    'tracked replacement anchors retain the complete transformed text across splits',
    () {
      final transformed =
          ProtectedText('abcdef', const [], offsets: const [0, 3, 6])
              .replaceAll(RegExp(r'^'), 'HEAD')
              .replaceAll('bcde', 'X')
              .replaceAll(RegExp(r'$'), 'TAIL');
      expect(transformed.text, 'HEADaXfTAIL');
      expect(transformed.offsets, [0, 6, 11]);
    },
  );
  test('inline thinking never restarts whole-run regex anchors', () {
    const text = 'before<think>reason</think>\n\n$_fence\n\nafter';
    final projected = projectAssistantTimeline(
      parts: const [TextPart(text)],
      liveTools: const [],
      reasoningSegments: const [],
      visualContent: text,
      parseInlineThinking: true,
      transformProtectedText: (text) =>
          text.replaceAll(RegExp(r'^'), 'HEADER\n'),
    );
    final texts = projected.blocks
        .where((b) => b.isText)
        .map((b) => b.text!)
        .toList();
    expect('HEADER'.allMatches(texts.join()), hasLength(1));
    expect(projected.blocks[1].isThinking, isTrue);
    expect(texts.first, 'HEADER\nbefore');
    expect(texts.last, '\n\n$_fence\n\nafter');
    final last = projected.blocks.last;
    final doc = parser.parse(last.text!);
    expect(
      last.uiSource!.resolve(doc, doc.children.first as CodeBlockNode),
      isNotNull,
    );
  });
  test(
    'fence across every adjacent TextPart cut survives whole-run transformation',
    () {
      const text = 'prefix\n\n$_fence\n\nafter';
      for (var cut = 0; cut <= text.length; cut++) {
        final projected = projectAssistantTimeline(
          parts: [
            TextPart(text.substring(0, cut)),
            TextPart(text.substring(cut)),
          ],
          liveTools: const [],
          reasoningSegments: const [],
          visualContent: text,
          transformProtectedText: (text) =>
              text.replaceAll(RegExp(r'^'), 'HEAD\n'),
        );
        final block = projected.blocks.single;
        expect(block.text, 'HEAD\n$text', reason: 'cut=$cut');
        final doc = parser.parse(block.text!);
        expect(
          block.uiSource!.resolve(
            doc,
            doc.children.whereType<CodeBlockNode>().single,
          ),
          isNotNull,
          reason: 'cut=$cut',
        );
      }
    },
  );
  test(
    'zero-width insertion retains distinct boundary sides after deleting all text',
    () {
      final p = ProtectedText(
        'before',
        const [],
        offsets: const [0, 6],
      ).replaceAll('before', '').replaceAll(RegExp(r'^'), 'HEADER');
      expect(p.text, 'HEADER');
      expect(p.offsets, [0, 6]);
      const raw = 'before$_fence';
      final projection = projectAssistantTimeline(
        parts: const [
          ReasoningPart('plan'),
          TextPart('before'),
          FilePart(uri: '/file', name: 'file'),
          TextPart(_fence),
        ],
        liveTools: const [],
        reasoningSegments: const [TimelineReasoningRef(text: 'plan')],
        visualContent: raw,
        contentSplitOffsets: const [6],
        reasoningCountAtSplit: const [1],
        toolCountAtSplit: const [0],
        transformProtectedText: (text) =>
            text.replaceAll('before', '').replaceAll(RegExp(r'^'), 'HEADER'),
      );
      expect(projection.blocks.first.text, 'HEADER');
      expect(projection.blocks[1].isThinking, isTrue);
      final block = projection.blocks.last;
      expect(block.text, _fence);
      final doc = parser.parse(block.text!);
      expect(
        block.uiSource!.resolve(doc, doc.children.single as CodeBlockNode),
        isNotNull,
      );
    },
  );
  test('a hidden leading prefix retains the first visible regex insertion', () {
    const text = '<think>reason</think>\n\n$_fence\n\nafter';
    final p = projectAssistantTimeline(
      parts: const [TextPart(text)],
      liveTools: const [],
      reasoningSegments: const [],
      visualContent: text,
      parseInlineThinking: true,
      transformProtectedText: (text) =>
          text.replaceAll(RegExp(r'^'), 'HEADER\n'),
    );
    expect(p.blocks.first.isThinking, isTrue);
    final block = p.blocks.last;
    expect(block.text, 'HEADER\n\n\n$_fence\n\nafter');
    final doc = parser.parse(block.text!);
    expect(
      block.uiSource!.resolve(
        doc,
        doc.children.whereType<CodeBlockNode>().single,
      ),
      isNotNull,
    );
  });
  test(
    'raw fence budget does not revoke a later card authorized after historical splits',
    () {
      final raw = List.filled(4, _fence).join('\n\n');
      final message = ChatMessage(
        id: 'revision',
        conversationId: 'conversation',
        role: 'assistant',
        parts: [const ReasoningPart('plan'), TextPart(raw)],
      );
      message.hydrateGenerationState(GenerationRunState.completed);
      final projection = projectAssistantTimeline(
        parts: message.parts,
        liveTools: const [],
        reasoningSegments: const [TimelineReasoningRef(text: 'plan')],
        visualContent: raw,
        contentSplitOffsets: [raw.indexOf('root =')],
        reasoningCountAtSplit: const [1],
        toolCountAtSplit: const [0],
      );
      final registry = UiRuntimeRegistry();
      addTearDown(registry.dispose);
      final entries = <UiRuntimeEntry>[];
      for (final block in projection.blocks.where((b) => b.isText)) {
        final document = parser.parse(block.text!);
        for (final node in document.children.whereType<CodeBlockNode>()) {
          final fence = block.uiSource?.resolve(document, node);
          if (fence == null || block.uiSource!.messageOrdinalOf(fence)! >= 3) {
            continue;
          }
          final entry = registry.obtain(
            message.conversationId,
            UiSurfaceOwner(
              revisionId: message.id,
              surfaceKey: fence.surfaceKey,
            ),
          );
          entry.controller.updateSource(
            fence.body,
            closed: fence.node.closed,
            generation: UiGenerationStatus.complete,
          );
          entries.add(entry);
        }
      }
      expect(
        entries.map((e) => e.controller.owner.surfaceKey),
        contains('1:3'),
      );
      final tokens = [for (final e in entries) e.controller.token];
      registry.reconcile(message, hasProviderReasoning: true);
      for (var i = 0; i < entries.length; i++) {
        expect(entries[i].controller.accepts(tokens[i]), isTrue);
      }
    },
  );
}
