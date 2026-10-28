import '../../side_panel/desktop_side_panel_controller.dart';
import '../../side_panel/widgets/desktop_side_panel.dart';
import '../../../desktop/sidebar_resize_handle.dart';
import '../../../desktop/widgets/desktop_pane_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'dart:ui' as ui;

import '../../../desktop/macos_window_drag_area.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/side_drawer.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../shared/animations/widgets.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/brand_assets.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../desktop/hotkeys/sidebar_tab_bus.dart';
import '../../chat/widgets/frosted/chat_frosted_backdrop.dart';
import '../widgets/assistant_avatar.dart';
import '../widgets/assistant_entry_actions.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

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
    required this.embeddedSidebarWidth,
    required this.sidebarMinWidth,
    required this.sidebarMaxWidth,
    // Callbacks
    required this.onToggleSidebar,
    required this.onSelectConversation,
    required this.onNewConversation,
    required this.onCreateNewConversation,
    required this.onToggleTemporaryConversation,
    required this.onSelectModel,
    required this.canToggleTemporaryConversation,
    required this.temporaryConversationEnabled,
    required this.globalSearchMode,
    required this.globalSearchQuery,
    required this.onGlobalSearchQueryChanged,
    required this.onOpenGlobalSearchResult,
    required this.onSidebarWidthChanged,
    required this.onSidebarWidthChangeEnd,
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
  final double embeddedSidebarWidth;
  final double sidebarMinWidth;
  final double sidebarMaxWidth;

  // Callbacks
  final VoidCallback onToggleSidebar;
  final void Function(String id) onSelectConversation;
  final VoidCallback onNewConversation;
  final Future<void> Function() onCreateNewConversation;
  final Future<void> Function() onToggleTemporaryConversation;
  final VoidCallback onSelectModel;
  final bool canToggleTemporaryConversation;
  final bool temporaryConversationEnabled;
  final bool globalSearchMode;
  final String globalSearchQuery;
  final ValueChanged<String> onGlobalSearchQueryChanged;
  final Future<void> Function(
    String conversationId,
    String messageId,
    String? surfaceKey,
  )
  onOpenGlobalSearchResult;
  final void Function(double dx) onSidebarWidthChanged;
  final VoidCallback onSidebarWidthChangeEnd;
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
    final chat = Scaffold(
      key: scaffoldKey,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: appBarOverride ?? _buildAppBar(context, cs, topicsOnRight),
      body: body,
    );
    final layout = Builder(
      builder: (context) {
        final wallpaper =
            ChatFrostedBackdropScope.maybeOf(context)?.backgroundActive ??
            false;
        final chatSurface = ColoredBox(
          color: cs.surface.withValues(alpha: wallpaper ? .12 : 1),
          child: chat,
        );
        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  _buildLeftSidebar(context, cs, topicsOnRight),
                  if (!_isDesktop) SizedBox(width: tabletSidebarOpen ? .6 : 0),
                  Expanded(
                    child: _isDesktop
                        ? DesktopSidePanel(
                            conversationId: context
                                .select<ChatService, String?>(
                                  (chat) => chat.currentConversationId,
                                ),
                            topicsOnRight: topicsOnRight,
                            topicsBuilder: (context, width) =>
                                _buildTopics(context, width),
                            child: chatSurface,
                          )
                        : chat,
                  ),
                ],
              ),
              if (_isDesktop)
                AnimatedPositioned(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : _sidebarAnimDuration,
                  curve: _sidebarAnimCurve,
                  left: (tabletSidebarOpen ? embeddedSidebarWidth : 0) - 4.5,
                  top: 0,
                  bottom: 0,
                  width: 9,
                  child: SidebarResizeHandle(
                    key: const ValueKey('desktopLeftResizeHandle'),
                    visible: tabletSidebarOpen,
                    hitWidth: 9,
                    onDrag: onSidebarWidthChanged,
                    onDragEnd: onSidebarWidthChangeEnd,
                  ),
                ),
            ],
          ),
        );
      },
    );
    // DesktopHomePage owns the single wallpaper shared with the navigation
    // rail. Standalone/tablet hosts still supply their own backdrop.
    if (_isDesktop && ChatFrostedBackdropScope.maybeOf(context) != null) {
      return layout;
    }
    return ChatFrostedBackdrop(
      backdrop: buildAssistantBackground(context),
      child: layout,
    );
  }

  Widget _buildLeftSidebar(
    BuildContext context,
    ColorScheme cs,
    bool topicsOnRight,
  ) {
    final sidebar = SideDrawer(
      embedded: true,
      embeddedWidth: embeddedSidebarWidth,
      userName: context.watch<UserProvider>().name,
      assistantName: _getAssistantName(context),
      closePickerTicker: assistantPickerCloseTick,
      loadingConversationIds: loadingConversationIds,
      useDesktopTabs: _isDesktop && !topicsOnRight,
      desktopAssistantsOnly: _isDesktop && topicsOnRight,
      globalSearchMode: globalSearchMode,
      globalSearchQuery: globalSearchQuery,
      onGlobalSearchQueryChanged: onGlobalSearchQueryChanged,
      onEnterGlobalSearch: () {
        ChatActionBus.instance.fire(ChatAction.enterGlobalSearch);
      },
      onExitGlobalSearch: () {
        ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
      },
      onOpenGlobalSearchResult: onOpenGlobalSearchResult,
      onNewConversation: ({closeDrawer = true}) => onNewConversation(),
      onSelectConversation: (id, {closeDrawer = true}) =>
          onSelectConversation(id),
    );

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _sidebarAnimDuration,
      curve: _sidebarAnimCurve,
      width: tabletSidebarOpen ? embeddedSidebarWidth : 0,
      color: Colors.transparent,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: embeddedSidebarWidth,
          child: SizedBox(
            width: embeddedSidebarWidth,
            child: _isDesktop ? DesktopPaneSurface(child: sidebar) : sidebar,
          ),
        ),
      ),
    );
  }

  Widget _buildTopics(BuildContext context, double width) => SideDrawer(
    embedded: true,
    embeddedWidth: width,
    userName: context.watch<UserProvider>().name,
    assistantName: _getAssistantName(context),
    closePickerTicker: assistantPickerCloseTick,
    loadingConversationIds: loadingConversationIds,
    useDesktopTabs: false,
    desktopTopicsOnly: true,
    globalSearchMode: false,
    globalSearchQuery: '',
    onGlobalSearchQueryChanged: (_) {},
    onEnterGlobalSearch: () {},
    onExitGlobalSearch: () {},
    onOpenGlobalSearchResult: (_, _, _) async {},
    onSelectConversation: (id, {closeDrawer = true}) =>
        onSelectConversation(id),
    onNewConversation: ({closeDrawer = true}) => onNewConversation(),
  );

  String _getAssistantName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final a = context.watch<AssistantProvider>().currentAssistant;
    final n = a?.name.trim();
    return (n == null || n.isEmpty) ? l10n.homePageDefaultAssistant : n;
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme cs,
    bool topicsOnRight,
  ) {
    return AppBar(
      flexibleSpace: const MacosWindowDragArea(child: SizedBox.expand()),
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
    final useNewAssistantAvatarUx = context
        .watch<SettingsProvider>()
        .useNewAssistantAvatarUx;
    final currentAssistant = context
        .watch<AssistantProvider>()
        .currentAssistant;
    final String? brandAsset =
        (modelDisplay != null
            ? BrandAssets.assetForName(modelDisplay!)
            : null) ??
        (providerName != null ? BrandAssets.assetForName(providerName!) : null);

    Widget? capsule;
    String? capsuleLabel;

    if (providerName != null && modelDisplay != null) {
      final showProv = context
          .watch<SettingsProvider>()
          .showProviderInModelCapsule;
      capsuleLabel = showProv
          ? '$modelDisplay | $providerName'
          : '$modelDisplay';

      final Widget brandIcon = AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: (brandAsset != null)
            ? (brandAsset.endsWith('.svg')
                  ? SvgPicture.asset(
                      brandAsset,
                      width: 16,
                      height: 16,
                      key: ValueKey('brand:$brandAsset'),
                      colorFilter:
                          isDark && BrandAssets.assetNeedsDarkInvert(brandAsset)
                          ? ColorFilter.mode(cs.onSurface, BlendMode.srcIn)
                          : null,
                    )
                  : Image.asset(
                      brandAsset,
                      width: 16,
                      height: 16,
                      key: ValueKey('brand:$brandAsset'),
                    ))
            : Icon(
                Lucide.Boxes,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.7),
                key: const ValueKey('brand:default'),
              ),
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                brandIcon,
                const SizedBox(width: 6),
                Flexible(
                  child: AnimatedTextSwap(
                    text: capsuleLabel,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      color: cs.onSurface.withValues(
                        alpha: isDark ? 0.92 : 0.9,
                      ),
                      fontWeight: AppFontWeights.medium,
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
        if (useNewAssistantAvatarUx) ...[
          _buildAssistantTitleAvatar(
            context,
            assistant: currentAssistant,
            fallbackName: _getAssistantName(context),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          fit: FlexFit.loose,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedTextSwap(
              text: title,
              style: TextStyle(fontSize: 16, fontWeight: AppFontWeights.medium),
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
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('cap:${capsuleLabel ?? ''}'),
                  child: capsule,
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
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey('hdr:$title|${capsuleLabel ?? ''}'),
          child: row,
        ),
      ),
    );
  }

  Widget _buildAssistantTitleAvatar(
    BuildContext context, {
    required Assistant? assistant,
    required String fallbackName,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: !_isDesktop || assistant == null
          ? null
          : (details) {
              AssistantEntryActions.showAssistantItemMenu(
                context: context,
                assistant: assistant,
                globalPosition: details.globalPosition,
              );
            },
      child: IosCardPress(
        borderRadius: BorderRadius.circular(999),
        baseColor: Colors.transparent,
        padding: const EdgeInsets.all(2),
        onTap: _isDesktop
            ? () => _revealAssistantTopics(context)
            : onToggleSidebar,
        onLongPress: !_isDesktop && assistant != null
            ? () {
                AssistantEntryActions.openAssistantSettings(
                  context,
                  assistant.id,
                );
              }
            : null,
        child: AssistantAvatar(
          assistant: assistant,
          fallbackName: fallbackName,
          size: 28,
        ),
      ),
    );
  }

  void _revealAssistantTopics(BuildContext context) {
    final topicsOnRight =
        context.read<SettingsProvider>().desktopTopicPosition ==
        DesktopTopicPosition.right;
    if (topicsOnRight) {
      DesktopSidePanelController.instance.open(kind: SidePanelTabKind.topics);
      return;
    }
    if (!tabletSidebarOpen) {
      onToggleSidebar();
    }
    DesktopSidebarTabBus.instance.switchToTopics();
  }

  List<Widget> _buildActions(BuildContext context, bool topicsOnRight) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (_isDesktop)
        ListenableBuilder(
          listenable: DesktopSidePanelController.instance,
          builder: (context, _) => Tooltip(
            message: l10n.sidePanelToggle,
            child: Container(
              decoration: BoxDecoration(
                color: DesktopSidePanelController.instance.isOpen
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .10)
                    : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IosIconButton(
                size: 20,
                padding: const EdgeInsets.all(8),
                minSize: 40,
                icon: Lucide.panelRight,
                color: DesktopSidePanelController.instance.isOpen
                    ? Theme.of(context).colorScheme.primary
                    : null,
                semanticLabel: l10n.sidePanelToggle,
                onTap: DesktopSidePanelController.instance.toggle,
              ),
            ),
          ),
        ),
      const SizedBox(width: 2),
      IosIconButton(
        size: 20,
        padding: const EdgeInsets.all(8),
        minSize: 40,
        semanticLabel: canToggleTemporaryConversation
            ? AppLocalizations.of(context)!.temporaryChatToggleTooltip
            : AppLocalizations.of(context)!.titleForLocale,
        icon: canToggleTemporaryConversation && !temporaryConversationEnabled
            ? Lucide.MessageCircleDashed
            : Lucide.MessageCirclePlus,
        builder: canToggleTemporaryConversation && temporaryConversationEnabled
            ? (color) => SvgPicture.asset(
                'assets/icons/temporary_chat_checked.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              )
            : null,
        onTap: () async {
          if (canToggleTemporaryConversation) {
            await onToggleTemporaryConversation();
          } else {
            await onCreateNewConversation();
          }
        },
      ),

      const SizedBox(width: 6),
    ];
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
        bg = Image.network(
          bgRaw,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
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
                  cs.surface.withValues(alpha: 0.08),
                  cs.surface.withValues(alpha: 0.36),
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
        // Scroll to previous message button
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
                    padding: EdgeInsets.only(
                      right: 16,
                      bottom: bottomOffset + 52,
                    ),
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
    final cs = Theme.of(context).colorScheme;
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.onSurface.withValues(alpha: 0.06)
                : cs.surface.withValues(alpha: 0.07),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? cs.onSurface.withValues(alpha: 0.10)
                  : cs.outline.withValues(alpha: 0.20),
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
                  color: cs.onSurface.withValues(alpha: isDark ? 1.0 : 0.87),
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
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  State<_DesktopGlassCircleButton> createState() =>
      _DesktopGlassCircleButtonState();
}

class _DesktopGlassCircleButtonState extends State<_DesktopGlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = cs.surface.withValues(alpha: 0.06);
    final overlay = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05);
    final tileColor = _pressed
        ? Color.alphaBlend(overlay, glassBase)
        : glassBase;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.10);

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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tileColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: Center(
                  child: Icon(widget.icon, size: 18, color: widget.color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
