import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../../utils/brand_assets.dart';
import '../../../utils/avatar_cache.dart';
import 'chat_message_widget.dart' show ToolUIPart;

// Regular expression to extract thinking content from message
final RegExp thinkingRegex = RegExp(r"<think>([\s\S]*?)(?:</think>|$)", dotAll: true);

// Shared helpers
String _guessImageMime(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/png';
}

String? _modelDisplayName(BuildContext context, ChatMessage msg) {
  if (msg.role != 'assistant') return null;
  final modelId = msg.modelId;
  if (modelId == null || modelId.isEmpty) return null;
  final settings = context.read<SettingsProvider>();
  String? name;
  final providerId = msg.providerId;
  if (providerId != null && providerId.isNotEmpty) {
    try {
      final cfg = settings.getProviderConfig(providerId);
      final ov = cfg.modelOverrides[modelId] as Map?;
      final overrideName = (ov?['name'] as String?)?.trim();
      if (overrideName != null && overrideName.isNotEmpty) {
        name = overrideName;
      }
    } catch (_) {
      // ignore lookup issues; fall back to inference below.
    }
  }

  final inferred = ModelRegistry.infer(ModelInfo(id: modelId, displayName: modelId));
  final fallback = inferred.displayName.trim();
  return name ?? (fallback.isNotEmpty ? fallback : modelId);
}


String _getRoleName(BuildContext context, ChatMessage msg) {
  final l10n = AppLocalizations.of(context)!;
  if (msg.role == 'user') {
    final userProvider = context.read<UserProvider>();
    return userProvider.name;
  } else if (msg.role == 'assistant') {
    // Check if using assistant  
    final assistant = context.read<AssistantProvider>().currentAssistant;
    if (assistant != null && assistant.useAssistantAvatar == true && assistant.name.trim().isNotEmpty) {
      return assistant.name.trim();
    }
    // Otherwise use model display name
    final modelName = _modelDisplayName(context, msg);
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
    if (raw.codeUnitAt(idx) == 0x5B /* '[' */) {
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
      final mFile = RegExp(r"^\[file:([^|\]]+)\|([^|\]]+)\|([^\]]+)\]").firstMatch(sub);
      if (mFile != null) {
        final path = (mFile.groupCount >= 1 ? mFile.group(1) : null)?.trim() ?? '';
        final name = (mFile.groupCount >= 2 ? mFile.group(2) : null)?.trim() ?? 'file';
        final mime = (mFile.groupCount >= 3 ? mFile.group(3) : null)?.trim() ?? 'text/plain';
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

Future<File?> _renderAndSaveMessageImage(
  BuildContext context,
  ChatMessage message, {
  bool showThinkingAndToolCards = false,
  bool expandThinkingContent = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final settings = context.read<SettingsProvider>();
  final l10n = AppLocalizations.of(context)!;
  // Pre-render mermaid diagrams to images for export
  try {
    final codes = extractMermaidCodes(message.content);
    await preRenderMermaidCodesForExport(context, codes);
  } catch (_) {}

  final content = ExportCaptureScope(
    enabled: true,
    child: _ExportedMessageCard(
    message: message,
    title: context.read<ChatService>().getConversation(message.conversationId)?.title ?? l10n.messageExportSheetDefaultTitle,
    cs: cs,
    chatFontScale: settings.chatFontScale,
    showThinkingAndToolCards: showThinkingAndToolCards,
    expandThinkingContent: expandThinkingContent,
    ),
  );
  return _renderWidgetDirectly(context, content);
}

Rect _shareAnchorRect(BuildContext context) {
  try {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
      final offset = box.localToGlobal(Offset.zero);
      return offset & box.size;
    }
  } catch (_) {}
  final size = MediaQuery.of(context).size;
  final center = Offset(size.width / 2, size.height / 2);
  return Rect.fromCenter(center: center, width: 1, height: 1);
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

  final content = ExportCaptureScope(
    enabled: true,
    child: _ExportedChatImage(
    conversationTitle: (conversation.title.trim().isNotEmpty) ? conversation.title : l10n.messageExportSheetDefaultTitle,
    cs: cs,
    chatFontScale: settings.chatFontScale,
    messages: messages,
    timestamp: conversation.updatedAt,
    showThinkingAndToolCards: showThinkingAndToolCards,
    expandThinkingContent: expandThinkingContent,
    ),
  );
  return _renderWidgetDirectly(context, content);
}

// New direct rendering approach without pagination
Future<File?> _renderWidgetDirectly(
  BuildContext context,
  Widget content, {
  double width = 480, // 宽度*3
  double pixelRatio = 3.0,
}) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return null;
  
  final boundaryKey = GlobalKey();
  final completer = Completer<void>();
  
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) {
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
          color: Theme.of(ctx).colorScheme.background,
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        ),
      ),
    );
  });
  
  overlay.insert(entry);
  
  try {
    // Wait for the widget to be ready
    await completer.future;
    // Additional delay to ensure everything is painted
    await Future<void>.delayed(const Duration(milliseconds: 500));
    
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // Try to capture the image with retries
    ui.Image? image;
    for (int retry = 0; retry < 10; retry++) {
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
        break;
      } catch (e) {
        if (retry == 9) {
          print('Failed to capture image after 10 retries: $e');
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
    final file = File('${dir.path}/chat-export-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    
    return file;
  } finally {
    entry.remove();
  }
}

// Keep the old paginated version for reference but renamed
Future<File?> _renderAndSavePagedOld(
  BuildContext context,
  Widget content, {
  double width = 480, // 宽度*3
  double pageHeight = 1600,
  double pixelRatio = 3.0,
}) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return null;
  final boundaryKey = GlobalKey();
  final contentKey = GlobalKey();
  final controller = ScrollController();
  
  // Create a completer to signal when the widget is ready
  final completer = Completer<void>();
  
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) {
    // Schedule a callback after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    
    return Material(
      type: MaterialType.transparency,
      child: IgnorePointer(
        ignoring: true,
        child: Opacity(
          opacity: 0.001,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: width,
                height: pageHeight,
                child: SingleChildScrollView(
                  controller: controller,
                  child: KeyedSubtree(key: contentKey, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });
  
  overlay.insert(entry);
  
  try {
    // Wait for the initial frame to be ready
    await completer.future;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    
    final contentSize = contentKey.currentContext?.size;
    if (contentSize == null) return null;
    
    final totalHeight = contentSize.height;
    final pages = (totalHeight / pageHeight).ceil().clamp(1, 200);
    final images = <ui.Image>[];
    final drawHeights = <int>[];
    
    for (int i = 0; i < pages; i++) {
      final offset = i * pageHeight;
      controller.jumpTo(offset);
      
      // Wait for the scroll to complete and the new content to render
      await Future<void>.delayed(const Duration(milliseconds: 200));
      
      // Force a frame
      SchedulerBinding.instance.scheduleFrameCallback((_) {});
      await SchedulerBinding.instance.endOfFrame;
      
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) break;
      
      // Capture with retry logic
      ui.Image? img;
      for (int retry = 0; retry < 5; retry++) {
        try {
          img = await boundary.toImage(pixelRatio: pixelRatio);
          break;
        } catch (e) {
          // Wait and retry
          await Future<void>.delayed(const Duration(milliseconds: 100));
          SchedulerBinding.instance.scheduleFrameCallback((_) {});
          await SchedulerBinding.instance.endOfFrame;
        }
      }
      
      if (img == null) continue;
      
      images.add(img);
      final drawn = drawHeights.fold<int>(0, (a, b) => a + b);
      final remaining = (totalHeight * pixelRatio).round() - drawn;
      final h = remaining <= 0 ? 0 : math.min(img.height, remaining);
      drawHeights.add(h);
    }
    
    if (images.isEmpty) return null;
    
    final composedHeightPx = drawHeights.fold<int>(0, (a, b) => a + b);
    final widthPx = (width * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    double y = 0;
    
    for (int i = 0; i < images.length; i++) {
      final ui.Image page = images[i];
      final int drawH = drawHeights[i];
      if (drawH <= 0) break;
      final src = Rect.fromLTWH(0, 0, page.width.toDouble(), drawH.toDouble());
      final dst = Rect.fromLTWH(0, y, widthPx.toDouble(), drawH.toDouble());
      canvas.drawImageRect(page, src, dst, Paint());
      y += drawH.toDouble();
    }
    
    final pic = recorder.endRecording();
    final img = await pic.toImage(widthPx, composedHeightPx);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/chat-export-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  } finally {
    entry.remove();
  }
}


Future<void> showMessageExportSheet(BuildContext context, ChatMessage message) async {
  final cs = Theme.of(context).colorScheme;
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
        child: _BatchExportSheet(conversation: conversation, messages: selectedMessages, parentContext: context),
      );
    },
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.message, required this.parentContext});
  final ChatMessage message;
  final BuildContext parentContext;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _BatchExportSheet extends StatefulWidget {
  const _BatchExportSheet({required this.conversation, required this.messages, required this.parentContext});
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

  String _formatTime(BuildContext context, DateTime time) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = DateFormat(l10n.messageExportSheetDateTimeWithSecondsPattern);
    return fmt.format(time);
  }

  Future<void> _onExportMarkdown() async {
    if (_exporting) return;
    
    // Dismiss dialog immediately
    if (mounted) Navigator.of(context).maybePop();
    
    setState(() => _exporting = true);
    try {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: l10n.messageExportSheetExporting,
          type: NotificationType.info,
        );
      }
      final ctx = context;
      final conv = widget.conversation;
      final l10n = AppLocalizations.of(ctx)!;
      final title = (conv.title.trim().isNotEmpty) ? conv.title : l10n.messageExportSheetDefaultTitle;
      final buf = StringBuffer();
      buf.writeln('# $title');
      buf.writeln('');
      for (final msg in widget.messages) {
        final time = _formatTime(ctx, msg.timestamp);
        buf.writeln('> $time · ${_getRoleName(ctx, msg)}');
        buf.writeln('');
        final parsed = _parseContent(msg.content);
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
        buf.writeln('\n---\n');
      }

      final tmp = await getTemporaryDirectory();
      final filename = 'chat-export-${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${tmp.path}/$filename');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/markdown', name: filename)],
        text: title,
        sharePositionOrigin: _shareAnchorRect(context),
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
      File? file;
      await _runWithExportingOverlay(widget.parentContext, () async {
        file = await _renderAndSaveChatImage(
          widget.parentContext,
          widget.conversation,
          widget.messages,
          showThinkingAndToolCards: _showThinkingAndToolCards,
          expandThinkingContent: _expandThinkingContent,
        );
      });
      if (file == null) throw 'render error';
      // After generation, close current sheet then open preview
      if (mounted) await Navigator.of(context).maybePop();
      await showImagePreviewSheet(widget.parentContext, file: file!);
      return; // do not fall through to setState after pop
    } catch (e) {
      final l10n = AppLocalizations.of(widget.parentContext)!;
      showAppSnackBar(
        widget.parentContext,
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
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 10),
            Center(child: Text(l10n.messageExportSheetFormatTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                controller: sc,
                children: [
                  _ExportOptionTile(
                    icon: Lucide.BookOpenText,
                    title: l10n.messageExportSheetMarkdown,
                    subtitle: l10n.messageExportSheetBatchMarkdownSubtitle,
                    onTap: _exporting ? null : () {
                      _onExportMarkdown();
                    },
                  ),
                  _ExportOptionTile(
                    icon: Lucide.Image,
                    title: l10n.messageExportSheetExportImage,
                    subtitle: l10n.messageExportSheetBatchExportImageSubtitle,
                    onTap: _exporting ? null : () {
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
                          title: l10n.messageExportSheetShowThinkingAndToolCards,
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
                          onChanged: _showThinkingAndToolCards ? (v) {
                            setState(() {
                              _expandThinkingContent = v;
                            });
                          } : null,
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

  Widget _buildSwitchRow(BuildContext context, {
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
                color: isEnabled ? cs.onSurface : cs.onSurface.withOpacity(0.4),
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

  String _formatTime(BuildContext context, DateTime time) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = DateFormat(l10n.messageExportSheetDateTimeWithSecondsPattern);
    return fmt.format(time);
  }

  Future<void> _onExportMarkdown() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final ctx = context;
      final msg = widget.message;
      final service = ctx.read<ChatService>();
      final convo = service.getConversation(msg.conversationId);
      final l10n = AppLocalizations.of(ctx)!;
      final title = ((convo?.title ?? '').trim().isNotEmpty) ? (convo?.title ?? '') : l10n.messageExportSheetDefaultTitle;
      final time = _formatTime(ctx, msg.timestamp);

      final parsed = _parseContent(msg.content);

      final buf = StringBuffer();
      buf.writeln('# $title');
      buf.writeln('');
      buf.writeln('> $time · ${_getRoleName(ctx, msg)}');
      buf.writeln('');
      if (parsed.text.isNotEmpty) {
        buf.writeln(parsed.text);
        buf.writeln('');
      }
      // Inline images as data URLs where possible
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
      // List file attachments as links (path only)
      for (final d in parsed.docs) {
        buf.writeln('- ${d.fileName}  `(${d.mime})`');
      }

      final tmp = await getTemporaryDirectory();
      final filename = 'chat-export-${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${tmp.path}/$filename');
      await file.writeAsString(buf.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/markdown', name: filename)],
        text: title,
        sharePositionOrigin: _shareAnchorRect(context),
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: l10n.messageExportSheetExportedAs(filename),
          type: NotificationType.success,
        );
      }
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
      File? file;
      await _runWithExportingOverlay(widget.parentContext, () async {
        file = await _renderAndSaveMessageImage(
          widget.parentContext,
          widget.message,
          showThinkingAndToolCards: _showThinkingAndToolCards,
          expandThinkingContent: _expandThinkingContent,
        );
      });
      if (file == null) throw 'render error';
      if (mounted) await Navigator.of(context).maybePop();
      await showImagePreviewSheet(widget.parentContext, file: file!);
      return;
    } catch (e) {
      final l10n = AppLocalizations.of(widget.parentContext)!;
      showAppSnackBar(
        widget.parentContext,
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
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 10),
            Center(child: Text(l10n.messageExportSheetFormatTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                controller: sc,
                children: [
                  _ExportOptionTile(
                    icon: Lucide.BookOpenText,
                    title: l10n.messageExportSheetMarkdown,
                    subtitle: l10n.messageExportSheetSingleMarkdownSubtitle,
                    onTap: _exporting ? null : () {
                      _onExportMarkdown();
                    },
                  ),
                  _ExportOptionTile(
                    icon: Lucide.Image,
                    title: l10n.messageExportSheetExportImage,
                    subtitle: l10n.messageExportSheetSingleExportImageSubtitle,
                    onTap: _exporting ? null : () {
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
                          title: l10n.messageExportSheetShowThinkingAndToolCards,
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
                          onChanged: _showThinkingAndToolCards ? (v) {
                            setState(() {
                              _expandThinkingContent = v;
                            });
                          } : null,
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

  Widget _buildSwitchRow(BuildContext context, {
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
                color: isEnabled ? cs.onSurface : cs.onSurface.withOpacity(0.4),
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
  });
  final ChatMessage message;
  final String title;
  final ColorScheme cs;
  final double chatFontScale;
  final bool showThinkingAndToolCards;
  final bool expandThinkingContent;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == 'assistant';
    final headerFg = cs.onSurface;
    final headerBg = cs.surface;
    final bubbleBg = cs.primary.withOpacity(0.08);
    final bubbleFg = cs.onSurface;
    final time = DateFormat('yyyy-MM-dd HH:mm').format(message.timestamp);

    // Extract thinking content and tool parts if enabled
    List<Map<String, dynamic>> reasoningSegments = [];
    String messageContent = message.content;
    List<ToolUIPart> toolParts = [];

    if (showThinkingAndToolCards && isAssistant) {
      // Get tool events first
      try {
        final chatService = context.read<ChatService>();
        final events = chatService.getToolEvents(message.id);
        if (events.isNotEmpty) {
          toolParts = events
              .map((e) => ToolUIPart(
                    id: (e['id'] ?? '').toString(),
                    toolName: (e['name'] ?? '').toString(),
                    arguments: (e['arguments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
                    content: (e['content']?.toString().isNotEmpty == true) ? e['content'].toString() : null,
                    loading: !(e['content']?.toString().isNotEmpty == true),
                  ))
              .toList();
        }
      } catch (_) {}

      // Check if message has reasoningSegmentsJson (multiple thinking segments with toolStartIndex)
      if (message.reasoningSegmentsJson != null && message.reasoningSegmentsJson!.isNotEmpty) {
        try {
          final segments = _deserializeReasoningSegments(message.reasoningSegmentsJson!);
          reasoningSegments = segments;
        } catch (_) {}
      }

      // If no segments, fall back to extracting from content or reasoningText
      if (reasoningSegments.isEmpty) {
        // Extract thinking content from <think> tags
        final thinkingMatches = thinkingRegex.allMatches(message.content);
        if (thinkingMatches.isNotEmpty) {
          final texts = thinkingMatches
              .map((m) => (m.group(1) ?? '').trim())
              .where((s) => s.isNotEmpty)
              .toList();
          // Create segments with sequential toolStartIndex
          for (int i = 0; i < texts.length; i++) {
            reasoningSegments.add({
              'text': texts[i],
              'toolStartIndex': 0, // All tools at the end for inline think
            });
          }
          // Remove thinking tags from message content
          messageContent = message.content.replaceAll(thinkingRegex, '').trim();
        }
        // Also check reasoningText field
        else if (message.reasoningText != null && message.reasoningText!.isNotEmpty) {
          reasoningSegments.add({
            'text': message.reasoningText!,
            'toolStartIndex': 0,
          });
        }
      }
    }

    final parsed = _parseContent(messageContent);
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
            style: const TextStyle(fontSize: 15.7, height: 1.5),
            child: MarkdownWithCodeHighlight(text: mdText.toString()),
          )
        : Text('—', style: TextStyle(color: bubbleFg.withOpacity(0.5)));

    return MediaQuery(
      // Respect chat font scale for export rendering
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: MediaQuery.of(context).textScaleFactor * chatFontScale,
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.background,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: headerFg.withOpacity(0.95)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            // Timestamp under title, aligned with title
            Text(time, style: TextStyle(fontSize: 12, color: headerFg.withOpacity(0.6))),
            const SizedBox(height: 12),
            // Message body styled like chat
            if (isAssistant) ...[
              _AssistantHeader(message: message),
              const SizedBox(height: 8),
              // Build mixed content: reasoning segments and tool cards按 toolStartIndex 混合显示
              ...() {
                final List<Widget> mixedContent = [];
                if (reasoningSegments.isNotEmpty) {
                  for (int i = 0; i < reasoningSegments.length; i++) {
                    final seg = reasoningSegments[i];
                    final text = seg['text'] as String? ?? '';

                    // Add the reasoning segment (if any text)
                    if (text.isNotEmpty) {
                      mixedContent.add(_ExportThinkingCard(
                        thinkingText: text,
                        cs: cs,
                        expanded: expandThinkingContent,
                      ));
                      mixedContent.add(const SizedBox(height: 8));
                    }

                    // Determine tool range mapped to this segment: [start, end)
                    int start = (seg['toolStartIndex'] as int?) ?? 0;
                    final int end = (i < reasoningSegments.length - 1)
                        ? (reasoningSegments[i + 1]['toolStartIndex'] as int?) ?? toolParts.length
                        : toolParts.length;

                    // Clamp to bounds and ensure non-decreasing
                    if (start < 0) start = 0;
                    if (start > toolParts.length) start = toolParts.length;
                    final int clampedEnd = end.clamp(start, toolParts.length);

                    for (int k = start; k < clampedEnd; k++) {
                      // Hide builtin_search tool cards
                      if (toolParts[k].toolName == 'builtin_search') continue;
                      mixedContent.add(_ExportToolCard(part: toolParts[k], cs: cs));
                      mixedContent.add(const SizedBox(height: 8));
                    }
                  }
                } else if (toolParts.isNotEmpty) {
                  // No reasoning segments but have tool cards - show all tool cards
                  for (final toolPart in toolParts) {
                    if (toolPart.toolName == 'builtin_search') continue;
                    mixedContent.add(_ExportToolCard(part: toolPart, cs: cs));
                    mixedContent.add(const SizedBox(height: 8));
                  }
                }
                return mixedContent;
              }(),
              contentWidget,
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: contentWidget,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _ExportDisclaimer(),
          ],
        ),
      ),
    );
  }

  // Helper to deserialize reasoning segments
  List<Map<String, dynamic>> _deserializeReasoningSegments(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
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
  });
  final String conversationTitle;
  final ColorScheme cs;
  final double chatFontScale;
  final List<ChatMessage> messages;
  final DateTime timestamp;
  final bool showThinkingAndToolCards;
  final bool expandThinkingContent;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: MediaQuery.of(context).textScaleFactor * chatFontScale,
      ),
      child: ClipRect(
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.background,
            borderRadius: BorderRadius.circular(16),
            // removed outer border per UX
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
            // Title (no icon, no bordered container)
            Text(
              conversationTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface.withOpacity(0.95)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            // Timestamp under title, aligned with title
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(timestamp),
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 12),
            for (final m in messages) ...[
              _ExportedBubble(
                message: m,
                cs: cs,
                showThinkingAndToolCards: showThinkingAndToolCards,
                expandThinkingContent: expandThinkingContent,
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            _ExportDisclaimer(),
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
  });
  final ChatMessage message;
  final ColorScheme cs;
  final bool showThinkingAndToolCards;
  final bool expandThinkingContent;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == 'assistant';
    final bubbleBg = cs.primary.withOpacity(0.08);
    final bubbleFg = cs.onSurface;

    // Extract thinking content and tool parts if enabled
    List<Map<String, dynamic>> reasoningSegments = [];
    String messageContent = message.content;
    List<ToolUIPart> toolParts = [];

    if (showThinkingAndToolCards && isAssistant) {
      // Get tool events first
      try {
        final chatService = context.read<ChatService>();
        final events = chatService.getToolEvents(message.id);
        if (events.isNotEmpty) {
          toolParts = events
              .map((e) => ToolUIPart(
                    id: (e['id'] ?? '').toString(),
                    toolName: (e['name'] ?? '').toString(),
                    arguments: (e['arguments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
                    content: (e['content']?.toString().isNotEmpty == true) ? e['content'].toString() : null,
                    loading: !(e['content']?.toString().isNotEmpty == true),
                  ))
              .toList();
        }
      } catch (_) {}

      // Check if message has reasoningSegmentsJson (multiple thinking segments with toolStartIndex)
      if (message.reasoningSegmentsJson != null && message.reasoningSegmentsJson!.isNotEmpty) {
        try {
          final segments = _deserializeReasoningSegments(message.reasoningSegmentsJson!);
          reasoningSegments = segments;
        } catch (_) {}
      }

      // If no segments, fall back to extracting from content or reasoningText
      if (reasoningSegments.isEmpty) {
        // Extract thinking content from <think> tags
        final thinkingMatches = thinkingRegex.allMatches(message.content);
        if (thinkingMatches.isNotEmpty) {
          final texts = thinkingMatches
              .map((m) => (m.group(1) ?? '').trim())
              .where((s) => s.isNotEmpty)
              .toList();
          // Create segments with sequential toolStartIndex
          for (int i = 0; i < texts.length; i++) {
            reasoningSegments.add({
              'text': texts[i],
              'toolStartIndex': 0, // All tools at the end for inline think
            });
          }
          // Remove thinking tags from message content
          messageContent = message.content.replaceAll(thinkingRegex, '').trim();
        }
        // Also check reasoningText field
        else if (message.reasoningText != null && message.reasoningText!.isNotEmpty) {
          reasoningSegments.add({
            'text': message.reasoningText!,
            'toolStartIndex': 0,
          });
        }
      }
    }

    final parsed = _parseContent(messageContent);
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
            style: const TextStyle(fontSize: 15.7, height: 1.5),
            child: MarkdownWithCodeHighlight(text: mdText.toString()),
          )
        : Text('—', style: TextStyle(color: bubbleFg.withOpacity(0.5)));

    if (isAssistant) {
      // Build mixed content: reasoning segments and tool cards按 toolStartIndex 混合显示
      final List<Widget> mixedContent = [];

      if (reasoningSegments.isNotEmpty) {
        for (int i = 0; i < reasoningSegments.length; i++) {
          final seg = reasoningSegments[i];
          final text = seg['text'] as String? ?? '';

          // Add the reasoning segment (if any text)
          if (text.isNotEmpty) {
            mixedContent.add(_ExportThinkingCard(
              thinkingText: text,
              cs: cs,
              expanded: expandThinkingContent,
            ));
            mixedContent.add(const SizedBox(height: 8));
          }

          // Determine tool range mapped to this segment: [start, end)
          int start = (seg['toolStartIndex'] as int?) ?? 0;
          final int end = (i < reasoningSegments.length - 1)
              ? (reasoningSegments[i + 1]['toolStartIndex'] as int?) ?? toolParts.length
              : toolParts.length;

          // Clamp to bounds and ensure non-decreasing
          if (start < 0) start = 0;
          if (start > toolParts.length) start = toolParts.length;
          final int clampedEnd = end.clamp(start, toolParts.length);

          for (int k = start; k < clampedEnd; k++) {
            // Hide builtin_search tool cards
            if (toolParts[k].toolName == 'builtin_search') continue;
            mixedContent.add(_ExportToolCard(part: toolParts[k], cs: cs));
            mixedContent.add(const SizedBox(height: 8));
          }
        }
      } else if (toolParts.isNotEmpty) {
        // No reasoning segments but have tool cards - show all tool cards
        for (final toolPart in toolParts) {
          if (toolPart.toolName == 'builtin_search') continue;
          mixedContent.add(_ExportToolCard(part: toolPart, cs: cs));
          mixedContent.add(const SizedBox(height: 8));
        }
      }

      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AssistantHeader(message: message),
              const SizedBox(height: 8),
              ...mixedContent,
              contentWidget,
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: contentWidget,
        ),
      ),
    );
  }

  // Helper to deserialize reasoning segments
  List<Map<String, dynamic>> _deserializeReasoningSegments(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}

// Assistant header (icon + name), mirroring chat style
class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final useAssist = (assistant?.useAssistantAvatar == true);
    final name = () {
      if (useAssist && (assistant?.name.trim().isNotEmpty ?? false)) {
        return assistant!.name.trim();
      }
      return _modelDisplayName(context, message) ?? AppLocalizations.of(context)!.messageExportSheetAssistant;
    }();

    final Widget leading = useAssist
        ? _AssistantAvatarSmall(assistant: assistant)
        : _ModelIconSmall(providerKey: message.providerId, modelId: message.modelId);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.7)),
        ),
      ],
    );
  }
}

class _ModelIconSmall extends StatelessWidget {
  const _ModelIconSmall({required this.providerKey, required this.modelId});
  final String? providerKey;
  final String? modelId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const double size = 28;
    if (providerKey == null || modelId == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: cs.secondary.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Lucide.Bot, size: 18, color: cs.secondary),
      );
    }
    String? asset = BrandAssets.assetForName(modelId!);
    asset ??= BrandAssets.assetForName(providerKey!);
    Widget inner;
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final isColorful = asset.contains('color');
        final ColorFilter? tint = (Theme.of(context).brightness == Brightness.dark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        inner = SvgPicture.asset(asset, width: size * 0.5, height: size * 0.5, colorFilter: tint);
      } else {
        inner = Image.asset(asset, width: size * 0.5, height: size * 0.5, fit: BoxFit.contain);
      }
    } else {
      inner = Text(
        modelId!.isNotEmpty ? modelId!.characters.first.toUpperCase() : '?',
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: size * 0.43),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : cs.primary.withOpacity(0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: SizedBox(width: size * 0.64, height: size * 0.64, child: Center(child: inner is SvgPicture || inner is Image ? inner : FittedBox(child: inner))),
    );
  }
}

class _AssistantAvatarSmall extends StatelessWidget {
  const _AssistantAvatarSmall({required this.assistant});
  final Assistant? assistant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final av = (assistant?.avatar ?? '').trim();
    const double size = 28;
    if (av.isNotEmpty) {
      if (av.startsWith('http')) {
        return FutureBuilder<String?>(
          future: AvatarCache.getPath(av),
          builder: (ctx, snap) {
            final p = snap.data;
            if (p != null && !kIsWeb && File(p).existsSync()) {
              return ClipOval(child: Image.file(File(p), width: size, height: size, fit: BoxFit.cover));
            }
            if (p != null && kIsWeb && p.startsWith('data:')) {
              return ClipOval(child: Image.network(p, width: size, height: size, fit: BoxFit.cover));
            }
            return ClipOval(
              child: Image.network(av, width: size, height: size, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _assistantInitial(cs, assistant?.name ?? '')),
            );
          },
        );
      }
      if (!kIsWeb && (av.startsWith('/') || av.contains(':'))) {
        final fixed = SandboxPathResolver.fix(av);
        return ClipOval(child: Image.file(File(fixed), width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _assistantInitial(cs, assistant?.name ?? '')));
      }
      // treat as emoji or single char label
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(av.characters.take(1).toString(), style: const TextStyle(fontSize: 16)),
      );
    }
    return _assistantInitial(cs, assistant?.name ?? '');
  }

  Widget _assistantInitial(ColorScheme cs, String name) {
    final ch = name.trim().isNotEmpty ? name.characters.first.toUpperCase() : 'A';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(ch, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}

class _ExportDisclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = AppLocalizations.of(context)!.exportDisclaimerAiGenerated;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Future<void> _runWithExportingOverlay(BuildContext context, Future<void> Function() task) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  // Show overlay first
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: Material(
        color: cs.surface,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.2),
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
                style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.8)),
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
    Navigator.of(context, rootNavigator: true).pop();
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
    final Color base = isDark ? cs.primary.withOpacity(0.10) : cs.primary.withOpacity(0.06);
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
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
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
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.75))),
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

// Simple thinking card widget for export
class _ExportThinkingCard extends StatelessWidget {
  const _ExportThinkingCard({
    required this.thinkingText,
    required this.cs,
    required this.expanded,
  });
  final String thinkingText;
  final ColorScheme cs;
  final bool expanded;

  String _sanitizeThinkingText(String s) {
    // 统一换行
    s = s.replaceAll('\r\n', '\n');
    s = s.replaceAll('\r', '');

    // 去掉首尾零宽字符（模型有时会插入）
    s = s
        .replaceAll(RegExp(r'^[\u200B\u200C\u200D\uFEFF]+'), '')
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]+$'), '');

    // 去掉**开头**的纯空白行
    s = s.replaceFirst(RegExp(r'^\s*\n+'), '');

    // 去掉**结尾**的纯空白行
    s = s.replaceFirst(RegExp(r'\n+\s*$'), '');

    return s.trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = cs.primaryContainer.withOpacity(isDark ? 0.25 : 0.30);
    final fg = cs.onPrimaryContainer;
    final l10n = AppLocalizations.of(context)!;
    final cleanedText = _sanitizeThinkingText(thinkingText);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/deepthink.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.chatMessageWidgetDeepThinking,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.secondary,
                  ),
                ),
                // const Spacer(),
                // Icon(
                //   Lucide.ChevronRight,
                //   size: 18,
                //   color: cs.secondary,
                // ),
              ],
            ),
          ),
          // Content (if expanded)
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Text(
                cleanedText,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.32,
                  leadingDistribution: TextLeadingDistribution.proportional,
                ),
                strutStyle: const StrutStyle(
                  forceStrutHeight: true,
                  fontSize: 12.5,
                  height: 1.32,
                  leading: 0,
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                  leadingDistribution: TextLeadingDistribution.proportional,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// Tool card widget for export
class _ExportToolCard extends StatelessWidget {
  const _ExportToolCard({required this.part, required this.cs});
  final ToolUIPart part;
  final ColorScheme cs;

  IconData _iconFor(String name) {
    switch (name) {
      case 'create_memory':
        return Lucide.bookHeart;
      case 'edit_memory':
        return Lucide.bookHeart;
      case 'delete_memory':
        return Lucide.bookDashed;
      case 'search_web':
        return Lucide.Earth;
      case 'builtin_search':
        return Lucide.Search;
      default:
        return Lucide.Wrench;
    }
  }

  String _titleFor(BuildContext context, String name, Map<String, dynamic> args) {
    final l10n = AppLocalizations.of(context)!;
    switch (name) {
      case 'create_memory':
        return l10n.chatMessageWidgetCreateMemory;
      case 'edit_memory':
        return l10n.chatMessageWidgetEditMemory;
      case 'delete_memory':
        return l10n.chatMessageWidgetDeleteMemory;
      case 'search_web':
        final q = (args['query'] ?? '').toString();
        return l10n.chatMessageWidgetWebSearch(q);
      case 'builtin_search':
        return l10n.chatMessageWidgetBuiltinSearch;
      default:
        return l10n.chatMessageWidgetToolCall(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = cs.primaryContainer.withOpacity(isDark ? 0.25 : 0.30);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Center(
              child: Icon(_iconFor(part.toolName), size: 18, color: cs.secondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _titleFor(context, part.toolName, part.arguments),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
