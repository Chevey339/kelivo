import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';

Future<void> showAssistantMcpSheet(BuildContext context, {required String assistantId}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AssistantMcpSheet(assistantId: assistantId),
  );
}

class _AssistantMcpSheet extends StatelessWidget {
  const _AssistantMcpSheet({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final mcp = context.watch<McpProvider>();
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;

    final selected = a.mcpServerIds.toSet();
    final servers = mcp.servers.where((s) => mcp.statusFor(s.id) == McpStatus.connected).toList();

    Widget tag(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.primary.withOpacity(0.35)),
          ),
          child: Text(text, style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600)),
        );

    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        l10n.mcpAssistantSheetTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (servers.isNotEmpty) ...[
                      Positioned(
                        left: 0,
                        child: IosIconButton(
                          icon: Lucide.X,
                          size: 18,
                          minSize: 34,
                          padding: const EdgeInsets.all(8),
                          onTap: () async {
                            Haptics.light();
                            final next = a.copyWith(mcpServerIds: const <String>[]);
                            await context.read<AssistantProvider>().updateAssistant(next);
                          },
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: IosIconButton(
                          icon: Lucide.Check,
                          size: 18,
                          minSize: 34,
                          padding: const EdgeInsets.all(8),
                          onTap: () async {
                            Haptics.light();
                            final ids = servers.map((e) => e.id).toList(growable: false);
                            final next = a.copyWith(mcpServerIds: ids);
                            await context.read<AssistantProvider>().updateAssistant(next);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: servers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          l10n.assistantEditMcpNoServersMessage,
                          style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                          final s = servers[index];
                          final tools = s.tools;
                          final enabledTools = tools.where((t) => t.enabled).length;
                          final isSelected = selected.contains(s.id);
                          return IosCardPress(
                            borderRadius: BorderRadius.circular(14),
                            baseColor: cs.surface,
                            duration: const Duration(milliseconds: 260),
                            onTap: () async {
                              Haptics.light();
                              final set = a.mcpServerIds.toSet();
                              if (isSelected) set.remove(s.id); else set.add(s.id);
                              await context.read<AssistantProvider>().updateAssistant(a.copyWith(mcpServerIds: set.toList()));
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Lucide.Hammer, size: 18, color: cs.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Tools count tag moved to right side before switch
                                tag(l10n.assistantEditMcpToolsCountTag(enabledTools.toString(), tools.length.toString())),
                                const SizedBox(width: 8),
                                IosSwitch(
                                  value: isSelected,
                                  onChanged: (v) async {
                                    final set = a.mcpServerIds.toSet();
                                    if (v) set.add(s.id); else set.remove(s.id);
                                    await context.read<AssistantProvider>().updateAssistant(a.copyWith(mcpServerIds: set.toList()));
                                  },
                                ),
                              ],
                            ),
                          );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemCount: servers.length,
                    ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
