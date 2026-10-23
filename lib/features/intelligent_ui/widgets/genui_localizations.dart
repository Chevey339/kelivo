import 'package:Kelivo/l10n/app_localizations.dart';
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
      UiDiagnosticCode.invalidValue => l10n.genuiErrorValue,
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
