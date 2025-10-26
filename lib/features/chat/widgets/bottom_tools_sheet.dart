import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/services/learning_mode_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

class BottomToolsSheet extends StatelessWidget {
  const BottomToolsSheet({super.key, this.onCamera, this.onPhotos, this.onUpload, this.onClear, this.clearLabel});

  final VoidCallback? onCamera;
  final VoidCallback? onPhotos;
  final VoidCallback? onUpload;
  final VoidCallback? onClear;
  final String? clearLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = Theme.of(context).colorScheme.surface;

    Widget roundedAction({required IconData icon, required String label, VoidCallback? onTap}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cardColor = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
      return Expanded(
        child: SizedBox(
          height: 72,
          child: IosCardPress(
            baseColor: cardColor,
            borderRadius: BorderRadius.circular(14),
            pressedScale: 0.98,
            duration: const Duration(milliseconds: 260),
            onTap: () {
              Haptics.light();
              onTap?.call();
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              roundedAction(
                icon: Lucide.Camera,
                label: l10n.bottomToolsSheetCamera,
                onTap: onCamera,
              ),
              const SizedBox(width: 12),
              roundedAction(
                icon: Lucide.Image,
                label: l10n.bottomToolsSheetPhotos,
                onTap: onPhotos,
              ),
              const SizedBox(width: 12),
              roundedAction(
                icon: Lucide.Paperclip,
                label: l10n.bottomToolsSheetUpload,
                onTap: onUpload,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LearningAndClearSection(clearLabel: clearLabel, onClear: onClear),
        ],
      ),
    ),
    );
  }
}

class _LearningAndClearSection extends StatefulWidget {
  const _LearningAndClearSection({this.onClear, this.clearLabel});
  final VoidCallback? onClear;
  final String? clearLabel;

  @override
  State<_LearningAndClearSection> createState() => _LearningAndClearSectionState();
}

class _LearningAndClearSectionState extends State<_LearningAndClearSection> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await LearningModeStore.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _loading = false;
    });
  }

  Widget _row({required IconData icon, required String label, bool selected = false, VoidCallback? onTap, VoidCallback? onLongPress}) {
    final cs = Theme.of(context).colorScheme;
    final onColor = selected ? cs.primary : cs.onSurface;
    final radius = BorderRadius.circular(14);
    return SizedBox(
      height: 48,
      child: IosCardPress(
        borderRadius: radius,
        baseColor: Theme.of(context).colorScheme.surface,
        duration: const Duration(milliseconds: 260),
        onTap: onTap,
        onLongPress: onLongPress,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: onColor),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: onColor))),
            if (selected) Icon(Lucide.Check, size: 18, color: cs.primary) else const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_loading)
          const SizedBox(height: 48)
        else
          _row(
            icon: Lucide.BookOpenText,
            label: l10n.bottomToolsSheetLearningMode,
            selected: _enabled,
            onTap: () async {
              Haptics.light();
              final next = !_enabled;
              await LearningModeStore.setEnabled(next);
              if (!mounted) return;
              setState(() => _enabled = next);
              // Close bottom sheet after toggling
              Navigator.of(context).maybePop();
            },
            onLongPress: () => _showLearningPromptSheet(context),
          ),
        const SizedBox(height: 8),
        _row(
          icon: Lucide.Eraser,
          label: widget.clearLabel ?? l10n.bottomToolsSheetClearContext,
          onTap: () {
            Haptics.light();
            widget.onClear?.call();
          },
        ),
      ],
    );
  }

  Future<void> _showLearningPromptSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final prompt = await LearningModeStore.getPrompt();
    final controller = TextEditingController(text: prompt);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.bottomToolsSheetPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: l10n.bottomToolsSheetPromptHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await LearningModeStore.resetPrompt();
                        controller.text = await LearningModeStore.getPrompt();
                      },
                      child: Text(l10n.bottomToolsSheetResetDefault),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await LearningModeStore.setPrompt(controller.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.bottomToolsSheetSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
