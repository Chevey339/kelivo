import 'dart:io';

import '../../../core/models/provider_oauth.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

final _unsupportedComplexity = RegExp(
  r"Complexity\s+'[^']+'\s+is not supported for this image model",
  caseSensitive: false,
);

String formatImageGenerationError(
  Object error, {
  required ProviderConfig config,
  required AppLocalizations l10n,
}) {
  final original = error.toString();
  if (config.oauthProvider != OAuthProvider.chatgpt ||
      error is! HttpException ||
      !_unsupportedComplexity.hasMatch(original)) {
    return original;
  }
  return '$original\n\n${l10n.imageGenerationComplexityErrorHint}';
}
