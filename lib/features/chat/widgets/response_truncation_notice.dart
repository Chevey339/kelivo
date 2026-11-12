import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/message_part.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

class ResponseTruncationNotice extends StatelessWidget {
  const ResponseTruncationNotice({
    super.key,
    required this.truncation,
    this.onRetryWithoutImages,
  });

  final ResponseTruncationPart truncation;
  final VoidCallback? onRetryWithoutImages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.circleAlert, size: 15, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  truncation.contextNearLimit
                      ? l10n.responseContextLimitReached(
                          truncation.inputTokens!,
                          truncation.contextWindow!,
                        )
                      : l10n.responseOutputLimitReached,
                  style: TextStyle(fontSize: 13, color: cs.error),
                ),
              ),
            ],
          ),
          if (truncation.hadImages && onRetryWithoutImages != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IosCardPress(
                baseColor: Colors.transparent,
                onTap: onRetryWithoutImages,
                child: Text(
                  l10n.responseRetryWithoutImages,
                  style: TextStyle(fontSize: 13, color: cs.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
