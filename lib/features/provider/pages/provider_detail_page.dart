import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../utils/brand_assets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../model/widgets/model_detail_sheet.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../widgets/share_provider_sheet.dart';
import '../widgets/provider_group_picker_sheet.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/logging/flutter_logger.dart';
import '../../../core/services/model_override_resolver.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/model_tag_wrap.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import 'multi_key_manager_page.dart';
import 'provider_balance_page.dart';
import 'provider_network_page.dart';
import '../../../core/services/haptics.dart';
import '../../provider/widgets/provider_balance_badge.dart';
import '../../provider/widgets/provider_avatar.dart';
import '../../../utils/model_grouping.dart';
import '../../../theme/app_font_weights.dart';

class ProviderDetailPage extends StatefulWidget {
  const ProviderDetailPage({
    super.key,
    required this.keyName,
    required this.displayName,
  });
  final String keyName;
  final String displayName;

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  final PageController _pc = PageController();
  int _index = 0;
  late ProviderConfig _cfg;
  late ProviderKind _kind;
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();
  // Google Vertex AI extras
  final _locationCtrl = TextEditingController();
  final _projectCtrl = TextEditingController();
  final _saJsonCtrl = TextEditingController();
  bool _enabled = true;
  bool _useResp = false; // openai
  bool _vertexAI = false; // google
  bool _showApiKey = false; // toggle visibility
  bool _multiKeyEnabled = false; // single/multi key mode

  // 模型选择模式相关
  bool _isSelectionMode = false;
  final Set<String> _selectedModels = {};
  bool _isDetecting = false;
  bool _detectUseStream = false;
  final Map<String, bool> _detectionResults = {};
  final Map<String, String> _detectionErrorMessages = {};
  String? _currentDetectingModel;
  final Set<String> _pendingModels = {};
  bool _aihubmixAppCodeEnabled = false;
  bool _claudePromptCachingEnabled = false;
  String _claudePromptCachingTtl = ProviderConfig.claudePromptCachingTtl5m;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _cfg = settings.getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );
    _kind = ProviderConfig.classify(
      widget.keyName,
      explicitType: _cfg.providerType,
    );
    _enabled = _cfg.enabled;
    _nameCtrl.text = _cfg.name;
    _keyCtrl.text = _cfg.apiKey;
    _baseCtrl.text = _cfg.baseUrl;
    _pathCtrl.text = _cfg.chatPath ?? '/chat/completions';
    _useResp = _cfg.useResponseApi ?? false;
    _vertexAI = _cfg.vertexAI ?? false;
    _locationCtrl.text = _cfg.location ?? '';
    _projectCtrl.text = _cfg.projectId ?? '';
    _saJsonCtrl.text = _cfg.serviceAccountJson ?? '';
    _multiKeyEnabled = _cfg.multiKeyEnabled ?? false;
    _aihubmixAppCodeEnabled = _cfg.aihubmixAppCodeEnabled ?? false;
    _claudePromptCachingEnabled = _cfg.claudePromptCachingEnabled ?? false;
    _claudePromptCachingTtl = ProviderConfig.resolveClaudePromptCachingTtl(
      _cfg.claudePromptCachingTtl,
    );
  }

  @override
  void dispose() {
    _pc.dispose();
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _baseCtrl.dispose();
    _pathCtrl.dispose();
    _locationCtrl.dispose();
    _projectCtrl.dispose();
    _saJsonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    bool isUserAdded(String key) {
      const fixed = {
        'KelivoIN',
        'OpenAI',
        'Gemini',
        'SiliconFlow',
        'OpenRouter',
        'DeepSeek',
        'Tensdaq',
        'AIhubmix',
        'Aliyun',
        'Zhipu AI',
        'Claude',
        'Grok',
        'ByteDance',
      };
      return !fixed.contains(key);
    }

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            semanticLabel: l10n.settingsPageBackButton,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Row(
          children: [
            ProviderAvatar(
              providerKey: widget.keyName,
              displayName: (_nameCtrl.text.isEmpty
                  ? widget.displayName
                  : _nameCtrl.text),
              size: 24,
              onTap: () async {
                try {
                  Haptics.light();
                } catch (_) {}
                await _editProviderAvatar(context);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _nameCtrl.text.isEmpty ? widget.displayName : _nameCtrl.text,
                style: TextStyle(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_index == 0)
            Tooltip(
              message: l10n.providerDetailPageTestButton,
              child: _TactileIconButton(
                icon: Lucide.HeartPulse,
                color: cs.onSurface,
                semanticLabel: l10n.providerDetailPageTestButton,
                size: 22,
                onTap: () {
                  if (_isDetecting) return;
                  _openTestDialog();
                },
              ),
            )
          else if (_isSelectionMode)
            Tooltip(
              message: l10n.providerDetailPageCancelButton,
              child: _TactileIconButton(
                icon: Lucide.X,
                color: cs.onSurface,
                semanticLabel: l10n.providerDetailPageCancelButton,
                size: 22,
                onTap: _exitSelectionMode,
              ),
            )
          else
            Tooltip(
              message: _isDetecting
                  ? l10n.providerDetailPageBatchDetecting
                  : l10n.providerDetailPageMultiSelectButton,
              child: _TactileIconButton(
                icon: _isDetecting ? Lucide.Loader : Lucide.CheckSquare,
                color: cs.onSurface,
                semanticLabel: _isDetecting
                    ? l10n.providerDetailPageBatchDetecting
                    : l10n.providerDetailPageMultiSelectButton,
                size: 22,
                onTap: _isDetecting ? () {} : _enterSelectionMode,
              ),
            ),
          Tooltip(
            message: l10n.providerDetailPageShareTooltip,
            child: _TactileIconButton(
              icon: Lucide.Share2,
              color: cs.onSurface,
              semanticLabel: l10n.providerDetailPageShareTooltip,
              size: 22,
              onTap: () async {
                await showShareProviderSheet(context, widget.keyName);
              },
            ),
          ),
          if (isUserAdded(widget.keyName))
            Tooltip(
              message: l10n.providerDetailPageDeleteProviderTooltip,
              child: _TactileIconButton(
                icon: Lucide.Trash2,
                color: cs.error,
                semanticLabel: l10n.providerDetailPageDeleteProviderTooltip,
                size: 22,
                onTap: () async {
                  final assistantProvider = context.read<AssistantProvider>();
                  final settings = context.read<SettingsProvider>();
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.providerDetailPageDeleteProviderTitle),
                      content: Text(
                        l10n.providerDetailPageDeleteProviderContent,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(l10n.providerDetailPageCancelButton),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(
                            l10n.providerDetailPageDeleteButton,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // Clear assistant-level model selections that reference this provider
                    try {
                      for (final a in assistantProvider.assistants) {
                        if (a.chatModelProvider == widget.keyName) {
                          await assistantProvider.updateAssistant(
                            a.copyWith(clearChatModel: true),
                          );
                        }
                      }
                    } catch (_) {}

                    // Remove provider config and related selections/pins
                    await settings.removeProviderConfig(widget.keyName);
                    if (!context.mounted) return;
                    showAppSnackBar(
                      context,
                      message: l10n.providerDetailPageProviderDeletedSnackbar,
                      type: NotificationType.success,
                    );
                    Navigator.of(context).maybePop();
                  }
                },
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        children: [
          _buildConfigTab(context, cs, l10n),
          _buildModelsTab(context, cs, l10n),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: _BottomTabs(
            index: _index,
            leftIcon: Lucide.Settings2,
            leftLabel: l10n.providerDetailPageConfigTab,
            rightIcon: Lucide.Boxes,
            rightLabel: l10n.providerDetailPageModelsTab,
            onSelect: (i) {
              setState(() => _index = i);
              _pc.animateToPage(
                i,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _editProviderAvatar(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxH = MediaQuery.of(ctx).size.height * 0.8;
        Widget row(String text, VoidCallback onTap) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 48,
              child: IosCardPress(
                borderRadius: BorderRadius.circular(14),
                baseColor: cs.surface,
                duration: const Duration(milliseconds: 260),
                onTap: () async {
                  try {
                    Haptics.light();
                  } catch (_) {}
                  Navigator.of(ctx).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  onTap();
                },
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                    row(l10n.sideDrawerChooseImage, () async {
                      try {
                        final settings = context.read<SettingsProvider>();
                        final ImagePicker picker = ImagePicker();
                        final XFile? img = await picker.pickImage(
                          source: ImageSource.gallery,
                          requestFullMetadata: false,
                        );
                        if (img != null && img.path.isNotEmpty) {
                          await settings.setProviderAvatarFilePath(
                            widget.keyName,
                            img.path,
                          );
                        }
                      } catch (_) {}
                    }),
                    row(l10n.sideDrawerEnterLink, () async {
                      await _inputProviderAvatarUrl();
                    }),
                    row(l10n.sideDrawerReset, () async {
                      await context
                          .read<SettingsProvider>()
                          .resetProviderAvatar(widget.keyName);
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _inputProviderAvatarUrl() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) =>
            s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(
          builder: (ctx2, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.sideDrawerImageUrlDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.sideDrawerImageUrlDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx2).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                onChanged: (v) => setLocal(() => value = v),
                onSubmitted: (_) {
                  if (valid(value)) Navigator.of(ctx2).pop(true);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.sideDrawerCancel),
                ),
                TextButton(
                  onPressed: valid(value)
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    l10n.sideDrawerSave,
                    style: TextStyle(
                      color: valid(value)
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.38),
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await settings.setProviderAvatarUrl(widget.keyName, url);
      }
    }
  }

  Widget _buildConfigTab(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    final sp = context.watch<SettingsProvider>();
    final gid = sp.groupIdForProvider(widget.keyName);
    final groupName = gid == null
        ? l10n.providerGroupsOther
        : (sp.groupById(gid)?.name ?? l10n.providerGroupsOther);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (widget.keyName.toLowerCase() == 'kelivoin') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
            ),
            child: Text.rich(
              TextSpan(
                text: 'Powered by ',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                children: [
                  TextSpan(
                    text: 'Pollinations AI',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        final uri = Uri.parse('https://pollinations.ai');
                        try {
                          final ok = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!ok) {
                            await launchUrl(uri);
                          }
                        } catch (_) {
                          await launchUrl(uri);
                        }
                      },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.keyName.toLowerCase() == 'tensdaq') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '革命性竞价 AI MaaS 平台，价格由市场供需决定，告别高成本固定定价。',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: '官网：',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                    children: [
                      TextSpan(
                        text: 'https://dashboard.x-aio.com',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: AppFontWeights.emphasis,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final uri = Uri.parse(
                              'https://dashboard.x-aio.com',
                            );
                            try {
                              final ok = await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!ok) {
                                await launchUrl(uri);
                              }
                            } catch (_) {
                              await launchUrl(uri);
                            }
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.keyName.toLowerCase() == 'siliconflow') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已内置硅基流动的免费模型，无需 API Key。若需更强大的模型，请申请并在此配置你自己的 API Key。',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: '官网：',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                    children: [
                      TextSpan(
                        text: 'https://siliconflow.cn',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: AppFontWeights.emphasis,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final uri = Uri.parse('https://siliconflow.cn');
                            try {
                              final ok = await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!ok) {
                                await launchUrl(uri);
                              }
                            } catch (_) {
                              await launchUrl(uri);
                            }
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // 顶部管理分组标题（左侧缩进以对齐卡片内容）
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            l10n.providerDetailPageManageSectionTitle,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Top iOS-style section card for key settings
        _iosSectionCard(
          children: [
            if (widget.keyName.toLowerCase() != 'kelivoin')
              _providerKindRow(context),
            _providerGroupRow(context, groupName: groupName),
            _iosRow(
              context,
              label: l10n.providerDetailPageEnabledTitle,
              trailing: IosSwitch(
                value: _enabled,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  _save();
                },
              ),
            ),
            _iosRow(
              context,
              label: l10n.providerDetailPageMultiKeyModeTitle,
              trailing: IosSwitch(
                value: _multiKeyEnabled,
                onChanged: (v) {
                  setState(() => _multiKeyEnabled = v);
                  _save();
                },
              ),
            ),
            if (_multiKeyEnabled)
              _TactileRow(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MultiKeyManagerPage(
                        providerKey: widget.keyName,
                        providerDisplayName: widget.displayName,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                builder: (pressed) {
                  final base = Theme.of(context).colorScheme.onSurface;
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final target = pressed
                      ? (Color.lerp(
                              base,
                              isDark ? Colors.black : Colors.white,
                              0.55,
                            ) ??
                            base)
                      : base;
                  return TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: target),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (context, color, _) {
                      final c = color ?? base;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.providerDetailPageManageKeysButton,
                                style: TextStyle(fontSize: 15, color: c),
                              ),
                            ),
                            Icon(Lucide.ChevronRight, size: 16, color: c),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            if (_kind == ProviderKind.openai)
              _iosRow(
                context,
                label: l10n.providerDetailPageResponseApiTitle,
                trailing: IosSwitch(
                  value: _useResp,
                  onChanged: (v) {
                    setState(() => _useResp = v);
                    _save();
                  },
                ),
              ),
            if (_kind == ProviderKind.openai) _buildBalanceEntry(context),
            if (_kind == ProviderKind.google)
              _iosRow(
                context,
                label: l10n.providerDetailPageVertexAiTitle,
                trailing: IosSwitch(
                  value: _vertexAI,
                  onChanged: (v) {
                    setState(() => _vertexAI = v);
                    _save();
                  },
                ),
              ),
            if (_isAihubmix)
              _iosRowWithHelp(
                context,
                label: l10n.providerDetailPageAihubmixAppCodeLabel,
                helpText: l10n.providerDetailPageAihubmixAppCodeHelp,
                trailing: IosSwitch(
                  value: _aihubmixAppCodeEnabled,
                  onChanged: (v) {
                    setState(() => _aihubmixAppCodeEnabled = v);
                    _save();
                  },
                ),
              ),
            if (_supportsClaudePromptCaching)
              _iosRowWithHelp(
                context,
                label: l10n.providerDetailPageClaudePromptCachingTitle,
                helpText: l10n.providerDetailPageClaudePromptCachingHelp,
                trailing: IosSwitch(
                  value: _claudePromptCachingEnabled,
                  semanticLabel:
                      l10n.providerDetailPageClaudePromptCachingTitle,
                  onChanged: (v) {
                    setState(() => _claudePromptCachingEnabled = v);
                    _save();
                  },
                ),
              ),
            if (_supportsClaudePromptCaching && _claudePromptCachingEnabled)
              _iosRowWithHelp(
                context,
                label: l10n.providerDetailPageClaudePromptCachingTtlTitle,
                helpText: l10n.providerDetailPageClaudePromptCachingTtlHelp,
                trailing: _PromptCachingTtlSegmentedControl(
                  value: _claudePromptCachingTtl,
                  fiveMinuteLabel:
                      l10n.providerDetailPageClaudePromptCachingTtl5m,
                  oneHourLabel: l10n.providerDetailPageClaudePromptCachingTtl1h,
                  semanticLabel:
                      l10n.providerDetailPageClaudePromptCachingTtlTitle,
                  onChanged: (value) {
                    setState(() => _claudePromptCachingTtl = value);
                    _save();
                  },
                ),
              ),
            _TactileRow(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderNetworkPage(
                      providerKey: widget.keyName,
                      providerDisplayName: widget.displayName,
                    ),
                  ),
                );
              },
              builder: (pressed) {
                final cs2 = Theme.of(context).colorScheme;
                final base = cs2.onSurface;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final target = pressed
                    ? (Color.lerp(
                            base,
                            isDark ? Colors.black : Colors.white,
                            0.55,
                          ) ??
                          base)
                    : base;
                return TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: target),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, color, _) {
                    final c = color ?? base;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.providerDetailPageNetworkTab,
                              style: TextStyle(fontSize: 15, color: c),
                            ),
                          ),
                          Icon(Lucide.ChevronRight, size: 16, color: c),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _inputRow(
          context,
          label: l10n.providerDetailPageNameLabel,
          controller: _nameCtrl,
          hint: widget.displayName,
          enabled: widget.keyName.toLowerCase() != 'kelivoin',
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 12),
        if (!(_kind == ProviderKind.google && _vertexAI)) ...[
          if (widget.keyName.toLowerCase() != 'kelivoin' &&
              !_multiKeyEnabled) ...[
            _inputRow(
              context,
              label: l10n.multiKeyPageKey,
              controller: _keyCtrl,
              hint: l10n.providerDetailPageApiKeyHint,
              obscure: !_showApiKey,
              suffix: IconButton(
                tooltip: _showApiKey
                    ? l10n.providerDetailPageHideTooltip
                    : l10n.providerDetailPageShowTooltip,
                icon: Icon(
                  _showApiKey ? Lucide.EyeOff : Lucide.Eye,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  size: 18,
                ),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
              onChanged: (_) => _save(),
            ),
            const SizedBox(height: 12),
          ],
          _inputRow(
            context,
            label: l10n.providerDetailPageApiBaseUrlLabel,
            controller: _baseCtrl,
            hint: ProviderConfig.defaultsFor(
              widget.keyName,
              displayName: widget.displayName,
            ).baseUrl,
            enabled: widget.keyName.toLowerCase() != 'kelivoin',
            onChanged: (_) => _save(),
          ),
        ],
        if (_kind == ProviderKind.openai &&
            widget.keyName.toLowerCase() != 'kelivoin' &&
            !_useResp) ...[
          const SizedBox(height: 12),
          _inputRow(
            context,
            label: l10n.providerDetailPageApiPathLabel,
            controller: _pathCtrl,
            enabled:
                widget.keyName.toLowerCase() != 'openai' &&
                widget.keyName.toLowerCase() != 'tensdaq',
            hint: '/chat/completions',
            onChanged: (_) => _save(),
          ),
        ],
        if (_kind == ProviderKind.google) ...[
          const SizedBox(height: 12),
          if (_vertexAI) ...[
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPageLocationLabel,
              controller: _locationCtrl,
              hint: 'us-central1',
              onChanged: (_) => _save(),
            ),
            const SizedBox(height: 12),
            _inputRow(
              context,
              label: l10n.providerDetailPageProjectIdLabel,
              controller: _projectCtrl,
              hint: 'my-project-id',
              onChanged: (_) => _save(),
            ),
            const SizedBox(height: 12),
            _multilineRow(
              context,
              label: l10n.providerDetailPageServiceAccountJsonLabel,
              controller: _saJsonCtrl,
              hint: '{\n  "type": "service_account", ...\n}',
              actions: [
                TextButton.icon(
                  onPressed: _importServiceAccountJson,
                  icon: Icon(Lucide.Upload, size: 16),
                  label: Text(l10n.providerDetailPageImportJsonButton),
                ),
              ],
              onChanged: (_) => _save(),
            ),
          ],
        ],
        const SizedBox(height: 12),
        if (widget.keyName.toLowerCase() == 'siliconflow') ...[
          const SizedBox(height: 6),
          Center(
            child: Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/icons/Powered-by-dark.png'
                  : 'assets/icons/Powered-by-light.png',
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelsTab(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    final settings = context.watch<SettingsProvider>();
    final bool providerKnown =
        settings.providersOrder.contains(widget.keyName) ||
        settings.providerConfigs.containsKey(widget.keyName);
    if (!providerKnown) {
      return Center(
        child: Text(
          l10n.providerDetailPageProviderRemovedMessage,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
      );
    }
    final cfg = settings.getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );
    final models = cfg.models;
    final allSelected =
        _selectedModels.length == models.length && models.isNotEmpty;
    return Stack(
      children: [
        if (models.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.providerDetailPageNoModelsTitle,
                  style: TextStyle(fontSize: 18, color: cs.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.providerDetailPageNoModelsSubtitle,
                  style: TextStyle(fontSize: 13, color: cs.primary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              _isSelectionMode ? 160 : 100,
            ),
            itemCount: models.length,
            onReorderItem: (oldIndex, newIndex) {
              if (_isSelectionMode) return;
              final list = List<String>.from(models);
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
              setState(() {});
              final settings = context.read<SettingsProvider>();
              // 使用 Future.microtask 来异步执行，避免阻塞回调
              Future.microtask(() async {
                final latest = settings.getProviderConfig(
                  widget.keyName,
                  defaultName: widget.displayName,
                );
                await settings.setProviderConfig(
                  widget.keyName,
                  latest.copyWith(models: list),
                );
              });
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(animation.value);
                  return Transform.scale(scale: 0.98 + 0.02 * t, child: child);
                },
                child: child,
              );
            },
            itemBuilder: (c, i) {
              final id = models[i];
              final cs = Theme.of(context).colorScheme;
              return KeyedSubtree(
                key: ValueKey('reorder-model-$id'),
                child: ReorderableDelayedDragStartListener(
                  index: i,
                  enabled: !_isSelectionMode,
                  child: Slidable(
                    key: ValueKey('model-$id'),
                    enabled: !_isSelectionMode,
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: 0.42,
                      children: [
                        CustomSlidableAction(
                          autoClose: true,
                          backgroundColor: Colors.transparent,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? cs.error.withValues(alpha: 0.22)
                                  : cs.error.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.error.withValues(alpha: 0.35),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Lucide.Trash2,
                                    color: cs.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.providerDetailPageDeleteModelButton,
                                    style: TextStyle(
                                      color: cs.error,
                                      fontWeight: AppFontWeights.emphasis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onPressed: (_) async {
                            final settings = context.read<SettingsProvider>();
                            final assistantProvider = context
                                .read<AssistantProvider>();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                backgroundColor: cs.surface,
                                title: Text(
                                  l10n.providerDetailPageConfirmDeleteTitle,
                                ),
                                content: Text(
                                  l10n.providerDetailPageConfirmDeleteContent,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(false),
                                    child: Text(
                                      l10n.providerDetailPageCancelButton,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(true),
                                    child: Text(
                                      l10n.providerDetailPageDeleteButton,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            final old = settings.getProviderConfig(
                              widget.keyName,
                              defaultName: widget.displayName,
                            );
                            final prevList = List<String>.from(old.models);
                            final prevOverrides = Map<String, dynamic>.from(
                              old.modelOverrides,
                            );
                            final removeIndex = prevList.indexOf(id);
                            final newList = prevList
                                .where((e) => e != id)
                                .toList();
                            final newOverrides = Map<String, dynamic>.from(
                              prevOverrides,
                            )..remove(id);
                            await settings.setProviderConfig(
                              widget.keyName,
                              old.copyWith(
                                models: newList,
                                modelOverrides: newOverrides,
                              ),
                            );

                            // Clear global and assistant-level model selections that reference the deleted model
                            await settings.clearSelectionsForModel(
                              widget.keyName,
                              id,
                            );
                            try {
                              for (final a in assistantProvider.assistants) {
                                if (a.chatModelProvider == widget.keyName &&
                                    a.chatModelId == id) {
                                  await assistantProvider.updateAssistant(
                                    a.copyWith(clearChatModel: true),
                                  );
                                }
                              }
                            } catch (_) {}

                            if (!context.mounted) return;
                            showAppSnackBar(
                              context,
                              message:
                                  l10n.providerDetailPageModelDeletedSnackbar,
                              type: NotificationType.info,
                              actionLabel: l10n.providerDetailPageUndoButton,
                              onAction: () {
                                Future(() async {
                                  final cfg2 = settings.getProviderConfig(
                                    widget.keyName,
                                    defaultName: widget.displayName,
                                  );
                                  final restoredList = List<String>.from(
                                    cfg2.models,
                                  );
                                  if (!restoredList.contains(id)) {
                                    if (removeIndex >= 0 &&
                                        removeIndex <= restoredList.length) {
                                      restoredList.insert(removeIndex, id);
                                    } else {
                                      restoredList.add(id);
                                    }
                                  }
                                  final restoredOverrides =
                                      Map<String, dynamic>.from(
                                        cfg2.modelOverrides,
                                      );
                                  if (!restoredOverrides.containsKey(id) &&
                                      prevOverrides.containsKey(id)) {
                                    restoredOverrides[id] = prevOverrides[id];
                                  }
                                  await settings.setProviderConfig(
                                    widget.keyName,
                                    cfg2.copyWith(
                                      models: restoredList,
                                      modelOverrides: restoredOverrides,
                                    ),
                                  );
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    child: _ModelCard(
                      providerKey: widget.keyName,
                      modelId: id,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedModels.contains(id),
                      onSelectionChanged: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedModels.add(id);
                          } else {
                            _selectedModels.remove(id);
                          }
                        });
                      },
                      detectionResult: _detectionResults[id],
                      detectionErrorMessage: _detectionErrorMessages[id],
                      isDetecting: _currentDetectingModel == id,
                      isPending: _pendingModels.contains(id),
                    ),
                  ),
                ),
              );
            },
          ),
        if (_isSelectionMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: _buildModelSelectionToolbar(
              l10n: l10n,
              cs: cs,
              allSelected: allSelected,
            ),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: _buildModelActionToolbar(
              l10n: l10n,
              cs: cs,
              hasModels: models.isNotEmpty,
            ),
          ),
      ],
    );
  }

  // Legacy network tab removed (replaced by ProviderNetworkPage)

  Widget _inputRow(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    bool enabled = true,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceEntry(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final cfg = settings.getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );
    final enabled = cfg.balanceEnabled == true;
    return _TactileRow(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProviderBalancePage(
              providerKey: widget.keyName,
              providerDisplayName: widget.displayName,
            ),
          ),
        );
        if (!mounted) return;
        setState(() {
          _cfg = context.read<SettingsProvider>().getProviderConfig(
            widget.keyName,
            defaultName: widget.displayName,
          );
        });
      },
      builder: (pressed) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final base = cs.onSurface;
        final target = pressed
            ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ??
                  base)
            : base;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            final c = color ?? base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  // Icon(Lucide.Coins, size: 18, color: c),
                  // const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.providerDetailPageBalanceInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: c),
                    ),
                  ),
                  if (enabled) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 108),
                      child: ProviderBalanceBadge(
                        providerKey: widget.keyName,
                        displayName: widget.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFontWeights.semibold,
                        ),
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(Lucide.ChevronRight, size: 16, color: c),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- iOS style helpers (consistent with MultiKeyManagerPage) ---

  Widget _iosSectionCard({required List<Widget> children}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color base = cs.surface;
    final Color bg = isDark
        ? Color.lerp(base, Colors.white, 0.06)!
        : Color.lerp(base, Colors.white, 0.92)!;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
          width: 0.6,
        ),
        // boxShadow: [
        //   if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 1)),
        // ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _iosRow(
    BuildContext context, {
    required String label,
    Widget? trailing,
    GestureTapCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      onTap: onTap,
      builder: (pressed) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final base = cs.onSurface;
        final target = pressed
            ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ??
                  base)
            : base;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            final c = color ?? base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 15, color: c),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _iosRowWithHelp(
    BuildContext context, {
    required String label,
    required String helpText,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      onTap: null,
      builder: (pressed) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final base = cs.onSurface;
        final target = pressed
            ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ??
                  base)
            : base;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            final c = color ?? base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 15, color: c),
                          ),
                        ),
                        Tooltip(
                          message: helpText,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.help_outline,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool get _isAihubmix {
    final keyLower = widget.keyName.toLowerCase();
    final baseLower = _baseCtrl.text.toLowerCase();
    return keyLower.contains('aihubmix') || baseLower.contains('aihubmix.com');
  }

  bool get _isOpenRouter {
    final keyLower = widget.keyName.toLowerCase();
    final baseLower = _baseCtrl.text.toLowerCase();
    return keyLower.contains('openrouter') || baseLower.contains('openrouter');
  }

  bool get _supportsClaudePromptCaching {
    return _kind == ProviderKind.claude ||
        (_kind == ProviderKind.openai && _isOpenRouter);
  }

  Widget _providerKindRow(BuildContext context) {
    String labelFor(ProviderKind k) {
      switch (k) {
        case ProviderKind.google:
          return 'Gemini';
        case ProviderKind.claude:
          return 'Claude';
        case ProviderKind.openai:
          return 'OpenAI';
      }
    }

    return _TactileRow(
      onTap: _showProviderKindSheet,
      builder: (pressed) {
        final cs = Theme.of(context).colorScheme;
        final base = cs.onSurface;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final target = pressed
            ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ??
                  base)
            : base;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            final c = color ?? base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.providerDetailPageProviderTypeTitle,
                      style: TextStyle(fontSize: 15, color: c),
                    ),
                  ),
                  Text(
                    labelFor(_kind),
                    style: TextStyle(fontSize: 15, color: c),
                  ),
                  const SizedBox(width: 6),
                  Icon(Lucide.ChevronRight, size: 16, color: c),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _providerGroupRow(BuildContext context, {required String groupName}) {
    final l10n = AppLocalizations.of(context)!;
    return _TactileRow(
      onTap: () async {
        await showProviderGroupPickerSheet(
          context,
          providerKey: widget.keyName,
        );
      },
      pressedScale: 1.00,
      haptics: false,
      builder: (pressed) {
        final cs = Theme.of(context).colorScheme;
        final base = cs.onSurface;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final target = pressed
            ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ??
                  base)
            : base;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            final c = color ?? base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxTrailingW = constraints.maxWidth * 0.55;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.providerGroupsGroupLabel,
                          style: TextStyle(fontSize: 15, color: c),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxTrailingW),
                        child: Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 15, color: c),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Lucide.ChevronRight, size: 16, color: c),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showProviderKindSheet() async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showModalBottomSheet<ProviderKind>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                _providerKindTile(ctx, ProviderKind.openai, label: 'OpenAI'),
                _providerKindTile(ctx, ProviderKind.google, label: 'Gemini'),
                _providerKindTile(ctx, ProviderKind.claude, label: 'Claude'),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      setState(() => _kind = selected);
      await _save();
    }
  }

  Widget _providerKindTile(
    BuildContext ctx,
    ProviderKind k, {
    required String label,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final selected = _kind == k;
    return _TactileRow(
      pressedScale: 1.00,
      haptics: false,
      onTap: () => Navigator.of(ctx).pop(k),
      builder: (pressed) {
        final base = cs.onSurface;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final target = pressed
            ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ??
                  base)
            : base;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            final c = color ?? base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 15, color: c),
                    ),
                  ),
                  if (selected) Icon(Icons.check, color: cs.primary),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final assistantProvider = context.read<AssistantProvider>();
    final old = settings.getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );
    String projectId = _projectCtrl.text.trim();
    if ((_kind == ProviderKind.google) && _vertexAI && projectId.isEmpty) {
      try {
        final obj = jsonDecode(_saJsonCtrl.text) as Map<String, dynamic>;
        projectId = (obj['project_id'] as String?)?.trim() ?? '';
      } catch (_) {}
    }
    final updated = old.copyWith(
      enabled: _enabled,
      name: _nameCtrl.text.trim().isEmpty
          ? widget.displayName
          : _nameCtrl.text.trim(),
      apiKey: _keyCtrl.text.trim(),
      baseUrl: _baseCtrl.text.trim(),
      providerType: _kind, // Save the selected provider type
      chatPath: _kind == ProviderKind.openai
          ? _pathCtrl.text.trim()
          : old.chatPath,
      useResponseApi: _kind == ProviderKind.openai
          ? _useResp
          : old.useResponseApi,
      vertexAI: _kind == ProviderKind.google ? _vertexAI : old.vertexAI,
      location: _kind == ProviderKind.google
          ? _locationCtrl.text.trim()
          : old.location,
      projectId: _kind == ProviderKind.google ? projectId : old.projectId,
      serviceAccountJson: _kind == ProviderKind.google
          ? _saJsonCtrl.text.trim()
          : old.serviceAccountJson,
      multiKeyEnabled: _multiKeyEnabled,
      aihubmixAppCodeEnabled: _aihubmixAppCodeEnabled,
      claudePromptCachingEnabled: _supportsClaudePromptCaching
          ? _claudePromptCachingEnabled
          : false,
      claudePromptCachingTtl: _supportsClaudePromptCaching
          ? _claudePromptCachingTtl
          : ProviderConfig.claudePromptCachingTtl5m,
      // preserve models and modelOverrides and proxy fields implicitly via copyWith
    );
    await settings.setProviderConfig(widget.keyName, updated);

    // If provider is now disabled but was previously enabled, clear model selections
    if (!_enabled && old.enabled) {
      await settings.clearSelectionsForProvider(widget.keyName);
      // Also clear assistant-level model selections referencing this provider
      try {
        for (final a in assistantProvider.assistants) {
          if (a.chatModelProvider == widget.keyName) {
            await assistantProvider.updateAssistant(
              a.copyWith(clearChatModel: true),
            );
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    // Silent auto-save (no snackbar) for immediate-save UX
  }

  Widget _multilineRow(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hint,
    List<Widget>? actions,
    ValueChanged<String>? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            if (actions != null) ...actions,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 8,
          minLines: 4,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            alignLabelWithHint: true,
            fillColor: isDark ? Colors.white10 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _importServiceAccountJson() async {
    try {
      // Lazy import to avoid hard dependency errors in web
      // ignore: avoid_dynamic_calls
      // ignore: import_of_legacy_library_into_null_safe
      // Using file_picker which is already in pubspec
      // import placed at top-level of this file
      final picker = await _pickJsonFile();
      if (picker == null) return;
      _saJsonCtrl.text = picker;
      // Auto-fill projectId if available
      try {
        final obj = jsonDecode(_saJsonCtrl.text) as Map<String, dynamic>;
        final pid = (obj['project_id'] as String?)?.trim();
        if ((pid ?? '').isNotEmpty && _projectCtrl.text.trim().isEmpty) {
          _projectCtrl.text = pid!;
        }
      } catch (_) {}
      if (mounted) {
        setState(() {});
        await _save();
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: '$e', type: NotificationType.error);
    }
  }

  Future<String?> _pickJsonFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      final path = file.path;
      if (path == null) return null;
      final text = await File(path).readAsString();
      return text;
    } catch (e) {
      return null;
    }
  }

  Widget _buildToolbarShell({
    required Widget child,
    required ColorScheme colorScheme,
    required double horizontalMargin,
    required EdgeInsetsGeometry padding,
    required double maxWidth,
  }) {
    final toolbarColor = Theme.of(context).brightness == Brightness.dark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.12),
            colorScheme.surface,
          )
        : const Color(0xFFF2F3F5);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth - horizontalMargin * 2,
          ),
          decoration: BoxDecoration(
            color: toolbarColor,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  Widget _buildModelActionToolbar({
    required AppLocalizations l10n,
    required ColorScheme cs,
    required bool hasModels,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final compact = availableWidth < 370;
        final horizontalMargin = compact ? 10.0 : 16.0;
        final itemGap = compact ? 8.0 : 10.0;
        final toolbarPadding = EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: 10,
        );
        final textButtonPadding = EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: 10,
        );
        final iconButtonPadding = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 10,
        );

        return _buildToolbarShell(
          colorScheme: cs,
          horizontalMargin: horizontalMargin,
          padding: toolbarPadding,
          maxWidth: availableWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: _buildActionToolbarButton(
                  label: l10n.providerDetailPageFetchModelsButton,
                  icon: Lucide.Boxes,
                  showLabel: !compact,
                  padding: compact ? iconButtonPadding : textButtonPadding,
                  colorScheme: cs,
                  outlined: true,
                  onTap: () => _showModelPicker(context),
                ),
              ),
              SizedBox(width: itemGap),
              Flexible(
                fit: FlexFit.loose,
                child: _buildActionToolbarButton(
                  label: l10n.providerDetailPageAddNewModelButton,
                  icon: Lucide.Plus,
                  showLabel: !compact,
                  padding: compact ? iconButtonPadding : textButtonPadding,
                  colorScheme: cs,
                  onTap: () async {
                    await showCreateModelSheet(
                      context,
                      providerKey: widget.keyName,
                    );
                  },
                ),
              ),
              if (hasModels) ...[
                SizedBox(width: itemGap),
                _buildActionToolbarButton(
                  label: l10n.providerDetailPageDeleteAllModelsTooltip,
                  icon: Lucide.Trash2,
                  showLabel: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  colorScheme: cs,
                  destructive: true,
                  onTap: _deleteAllModels,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionToolbarButton({
    required String label,
    required IconData icon,
    required bool showLabel,
    required EdgeInsetsGeometry padding,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    bool outlined = false,
    bool destructive = false,
  }) {
    final fg = destructive ? colorScheme.error : colorScheme.primary;
    return Semantics(
      button: true,
      label: label,
      child: _TactileRow(
        pressedScale: 0.97,
        haptics: false,
        onTap: onTap,
        builder: (pressed) {
          return Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              color: destructive
                  ? colorScheme.error.withValues(alpha: 0.1)
                  : (outlined
                        ? null
                        : colorScheme.primary.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(999),
              border: outlined
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                    )
                  : null,
            ),
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: destructive ? 18 : 20, color: fg),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: outlined
                            ? AppFontWeights.semibold
                            : AppFontWeights.medium,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModelSelectionToolbar({
    required AppLocalizations l10n,
    required ColorScheme cs,
    required bool allSelected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final compact = availableWidth < 370;
        final horizontalMargin = compact ? 10.0 : 16.0;
        final itemGap = compact ? 8.0 : 10.0;
        final toolbarPadding = EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: 10,
        );
        final textButtonPadding = EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: 10,
        );
        final iconButtonPadding = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 9,
        );
        final iconOnlyPadding = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 10,
        );
        final selectLabel = allSelected
            ? l10n.mcpAssistantSheetClearAll
            : l10n.mcpAssistantSheetSelectAll;
        final selectIcon = allSelected ? Lucide.Square : Lucide.CheckSquare;
        final detectLabel = _isDetecting
            ? l10n.providerDetailPageBatchDetecting
            : l10n.providerDetailPageBatchDetectButton;
        final deleteDisabled = _selectedModels.isEmpty || _isDetecting;
        final buttonTextStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(fontSize: 14, fontWeight: AppFontWeights.semibold),
        );
        final textScaler = MediaQuery.textScalerOf(context);
        final textDirection = Directionality.of(context);
        final locale = Localizations.maybeLocaleOf(context);

        double labelWidth(String label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: buttonTextStyle),
            maxLines: 1,
            textDirection: textDirection,
            textScaler: textScaler,
            locale: locale,
          )..layout();
          return painter.width;
        }

        double buttonWidth({
          required String label,
          required bool showLabel,
          required EdgeInsets padding,
          double iconSize = 20,
        }) {
          final width =
              padding.horizontal +
              iconSize +
              (showLabel ? 8 + labelWidth(label) : 0);
          return width < 44 ? 44 : width;
        }

        final toolbarInnerWidth =
            availableWidth - horizontalMargin * 2 - toolbarPadding.horizontal;
        final toolbarTextBudget = toolbarInnerWidth - 8;
        double totalWidth({
          required bool showSelectLabel,
          required bool showDetectLabel,
          required bool showDeleteLabel,
        }) {
          return buttonWidth(
                label: selectLabel,
                showLabel: showSelectLabel,
                padding: iconOnlyPadding,
              ) +
              itemGap +
              buttonWidth(
                label: '',
                showLabel: false,
                padding: iconButtonPadding,
                iconSize: 18,
              ) +
              itemGap +
              buttonWidth(
                label: detectLabel,
                showLabel: showDetectLabel,
                padding: showDetectLabel ? textButtonPadding : iconOnlyPadding,
              ) +
              itemGap +
              buttonWidth(
                label: l10n.providerDetailPageDeleteSelectedModelsButton,
                showLabel: showDeleteLabel,
                padding: iconOnlyPadding,
              );
        }

        var showSelectLabel = true;
        var showDetectLabel = true;
        var showDeleteLabel = true;
        if (totalWidth(
              showSelectLabel: showSelectLabel,
              showDetectLabel: showDetectLabel,
              showDeleteLabel: showDeleteLabel,
            ) >
            toolbarTextBudget) {
          showDeleteLabel = false;
        }
        if (totalWidth(
              showSelectLabel: showSelectLabel,
              showDetectLabel: showDetectLabel,
              showDeleteLabel: showDeleteLabel,
            ) >
            toolbarTextBudget) {
          showSelectLabel = false;
        }
        if (totalWidth(
              showSelectLabel: showSelectLabel,
              showDetectLabel: showDetectLabel,
              showDeleteLabel: showDeleteLabel,
            ) >
            toolbarTextBudget) {
          showDetectLabel = false;
        }

        return _buildToolbarShell(
          colorScheme: cs,
          horizontalMargin: horizontalMargin,
          padding: toolbarPadding,
          maxWidth: availableWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectionToolbarSelectButton(
                label: selectLabel,
                icon: selectIcon,
                showLabel: showSelectLabel,
                padding: iconOnlyPadding,
                colorScheme: cs,
                allSelected: allSelected,
              ),
              SizedBox(width: itemGap),
              _buildSelectionToolbarStreamButton(
                padding: iconButtonPadding,
                colorScheme: cs,
              ),
              SizedBox(width: itemGap),
              _buildSelectionToolbarDetectButton(
                l10n: l10n,
                showLabel: showDetectLabel,
                padding: showDetectLabel ? textButtonPadding : iconOnlyPadding,
                colorScheme: cs,
              ),
              SizedBox(width: itemGap),
              _buildSelectionToolbarDeleteButton(
                l10n: l10n,
                showLabel: showDeleteLabel,
                padding: iconOnlyPadding,
                disabled: deleteDisabled,
                colorScheme: cs,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionToolbarSelectButton({
    required String label,
    required IconData icon,
    required bool showLabel,
    required EdgeInsetsGeometry padding,
    required ColorScheme colorScheme,
    required bool allSelected,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: _TactileRow(
        pressedScale: 0.97,
        haptics: false,
        onTap: () {
          if (allSelected) {
            setState(() {
              _selectedModels.clear();
            });
          } else {
            _selectAll();
          }
        },
        builder: (pressed) {
          return Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              color: pressed
                  ? colorScheme.onSurface.withValues(alpha: 0.06)
                  : null,
            ),
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey(allSelected),
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionToolbarStreamButton({
    required EdgeInsetsGeometry padding,
    required ColorScheme colorScheme,
  }) {
    return _TactileRow(
      pressedScale: 0.97,
      haptics: false,
      onTap: () => setState(() => _detectUseStream = !_detectUseStream),
      builder: (pressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            color: pressed
                ? colorScheme.onSurface.withValues(alpha: 0.06)
                : (_detectUseStream
                      ? colorScheme.onSurface.withValues(alpha: 0.08)
                      : Colors.transparent),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _detectUseStream ? Lucide.AudioWaveform : Lucide.SquareEqual,
                key: ValueKey(_detectUseStream),
                size: 18,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionToolbarDetectButton({
    required AppLocalizations l10n,
    required bool showLabel,
    required EdgeInsetsGeometry padding,
    required ColorScheme colorScheme,
  }) {
    final disabled = _selectedModels.isEmpty;
    final label = _isDetecting
        ? l10n.providerDetailPageBatchDetecting
        : l10n.providerDetailPageBatchDetectButton;
    return Semantics(
      button: true,
      label: label,
      enabled: !disabled,
      child: _TactileRow(
        pressedScale: 0.97,
        haptics: false,
        onTap: disabled ? null : _startDetection,
        builder: (pressed) {
          return Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              color: disabled
                  ? colorScheme.onSurface.withValues(alpha: 0.1)
                  : colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isDetecting ? Lucide.Loader : Lucide.HeartPulse,
                  size: 20,
                  color: disabled
                      ? colorScheme.onSurface.withValues(alpha: 0.5)
                      : colorScheme.primary,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: disabled
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : colorScheme.primary,
                        fontSize: 14,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionToolbarDeleteButton({
    required AppLocalizations l10n,
    required bool showLabel,
    required EdgeInsetsGeometry padding,
    required bool disabled,
    required ColorScheme colorScheme,
  }) {
    final label = l10n.providerDetailPageDeleteSelectedModelsButton;
    return Semantics(
      button: true,
      label: label,
      enabled: !disabled,
      child: _TactileRow(
        pressedScale: 0.97,
        haptics: false,
        onTap: disabled ? null : _confirmDeleteSelectedModels,
        builder: (pressed) {
          return Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              color: disabled
                  ? colorScheme.onSurface.withValues(alpha: 0.1)
                  : colorScheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Lucide.Trash2,
                  size: 20,
                  color: disabled
                      ? colorScheme.onSurface.withValues(alpha: 0.5)
                      : colorScheme.error,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: disabled
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : colorScheme.error,
                        fontSize: 14,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedModels.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedModels.clear();
    });
  }

  void _selectAll() {
    final cfg = context.read<SettingsProvider>().getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );
    setState(() {
      _selectedModels.clear();
      _selectedModels.addAll(cfg.models);
    });
  }

  Future<void> _clearAssistantSelectionsForModels(
    Set<String> modelIds,
    AssistantProvider assistantProvider,
  ) async {
    if (modelIds.isEmpty) return;
    try {
      for (final assistant in assistantProvider.assistants) {
        if (assistant.chatModelProvider == widget.keyName &&
            assistant.chatModelId != null &&
            modelIds.contains(assistant.chatModelId)) {
          await assistantProvider.updateAssistant(
            assistant.copyWith(clearChatModel: true),
          );
        }
      }
    } catch (e, st) {
      FlutterLogger.log(
        '[ProviderDetail] clear assistant model selections failed: $e\n$st',
        tag: 'Provider',
      );
      assert(() {
        debugPrint(
          '[ProviderDetail] clear assistant model selections failed: $e',
        );
        return true;
      }());
    }
  }

  Future<void> _confirmDeleteSelectedModels() async {
    if (_selectedModels.isEmpty || _isDetecting) return;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final modelsToDelete = Set<String>.from(_selectedModels);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(l10n.providerDetailPageConfirmDeleteTitle),
        content: Text(
          l10n.providerDetailPageDeleteSelectedModelsConfirm(
            modelsToDelete.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerDetailPageCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.providerDetailPageDeleteButton,
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    final settings = context.read<SettingsProvider>();
    final assistantProvider = context.read<AssistantProvider>();
    final deletedCount = await settings.deleteModels(
      widget.keyName,
      modelsToDelete,
    );
    await _clearAssistantSelectionsForModels(modelsToDelete, assistantProvider);
    if (!mounted) return;
    setState(() {
      _selectedModels.clear();
      _detectionResults.removeWhere((id, _) => modelsToDelete.contains(id));
      _detectionErrorMessages.removeWhere(
        (id, _) => modelsToDelete.contains(id),
      );
      _pendingModels.removeAll(modelsToDelete);
      if (_currentDetectingModel != null &&
          modelsToDelete.contains(_currentDetectingModel)) {
        _currentDetectingModel = null;
      }
      _isSelectionMode = false;
    });
    if (deletedCount > 0) {
      showAppSnackBar(
        context,
        message: l10n.providerDetailPageSelectedModelsDeletedSnackbar(
          deletedCount,
        ),
        type: NotificationType.info,
      );
    }
  }

  Future<void> _startDetection() async {
    if (_selectedModels.isEmpty || _isDetecting) return;

    final modelsToTest = Set<String>.from(_selectedModels);

    setState(() {
      _isDetecting = true;
      _detectionResults.removeWhere((id, _) => modelsToTest.contains(id));
      _detectionErrorMessages.removeWhere((id, _) => modelsToTest.contains(id));
      _pendingModels.clear();
      _pendingModels.addAll(modelsToTest);
      _currentDetectingModel = null;
    });

    final cfg = context.read<SettingsProvider>().getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );

    // 顺序检测,防止并发导致API被封锁
    for (final modelId in modelsToTest) {
      if (mounted) {
        setState(() {
          _currentDetectingModel = modelId;
          _pendingModels.remove(modelId);
        });
      }

      try {
        await ProviderManager.testConnection(
          cfg,
          modelId,
          useStream: _detectUseStream,
        );
        if (mounted) {
          setState(() {
            _detectionResults[modelId] = true;
            _detectionErrorMessages.remove(modelId);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _detectionResults[modelId] = false;
            _detectionErrorMessages[modelId] = e.toString();
          });
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isDetecting = false;
        _currentDetectingModel = null;
        _pendingModels.clear();
      });
    }
  }

  Future<void> _deleteAllModels() async {
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );
    if (cfg.models.isEmpty) return;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(l10n.providerDetailPageConfirmDeleteTitle),
        content: Text(l10n.providerDetailPageDeleteAllModelsWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerDetailPageCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.providerDetailPageDeleteButton,
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final assistantProvider = context.read<AssistantProvider>();
    final modelsToDelete = Set<String>.from(cfg.models);
    await settings.deleteModels(widget.keyName, modelsToDelete);
    await _clearAssistantSelectionsForModels(modelsToDelete, assistantProvider);
    if (!mounted) return;
    setState(() {
      _selectedModels.clear();
      _detectionResults.clear();
      _detectionErrorMessages.clear();
      _pendingModels.clear();
      _currentDetectingModel = null;
      _isSelectionMode = false;
    });
  }

  Future<void> _openTestDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConnectionTestDialog(
        providerKey: widget.keyName,
        providerDisplayName: widget.displayName,
      ),
    );
  }

  // _saveNetwork moved to ProviderNetworkPage

  Future<void> _showModelPicker(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(
      widget.keyName,
      defaultName: widget.displayName,
    );
    final bool isDefaultSilicon = widget.keyName.toLowerCase() == 'siliconflow';
    final bool hasUserKey =
        (cfg.multiKeyEnabled == true && (cfg.apiKeys?.isNotEmpty == true)) ||
        cfg.apiKey.trim().isNotEmpty;
    final bool restrictToFree = isDefaultSilicon && !hasUserKey;
    final controller = TextEditingController();
    List<dynamic> items = const [];
    bool loading = true;
    String error = '';
    // Collapsed state per group in the selector dialog
    final Map<String, bool> collapsed = <String, bool>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final l10n = AppLocalizations.of(ctx)!;
            Future<void> loadModels() async {
              try {
                if (restrictToFree) {
                  final list = <ModelInfo>[
                    ModelRegistry.infer(
                      ModelInfo(
                        id: 'THUDM/GLM-4-9B-0414',
                        displayName: 'THUDM/GLM-4-9B-0414',
                      ),
                    ),
                    ModelRegistry.infer(
                      ModelInfo(
                        id: 'Qwen/Qwen3-8B',
                        displayName: 'Qwen/Qwen3-8B',
                      ),
                    ),
                  ];
                  setLocal(() {
                    items = list;
                    loading = false;
                  });
                } else {
                  final list = await ProviderManager.listModels(cfg);
                  setLocal(() {
                    items = list;
                    loading = false;
                  });
                }
              } catch (e) {
                setLocal(() {
                  items = const [];
                  loading = false;
                  error = '$e';
                });
              }
            }

            if (loading) {
              // kick off loading once
              Future.microtask(loadModels);
            }

            final selected = settings
                .getProviderConfig(
                  widget.keyName,
                  defaultName: widget.displayName,
                )
                .models
                .toSet();
            final query = controller.text.trim().toLowerCase();
            final filtered = <ModelInfo>[
              for (final m in items)
                if (m is ModelInfo &&
                    (query.isEmpty ||
                        m.id.toLowerCase().contains(query) ||
                        m.displayName.toLowerCase().contains(query)))
                  m,
            ];

            String groupFor(ModelInfo m) {
              return ModelGrouping.groupFor(
                m,
                embeddingsLabel: l10n.providerDetailPageEmbeddingsGroupTitle,
                otherLabel: l10n.providerDetailPageOtherModelsGroupTitle,
              );
            }

            final Map<String, List<ModelInfo>> grouped = {};
            for (final m in filtered) {
              final g = groupFor(m);
              (grouped[g] ??= []).add(m);
            }
            final groupKeys = grouped.keys.toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.7,
                  maxChildSize: 0.8,
                  minChildSize: 0.4,
                  builder: (c, scrollController) {
                    final bottomPadding =
                        MediaQuery.of(ctx).padding.bottom + 16;
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: controller,
                            onChanged: (_) => setLocal(() {}),
                            decoration: InputDecoration(
                              hintText: l10n.providerDetailPageFilterHint,
                              filled: true,
                              fillColor:
                                  Theme.of(ctx).brightness == Brightness.dark
                                  ? Colors.white10
                                  : const Color(0xFFF2F3F5),
                              prefixIcon: Icon(
                                Lucide.Search,
                                size: 20,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                              suffixIcon: ExcludeSemantics(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Animated toggle: Select All / Deselect All (based on current filtered state)
                                    Builder(
                                      builder: (_) {
                                        final allSelected =
                                            filtered.isNotEmpty &&
                                            filtered.every(
                                              (m) => selected.contains(m.id),
                                            );
                                        return IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 40,
                                          ),
                                          icon: Icon(
                                            allSelected
                                                ? Lucide.Square
                                                : Lucide.CheckSquare,
                                            size: 22,
                                            color: cs.onSurface.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                          tooltip: allSelected
                                              ? l10n.mcpAssistantSheetClearAll
                                              : l10n.mcpAssistantSheetSelectAll,
                                          onPressed: () async {
                                            final old = settings
                                                .getProviderConfig(
                                                  widget.keyName,
                                                  defaultName:
                                                      widget.displayName,
                                                );
                                            if (filtered.isEmpty) return;
                                            if (allSelected) {
                                              // Deselect all filtered
                                              final toRemove = filtered
                                                  .map((m) => m.id)
                                                  .toSet();
                                              final next = old.models
                                                  .where(
                                                    (id) =>
                                                        !toRemove.contains(id),
                                                  )
                                                  .toList();
                                              await settings.setProviderConfig(
                                                widget.keyName,
                                                old.copyWith(models: next),
                                              );
                                            } else {
                                              // Select all filtered
                                              final setIds = old.models.toSet();
                                              setIds.addAll(
                                                filtered.map((m) => m.id),
                                              );
                                              await settings.setProviderConfig(
                                                widget.keyName,
                                                old.copyWith(
                                                  models: setIds.toList(),
                                                ),
                                              );
                                            }
                                            setLocal(() {});
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 40,
                                      ),
                                      icon: Icon(
                                        Lucide.Repeat,
                                        size: 22,
                                        color: cs.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      tooltip: l10n.modelFetchInvertTooltip,
                                      onPressed: () async {
                                        final old = settings.getProviderConfig(
                                          widget.keyName,
                                          defaultName: widget.displayName,
                                        );
                                        final q = controller.text
                                            .trim()
                                            .toLowerCase();
                                        final filteredNow = <ModelInfo>[
                                          for (final m in items)
                                            if (m is ModelInfo &&
                                                (q.isEmpty ||
                                                    m.id.toLowerCase().contains(
                                                      q,
                                                    ) ||
                                                    m.displayName
                                                        .toLowerCase()
                                                        .contains(q)))
                                              m,
                                        ];
                                        if (filteredNow.isEmpty) return;
                                        final current = old.models.toSet();
                                        for (final m in filteredNow) {
                                          if (current.contains(m.id)) {
                                            current.remove(m.id);
                                          } else {
                                            current.add(m.id);
                                          }
                                        }
                                        await settings.setProviderConfig(
                                          widget.keyName,
                                          old.copyWith(
                                            models: current.toList(),
                                          ),
                                        );
                                        setLocal(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.transparent,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.transparent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: loading
                              ? const Center(child: CircularProgressIndicator())
                              : error.isNotEmpty
                              ? Center(
                                  child: Text(
                                    error,
                                    style: TextStyle(color: cs.error),
                                  ),
                                )
                              : ListView(
                                  controller: scrollController,
                                  padding: EdgeInsets.only(
                                    bottom: bottomPadding,
                                  ),
                                  children: [
                                    for (final g in groupKeys) ...[
                                      // Group header with actions
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          6,
                                          12,
                                          6,
                                        ),
                                        child: _TactileRow(
                                          pressedScale: 0.98,
                                          haptics: false,
                                          onTap: () => setLocal(() {
                                            collapsed[g] =
                                                !(collapsed[g] == true);
                                          }),
                                          builder: (_) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white10
                                                    : const Color(0xFFF2F3F5),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 6,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 28,
                                                      child: Center(
                                                        child: AnimatedRotation(
                                                          turns:
                                                              (collapsed[g] ==
                                                                  true)
                                                              ? 0.0
                                                              : 0.25,
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    220,
                                                              ),
                                                          curve: Curves
                                                              .easeOutCubic,
                                                          child: Icon(
                                                            Lucide.ChevronRight,
                                                            size: 20,
                                                            color: cs.onSurface
                                                                .withValues(
                                                                  alpha: 0.7,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Text(
                                                        g,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              AppFontWeights
                                                                  .semibold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Builder(
                                                      builder: (ctx2) {
                                                        final allAdded =
                                                            grouped[g]!.every(
                                                              (m) => selected
                                                                  .contains(
                                                                    m.id,
                                                                  ),
                                                            );
                                                        return IconButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(
                                                                minWidth: 48,
                                                                minHeight: 40,
                                                              ),
                                                          tooltip: allAdded
                                                              ? l10n.providerDetailPageRemoveGroupTooltip
                                                              : l10n.providerDetailPageAddGroupTooltip,
                                                          icon: Icon(
                                                            allAdded
                                                                ? Lucide.Minus
                                                                : Lucide.Plus,
                                                            size: 24,
                                                            color: allAdded
                                                                ? cs.onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.7,
                                                                      )
                                                                : cs.onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.7,
                                                                      ),
                                                          ),
                                                          onPressed: () async {
                                                            final old = settings
                                                                .getProviderConfig(
                                                                  widget
                                                                      .keyName,
                                                                  defaultName:
                                                                      widget
                                                                          .displayName,
                                                                );
                                                            if (allAdded) {
                                                              final toRemove =
                                                                  grouped[g]!
                                                                      .map(
                                                                        (m) => m
                                                                            .id,
                                                                      )
                                                                      .toSet();
                                                              final list = old
                                                                  .models
                                                                  .where(
                                                                    (
                                                                      id,
                                                                    ) => !toRemove
                                                                        .contains(
                                                                          id,
                                                                        ),
                                                                  )
                                                                  .toList();
                                                              await settings
                                                                  .setProviderConfig(
                                                                    widget
                                                                        .keyName,
                                                                    old.copyWith(
                                                                      models:
                                                                          list,
                                                                    ),
                                                                  );
                                                            } else {
                                                              final toAdd = grouped[g]!
                                                                  .where(
                                                                    (
                                                                      m,
                                                                    ) => !selected
                                                                        .contains(
                                                                          m.id,
                                                                        ),
                                                                  )
                                                                  .map(
                                                                    (m) => m.id,
                                                                  )
                                                                  .toList();
                                                              if (toAdd
                                                                  .isEmpty) {
                                                                return;
                                                              }
                                                              final set =
                                                                  old.models
                                                                      .toSet()
                                                                    ..addAll(
                                                                      toAdd,
                                                                    );
                                                              await settings
                                                                  .setProviderConfig(
                                                                    widget
                                                                        .keyName,
                                                                    old.copyWith(
                                                                      models: set
                                                                          .toList(),
                                                                    ),
                                                                  );
                                                            }
                                                            setLocal(() {});
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        child: (collapsed[g] == true)
                                            ? const SizedBox.shrink()
                                            : Column(
                                                children: [
                                                  for (final m in grouped[g]!)
                                                    Builder(
                                                      builder: (c2) {
                                                        final added = selected
                                                            .contains(m.id);
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.fromLTRB(
                                                                12,
                                                                6,
                                                                12,
                                                                6,
                                                              ),
                                                          child: _TactileRow(
                                                            pressedScale: 0.98,
                                                            haptics: false,
                                                            onTap: () {},
                                                            builder: (_) {
                                                              return Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                    ),
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            10,
                                                                      ),
                                                                  child: Row(
                                                                    children: [
                                                                      SizedBox(
                                                                        width:
                                                                            28,
                                                                        child: Center(
                                                                          child: _BrandAvatar(
                                                                            name:
                                                                                m.id,
                                                                            size:
                                                                                28,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            16,
                                                                      ),
                                                                      Expanded(
                                                                        child: Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(
                                                                              m.displayName,
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: AppFontWeights.semibold,
                                                                              ),
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                            const SizedBox(
                                                                              height: 4,
                                                                            ),
                                                                            ModelTagWrap(
                                                                              model: m,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      IconButton(
                                                                        padding:
                                                                            EdgeInsets.zero,
                                                                        constraints: const BoxConstraints(
                                                                          minWidth:
                                                                              48,
                                                                          minHeight:
                                                                              40,
                                                                        ),
                                                                        onPressed: () async {
                                                                          final old = settings.getProviderConfig(
                                                                            widget.keyName,
                                                                            defaultName:
                                                                                widget.displayName,
                                                                          );
                                                                          final list = old
                                                                              .models
                                                                              .toList();
                                                                          if (added) {
                                                                            list.removeWhere(
                                                                              (
                                                                                e,
                                                                              ) =>
                                                                                  e ==
                                                                                  m.id,
                                                                            );
                                                                          } else {
                                                                            list.add(
                                                                              m.id,
                                                                            );
                                                                          }
                                                                          await settings.setProviderConfig(
                                                                            widget.keyName,
                                                                            old.copyWith(
                                                                              models: list,
                                                                            ),
                                                                          );
                                                                          setLocal(
                                                                            () {},
                                                                          );
                                                                        },
                                                                        icon: Icon(
                                                                          added
                                                                              ? Lucide.Minus
                                                                              : Lucide.Plus,
                                                                          size:
                                                                              24,
                                                                          color:
                                                                              added
                                                                              ? cs.onSurface.withValues(
                                                                                  alpha: 0.7,
                                                                                )
                                                                              : cs.onSurface.withValues(
                                                                                  alpha: 0.7,
                                                                                ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.providerKey,
    required this.modelId,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
    this.detectionResult,
    this.detectionErrorMessage,
    this.isDetecting = false,
    this.isPending = false,
  });
  final String providerKey;
  final String modelId;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;
  final bool? detectionResult;
  final String? detectionErrorMessage;
  final bool isDetecting;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final resolved = _resolveBaseAndOverride(context);
    final effective = resolved.ov == null
        ? resolved.base
        : _applyModelOverride(
            resolved.base,
            resolved.ov!,
            applyDisplayName: true,
          );
    String displayName = effective.displayName.trim();
    if (displayName.isEmpty) displayName = modelId;
    final Widget? detectionIndicator = isDetecting
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          )
        : isPending
        ? Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.onSurface.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          )
        : detectionResult != null
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: detectionResult!
                  ? l10n.providerDetailPageDetectSuccess
                  : (detectionErrorMessage ??
                        l10n.providerDetailPageDetectFailed),
              child: Icon(
                detectionResult! ? Lucide.CheckCircle : Lucide.XCircle,
                size: 16,
                color: detectionResult! ? Colors.green : cs.error,
              ),
            ),
          )
        : null;
    return _TactileRow(
      pressedScale: 0.98,
      haptics: false,
      onTap: isSelectionMode
          ? () => onSelectionChanged?.call(!isSelected)
          : () {},
      builder: (pressed) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  IosCheckbox(
                    value: isSelected,
                    onChanged: (value) => onSelectionChanged?.call(value),
                  ),
                  const SizedBox(width: 12),
                ],
                _BrandAvatar(name: resolved.baseId, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ModelTagWrap(model: effective),
                    ],
                  ),
                ),
                if (detectionIndicator != null) ...[
                  const SizedBox(width: 8),
                  detectionIndicator,
                ],
                if (!isSelectionMode) ...[
                  const SizedBox(width: 8),
                  _TactileIconButton(
                    icon: Lucide.Settings2,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    size: 18,
                    semanticLabel: l10n.providerDetailPageEditTooltip,
                    haptics: false,
                    onTap: () async {
                      await showModelDetailSheet(
                        context,
                        providerKey: providerKey,
                        modelId: modelId,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  ModelInfo _infer(String id) {
    // build a minimal ModelInfo and let registry infer
    return ModelRegistry.infer(ModelInfo(id: id, displayName: id));
  }

  _ResolvedModelOverride _resolveBaseAndOverride(BuildContext context) {
    final configs = context.watch<SettingsProvider>().providerConfigs;
    final cfg = configs[providerKey];
    if (cfg == null) {
      final base = _infer(modelId);
      return _ResolvedModelOverride(base: base, ov: null, baseId: modelId);
    }
    final rawOv = cfg.modelOverrides[modelId];
    final Map<String, dynamic>? ov = rawOv is Map
        ? {for (final e in rawOv.entries) e.key.toString(): e.value}
        : null;
    String baseId = modelId;
    if (ov != null) {
      final raw = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
      if (raw != null && raw.isNotEmpty) baseId = raw;
    }
    final base = _infer(baseId);
    return _ResolvedModelOverride(base: base, ov: ov, baseId: baseId);
  }
}

class _ResolvedModelOverride {
  const _ResolvedModelOverride({
    required this.base,
    required this.ov,
    required this.baseId,
  });

  final ModelInfo base;
  final Map<String, dynamic>? ov;
  final String baseId;
}

class _ConnectionTestDialog extends StatefulWidget {
  const _ConnectionTestDialog({
    required this.providerKey,
    required this.providerDisplayName,
  });
  final String providerKey;
  final String providerDisplayName;

  @override
  State<_ConnectionTestDialog> createState() => _ConnectionTestDialogState();
}

enum _TestState { idle, loading, success, error }

class _ConnectionTestDialogState extends State<_ConnectionTestDialog> {
  String? _selectedModelId;
  _TestState _state = _TestState.idle;
  String _errorMessage = '';
  bool _useStream = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.providerDetailPageTestConnectionTitle;
    final canTest = _selectedModelId != null && _state != _TestState.loading;
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildBody(context, cs, l10n),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.providerDetailPageCancelButton),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: canTest ? _doTest : null,
                    style: TextButton.styleFrom(
                      foregroundColor: canTest
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.4),
                    ),
                    child: Text(l10n.providerDetailPageTestButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    switch (_state) {
      case _TestState.idle:
        return _buildIdle(context, cs, l10n);
      case _TestState.loading:
        return _buildLoading(context, cs, l10n);
      case _TestState.success:
        return _buildResult(
          context,
          cs,
          l10n,
          success: true,
          message: l10n.providerDetailPageTestSuccessMessage,
        );
      case _TestState.error:
        return _buildResult(
          context,
          cs,
          l10n,
          success: false,
          message: _errorMessage,
        );
    }
  }

  Widget _buildIdle(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_selectedModelId == null)
          TextButton(
            onPressed: _pickModel,
            child: Text(l10n.providerDetailPageSelectModelButton),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrandAvatar(name: _selectedModelId!, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _selectedModelId!,
                  style: TextStyle(fontWeight: AppFontWeights.semibold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _pickModel,
                child: Text(l10n.providerDetailPageChangeButton),
              ),
            ],
          ),
        if (_selectedModelId != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.providerDetailPageUseStreamingLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 8),
              IosSwitch(
                value: _useStream,
                onChanged: (v) => setState(() => _useStream = v),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLoading(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_selectedModelId != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrandAvatar(name: _selectedModelId!, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _selectedModelId!,
                  style: TextStyle(fontWeight: AppFontWeights.semibold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        const LinearProgressIndicator(minHeight: 4),
        const SizedBox(height: 12),
        Text(
          l10n.providerDetailPageTestingMessage,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildResult(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n, {
    required bool success,
    required String message,
  }) {
    final color = success ? Colors.green : cs.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_selectedModelId != null)
          _TactileRow(
            pressedScale: 0.98,
            haptics: false,
            onTap: _pickModel,
            builder: (_) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _BrandAvatar(name: _selectedModelId!, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedModelId!,
                        style: TextStyle(fontWeight: AppFontWeights.semibold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Lucide.ChevronDown,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 14),
        Text(
          message,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: AppFontWeights.semibold,
          ),
        ),
      ],
    );
  }

  Future<void> _pickModel() async {
    final selected = await showModelPickerForTest(
      context,
      widget.providerKey,
      widget.providerDisplayName,
    );
    if (selected != null) {
      setState(() {
        _selectedModelId = selected;
        _state = _TestState.idle;
        _errorMessage = '';
      });
    }
  }

  Future<void> _doTest() async {
    if (_selectedModelId == null) return;
    setState(() {
      _state = _TestState.loading;
      _errorMessage = '';
    });
    try {
      final cfg = context.read<SettingsProvider>().getProviderConfig(
        widget.providerKey,
        defaultName: widget.providerDisplayName,
      );
      await ProviderManager.testConnection(
        cfg,
        _selectedModelId!,
        useStream: _useStream,
      );
      if (!mounted) return;
      setState(() => _state = _TestState.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _TestState.error;
        _errorMessage = e.toString();
      });
    }
  }
}

Future<String?> showModelPickerForTest(
  BuildContext context,
  String providerKey,
  String providerDisplayName,
) async {
  final sel = await showModelSelector(context, limitProviderKey: providerKey);
  return sel?.modelId;
}

ModelInfo _applyModelOverride(
  ModelInfo base,
  Map<String, dynamic> ov, {
  bool applyDisplayName = false,
}) {
  try {
    return ModelOverrideResolver.applyModelOverride(
      base,
      ov,
      applyDisplayName: applyDisplayName,
    );
  } catch (e, st) {
    FlutterLogger.log(
      '[ModelOverride] applyModelOverride failed: $e\n$st',
      tag: 'ModelOverride',
    );
    assert(() {
      debugPrint('[ModelOverride] applyModelOverride failed: $e');
      return true;
    }());
    return base;
  }
}

// Using flutter_slidable for reliable swipe actions with confirm + undo.

// Legacy page-based implementations removed in favor of swipeable PageView tabs.

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.name, this.size = 20});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    final lower = name.toLowerCase();
    final bool mono =
        isDark &&
        (RegExp(r'openai|gpt|o\\d').hasMatch(lower) ||
            RegExp(r'grok|xai').hasMatch(lower) ||
            RegExp(r'openrouter').hasMatch(lower));
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: isDark
          ? Colors.white10
          : cs.primary.withValues(alpha: 0.1),
      child: asset == null
          ? Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
              style: TextStyle(
                color: cs.primary,
                fontSize: size * 0.5,
                fontWeight: AppFontWeights.emphasis,
              ),
            )
          : (asset.endsWith('.svg')
                ? SvgPicture.asset(
                    asset,
                    width: size * 0.7,
                    height: size * 0.7,
                    colorFilter: mono
                        ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                        : null,
                  )
                : Image.asset(
                    asset,
                    width: size * 0.7,
                    height: size * 0.7,
                    fit: BoxFit.contain,
                    color: mono ? Colors.white : null,
                    colorBlendMode: mono ? BlendMode.srcIn : null,
                  )),
    );
  }
}

// Top-level tactile row used by iOS-style lists here
class _TactileRow extends StatefulWidget {
  const _TactileRow({
    required this.builder,
    this.onTap,
    this.pressedScale = 1.00,
    this.haptics = true,
  });
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

// Icon-only tactile button for AppBar (no ripple, slight press scale)
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
    this.size = 22,
    this.haptics = true,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double size;
  final bool haptics;

  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withValues(alpha: 0.7);
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: _pressed ? pressColor : base,
      semanticLabel: widget.semanticLabel,
    );

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          // if (widget.haptics) Haptics.light();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics &&
                  context.read<SettingsProvider>().hapticsOnListItemTap) {
                Haptics.soft();
              }
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.builder(_pressed),
      ),
    );
  }
}

// Bottom tactile tabs (two items) without ripple
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.index,
    required this.leftIcon,
    required this.leftLabel,
    required this.rightIcon,
    required this.rightLabel,
    required this.onSelect,
  });
  final int index;
  final IconData leftIcon;
  final String leftLabel;
  final IconData rightIcon;
  final String rightLabel;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.12),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _BottomTabItem(
              icon: leftIcon,
              label: leftLabel,
              selected: index == 0,
              onTap: () => onSelect(0),
            ),
          ),
          Expanded(
            child: _BottomTabItem(
              icon: rightIcon,
              label: rightLabel,
              selected: index == 1,
              onTap: () => onSelect(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomTabItem extends StatefulWidget {
  const _BottomTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BottomTabItem> createState() => _BottomTabItemState();
}

class _BottomTabItemState extends State<_BottomTabItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.onSurface.withValues(alpha: 0.7);
    final selColor = cs.primary;
    final target = widget.selected ? selColor : baseColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: target),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, color, _) {
          final c = color ?? baseColor;
          return AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 20, color: c),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFontWeights.semibold,
                      color: c,
                    ),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PromptCachingTtlSegmentedControl extends StatelessWidget {
  const _PromptCachingTtlSegmentedControl({
    required this.value,
    required this.fiveMinuteLabel,
    required this.oneHourLabel,
    required this.semanticLabel,
    required this.onChanged,
  });

  final String value;
  final String fiveMinuteLabel;
  final String oneHourLabel;
  final String semanticLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PromptCachingTtlSegment(
              label: fiveMinuteLabel,
              selected: value == ProviderConfig.claudePromptCachingTtl5m,
              selectedColor: cs.primary,
              onTap: () => onChanged(ProviderConfig.claudePromptCachingTtl5m),
            ),
            _PromptCachingTtlSegment(
              label: oneHourLabel,
              selected: value == ProviderConfig.claudePromptCachingTtl1h,
              selectedColor: cs.primary,
              onTap: () => onChanged(ProviderConfig.claudePromptCachingTtl1h),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptCachingTtlSegment extends StatelessWidget {
  const _PromptCachingTtlSegment({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: selected
                ? cs.onPrimary
                : cs.onSurface.withValues(alpha: 0.7),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
