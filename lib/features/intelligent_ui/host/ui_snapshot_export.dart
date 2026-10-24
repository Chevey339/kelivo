import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markstream/markstream.dart';
import 'package:path_provider/path_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/chat/widgets/export_image_capture.dart';
import 'package:Kelivo/features/chat/widgets/image_preview_sheet.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart'
    show saveExportTextWithPicker;
import '../catalog/ui_budgets.dart';
import '../runtime/ui_surface_controller.dart';
import '../text/ui_message_text.dart';
import '../text/ui_text_projection.dart';
import '../widgets/genui_localizations.dart';
import '../widgets/genui_surface.dart';

/// The menu captures once, before choosing a file type. Each operation owns a
/// read-only controller and cannot alter or reset the live Surface.
Future<void> exportUiSnapshot(
  BuildContext context,
  UiSurfaceController live, {
  required String originalFence,
  MarkstreamTheme? markdownTheme,
}) async {
  final l10n = AppLocalizations.of(context)!;
  UiSurfaceController? controller;
  try {
    if (!live.canSnapshot) {
      showAppSnackBar(
        context,
        message: l10n.genuiTextFailed,
        type: NotificationType.error,
      );
      return;
    }
    final captured = UiCapturedSurface(
      owner: live.owner,
      source: live.parsed.source,
      closed: live.parsed.closed,
      generation: UiGenerationStatus.complete,
      snapshot: live.captureSnapshot(),
    );
    final semantic = UiTextProjection(
      genUiProjectionLabels(l10n),
    ).text(live.captureRead(), mode: UiTextMode.export);
    final theme = Theme.of(context);
    final frozen = captured.createController();
    controller = frozen;
    final format = await showAppDialog<String>(
      context,
      waitForExit: true,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(title: l10n.genuiExportSnapshot),
            IosTextButton(
              label: l10n.messageExportSheetPlainText,
              icon: LucideIcons.fileText,
              onPressed: () => Navigator.of(context).pop('txt'),
            ),
            IosTextButton(
              label: l10n.messageExportSheetMarkdown,
              icon: LucideIcons.codeXml,
              onPressed: () => Navigator.of(context).pop('md'),
            ),
            IosTextButton(
              label: l10n.messageExportSheetExportImage,
              icon: LucideIcons.image,
              onPressed: () => Navigator.of(context).pop('png'),
            ),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) return;
    final name = 'kelivo-ui-${DateTime.now().microsecondsSinceEpoch}';
    if (format != 'png') {
      await saveExportTextWithPicker(
        context,
        filename: '$name.$format',
        content: format == 'md'
            ? uiExportMarkdown(semantic, originalFence)
            : semantic,
        allowedExtensions: [format],
      );
      return;
    }
    final image = await captureExportWidget(
      context,
      ExportCaptureScope(
        enabled: true,
        child: Focus(
          descendantsAreFocusable: false,
          descendantsAreTraversable: false,
          child: IgnorePointer(
            child: GenUiSurface(
              controller: frozen,
              markdownTheme: markdownTheme,
              exporting: true,
            ),
          ),
        ),
      ),
      theme: theme,
      maxPixels: UiBudgets.exportPixels,
    );
    final directory = await getTemporaryDirectory();
    final file = await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(image.pngBytes);
    if (!context.mounted) return;
    await showImagePreviewSheet(
      context,
      file: file,
      preparedPreview: image.preview,
    );
  } catch (error) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: error is ExportImageTooLarge
          ? l10n.genuiExportTooLarge
          : l10n.messageExportSheetExportFailed('$error'),
      type: NotificationType.error,
    );
  } finally {
    controller?.dispose();
  }
}
