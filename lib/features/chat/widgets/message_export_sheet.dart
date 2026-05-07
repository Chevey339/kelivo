import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'image_preview_sheet.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/models/assistant.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../shared/widgets/export_capture_scope.dart';
import '../../../shared/widgets/mermaid_exporter.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/model_icon.dart';
import '../utils/thinking_tag_parser.dart';
import 'chat_message_widget.dart'
    show ChatMessageWidget, ToolUIPart, ReasoningSegment;

// Shared helpers
String _guessImageMime(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/png';
}

String? _modelDisplayNameFromSettings(
  SettingsProvider settings,
  ChatMessage msg,
) {
  if (msg.role != 'assistant') return null;
  final modelId = msg.modelId;
  if (modelId == null || modelId.isEmpty) return null;
  String? name;
  String baseId = modelId;
  final providerId = msg.providerId;
  if (providerId != null && providerId.isNotEmpty) {
    try {
      final cfg = settings.getProviderConfig(providerId);
      final ov = cfg.modelOverrides[modelId] as Map?;
      if (ov != null) {
        final overrideName = (ov['name'] as String?)?.trim();
        if (overrideName != null && overrideName.isNotEmpty) {
          name = overrideName;
        }
        final apiId = (ov['apiModelId'] ?? ov['api_model_id'])
            ?.toString()
            .trim();
        if (apiId != null && apiId.isNotEmpty) {
          baseId = apiId;
        }
      }
    } catch (_) {
      // ignore lookup issues; fall back to inference below.
    }
  }

  final inferred = ModelRegistry.infer(
    ModelInfo(id: baseId, displayName: baseId),
  );
  final fallback = inferred.displayName.trim();
  return name ?? (fallback.isNotEmpty ? fallback : baseId);
}

String _getRoleNameFromDependencies({
  required AppLocalizations l10n,
  required SettingsProvider settings,
  required UserProvider userProvider,
  required Assistant? assistant,
  required ChatMessage msg,
}) {
  if (msg.role == 'user') {
    return userProvider.name;
  }
  if (msg.role == 'assistant') {
    if (assistant != null &&
        assistant.useAssistantName == true &&
        assistant.name.trim().isNotEmpty) {
      return assistant.name.trim();
    }
    final modelName = _modelDisplayNameFromSettings(settings, msg);
    if (modelName != null && modelName.isNotEmpty) {
      return modelName;
    }
    return l10n.messageExportSheetAssistant;
  }
  return msg.role;
}

_Parsed _parseContent(String raw) {
  // Robustly parse inline attachments in the form [image:...] and [file:path|name|mime]
  // without requiring escaping backslashes, and guard against malformed tokens.
  final images = <String>[];
  final docs = <_DocRef>[];
  final buffer = StringBuffer();
  int idx = 0;
  while (idx < raw.length) {
    // Fast path: only try to parse when current char is '['
    if (raw.codeUnitAt(idx) == 0x5B /* '[' */ ) {
      final sub = raw.substring(idx);
      // [image:...]
      final mImg = RegExp(r"^\[image:([^\]]+)\]").firstMatch(sub);
      if (mImg != null) {
        final p = (mImg.groupCount >= 1 ? mImg.group(1) : null)?.trim();
        if (p != null && p.isNotEmpty) images.add(p);
        idx += mImg.group(0)!.length;
        continue;
      }
      // [file:path|name|mime]
      final mFile = RegExp(
        r"^\[file:([^|\]]+)\|([^|\]]+)\|([^\]]+)\]",
      ).firstMatch(sub);
      if (mFile != null) {
        final path =
            (mFile.groupCount >= 1 ? mFile.group(1) : null)?.trim() ?? '';
        final name =
            (mFile.groupCount >= 2 ? mFile.group(2) : null)?.trim() ?? 'file';
        final mime =
            (mFile.groupCount >= 3 ? mFile.group(3) : null)?.trim() ??
            'text/plain';
        docs.add(_DocRef(path: path, fileName: name, mime: mime));
        idx += mFile.group(0)!.length;
        continue;
      }
    }
    // Fallback: normal character
    buffer.write(raw[idx]);
    idx++;
  }
  return _Parsed(buffer.toString().trim(), images, docs);
}

String _softBreakMd(String input) {
  // Insert zero-width break in very long tokens outside fenced code blocks.
  final lines = input.split('\n');
  final out = StringBuffer();
  bool inFence = false;
  for (final line in lines) {
    String l = line;
    final trimmed = l.trimLeft();
    if (trimmed.startsWith('```')) {
      inFence = !inFence; // toggle on fence lines
      out.writeln(l);
      continue;
    }
    if (!inFence) {
      l = l.replaceAllMapped(RegExp(r'(\S{60,})'), (m) {
        final s = m.group(1)!;
        final buf = StringBuffer();
        for (int i = 0; i < s.length; i++) {
          buf.write(s[i]);
          if ((i + 1) % 20 == 0) buf.write('\u200B');
        }
        return buf.toString();
      });
    }
    out.writeln(l);
  }
  return out.toString();
}

class _ThinkingExportData {
  const _ThinkingExportData({
    required this.cleanedContent,
    required this.thinkingTexts,
  });

  final String cleanedContent;
  final List<String> thinkingTexts;
}

_ThinkingExportData _thinkingExportDataForMessage(ChatMessage message) {
  final thinkingTexts = <String>[];
  var cleanedContent = message.content.trim();

  // Prefer structured reasoning segments (may include multiple blocks).
  final segJson = (message.reasoningSegmentsJson ?? '').trim();
  if (segJson.isNotEmpty) {
    try {
      final decoded = jsonDecode(segJson);
      if (decoded is List) {
        _addReasoningSegmentTexts(thinkingTexts, decoded);
      } else if (decoded is Map) {
        _addReasoningSegmentTexts(
          thinkingTexts,
          decoded['segments'] as List? ?? const <dynamic>[],
        );
      }
    } catch (_) {}
  }

  // Fall back to <think> tags if segments are not available.
  if (thinkingTexts.isEmpty) {
    final parsed = ThinkingTagParser.parseLegacyInlineBlocks(message.content);
    cleanedContent = parsed.visibleContent;
    thinkingTexts.addAll(parsed.thinkingTexts);
  }

  // Fall back to the legacy reasoningText field.
  if (thinkingTexts.isEmpty) {
    final rt = (message.reasoningText ?? '').trim();
    if (rt.isNotEmpty) thinkingTexts.add(rt);
  }

  return _ThinkingExportData(
    cleanedContent: cleanedContent,
    thinkingTexts: thinkingTexts,
  );
}

void _addReasoningSegmentTexts(List<String> output, List<dynamic> segments) {
  for (final item in segments) {
    if (item is Map) {
      final t = (item['text']?.toString() ?? '').trim();
      if (t.isNotEmpty) output.add(t);
    }
  }
}

class _ExportReasoningPayload {
  const _ExportReasoningPayload({
    required this.segments,
    this.contentSplitOffsets,
    this.reasoningCountAtSplit,
    this.toolCountAtSplit,
  });

  final List<ReasoningSegment> segments;
  final List<int>? contentSplitOffsets;
  final List<int>? reasoningCountAtSplit;
  final List<int>? toolCountAtSplit;
}

List<ToolUIPart> _exportToolPartsForMessage(
  BuildContext context,
  ChatMessage message,
) {
  try {
    final chatService = context.read<ChatService>();
    final events = chatService.getToolEvents(message.id);
    if (events.isEmpty) return const <ToolUIPart>[];
    return events
        .map(
          (e) => ToolUIPart(
            id: (e['id'] ?? '').toString(),
            toolName: (e['name'] ?? '').toString(),
            arguments:
                (e['arguments'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{},
            content: (e['content']?.toString().isNotEmpty == true)
                ? e['content'].toString()
                : null,
            loading: !(e['content']?.toString().isNotEmpty == true),
          ),
        )
        .toList();
  } catch (_) {
    return const <ToolUIPart>[];
  }
}

_ExportReasoningPayload _exportReasoningPayloadForMessage(
  ChatMessage message, {
  required bool expandThinkingContent,
}) {
  final segJson = (message.reasoningSegmentsJson ?? '').trim();
  final segments = <ReasoningSegment>[];
  List<int>? offsets;
  List<int>? reasoningCounts;
  List<int>? toolCounts;

  if (segJson.isNotEmpty) {
    try {
      final decoded = jsonDecode(segJson);
      if (decoded is Map<String, dynamic>) {
        final rawSegments = (decoded['segments'] as List? ?? const <dynamic>[]);
        final contentSplits = (decoded['contentSplits'] as Map?)
            ?.cast<String, dynamic>();
        if (contentSplits != null) {
          offsets = (contentSplits['offsets'] as List? ?? const <dynamic>[])
              .map((item) => item as int)
              .toList();
          reasoningCounts =
              (contentSplits['reasoningCounts'] as List? ?? const <dynamic>[])
                  .map((item) => item as int)
                  .toList();
          toolCounts =
              (contentSplits['toolCounts'] as List? ?? const <dynamic>[])
                  .map((item) => item as int)
                  .toList();
          final normalizedLength = [
            offsets.length,
            reasoningCounts.length,
            toolCounts.length,
          ].reduce((a, b) => a < b ? a : b);
          offsets = List<int>.of(offsets.take(normalizedLength));
          reasoningCounts = List<int>.of(
            reasoningCounts.take(normalizedLength),
          );
          toolCounts = List<int>.of(toolCounts.take(normalizedLength));
        }
        for (final item in rawSegments) {
          if (item is! Map) continue;
          final map = item.cast<String, dynamic>();
          final text = (map['text']?.toString() ?? '').trim();
          if (text.isEmpty) continue;
          segments.add(
            ReasoningSegment(
              text: text,
              expanded: expandThinkingContent,
              loading: false,
              startAt: DateTime.tryParse(map['startAt']?.toString() ?? ''),
              finishedAt: DateTime.tryParse(
                map['finishedAt']?.toString() ?? '',
              ),
              toolStartIndex: (map['toolStartIndex'] as int?) ?? 0,
            ),
          );
        }
      } else if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final map = item.cast<String, dynamic>();
          final text = (map['text']?.toString() ?? '').trim();
          if (text.isEmpty) continue;
          segments.add(
            ReasoningSegment(
              text: text,
              expanded: expandThinkingContent,
              loading: false,
              startAt: DateTime.tryParse(map['startAt']?.toString() ?? ''),
              finishedAt: DateTime.tryParse(
                map['finishedAt']?.toString() ?? '',
              ),
              toolStartIndex: (map['toolStartIndex'] as int?) ?? 0,
            ),
          );
        }
      }
    } catch (_) {}
  }

  if (segments.isEmpty) {
    final thinkingData = _thinkingExportDataForMessage(message);
    if (thinkingData.thinkingTexts.isNotEmpty) {
      segments.addAll(
        thinkingData.thinkingTexts.map(
          (text) => ReasoningSegment(
            text: text,
            expanded: expandThinkingContent,
            loading: false,
            toolStartIndex: 0,
          ),
        ),
      );
    }
  }

  return _ExportReasoningPayload(
    segments: segments,
    contentSplitOffsets: offsets,
    reasoningCountAtSplit: reasoningCounts,
    toolCountAtSplit: toolCounts,
  );
}

Future<void> _saveExportTextWithPicker(
  BuildContext context, {
  required String filename,
  required String content,
  required List<String> allowedExtensions,
}) async {
  final l10n = AppLocalizations.of(context)!;

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.backupPageExportToFile,
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (savePath == null) return; // user cancelled

    try {
      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsString(content);
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
      return;
    }

    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
      type: NotificationType.success,
    );
    return;
  }

  // Mobile: use FilePicker with bytes parameter (required on Android & iOS).
  final contentBytes = utf8.encode(content);
  final String? savePath = await FilePicker.platform.saveFile(
    dialogTitle: l10n.backupPageExportToFile,
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    bytes: Uint8List.fromList(contentBytes),
  );
  if (savePath == null) return;
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
    type: NotificationType.success,
  );
}

Future<void> exportChatMessagesMarkdown(
  BuildContext context, {
  required Conversation conversation,
  required List<ChatMessage> messages,
  bool showThinkingAndToolCards = false,
  bool expandThinkingContent = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final settings = context.read<SettingsProvider>();
  final userProvider = context.read<UserProvider>();
  final assistant = context.read<AssistantProvider>().currentAssistant;
  final thinkingLabel = l10n.messageExportThinkingContentLabel;
  final timeFormatter = DateFormat(
    l10n.messageExportSheetDateTimeWithSecondsPattern,
  );
  try {
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExporting,
      type: NotificationType.info,
    );

    final title = (conversation.title.trim().isNotEmpty)
        ? conversation.title
        : l10n.messageExportSheetDefaultTitle;
    final includeThinking = showThinkingAndToolCards && expandThinkingContent;

    final buf = StringBuffer();
    buf.writeln('# $title');
    buf.writeln('');

    for (final msg in messages) {
      final time = timeFormatter.format(msg.timestamp);
      final roleName = _getRoleNameFromDependencies(
        l10n: l10n,
        settings: settings,
        userProvider: userProvider,
        assistant: assistant,
        msg: msg,
      );
      buf.writeln('> $time · $roleName');
      buf.writeln('');

      final exportData = (msg.role == 'assistant')
          ? _thinkingExportDataForMessage(msg)
          : null;
      final contentForExport = exportData?.cleanedContent ?? msg.content;

      final parsed = _parseContent(contentForExport);
      if (parsed.text.isNotEmpty) {
        buf.writeln(parsed.text);
        buf.writeln('');
      }

      for (final p in parsed.images) {
        final fixed = SandboxPathResolver.fix(p);
        try {
          final f = File(fixed);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            final b64 = base64Encode(bytes);
            final mime = _guessImageMime(fixed);
            buf.writeln('![](data:$mime;base64,$b64)');
          } else {
            buf.writeln('![image]($fixed)');
          }
        } catch (_) {
          buf.writeln('![image]($fixed)');
        }
        buf.writeln('');
      }

      for (final d in parsed.docs) {
        buf.writeln('- ${d.fileName}  `(${d.mime})`');
      }

      if (includeThinking &&
          exportData != null &&
          exportData.thinkingTexts.isNotEmpty) {
        final t = exportData.thinkingTexts.join('\n\n').trim();
        if (t.isNotEmpty) {
          buf.writeln('');
          buf.writeln('**$thinkingLabel**');
          buf.writeln('');
          buf.writeln('```text');
          buf.writeln(t);
          buf.writeln('```');
          buf.writeln('');
        }
      }

      buf.writeln('\n---\n');
    }

    final filename = 'chat-export-${DateTime.now().millisecondsSinceEpoch}.md';
    if (!context.mounted) return;
    await _saveExportTextWithPicker(
      context,
      filename: filename,
      content: buf.toString(),
      allowedExtensions: const ['md'],
    );
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExportFailed('$e'),
      type: NotificationType.error,
    );
  }
}

Future<void> exportChatMessagesTxt(
  BuildContext context, {
  required Conversation conversation,
  required List<ChatMessage> messages,
  bool showThinkingAndToolCards = false,
  bool expandThinkingContent = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final settings = context.read<SettingsProvider>();
  final userProvider = context.read<UserProvider>();
  final assistant = context.read<AssistantProvider>().currentAssistant;
  final thinkingLabel = l10n.messageExportThinkingContentLabel;
  final timeFormatter = DateFormat(
    l10n.messageExportSheetDateTimeWithSecondsPattern,
  );
  try {
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExporting,
      type: NotificationType.info,
    );

    final title = (conversation.title.trim().isNotEmpty)
        ? conversation.title
        : l10n.messageExportSheetDefaultTitle;
    final includeThinking = showThinkingAndToolCards && expandThinkingContent;

    final buf = StringBuffer();
    buf.writeln(title);
    buf.writeln('');

    for (final msg in messages) {
      final time = timeFormatter.format(msg.timestamp);
      final roleName = _getRoleNameFromDependencies(
        l10n: l10n,
        settings: settings,
        userProvider: userProvider,
        assistant: assistant,
        msg: msg,
      );
      buf.writeln('$time · $roleName');
      buf.writeln('');

      final exportData = (msg.role == 'assistant')
          ? _thinkingExportDataForMessage(msg)
          : null;
      final contentForExport = exportData?.cleanedContent ?? msg.content;

      final parsed = _parseContent(contentForExport);
      if (parsed.text.isNotEmpty) {
        buf.writeln(parsed.text);
        buf.writeln('');
      }

      for (final d in parsed.docs) {
        buf.writeln('- ${d.fileName} (${d.mime})');
      }

      if (includeThinking &&
          exportData != null &&
          exportData.thinkingTexts.isNotEmpty) {
        final t = exportData.thinkingTexts.join('\n\n').trim();
        if (t.isNotEmpty) {
          buf.writeln('');
          buf.writeln('[$thinkingLabel]');
          buf.writeln(t);
          buf.writeln('');
        }
      }

      buf.writeln('\n---\n');
    }

    final filename = 'chat-export-${DateTime.now().millisecondsSinceEpoch}.txt';
    await _saveExportTextWithPicker(
      context,
      filename: filename,
      content: buf.toString(),
      allowedExtensions: const ['txt'],
    );
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExportFailed('$e'),
      type: NotificationType.error,
    );
  }
}

Future<void> exportChatMessagesImage(
  BuildContext context, {
  required Conversation conversation,
  required List<ChatMessage> messages,
  bool showThinkingAndToolCards = false,
  bool expandThinkingContent = false,
}) async {
  try {
    File? file;
    await _runWithExportingOverlay(context, () async {
      file = await _renderAndSaveChatImage(
        context,
        conversation,
        messages,
        showThinkingAndToolCards: showThinkingAndToolCards,
        expandThinkingContent: expandThinkingContent,
      );
    });
    if (file == null) throw 'render error';
    if (!context.mounted) return;
    await showImagePreviewSheet(context, file: file!);
  } catch (e) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExportFailed('$e'),
      type: NotificationType.error,
    );
  }
}

Future<File?> _renderAndSaveMessageImage(
  BuildContext context,
  ChatMessage message, {
  bool showThinkingAndToolCards = false,
  bool expandThinkingContent = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final settings = context.read<SettingsProvider>();
  final l10n = AppLocalizations.of(context)!;
  final chatService = context.read<ChatService>();
  final title =
      chatService.getConversation(message.conversationId)?.title ??
      l10n.messageExportSheetDefaultTitle;
  // Pre-render mermaid diagrams to images for export
  try {
    final codes = extractMermaidCodes(message.content);
    await preRenderMermaidCodesForExport(context, codes);
  } catch (_) {}

  // Desktop uses larger width and lower pixel ratio for better proportions
  final bool isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  final content = ExportCaptureScope(
    enabled: true,
    child: _ExportedMessageCard(
      message: message,
      title: title,
      cs: cs,
      chatFontScale: settings.chatFontScale,
      showThinkingAndToolCards: showThinkingAndToolCards,
      expandThinkingContent: expandThinkingContent,
      isDesktop: isDesktop,
    ),
  );
  if (!context.mounted) return null;
  return _renderWidgetDirectly(
    context,
    content,
    width: isDesktop ? 720 : 480,
    pixelRatio: isDesktop ? 2.0 : 3.0,
  );
}

Future<File?> _renderAndSaveChatImage(
  BuildContext context,
  Conversation conversation,
  List<ChatMessage> messages, {
  bool showThinkingAndToolCards = false,
  bool expandThinkingContent = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final settings = context.read<SettingsProvider>();
  final l10n = AppLocalizations.of(context)!;
  // Pre-render all mermaid diagrams found in selected messages
  try {
    final codes = messages
        .map((m) => extractMermaidCodes(m.content))
        .expand((e) => e)
        .toList();
    await preRenderMermaidCodesForExport(context, codes);
  } catch (_) {}

  // Desktop uses larger width and lower pixel ratio for better proportions
  final bool isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  final content = ExportCaptureScope(
    enabled: true,
    child: _ExportedChatImage(
      conversationTitle: (conversation.title.trim().isNotEmpty)
          ? conversation.title
          : l10n.messageExportSheetDefaultTitle,
      cs: cs,
      chatFontScale: settings.chatFontScale,
      messages: messages,
      timestamp: conversation.updatedAt,
      showThinkingAndToolCards: showThinkingAndToolCards,
      expandThinkingContent: expandThinkingContent,
      isDesktop: isDesktop,
    ),
  );
  if (!context.mounted) return null;
  return _renderWidgetDirectly(
    context,
    content,
    width: isDesktop ? 720 : 480,
    pixelRatio: isDesktop ? 2.0 : 3.0,
  );
}

// New direct rendering approach without pagination
Future<File?> _renderWidgetDirectly(
  BuildContext context,
  Widget content, {
  double width = 480, // 宽度*3
  double pixelRatio = 3.0,
}) async {
  final overlay = Overlay.of(context);

  final boundaryKey = GlobalKey();
  final completer = Completer<void>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      // Schedule the completion after multiple frames to ensure rendering
      int frameCount = 0;
      void scheduleCompletion() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          frameCount++;
          if (frameCount < 3) {
            // Wait for 3 frames to ensure complete rendering
            scheduleCompletion();
          } else if (!completer.isCompleted) {
            completer.complete();
          }
        });
      }

      scheduleCompletion();

      return Positioned(
        left: -10000, // Position far offscreen
        top: -10000,
        child: RepaintBoundary(
          key: boundaryKey,
          child: Container(
            width: width,
            color: Theme.of(ctx).colorScheme.surface,
            child: Material(type: MaterialType.transparency, child: content),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  try {
    // Wait for the widget to be ready
    await completer.future;
    // Additional delay to ensure everything is painted
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // Try to capture the image with retries
    ui.Image? image;
    for (int retry = 0; retry < 10; retry++) {
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
        break;
      } catch (e) {
        if (retry == 9) {
          debugPrint('Failed to capture image after 10 retries: $e');
          return null;
        }
        // Wait before retrying
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }

    if (image == null) return null;

    // Convert to PNG
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;

    // Save to file
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/chat-export-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data.buffer.asUint8List());

    return file;
  } finally {
    entry.remove();
  }
}

Future<void> showMessageExportSheet(
  BuildContext context,
  ChatMessage message,
) async {
  final cs = Theme.of(context).colorScheme;
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: show centered dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _ExportDialog(message: message, parentContext: context),
        ),
      );
      return;
    }
  } catch (_) {
    // Fallback to bottom sheet below
  }
  // Mobile: keep bottom sheet
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: _ExportSheet(message: message, parentContext: context),
      );
    },
  );
}

Future<void> showChatExportSheet(
  BuildContext context, {
  required Conversation conversation,
  required List<ChatMessage> selectedMessages,
}) async {
  final cs = Theme.of(context).colorScheme;
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: show centered dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _BatchExportDialog(
            conversation: conversation,
            messages: selectedMessages,
            parentContext: context,
          ),
        ),
      );
      return;
    }
  } catch (_) {
    // Fallback to bottom sheet below
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: _BatchExportSheet(
          conversation: conversation,
          messages: selectedMessages,
          parentContext: context,
        ),
      );
    },
  );
}

// Desktop dialog: single message export
class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.message, required this.parentContext});
  final ChatMessage message;
  final BuildContext parentContext;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  final bool _exporting = false;
  bool _showThinkingAndToolCards = false;
  bool _expandThinkingContent = false;

  Future<void> _onExportMarkdown() async {
    if (_exporting) return;
    try {
      final pctx = widget.parentContext;
      final msg = widget.message;
      final service = pctx.read<ChatService>();
      final convo = service.getConversation(msg.conversationId);
      final effectiveConvo =
          convo ?? Conversation(id: msg.conversationId, title: '');
      await Navigator.of(context).maybePop();
      if (!pctx.mounted) return;
      await exportChatMessagesMarkdown(
        pctx,
        conversation: effectiveConvo,
        messages: [msg],
        showThinkingAndToolCards: _showThinkingAndToolCards,
        expandThinkingContent: _expandThinkingContent,
      );
    } catch (e) {
      final pctx = widget.parentContext;
      if (!pctx.mounted) return;
      final l10n = AppLocalizations.of(pctx)!;
      showAppSnackBar(
        pctx,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _onExportTxt() async {
    if (_exporting) return;
    try {
      final pctx = widget.parentContext;
      final msg = widget.message;
      final service = pctx.read<ChatService>();
      final convo = service.getConversation(msg.conversationId);
      final effectiveConvo =
          convo ?? Conversation(id: msg.conversationId, title: '');
      await Navigator.of(context).maybePop();
      if (!pctx.mounted) return;
      await exportChatMessagesTxt(
        pctx,
        conversation: effectiveConvo,
        messages: [msg],
        showThinkingAndToolCards: _showThinkingAndToolCards,
        expandThinkingContent: _expandThinkingContent,
      );
    } catch (e) {
      final pctx = widget.parentContext;
      if (!pctx.mounted) return;
      final l10n = AppLocalizations.of(pctx)!;
      showAppSnackBar(
        pctx,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _onExportImage() async {
    if (_exporting) return;
    try {
      final pctx = widget.parentContext;
      await Navigator.of(context).maybePop();
      if (!pctx.mounted) return;
      File? file;
      await _runWithExportingOverlay(pctx, () async {
        file = await _renderAndSaveMessageImage(
          pctx,
          widget.message,
          showThinkingAndToolCards: _showThinkingAndToolCards,
          expandThinkingContent: _expandThinkingContent,
        );
      });
      if (file == null) throw 'render error';
      if (!pctx.mounted) return;
      await showImagePreviewSheet(pctx, file: file!);
      return;
    } catch (e) {
      final pctx = widget.parentContext;
      if (!pctx.mounted) return;
      final l10n = AppLocalizations.of(pctx)!;
      showAppSnackBar(
        pctx,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 420,
        maxWidth: 640,
        maxHeight: 640,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: cs.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.messageExportSheetFormatTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.mcpPageClose,
                      icon: Icon(
                        Lucide.X,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Scrollbar(
                    child: ListView(
                      children: [
                        _ExportOptionTile(
                          icon: Lucide.BookOpenText,
                          title: l10n.messageExportSheetMarkdown,
                          subtitle:
                              l10n.messageExportSheetSingleMarkdownSubtitle,
                          onTap: _exporting ? null : _onExportMarkdown,
                        ),
                        _ExportOptionTile(
                          icon: Lucide.FileText,
                          title: l10n.messageExportSheetPlainText,
                          subtitle: l10n.messageExportSheetSingleTxtSubtitle,
                          onTap: _exporting ? null : _onExportTxt,
                        ),
                        _ExportOptionTile(
                          icon: Lucide.Image,
                          title: l10n.messageExportSheetExportImage,
                          subtitle:
                              l10n.messageExportSheetSingleExportImageSubtitle,
                          onTap: _exporting ? null : _onExportImage,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              _buildSwitchRow(
                                context,
                                title: l10n
                                    .messageExportSheetShowThinkingAndToolCards,
                                value: _showThinkingAndToolCards,
                                onChanged: (v) {
                                  setState(() {
                                    _showThinkingAndToolCards = v;
                                    if (!v) _expandThinkingContent = false;
                                  });
                                },
                              ),
                              _buildSwitchRow(
                                context,
                                title:
                                    l10n.messageExportSheetShowThinkingContent,
                                value: _expandThinkingContent,
                                onChanged: _showThinkingAndToolCards
                                    ? (v) => setState(
                                        () => _expandThinkingContent = v,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          IosSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }
}

// Desktop dialog: batch export
class _BatchExportDialog extends StatefulWidget {
  const _BatchExportDialog({
    required this.conversation,
    required this.messages,
    required this.parentContext,
  });
  final Conversation conversation;
  final List<ChatMessage> messages;
  final BuildContext parentContext;

  @override
  State<_BatchExportDialog> createState() => _BatchExportDialogState();
}

class _BatchExportDialogState extends State<_BatchExportDialog> {
  final bool _exporting = false;
  bool _showThinkingAndToolCards = false;
  bool _expandThinkingContent = false;

  Future<void> _onExportMarkdown() async {
    if (_exporting) return;
    final pctx = widget.parentContext;
    await Navigator.of(context).maybePop();
    if (!pctx.mounted) return;
    await exportChatMessagesMarkdown(
      pctx,
      conversation: widget.conversation,
      messages: widget.messages,
      showThinkingAndToolCards: _showThinkingAndToolCards,
      expandThinkingContent: _expandThinkingContent,
    );
  }

  Future<void> _onExportTxt() async {
    if (_exporting) return;
    final pctx = widget.parentContext;
    await Navigator.of(context).maybePop();
    if (!pctx.mounted) return;
    await exportChatMessagesTxt(
      pctx,
      conversation: widget.conversation,
      messages: widget.messages,
      showThinkingAndToolCards: _showThinkingAndToolCards,
      expandThinkingContent: _expandThinkingContent,
    );
  }

  Future<void> _onExportImage() async {
    if (_exporting) return;
    try {
      final pctx = widget.parentContext;
      await Navigator.of(context).maybePop();
      if (!pctx.mounted) return;
      File? file;
      await _runWithExportingOverlay(pctx, () async {
        file = await _renderAndSaveChatImage(
          pctx,
          widget.conversation,
          widget.messages,
          showThinkingAndToolCards: _showThinkingAndToolCards,
          expandThinkingContent: _expandThinkingContent,
        );
      });
      if (file == null) throw 'render error';
      if (!pctx.mounted) return;
      await showImagePreviewSheet(pctx, file: file!);
      return;
    } catch (e) {
      final pctx = widget.parentContext;
      if (!pctx.mounted) return;
      final l10n = AppLocalizations.of(pctx)!;
      showAppSnackBar(
        pctx,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 480,
        maxWidth: 720,
        maxHeight: 460,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: cs.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.messageExportSheetFormatTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.mcpPageClose,
                      icon: Icon(
                        Lucide.X,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Scrollbar(
                    child: ListView(
                      children: [
                        _ExportOptionTile(
                          icon: Lucide.BookOpenText,
                          title: l10n.messageExportSheetMarkdown,
                          subtitle:
                              l10n.messageExportSheetBatchMarkdownSubtitle,
                          onTap: _exporting ? null : _onExportMarkdown,
                        ),
                        _ExportOptionTile(
                          icon: Lucide.FileText,
                          title: l10n.messageExportSheetPlainText,
                          subtitle: l10n.messageExportSheetBatchTxtSubtitle,
                          onTap: _exporting ? null : _onExportTxt,
                        ),
                        _ExportOptionTile(
                          icon: Lucide.Image,
                          title: l10n.messageExportSheetExportImage,
                          subtitle:
                              l10n.messageExportSheetBatchExportImageSubtitle,
                          onTap: _exporting ? null : _onExportImage,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              _buildSwitchRow(
                                context,
                                title: l10n
                                    .messageExportSheetShowThinkingAndToolCards,
                                value: _showThinkingAndToolCards,
                                onChanged: (v) {
                                  setState(() {
                                    _showThinkingAndToolCards = v;
                                    if (!v) _expandThinkingContent = false;
                                  });
                                },
                              ),
                              _buildSwitchRow(
                                context,
                                title:
                                    l10n.messageExportSheetShowThinkingContent,
                                value: _expandThinkingContent,
                                onChanged: _showThinkingAndToolCards
                                    ? (v) => setState(
                                        () => _expandThinkingContent = v,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          IosSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.message, required this.parentContext});
  final ChatMessage message;
  final BuildContext parentContext;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _BatchExportSheet extends StatefulWidget {
  const _BatchExportSheet({
    required this.conversation,
    required this.messages,
    required this.parentContext,
  });
  final Conversation conversation;
  final List<ChatMessage> messages;
  final BuildContext parentContext;

  @override
  State<_BatchExportSheet> createState() => _BatchExportSheetState();
}

class _BatchExportSheetState extends State<_BatchExportSheet> {
  final DraggableScrollableController _ctrl = DraggableScrollableController();
  bool _exporting = false;
  bool _showThinkingAndToolCards = false;
  bool _expandThinkingContent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onExportMarkdown() async {
    if (_exporting) return;

    // Dismiss dialog immediately
    if (mounted) Navigator.of(context).maybePop();

    await exportChatMessagesMarkdown(
      widget.parentContext,
      conversation: widget.conversation,
      messages: widget.messages,
      showThinkingAndToolCards: _showThinkingAndToolCards,
      expandThinkingContent: _expandThinkingContent,
    );
  }

  Future<void> _onExportTxt() async {
    if (_exporting) return;

    // Dismiss dialog immediately
    if (mounted) Navigator.of(context).maybePop();

    await exportChatMessagesTxt(
      widget.parentContext,
      conversation: widget.conversation,
      messages: widget.messages,
      showThinkingAndToolCards: _showThinkingAndToolCards,
      expandThinkingContent: _expandThinkingContent,
    );
  }

  Future<void> _onExportImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pctx = widget.parentContext;
      File? file;
      await _runWithExportingOverlay(pctx, () async {
        file = await _renderAndSaveChatImage(
          pctx,
          widget.conversation,
          widget.messages,
          showThinkingAndToolCards: _showThinkingAndToolCards,
          expandThinkingContent: _expandThinkingContent,
        );
      });
      if (file == null) throw 'render error';
      // After generation, close current sheet then open preview
      if (mounted) await Navigator.of(context).maybePop();
      if (!pctx.mounted) return;
      await showImagePreviewSheet(pctx, file: file!);
      return; // do not fall through to setState after pop
    } catch (e) {
      final pctx = widget.parentContext;
      if (!pctx.mounted) return;
      final l10n = AppLocalizations.of(pctx)!;
      showAppSnackBar(
        pctx,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      controller: _ctrl,
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.70,
      minChildSize: 0.3,
      builder: (c, sc) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                l10n.messageExportSheetFormatTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                controller: sc,
                children: [
                  _ExportOptionTile(
                    icon: Lucide.BookOpenText,
                    title: l10n.messageExportSheetMarkdown,
                    subtitle: l10n.messageExportSheetBatchMarkdownSubtitle,
                    onTap: _exporting
                        ? null
                        : () {
                            _onExportMarkdown();
                          },
                  ),
                  _ExportOptionTile(
                    icon: Lucide.FileText,
                    title: l10n.messageExportSheetPlainText,
                    subtitle: l10n.messageExportSheetBatchTxtSubtitle,
                    onTap: _exporting
                        ? null
                        : () {
                            _onExportTxt();
                          },
                  ),
                  _ExportOptionTile(
                    icon: Lucide.Image,
                    title: l10n.messageExportSheetExportImage,
                    subtitle: l10n.messageExportSheetBatchExportImageSubtitle,
                    onTap: _exporting
                        ? null
                        : () {
                            _onExportImage();
                          },
                  ),
                  const SizedBox(height: 8),
                  // Image export options
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          title:
                              l10n.messageExportSheetShowThinkingAndToolCards,
                          value: _showThinkingAndToolCards,
                          onChanged: (v) {
                            setState(() {
                              _showThinkingAndToolCards = v;
                              if (!v) {
                                _expandThinkingContent = false;
                              }
                            });
                          },
                        ),
                        _buildSwitchRow(
                          context,
                          title: l10n.messageExportSheetShowThinkingContent,
                          value: _expandThinkingContent,
                          onChanged: _showThinkingAndToolCards
                              ? (v) {
                                  setState(() {
                                    _expandThinkingContent = v;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          IosSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }
}

class _ExportSheetState extends State<_ExportSheet> {
  final DraggableScrollableController _ctrl = DraggableScrollableController();
  bool _exporting = false;
  bool _showThinkingAndToolCards = false;
  bool _expandThinkingContent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onExportMarkdown() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pctx = widget.parentContext;
      final msg = widget.message;
      final service = pctx.read<ChatService>();
      final convo = service.getConversation(msg.conversationId);
      final effectiveConvo =
          convo ?? Conversation(id: msg.conversationId, title: '');
      await exportChatMessagesMarkdown(
        pctx,
        conversation: effectiveConvo,
        messages: [msg],
        showThinkingAndToolCards: _showThinkingAndToolCards,
        expandThinkingContent: _expandThinkingContent,
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: l10n.messageExportSheetExportFailed('$e'),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _onExportTxt() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pctx = widget.parentContext;
      final msg = widget.message;
      final service = pctx.read<ChatService>();
      final convo = service.getConversation(msg.conversationId);
      final effectiveConvo =
          convo ?? Conversation(id: msg.conversationId, title: '');
      await exportChatMessagesTxt(
        pctx,
        conversation: effectiveConvo,
        messages: [msg],
        showThinkingAndToolCards: _showThinkingAndToolCards,
        expandThinkingContent: _expandThinkingContent,
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: l10n.messageExportSheetExportFailed('$e'),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _onExportImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pctx = widget.parentContext;
      File? file;
      await _runWithExportingOverlay(pctx, () async {
        file = await _renderAndSaveMessageImage(
          pctx,
          widget.message,
          showThinkingAndToolCards: _showThinkingAndToolCards,
          expandThinkingContent: _expandThinkingContent,
        );
      });
      if (file == null) throw 'render error';
      if (mounted) await Navigator.of(context).maybePop();
      if (!pctx.mounted) return;
      await showImagePreviewSheet(pctx, file: file!);
      return;
    } catch (e) {
      final pctx = widget.parentContext;
      if (!pctx.mounted) return;
      final l10n = AppLocalizations.of(pctx)!;
      showAppSnackBar(
        pctx,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      controller: _ctrl,
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.70,
      minChildSize: 0.3,
      builder: (c, sc) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                l10n.messageExportSheetFormatTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                controller: sc,
                children: [
                  _ExportOptionTile(
                    icon: Lucide.BookOpenText,
                    title: l10n.messageExportSheetMarkdown,
                    subtitle: l10n.messageExportSheetSingleMarkdownSubtitle,
                    onTap: _exporting
                        ? null
                        : () {
                            _onExportMarkdown();
                          },
                  ),
                  _ExportOptionTile(
                    icon: Lucide.FileText,
                    title: l10n.messageExportSheetPlainText,
                    subtitle: l10n.messageExportSheetSingleTxtSubtitle,
                    onTap: _exporting
                        ? null
                        : () {
                            _onExportTxt();
                          },
                  ),
                  _ExportOptionTile(
                    icon: Lucide.Image,
                    title: l10n.messageExportSheetExportImage,
                    subtitle: l10n.messageExportSheetSingleExportImageSubtitle,
                    onTap: _exporting
                        ? null
                        : () {
                            _onExportImage();
                          },
                  ),
                  const SizedBox(height: 8),
                  // Image export options
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          title:
                              l10n.messageExportSheetShowThinkingAndToolCards,
                          value: _showThinkingAndToolCards,
                          onChanged: (v) {
                            setState(() {
                              _showThinkingAndToolCards = v;
                              if (!v) {
                                _expandThinkingContent = false;
                              }
                            });
                          },
                        ),
                        _buildSwitchRow(
                          context,
                          title: l10n.messageExportSheetShowThinkingContent,
                          value: _expandThinkingContent,
                          onChanged: _showThinkingAndToolCards
                              ? (v) {
                                  setState(() {
                                    _expandThinkingContent = v;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          IosSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }

  // shared widgets and helpers moved to top-level
}

class _ExportedMessageCard extends StatelessWidget {
  const _ExportedMessageCard({
    required this.message,
    required this.title,
    required this.cs,
    required this.chatFontScale,
    this.showThinkingAndToolCards = false,
    this.expandThinkingContent = false,
    this.isDesktop = false,
  });
  final ChatMessage message;
  final String title;
  final ColorScheme cs;
  final double chatFontScale;
  final bool showThinkingAndToolCards;
  final bool expandThinkingContent;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == 'assistant';
    final headerFg = cs.onSurface;
    final time = DateFormat('yyyy-MM-dd HH:mm').format(message.timestamp);

    // Desktop uses smaller font sizes for better proportions
    final double titleFontSize = isDesktop ? 15.0 : 18.0;
    final double timeFontSize = isDesktop ? 10.0 : 12.0;
    // Desktop uses smaller margins and paddings
    final double containerMargin = isDesktop ? 12.0 : 16.0;
    final double containerPadding = isDesktop ? 12.0 : 16.0;

    final exportThinkingData = _thinkingExportDataForMessage(message);
    final messageForExport = (!showThinkingAndToolCards && isAssistant)
        ? message.copyWith(content: exportThinkingData.cleanedContent)
        : message;
    final exportReasoningPayload = showThinkingAndToolCards && isAssistant
        ? _exportReasoningPayloadForMessage(
            message,
            expandThinkingContent: expandThinkingContent,
          )
        : const _ExportReasoningPayload(segments: <ReasoningSegment>[]);
    final toolParts = showThinkingAndToolCards && isAssistant
        ? _exportToolPartsForMessage(context, message)
        : const <ToolUIPart>[];
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final useAssistAvatar =
        isAssistant && (assistant?.useAssistantAvatar == true);
    final useAssistName = isAssistant && (assistant?.useAssistantName == true);

    return MediaQuery(
      // Respect chat font scale for export rendering
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1) * chatFontScale,
        ),
      ),
      child: Container(
        margin: EdgeInsets.all(containerMargin),
        padding: EdgeInsets.all(containerPadding),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          // removed outer border per UX
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title (no icon, no bordered container)
            Text(
              title,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: headerFg.withValues(alpha: 0.95),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            // Timestamp under title, aligned with title
            Text(
              time,
              style: TextStyle(
                fontSize: timeFontSize,
                color: headerFg.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: isDesktop ? 10.0 : 12.0),
            ChatMessageWidget(
              message: messageForExport,
              modelIcon:
                  (!useAssistAvatar &&
                      message.role == 'assistant' &&
                      message.providerId != null &&
                      message.modelId != null)
                  ? CurrentModelIcon(
                      providerKey: message.providerId,
                      modelId: message.modelId,
                      size: 30,
                    )
                  : null,
              showModelIcon: !useAssistAvatar,
              useAssistantAvatar: useAssistAvatar,
              useAssistantName: useAssistName,
              assistantName: (useAssistAvatar || useAssistName)
                  ? (assistant?.name ?? 'Assistant')
                  : null,
              assistantAvatar: useAssistAvatar
                  ? (assistant?.avatar ?? '')
                  : null,
              showUserAvatar: context.read<SettingsProvider>().showUserAvatar,
              showTokenStats: false,
              reasoningSegments: exportReasoningPayload.segments.isEmpty
                  ? null
                  : exportReasoningPayload.segments,
              toolParts: toolParts.isEmpty ? null : toolParts,
              contentSplitOffsets: exportReasoningPayload.contentSplitOffsets,
              reasoningCountAtSplit:
                  exportReasoningPayload.reasoningCountAtSplit,
              toolCountAtSplit: exportReasoningPayload.toolCountAtSplit,
              hideStreamingIndicator: true,
            ),
            SizedBox(height: isDesktop ? 12.0 : 16.0),
            _ExportDisclaimer(isDesktop: isDesktop),
          ],
        ),
      ),
    );
  }
}

class _ExportedChatImage extends StatelessWidget {
  const _ExportedChatImage({
    required this.conversationTitle,
    required this.cs,
    required this.chatFontScale,
    required this.messages,
    required this.timestamp,
    this.showThinkingAndToolCards = false,
    this.expandThinkingContent = false,
    this.isDesktop = false,
  });
  final String conversationTitle;
  final ColorScheme cs;
  final double chatFontScale;
  final List<ChatMessage> messages;
  final DateTime timestamp;
  final bool showThinkingAndToolCards;
  final bool expandThinkingContent;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    // Desktop uses smaller font sizes for better proportions
    final double titleFontSize = isDesktop ? 15.0 : 18.0;
    final double timeFontSize = isDesktop ? 10.0 : 12.0;
    final double containerMargin = isDesktop ? 5.0 : 6.0;
    final double containerPadding = isDesktop ? 5.0 : 6.0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1) * chatFontScale,
        ),
      ),
      child: ClipRect(
        child: Container(
          margin: EdgeInsets.all(containerMargin),
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(isDesktop ? 12.0 : 16.0),
            // removed outer border per UX
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title (no icon, no bordered container)
              Text(
                conversationTitle,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.95),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              // Timestamp under title, aligned with title
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(timestamp),
                style: TextStyle(
                  fontSize: timeFontSize,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: isDesktop ? 10.0 : 12.0),
              for (final m in messages) ...[
                _ExportedBubble(
                  message: m,
                  cs: cs,
                  showThinkingAndToolCards: showThinkingAndToolCards,
                  expandThinkingContent: expandThinkingContent,
                  isDesktop: isDesktop,
                ),
                SizedBox(height: isDesktop ? 6.0 : 8.0),
              ],
              SizedBox(height: isDesktop ? 10.0 : 12.0),
              _ExportDisclaimer(isDesktop: isDesktop),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportedBubble extends StatelessWidget {
  const _ExportedBubble({
    required this.message,
    required this.cs,
    this.showThinkingAndToolCards = false,
    this.expandThinkingContent = false,
    this.isDesktop = false,
  });
  final ChatMessage message;
  final ColorScheme cs;
  final bool showThinkingAndToolCards;
  final bool expandThinkingContent;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == 'assistant';
    final bubbleBg = cs.primary.withValues(alpha: 0.08);
    final bubbleFg = cs.onSurface;

    // Desktop uses smaller font sizes for better proportions
    final double contentFontSize = isDesktop ? 13.0 : 15.7;

    final exportThinkingData = _thinkingExportDataForMessage(message);
    final messageForExport = (!showThinkingAndToolCards && isAssistant)
        ? message.copyWith(content: exportThinkingData.cleanedContent)
        : message;
    final exportReasoningPayload = showThinkingAndToolCards && isAssistant
        ? _exportReasoningPayloadForMessage(
            message,
            expandThinkingContent: expandThinkingContent,
          )
        : const _ExportReasoningPayload(segments: <ReasoningSegment>[]);
    final toolParts = showThinkingAndToolCards && isAssistant
        ? _exportToolPartsForMessage(context, message)
        : const <ToolUIPart>[];
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final useAssistAvatar =
        isAssistant && (assistant?.useAssistantAvatar == true);
    final useAssistName = isAssistant && (assistant?.useAssistantName == true);

    final parsed = _parseContent(messageForExport.content);
    final mdText = StringBuffer();
    if (parsed.text.isNotEmpty) mdText.writeln(_softBreakMd(parsed.text));
    for (final p in parsed.images) {
      mdText.writeln('\n![](${SandboxPathResolver.fix(p)})\n');
    }
    for (final d in parsed.docs) {
      mdText.writeln('\n- ${d.fileName}  `(${d.mime})`');
    }
    final Widget contentWidget = (mdText.toString().trim().isNotEmpty)
        ? DefaultTextStyle.merge(
            style: TextStyle(fontSize: contentFontSize, height: 1.5),
            child: MarkdownWithCodeHighlight(text: mdText.toString()),
          )
        : Text('—', style: TextStyle(color: bubbleFg.withValues(alpha: 0.5)));

    if (isAssistant) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 760.0 : 860.0),
          child: ChatMessageWidget(
            message: messageForExport,
            modelIcon:
                (!useAssistAvatar &&
                    message.role == 'assistant' &&
                    message.providerId != null &&
                    message.modelId != null)
                ? CurrentModelIcon(
                    providerKey: message.providerId,
                    modelId: message.modelId,
                    size: 30,
                  )
                : null,
            showModelIcon: !useAssistAvatar,
            useAssistantAvatar: useAssistAvatar,
            useAssistantName: useAssistName,
            assistantName: (useAssistAvatar || useAssistName)
                ? (assistant?.name ?? 'Assistant')
                : null,
            assistantAvatar: useAssistAvatar ? (assistant?.avatar ?? '') : null,
            showUserAvatar: context.read<SettingsProvider>().showUserAvatar,
            showTokenStats: false,
            reasoningSegments: exportReasoningPayload.segments.isEmpty
                ? null
                : exportReasoningPayload.segments,
            toolParts: toolParts.isEmpty ? null : toolParts,
            contentSplitOffsets: exportReasoningPayload.contentSplitOffsets,
            reasoningCountAtSplit: exportReasoningPayload.reasoningCountAtSplit,
            toolCountAtSplit: exportReasoningPayload.toolCountAtSplit,
            hideStreamingIndicator: true,
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 600.0 : 680.0),
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 10.0 : 12.0),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(isDesktop ? 12.0 : 16.0),
          ),
          child: contentWidget,
        ),
      ),
    );
  }
}

class _ExportDisclaimer extends StatelessWidget {
  const _ExportDisclaimer({this.isDesktop = false});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = AppLocalizations.of(context)!.exportDisclaimerAiGenerated;
    final double fontSize = isDesktop ? 10.0 : 12.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          top: isDesktop ? 3.0 : 4.0,
          bottom: isDesktop ? 4.0 : 6.0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Future<void> _runWithExportingOverlay(
  BuildContext context,
  Future<void> Function() task,
) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context, rootNavigator: true);
  // Show overlay first
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: Material(
        color: cs.surface,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 16),
              const SizedBox(height: 12),
              Text(
                l10n.messageExportSheetExporting,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    await task();
  } finally {
    if (navigator.mounted) {
      await navigator.maybePop();
    }
  }
}

class _Parsed {
  final String text;
  final List<String> images;
  final List<_DocRef> docs;
  _Parsed(this.text, this.images, this.docs);
}

class _DocRef {
  final String path;
  final String fileName;
  final String mime;
  _DocRef({required this.path, required this.fileName, required this.mime});
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color base = isDark
        ? cs.primary.withValues(alpha: 0.10)
        : cs.primary.withValues(alpha: 0.06);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: IosCardPress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        baseColor: base,
        pressedBlendStrength: isDark ? 0.14 : 0.12,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
