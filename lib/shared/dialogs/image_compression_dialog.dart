import 'dart:io';

import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/format.dart';
import '../widgets/ios_tactile.dart';

/// Compression config returned by [ImageCompressionDialog].
class CompressionConfig {
  final int quality;
  final int? maxDimension;
  final bool keepPng;
  final bool compressAll;

  const CompressionConfig({
    required this.quality,
    this.maxDimension,
    required this.keepPng,
    required this.compressAll,
  });
}

/// Image compression dialog. Follows the "same content, different shell" pattern.
///
/// Use [show] on desktop (centered Dialog) and [showSheet] on mobile (bottom sheet).
/// Callback invoked when the user confirms compression.
/// The dialog stays open with a spinner until the returned Future completes.
typedef CompressionCallback = Future<void> Function(CompressionConfig config);

class ImageCompressionDialog {
  /// Desktop: centered Dialog
  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    required int totalImageCount,
    required int originalWidth,
    required int originalHeight,
    required bool hasRealAlpha,
    required CompressionCallback onCompress,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImageCompressionDialogBody(
        imagePath: imagePath,
        totalImageCount: totalImageCount,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        hasRealAlpha: hasRealAlpha,
        isSheet: false,
        onCompress: onCompress,
      ),
    );
  }

  /// Mobile: bottom sheet
  static Future<void> showSheet(
    BuildContext context, {
    required String imagePath,
    required int totalImageCount,
    required int originalWidth,
    required int originalHeight,
    required bool hasRealAlpha,
    required CompressionCallback onCompress,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: _ImageCompressionDialogBody(
          imagePath: imagePath,
          totalImageCount: totalImageCount,
          originalWidth: originalWidth,
          originalHeight: originalHeight,
          hasRealAlpha: hasRealAlpha,
          isSheet: true,
          onCompress: onCompress,
        ),
      ),
    );
  }
}

class _ImageCompressionDialogBody extends StatefulWidget {
  const _ImageCompressionDialogBody({
    required this.imagePath,
    required this.totalImageCount,
    required this.originalWidth,
    required this.originalHeight,
    required this.hasRealAlpha,
    required this.onCompress,
    this.isSheet = false,
  });

  final String imagePath;
  final int totalImageCount;
  final int originalWidth;
  final int originalHeight;
  final bool hasRealAlpha;
  final bool isSheet;
  final CompressionCallback onCompress;

  @override
  State<_ImageCompressionDialogBody> createState() =>
      _ImageCompressionDialogBodyState();
}

class _ImageCompressionDialogBodyState
    extends State<_ImageCompressionDialogBody> {
  static const int _minQuality = 30;
  static const int _maxQuality = 100;

  late int _quality;
  late int _maxDimension;
  late bool _keepPng;
  bool _isCompressing = false;

  bool get _canBatch => widget.totalImageCount > 1;
  bool get _hasAlpha => widget.hasRealAlpha;
  int get _imageSizeBytes {
    try {
      return File(widget.imagePath).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  int get _maxDimensionUpper => widget.originalWidth > widget.originalHeight
      ? widget.originalWidth
      : widget.originalHeight;

  /// Slider minimum: allow down to 1/4 of original, capped at 320px.
  int get _sliderMin => (_maxDimensionUpper ~/ 4).clamp(1, 320);

  @override
  void initState() {
    super.initState();
    _quality = 75;
    _maxDimension = _maxDimensionUpper;
    _keepPng = _hasAlpha;
  }

  Future<void> _onConfirm({required bool compressAll}) async {
    if (_isCompressing) return;
    setState(() => _isCompressing = true);
    try {
      await widget.onCompress(
        CompressionConfig(
          quality: _quality,
          maxDimension: _maxDimension < _maxDimensionUpper
              ? _maxDimension
              : null,
          keepPng: _keepPng,
          compressAll: compressAll,
        ),
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (widget.isSheet) {
      return _buildSheetLayout(cs, l10n);
    }
    return _buildDialogLayout(cs, l10n);
  }

  Widget _buildDialogLayout(ColorScheme cs, AppLocalizations l10n) {
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: _buildBody(cs, l10n),
        ),
      ),
    );
  }

  Widget _buildSheetLayout(ColorScheme cs, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          _buildBody(cs, l10n),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(cs, l10n),
        const SizedBox(height: 16),
        _buildQualitySlider(cs, l10n),
        const SizedBox(height: 16),
        _buildDimensionSlider(cs, l10n),
        if (_hasAlpha) ...[
          const SizedBox(height: 16),
          _buildFormatOptions(cs, l10n),
        ],
        const SizedBox(height: 20),
        _buildActions(cs, l10n),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs, AppLocalizations l10n) {
    final size = _imageSizeBytes;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(widget.imagePath),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: cs.surfaceContainerHighest,
              child: Icon(
                Lucide.ImageOff,
                size: 24,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.imageCompressionDialogTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatBytes(size)}  ·  ${widget.originalWidth}×${widget.originalHeight}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualitySlider(ColorScheme cs, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.imageCompressionQuality,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const Spacer(),
            Text(
              (_hasAlpha && _keepPng) ? '—' : '$_quality%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.onSurface.withValues(
              alpha: isDark ? 0.22 : 0.18,
            ),
            thumbColor: cs.primary,
            overlayColor: cs.primary.withValues(alpha: 0.12),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: _quality.toDouble(),
            min: _minQuality.toDouble(),
            max: _maxQuality.toDouble(),
            divisions: _maxQuality - _minQuality,
            onChanged: (_hasAlpha && _keepPng)
                ? null
                : (v) => setState(() => _quality = v.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionSlider(ColorScheme cs, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.imageCompressionMaxDimension,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const Spacer(),
            Text(
              '$_maxDimension px',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.onSurface.withValues(
              alpha: isDark ? 0.22 : 0.18,
            ),
            thumbColor: cs.primary,
            overlayColor: cs.primary.withValues(alpha: 0.12),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: _maxDimension.toDouble(),
            min: _sliderMin.toDouble(),
            max: _maxDimensionUpper.toDouble(),
            divisions: ((_maxDimensionUpper - _sliderMin) ~/ 64).clamp(1, 100),
            onChanged: (v) => setState(() => _maxDimension = v.round()),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _dimensionChip(
              cs,
              l10n.imageCompressionDimensionOriginal,
              _maxDimensionUpper,
            ),
            const SizedBox(width: 6),
            _dimensionChip(
              cs,
              '1/2',
              (_maxDimensionUpper / 2).round().clamp(
                _sliderMin,
                _maxDimensionUpper,
              ),
            ),
            const SizedBox(width: 6),
            _dimensionChip(
              cs,
              '1/4',
              (_maxDimensionUpper / 4).round().clamp(
                _sliderMin,
                _maxDimensionUpper,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dimensionChip(ColorScheme cs, String label, int value) {
    final selected = _maxDimension == value;
    return IosCardPress(
      baseColor: selected
          ? cs.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      pressedScale: 0.96,
      borderRadius: BorderRadius.circular(6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      onTap: () => setState(
        () => _maxDimension = value.clamp(_sliderMin, _maxDimensionUpper),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  Widget _buildFormatOptions(ColorScheme cs, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.imageCompressionFormat,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          _formatOption(cs, l10n.imageCompressionKeepPng, true),
          const SizedBox(height: 4),
          _formatOption(cs, l10n.imageCompressionConvertJpeg, false),
        ],
      ),
    );
  }

  Widget _formatOption(ColorScheme cs, String label, bool value) {
    final selected = _keepPng == value;
    return GestureDetector(
      onTap: () => setState(() => _keepPng = value),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme cs, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isCompressing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.imageCompressionCancel),
        ),
        const SizedBox(width: 6),
        if (_isCompressing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          )
        else ...[
          TextButton(
            onPressed: () => _onConfirm(compressAll: false),
            child: Text(l10n.imageCompressionButton),
          ),
          if (_canBatch) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: () => _onConfirm(compressAll: true),
              child: Text(l10n.imageCompressionBatchButton),
            ),
          ],
        ],
      ],
    );
  }
}
