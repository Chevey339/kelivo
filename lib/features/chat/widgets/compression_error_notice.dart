import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_text_button.dart';
import 'context_compression_status.dart';

/// Keep the next step readable, with the full provider error available on demand.
class CompressionErrorNotice extends StatefulWidget {
  const CompressionErrorNotice({
    super.key,
    required this.error,
    this.initiallyExpanded = false,
  });

  final String error;
  final bool initiallyExpanded;

  @override
  State<CompressionErrorNotice> createState() => _CompressionErrorNoticeState();
}

class _CompressionErrorNoticeState extends State<CompressionErrorNotice> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant CompressionErrorNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != widget.error) _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(compressionErrorLabel(l10n, widget.error)),
        IosTextButton(
          label: _expanded
              ? l10n.startupRecoveryHideDetails
              : l10n.startupRecoveryShowDetails,
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          SelectableText(widget.error),
          IosTextButton(
            label: l10n.backupProgressCopyError,
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: widget.error)),
          ),
        ],
      ],
    );
  }
}
