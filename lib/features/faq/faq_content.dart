import 'package:flutter/material.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../theme/app_font_weights.dart';
import 'faq_data.dart';

class FaqContent extends StatefulWidget {
  final String? initialEntryKey;

  const FaqContent({super.key, this.initialEntryKey});

  @override
  State<FaqContent> createState() => _FaqContentState();
}

class _FaqContentState extends State<FaqContent> {
  final Map<String, bool> _expanded = {};
  final Map<String, GlobalKey> _cardKeys = {};
  final ScrollController _scrollController = ScrollController();
  bool _highlighted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEntryKey != null) {
      _expanded[widget.initialEntryKey!] = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEntry(widget.initialEntryKey!);
        setState(() => _highlighted = true);
      });
    }
  }

  void _scrollToEntry(String key) {
    final ctx = _cardKeys[key]?.currentContext;
    if (ctx != null && ctx.findRenderObject() != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = faqItems(l10n);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: items.map((item) {
        if (item is FaqSectionHeader) {
          return _buildSectionHeader(context, l10n, item);
        }
        if (item is FaqEntryItem) {
          return _buildEntryCard(context, l10n, item);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    AppLocalizations l10n,
    FaqSectionHeader section,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        section.title(l10n),
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    AppLocalizations l10n,
    FaqEntryItem entry,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isExpanded = _expanded[entry.key] ?? false;
    final isHighlighted = _highlighted && widget.initialEntryKey == entry.key;

    _cardKeys.putIfAbsent(entry.key, () => GlobalKey());
    return Padding(
      key: _cardKeys[entry.key],
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isHighlighted
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IosCardPress(
              onTap: () => setState(() {
                _expanded[entry.key] = !isExpanded;
                _highlighted = false;
              }),
              borderRadius: BorderRadius.circular(14),
              baseColor: Colors.transparent,
              pressedBlendStrength: 0.06,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    entry.icon,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.title(l10n),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.medium,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Lucide.ChevronUp : Lucide.ChevronDown,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  entry.summary(l10n),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
