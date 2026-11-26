import 'package:flutter/material.dart';

import '../../../core/models/avatar_config.dart';
import '../../../core/services/search/search_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/configurable_avatar.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/icon_cache.dart';
import '../../provider/widgets/avatar_picker.dart';

class SearchServiceAvatar extends StatelessWidget {
  const SearchServiceAvatar({
    super.key,
    required this.brand,
    this.avatar,
    this.size = 24,
    this.compact = false,
  });

  factory SearchServiceAvatar.forService(
    SearchServiceOptions service, {
    AvatarConfig? avatar,
    double size = 24,
    bool compact = false,
  }) => SearchServiceAvatar(
    brand: _brandForService(service),
    avatar: avatar,
    size: size,
    compact: compact,
  );

  final String brand;
  final AvatarConfig? avatar;
  final double size;
  final bool compact;

  static String _brandForService(SearchServiceOptions service) =>
      switch (service) {
        BingLocalOptions() => 'bing',
        DuckDuckGoOptions() => 'duckduckgo',
        TavilyOptions() => 'tavily',
        ExaOptions() || ExaMcpOptions() => 'exa',
        ZhipuOptions() => 'zhipu',
        SearXNGOptions() => 'searxng',
        FourGetOptions() => '4get',
        LinkUpOptions() => 'linkup',
        BraveOptions() => 'brave',
        MetasoOptions() => 'metaso',
        OllamaOptions() => 'ollama',
        DeepSeekOptions() => 'deepseek',
        JinaOptions() => 'jina',
        PerplexityOptions() => 'perplexity',
        BochaOptions() => 'bocha',
        DoubaoOptions() => 'doubao',
        KagiOptions() => 'kagi',
        SerperOptions() => 'serper',
        QueritOptions() => 'querit',
        GrokOptions() => 'grok',
        StepFunOptions() => 'stepfun',
        FirecrawlOptions() => 'firecrawl',
        TinyFishOptions() => 'tinyfish',
        AnySearchOptions() => 'anysearch',
        ParallelOptions() => 'parallel',
        KimiOptions() => 'kimi',
        YouSearchOptions() => 'you',
        KeenableOptions() => 'keenable',
        KelivoOptions() => 'kelivo',
        _ => 'search',
      };

  @override
  Widget build(BuildContext context) => ConfigurableAvatar(
    avatar: avatar,
    name: brand,
    size: size,
    iconScale: compact ? 1 : .62,
    withBackground: !compact,
    normalizeRemoteIcons: true,
  );
}

class SearchServiceAvatarButton extends StatefulWidget {
  const SearchServiceAvatarButton({
    super.key,
    required this.service,
    required this.avatar,
    required this.onChanged,
    required this.desktop,
    this.enabled = true,
  });

  final SearchServiceOptions service;
  final AvatarConfig? avatar;
  final ValueChanged<AvatarConfig?> onChanged;
  final bool desktop;
  final bool enabled;

  @override
  State<SearchServiceAvatarButton> createState() =>
      _SearchServiceAvatarButtonState();
}

class _SearchServiceAvatarButtonState extends State<SearchServiceAvatarButton> {
  final _anchor = GlobalKey();

  Future<void> _pick() async {
    try {
      await showAvatarPicker(
        context,
        desktop: widget.desktop,
        anchorKey: _anchor,
        current: widget.avatar,
        onSelected: (avatar) => widget.onChanged(avatar),
        validateImageUrl: IconCache.isWebUri,
        keyPrefix: 'search-service-avatar-input',
      );
    } catch (_) {
      if (mounted) showSearchServiceIconError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = widget.desktop ? 28.0 : 38.0;
    return IosIconButton(
      key: _anchor,
      enabled: widget.enabled,
      onTap: _pick,
      minSize: widget.desktop ? 34 : 44,
      padding: EdgeInsets.zero,
      tooltip: AppLocalizations.of(context)!.searchServiceEditorChangeIcon,
      builder: (color) => Stack(
        children: [
          SearchServiceAvatar.forService(
            widget.service,
            avatar: widget.avatar,
            size: size,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Lucide.Pencil, size: 10, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<AvatarConfig?> saveSearchServiceAvatar(
  AvatarConfig? avatar,
  AvatarConfig? initialAvatar,
) async {
  if (avatar == initialAvatar || avatar?.type != AvatarType.file) {
    return avatar;
  }
  final name = await IconCache.importAvatarFile(avatar!.value);
  return AvatarConfig(
    type: AvatarType.file,
    value: 'kelivo-file:///avatars/${Uri.encodeComponent(name)}',
  );
}

void showSearchServiceIconError(BuildContext context) => showAppSnackBar(
  context,
  message: AppLocalizations.of(context)!.searchServiceEditorIconFailed,
  type: NotificationType.error,
);
