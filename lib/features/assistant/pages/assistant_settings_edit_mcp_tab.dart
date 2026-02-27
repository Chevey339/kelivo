part of 'assistant_settings_edit_page.dart';

class _McpTab extends StatelessWidget {
  const _McpTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;
    final mcp = context.watch<McpProvider>();
    final servers = mcp.servers
        .where((s) => mcp.statusFor(s.id) == McpStatus.connected)
        .toList();

    if (servers.isEmpty) {
      return Center(
        child: Text(
          l10n.assistantEditMcpNoServersMessage,
          style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
        ),
      );
    }

    Widget tag(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(0.35)),
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = servers[index];
        final tools = s.tools;
        final enabledTools = tools.where((t) => t.enabled).length;
        final isSelected = a.mcpServerIds.contains(s.id);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isSelected
            ? cs.primary.withOpacity(isDark ? 0.12 : 0.10)
            : (isDark ? Colors.white10 : cs.surface);
        final borderColor = isSelected
            ? cs.primary.withOpacity(0.45)
            : cs.outlineVariant.withOpacity(0.25);

        return _TactileRow(
          onTap: () async {
            final set = a.mcpServerIds.toSet();
            if (isSelected)
              set.remove(s.id);
            else
              set.add(s.id);
            await context.read<AssistantProvider>().updateAssistant(
              a.copyWith(mcpServerIds: set.toList()),
            );
          },
          pressedScale: 1.0, // No scale on press
          builder: (pressed) {
            final overlayBg = pressed
                ? (isDark
                      ? Color.alphaBlend(Colors.white.withOpacity(0.06), bg)
                      : Color.alphaBlend(Colors.black.withOpacity(0.05), bg))
                : bg;
            return Container(
              decoration: BoxDecoration(
                color: overlayBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 0.6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Lucide.Terminal, size: 20, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              tag(l10n.assistantEditMcpConnectedTag),
                              tag(
                                l10n.assistantEditMcpToolsCountTag(
                                  enabledTools.toString(),
                                  tools.length.toString(),
                                ),
                              ),
                              tag(
                                s.transport == McpTransportType.inmemory
                                    ? AppLocalizations.of(
                                        context,
                                      )!.mcpTransportTagInmemory
                                    : (s.transport == McpTransportType.sse
                                          ? 'SSE'
                                          : 'HTTP'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IosSwitch(
                      value: isSelected,
                      onChanged: (v) async {
                        final set = a.mcpServerIds.toSet();
                        if (v)
                          set.add(s.id);
                        else
                          set.remove(s.id);
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(mcpServerIds: set.toList()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
