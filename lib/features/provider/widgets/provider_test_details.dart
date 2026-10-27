import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../utils/provider_test_failure.dart';

class ProviderTestDetails extends StatelessWidget {
  const ProviderTestDetails({
    super.key,
    required this.requestUrl,
    required this.baseUrl,
    this.failure,
  });
  final String requestUrl;
  final String baseUrl;
  final ProviderTestFailure? failure;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(baseUrl);
    final requestUri = Uri.tryParse(requestUrl);
    final suggestVersion =
        failure?.statusCode == 404 &&
        uri != null &&
        requestUri != null &&
        !RegExp(r'/v\d').hasMatch(requestUri.path);
    final suggestion = uri
        ?.replace(path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/v1')
        .toString();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requestUrl,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (suggestVersion)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                AppLocalizations.of(
                  context,
                )!.providerDetailPageTestHintMissingVersion(suggestion!),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          if (failure?.detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Text(
                    failure!.detail!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
