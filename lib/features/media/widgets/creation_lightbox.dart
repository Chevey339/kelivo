import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../core/database/app_database.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../providers/media_creation_controller.dart';

Future<void> showCreationLightbox(
  BuildContext context,
  GenerationItemRow item, {
  required bool desktop,
}) async {
  final controller = context.read<MediaCreationController>();
  if (SandboxPathResolver.resolveForIo(item.path) == null) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.creationActionFailed,
    );
    return;
  }
  await showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .9),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierDismissible: true,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) =>
        _CreationLightbox(item: item, controller: controller, desktop: desktop),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _CreationLightbox extends StatelessWidget {
  const _CreationLightbox({
    required this.item,
    required this.controller,
    required this.desktop,
  });

  final GenerationItemRow item;
  final MediaCreationController controller;
  final bool desktop;

  Future<void> _perform(
    BuildContext context,
    Future<void> Function(String) action, {
    String? success,
  }) async {
    try {
      final path = SandboxPathResolver.resolveForIo(item.path);
      if (path == null) throw StateError('Creation file is unavailable');
      await action(path);
      if (context.mounted && success != null) {
        showAppSnackBar(context, message: success);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.creationActionFailed,
        );
      }
    }
  }

  Future<void> _save(String path) async {
    if (desktop) {
      final target = await FilePicker.platform.saveFile(
        fileName: p.basename(path),
      );
      if (target != null && !p.equals(path, target)) {
        await File(path).copy(target);
      }
    } else {
      final result = await ImageGallerySaverPlus.saveFile(path);
      if (result is! Map || result['isSuccess'] != true) {
        throw StateError('Could not save creation');
      }
    }
  }

  Future<void> _copy(String path) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) throw StateError('Image clipboard unavailable');
    final bytes = await File(path).readAsBytes();
    final format = switch (item.mime) {
      'image/jpeg' => Formats.jpeg,
      'image/webp' => Formats.webp,
      'image/gif' => Formats.gif,
      _ => Formats.png,
    };
    await clipboard.write([DataWriterItem()..add(format(bytes))]);
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.creationDeleteItem),
        content: Text(l10n.creationDeleteItemBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.chatHistoryPageDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _perform(context, (_) async {
      await controller.deleteItem(item);
      if (context.mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final batch = controller.batch(item.batchId);
    Widget icon(IconData icon, String title, VoidCallback onTap) =>
        IosIconButton(
          icon: icon,
          tooltip: title,
          color: Colors.white,
          minSize: 34,
          onTap: onTap,
        );
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop && Platform.isMacOS ? 90 : 12,
                  8,
                  12,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        batch?.prompt ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                    if (desktop) ...[
                      icon(
                        Lucide.Download,
                        l10n.creationSaveImage,
                        () => _perform(context, _save),
                      ),
                      icon(
                        Lucide.Share,
                        l10n.creationShare,
                        () =>
                            _perform(context, (path) => _share(context, path)),
                      ),
                    ],
                    PopupMenuButton<String>(
                      icon: const Icon(Lucide.Ellipsis, color: Colors.white),
                      onSelected: (option) {
                        switch (option) {
                          case 'save':
                            _perform(context, _save);
                          case 'share':
                            _perform(context, (path) => _share(context, path));
                          case 'copy':
                            _perform(
                              context,
                              _copy,
                              success: l10n.creationOptionCopied,
                            );
                          case 'delete':
                            _delete(context);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!desktop) ...[
                          PopupMenuItem(
                            value: 'save',
                            child: Text(l10n.creationSaveImage),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Text(l10n.creationShare),
                          ),
                        ],
                        PopupMenuItem(
                          value: 'copy',
                          child: Text(l10n.creationCopyImage),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.creationDeleteItem),
                        ),
                      ],
                    ),
                    icon(
                      Lucide.X,
                      MaterialLocalizations.of(context).closeButtonTooltip,
                      () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Hero(
                      tag: 'creation:${item.id}',
                      child: CreationFileImage(item.path, fit: BoxFit.contain),
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

  Future<void> _share(BuildContext context, String path) async {
    final box = context.findRenderObject()! as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

class CreationFileImage extends StatelessWidget {
  const CreationFileImage(this.path, {super.key, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final file = SandboxPathResolver.resolveForIo(path);
    const placeholder = Center(child: Icon(Lucide.Image, size: 22));
    return file == null
        ? placeholder
        : Image.file(
            File(file),
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => placeholder,
          );
  }
}
