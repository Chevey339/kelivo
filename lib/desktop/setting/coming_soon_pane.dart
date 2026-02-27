part of '../desktop_settings_page.dart';

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody({required this.selected});
  final _SettingsMenuItem selected;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.25),
          ),
        ),
        child: Text(
          'Coming soon',
          style: TextStyle(
            fontSize: 16,
            color: cs.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
