import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/message_part.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../utils/platform_utils.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../chat/widgets/forwarded_messages_card.dart';

class ForwardMessagesRequest {
  const ForwardMessagesRequest({
    required this.conversationId,
    required this.comment,
  });
  final String conversationId;
  final String comment;
}

Future<ForwardMessagesRequest?> showForwardMessagesSheet(
  BuildContext context, {
  required List<Conversation> conversations,
  required ForwardedMessagesPart record,
}) {
  final body = ForwardMessagesSheet(
    conversations: conversations,
    record: record,
  );
  if (PlatformUtils.isDesktopTarget || !ResponsiveHelper.isMobile(context)) {
    return showDialog<ForwardMessagesRequest>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SizedBox(width: 440, child: body),
        ),
      ),
    );
  }
  return Navigator.of(
    context,
  ).push<ForwardMessagesRequest>(MaterialPageRoute(builder: (_) => body));
}

/// A destination picker. Confirmation is a separate, compact dialog.
class ForwardMessagesSheet extends StatefulWidget {
  const ForwardMessagesSheet({
    super.key,
    required this.conversations,
    required this.record,
  });
  final List<Conversation> conversations;
  final ForwardedMessagesPart record;
  @override
  State<ForwardMessagesSheet> createState() => _ForwardMessagesSheetState();
}

class _ForwardMessagesSheetState extends State<ForwardMessagesSheet> {
  final _search = TextEditingController();
  bool _confirming = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirm(Conversation destination) async {
    if (_confirming) return;
    _confirming = true;
    final request = await showDialog<ForwardMessagesRequest>(
      context: context,
      builder: (_) => ForwardMessagesConfirmation(
        destination: destination,
        record: widget.record,
      ),
    );
    _confirming = false;
    if (mounted && request != null) Navigator.pop(context, request);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _search.text.trim().toLowerCase();
    final conversations = widget.conversations
        .where((c) => c.title.toLowerCase().contains(query))
        .toList();
    final desktop =
        PlatformUtils.isDesktopTarget || !ResponsiveHelper.isMobile(context);
    final header = AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Lucide.ArrowLeft),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(l10n.forwardMessagesDestination),
    );
    final body = SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: IosFormTextField(
              label: l10n.chatHistoryPageSearchHint,
              controller: _search,
              inlineLabel: false,
              outerPadding: EdgeInsets.zero,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Flexible(
            child: conversations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.forwardMessagesEmpty),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return IosCardPress(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        onTap: () => _confirm(conversation),
                        child: Row(
                          children: [
                            const Icon(Lucide.MessageCircle, size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                conversation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Lucide.ChevronRight, size: 16),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    if (desktop) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: kToolbarHeight, child: header),
          Flexible(child: body),
        ],
      );
    }
    return Scaffold(appBar: header, body: body);
  }
}

class ForwardMessagesConfirmation extends StatefulWidget {
  const ForwardMessagesConfirmation({
    super.key,
    required this.destination,
    required this.record,
  });
  final Conversation destination;
  final ForwardedMessagesPart record;
  @override
  State<ForwardMessagesConfirmation> createState() =>
      _ForwardMessagesConfirmationState();
}

class _ForwardMessagesConfirmationState
    extends State<ForwardMessagesConfirmation> {
  final _comment = TextEditingController();
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.forwardMessagesTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Lucide.MessageCircle),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.destination.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ForwardedMessagesCard(record: widget.record),
              const SizedBox(height: 18),
              IosFormTextField(
                key: const ValueKey('forward-comment'),
                label: l10n.forwardMessagesComment,
                controller: _comment,
                inlineLabel: false,
                outerPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              FormSheetActions(
                cancelLabel: l10n.homePageCancel,
                confirmLabel: l10n.forwardMessagesAction,
                onCancel: () => Navigator.pop(context),
                onConfirm: () => Navigator.pop(
                  context,
                  ForwardMessagesRequest(
                    conversationId: widget.destination.id,
                    comment: _comment.text.trim(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
