import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/services/media/media_request.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/media_creation_controller.dart';
import 'creation_toast.dart';

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
      model!.capabilities.maxReferences,
    ),
    CreationReferenceResult.unsupported =>
      model == null
          ? l10n.creationNoModelPlaceholder
          : l10n.creationReferenceUnsupported(model.spec.displayName),
    CreationReferenceResult.empty => null,
  };
  if (message != null) {
    showCreationToast(context, message: message, icon: LucideIcons.imagePlus);
  }
  return result;
}
