import 'package:flutter/widgets.dart';

import '../../../core/services/media/media_request.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/media_creation_controller.dart';
import '../../../shared/widgets/snackbar.dart';

CreationReferenceResult addCreationReferences(
  BuildContext context,
  MediaCreationController media,
  String? topicId,
  List<String> paths, {
  MediaReferenceRole? frameRole,
}) {
  final result = media.addReferencePaths(topicId, paths, frameRole: frameRole);
  final l10n = AppLocalizations.of(context)!;
  final model = media.model;
  final message = switch (result) {
    CreationReferenceResult.added => l10n.creationReferenceAdded,
    CreationReferenceResult.alreadyAdded => l10n.creationReferenceAlreadyAdded,
    CreationReferenceResult.limitReached => l10n.creationReferenceLimitReached(
      model!.capabilities.referenceLimits(media.parameters).max,
    ),
    CreationReferenceResult.unsupported =>
      model == null
          ? l10n.creationNoModelPlaceholder
          : l10n.creationReferenceUnsupported(model.spec.displayName),
    CreationReferenceResult.empty => null,
  };
  if (message != null) {
    showAppSnackBar(
      context,
      message: message,
      type: switch (result) {
        CreationReferenceResult.added => NotificationType.success,
        CreationReferenceResult.alreadyAdded => NotificationType.info,
        _ => NotificationType.warning,
      },
    );
  }
  return result;
}
