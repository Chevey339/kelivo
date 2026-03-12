import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';

const String kVerbosityDefaultSelection = '__default__';

Future<String?> showVerbositySheet(
  BuildContext context, {
  String? initialValue,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _VerbositySheet(initialValue: initialValue),
  );
}

class _VerbositySheet extends StatefulWidget {
  const _VerbositySheet({this.initialValue});

  final String? initialValue;

  @override
  State<_VerbositySheet> createState() => _VerbositySheetState();
}

class _VerbositySheetState extends State<_VerbositySheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue ?? kVerbosityDefaultSelection;
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final active = _selected == value;
    final Color iconColor = active ? cs.primary : cs.onSurface.withOpacity(0.7);
    final Color onColor = active ? cs.primary : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: cs.surface,
          duration: const Duration(milliseconds: 260),
          onTap: () {
            Haptics.light();
            Navigator.of(context).maybePop(
              value == kVerbosityDefaultSelection ? kVerbosityDefaultSelection : value,
            );
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: onColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (active) Icon(Lucide.Check, size: 18, color: cs.primary) else const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      _tile(
                        context,
                        icon: Lucide.RotateCcw,
                        title: l10n.verbosityDefault,
                        value: kVerbosityDefaultSelection,
                      ),
                      _tile(context, icon: Lucide.MessageCircleMore, title: l10n.verbosityLow, value: 'low'),
                      _tile(context, icon: Lucide.MessageCircleMore, title: l10n.verbosityMedium, value: 'medium'),
                      _tile(context, icon: Lucide.MessageCircleMore, title: l10n.verbosityHigh, value: 'high'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
