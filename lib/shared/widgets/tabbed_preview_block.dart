import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';
import 'export_capture_scope.dart';
import 'ios_tactile.dart';
import 'snackbar.dart';

// ---------------------------------------------------------------------------
// Color scheme shared by all tabbed preview blocks (PlantUML, Mermaid, SVG).
// ---------------------------------------------------------------------------

class PreviewBlockColors {
  const PreviewBlockColors({
    required this.body,
    required this.header,
    required this.border,
    required this.tabTrack,
    required this.tabSelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final Color body;
  final Color header;
  final Color border;
  final Color tabTrack;
  final Color tabSelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  static PreviewBlockColors resolve(bool isDark) {
    if (isDark) {
      return const PreviewBlockColors(
        body: Color(0xFF212121),
        header: Color(0xFF303030),
        border: Color(0xFF383838),
        tabTrack: Color(0xF2212121),
        tabSelected: Color(0xFF333333),
        textPrimary: Color(0xFFE6E6E6),
        textSecondary: Color(0xFFA0A0A0),
        textTertiary: Color(0xFF707070),
      );
    }
    return const PreviewBlockColors(
      body: Color(0xFFF8F8F8),
      header: Color(0xFFEDEDED),
      border: Color(0xFFE0E0E0),
      tabTrack: Color(0xCCD9D9D9),
      tabSelected: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF261208),
      textSecondary: Color(0xFF46352B),
      textTertiary: Color(0xFF5B4C43),
    );
  }
}

// ---------------------------------------------------------------------------
// Segmented tab button (Image / Code).
// ---------------------------------------------------------------------------

class PreviewTabButton extends StatefulWidget {
  const PreviewTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final PreviewBlockColors colors;
  final VoidCallback onTap;

  @override
  State<PreviewTabButton> createState() => _PreviewTabButtonState();
}

class _PreviewTabButtonState extends State<PreviewTabButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.selected
        ? widget.colors.tabSelected
        : Colors.transparent;
    final hoverColor = Color.alphaBlend(
      widget.colors.textPrimary.withValues(alpha: _pressed ? 0.10 : 0.06),
      baseColor,
    );
    final bg = widget.selected || _pressed || _hovered
        ? hoverColor
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectionContainer.disabled(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: widget.selected
                      ? AppFontWeights.semibold
                      : AppFontWeights.medium,
                  color: widget.selected
                      ? widget.colors.textPrimary
                      : widget.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon action button used in the header toolbar.
// ---------------------------------------------------------------------------

class PreviewTextAction extends StatelessWidget {
  const PreviewTextAction({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final PreviewBlockColors colors;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    final color = colors.textSecondary.withValues(alpha: active ? 0.88 : 0.38);

    return Tooltip(
      message: label,
      child: IosIconButton(
        onTap: onTap,
        enabled: active,
        semanticLabel: label,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        builder: (buttonColor) => Icon(icon, size: 14, color: buttonColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading indicator.
// ---------------------------------------------------------------------------

class PreviewLoadingView extends StatelessWidget {
  const PreviewLoadingView({super.key, required this.colors});

  final PreviewBlockColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state (image failed to load).
// ---------------------------------------------------------------------------

class PreviewErrorView extends StatelessWidget {
  const PreviewErrorView({super.key, required this.colors});

  final PreviewBlockColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Lucide.ImageOff, size: 48, color: colors.textTertiary),
    );
  }
}

// ---------------------------------------------------------------------------
// Abstract base widget for tabbed image / code preview blocks.
//
// Subclasses must implement [buildImageContent] and [buildExtraActions].
// The base provides the shared header (Image / Code tabs + Copy button),
// a fixed‑height animated switcher body, and the plain‑text code view.
// ---------------------------------------------------------------------------

abstract class TabbedPreviewBlock extends StatefulWidget {
  const TabbedPreviewBlock({super.key, required this.code});

  final String code;
}

abstract class TabbedPreviewBlockState<T extends TabbedPreviewBlock>
    extends State<T> {
  static const double previewHeight = 406;

  bool _showCode = false;
  late final ScrollController codeScrollController;

  // -----------------------------------------------------------------------
  // Subclass hooks
  // -----------------------------------------------------------------------

  /// The content shown when the Image tab is selected.
  Widget buildImageContent(BuildContext context, PreviewBlockColors colors);

  /// Extra header actions placed after the built‑in Copy button.
  /// Return an empty list when no extras are needed.
  List<Widget> buildExtraActions(
    BuildContext context,
    PreviewBlockColors colors,
    bool exporting,
  );

  /// Called after the tab is reset when [code] changes.
  void onCodeChanged() {}

  // -----------------------------------------------------------------------
  // Tab label overrides (default to Mermaid keys).
  // -----------------------------------------------------------------------

  String imageTabLabel(AppLocalizations l10n) => l10n.mermaidImageTab;
  String codeTabLabel(AppLocalizations l10n) => l10n.mermaidCodeTab;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    codeScrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _showCode = false;
      onCodeChanged();
    }
  }

  @override
  void dispose() {
    codeScrollController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final exporting = ExportCaptureScope.of(context);
    final colors = PreviewBlockColors.resolve(isDark);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.body,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, l10n, colors, exporting),
          _buildBody(colors),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    PreviewBlockColors colors,
    bool exporting,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.tabTrack,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PreviewTabButton(
                          label: imageTabLabel(l10n),
                          selected: !_showCode,
                          colors: colors,
                          onTap: () => setState(() => _showCode = false),
                        ),
                        PreviewTabButton(
                          label: codeTabLabel(l10n),
                          selected: _showCode,
                          colors: colors,
                          onTap: () => setState(() => _showCode = true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!exporting)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PreviewTextAction(
                    icon: Lucide.Copy,
                    label: l10n.shareProviderSheetCopyButton,
                    colors: colors,
                    onTap: () => _copyCode(context),
                  ),
                  ..._buildSpacedActions(context, colors, exporting),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSpacedActions(
    BuildContext context,
    PreviewBlockColors colors,
    bool exporting,
  ) {
    final extras = buildExtraActions(context, colors, exporting);
    if (extras.isEmpty) return const [];
    return [
      const SizedBox(width: 4),
      ...extras.expand((w) => [w, const SizedBox(width: 4)]).toList()
        ..removeLast(),
    ];
  }

  Widget _buildBody(PreviewBlockColors colors) {
    return SizedBox(
      key: const ValueKey('preview-body'),
      width: double.infinity,
      height: previewHeight,
      child: ColoredBox(
        color: colors.body,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return currentChild ?? const SizedBox.shrink();
          },
          child: _showCode
              ? _buildCodeView(colors)
              : Padding(
                  key: const ValueKey('preview-image-body'),
                  padding: const EdgeInsets.all(8),
                  child: buildImageContent(context, colors),
                ),
        ),
      ),
    );
  }

  Widget _buildCodeView(PreviewBlockColors colors) {
    return Padding(
      key: const ValueKey('preview-code-body'),
      padding: const EdgeInsets.all(12),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        child: Scrollbar(
          controller: codeScrollController,
          thumbVisibility: true,
          interactive: true,
          notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
          child: SingleChildScrollView(
            controller: codeScrollController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                widget.code,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    final copiedMessage = AppLocalizations.of(
      context,
    )!.chatMessageWidgetCopiedToClipboard;
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: copiedMessage,
      type: NotificationType.success,
    );
  }
}
