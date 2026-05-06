part of 'assistant_settings_edit_page.dart';

class _McpTab extends StatelessWidget {
  const _McpTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final mcp = context.watch<McpProvider>();
    final ap = context.watch<AssistantProvider>();
    final assistant = ap.getById(assistantId)!;

    final selected = assistant.mcpServerIds.toSet();
    final servers = mcp.servers
        .where((server) => mcp.statusFor(server.id) == McpStatus.connected)
        .toList();

    Future<void> updateSelected(Set<String> ids) {
      return context.read<AssistantProvider>().updateAssistant(
        assistant.copyWith(mcpServerIds: ids.toList(growable: false)),
      );
    }

    Widget tag(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        _iosSectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Icon(Lucide.Hammer, size: 20, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mcpAssistantSheetTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.mcpAssistantSheetSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (servers.isNotEmpty) ...[
                    IosIconButton(
                      icon: Lucide.X,
                      size: 18,
                      minSize: 34,
                      padding: const EdgeInsets.all(8),
                      onTap: () async {
                        Haptics.light();
                        await updateSelected(<String>{});
                      },
                    ),
                    const SizedBox(width: 2),
                    IosIconButton(
                      icon: Lucide.Check,
                      size: 18,
                      minSize: 34,
                      padding: const EdgeInsets.all(8),
                      onTap: () async {
                        Haptics.light();
                        await updateSelected(
                          servers.map((server) => server.id).toSet(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (servers.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                child: Center(
                  child: Text(
                    l10n.assistantEditMcpNoServersMessage,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else
              for (final server in servers) ...[
                _iosDivider(context),
                _McpServerRow(
                  server: server,
                  selected: selected.contains(server.id),
                  toolsTag: tag(
                    l10n.assistantEditMcpToolsCountTag(
                      server.tools
                          .where((tool) => tool.enabled)
                          .length
                          .toString(),
                      server.tools.length.toString(),
                    ),
                  ),
                  onChanged: (enabled) async {
                    final ids = selected.toSet();
                    if (enabled) {
                      ids.add(server.id);
                    } else {
                      ids.remove(server.id);
                    }
                    await updateSelected(ids);
                  },
                ),
              ],
          ],
        ),
      ],
    );
  }
}

class _McpServerRow extends StatelessWidget {
  const _McpServerRow({
    required this.server,
    required this.selected,
    required this.toolsTag,
    required this.onChanged,
  });

  final McpServerConfig server;
  final bool selected;
  final Widget toolsTag;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      onTap: () => onChanged(!selected),
      builder: (pressed) {
        final baseColor = cs.onSurface.withValues(alpha: 0.9);
        return _AnimatedPressColor(
          pressed: pressed,
          base: baseColor,
          builder: (color) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Icon(Lucide.Hammer, size: 20, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  toolsTag,
                  const SizedBox(width: 8),
                  IosSwitch(value: selected, onChanged: onChanged),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
