import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

class WorldBookSheet extends StatelessWidget {
  const WorldBookSheet({super.key, required this.assistantId});

  final String? assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.45,
        builder: (ctx, controller) {
          final cs = Theme.of(ctx).colorScheme;
          final provider = ctx.watch<WorldBookProvider>();
          final books = provider.books;
          final activeIds = provider.activeBookIdsFor(assistantId).toSet();

          return Column(
            children: [
              _SheetTopBar(
                title: l10n.worldBookTitle,
                onBack: () => Navigator.of(ctx).maybePop(),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (books.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32, bottom: 24),
                        child: Center(
                          child: Text(
                            l10n.worldBookEmptyMessage,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final book in books)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SelectableRow(
                            icon: Lucide.BookOpen,
                            label: book.name.trim().isEmpty
                                ? l10n.worldBookUnnamed
                                : book.name.trim(),
                            subtitle: book.description.trim().isEmpty
                                ? null
                                : book.description.trim(),
                            selected: activeIds.contains(book.id),
                            disabled: !book.enabled,
                            onTap: () async {
                              Haptics.light();
                              await ctx
                                  .read<WorldBookProvider>()
                                  .toggleActiveBookId(
                                    book.id,
                                    assistantId: assistantId,
                                  );
                            },
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _NavIconButton(icon: Lucide.ArrowLeft, onTap: onBack),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      height: 40,
      child: IosCardPress(
        borderRadius: BorderRadius.circular(12),
        baseColor: Colors.transparent,
        onTap: onTap,
        child: Center(child: Icon(icon, size: 20, color: cs.onSurface)),
      ),
    );
  }
}

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onColor = selected ? cs.primary : cs.onSurface;
    final opacity = disabled ? 0.55 : 1.0;
    return SizedBox(
      height: subtitle == null ? 52 : 66,
      child: IosCardPress(
        borderRadius: BorderRadius.circular(14),
        baseColor: cs.surface,
        duration: const Duration(milliseconds: 260),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: onColor.withOpacity(opacity)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onColor.withOpacity(opacity),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withOpacity(0.55 * opacity),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(
                Lucide.Check,
                size: 18,
                color: cs.primary.withOpacity(opacity),
              )
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}

Future<void> showWorldBookSheet(
  BuildContext context, {
  required String? assistantId,
}) async {
  final cs = Theme.of(context).colorScheme;
  final provider = context.read<WorldBookProvider>();
  await provider.initialize();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => WorldBookSheet(assistantId: assistantId),
  );
}
