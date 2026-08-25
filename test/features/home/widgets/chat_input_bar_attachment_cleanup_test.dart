import "../../../support/business_test_harness.dart";
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/image_compressor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:irondash_message_channel/irondash_message_channel.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:super_native_extensions/src/native/context.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;
  Completer<void>? appDataGate;
  Completer<void>? cacheGate;
  int startedAppDataRequests = 0;
  int completedAppDataRequests = 0;

  Future<String> _getAppDataPath() async {
    startedAppDataRequests++;
    await appDataGate?.future;
    completedAppDataRequests++;
    return path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() => _getAppDataPath();

  @override
  Future<String?> getApplicationSupportPath() => _getAppDataPath();

  @override
  Future<String?> getApplicationCachePath() async {
    await cacheGate?.future;
    return '$path/cache';
  }

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

const _config = ImageCompressConfig(
  enabled: true,
  quality: 80,
  maxLongEdge: 1024,
  includeTransparent: false,
);

void main() {
  late PathProviderPlatform previousPathProvider;
  late _FakePathProviderPlatform fakePathProvider;
  late Directory appSupportDir;
  late Directory userDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    previousPathProvider = PathProviderPlatform.instance;
    appSupportDir = await Directory.systemTemp.createTemp(
      'kelivo_input_cleanup_app_',
    );
    userDir = await Directory.systemTemp.createTemp(
      'kelivo_input_cleanup_user_',
    );
    fakePathProvider = _FakePathProviderPlatform(appSupportDir.path);
    PathProviderPlatform.instance = fakePathProvider;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await _forceDelete(appSupportDir);
    await _forceDelete(userDir);
  });

  Future<File> writeUserImage(
    String name, {
    int byteCount = 256,
    Directory? parent,
  }) async {
    final dir = parent ?? userDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(List<int>.filled(byteCount, 7), flush: true);
    return file;
  }

  Future<bool> fileExists(WidgetTester tester, File file) async {
    final result = await tester.runAsync(() => file.exists());
    return result ?? false;
  }

  Future<bool> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await tester.runAsync(() async {
      final deadline = DateTime.now().add(timeout);
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return condition();
    });
    return result ?? false;
  }

  Widget buildHarness({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Future<ChatInputSubmissionResult> Function(ChatInputData input)
    onSend,
    ChatInputBarController? mediaController,
    SettingsProvider? settings,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: settings ?? SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider.value(
          value: AssistantProvider(
            preferences: createBusinessTestPreferences(),
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            focusNode: focusNode,
            mediaController: mediaController,
            onSend: onSend,
          ),
        ),
      ),
    );
  }

  testWidgets('超过 5000 个字符的粘贴内容转为文本附件', (tester) async {
    final nativeClipboardContext = MockMessageChannelContext()
      ..registerMockMethodCallHandler('ClipboardReader', (_) {
        throw PlatformException(code: 'unavailable-in-widget-test');
      });
    setContextOverride(nativeClipboardContext);

    var clipboardText = '';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    const clipboardFilesChannel = MethodChannel('app.clipboard');
    messenger.setMockMethodCallHandler(
      clipboardFilesChannel,
      (_) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(clipboardFilesChannel, null);
    });

    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();
    ChatInputData? submitted;
    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (input) async {
          submitted = input;
          return ChatInputSubmissionResult.rejected;
        },
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    clipboardText = List.filled(5000, 'a').join();
    await _invokePasteShortcut(tester, focusNode);
    expect(
      await pumpUntil(tester, () => controller.text == clipboardText),
      isTrue,
    );
    expect(mediaController.snapshotInput(controller.text).documents, isEmpty);

    controller.text = 'keep';
    final firstLongPaste = List.filled(5001, 'b').join();
    final secondLongPaste = List.filled(5001, 'c').join();
    clipboardText = firstLongPaste;
    final firstWriteGate = Completer<void>();
    fakePathProvider.appDataGate = firstWriteGate;
    final startedRequestsBeforePaste = fakePathProvider.startedAppDataRequests;
    await _invokePasteShortcut(tester, focusNode);
    expect(
      fakePathProvider.startedAppDataRequests,
      greaterThan(startedRequestsBeforePaste),
    );

    fakePathProvider.appDataGate = null;
    clipboardText = secondLongPaste;
    await _invokePasteShortcut(tester, focusNode);
    expect(mediaController.hasUnreadyImages, isTrue);
    expect(mediaController.snapshotInput(controller.text).documents, isEmpty);

    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    expect(submitted, isNull);

    firstWriteGate.complete();
    expect(
      await pumpUntil(
        tester,
        () =>
            mediaController.snapshotInput(controller.text).documents.length ==
            2,
      ),
      isTrue,
    );

    final input = mediaController.snapshotInput(controller.text);
    final firstAttachment = input.documents[0];
    final secondAttachment = input.documents[1];
    expect(controller.text, 'keep');
    final pastedFileName = RegExp(r'^pasted_\d+(?:\(\d+\))?\.txt$');
    expect(firstAttachment.fileName, matches(pastedFileName));
    expect(secondAttachment.fileName, matches(pastedFileName));
    expect(firstAttachment.path, isNot(secondAttachment.path));
    expect(firstAttachment.mime, 'text/plain');
    expect(secondAttachment.mime, 'text/plain');
    expect(
      await tester.runAsync(() => File(firstAttachment.path).readAsString()),
      firstLongPaste,
    );
    expect(
      await tester.runAsync(() => File(secondAttachment.path).readAsString()),
      secondLongPaste,
    );

    final uploadDir = Directory('${appSupportDir.path}/upload');
    final existingPaths = await tester.runAsync(
      () => uploadDir.list().map((entry) => entry.path).toSet(),
    );

    final disposeGate = Completer<void>();
    fakePathProvider.appDataGate = disposeGate;
    final completedRequestsBeforeDispose =
        fakePathProvider.completedAppDataRequests;
    clipboardText = List.filled(5001, 'd').join();
    await _invokePasteShortcut(tester, focusNode);
    expect(mediaController.hasUnreadyImages, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      disposeGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(
      fakePathProvider.completedAppDataRequests,
      greaterThan(completedRequestsBeforeDispose),
    );
    final remainingPaths = await tester.runAsync(
      () => uploadDir.list().map((entry) => entry.path).toSet(),
    );
    expect(remainingPaths, existingPaths);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('关闭超长粘贴转文件后保持为输入文本', (tester) async {
    final nativeClipboardContext = MockMessageChannelContext()
      ..registerMockMethodCallHandler('ClipboardReader', (_) {
        throw PlatformException(code: 'unavailable-in-widget-test');
      });
    setContextOverride(nativeClipboardContext);

    var clipboardText = '';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    const clipboardFilesChannel = MethodChannel('app.clipboard');
    messenger.setMockMethodCallHandler(
      clipboardFilesChannel,
      (_) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(clipboardFilesChannel, null);
    });

    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setLongPasteAsFile(false);

    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();
    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        settings: settings,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    clipboardText = List.filled(5001, 'a').join();
    await _invokePasteShortcut(tester, focusNode);
    expect(
      await pumpUntil(tester, () => controller.text == clipboardText),
      isTrue,
    );
    expect(mediaController.snapshotInput(controller.text).documents, isEmpty);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('自定义阈值决定是否将粘贴转为文本附件', (tester) async {
    final nativeClipboardContext = MockMessageChannelContext()
      ..registerMockMethodCallHandler('ClipboardReader', (_) {
        throw PlatformException(code: 'unavailable-in-widget-test');
      });
    setContextOverride(nativeClipboardContext);

    var clipboardText = '';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    const clipboardFilesChannel = MethodChannel('app.clipboard');
    messenger.setMockMethodCallHandler(
      clipboardFilesChannel,
      (_) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(clipboardFilesChannel, null);
    });

    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setLongPasteAsFileThreshold(100);

    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();
    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        settings: settings,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    clipboardText = List.filled(100, 'a').join();
    await _invokePasteShortcut(tester, focusNode);
    expect(
      await pumpUntil(tester, () => controller.text == clipboardText),
      isTrue,
    );
    expect(mediaController.snapshotInput(controller.text).documents, isEmpty);

    controller.text = '';
    clipboardText = List.filled(101, 'b').join();
    await _invokePasteShortcut(tester, focusNode);
    expect(
      await pumpUntil(
        tester,
        () =>
            controller.text.isEmpty &&
            mediaController.snapshotInput(controller.text).documents.length ==
                1,
      ),
      isTrue,
    );
    expect(
      await tester.runAsync(
        () => File(
          mediaController.snapshotInput(controller.text).documents.single.path,
        ).readAsString(),
      ),
      clipboardText,
    );

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('输入法图片落盘期间阻止发送并在取消时清理缓存', (tester) async {
    final controller = TextEditingController(text: 'send with image');
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();
    ChatInputData? submitted;
    Completer<ChatInputSubmissionResult>? submissionGate;
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    final cacheGate = Completer<void>();
    fakePathProvider.cacheGate = cacheGate;
    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (input) async {
          submitted = input;
          final gate = submissionGate;
          if (gate != null) return await gate.future;
          return ChatInputSubmissionResult.rejected;
        },
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.runAsync(() async {
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .insertContent(
            KeyboardInsertedContent(
              mimeType: 'image/png',
              uri: 'content://com.google.android.inputmethod.latin/image.png',
              data: bytes,
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    expect(mediaController.hasUnreadyImages, isTrue);
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    expect(submitted, isNull);

    cacheGate.complete();
    fakePathProvider.cacheGate = null;
    expect(
      await pumpUntil(
        tester,
        () =>
            !mediaController.hasUnreadyImages &&
            mediaController.snapshotInput('').imagePaths.length == 1,
      ),
      isTrue,
    );
    final imagePath = mediaController.snapshotInput('').imagePaths.single;
    expect(imagePath, endsWith('.png'));
    expect(
      await tester.runAsync(() => File(imagePath).readAsBytes()),
      orderedEquals(bytes),
    );
    submissionGate = Completer<ChatInputSubmissionResult>();
    await tester.pump();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    expect(submitted?.text, 'send with image');
    expect(submitted?.imagePaths, [imagePath]);
    expect(controller.text, isEmpty);
    // 提交的附件跟文本一样立刻离开输入框，不等发送 future 完成。
    expect(mediaController.snapshotInput('').imagePaths, isEmpty);

    controller.text = 'send with image';
    const lateDocument = DocumentAttachment(
      path: '/tmp/late.pdf',
      fileName: 'late.pdf',
      mime: 'application/pdf',
    );
    mediaController.addFiles(const [lateDocument]);
    await tester.runAsync(() async {
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .insertContent(
            KeyboardInsertedContent(
              mimeType: 'image/png',
              uri: 'content://com.google.android.inputmethod.latin/late.png',
              data: bytes,
            ),
          );
    });
    expect(
      await pumpUntil(
        tester,
        () =>
            !mediaController.hasUnreadyImages &&
            mediaController.snapshotInput('').imagePaths.length == 1,
      ),
      isTrue,
    );
    final lateImagePath = mediaController.snapshotInput('').imagePaths.single;
    expect(lateImagePath, isNot(imagePath));
    submissionGate.complete(ChatInputSubmissionResult.sent);
    submissionGate = null;
    await tester.pumpAndSettle();
    expect(controller.text, 'send with image');
    expect(mediaController.snapshotInput('').imagePaths, [lateImagePath]);
    expect(mediaController.snapshotInput('').documents, [lateDocument]);

    submissionGate = Completer<ChatInputSubmissionResult>();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    expect(mediaController.snapshotInput('').imagePaths, isEmpty);
    expect(mediaController.snapshotInput('').documents, isEmpty);
    controller.value = const TextEditingValue(
      text: '下一条',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 2),
    );
    submissionGate.complete(ChatInputSubmissionResult.rejected);
    submissionGate = null;
    await tester.pumpAndSettle();
    expect(controller.text, 'send with image下一条');
    expect(controller.selection, const TextSelection.collapsed(offset: 18));
    expect(controller.value.composing, const TextRange(start: 15, end: 17));
    // 被拒绝的发送会把附件放回输入框。
    expect(mediaController.snapshotInput('').imagePaths, [lateImagePath]);
    expect(mediaController.snapshotInput('').documents, [lateDocument]);

    controller.text = 'discarded';
    submissionGate = Completer<ChatInputSubmissionResult>();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    mediaController.clearDraft();
    controller.value = const TextEditingValue(
      text: 'replacement',
      selection: TextSelection.collapsed(offset: 4),
    );
    submissionGate.complete(ChatInputSubmissionResult.rejected);
    submissionGate = null;
    await tester.pumpAndSettle();
    expect(controller.text, 'replacement');
    expect(controller.selection, const TextSelection.collapsed(offset: 4));

    final cacheDir = Directory('${appSupportDir.path}/cache');
    await tester.runAsync(() => cacheDir.create(recursive: true));
    final cancelledCompressionGate = Completer<void>();
    fakePathProvider.appDataGate = cancelledCompressionGate;
    await tester.runAsync(() async {
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .insertContent(
            KeyboardInsertedContent(
              mimeType: 'image/png',
              uri:
                  'content://com.google.android.inputmethod.latin/cancelled.png',
              data: Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final cancelledSource = await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        final files = await cacheDir.list().toList();
        for (final file in files.whereType<File>()) {
          if (file.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('paste_')) {
            return file;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return null;
    });
    expect(cancelledSource, isNotNull);
    expect(mediaController.hasUnreadyImages, isTrue);

    mediaController.clearDraft();
    cancelledCompressionGate.complete();
    fakePathProvider.appDataGate = null;
    expect(
      await pumpUntil(tester, () => !cancelledSource!.existsSync()),
      isTrue,
    );

    final cachedFiles = await tester.runAsync(
      () async => await cacheDir.exists() ? await cacheDir.list().toList() : [],
    );
    expect(mediaController.hasUnreadyImages, isFalse);
    expect(mediaController.snapshotInput('').imagePaths, isEmpty);
    expect(cachedFiles, isEmpty);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('退出页面会清理排队中的应用临时图片', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();
    final gate = Completer<void>();
    fakePathProvider.appDataGate = gate;
    late List<File> sources;
    await tester.runAsync(() async {
      sources = [
        await writeUserImage('queued_temp_1.png'),
        await writeUserImage('queued_temp_2.png'),
        await writeUserImage('queued_temp_3.png'),
      ];
    });

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );
    final startedRequestsBeforeEnqueue =
        fakePathProvider.startedAppDataRequests;
    await tester.runAsync(() async {
      mediaController.enqueueImages(
        sources.map((file) => file.path).toList(),
        _config,
        deleteSourcesAfterProcessing: true,
      );
    });
    expect(
      fakePathProvider.startedAppDataRequests - startedRequestsBeforeEnqueue,
      2,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    expect(await pumpUntil(tester, () => !sources[2].existsSync()), isTrue);

    final uploadDir = Directory('${appSupportDir.path}/upload');
    gate.complete();
    fakePathProvider.appDataGate = null;
    expect(
      await pumpUntil(
        tester,
        () =>
            sources.every((file) => !file.existsSync()) &&
            (!uploadDir.existsSync() || uploadDir.listSync().isEmpty),
      ),
      isTrue,
    );

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('发送后保留用户源文件，提交的是压缩副本', (tester) async {
    late File source;
    await tester.runAsync(() async {
      source = await writeUserImage('user_photo.png');
    });
    final product = File('${appSupportDir.path}/upload/user_photo.png');
    final controller = TextEditingController(text: 'with image');
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();
    ChatInputData? submitted;

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (input) async {
          submitted = input;
          return ChatInputSubmissionResult.sent;
        },
      ),
    );

    await tester.runAsync(() async {
      mediaController.enqueueImages(
        [source.path],
        _config,
        deleteSourcesAfterProcessing: false,
      );
    });
    expect(
      await pumpUntil(tester, () => !mediaController.hasUnreadyImages),
      isTrue,
      reason: 'image processing did not finish in time',
    );
    await tester.pump();
    expect(await fileExists(tester, product), isTrue);

    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pumpAndSettle();

    expect(submitted?.imagePaths.single, product.path);
    expect(await fileExists(tester, source), isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('restoreInput 清空草稿后保留用户源文件', (tester) async {
    late File source;
    await tester.runAsync(() async {
      source = await writeUserImage('restore_user.png');
    });
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    await tester.runAsync(() async {
      mediaController.enqueueImages(
        [source.path],
        _config,
        deleteSourcesAfterProcessing: false,
      );
    });
    expect(
      await pumpUntil(tester, () => !mediaController.hasUnreadyImages),
      isTrue,
    );
    await tester.pump();

    await tester.runAsync(() async {
      mediaController.restoreInput(const ChatInputData(text: ''));
    });
    await tester.pump();

    expect(await fileExists(tester, source), isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('dispose 后保留用户源文件', (tester) async {
    late File source;
    await tester.runAsync(() async {
      source = await writeUserImage('dispose_user.png');
    });
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    await tester.runAsync(() async {
      mediaController.enqueueImages(
        [source.path],
        _config,
        deleteSourcesAfterProcessing: false,
      );
    });
    expect(
      await pumpUntil(tester, () => !mediaController.hasUnreadyImages),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());

    expect(await fileExists(tester, source), isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('丢弃复用的已有上传时不删除该文件', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    late File source;
    await tester.runAsync(() async {
      source = await writeUserImage('reused_user.png');
      mediaController.enqueueImages(
        [source.path],
        _config,
        deleteSourcesAfterProcessing: false,
      );
    });
    expect(
      await pumpUntil(tester, () => !mediaController.hasUnreadyImages),
      isTrue,
      reason: 'image processing did not finish in time',
    );
    final stored = File(mediaController.snapshotInput('').imagePaths.single);
    expect(await fileExists(tester, stored), isTrue);
    mediaController.clearImages();

    // The same picture again resolves to the stored upload, which earlier
    // messages may still reference — discarding this draft must not delete it.
    await tester.runAsync(() async {
      mediaController.enqueueImages(
        [source.path],
        _config,
        deleteSourcesAfterProcessing: false,
      );
      mediaController.clearImages();
      await Future<void>.delayed(const Duration(seconds: 2));
    });

    expect(await fileExists(tester, stored), isTrue);
    expect(await fileExists(tester, source), isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('处理中丢弃只清理压缩副本，保留用户源文件', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    late File source;
    final cleanupObserved = await tester.runAsync(() async {
      source = await writeUserImage(
        'inflight_user.png',
        byteCount: 8 * 1024 * 1024,
      );
      final uploadDir = Directory('${appSupportDir.path}/upload');
      await uploadDir.create(recursive: true);
      final product = File('${uploadDir.path}/inflight_user.png');
      var sawProductCreated = false;
      final productDeleted = Completer<void>();
      final subscription = uploadDir
          .watch(events: FileSystemEvent.create | FileSystemEvent.delete)
          .listen((event) {
            if (event.path != product.path) return;
            if (event.type == FileSystemEvent.create) {
              sawProductCreated = true;
            } else if (event.type == FileSystemEvent.delete &&
                sawProductCreated &&
                !productDeleted.isCompleted) {
              productDeleted.complete();
            }
          });
      addTearDown(subscription.cancel);

      mediaController.enqueueImages(
        [source.path],
        _config,
        deleteSourcesAfterProcessing: false,
      );
      // Discard synchronously while the task is in flight.
      mediaController.clearImages();

      await productDeleted.future.timeout(const Duration(seconds: 10));
      return !await product.exists();
    });

    expect(
      cleanupObserved,
      isTrue,
      reason: 'discarded compressed copy was not cleaned up',
    );
    expect(await fileExists(tester, source), isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('应用自有临时源在处理完成后被删除', (tester) async {
    late File tempSource;
    await tester.runAsync(() async {
      tempSource = await writeUserImage('pasted_temp.png');
    });
    final product = File('${appSupportDir.path}/upload/pasted_temp.png');
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    await tester.runAsync(() async {
      mediaController.enqueueImages(
        [tempSource.path],
        _config,
        deleteSourcesAfterProcessing: true,
      );
    });
    expect(
      await pumpUntil(tester, () => !mediaController.hasUnreadyImages),
      isTrue,
    );

    expect(await fileExists(tester, tempSource), isFalse);
    expect(await fileExists(tester, product), isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('源文件删除失败会记录日志且保留源文件', (tester) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    try {
      await tester.pumpWidget(
        buildHarness(
          controller: controller,
          focusNode: focusNode,
          mediaController: mediaController,
          onSend: (_) async => ChatInputSubmissionResult.rejected,
        ),
      );

      late File source;
      await tester.runAsync(() async {
        final readOnlyDir = Directory('${userDir.path}/readonly');
        await readOnlyDir.create(recursive: true);
        source = await writeUserImage('locked_temp.png', parent: readOnlyDir);
        await Process.run('chmod', ['0555', readOnlyDir.path]);

        mediaController.enqueueImages(
          [source.path],
          _config,
          deleteSourcesAfterProcessing: true,
        );
      });
      addTearDown(() async {
        await Process.run('chmod', ['-R', '0755', userDir.path]);
      });
      expect(
        await pumpUntil(tester, () => !mediaController.hasUnreadyImages),
        isTrue,
      );

      expect(
        logs.any((line) => line.contains('[ChatInputBar] Failed to delete')),
        isTrue,
        reason: 'deletion failure must be diagnosable via logs',
      );
      expect(await fileExists(tester, source), isTrue);
    } finally {
      debugPrint = previousDebugPrint;
    }

    controller.dispose();
    focusNode.dispose();
  }, skip: !(Platform.isMacOS || Platform.isLinux));

  testWidgets('压缩失败会记录日志且保留用户源文件', (tester) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    try {
      await tester.pumpWidget(
        buildHarness(
          controller: controller,
          focusNode: focusNode,
          mediaController: mediaController,
          onSend: (_) async => ChatInputSubmissionResult.rejected,
        ),
      );

      late File source;
      await tester.runAsync(() async {
        // Block the upload directory with a plain file so compression cannot
        // persist the copy and must fail.
        await File('${appSupportDir.path}/upload').writeAsBytes(const [0]);
        source = await writeUserImage('failing_user.png');

        mediaController.enqueueImages(
          [source.path],
          _config,
          deleteSourcesAfterProcessing: false,
        );
      });
      expect(
        await pumpUntil(
          tester,
          () => logs.any((line) => line.contains('[ImageCompressor]')),
        ),
        isTrue,
        reason: 'compression failure must be diagnosable via logs',
      );

      expect(await fileExists(tester, source), isTrue);
    } finally {
      debugPrint = previousDebugPrint;
    }

    controller.dispose();
    focusNode.dispose();
  });
}

Future<void> _invokePasteShortcut(
  WidgetTester tester,
  FocusNode focusNode,
) async {
  final focus = tester
      .widgetList<Focus>(
        find.ancestor(of: find.byType(TextField), matching: find.byType(Focus)),
      )
      .firstWhere((widget) => widget.onKeyEvent != null);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.runAsync(() async {
    expect(
      focus.onKeyEvent!(
        focusNode,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyV,
          logicalKey: LogicalKeyboardKey.keyV,
          timeStamp: Duration.zero,
        ),
      ),
      KeyEventResult.handled,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _forceDelete(Directory dir) async {
  try {
    if (await dir.exists()) {
      await Process.run('chmod', ['-R', '0755', dir.path]);
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}
