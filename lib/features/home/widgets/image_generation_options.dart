import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';

/// Holds the state of image generation options.
class ImageGenerationOptionsController {
  String quality = 'high';
  String sizeTier = 'auto';
  String aspectRatio = 'auto';
  String customAspectRatio = '16:9';
  String outputFormat = 'png';
  int? outputCompression;
  int count = 1;

  static const Map<String, Map<String, String>> sizePresets = {
    '1K': {
      '1:1': '1024x1024',
      '4:3': '1024x768',
      '3:4': '768x1024',
      '3:2': '1536x1024',
      '2:3': '1024x1536',
      '16:9': '1280x720',
      '9:16': '720x1280',
      '21:9': '1280x544',
      '9:21': '544x1280',
      '5:4': '1024x816',
      '4:5': '816x1024',
      '2:1': '1280x640',
      '1:2': '640x1280',
      '3:1': '1408x480',
      '1:3': '480x1408',
    },
    '2K': {
      '1:1': '2048x2048',
      '4:3': '2048x1536',
      '3:4': '1536x2048',
      '3:2': '2160x1440',
      '2:3': '1440x2160',
      '16:9': '2560x1440',
      '9:16': '1440x2560',
      '21:9': '2560x1088',
      '9:21': '1088x2560',
      '5:4': '2304x1840',
      '4:5': '1840x2304',
      '2:1': '2880x1440',
      '1:2': '1440x2880',
      '3:1': '3072x1024',
      '1:3': '1024x3072',
    },
    '4K': {
      '1:1': '2880x2880',
      '4:3': '3200x2400',
      '3:4': '2400x3200',
      '3:2': '3456x2304',
      '2:3': '2304x3456',
      '16:9': '3840x2160',
      '9:16': '2160x3840',
      '21:9': '3840x1600',
      '9:21': '1600x3840',
      '5:4': '3200x2560',
      '4:5': '2560x3200',
      '2:1': '3840x1920',
      '1:2': '1920x3840',
      '3:1': '3840x1280',
      '1:3': '1280x3840',
    },
  };

  static const Map<String, int> tierPixelBudget = {
    '1K': 1572864,
    '2K': 4194304,
    '4K': 8294400,
  };

  bool get customized {
    return quality != 'high' ||
        sizeTier != 'auto' ||
        aspectRatio != 'auto' ||
        outputFormat != 'png' ||
        outputCompression != null ||
        count != 1;
  }

  String get resolvedSize {
    if (sizeTier == 'auto') return 'auto';
    final ratio = _resolvedAspectRatio;
    if (ratio.isEmpty) return 'auto';
    return _calculateImageSize(sizeTier, ratio) ?? 'auto';
  }

  String get _resolvedAspectRatio {
    if (aspectRatio == 'custom') return customAspectRatio.trim();
    if (aspectRatio == 'auto') {
      final fallback = customAspectRatio.trim();
      return fallback.isEmpty ? '16:9' : fallback;
    }
    return aspectRatio;
  }

  Map<String, dynamic> toExtraBody() {
    final size = resolvedSize;
    return <String, dynamic>{
      'quality': quality,
      if (size != 'auto') 'size': size,
      'output_format': outputFormat,
      if (outputFormat != 'png' && outputCompression != null)
        'output_compression': outputCompression,
      if (count > 1) 'n': count,
    };
  }

  void restoreFromBody(Map<String, dynamic> body) {
    final q = body['quality']?.toString();
    final size = body['size']?.toString();
    final format = body['output_format']?.toString();
    final compression = body['output_compression'];
    final n = body['n'];
    if (q == 'auto' || q == 'low' || q == 'medium' || q == 'high') {
      quality = q!;
    }
    _restoreSize(size);
    if (format == 'png' || format == 'jpeg' || format == 'webp') {
      outputFormat = format!;
    }
    outputCompression = compression is int
        ? compression
        : int.tryParse(compression?.toString() ?? '');
    final parsedN = n is int ? n : int.tryParse(n?.toString() ?? '');
    if (parsedN != null && parsedN >= 1 && parsedN <= 4) {
      count = parsedN;
    }
  }

  void reset() {
    quality = 'high';
    sizeTier = 'auto';
    aspectRatio = 'auto';
    customAspectRatio = '16:9';
    outputFormat = 'png';
    outputCompression = null;
    count = 1;
  }

  String summary(AppLocalizations l10n) {
    final size = resolvedSize;
    final sizeLabel = size == 'auto'
        ? l10n.imageGenAutoSize
        : '$sizeTier ${_aspectRatioLabel(l10n)} $size';
    final countStr = count > 1 ? ' ×$count' : '';
    return '${quality.toUpperCase()} · $sizeLabel · '
        '${outputFormat.toUpperCase()}$countStr';
  }

  String _aspectRatioLabel(AppLocalizations l10n) {
    if (aspectRatio == 'auto') {
      return sizeTier == 'auto' ? l10n.imageGenAutoRatio : _resolvedAspectRatio;
    }
    if (aspectRatio == 'custom') {
      return customAspectRatio.trim().isEmpty
          ? l10n.imageGenCustomRatio
          : customAspectRatio.trim();
    }
    return aspectRatio;
  }

  void _restoreSize(String? size) {
    final normalized = _normalizeSize(size ?? '');
    if (normalized == null || normalized == 'auto') {
      sizeTier = 'auto';
      aspectRatio = 'auto';
      return;
    }
    for (final tierEntry in sizePresets.entries) {
      for (final ratioEntry in tierEntry.value.entries) {
        if (ratioEntry.value == normalized) {
          sizeTier = tierEntry.key;
          aspectRatio = ratioEntry.key;
          return;
        }
      }
    }
    final parsed = _parseSize(normalized);
    if (parsed == null) return;
    sizeTier = closestTier(parsed.width * parsed.height);
    aspectRatio = 'custom';
    customAspectRatio = _formatAspectRatio(parsed.width, parsed.height);
  }

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  static String? _calculateImageSize(String tier, String ratio) {
    final normalizedRatio = _normalizeRatio(ratio);
    if (normalizedRatio == null) return null;
    final preset = sizePresets[tier]?[normalizedRatio];
    if (preset != null) return preset;

    final parsed = _parseRatio(normalizedRatio);
    final pixelBudget = tierPixelBudget[tier];
    if (parsed == null || pixelBudget == null) return null;
    final targetRatio = parsed.width / parsed.height;
    var bestWidth = 0;
    var bestHeight = 0;
    var bestPixels = 0;
    const sizeMultiple = 16;
    const maxEdge = 3840;
    const minPixels = 655360;
    const maxAspectRatio = 3.0;
    const maxRatioError = 0.01;

    for (var w = sizeMultiple; w <= maxEdge; w += sizeMultiple) {
      final idealH = w / targetRatio;
      final candidates = <int>{
        (idealH / sizeMultiple).floor() * sizeMultiple,
        (idealH / sizeMultiple).ceil() * sizeMultiple,
      };
      for (final h in candidates) {
        if (h < sizeMultiple || h > maxEdge) continue;
        final pixels = w * h;
        if (pixels > pixelBudget || pixels < minPixels) continue;
        if (math.max(w / h, h / w) > maxAspectRatio) continue;
        final actualRatio = w / h;
        final ratioError = (actualRatio - targetRatio).abs() / targetRatio;
        if (ratioError > maxRatioError) continue;
        if (pixels > bestPixels) {
          bestPixels = pixels;
          bestWidth = w;
          bestHeight = h;
        }
      }
    }
    if (bestPixels == 0) return null;
    return '${bestWidth}x$bestHeight';
  }

  static ({double width, double height})? _parseRatio(String ratio) {
    final match = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*[:xX×]\s*(\d+(?:\.\d+)?)\s*$')
        .firstMatch(ratio);
    if (match == null) return null;
    final w = double.tryParse(match.group(1) ?? '');
    final h = double.tryParse(match.group(2) ?? '');
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return (width: w, height: h);
  }

  static String? _normalizeRatio(String ratio) {
    final parsed = _parseRatio(ratio);
    if (parsed == null) return null;
    final w = parsed.width;
    final h = parsed.height;
    if (w % 1 != 0 || h % 1 != 0) {
      return '${_trimDouble(w)}:${_trimDouble(h)}';
    }
    final iw = w.round();
    final ih = h.round();
    final divisor = gcd(iw, ih);
    return '${iw ~/ divisor}:${ih ~/ divisor}';
  }

  static String? _normalizeSize(String size) {
    final trimmed = size.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == 'auto') return trimmed;
    final parsed = _parseSize(trimmed);
    if (parsed == null) return null;
    return '${parsed.width}x${parsed.height}';
  }

  static ({int width, int height})? _parseSize(String size) {
    final match = RegExp(r'^\s*(\d+)\s*[xX×]\s*(\d+)\s*$')
        .firstMatch(size);
    if (match == null) return null;
    final w = int.tryParse(match.group(1) ?? '');
    final h = int.tryParse(match.group(2) ?? '');
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return (width: w, height: h);
  }

  static String closestTier(int pixels) {
    return tierPixelBudget.entries
        .map((e) => (tier: e.key, delta: (e.value - pixels).abs()))
        .reduce((a, b) => a.delta <= b.delta ? a : b)
        .tier;
  }

  static String _formatAspectRatio(int width, int height) {
    final divisor = gcd(width, height);
    return '${width ~/ divisor}:${height ~/ divisor}';
  }

  static int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);

  static String _trimDouble(double value) {
    final rounded = value.toStringAsFixed(4);
    return rounded
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'0+$'), '');
  }
}

// ---------------------------------------------------------------------------
// Bottom Sheet widget
// ---------------------------------------------------------------------------

/// Shows the image generation options bottom sheet.
class ImageGenerationOptionsSheet extends StatelessWidget {
  const ImageGenerationOptionsSheet({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final ImageGenerationOptionsController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final maxSheetHeight = math.min(
      media.size.height * 0.74,
      media.size.height - media.padding.top - 12,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 12 + media.viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, l10n),
                const SizedBox(height: 10),
                _buildChips(
                  context: context,
                  label: l10n.imageGenQualityLabel,
                  selected: controller.quality,
                  options: const [
                    (value: 'auto', label: null),
                    (value: 'low', label: null),
                    (value: 'medium', label: null),
                    (value: 'high', label: null),
                  ],
                  labelBuilder: (v) => _qualityLabel(l10n, v),
                  onSelected: (v) {
                    controller.quality = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 10),
                _buildChips(
                  context: context,
                  label: l10n.imageGenSizeLabel,
                  selected: controller.sizeTier,
                  options: const [
                    (value: 'auto', label: null),
                    (value: '1K', label: null),
                    (value: '2K', label: null),
                    (value: '4K', label: null),
                  ],
                  labelBuilder: (v) => _sizeLabel(l10n, v),
                  onSelected: (v) {
                    controller.sizeTier = v;
                    if (v == 'auto') controller.aspectRatio = 'auto';
                    onChanged();
                  },
                ),
                const SizedBox(height: 10),
                _buildChips(
                  context: context,
                  label: l10n.imageGenAspectRatioLabel,
                  selected: controller.aspectRatio,
                  options: const [
                    (value: 'auto', label: null),
                    (value: '1:1', label: null),
                    (value: '4:3', label: null),
                    (value: '3:4', label: null),
                    (value: '3:2', label: null),
                    (value: '2:3', label: null),
                    (value: '16:9', label: null),
                    (value: '9:16', label: null),
                    (value: '21:9', label: null),
                    (value: '9:21', label: null),
                    (value: '5:4', label: null),
                    (value: '4:5', label: null),
                    (value: '2:1', label: null),
                    (value: '1:2', label: null),
                    (value: '3:1', label: null),
                    (value: '1:3', label: null),
                    (value: 'custom', label: null),
                  ],
                  labelBuilder: (v) => _aspectRatioLabel(l10n, v),
                  onSelected: (v) {
                    controller.aspectRatio = v;
                    onChanged();
                  },
                ),
                if (controller.aspectRatio == 'custom') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(
                      text: controller.customAspectRatio,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.imageGenCustomRatioLabel,
                      hintText: l10n.imageGenCustomRatioHint,
                      isDense: true,
                    ),
                    onChanged: (v) {
                      controller.customAspectRatio = v;
                      onChanged();
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${l10n.imageGenActualSize}: ${controller.resolvedSize}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.64),
                      ),
                ),
                const SizedBox(height: 10),
                _buildChips(
                  context: context,
                  label: l10n.imageGenFormatLabel,
                  selected: controller.outputFormat,
                  options: const [
                    (value: 'png', label: null),
                    (value: 'jpeg', label: null),
                    (value: 'webp', label: null),
                  ],
                  labelBuilder: (v) => _formatLabel(l10n, v),
                  onSelected: (v) {
                    controller.outputFormat = v;
                    if (v == 'png') controller.outputCompression = null;
                    onChanged();
                  },
                ),
                if (controller.outputFormat != 'png') ...[
                  const SizedBox(height: 10),
                  _buildChips(
                    context: context,
                    label: l10n.imageGenCompressionLabel,
                    selected: (controller.outputCompression ?? 90).toString(),
                    options: const [
                      (value: '100', label: null),
                      (value: '90', label: null),
                      (value: '75', label: null),
                      (value: '50', label: null),
                    ],
                    labelBuilder: (v) => v,
                    onSelected: (v) {
                      controller.outputCompression = int.tryParse(v);
                      onChanged();
                    },
                  ),
                ],
                const SizedBox(height: 10),
                _buildNumberChips(
                  context: context,
                  label: l10n.imageGenCountLabel,
                  selected: controller.count,
                  options: const [1, 2, 3, 4],
                  onSelected: (v) {
                    controller.count = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  '${l10n.imageGenCurrent}: ${controller.summary(l10n)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.64),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(Lucide.Palette,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l10n.imageGenTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(
          onPressed: () {
            controller.reset();
            onChanged();
          },
          child: Text(l10n.imageGenReset),
        ),
      ],
    );
  }

  Widget _buildChips({
    required BuildContext context,
    required String label,
    required String selected,
    required List<({String value, String? label})> options,
    required String Function(String) labelBuilder,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(labelBuilder(option.value)),
                selected: selected == option.value,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => onSelected(option.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberChips({
    required BuildContext context,
    required String label,
    required int selected,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option.toString()),
                selected: selected == option,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }

  static String _qualityLabel(AppLocalizations l10n, String v) {
    switch (v) {
      case 'auto': return l10n.imageGenAuto;
      case 'low': return l10n.imageGenLow;
      case 'medium': return l10n.imageGenMedium;
      case 'high': return l10n.imageGenHigh;
      default: return v;
    }
  }

  static String _sizeLabel(AppLocalizations l10n, String v) {
    switch (v) {
      case 'auto': return l10n.imageGenAuto;
      case '1K': return '1K';
      case '2K': return '2K';
      case '4K': return '4K';
      default: return v;
    }
  }

  static String _aspectRatioLabel(AppLocalizations l10n, String v) {
    if (v == 'auto') return l10n.imageGenAuto;
    if (v == 'custom') return l10n.imageGenCustomRatio;
    return v;
  }

  static String _formatLabel(AppLocalizations l10n, String v) {
    switch (v) {
      case 'png': return '${l10n.imageGenPNG} ${l10n.imageGenLossless}';
      case 'jpeg': return 'JPEG';
      case 'webp': return 'WEBP';
      default: return v;
    }
  }
}