import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../../../core/services/android_background.dart';
import '../../../core/services/notification_service.dart';
import '../../../icons/lucide_adapter.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../../../core/providers/settings_provider.dart';
import 'theme_settings_page.dart';
import '../../../theme/palettes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../core/services/haptics.dart';
import 'package:file_picker/file_picker.dart';
import 'google_fonts_picker_page.dart';

enum _FontTarget { app, code }

class DisplaySettingsPage extends StatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  State<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends State<DisplaySettingsPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    context.watch<SettingsProvider>();

    String _paletteName() {
      final settings = context.read<SettingsProvider>();
      final palette = ThemePalettes.byId(settings.themePaletteId);
      return Localizations.localeOf(context).languageCode == 'zh' ? palette.displayNameZh : palette.displayNameEn;
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
          child: Text(
            text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.8)),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.settingsPageDisplay),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // header(l10n.displaySettingsPageThemeSettingsTitle),
          _iosSectionCard(children: [
            _iosNavRow(
              context,
              icon: Lucide.Palette,
              label: l10n.displaySettingsPageThemeSettingsTitle,
              detailText: _paletteName(),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemeSettingsPage())),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Languages,
              label: l10n.displaySettingsPageLanguageTitle,
              detailBuilder: (ctx) {
                final settings = ctx.watch<SettingsProvider>();
                String labelFor(Locale l) {
                  if (l.languageCode == 'zh') {
                    if ((l.scriptCode ?? '').toLowerCase() == 'hant') return l10n.languageDisplayTraditionalChinese;
                    return l10n.displaySettingsPageLanguageChineseLabel;
                  }
                  return l10n.displaySettingsPageLanguageEnglishLabel;
                }
                return Text(
                  settings.isFollowingSystemLocale ? l10n.settingsPageSystemMode : labelFor(settings.appLocale),
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                );
              },
              onTap: () async {
                await _showLanguageSheet(context);
                if (mounted) setState(() {});
              },
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.MessageCircleMore,
              label: l10n.displaySettingsPageChatItemDisplayTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatItemDisplaySettingsPage())),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.TextInitial,
              label: l10n.displaySettingsPageRenderingSettingsTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RenderingSettingsPage())),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.eclipse,
              label: l10n.displaySettingsPageBehaviorStartupTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BehaviorStartupSettingsPage())),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Vibrate,
              label: l10n.displaySettingsPageHapticsSettingsTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HapticsSettingsPage())),
            ),
            _iosDivider(context),
            if (Platform.isAndroid) _iosNavRow(
              context,
              icon: Lucide.Monitor,
              label: l10n.displaySettingsPageAndroidBackgroundChatTitle,
              detailBuilder: (ctx) {
                final sp = ctx.watch<SettingsProvider>();
                switch (sp.androidBackgroundChatMode) {
                  case AndroidBackgroundChatMode.off:
                    return Text(
                      l10n.androidBackgroundStatusOff,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                    );
                  case AndroidBackgroundChatMode.on:
                    return Text(
                      l10n.androidBackgroundStatusOn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                    );
                  case AndroidBackgroundChatMode.onNotify:
                    return Text(
                      l10n.androidBackgroundStatusOther,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                    );
                }
              },
              onTap: () => _showAndroidBackgroundChatSheet(context),
            ),
            if (Platform.isAndroid) _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.MessageSquare,
              label: l10n.displaySettingsPageChatMessageBackgroundTitle,
              detailBuilder: (ctx) {
                final sp = ctx.watch<SettingsProvider>();
                String labelOf() {
                  switch (sp.chatMessageBackgroundStyle) {
                    case ChatMessageBackgroundStyle.frosted:
                      return l10n.displaySettingsPageChatMessageBackgroundFrosted;
                    case ChatMessageBackgroundStyle.solid:
                      return l10n.displaySettingsPageChatMessageBackgroundSolid;
                    case ChatMessageBackgroundStyle.defaultStyle:
                    default:
                      return l10n.displaySettingsPageChatMessageBackgroundDefault;
                  }
                }
                return Text(
                  labelOf(),
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                );
              },
              onTap: () => _showChatMessageBackgroundSheet(context),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Type,
              label: l10n.displaySettingsPageAppFontTitle,
              detailBuilder: (ctx) {
                final sp = ctx.watch<SettingsProvider>();
                final fam = sp.appFontFamily;
                final useLocal = (sp.appFontLocalAlias ?? '').isNotEmpty;
                final text = useLocal
                    ? l10n.displaySettingsPageFontLocalFileLabel
                    : (fam == null || fam.isEmpty)
                        ? l10n.desktopFontFamilySystemDefault
                        : fam;
                return Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                );
              },
              onTap: () => _showMobileFontSourceSheet(context, target: _FontTarget.app),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Code,
              label: l10n.displaySettingsPageCodeFontTitle,
              detailBuilder: (ctx) {
                final sp = ctx.watch<SettingsProvider>();
                final fam = sp.codeFontFamily;
                final useLocal = (sp.codeFontLocalAlias ?? '').isNotEmpty;
                final text = useLocal
                    ? l10n.displaySettingsPageFontLocalFileLabel
                    : (fam == null || fam.isEmpty)
                        ? l10n.desktopFontFamilyMonospaceDefault
                        : fam;
                return Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                );
              },
              onTap: () => _showMobileFontSourceSheet(context, target: _FontTarget.code),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.CaseSensitive,
              label: l10n.displaySettingsPageChatFontSizeTitle,
              detailBuilder: (ctx) {
                final scale = ctx.watch<SettingsProvider>().chatFontScale;
                return Text('${(scale * 100).round()}%', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13));
              },
              onTap: () => _showChatFontSizeSheet(context),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.ArrowDown,
              label: l10n.displaySettingsPageAutoScrollIdleTitle,
              detailBuilder: (ctx) {
                final sp = ctx.watch<SettingsProvider>();
                if (!sp.autoScrollEnabled) {
                  return Text(
                    l10n.displaySettingsPageAutoScrollDisabledLabel,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 13),
                  );
                }
                final seconds = sp.autoScrollIdleSeconds;
                return Text('${seconds.round()}s', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13));
              },
              onTap: () => _showAutoScrollIdleSheet(context),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Image,
              label: l10n.displaySettingsPageChatBackgroundMaskTitle,
              detailBuilder: (ctx) {
                final v = ctx.watch<SettingsProvider>().chatBackgroundMaskStrength;
                return Text('${(v * 100).round()}%', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13));
              },
              onTap: () => _showChatBackgroundMaskSheet(context),
            ),
          ]),
          // Inline cards replaced by sheet-triggering rows above.
        ],
      ),
    );
  }

  Future<void> _showMobileFontSourceSheet(BuildContext context, {required _FontTarget target}) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetOption(ctx, label: l10n.fontPickerChooseLocalFile, onTap: () => Navigator.of(ctx).pop('local')),
              _sheetDividerNoIcon(ctx),
              _sheetOption(ctx, label: l10n.fontPickerGetFromGoogleFonts, onTap: () => Navigator.of(ctx).pop('google')),
              _sheetDividerNoIcon(ctx),
              _sheetOption(ctx, label: l10n.displaySettingsPageFontResetLabel, onTap: () => Navigator.of(ctx).pop('reset')),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'local') {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['ttf', 'otf']);
      final path = res?.files.singleOrNull?.path;
      if (path == null) return;
      if (target == _FontTarget.app) {
        await context.read<SettingsProvider>().setAppFontFromLocal(path: path);
      } else {
        await context.read<SettingsProvider>().setCodeFontFromLocal(path: path);
      }
      return;
    }
    if (choice == 'google') {
      final title = target == _FontTarget.app ? l10n.displaySettingsPageAppFontTitle : l10n.displaySettingsPageCodeFontTitle;
      final selected = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => GoogleFontsPickerPage(title: title)));
      if (selected == null || selected.isEmpty) return;
      if (target == _FontTarget.app) {
        await context.read<SettingsProvider>().setAppFontFromGoogle(selected);
      } else {
        await context.read<SettingsProvider>().setCodeFontFromGoogle(selected);
      }
      return;
    }
    if (choice == 'reset') {
      if (target == _FontTarget.app) {
        await context.read<SettingsProvider>().clearAppFont();
      } else {
        await context.read<SettingsProvider>().clearCodeFont();
      }
    }
  }

  Future<void> _showChatMessageBackgroundSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetOption(ctx, label: l10n.displaySettingsPageChatMessageBackgroundDefault, onTap: () => Navigator.of(ctx).pop('default')),
              _sheetDividerNoIcon(ctx),
              _sheetOption(ctx, label: l10n.displaySettingsPageChatMessageBackgroundFrosted, onTap: () => Navigator.of(ctx).pop('frosted')),
              _sheetDividerNoIcon(ctx),
              _sheetOption(ctx, label: l10n.displaySettingsPageChatMessageBackgroundSolid, onTap: () => Navigator.of(ctx).pop('solid')),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    final sp = context.read<SettingsProvider>();
    switch (choice) {
      case 'frosted':
        await sp.setChatMessageBackgroundStyle(ChatMessageBackgroundStyle.frosted);
        break;
      case 'solid':
        await sp.setChatMessageBackgroundStyle(ChatMessageBackgroundStyle.solid);
        break;
      default:
        await sp.setChatMessageBackgroundStyle(ChatMessageBackgroundStyle.defaultStyle);
    }
  }

  Future<void> _showAndroidBackgroundChatSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetOption(ctx, label: l10n.androidBackgroundOptionOn, onTap: () => Navigator.of(ctx).pop('on')),
              _sheetDividerNoIcon(ctx),
              _sheetOption(ctx, label: l10n.androidBackgroundOptionOnNotify, onTap: () => Navigator.of(ctx).pop('on_notify')),
              _sheetDividerNoIcon(ctx),
              _sheetOption(ctx, label: l10n.androidBackgroundOptionOff, onTap: () => Navigator.of(ctx).pop('off')),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    final sp = context.read<SettingsProvider>();
    switch (choice) {
      case 'on_notify':
        await sp.setAndroidBackgroundChatMode(AndroidBackgroundChatMode.onNotify);
        try {
          await AndroidBackgroundManager.ensureInitialized(
            notificationTitle: AppLocalizations.of(context)!.androidBackgroundNotificationTitle,
            notificationText: AppLocalizations.of(context)!.androidBackgroundNotificationText,
          );
          await AndroidBackgroundManager.setEnabled(true);
          await NotificationService.ensureInitialized();
          await NotificationService.ensureAndroidNotificationsPermission();
        } catch (_) {}
        break;
      case 'on':
        await sp.setAndroidBackgroundChatMode(AndroidBackgroundChatMode.on);
        try {
          await AndroidBackgroundManager.ensureInitialized(
            notificationTitle: AppLocalizations.of(context)!.androidBackgroundNotificationTitle,
            notificationText: AppLocalizations.of(context)!.androidBackgroundNotificationText,
          );
          await AndroidBackgroundManager.setEnabled(true);
          // Prepare notification channel as well to avoid FGS notification issues on some ROMs
          await NotificationService.ensureInitialized();
        } catch (_) {}
        break;
      default:
        await sp.setAndroidBackgroundChatMode(AndroidBackgroundChatMode.off);
        try { await AndroidBackgroundManager.setEnabled(false); } catch (_) {}
    }
  }


  Future<void> _showLanguageSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetOption(ctx, label: l10n.settingsPageSystemMode, onTap: () => Navigator.of(ctx).pop('system')),
                _sheetDividerNoIcon(ctx),
                _sheetOption(ctx, label: l10n.displaySettingsPageLanguageChineseLabel, onTap: () => Navigator.of(ctx).pop('zh_CN')),
                _sheetDividerNoIcon(ctx),
                _sheetOption(ctx, label: l10n.languageDisplayTraditionalChinese, onTap: () => Navigator.of(ctx).pop('zh_Hant')),
                _sheetDividerNoIcon(ctx),
                _sheetOption(ctx, label: l10n.displaySettingsPageLanguageEnglishLabel, onTap: () => Navigator.of(ctx).pop('en_US')),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    switch (selected) {
      case 'system':
        await context.read<SettingsProvider>().setAppLocaleFollowSystem();
        break;
      case 'zh_CN':
        await context.read<SettingsProvider>().setAppLocale(const Locale('zh', 'CN'));
        break;
      case 'zh_Hant':
        await context.read<SettingsProvider>().setAppLocale(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
        break;
      case 'en_US':
      default:
        await context.read<SettingsProvider>().setAppLocale(const Locale('en', 'US'));
    }
  }

  Future<void> _showChatFontSizeSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Builder(builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final scale = context.watch<SettingsProvider>().chatFontScale;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('50%', style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SfSliderTheme(
                        data: SfSliderThemeData(
                          activeTrackHeight: 8,
                          inactiveTrackHeight: 8,
                          overlayRadius: 14,
                          activeTrackColor: cs.primary,
                          inactiveTrackColor: cs.onSurface.withOpacity(isDark ? 0.25 : 0.20),
                          tooltipBackgroundColor: cs.primary,
                          tooltipTextStyle: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
                          activeTickColor: cs.onSurface.withOpacity(isDark ? 0.45 : 0.35),
                          inactiveTickColor: cs.onSurface.withOpacity(isDark ? 0.30 : 0.25),
                          activeMinorTickColor: cs.onSurface.withOpacity(isDark ? 0.34 : 0.28),
                          inactiveMinorTickColor: cs.onSurface.withOpacity(isDark ? 0.24 : 0.20),
                        ),
                        child: SfSlider(
                          value: scale,
                          min: 0.5,
                          max: 1.50001,
                          stepSize: 0.05,
                          showTicks: true,
                          showLabels: true,
                          interval: 0.1,
                          minorTicksPerInterval: 1,
                          enableTooltip: true,
                          shouldAlwaysShowTooltip: false,
                          tooltipShape: const SfPaddleTooltipShape(),
                          labelFormatterCallback: (value, text) => (value as double).toStringAsFixed(1),
                          thumbIcon: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              boxShadow: isDark ? [] : [
                                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          onChanged: (v) => context.read<SettingsProvider>().setChatFontScale((v as double).clamp(0.5, 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(scale * 100).round()}%', style: TextStyle(color: cs.onSurface, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.displaySettingsPageChatFontSampleText,
                      style: TextStyle(fontSize: 16 * context.watch<SettingsProvider>().chatFontScale),
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _showAutoScrollIdleSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Builder(builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final sp = context.watch<SettingsProvider>();
              final seconds = sp.autoScrollIdleSeconds;
              final enabled = sp.autoScrollEnabled;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.displaySettingsPageAutoScrollEnableTitle,
                        style: TextStyle(fontSize: 15, color: cs.onSurface),
                      ),
                      const Spacer(),
                      IosSwitch(
                        value: enabled,
                        onChanged: (v) => context.read<SettingsProvider>().setAutoScrollEnabled(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('2s', style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SfSliderTheme(
                        data: SfSliderThemeData(
                          activeTrackHeight: 8,
                          inactiveTrackHeight: 8,
                          overlayRadius: 14,
                          activeTrackColor: cs.primary,
                          inactiveTrackColor: cs.onSurface.withOpacity(isDark ? 0.25 : 0.20),
                          tooltipBackgroundColor: cs.primary,
                          tooltipTextStyle: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
                          activeTickColor: cs.onSurface.withOpacity(isDark ? 0.45 : 0.35),
                          inactiveTickColor: cs.onSurface.withOpacity(isDark ? 0.30 : 0.25),
                          activeMinorTickColor: cs.onSurface.withOpacity(isDark ? 0.34 : 0.28),
                          inactiveMinorTickColor: cs.onSurface.withOpacity(isDark ? 0.24 : 0.20),
                        ),
                        child: SfSlider(
                          value: seconds.toDouble(),
                          min: 2.0,
                          max: 64.0,
                          stepSize: 2.0,
                          showTicks: true,
                          showLabels: true,
                          interval: 10.0,
                          minorTicksPerInterval: 1,
                          enableTooltip: true,
                          shouldAlwaysShowTooltip: false,
                          tooltipShape: const SfPaddleTooltipShape(),
                          labelFormatterCallback: (value, text) => value.toInt().toString(),
                          thumbIcon: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              boxShadow: isDark ? [] : [
                                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          onChanged: enabled
                              ? (v) => context.read<SettingsProvider>().setAutoScrollIdleSeconds((v as double).round())
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      enabled ? '${seconds.round()}s' : l10n.displaySettingsPageAutoScrollDisabledLabel,
                      style: TextStyle(color: cs.onSurface.withOpacity(enabled ? 1.0 : 0.5), fontSize: 12),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    l10n.displaySettingsPageAutoScrollIdleSubtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _showChatBackgroundMaskSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Builder(builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final strength = context.watch<SettingsProvider>().chatBackgroundMaskStrength;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('0%', style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SfSliderTheme(
                        data: SfSliderThemeData(
                          activeTrackHeight: 8,
                          inactiveTrackHeight: 8,
                          overlayRadius: 14,
                          activeTrackColor: cs.primary,
                          inactiveTrackColor: cs.onSurface.withOpacity(isDark ? 0.25 : 0.20),
                          tooltipBackgroundColor: cs.primary,
                          tooltipTextStyle: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
                          activeTickColor: cs.onSurface.withOpacity(isDark ? 0.45 : 0.35),
                          inactiveTickColor: cs.onSurface.withOpacity(isDark ? 0.30 : 0.25),
                          activeMinorTickColor: cs.onSurface.withOpacity(isDark ? 0.34 : 0.28),
                          inactiveMinorTickColor: cs.onSurface.withOpacity(isDark ? 0.24 : 0.20),
                        ),
                        child: SfSlider(
                          value: (strength * 100).roundToDouble(),
                          min: 0.0,
                          max: 200.0001,
                          stepSize: 5.0,
                          showTicks: true,
                          showLabels: true,
                          interval: 50,
                          minorTicksPerInterval: 1,
                          enableTooltip: true,
                          shouldAlwaysShowTooltip: false,
                          tooltipShape: const SfPaddleTooltipShape(),
                          labelFormatterCallback: (value, text) => '${(value as double).round()}%',
                          thumbIcon: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              boxShadow: isDark ? [] : [
                                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          onChanged: (v) => context.read<SettingsProvider>().setChatBackgroundMaskStrength(((v as double) / 100.0).clamp(0.0, 2.0)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(strength * 100).round()}%', style: TextStyle(color: cs.onSurface, fontSize: 12)),
                  ]),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

// --- iOS-style helpers ---

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(builder: (context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  });
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(height: 6, thickness: 0.6, indent: 54, endIndent: 12, color: cs.outlineVariant.withOpacity(0.18));
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({required this.pressed, required this.base, required this.builder});
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.haptics = true});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final bool haptics;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _setPressed(bool v) { if (_pressed != v) setState(() => _pressed = v); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null ? null : () {
        if (widget.haptics && context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
        widget.onTap!.call();
      },
      child: widget.builder(_pressed),
    );
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.onLongPress, this.semanticLabel, this.size = 22, this.haptics = true});
  final IconData icon; final Color color; final VoidCallback onTap; final VoidCallback? onLongPress; final String? semanticLabel; final double size; final bool haptics;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final pressColor = base.withOpacity(0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base, semanticLabel: widget.semanticLabel);
    return Semantics(
      button: true, label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () { if (widget.haptics) Haptics.light(); widget.onTap(); },
        onLongPress: widget.onLongPress == null ? null : () { if (widget.haptics) Haptics.light(); widget.onLongPress!.call(); },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
      ),
    );
  }
}

Widget _iosNavRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  VoidCallback? onTap,
  String? detailText,
  Widget Function(BuildContext ctx)? detailBuilder,
}) {
  final cs = Theme.of(context).colorScheme; final interactive = onTap != null;
  return _TactileRow(
    onTap: onTap, haptics: true,
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed, base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (detailBuilder != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                        child: detailBuilder(context),
                      ),
                    ),
                  ),
                )
              else if (detailText != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ),
                ),
              if (interactive) Icon(Lucide.ChevronRight, size: 16, color: c),
            ]),
          );
        },
      );
    },
  );
}

Widget _iosSwitchRow(BuildContext context, {IconData? icon, required String label, required bool value, required ValueChanged<bool> onChanged}) {
  final cs = Theme.of(context).colorScheme;
  return _TactileRow(
    onTap: () => onChanged(!value),
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed, base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(children: [
              if (icon != null) ...[
                SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
                const SizedBox(width: 12),
              ],
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c))),
              IosSwitch(value: value, onChanged: onChanged),
            ]),
          );
        },
      );
    },
  );
}

Widget _sheetOption(BuildContext context, {IconData? icon, required String label, required VoidCallback onTap}) {
  final cs = Theme.of(context).colorScheme; final isDark = Theme.of(context).brightness == Brightness.dark;
  return _TactileRow(
    onTap: onTap,
    builder: (pressed) {
      final base = cs.onSurface; final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
      final bgTarget = pressed ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: target), duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
        builder: (context, color, _) {
          final c = color ?? base;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic, color: bgTarget,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              if (icon != null) ...[
                SizedBox(width: 24, child: Icon(icon, size: 20, color: c)),
                const SizedBox(width: 12),
              ],
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c))),
            ]),
          );
        },
      );
    },
  );
}

Widget _sheetDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme; return Divider(height: 1, thickness: 0.6, indent: 52, endIndent: 16, color: cs.outlineVariant.withOpacity(0.18));
}

Widget _sheetDividerNoIcon(BuildContext context) {
  final cs = Theme.of(context).colorScheme; return Divider(height: 1, thickness: 0.6, indent: 16, endIndent: 16, color: cs.outlineVariant.withOpacity(0.18));
}

// --- Subpages ---

class ChatItemDisplaySettingsPage extends StatelessWidget {
  const ChatItemDisplaySettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(icon: Lucide.ArrowLeft, color: cs.onSurface, size: 22, onTap: () => Navigator.of(context).maybePop()),
        ),
        title: Text(l10n.displaySettingsPageChatItemDisplayTitle),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
        _iosSectionCard(children: [
          _iosSwitchRow(context, icon: Lucide.User, label: l10n.displaySettingsPageShowUserAvatarTitle, value: sp.showUserAvatar, onChanged: (v) => context.read<SettingsProvider>().setShowUserAvatar(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.MessageCircle, label: l10n.displaySettingsPageShowUserNameTimestampTitle, value: sp.showUserNameTimestamp, onChanged: (v) => context.read<SettingsProvider>().setShowUserNameTimestamp(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Ellipsis, label: l10n.displaySettingsPageShowUserMessageActionsTitle, value: sp.showUserMessageActions, onChanged: (v) => context.read<SettingsProvider>().setShowUserMessageActions(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Bot, label: l10n.displaySettingsPageChatModelIconTitle, value: sp.showModelIcon, onChanged: (v) => context.read<SettingsProvider>().setShowModelIcon(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.MessageSquare, label: l10n.displaySettingsPageShowModelNameTimestampTitle, value: sp.showModelNameTimestamp, onChanged: (v) => context.read<SettingsProvider>().setShowModelNameTimestamp(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Globe, label: l10n.displaySettingsPageShowProviderInChatMessageTitle, value: sp.showProviderInChatMessage, onChanged: (v) => context.read<SettingsProvider>().setShowProviderInChatMessage(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Type, label: l10n.displaySettingsPageShowTokenStatsTitle, value: sp.showTokenStats, onChanged: (v) => context.read<SettingsProvider>().setShowTokenStats(v)),
        ]),
      ]),
    );
  }
}

class RenderingSettingsPage extends StatelessWidget {
  const RenderingSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final l10n = AppLocalizations.of(context)!; final sp = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(message: l10n.settingsPageBackButton, child: _TactileIconButton(icon: Lucide.ArrowLeft, color: cs.onSurface, size: 22, onTap: () => Navigator.of(context).maybePop())),
        title: Text(l10n.displaySettingsPageRenderingSettingsTitle),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
        _iosSectionCard(children: [
          _iosSwitchRow(context, icon: Lucide.Hash, label: l10n.displaySettingsPageEnableDollarLatexTitle, value: sp.enableDollarLatex, onChanged: (v) => context.read<SettingsProvider>().setEnableDollarLatex(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Code, label: l10n.displaySettingsPageEnableMathTitle, value: sp.enableMathRendering, onChanged: (v) => context.read<SettingsProvider>().setEnableMathRendering(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.TextSelect, label: l10n.displaySettingsPageEnableUserMarkdownTitle, value: sp.enableUserMarkdown, onChanged: (v) => context.read<SettingsProvider>().setEnableUserMarkdown(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Brain, label: l10n.displaySettingsPageEnableReasoningMarkdownTitle, value: sp.enableReasoningMarkdown, onChanged: (v) => context.read<SettingsProvider>().setEnableReasoningMarkdown(v)),
          _iosDivider(context),
          _iosSwitchRow(
            context,
            icon: Lucide.FoldVertical,
            label: l10n.displaySettingsPageAutoCollapseCodeBlockTitle,
            value: sp.autoCollapseCodeBlock,
            onChanged: (v) => context.read<SettingsProvider>().setAutoCollapseCodeBlock(v),
          ),
          if (sp.autoCollapseCodeBlock) ...[
            _iosDivider(context),
            const _AutoCollapseCodeBlockLinesRow(),
          ],
          if (Platform.isAndroid || Platform.isIOS) ...[
            _iosDivider(context),
            _iosSwitchRow(context, icon: Lucide.WrapText, label: l10n.displaySettingsPageMobileCodeBlockWrapTitle, value: sp.mobileCodeBlockWrap, onChanged: (v) => context.read<SettingsProvider>().setMobileCodeBlockWrap(v)),
          ],
        ]),
      ]),
    );
  }
}

class _AutoCollapseCodeBlockLinesRow extends StatefulWidget {
  const _AutoCollapseCodeBlockLinesRow();
  @override
  State<_AutoCollapseCodeBlockLinesRow> createState() => _AutoCollapseCodeBlockLinesRowState();
}

class _AutoCollapseCodeBlockLinesRowState extends State<_AutoCollapseCodeBlockLinesRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final sp = context.read<SettingsProvider>();
    _controller = TextEditingController(text: '${sp.autoCollapseCodeBlockLines}');
    _focusNode = FocusNode()
      ..addListener(() {
        if (!_focusNode.hasFocus) _commit();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final sp = context.read<SettingsProvider>();
    final raw = _controller.text.trim();
    final parsed = int.tryParse(raw) ?? sp.autoCollapseCodeBlockLines;
    final next = parsed.clamp(1, 999);
    sp.setAutoCollapseCodeBlockLines(next);
    final text = '$next';
    if (_controller.text != text) {
      _controller.value = _controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sp = context.watch<SettingsProvider>();

    // Keep controller in sync when not editing
    if (!_focusNode.hasFocus) {
      final t = '${sp.autoCollapseCodeBlockLines}';
      if (_controller.text != t) _controller.text = t;
    }

    final baseColor = cs.onSurface.withOpacity(0.9);
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.28), width: 0.8),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.primary, width: 1.0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        SizedBox(width: 36, child: Icon(Lucide.ListOrdered, size: 20, color: baseColor)),
        const SizedBox(width: 12),
        Expanded(child: Text(l10n.displaySettingsPageAutoCollapseCodeBlockLinesTitle, style: TextStyle(fontSize: 15, color: baseColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
        IntrinsicWidth(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, maxWidth: 80),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: baseBorder,
                enabledBorder: baseBorder,
                focusedBorder: focusBorder,
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(l10n.displaySettingsPageAutoCollapseCodeBlockLinesUnit, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
      ]),
    );
  }
}

class BehaviorStartupSettingsPage extends StatelessWidget {
  const BehaviorStartupSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final l10n = AppLocalizations.of(context)!; final sp = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(message: l10n.settingsPageBackButton, child: _TactileIconButton(icon: Lucide.ArrowLeft, color: cs.onSurface, size: 22, onTap: () => Navigator.of(context).maybePop())),
        title: Text(l10n.displaySettingsPageBehaviorStartupTitle),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
        _iosSectionCard(children: [
          _iosSwitchRow(context, icon: Lucide.Brain, label: l10n.displaySettingsPageAutoCollapseThinkingTitle, value: sp.autoCollapseThinking, onChanged: (v) => context.read<SettingsProvider>().setAutoCollapseThinking(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.BadgeInfo, label: l10n.displaySettingsPageShowUpdatesTitle, value: sp.showAppUpdates, onChanged: (v) => context.read<SettingsProvider>().setShowAppUpdates(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.ChevronRight, label: l10n.displaySettingsPageMessageNavButtonsTitle, value: sp.showMessageNavButtons, onChanged: (v) => context.read<SettingsProvider>().setShowMessageNavButtons(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Calendar, label: l10n.displaySettingsPageShowChatListDateTitle, value: sp.showChatListDate, onChanged: (v) => context.read<SettingsProvider>().setShowChatListDate(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.panelLeft, label: l10n.displaySettingsPageKeepSidebarOpenOnAssistantTapTitle, value: sp.keepSidebarOpenOnAssistantTap, onChanged: (v) => context.read<SettingsProvider>().setKeepSidebarOpenOnAssistantTap(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.ListTree, label: l10n.displaySettingsPageKeepSidebarOpenOnTopicTapTitle, value: sp.keepSidebarOpenOnTopicTap, onChanged: (v) => context.read<SettingsProvider>().setKeepSidebarOpenOnTopicTap(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.UnfoldVertical, label: l10n.displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle, value: sp.keepAssistantListExpandedOnSidebarClose, onChanged: (v) => context.read<SettingsProvider>().setKeepAssistantListExpandedOnSidebarClose(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Shuffle, label: l10n.displaySettingsPageNewChatOnAssistantSwitchTitle, value: sp.newChatOnAssistantSwitch, onChanged: (v) => context.read<SettingsProvider>().setNewChatOnAssistantSwitch(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Trash2, label: l10n.displaySettingsPageNewChatAfterDeleteTitle, value: sp.newChatAfterDelete, onChanged: (v) => context.read<SettingsProvider>().setNewChatAfterDelete(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.MessageCirclePlus, label: l10n.displaySettingsPageNewChatOnLaunchTitle, value: sp.newChatOnLaunch, onChanged: (v) => context.read<SettingsProvider>().setNewChatOnLaunch(v)),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.CornerDownLeft, label: l10n.displaySettingsPageEnterToSendTitle, value: sp.enterToSendOnMobile, onChanged: (v) => context.read<SettingsProvider>().setEnterToSendOnMobile(v)),
        ]),
      ]),
    );
  }
}

class HapticsSettingsPage extends StatelessWidget {
  const HapticsSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final l10n = AppLocalizations.of(context)!; final sp = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(message: l10n.settingsPageBackButton, child: _TactileIconButton(icon: Lucide.ArrowLeft, color: cs.onSurface, size: 22, onTap: () => Navigator.of(context).maybePop())),
        title: Text(l10n.displaySettingsPageHapticsSettingsTitle),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
        _iosSectionCard(children: [
          _iosSwitchRow(
            context,
            icon: Lucide.Vibrate,
            label: l10n.displaySettingsPageHapticsGlobalTitle,
            value: sp.hapticsGlobalEnabled,
            onChanged: (v) => context.read<SettingsProvider>().setHapticsGlobalEnabled(v),
          ),
          _iosDivider(context),
          _iosSwitchRow(
            context,
            icon: Lucide.toggleRight,
            label: l10n.displaySettingsPageHapticsIosSwitchTitle,
            value: sp.hapticsIosSwitch,
            onChanged: (v) => context.read<SettingsProvider>().setHapticsIosSwitch(v),
          ),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.panelRight, label: l10n.displaySettingsPageHapticsOnSidebarTitle, value: sp.hapticsOnDrawer, onChanged: (v) => context.read<SettingsProvider>().setHapticsOnDrawer(v)),
          _iosDivider(context),
          _iosSwitchRow(
            context,
            icon: Lucide.ListOrdered,
            label: l10n.displaySettingsPageHapticsOnListItemTapTitle,
            value: sp.hapticsOnListItemTap,
            onChanged: (v) => context.read<SettingsProvider>().setHapticsOnListItemTap(v),
          ),
          _iosDivider(context),
          _iosSwitchRow(
            context,
            icon: Lucide.Square,
            label: l10n.displaySettingsPageHapticsOnCardTapTitle,
            value: sp.hapticsOnCardTap,
            onChanged: (v) => context.read<SettingsProvider>().setHapticsOnCardTap(v),
          ),
          _iosDivider(context),
          _iosSwitchRow(context, icon: Lucide.Vibrate, label: l10n.displaySettingsPageHapticsOnGenerateTitle, value: sp.hapticsOnGenerate, onChanged: (v) => context.read<SettingsProvider>().setHapticsOnGenerate(v)),
        ]),
      ]),
    );
  }
}
