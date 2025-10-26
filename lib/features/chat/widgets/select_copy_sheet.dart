import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';

Future<void> showSelectCopySheet(BuildContext context, {required ChatMessage message}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(top: false, child: _SelectCopySheet(message: message)),
  );
}

class _SelectCopySheet extends StatelessWidget {
  const _SelectCopySheet({required this.message});
  final ChatMessage message;

  Future<void> _copyAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!context.mounted) return;
    showAppSnackBar(context, message: l10n.selectCopyPageCopiedAll, type: NotificationType.success);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (c, sc) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Invisible left button to balance the right button's width
                  Opacity(
                    opacity: 0,
                    child: IgnorePointer(
                      child: IosCardPress(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(20),
                        baseColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(l10n.selectCopyPageCopyAll, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.selectCopyPageTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IosCardPress(
                    onTap: () { Haptics.light(); _copyAll(context); },
                    borderRadius: BorderRadius.circular(20),
                    baseColor: Colors.transparent,
                    pressedBlendStrength: Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.06,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(l10n.selectCopyPageCopyAll, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                controller: sc,
                child: SingleChildScrollView(
                  controller: sc,
                  primary: false,
                  child: SelectionArea(
                    child: Text(
                      message.content,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
