import '../text/ui_number.dart';
import '../text/ui_text_projection.dart';
import '../catalog/ui_catalog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';

String genUiDiagnosticMessage(AppLocalizations l10n, UiDiagnostic diagnostic) =>
    switch (diagnostic.code) {
      UiDiagnosticCode.invalidHeader => l10n.genuiErrorHeader,
      UiDiagnosticCode.unsupportedVersion => l10n.genuiErrorVersion,
      UiDiagnosticCode.unsupportedCatalog => l10n.genuiErrorCatalog,
      UiDiagnosticCode.missingRoot => l10n.genuiErrorRoot,
      UiDiagnosticCode.syntax => l10n.genuiErrorSyntax,
      UiDiagnosticCode.duplicateSymbol => l10n.genuiErrorDuplicateSymbol,
      UiDiagnosticCode.duplicateProperty => l10n.genuiErrorDuplicateProperty,
      UiDiagnosticCode.reservedName => l10n.genuiErrorReservedName,
      UiDiagnosticCode.unknownComponent => l10n.genuiErrorUnknownComponent(
        diagnostic.detail,
      ),
      UiDiagnosticCode.unknownProperty => l10n.genuiErrorUnknownProperty(
        diagnostic.detail,
      ),
      UiDiagnosticCode.missingProperty => l10n.genuiErrorMissingProperty(
        diagnostic.detail,
      ),
      UiDiagnosticCode.invalidBinding => l10n.genuiErrorBinding,
      UiDiagnosticCode.invalidReference => l10n.genuiErrorReference,
      UiDiagnosticCode.missingReference => l10n.genuiErrorMissingReference,
      UiDiagnosticCode.dependency => l10n.genuiErrorDependency,
      UiDiagnosticCode.cycle => l10n.genuiErrorCycle,
      UiDiagnosticCode.duplicateParent => l10n.genuiErrorDuplicateParent,
      UiDiagnosticCode.unreachableNode => l10n.genuiErrorUnreachableNode,
      UiDiagnosticCode.typeMismatch => l10n.genuiErrorType,
      UiDiagnosticCode.invalidValue => switch (diagnostic.detail) {
        'chartFields' => l10n.genuiChartFieldsError,
        'chartRecords' => l10n.genuiChartRecordsError,
        'chartX' => l10n.genuiChartXError,
        'chartY' => l10n.genuiChartYError,
        'chartPieValues' => l10n.genuiChartPieError,
        'tableRecords' || 'tableCells' => l10n.genuiTableCellsError,
        'tableColumns' || 'tableFields' => l10n.genuiTableColumnsError,
        'tableRowKey' => l10n.genuiTableRowKeyError,
        _ => l10n.genuiErrorValue,
      },
      UiDiagnosticCode.sourceBudget => l10n.genuiErrorSourceBudget,
      UiDiagnosticCode.declarationBudget => l10n.genuiErrorDeclarationBudget,
      UiDiagnosticCode.declarationCount => l10n.genuiErrorDeclarationCount,
      UiDiagnosticCode.componentCount => l10n.genuiErrorComponentCount,
      UiDiagnosticCode.inputCount => l10n.genuiErrorInputCount,
      UiDiagnosticCode.componentDepth => l10n.genuiErrorComponentDepth,
      UiDiagnosticCode.expressionDepth => l10n.genuiErrorExpressionDepth,
      UiDiagnosticCode.unknownFunction => l10n.genuiErrorFunction,
      UiDiagnosticCode.invalidAction => l10n.genuiErrorAction,
      UiDiagnosticCode.nestedSample => l10n.genuiErrorNestedSample,
      UiDiagnosticCode.invalidSample => l10n.genuiErrorSample,
      UiDiagnosticCode.dataBudget => l10n.genuiErrorDataBudget,
      UiDiagnosticCode.duplicateRowKey => l10n.genuiErrorRowKey,
      UiDiagnosticCode.domain => l10n.genuiErrorDomain,
      UiDiagnosticCode.divisionByZero => l10n.genuiErrorDivisionByZero,
      UiDiagnosticCode.nonFinite => l10n.genuiErrorNonFinite,
      UiDiagnosticCode.operationsBudget => l10n.genuiErrorOperationsBudget,
    };

String genUiFieldIssueMessage(AppLocalizations l10n, UiFieldIssue issue) =>
    switch (issue.error) {
      UiFieldError.required => l10n.genuiFieldRequired,
      UiFieldError.tooShort => l10n.genuiFieldTooShort(issue.min!.toInt()),
      UiFieldError.tooLong => l10n.genuiFieldTooLong(issue.max!.toInt()),
      UiFieldError.number => l10n.genuiInvalidNumber,
      UiFieldError.option => l10n.genuiChooseOption,
      UiFieldError.composing => l10n.genuiFinishComposing,
      UiFieldError.stateBudget => l10n.genuiErrorDataBudget,
      UiFieldError.range =>
        issue.min == null
            ? l10n.genuiNumberMaximum(genUiNumber(issue.max))
            : issue.max == null
            ? l10n.genuiNumberMinimum(genUiNumber(issue.min))
            : l10n.genuiNumberRange(
                genUiNumber(issue.min),
                genUiNumber(issue.max),
              ),
    };

UiProjectionLabels genUiProjectionLabels(AppLocalizations l10n) =>
    UiProjectionLabels(
      defaultTitle: l10n.genuiSurfaceTitle,
      yes: l10n.genuiValueTrue,
      no: l10n.genuiValueFalse,
      empty: l10n.genuiContextEmpty,
      omitted: l10n.genuiContextOmitted,
      waiting: l10n.genuiPendingNode,
      diagnostic: (d) =>
          '${genUiDiagnosticMessage(l10n, d)} (${l10n.genuiErrorLine(d.line)})',
      fieldIssue: (issue) => genUiFieldIssueMessage(l10n, issue),
      chartKind: (kind, donut) => switch (kind) {
        UiChartKind.line => l10n.genuiChartLine,
        UiChartKind.area => l10n.genuiChartArea,
        UiChartKind.bar => l10n.genuiChartBar,
        UiChartKind.scatter => l10n.genuiChartScatter,
        UiChartKind.pie => donut ? l10n.genuiChartDonut : l10n.genuiChartPie,
      },
      chartSummary: l10n.genuiChartSummary,
      pieSummary: l10n.genuiChartPieSummary,
      range: (name, min, max) => '$name: ${l10n.genuiNumberRange(min, max)}',
      tablePage: l10n.genuiTablePageInfo,
      filter: (query) => '${l10n.genuiTableFilterHint}: $query',
      domainGaps: l10n.genuiChartDomainSummary,
      trend: l10n.genuiMetricTrend,
    );
