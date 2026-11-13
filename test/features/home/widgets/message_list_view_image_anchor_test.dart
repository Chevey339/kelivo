import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/markdown_render_helpers.dart';

const _anchorText = 'Keep this reading paragraph in place.';

class _ImageChat extends ChatService {
  final conversation = Conversation(id: 'image-anchor', title: 'Images');

  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
}

class _DelayedImageResolver extends FileLinkResolver {
  _DelayedImageResolver({required super.workspaces, required this.root});

  final Directory root;
  final ready = {
    'above.png': Completer<void>(),
    'below.png': Completer<void>(),
  };
  final requested = <String>{};

  @override
  Future<FileSystemEntity?> resolveToHostEntry(
    KelivoLink link, {
    required String conversationId,
    required WorkspaceBinding binding,
  }) async {
    requested.add(link.relativePath);
    await ready[link.relativePath]!.future;
    return File('${root.path}/${link.relativePath}');
  }
}

enum _ImageSource { workspaceMarkdown, networkMarkdown, assistantPart }

class _DelayedImageClient extends Fake implements HttpClient {
  _DelayedImageClient(this.root);

  final Directory root;
  final ready = {
    'above.png': Completer<void>(),
    'below.png': Completer<void>(),
  };
  final requested = <String>{};

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final name = url.pathSegments.last;
    requested.add(name);
    return _ImageRequest(
      ready[name]!.future,
      File('${root.path}/$name').readAsBytesSync(),
    );
  }
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.ready, this.bytes);

  final Future<void> ready;
  final List<int> bytes;

  @override
  Future<HttpClientResponse> close() async {
    await ready;
    return _ImageResponse(bytes);
  }
}

class _ImageResponse extends Fake implements HttpClientResponse {
  _ImageResponse(this.bytes);

  final List<int> bytes;

  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

void main() {
  for (final (imageSource, sameMessage, simultaneous, inTable, wheelDelta) in [
    for (final imageSource in _ImageSource.values)
      for (final (sameMessage, simultaneous, inTable) in const [
        (false, false, false),
        (false, true, false),
        (true, false, false),
        (true, true, false),
        (false, true, true),
      ])
        if (!inTable || imageSource != _ImageSource.assistantPart)
          for (final wheelDelta in [
            -120.0,
            if (simultaneous && !inTable) 120.0,
          ])
            (imageSource, sameMessage, simultaneous, inTable, wheelDelta),
  ]) {
    final name =
        '${imageSource.name}: wheel reading anchor survives images loading '
        '${sameMessage ? 'within one message' : 'in preceding and following messages'} '
        '${simultaneous ? 'together with wheel input' : 'separately'}'
        '${inTable ? ' inside a horizontal table' : ''}, wheel=$wheelDelta';
    testWidgets(name, (tester) async {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      timelineImageAspects.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = Size(inTable ? 900 : 1400, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      for (final name in [
        'app.desktop_startup',
        'flutter_tts',
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers.global/events',
        'xyz.luan/audioplayers',
      ]) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(name),
          (call) async {
            // Bind the silent speech engine without native-plugin retries.
            if (call.method == 'getLanguages' || call.method == 'getEngines') {
              return <String>[];
            }
            if (call.method == 'create') {
              final id = (call.arguments as Map)['playerId'];
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                MethodChannel('xyz.luan/audioplayers/events/$id'),
                (_) async => null,
              );
            }
            return null;
          },
        );
      }
      final root = Directory.systemTemp.createTempSync('kelivo_image_anchor_');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final entry in {
        'above.png': (126, 200),
        'below.png': (120, 240),
      }.entries) {
        File('${root.path}/${entry.key}').writeAsBytesSync(
          image.encodePng(
            image.Image(width: entry.value.$1, height: entry.value.$2),
          ),
        );
      }

      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      addTearDown(settings.dispose);
      final workspaces = WorkspaceProvider(
        store: ExtensionEntityStore(harness.database),
      );
      await workspaces.loaded;
      addTearDown(workspaces.dispose);
      final resolver = _DelayedImageResolver(
        workspaces: workspaces,
        root: root,
      );
      final client = _DelayedImageClient(root);
      debugNetworkImageHttpClientProvider = () => client;
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      final ready = imageSource == _ImageSource.workspaceMarkdown
          ? resolver.ready
          : client.ready;
      String source(String filename) =>
          imageSource == _ImageSource.workspaceMarkdown
          ? 'kelivo://workspace/$filename'
          : 'https://image.invalid/$filename';
      final controller = ChatAutoFollowScrollController();
      addTearDown(controller.dispose);
      final listController = ListController();
      addTearDown(listController.dispose);
      final processing = ValueNotifier<String?>(null);
      addTearDown(processing.dispose);

      String paragraphs(String label, int count) =>
          List.generate(count, (i) => '$label paragraph $i.').join('\n\n');
      final above = inTable
          ? '| Screenshot | A | B | C | D |\n'
                '| --- | --- | --- | --- | --- |\n'
                '| ![above](${source('above.png')}) | a | b | c | d |'
          : 'Image above the reader.\n\n![above](${source('above.png')})';
      final reading =
          '${paragraphs('Before reading', 14)}\n\n$_anchorText\n\nAfter reading.';
      final below =
          'Image below the reader.\n\n![below](${source('below.png')})';
      final messages = <ChatMessage>[
        ChatMessage(
          id: 'prefix',
          conversationId: 'image-anchor',
          role: 'user',
          parts: [TextPart(paragraphs('Prefix', 8))],
        ),
        if (sameMessage)
          ChatMessage(
            id: 'long-markdown',
            conversationId: 'image-anchor',
            role: 'assistant',
            parts: [
              if (imageSource == _ImageSource.assistantPart) ...[
                const TextPart('Image above the reader.'),
                ImagePart(uri: source('above.png'), assetId: 'above'),
                TextPart(reading),
                ImagePart(uri: source('below.png'), assetId: 'below'),
                TextPart(paragraphs('Tail', 30)),
              ] else
                TextPart(
                  '$above\n\n$reading\n\n$below\n\n${paragraphs('Tail', 30)}',
                ),
            ],
          )
        else ...[
          for (final entry in {
            'above': above,
            'reading': reading,
            'below': below,
          }.entries)
            ChatMessage(
              id: entry.key,
              conversationId: 'image-anchor',
              role: 'assistant',
              parts:
                  imageSource == _ImageSource.assistantPart &&
                      entry.key != 'reading'
                  ? [
                      TextPart('Image ${entry.key} the reader.'),
                      ImagePart(
                        uri: source('${entry.key}.png'),
                        assetId: entry.key,
                      ),
                    ]
                  : [TextPart(entry.value)],
            ),
          ChatMessage(
            id: 'tail',
            conversationId: 'image-anchor',
            role: 'user',
            parts: [TextPart(paragraphs('Tail', 30))],
          ),
        ],
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider<ChatService>(create: (_) => _ImageChat()),
            Provider<FileLinkResolver>.value(value: resolver),
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  TtsProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
            ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageListView(
                scrollController: controller,
                listController: listController,
                messages: messages,
                byGroup: const {},
                versionSelections: const {},
                reasoning: const {},
                reasoningSegments: const {},
                contentSplits: const {},
                toolParts: const {},
                translations: const {},
                selecting: false,
                selectedItems: const {},
                dividerPadding: EdgeInsets.zero,
                processingFilesMessageId: processing,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      controller.jumpTo(
        controller.offset + markdownGlyphCenter(tester, _anchorText).dy - 300,
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(markdownGlyphCenter(tester, _anchorText).dy, closeTo(300, .5));
      expect(
        imageSource == _ImageSource.workspaceMarkdown
            ? resolver.requested
            : client.requested,
        containsAll(['above.png', 'below.png']),
      );
      if (inTable) {
        expect(
          find.byKey(
            const ValueKey('markstream-table-scroll'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }

      Finder imageFinder(String filename) => find.byWidgetPredicate((widget) {
        if (widget is! Image) return false;
        final provider = widget.image;
        final source = provider is ResizeImage
            ? provider.imageProvider
            : provider;
        return (source is FileImage &&
                source.file.path.endsWith('/$filename')) ||
            (source is NetworkImage && source.url.endsWith('/$filename'));
      }, skipOffstage: false);
      bool hasDecoded(String filename) {
        final finder = imageFinder(filename);
        return finder.evaluate().isNotEmpty &&
            tester
                    .widget<RawImage>(
                      find.descendant(
                        of: finder,
                        matching: find.byType(RawImage, skipOffstage: false),
                        skipOffstage: false,
                      ),
                    )
                    .image !=
                null;
      }

      Future<void> finishImages(
        List<String> filenames,
        double expectedY,
      ) async {
        for (final filename in filenames) {
          ready[filename]!.complete();
        }
        var decoded = false;
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            markdownGlyphCenter(tester, _anchorText).dy,
            closeTo(expectedY, .5),
            reason:
                'Loading $filenames must preserve the visible reading glyph on every frame.',
          );

          if (filenames.every(hasDecoded)) {
            decoded = true;
            break;
          }
        }
        expect(decoded, isTrue, reason: '$filenames must finish decoding.');
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            markdownGlyphCenter(tester, _anchorText).dy,
            closeTo(expectedY, .5),
          );
        }
      }

      // A below-reader image changes the distance to the end, but must not
      // move the reader. Preserving distance from the end is not sufficient.
      if (!simultaneous) {
        final beforeBelow = controller.offset;
        final extentBeforeBelow = controller.position.maxScrollExtent;
        await finishImages(['below.png'], 300);
        expect(controller.offset, closeTo(beforeBelow, .5));
        expect(
          controller.position.maxScrollExtent,
          greaterThan(extentBeforeBelow + 100),
        );
      }

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: Offset(400, 300),
          scrollDelta: Offset(0, wheelDelta),
        ),
      );
      if (!simultaneous) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          markdownGlyphCenter(tester, _anchorText).dy,
          closeTo(300 - wheelDelta, .5),
        );
      }
      // In this variant resolution completes after pointerScroll changes
      // pixels, but before that wheel movement has been laid out or painted.
      await finishImages([
        'above.png',
        if (simultaneous) 'below.png',
      ], 300 - wheelDelta);
      if (!sameMessage && simultaneous && !inTable && wheelDelta < 0) {
        // Re-enter a recycled row with its decoded pixels evicted. Its
        // measured aspect must reserve the same height throughout reloading.
        final returnOffset = controller.offset;
        controller.jumpTo(controller.position.maxScrollExtent);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(imageFinder('above.png'), findsNothing);
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        ready['above.png'] = Completer<void>();
        controller.jumpTo(returnOffset);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            markdownGlyphCenter(tester, _anchorText).dy,
            closeTo(300 - wheelDelta, .5),
          );
        }
        await finishImages(['above.png'], 300 - wheelDelta);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugNetworkImageHttpClientProvider = null;
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
