import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/pages/default_model_page.dart';
import '../../provider/pages/providers_page.dart';
import 'display_settings_page.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../mcp/pages/mcp_page.dart';
import '../../assistant/pages/assistant_settings_page.dart';
import 'about_page.dart';
import 'tts_services_page.dart';
import '../../search/pages/search_services_page.dart';
import '../../backup/pages/backup_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    String modeLabel(ThemeMode m) {
      switch (m) {
        case ThemeMode.dark:
          return l10n.dark;
        case ThemeMode.light:
          return l10n.light;
        case ThemeMode.system:
        default:
          return l10n.system;
      }
    }

    Future<void> pickThemeMode() async {
      final selected = await showModalBottomSheet<ThemeMode>(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(modeLabel(ThemeMode.system)),
                  onTap: () => Navigator.of(ctx).pop(ThemeMode.system),
                ),
                ListTile(
                  title: Text(modeLabel(ThemeMode.light)),
                  onTap: () => Navigator.of(ctx).pop(ThemeMode.light),
                ),
                ListTile(
                  title: Text(modeLabel(ThemeMode.dark)),
                  onTap: () => Navigator.of(ctx).pop(ThemeMode.dark),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      if (selected != null) {
        await context.read<SettingsProvider>().setThemeMode(selected);
      }
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: l10n.back,
        ),
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          if (!settings.hasAnyActiveModel)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: cs.errorContainer.withOpacity(0.30),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Lucide.MessageCircleWarning, size: 18, color: cs.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'zh'
                              ? '部分服务未配置，某些功能可能不可用'
                              : 'Some services are not configured; features may be limited.',
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          header(Localizations.localeOf(context).languageCode == 'zh' ? '通用设置' : 'General'),
          SettingRow(
            icon: Lucide.SunMoon,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '颜色模式' : 'Color Mode',
            trailing: _ModePill(
              label: modeLabel(settings.themeMode),
              onTap: pickThemeMode,
            ),
          ),
          SettingRow(
            icon: Lucide.Monitor,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '显示设置' : 'Display',
            subtitle: Localizations.localeOf(context).languageCode == 'zh' ? '界面主题与字号等外观设置' : 'Appearance and text size',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DisplaySettingsPage()),
              );
            },
          ),
          SettingRow(
            icon: Lucide.Bot,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '助手' : 'Assistant',
            subtitle: Localizations.localeOf(context).languageCode == 'zh' ? '默认助手与对话风格' : 'Default assistant and style',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssistantSettingsPage()),
              );
            },
          ),

          header(Localizations.localeOf(context).languageCode == 'zh' ? '模型与服务' : 'Models & Services'),
          SettingRow(
            icon: Lucide.Heart,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '默认模型' : 'Default Model',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DefaultModelPage()),
              );
            },
          ),
          SettingRow(
            icon: Lucide.Boxes,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '供应商' : 'Providers',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProvidersPage()));
            },
          ),
          SettingRow(
            icon: Lucide.Earth,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '搜索服务' : 'Search',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchServicesPage()),
              );
            },
          ),
          SettingRow(
            icon: Lucide.Volume2,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '语音服务' : 'TTS',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TtsServicesPage()),
              );
            },
          ),
          SettingRow(
            icon: Lucide.Terminal,
            title: Localizations.localeOf(context).languageCode == 'zh' ? 'MCP' : 'MCP',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const McpPage()));
            },
          ),

          header(Localizations.localeOf(context).languageCode == 'zh' ? '数据设置' : 'Data'),
          SettingRow(
            icon: Lucide.Database,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '数据备份' : 'Backup',
            // subtitle: Localizations.localeOf(context).languageCode == 'zh' ? 'WebDAV · 导入导出' : 'WebDAV · Import/Export',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BackupPage()),
              );
            },
          ),
          SettingRow(
            icon: Lucide.HardDrive,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '聊天记录存储' : 'Chat Storage',
            subtitleWidget: Builder(
              builder: (ctx) {
                String fmtBytes(int bytes) {
                  const kb = 1024;
                  const mb = kb * 1024;
                  const gb = mb * 1024;
                  if (bytes >= gb) return (bytes / gb).toStringAsFixed(2) + ' GB';
                  if (bytes >= mb) return (bytes / mb).toStringAsFixed(2) + ' MB';
                  if (bytes >= kb) return (bytes / kb).toStringAsFixed(1) + ' KB';
                  return '$bytes B';
                }
                final zh = Localizations.localeOf(ctx).languageCode == 'zh';
                final svc = ctx.read<ChatService>();
                return FutureBuilder<UploadStats>(
                  future: svc.getUploadStats(),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Text(zh ? '统计中…' : 'Calculating…');
                    }
                    final count = data?.fileCount ?? 0;
                    final size = fmtBytes(data?.totalBytes ?? 0);
                    return Text(zh ? '共 $count 个文件 · $size' : '$count files · $size');
                  },
                );
              },
            ),
            onTap: () {},
          ),

          header(Localizations.localeOf(context).languageCode == 'zh' ? '关于' : 'About'),
          SettingRow(
            icon: Lucide.BadgeInfo,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '关于' : 'About',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutPage()));
            },
          ),
          SettingRow(
            icon: Lucide.Library,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '使用文档' : 'Docs',
            onTap: () async {
              final uri = Uri.parse('https://kelivo.vercel.app/');
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                await launchUrl(uri, mode: LaunchMode.platformDefault);
              }
            },
          ),
          SettingRow(
            icon: Lucide.Heart,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '赞助' : 'Sponsor',
            onTap: () async {
              final uri = Uri.parse('https://c.img.dasctf.com/LightPicture/2024/12/6c2a6df245ed97b3.jpg');
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                await launchUrl(uri, mode: LaunchMode.platformDefault);
              }
            },
          ),
          SettingRow(
            icon: Lucide.Share2,
            title: Localizations.localeOf(context).languageCode == 'zh' ? '分享' : 'Share',
            onTap: () async {
              await Share.share('Kelivo - 开源移动端AI助手');
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 12),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (subtitleWidget != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle(
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                        child: subtitleWidget!,
                      ),
                    ] else if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: cs.primary, fontSize: 13)),
              const SizedBox(width: 6),
              Icon(Lucide.ChevronDown, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
