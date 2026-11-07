import '../../../core/models/image_context.dart';
import '../../../core/models/request_budget.dart';
import '../../../l10n/app_localizations.dart';

String formatImageContextBudgetError(
  ImageContextBudgetException error,
  AppLocalizations l10n,
) {
  String bytes(int value) => l10n.requestBudgetBytes(
    (value / RequestBudget.mib).toStringAsFixed(2),
    value,
  );
  String actual(String value) =>
      error.minimum ? l10n.requestBudgetAtLeast(value) : value;
  final message = switch (error.kind) {
    ImageContextBudgetKind.singleImage => l10n.requestBudgetSingleError(
      error.imageIndex!,
      actual(bytes(error.actual)),
      bytes(error.limit),
    ),
    ImageContextBudgetKind.totalImages => l10n.requestBudgetTotalError(
      actual(bytes(error.actual)),
      bytes(error.limit),
    ),
    ImageContextBudgetKind.imageCount => l10n.requestBudgetCountError(
      actual(error.actual.toString()),
      error.limit,
    ),
    ImageContextBudgetKind.requestBody => l10n.requestBudgetBodyError(
      actual(bytes(error.actual)),
      bytes(error.limit),
    ),
  };
  return [
    message,
    if (error.pinned) l10n.requestBudgetPinnedError,
    error.kind == ImageContextBudgetKind.requestBody
        ? l10n.requestBudgetBodyHint
        : l10n.requestBudgetImageHint,
  ].join('\n\n');
}
