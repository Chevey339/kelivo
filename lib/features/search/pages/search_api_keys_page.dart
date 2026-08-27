import 'package:flutter/material.dart';

import '../../../core/services/search/search_api_key_rotator.dart';
import '../../../core/services/search/search_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

/// Full-page manager for a search service's API key rotation pool.
///
/// The list shown here is the exact rotation order: the first key is the
/// primary key stored in `apiKey`, the rest are `extraApiKeys`. Popping the
/// page returns the full pool as a `List<String>`.
///
/// Per-key usage is intentionally not queried here: hammering the usage
/// endpoint for every key would risk provider rate limits (HTTP 429).
class SearchApiKeysPage extends StatefulWidget {
  const SearchApiKeysPage({
    super.key,
    required this.service,
    required this.commonOptions,
    required this.onPop,
  });

  final SearchServiceOptions service;
  final SearchCommonOptions commonOptions;
  final ValueChanged<List<String>> onPop;

  @override
  State<SearchApiKeysPage> createState() => _SearchApiKeysPageState();
}

class _SearchApiKeysPageState extends State<SearchApiKeysPage> {
  late final List<String> _keys = SearchApiKeyRotator.rotationPool(
    widget.service.primaryApiKey,
    widget.service.extraApiKeys,
  );
  final _addController = TextEditingController();
  final Set<int> _revealed = {};
  ({int added, int skipped})? _batchFeedback;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addKeys() {
    final parsed = SearchApiKeyRotator.parseBatch(_addController.text);
    if (parsed.isEmpty) return;
    final existing = _keys.toSet();
    final fresh = parsed.where((key) => !existing.contains(key)).toList();
    setState(() {
      _keys.addAll(fresh);
      _addController.clear();
      _batchFeedback = (
        added: fresh.length,
        skipped: parsed.length - fresh.length,
      );
    });
  }

  void _removeKey(int index) {
    setState(() {
      _keys.removeAt(index);
      _revealed.clear();
    });
  }

  void _popWithPool() {
    Navigator.of(context).pop(List<String>.unmodifiable(_keys));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return PopScope<List<String>>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null) {
          widget.onPop(List<String>.unmodifiable(_keys));
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          leading: Tooltip(
            message: l10n.searchServicesPageBackTooltip,
            child: _PageIconButton(
              icon: Lucide.ArrowLeft,
              semanticLabel: l10n.searchServicesPageBackTooltip,
              onTap: _popWithPool,
            ),
          ),
          title: Text(l10n.searchServiceEditorMultiKeyTitle),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildIntro(context),
                  const SizedBox(height: 12),
                  _buildKeysCard(context),
                  const SizedBox(height: 12),
                  _buildAddCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        l10n.searchApiKeysPageDescription,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.45,
          color: cs.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }

  Widget _buildKeysCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (_keys.isEmpty) {
      return SectionCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            l10n.searchApiKeysPageEmpty,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ),
      );
    }
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < _keys.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 0.6,
                  indent: 28,
                  color: cs.outlineVariant.withValues(alpha: 0.16),
                ),
              _buildKeyRow(context, i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final key = _keys[index];
    final revealed = _revealed.contains(index);
    final isPrimary = index == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            Lucide.KeyRound,
            size: 16,
            color: isPrimary ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    revealed ? key : SearchApiKeyRotator.mask(key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (isPrimary) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.searchApiKeysPagePrimaryBadge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _PageIconButton(
            icon: revealed ? Lucide.EyeOff : Lucide.Eye,
            size: 18,
            semanticLabel: key,
            onTap: () => setState(() {
              revealed ? _revealed.remove(index) : _revealed.add(index);
            }),
          ),
          _PageIconButton(
            icon: Lucide.Trash2,
            size: 18,
            color: cs.error,
            semanticLabel: key,
            onTap: () => _removeKey(index),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final feedback = _batchFeedback;
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _addController,
              minLines: 1,
              maxLines: 4,
              key: const ValueKey('search-api-keys-batch-field'),
              onChanged: (_) {
                if (_batchFeedback != null) {
                  setState(() => _batchFeedback = null);
                }
              },
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurface.withValues(alpha: 0.92),
              ),
              decoration: InputDecoration(
                hintText: l10n.searchApiKeysPageBatchHint,
                isDense: true,
                filled: true,
                fillColor: context.appColors.surfaceFill,
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: feedback == null
                      ? const SizedBox.shrink()
                      : Text(
                          l10n.searchApiKeysPageBatchResult(
                            '${feedback.added}',
                            '${feedback.skipped}',
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: feedback.added > 0
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                ),
                _AddButton(label: l10n.searchApiKeysPageAdd, onTap: _addKeys),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIconButton extends StatefulWidget {
  const _PageIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.color,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final Color? color;
  final double size;

  @override
  State<_PageIconButton> createState() => _PageIconButtonState();
}

class _PageIconButtonState extends State<_PageIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.color ?? cs.onSurface;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressed
                    ? cs.onSurface.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: widget.size, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? cs.primary.withValues(alpha: 0.18)
        : cs.primary.withValues(alpha: 0.11);
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _pressed
                ? Color.alphaBlend(cs.onSurface.withValues(alpha: 0.08), base)
                : base,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.28),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Lucide.Plus, size: 16, color: cs.primary),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
