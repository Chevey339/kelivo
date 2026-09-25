import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/chat/chat_service.dart';
import '../../../features/home/services/context_usage_service.dart';
import '../../../features/model/pages/model_spec_edit_page.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_usage_details.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';

class ContextUsageHeader extends StatefulWidget {
  const ContextUsageHeader({
    super.key,
    this.conversationId,
    this.draftText = '',
  });

  final String? conversationId;
  final String draftText;

  @override
  State<ContextUsageHeader> createState() => _ContextUsageHeaderState();
}

class _ContextUsageHeaderState extends State<ContextUsageHeader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh(force: false);
    });
  }

  String? get _conversationId {
    final explicit = widget.conversationId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return context.read<ChatService?>()?.currentConversationId;
  }

  Future<void> _refresh({required bool force}) async {
    final id = _conversationId;
    final usage = context.read<ContextUsageService?>();
    if (id == null || usage == null) return;
    await usage.refresh(
      id,
      draftText: force ? null : widget.draftText,
      force: force,
    );
  }

  Future<void> _openSetWindow(ContextUsageSnapshot snapshot) async {
    if (snapshot.providerKey.isEmpty || snapshot.modelId.isEmpty) return;
    final saved = await showModelSpecEditPage(
      context,
      providerKey: snapshot.providerKey,
      modelKey: snapshot.modelId,
    );
    if (saved == true && mounted) {
      await _refresh(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<ContextUsageService?>();
    final id = _conversationId;
    final snapshot = id == null
        ? usage?.current
        : usage?.snapshot(id) ?? usage?.current;
    final showSetWindow =
        snapshot != null &&
        snapshot.contextWindow == null &&
        snapshot.providerKey.isNotEmpty &&
        snapshot.modelId.isNotEmpty;

    return Column(
      key: const ValueKey('context-usage-header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContextUsageBreakdown(snapshot: snapshot),
        if (showSetWindow) ...[
          const SizedBox(height: 12),
          _SetWindowRow(onTap: () => _openSetWindow(snapshot)),
        ],
      ],
    );
  }
}

class _SetWindowRow extends StatelessWidget {
  const _SetWindowRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);
    return IosCardPress(
      key: const ValueKey('context-usage-set-window'),
      baseColor: sheetTileColor(context),
      borderRadius: radius,
      pressedScale: 0.98,
      duration: const Duration(milliseconds: 260),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Lucide.Settings2, size: 22, color: cs.onSurface),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.contextUsageSetWindow,
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
