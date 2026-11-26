import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/media/media_request.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../chat/pages/image_viewer_page.dart';
import 'creation_lightbox.dart';

List<MediaReference> _references(GenerationBatchRow batch) {
  try {
    return MediaReference.forBatch(batch);
  } on FormatException {
    return const [];
  } on TypeError {
    return const [];
  }
}

String _label(AppLocalizations l, MediaReference ref) => switch (ref.role) {
  MediaReferenceRole.image => l.creationReferenceImagesLabel,
  MediaReferenceRole.firstFrame => l.creationFirstFrame,
  MediaReferenceRole.lastFrame => l.creationLastFrame,
  MediaReferenceRole.platform =>
    ref.parameterKey == 'mask_url'
        ? l.creationMaskLabel
        : ref.parameterKey?.replaceAll('_', ' ') ??
              l.creationReferenceImagesLabel,
};

class CreationReferenceStrip extends StatefulWidget {
  const CreationReferenceStrip({super.key, required this.batch});
  final GenerationBatchRow batch;
  @override
  State<CreationReferenceStrip> createState() => _CreationReferenceStripState();
}

class _CreationReferenceStripState extends State<CreationReferenceStrip> {
  late List<MediaReference> refs = _references(widget.batch);
  @override
  void didUpdateWidget(CreationReferenceStrip old) {
    super.didUpdateWidget(old);
    if (old.batch.id != widget.batch.id ||
        old.batch.referencesJson != widget.batch.referencesJson) {
      refs = _references(widget.batch);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.creationReferenceImagesLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: refs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final ref = refs[i];
                final label = '${_label(l, ref)} ${i + 1}';
                return _ReferenceThumbnail(
                  label: ref.unavailable ? l.creationReferenceDeleted : label,
                  uri: ref.unavailable ? null : ref.path,
                  onTap: ref.unavailable
                      ? null
                      : () {
                          final available = refs
                              .where((r) => !r.unavailable)
                              .toList();
                          ImageViewerPage(
                            images: [for (final r in available) r.path],
                            initialIndex: available.indexOf(ref),
                            dismissOnTap: true,
                          ).open(context);
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceThumbnail extends StatelessWidget {
  const _ReferenceThumbnail({
    required this.label,
    required this.uri,
    required this.onTap,
  });
  final String label;
  final String? uri;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: onTap != null,
      child: IosCardPress(
        baseColor: Colors.transparent,
        focusable: onTap != null,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 48,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: uri == null
                  ? ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Lucide.ImageOff, size: 16),
                    )
                  : CreationFileImage(
                      uri!,
                      cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
