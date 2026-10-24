import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_selection_area.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../intelligent_ui/host/ui_copy_actions.dart';
import '../../intelligent_ui/text/ui_message_text.dart';
import '../../intelligent_ui/widgets/genui_clipboard.dart';

class SelectCopyPage extends StatefulWidget {
  const SelectCopyPage({super.key, required this.message});
  final ChatMessage message;
  @override
  State<SelectCopyPage> createState() => _SelectCopyPageState();
}

class _SelectCopyPageState extends State<SelectCopyPage> {
  Future<UiMessageText?>? _projection;
  AppLocalizations? _labels;
  ChatMessage? _message;
  void _capture() {
    final labels = AppLocalizations.of(context)!;
    if (_message == widget.message && identical(_labels, labels)) return;
    _message = widget.message;
    _labels = labels;
    _projection = readUiMessageText(context, widget.message);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _capture();
  }

  @override
  void didUpdateWidget(SelectCopyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _capture();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<UiMessageText?>(
      future: _projection,
      builder: (context, snapshot) {
        final text = snapshot.data?.copyText;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.selectCopyPageTitle),
            actions: [
              IosIconButton(
                icon: Lucide.Code,
                tooltip: l10n.genuiCopySourceMarkdown,
                minSize: 44,
                onTap: () => copyUiMessageSource(context, widget.message),
              ),
              TextButton.icon(
                onPressed: text == null
                    ? null
                    : () => copyGenUiText(
                        context,
                        text,
                        successMessage: l10n.selectCopyPageCopiedAll,
                      ),
                icon: Icon(Lucide.Copy, size: 18, color: cs.primary),
                label: Text(
                  l10n.selectCopyPageCopyAll,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : text == null
                  ? Text(l10n.genuiTextFailed)
                  : Scrollbar(
                      child: SingleChildScrollView(
                        child: AppSelectionArea(
                          copyByteLimit: UiBudgets.copyBytes,
                          child: Text(
                            text,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
