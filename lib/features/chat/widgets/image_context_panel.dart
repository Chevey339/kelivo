import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/image_context.dart';
import '../../../core/services/api/request_image_context.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../home/services/context_usage_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';

Future<void> showImageContextPanel(
  BuildContext context,
  String conversationId, {
  ValueChanged<String>? onAttach,
}) async {
  final chat = context.read<ChatService>();
  final usage = context.read<ContextUsageService>();
  final title = AppLocalizations.of(context)!.imageContextTitle;
  Widget panel(ScrollController? scroll) => ImageContextPanel(
    conversationId: conversationId,
    chat: chat,
    usage: usage,
    onAttach: onAttach,
    scrollController: scroll,
  );
  if (ResponsiveHelper.isDesktop(context)) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 620, height: 480, child: panel(null)),
        actions: [
          IosTextButton(
            label: MaterialLocalizations.of(context).closeButtonLabel,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else {
    await showCustomBottomSheet<void>(
      context: context,
      title: title,
      builder: (_, scroll) => panel(scroll),
    );
  }
}

class ImageContextPanel extends StatefulWidget {
  const ImageContextPanel({
    super.key,
    required this.conversationId,
    required this.chat,
    required this.usage,
    this.onAttach,
    this.scrollController,
  });
  final String conversationId;
  final ChatService chat;
  final ContextUsageService usage;
  final ValueChanged<String>? onAttach;
  final ScrollController? scrollController;
  @override
  State<ImageContextPanel> createState() => _ImageContextPanelState();
}

class _ImageContextPanelState extends State<ImageContextPanel> {
  RequestImageContext? _request;
  List<ImageContextPreviewItem> _items = [];
  Object? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final request = await widget.usage.imageContextPreview(
        widget.conversationId,
      );
      final items = await request?.preview() ?? [];
      if (mounted) {
        setState(() {
          _request = request;
          _items = items;
          _error = null;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _busy = false;
        });
      }
    }
  }

  Future<void> _save(ImageContextSettings settings) async {
    setState(() => _busy = true);
    try {
      await widget.chat.setImageContextSettings(
        widget.conversationId,
        settings,
      );
      await widget.usage.refresh(widget.conversationId, force: true);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _busy = false;
        });
      }
    }
  }

  Future<void> _attach(ChatContextImage image) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      // Revalidate the clear boundary in case it changed while this panel was open.
      final current = await widget.usage.imageContextPreview(
        widget.conversationId,
      );
      final path = await current?.attachmentPath(image.handle);
      if (path == null) throw StateError(l10n.imageContextUnavailable);
      widget.onAttach?.call(path);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = _request?.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings != null)
          Row(
            children: [
              IosCheckbox(
                value: settings.automatic,
                semanticLabel: l10n.imageContextAutomatic,
                onChanged: _busy
                    ? null
                    : (value) => _save(
                        ImageContextSettings(
                          automatic: value,
                          pinned: settings.pinned,
                        ),
                      ),
              ),
              Expanded(child: Text(l10n.imageContextAutomatic)),
            ],
          ),
        Text(
          l10n.imageContextDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Expanded(
          child: _items.isEmpty && !_busy
              ? Center(child: Text(l10n.imageContextEmpty))
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final image = item.image;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            image.source == ContextImageSource.user
                                ? Lucide.Image
                                : Lucide.Wrench,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  image.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.included ? l10n.imageContextIncluded : l10n.imageContextOmitted} · ${image.handle}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IosIconButton(
                            icon: item.pinned ? Lucide.PinOff : Lucide.Pin,
                            size: 18,
                            tooltip: item.pinned
                                ? l10n.imageContextUnpin
                                : l10n.imageContextPin,
                            onTap: _busy
                                ? null
                                : () => _save(
                                    settings!.pin(image.key, !item.pinned),
                                  ),
                          ),
                          if (widget.onAttach != null)
                            IosIconButton(
                              icon: Lucide.Plus,
                              size: 18,
                              tooltip: l10n.imageContextAttachAgain,
                              onTap: _busy || image.unavailable
                                  ? null
                                  : () => _attach(image),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
