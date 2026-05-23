import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';

class CitationSourceItem {
  const CitationSourceItem({
    required this.title,
    required this.url,
    this.text = '',
    this.index,
    this.sourceName,
    this.webSiteSource,
    this.publishedText,
    this.tags = const <CitationSourceTag>[],
  });

  factory CitationSourceItem.fromMap(
    Map<String, dynamic> map, {
    required int fallbackIndex,
  }) {
    return CitationSourceItem(
      index: _intValue(map['index']) ?? fallbackIndex,
      title: (map['title'] ?? '').toString(),
      url: (map['url'] ?? '').toString(),
      text: (map['text'] ?? map['quote'] ?? map['snippet'] ?? '').toString(),
      sourceName:
          (map['sourceName'] ?? map['source_name'] ?? map['web_site_name'])
              ?.toString(),
      webSiteSource: map['webSiteSource']?.toString(),
      publishedText: (map['publish_time'] ?? map['publishedText'])?.toString(),
      tags: _tagsFrom(map['tags']),
    );
  }

  final int? index;
  final String title;
  final String url;
  final String text;
  final String? sourceName;
  final String? webSiteSource;
  final String? publishedText;
  final List<CitationSourceTag> tags;
}

class CitationSourceTag {
  const CitationSourceTag({required this.title, this.description});

  final String title;
  final String? description;
}

class CitationSourcesSheet extends StatelessWidget {
  const CitationSourcesSheet({
    super.key,
    required this.title,
    required this.items,
    required this.onDismiss,
    required this.onOpen,
    this.count,
    this.closeSemanticLabel,
  });

  final String title;
  final int? count;
  final String? closeSemanticLabel;
  final List<CitationSourceItem> items;
  final VoidCallback onDismiss;
  final ValueChanged<CitationSourceItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: title,
      count: count ?? items.length,
      closeSemanticLabel: closeSemanticLabel,
      onDismiss: onDismiss,
      builder: (context, controller) => _CitationSourceList(
        controller: controller,
        items: items,
        onOpen: onOpen,
      ),
    );
  }
}

Future<void> showCitationSourcesBottomSheet({
  required BuildContext context,
  required String title,
  required String closeSemanticLabel,
  required List<CitationSourceItem> items,
  required ValueChanged<CitationSourceItem> onOpen,
}) {
  return showCustomBottomSheet<void>(
    context: context,
    title: title,
    count: items.length,
    closeSemanticLabel: closeSemanticLabel,
    builder: (context, controller) => _CitationSourceList(
      controller: controller,
      items: items,
      onOpen: onOpen,
    ),
  );
}

class _CitationSourceList extends StatelessWidget {
  const _CitationSourceList({
    required this.controller,
    required this.items,
    required this.onOpen,
  });

  final ScrollController controller;
  final List<CitationSourceItem> items;
  final ValueChanged<CitationSourceItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: SizedBox(height: 16),
          );
        }
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: CitationSourceCard(
            item: item,
            displayIndex: index,
            onTap: () => onOpen(item),
          ),
        );
      },
    );
  }
}

class CitationSourceCard extends StatelessWidget {
  const CitationSourceCard({
    super.key,
    required this.item,
    required this.displayIndex,
    required this.onTap,
  });

  final CitationSourceItem item;
  final int displayIndex;
  final VoidCallback onTap;

  static final RegExp _pureNumber = RegExp(r'^\d+$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final domain = _domain(item.url);
    final title = _displayTitle(domain);
    final quoteText = _quoteText();
    final sourceParts = _sourceParts(domain);

    return IosCardPress(
      borderRadius: BorderRadius.circular(12),
      baseColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.50)
          : cs.surfaceContainerHighest.withValues(alpha: 0.45),
      pressedScale: 1.0,
      duration: const Duration(milliseconds: 200),
      haptics: false,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(8, 20, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sourceParts.isNotEmpty || domain.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  _FaviconIcon(domain: domain),
                  const SizedBox(width: 4),
                  Expanded(child: _SourceParts(parts: sourceParts)),
                  _IndexBadge(index: item.index ?? displayIndex + 1),
                ],
              ),
            ),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          if (quoteText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              quoteText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ],
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 3),
            SizedBox(
              height: 24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.tags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  return _CitationTag(tag: item.tags[index]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _displayTitle(String domain) {
    final trimmed = item.title.trim();
    if (trimmed.isNotEmpty && !_pureNumber.hasMatch(trimmed)) return trimmed;
    return domain.isNotEmpty ? domain : item.url;
  }

  String _quoteText() {
    final quote = item.text.trim();
    if (quote.isEmpty) return '';
    final published = (item.publishedText ?? '').trim();
    if (published.isEmpty) return quote;
    return '$published - $quote';
  }

  List<String> _sourceParts(String domain) {
    final parts = <String>[
      if ((item.sourceName ?? '').trim().isNotEmpty) item.sourceName!.trim(),
      if ((item.webSiteSource ?? '').trim().isNotEmpty)
        item.webSiteSource!.trim(),
    ];
    if (parts.isEmpty && domain.isNotEmpty) parts.add(domain);
    return parts;
  }
}

class _FaviconIcon extends StatelessWidget {
  const _FaviconIcon({required this.domain});

  final String domain;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (domain.isEmpty) {
      return Icon(
        Lucide.Globe,
        size: 14,
        color: cs.onSurface.withValues(alpha: 0.52),
      );
    }
    return ClipOval(
      child: Image.network(
        'https://favicone.com/$domain',
        width: 14,
        height: 14,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Lucide.Globe,
          size: 14,
          color: cs.onSurface.withValues(alpha: 0.52),
        ),
      ),
    );
  }
}

class _SourceParts extends StatelessWidget {
  const _SourceParts({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0) _InlineDivider(color: cs.onSurface),
          Flexible(
            child: Text(
              parts[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.56),
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineDivider extends StatelessWidget {
  const _InlineDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        width: 2.5,
        height: 2.5,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});

  final int index;

  static ValueKey<String> badgeKey(int index) =>
      ValueKey<String>('citation_source_index_badge_$index');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: badgeKey(index),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: EdgeInsets.symmetric(horizontal: index >= 10 ? 5 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          width: 0.5,
          color: cs.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        index.toString(),
        style: TextStyle(
          color: cs.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _CitationTag extends StatelessWidget {
  const _CitationTag({required this.tag});

  final CitationSourceTag tag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tagText = Text(
      tag.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.62),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );
    final content = Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: tagText,
    );
    final description = tag.description?.trim();
    if (description == null || description.isEmpty) return content;
    return Tooltip(message: description, child: content);
  }
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

List<CitationSourceTag> _tagsFrom(Object? value) {
  if (value is! List) return const <CitationSourceTag>[];
  return [
    for (final tag in value)
      if (tag is Map && (tag['title'] ?? '').toString().trim().isNotEmpty)
        CitationSourceTag(
          title: tag['title'].toString(),
          description: tag['desc']?.toString(),
        ),
  ];
}

String _domain(String url) {
  final uri = _normalizeUri(url);
  return uri?.host ?? '';
}

Uri? _normalizeUri(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('//')) {
    value = 'https:$value';
  } else if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(value)) {
    value = 'https://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
    return null;
  }
  return uri;
}
