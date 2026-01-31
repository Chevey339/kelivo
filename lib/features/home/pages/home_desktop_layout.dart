import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'dart:ui' as ui;

import '../../../l10n/app_localizations.dart';
import '../widgets/side_drawer.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../shared/animations/widgets.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/brand_assets.dart';
import '../../../utils/sandbox_path_resolver.dart';

/// Desktop/Tablet layout scaffold for the home page
/// Handles the overall structure: left sidebar, main content, optional right sidebar
/// All message list rendering and input bar logic remain in home_page.dart
class HomeDesktopScaffold extends StatelessWidget {
  const HomeDesktopScaffold({
    super.key,
    required this.scaffoldKey,
    required this.assistantPickerCloseTick,
    required this.loadingConversationIds,
    required this.title,
    required this.providerName,
    required this.modelDisplay,
    // Sidebar state
    required this.tabletSidebarOpen,
    required this.rightSidebarOpen,
    required this.embeddedSidebarWidth,
    required this.rightSidebarWidth,
    required this.sidebarMinWidth,
    required this.sidebarMaxWidth,
    // Callbacks
    required this.onToggleSidebar,
    required this.onToggleRightSidebar,
    required this.onSelectConversation,
    required this.onNewConversation,
    required this.onCreateNewConversation,
    required this.onSelectModel,
    required this.onSidebarWidthChanged,
    required this.onSidebarWidthChangeEnd,
    required this.onRightSidebarWidthChanged,
    required this.onRightSidebarWidthChangeEnd,
    required this.buildAssistantBackground,
    this.appBarOverride,
    required this.body,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final ValueNotifier<int> assistantPickerCloseTick;
  final Set<String> loadingConversationIds;
  final String title;
  final String? providerName;
  final String? modelDisplay;

  // Sidebar state
  final bool tabletSidebarOpen;
  final bool rightSidebarOpen;
  final double embeddedSidebarWidth;
  final double rightSidebarWidth;
  final double sidebarMinWidth;
  final double sidebarMaxWidth;

  // Callbacks
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleRightSidebar;
  final void Function(String id) onSelectConversation;
  final VoidCallback onNewConversation;
  final Future<void> Function() onCreateNewConversation;
  final VoidCallback onSelectModel;
  final void Function(double dx) onSidebarWidthChanged;
  final VoidCallback onSidebarWidthChangeEnd;
  final void Function(double dx) onRightSidebarWidthChanged;
  final VoidCallback onRightSidebarWidthChangeEnd;
  final Widget Function(BuildContext context) buildAssistantBackground;
  final PreferredSizeWidget? appBarOverride;
  final Widget body;

  static const Duration _sidebarAnimDuration = Duration(milliseconds: 260);
  static const Curve _sidebarAnimCurve = Curves.easeOutCubic;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final topicsOnRight = sp.desktopTopicPosition == DesktopTopicPosition.right;

    return Stack(
      children: [
        Positioned.fill(child: buildAssistantBackground(context)),
        SizedBox.expand(
          child: Row(
            children: [
              // Left sidebar
              _buildLeftSidebar(context, cs, topicsOnRight),
              // Left sidebar resize handle / divider
              if (_isDesktop)
                SidebarResizeHandle(
                  visible: tabletSidebarOpen,
                  onDrag: onSidebarWidthChanged,
                  onDragEnd: onSidebarWidthChangeEnd,
                )
              else
                AnimatedContainer(
                  duration: _sidebarAnimDuration,
                  curve: _sidebarAnimCurve,
                  width: tabletSidebarOpen ? 0.6 : 0,
                  child: tabletSidebarOpen
                      ? VerticalDivider(
                          width: 0.6,
                          thickness: 0.5,
                          color: cs.outlineVariant.withOpacity(0.20),
                        )
                      : const SizedBox.shrink(),
                ),
              // Main content
              Expanded(
                child: Scaffold(
                  key: scaffoldKey,
                  resizeToAvoidBottomInset: true,
                  extendBodyBehindAppBar: true,
                  backgroundColor: Colors.transparent,
                  appBar: appBarOverride ?? _buildAppBar(context, cs, topicsOnRight),
                  body: body,
                ),
              ),
              // Right sidebar (desktop only with topics on right)
              _buildRightSidebar(context, cs, topicsOnRight),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeftSidebar(BuildContext context, ColorScheme cs, bool topicsOnRight) {
    final sidebar = SideDrawer(
      embedded: true,
      embeddedWidth: embeddedSidebarWidth,
      userName: context.watch<UserProvider>().name,
      assistantName: _getAssistantName(context),
      closePickerTicker: assistantPickerCloseTick,
      loadingConversationIds: loadingConversationIds,
      useDesktopTabs: _isDesktop && !topicsOnRight,
      desktopAssistantsOnly: _isDesktop && topicsOnRight,
      onNewConversation: ({closeDrawer = true}) => onNewConversation(),
      onSelectConversation: (id, {closeDrawer = true}) => onSelectConversation(id),
    );

    return AnimatedContainer(
      duration: _sidebarAnimDuration,
      curve: _sidebarAnimCurve,
      width: tabletSidebarOpen ? embeddedSidebarWidth : 0,
      color: Colors.transparent,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: embeddedSidebarWidth,
          child: SizedBox(width: embeddedSidebarWidth, child: sidebar),
        ),
      ),
    );
  }

  Widget _buildRightSidebar(BuildContext context, ColorScheme cs, bool topicsOnRight) {
    if (!_isDesktop || !topicsOnRight) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SidebarResizeHandle(
          visible: rightSidebarOpen,
          onDrag: onRightSidebarWidthChanged,
          onDragEnd: onRightSidebarWidthChangeEnd,
        ),
        AnimatedContainer(
          duration: _sidebarAnimDuration,
          curve: _sidebarAnimCurve,
          width: rightSidebarOpen ? rightSidebarWidth : 0,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerRight,
              minWidth: 0,
              maxWidth: rightSidebarWidth,
              child: SizedBox(
                width: rightSidebarWidth,
                child: SideDrawer(
                  embedded: true,
                  embeddedWidth: rightSidebarWidth,
                  userName: context.watch<UserProvider>().name,
                  assistantName: _getAssistantName(context),
                  closePickerTicker: assistantPickerCloseTick,
                  loadingConversationIds: loadingConversationIds,
                  useDesktopTabs: false,
                  desktopTopicsOnly: true,
                  onSelectConversation: (id, {closeDrawer = true}) => onSelectConversation(id),
                  onNewConversation: ({closeDrawer = true}) => onNewConversation(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getAssistantName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final a = context.watch<AssistantProvider>().currentAssistant;
    final n = a?.name.trim();
    return (n == null || n.isEmpty) ? l10n.homePageDefaultAssistant : n;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme cs, bool topicsOnRight) {
    return AppBar(
      centerTitle: false,
      systemOverlayStyle: (Theme.of(context).brightness == Brightness.dark)
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IosIconButton(
        size: 20,
        padding: const EdgeInsets.all(8),
        minSize: 40,
        builder: (color) => SvgPicture.asset(
          'assets/icons/list.svg',
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        onTap: onToggleSidebar,
      ),
      titleSpacing: 2,
      title: _buildTitle(context, cs),
      actions: _buildActions(context, topicsOnRight),
    );
  }

  Widget _buildTitle(BuildContext context, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String? brandAsset = (modelDisplay != null
            ? BrandAssets.assetForName(modelDisplay!)
            : null) ??
        (providerName != null ? BrandAssets.assetForName(providerName!) : null);

    Widget? capsule;
    String? capsuleLabel;

    if (providerName != null && modelDisplay != null) {
      final showProv = context.watch<SettingsProvider>().showProviderInModelCapsule;
      capsuleLabel = showProv ? '$modelDisplay | $providerName' : '$modelDisplay';

      final Widget brandIcon = AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: (brandAsset != null)
            ? (brandAsset.endsWith('.svg')
                ? SvgPicture.asset(brandAsset, width: 16, height: 16, key: ValueKey('brand:$brandAsset'))
                : Image.asset(brandAsset, width: 16, height: 16, key: ValueKey('brand:$brandAsset')))
            : Icon(Lucide.Boxes, size: 16, color: cs.onSurface.withOpacity(0.7), key: const ValueKey('brand:default')),
      );

      capsule = IosCardPress(
        borderRadius: BorderRadius.circular(20),
        baseColor: Colors.transparent,
        pressedBlendStrength: isDark ? 0.18 : 0.12,
        padding: EdgeInsets.zero,
        onTap: onSelectModel,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                brandIcon,
                const SizedBox(width: 6),
                Flexible(
                  child: AnimatedTextSwap(
                    text: capsuleLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      color: isDark ? Colors.white.withOpacity(0.92) : cs.onSurface.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final row = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedTextSwap(
              text: title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (capsule != null) ...[
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('cap:${capsuleLabel ?? ''}'),
                  child: capsule!,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey('hdr:$title|${capsuleLabel ?? ''}'), child: row),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, bool topicsOnRight) {
    return [
      // Right sidebar toggle (desktop + topics on right)
      if (_isDesktop && topicsOnRight)
        IosIconButton(
          size: 20,
          padding: const EdgeInsets.all(8),
          minSize: 40,
          icon: Lucide.panelRight,
          onTap: onToggleRightSidebar,
        ),
      const SizedBox(width: 2),
      IosIconButton(
        size: 20,
        padding: const EdgeInsets.all(8),
        minSize: 40,
        icon: Lucide.MessageCirclePlus,
        onTap: () async {
          await onCreateNewConversation();
        },
      ),
      const SizedBox(width: 6),
    ];
  }
}

/// Sidebar resize handle widget for desktop
class SidebarResizeHandle extends StatefulWidget {
  const SidebarResizeHandle({
    super.key,
    required this.visible,
    required this.onDrag,
    this.onDragEnd,
  });

  final bool visible;
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  @override
  State<SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<SidebarResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!widget.visible) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
      onHorizontalDragEnd: (_) => widget.onDragEnd?.call(),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          width: 6,
          height: double.infinity,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            height: double.infinity,
            color: _hovered ? cs.primary.withOpacity(0.28) : cs.outlineVariant.withOpacity(0.10),
          ),
        ),
      ),
    );
  }
}

/// Desktop background widget with assistant-specific image
class DesktopBackgroundLayer extends StatelessWidget {
  const DesktopBackgroundLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    final bgRaw = (assistant?.background ?? '').trim();

    Widget? bg;
    if (bgRaw.isNotEmpty) {
      if (bgRaw.startsWith('http')) {
        bg = Image.network(bgRaw, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
      } else {
        try {
          final fixed = SandboxPathResolver.fix(bgRaw);
          final f = File(fixed);
          if (f.existsSync()) {
            bg = Image(image: FileImage(f), fit: BoxFit.cover);
          }
        } catch (_) {}
      }
    }

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: cs.surface),
          if (bg != null) Opacity(opacity: 0.9, child: bg),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface.withOpacity(0.08),
                  cs.surface.withOpacity(0.36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scroll navigation buttons for desktop (same as mobile but with different padding)
class DesktopScrollNavigationButtons extends StatelessWidget {
  const DesktopScrollNavigationButtons({
    super.key,
    required this.showJumpToBottom,
    required this.inputBarHeight,
    required this.hasMessages,
    required this.onScrollToBottom,
    required this.onScrollToPreviousQuestion,
  });

  final bool showJumpToBottom;
  final double inputBarHeight;
  final bool hasMessages;
  final VoidCallback onScrollToBottom;
  final VoidCallback onScrollToPreviousQuestion;

  @override
  Widget build(BuildContext context) {
    final showSetting = context.watch<SettingsProvider>().showMessageNavButtons;
    if (!showSetting || !hasMessages) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomOffset = inputBarHeight + 12;

    return Stack(
      children: [
        // Scroll to bottom button
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            top: false,
            bottom: false,
            child: IgnorePointer(
              ignoring: !showJumpToBottom,
              child: AnimatedScale(
                scale: showJumpToBottom ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: showJumpToBottom ? 1 : 0,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: bottomOffset),
                    child: _DesktopScrollButton(
                      isDark: isDark,
                      icon: Lucide.ChevronDown,
                      onTap: onScrollToBottom,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Scroll to previous question button
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            top: false,
            bottom: false,
            child: IgnorePointer(
              ignoring: !showJumpToBottom,
              child: AnimatedScale(
                scale: showJumpToBottom ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: showJumpToBottom ? 1 : 0,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: bottomOffset + 52),
                    child: _DesktopScrollButton(
                      isDark: isDark,
                      icon: Lucide.ChevronUp,
                      onTap: onScrollToPreviousQuestion,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopScrollButton extends StatelessWidget {
  const _DesktopScrollButton({
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.07),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.20),
              width: 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection mode toolbar overlay for desktop
class DesktopSelectionToolbarOverlay extends StatelessWidget {
  const DesktopSelectionToolbarOverlay({
    super.key,
    required this.visible,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool visible;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 122),
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !visible,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DesktopGlassCircleButton(
                      icon: Lucide.X,
                      color: cs.onSurface,
                      onTap: onCancel,
                      semanticLabel: l10n.homePageCancel,
                    ),
                    const SizedBox(width: 14),
                    _DesktopGlassCircleButton(
                      icon: Lucide.Check,
                      color: cs.primary,
                      onTap: onConfirm,
                      semanticLabel: l10n.homePageDone,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopGlassCircleButton extends StatefulWidget {
  const _DesktopGlassCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double size;

  @override
  State<_DesktopGlassCircleButton> createState() => _DesktopGlassCircleButtonState();
}

class _DesktopGlassCircleButtonState extends State<_DesktopGlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06);
    final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final tileColor = _pressed ? Color.alphaBlend(overlay, glassBase) : glassBase;
    final borderColor = cs.outlineVariant.withOpacity(0.10);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: tileColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: Center(child: Icon(widget.icon, size: 18, color: widget.color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
