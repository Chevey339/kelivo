import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/plantuml_encoder.dart';
import 'snackbar.dart';
import 'tabbed_preview_block.dart';

class PlantUMLBlock extends TabbedPreviewBlock {
  const PlantUMLBlock({super.key, required super.code});

  @override
  State<PlantUMLBlock> createState() => _PlantUMLBlockState();
}

class _PlantUMLBlockState extends TabbedPreviewBlockState<PlantUMLBlock> {
  late String _imageUrl;

  @override
  void initState() {
    super.initState();
    _updateUrl();
  }

  @override
  void onCodeChanged() {
    _updateUrl();
  }

  void _updateUrl() {
    final encoded = PlantUmlEncoder.encode(widget.code);
    _imageUrl = 'https://www.plantuml.com/plantuml/svg/$encoded';
  }

  @override
  Widget buildImageContent(BuildContext context, PreviewBlockColors colors) {
    return SvgPicture.network(
      _imageUrl,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => PreviewLoadingView(colors: colors),
      errorBuilder: (_, __, ___) => PreviewErrorView(colors: colors),
    );
  }

  @override
  List<Widget> buildExtraActions(
    BuildContext context,
    PreviewBlockColors colors,
    bool exporting,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      PreviewTextAction(
        icon: Lucide.Link,
        label: l10n.mermaidPreviewOpen,
        colors: colors,
        onTap: () => _openPreview(context),
      ),
    ];
  }

  Future<void> _openPreview(BuildContext context) async {
    final failedMessage = AppLocalizations.of(
      context,
    )!.mermaidPreviewOpenFailed;
    try {
      final ok = await launchUrl(
        Uri.parse(_imageUrl),
        mode: LaunchMode.externalApplication,
      );
      if (ok || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    showAppSnackBar(
      context,
      message: failedMessage,
      type: NotificationType.error,
    );
  }
}
