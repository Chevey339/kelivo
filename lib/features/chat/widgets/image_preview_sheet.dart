import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image/image.dart' as image_lib;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/clipboard_images.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'dart:ui' as ui;

const int _previewBlankTrimPreservePadding = 48;
const int _previewBlankAlphaTolerance = 8;
const int _previewBlankColorTolerance = 3;
const int _previewBlankMinContentPixels = 3;
const int _previewBlankMaxContentPixels = 16;
const int _previewBlankMinContentRun = 2;
const int _previewBlankMaxContentRun = 6;
const int _previewMaxTileSourceHeight = 2048;

Future<void> showImagePreviewSheet(
  BuildContext context, {
  required File file,
}) async {
  // On desktop platforms, show a custom dialog instead of bottom sheet
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ImagePreviewDesktopDialog(file: file),
    );
    return;
  }

  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) =>
        SafeArea(top: false, child: _ImagePreviewSheet(file: file)),
  );
}

class _ImagePreviewDesktopDialog extends StatefulWidget {
  const _ImagePreviewDesktopDialog({required this.file});
  final File file;

  @override
  State<_ImagePreviewDesktopDialog> createState() =>
      _ImagePreviewDesktopDialogState();
}

class _ImagePreviewDesktopDialogState
    extends State<_ImagePreviewDesktopDialog> {
  bool _saving = false;
  _ImagePreviewDisplay? _display;
  bool _loadingDisplay = true;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDisplay();
  }

  Future<void> _loadDisplay() async {
    final display = await _readImagePreviewDisplayAsync(widget.file);
    if (!mounted) return;
    setState(() {
      _display = display;
      _loadingDisplay = false;
    });
  }

  Rect _shareAnchorRect(BuildContext context) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          box.size.width > 0 &&
          box.size.height > 0) {
        final offset = box.localToGlobal(Offset.zero);
        return offset & box.size;
      }
    } catch (_) {}
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height / 2);
    return Rect.fromCenter(center: center, width: 1, height: 1);
  }

  Future<void> _onShare(BuildContext anchorContext) async {
    final l10n = AppLocalizations.of(context)!;
    final filename = widget.file.uri.pathSegments.isNotEmpty
        ? widget.file.uri.pathSegments.last
        : 'image.png';
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.file.path, mimeType: 'image/png')],
          fileNameOverrides: [filename],
          sharePositionOrigin: _shareAnchorRect(anchorContext),
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _onSaveDesktop() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final Uint8List bytes = await widget.file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        showAppSnackBar(
          context,
          message: l10n.imageViewerPageSaveFailed('empty-bytes'),
          type: NotificationType.error,
        );
        return;
      }

      final ext = p.extension(widget.file.path).isNotEmpty
          ? p.extension(widget.file.path)
          : '.png';
      final defaultName = 'kelivo-${DateTime.now().millisecondsSinceEpoch}$ext';
      final allowed = [ext.replaceFirst('.', '').toLowerCase()];
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.imageViewerPageSaveButton,
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: allowed,
      );
      if (!mounted) return;
      if (savePath == null) {
        return; // cancelled
      }

      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsBytes(bytes);

      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageSaveSuccess,
        type: NotificationType.success,
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageSaveFailed(e.toString()),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onCopy() async {
    // Prefer super_clipboard for robust cross-platform image copy
    bool ok = false;
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final path = widget.file.path;
        final bytes = await File(path).readAsBytes();
        if (bytes.isNotEmpty) {
          final ext = p.extension(path).toLowerCase();
          String format = 'png';
          Uint8List outBytes = bytes;
          if (ext == '.png') {
            format = 'png';
          } else if (ext == '.jpg' || ext == '.jpeg') {
            format = 'jpeg';
          } else if (ext == '.gif') {
            format = 'gif';
          } else if (ext == '.webp') {
            format = 'webp';
          } else {
            // Convert unknown formats to PNG via image codec
            try {
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              final data = await frame.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (data != null) {
                outBytes = data.buffer.asUint8List();
                format = 'png';
              }
            } catch (_) {}
          }

          // Build clipboard item with suggested name
          String suggestedName = p.basename(path);
          if (format == 'png' &&
              !suggestedName.toLowerCase().endsWith('.png')) {
            suggestedName = p.setExtension(suggestedName, '.png');
          }
          final item = DataWriterItem(suggestedName: suggestedName);
          switch (format) {
            case 'png':
              item.add(Formats.png(outBytes));
              break;
            case 'jpeg':
              item.add(Formats.jpeg(outBytes));
              break;
            case 'gif':
              item.add(Formats.gif(outBytes));
              break;
            case 'webp':
              item.add(Formats.webp(outBytes));
              break;
          }
          await clipboard.write([item]);
          ok = true;
        }
      }
    } catch (_) {
      ok = false;
    }
    // Fallback to legacy platform channel if needed
    if (!ok) {
      try {
        ok = await ClipboardImages.setImagePath(widget.file.path);
      } catch (_) {}
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (ok) {
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetCopiedToClipboard,
        type: NotificationType.success,
      );
    } else {
      // Reuse export failed message to avoid adding new l10n
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('copy-failed'),
        type: NotificationType.error,
      );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 720,
          minWidth: 520,
          maxHeight: 720,
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
                      Text(
                        l10n.assistantEditPreviewTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _DesktopIconButton(
                        tooltip: l10n.shareProviderSheetCopyButton,
                        onTap: _onCopy,
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                      const SizedBox(width: 6),
                      _DesktopIconButton(
                        tooltip: l10n.settingsPageShare,
                        onTap: () => _onShare(context),
                        icon: const Icon(Icons.share_outlined, size: 18),
                      ),
                      const SizedBox(width: 6),
                      _DesktopIconButton(
                        tooltip: l10n.imageViewerPageSaveButton,
                        onTap: _saving ? null : _onSaveDesktop,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CupertinoActivityIndicator(radius: 9),
                              )
                            : const Icon(Icons.download_outlined, size: 18),
                      ),
                      const SizedBox(width: 6),
                      _DesktopIconButton(
                        tooltip: l10n.sideDrawerCancel,
                        onTap: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Scrollbar(
                    controller: _scrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (_loadingDisplay) {
                              return const SizedBox(
                                height: 360,
                                child: Center(
                                  child: CupertinoActivityIndicator(radius: 14),
                                ),
                              );
                            }
                            return _ImagePreviewCard(
                              file: widget.file,
                              display: _display,
                              maxWidth: constraints.maxWidth,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreviewSheet extends StatefulWidget {
  const _ImagePreviewSheet({required this.file});
  final File file;

  @override
  State<_ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewCard extends StatelessWidget {
  const _ImagePreviewCard({
    required this.file,
    required this.display,
    required this.maxWidth,
  });

  final File file;
  final _ImagePreviewDisplay? display;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = maxWidth.isFinite ? maxWidth : null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildPreviewImageFrame(
        file: file,
        display: display,
        width: width,
      ),
    );
  }
}

Widget _buildPreviewImageFrame({
  required File file,
  required _ImagePreviewDisplay? display,
  required double? width,
}) {
  if (display == null) {
    return _buildPreviewImage(
      image: FileImage(file),
      width: width,
      height: null,
      fit: BoxFit.contain,
    );
  }

  return SizedBox(
    width: width,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tile in display.tiles)
          _buildPreviewImage(
            image: tile.provider,
            width: width,
            height: _previewDisplayHeight(
              width: width,
              dimensions: tile.dimensions,
            ),
            fit: BoxFit.fill,
          ),
      ],
    ),
  );
}

Image _buildPreviewImage({
  required ImageProvider image,
  required double? width,
  required double? height,
  required BoxFit fit,
}) {
  return Image(image: image, width: width, height: height, fit: fit);
}

@visibleForTesting
Image buildPreviewImageForTesting({
  required File file,
  required double? width,
}) {
  final display = _readImagePreviewDisplay(file);
  final tile = display?.tiles.first;
  return _buildPreviewImage(
    image: tile?.provider ?? FileImage(file),
    width: width,
    height: _previewDisplayHeight(
      width: width,
      dimensions: tile?.dimensions ?? display?.dimensions,
    ),
    fit: BoxFit.contain,
  );
}

@visibleForTesting
({double? height, int tileCount, List<ImageProvider> providers})
previewImageDisplayLayoutForTesting({
  required File file,
  required double? width,
  Object? cachedDisplay,
}) {
  final display =
      (cachedDisplay as _ImagePreviewDisplay?) ??
      _readImagePreviewDisplay(file);
  return (
    height: _previewDisplayHeight(
      width: width,
      dimensions: display?.dimensions,
    ),
    tileCount: display?.tiles.length ?? 1,
    providers:
        display?.tiles.map((tile) => tile.provider).toList() ??
        <ImageProvider>[FileImage(file)],
  );
}

@visibleForTesting
Object? readPreviewDisplayForTesting(File file) {
  return _readImagePreviewDisplay(file);
}

class _ImagePreviewDisplay {
  const _ImagePreviewDisplay({required this.dimensions, required this.tiles});

  final ({int width, int height}) dimensions;
  final List<_ImagePreviewTile> tiles;
}

class _ImagePreviewTile {
  const _ImagePreviewTile({required this.provider, required this.dimensions});

  final ImageProvider provider;
  final ({int width, int height}) dimensions;
}

class _ImagePreviewDisplayPayload {
  const _ImagePreviewDisplayPayload({
    required this.dimensions,
    required this.tiles,
  });

  final ({int width, int height}) dimensions;
  final List<_ImagePreviewTilePayload> tiles;
}

class _ImagePreviewTilePayload {
  const _ImagePreviewTilePayload({
    required this.bytes,
    required this.dimensions,
    required this.useFile,
  });

  final Uint8List? bytes;
  final ({int width, int height}) dimensions;
  final bool useFile;
}

_ImagePreviewDisplay? _readImagePreviewDisplay(File file) {
  try {
    return _previewDisplayFromPayload(
      _readImagePreviewDisplayPayloadSync(file.path),
      file,
    );
  } catch (_) {
    return null;
  }
}

Future<_ImagePreviewDisplay?> _readImagePreviewDisplayAsync(File file) async {
  try {
    final payload = await compute(
      _readImagePreviewDisplayPayloadSync,
      file.path,
      debugLabel: 'image-preview-display-processing',
    );
    return _previewDisplayFromPayload(payload, file);
  } catch (_) {
    return null;
  }
}

@visibleForTesting
Future<Object?> readPreviewDisplayAsyncForTesting(File file) {
  return _readImagePreviewDisplayAsync(file);
}

_ImagePreviewDisplayPayload? _readImagePreviewDisplayPayloadSync(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return null;
  }
  final trimmed = _trimPreviewBlankPadding(decoded);
  final source = trimmed.image;
  return _ImagePreviewDisplayPayload(
    dimensions: (width: source.width, height: source.height),
    tiles: _previewImageTilePayloads(
      source,
      forceMemoryImage:
          trimmed.changed || source.height > _previewMaxTileSourceHeight,
    ),
  );
}

_ImagePreviewDisplay? _previewDisplayFromPayload(
  _ImagePreviewDisplayPayload? payload,
  File file,
) {
  if (payload == null) return null;
  return _ImagePreviewDisplay(
    dimensions: payload.dimensions,
    tiles: payload.tiles
        .map(
          (tile) => _ImagePreviewTile(
            provider: tile.useFile
                ? FileImage(file)
                : MemoryImage(tile.bytes ?? Uint8List(0)),
            dimensions: tile.dimensions,
          ),
        )
        .toList(growable: false),
  );
}

List<_ImagePreviewTilePayload> _previewImageTilePayloads(
  image_lib.Image image, {
  required bool forceMemoryImage,
}) {
  if (!forceMemoryImage) {
    return [
      _ImagePreviewTilePayload(
        bytes: null,
        dimensions: (width: image.width, height: image.height),
        useFile: true,
      ),
    ];
  }

  final tiles = <_ImagePreviewTilePayload>[];
  var y = 0;
  while (y < image.height) {
    final tileHeight = (image.height - y) > _previewMaxTileSourceHeight
        ? _previewMaxTileSourceHeight
        : image.height - y;
    final tileImage = image_lib.copyCrop(
      image,
      x: 0,
      y: y,
      width: image.width,
      height: tileHeight,
    );
    tiles.add(
      _ImagePreviewTilePayload(
        bytes: Uint8List.fromList(image_lib.encodePng(tileImage)),
        dimensions: (width: tileImage.width, height: tileImage.height),
        useFile: false,
      ),
    );
    y += tileHeight;
  }
  return tiles;
}

({image_lib.Image image, bool changed}) _trimPreviewBlankPadding(
  image_lib.Image decoded,
) {
  final background = _previewBlankReferencePixel(decoded);
  final width = decoded.width;
  final height = decoded.height;

  int? top;
  for (var y = 0; y < height; y += 1) {
    if (_previewRowHasContent(decoded, y, background)) {
      top = y;
      break;
    }
  }
  if (top == null) return (image: decoded, changed: false);

  var bottom = height - 1;
  for (var y = height - 1; y >= top; y -= 1) {
    if (_previewRowHasContent(decoded, y, background)) {
      bottom = y;
      break;
    }
  }

  var left = 0;
  for (var x = 0; x < width; x += 1) {
    if (_previewColumnHasContent(decoded, x, top, bottom, background)) {
      left = x;
      break;
    }
  }

  var right = width - 1;
  for (var x = width - 1; x >= left; x -= 1) {
    if (_previewColumnHasContent(decoded, x, top, bottom, background)) {
      right = x;
      break;
    }
  }

  const padding = _previewBlankTrimPreservePadding;
  final cropLeft = (left - padding).clamp(0, width - 1);
  final cropTop = (top - padding).clamp(0, height - 1);
  final cropRight = (right + padding).clamp(0, width - 1);
  final cropBottom = (bottom + padding).clamp(0, height - 1);

  if (cropLeft == 0 &&
      cropTop == 0 &&
      cropRight == width - 1 &&
      cropBottom == height - 1) {
    return (image: decoded, changed: false);
  }

  return (
    image: image_lib.copyCrop(
      decoded,
      x: cropLeft,
      y: cropTop,
      width: cropRight - cropLeft + 1,
      height: cropBottom - cropTop + 1,
    ),
    changed: true,
  );
}

image_lib.Pixel _previewBlankReferencePixel(image_lib.Image image) {
  final counts = <int, ({int count, image_lib.Pixel pixel})>{};
  void add(image_lib.Pixel pixel) {
    if (pixel.a <= _previewBlankAlphaTolerance) return;
    final key =
        ((pixel.r.toInt() ~/ 8) << 24) |
        ((pixel.g.toInt() ~/ 8) << 16) |
        ((pixel.b.toInt() ~/ 8) << 8) |
        (pixel.a.toInt() ~/ 8);
    final current = counts[key];
    counts[key] = (
      count: (current?.count ?? 0) + 1,
      pixel: current?.pixel ?? pixel,
    );
  }

  for (var x = 0; x < image.width; x += 1) {
    add(image.getPixel(x, 0));
    add(image.getPixel(x, image.height - 1));
  }
  for (var y = 1; y < image.height - 1; y += 1) {
    add(image.getPixel(0, y));
    add(image.getPixel(image.width - 1, y));
  }

  if (counts.isNotEmpty) {
    return counts.values.reduce((a, b) => a.count >= b.count ? a : b).pixel;
  }
  return image.getPixel(0, 0);
}

bool _previewRowHasContent(
  image_lib.Image image,
  int y,
  image_lib.Pixel background,
) {
  final pixelThreshold = _previewContentPixelThreshold(image.width);
  final runThreshold = _previewContentRunThreshold(image.width);
  var contentPixels = 0;
  var currentRun = 0;
  var longestRun = 0;
  for (var x = 0; x < image.width; x += 1) {
    if (_previewIsBlankPixel(image.getPixel(x, y), background)) {
      currentRun = 0;
      continue;
    }
    contentPixels += 1;
    currentRun += 1;
    if (currentRun > longestRun) longestRun = currentRun;
    if (contentPixels >= pixelThreshold && longestRun >= runThreshold) {
      return true;
    }
  }
  return false;
}

bool _previewColumnHasContent(
  image_lib.Image image,
  int x,
  int top,
  int bottom,
  image_lib.Pixel background,
) {
  final length = bottom - top + 1;
  final pixelThreshold = _previewContentPixelThreshold(length);
  final runThreshold = _previewContentRunThreshold(length);
  var contentPixels = 0;
  var currentRun = 0;
  var longestRun = 0;
  for (var y = top; y <= bottom; y += 1) {
    if (_previewIsBlankPixel(image.getPixel(x, y), background)) {
      currentRun = 0;
      continue;
    }
    contentPixels += 1;
    currentRun += 1;
    if (currentRun > longestRun) longestRun = currentRun;
    if (contentPixels >= pixelThreshold && longestRun >= runThreshold) {
      return true;
    }
  }
  return false;
}

int _previewContentPixelThreshold(int lineLength) {
  final scaled = (lineLength * 0.01).ceil();
  if (scaled < _previewBlankMinContentPixels) {
    return _previewBlankMinContentPixels;
  }
  if (scaled > _previewBlankMaxContentPixels) {
    return _previewBlankMaxContentPixels;
  }
  return scaled;
}

int _previewContentRunThreshold(int lineLength) {
  final scaled = (lineLength * 0.005).ceil();
  if (scaled < _previewBlankMinContentRun) {
    return _previewBlankMinContentRun;
  }
  if (scaled > _previewBlankMaxContentRun) {
    return _previewBlankMaxContentRun;
  }
  return scaled;
}

bool _previewIsBlankPixel(image_lib.Pixel pixel, image_lib.Pixel background) {
  if (pixel.a <= _previewBlankAlphaTolerance) return true;
  if (background.a <= _previewBlankAlphaTolerance) return false;
  return _previewChannelNear(pixel.r, background.r) &&
      _previewChannelNear(pixel.g, background.g) &&
      _previewChannelNear(pixel.b, background.b) &&
      _previewChannelNear(pixel.a, background.a);
}

bool _previewChannelNear(num a, num b) {
  return (a - b).abs() <= _previewBlankColorTolerance;
}

double? _previewDisplayHeight({
  required double? width,
  required ({int width, int height})? dimensions,
}) {
  if (width == null || dimensions == null) return null;
  return width * dimensions.height / dimensions.width;
}

Future<dynamic> _saveImagePreviewFile(File file, {required String name}) async {
  return ImageGallerySaverPlus.saveFile(
    Platform.isIOS ? file.uri.toString() : file.path,
    name: name,
    isReturnPathOfIOS: true,
  );
}

@visibleForTesting
Future<dynamic> saveImagePreviewFileForTesting(
  File file, {
  required String name,
}) {
  return _saveImagePreviewFile(file, name: name);
}

class _DesktopIconButton extends StatefulWidget {
  const _DesktopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_DesktopIconButton> createState() => _DesktopIconButtonState();
}

class _DesktopIconButtonState extends State<_DesktopIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool v) {
    if (_hovered == v) return;
    setState(() => _hovered = v);
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool disabled = widget.onTap == null;
    final Color baseBorder = cs.outline.withValues(alpha: 0.16);
    final Color hoverFill = cs.onSurface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.06,
    );
    final Color bg = _hovered ? hoverFill : Colors.transparent;
    final Color border = _hovered ? baseBorder : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) {
          _setHovered(false);
          _setPressed(false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOutCubic,
            scale: _pressed ? 0.96 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: disabled ? Colors.transparent : bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: disabled ? Colors.transparent : border,
                  width: 0.75,
                ),
              ),
              child: Center(
                child: IconTheme(
                  data: IconTheme.of(context).copyWith(
                    color: cs.onSurface.withValues(alpha: disabled ? 0.4 : 0.9),
                  ),
                  child: widget.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreviewSheetState extends State<_ImagePreviewSheet> {
  final DraggableScrollableController _ctrl = DraggableScrollableController();
  _ImagePreviewDisplay? _display;
  bool _loadingDisplay = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDisplay();
  }

  Future<void> _loadDisplay() async {
    final display = await _readImagePreviewDisplayAsync(widget.file);
    if (!mounted) return;
    setState(() {
      _display = display;
      _loadingDisplay = false;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Rect _shareAnchorRect(BuildContext context) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        return offset & box.size;
      }
    } catch (_) {}
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height / 2);
    return Rect.fromCenter(center: center, width: 1, height: 1);
  }

  Future<void> _onShare(BuildContext anchorContext) async {
    final l10n = AppLocalizations.of(context)!;
    final filename = widget.file.uri.pathSegments.isNotEmpty
        ? widget.file.uri.pathSegments.last
        : 'image.png';
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.file.path, mimeType: 'image/png')],
          fileNameOverrides: [filename],
          sharePositionOrigin: _shareAnchorRect(anchorContext),
        ),
      );
      if (!mounted) return;
      // Close only if sharing succeeds (when the platform reports it)
      if (result.status == ShareResultStatus.success) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final name = 'kelivo-${DateTime.now().millisecondsSinceEpoch}';
      final result = await _saveImagePreviewFile(widget.file, name: name);
      if (!mounted) return;
      bool success = false;
      if (result is Map) {
        final isSuccess =
            result['isSuccess'] == true || result['isSuccess'] == 1;
        final filePath = result['filePath'] ?? result['file_path'];
        success = isSuccess || (filePath is String && filePath.isNotEmpty);
      }
      if (success) {
        showAppSnackBar(
          context,
          message: l10n.imagePreviewSheetSaveSuccess,
          type: NotificationType.success,
        );
        // Auto-close the preview sheet after successful save
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        showAppSnackBar(
          context,
          message: l10n.imagePreviewSheetSaveFailed('unknown'),
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imagePreviewSheetSaveFailed('$e'),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      controller: _ctrl,
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.8,
      minChildSize: 0.4,
      builder: (c, sc) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Stack(
          children: [
            // Scrollable image preview
            Positioned.fill(
              child: Column(
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
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: sc,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_loadingDisplay)
                                  SizedBox(
                                    height: math.min(
                                      constraints.maxWidth * 1.2,
                                      420.0,
                                    ),
                                    child: const Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 14,
                                      ),
                                    ),
                                  )
                                else
                                  _ImagePreviewCard(
                                    file: widget.file,
                                    display: _display,
                                    maxWidth: constraints.maxWidth,
                                  ),
                                const SizedBox(
                                  height: 80,
                                ), // leave space for action bar overlap, outside the card
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Bottom action bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      // Left small square share button (no ripple)
                      Builder(
                        builder: (btnCtx) => SizedBox(
                          width: 48,
                          height: 48,
                          child: IosCardPress(
                            onTap: () => _onShare(btnCtx),
                            borderRadius: BorderRadius.circular(12),
                            baseColor: cs.surface,
                            pressedBlendStrength:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.14
                                : 0.10,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.outline.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Lucide.MoreVertical,
                                  color: cs.onSurface.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Right main save button (no ripple)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: IosCardPress(
                            onTap: _saving ? null : _onSave,
                            borderRadius: BorderRadius.circular(12),
                            baseColor: cs.primary,
                            pressedBlendStrength:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.14
                                : 0.12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _saving
                                      ? const SizedBox(
                                          key: ValueKey('saving'),
                                          width: 18,
                                          height: 18,
                                          child: CupertinoActivityIndicator(
                                            radius: 9,
                                          ),
                                        )
                                      : Row(
                                          key: const ValueKey('ready'),
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Lucide.Download,
                                              color: cs.onPrimary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.imagePreviewSheetSaveImage,
                                              style: TextStyle(
                                                color: cs.onPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
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
    );
  }
}
