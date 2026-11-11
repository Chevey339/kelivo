/// Stable, bounded diagnostic codes. The Flutter layer resolves these keys.
enum UiDiagnosticCode {
  invalidHeader('genuiErrorHeader'),
  unsupportedVersion('genuiErrorVersion'),
  unsupportedCatalog('genuiErrorCatalog'),
  missingRoot('genuiErrorRoot'),
  syntax('genuiErrorSyntax'),
  duplicateSymbol('genuiErrorDuplicateSymbol'),
  duplicateProperty('genuiErrorDuplicateProperty'),
  reservedName('genuiErrorReservedName'),
  unknownComponent('genuiErrorUnknownComponent'),
  unknownProperty('genuiErrorUnknownProperty'),
  missingProperty('genuiErrorMissingProperty'),
  invalidBinding('genuiErrorBinding'),
  invalidReference('genuiErrorReference'),
  missingReference('genuiErrorMissingReference'),
  dependency('genuiErrorDependency'),
  cycle('genuiErrorCycle'),
  duplicateParent('genuiErrorDuplicateParent'),
  unreachableNode('genuiErrorUnreachableNode'),
  typeMismatch('genuiErrorType'),
  invalidValue('genuiErrorValue'),
  sourceBudget('genuiErrorSourceBudget'),
  declarationBudget('genuiErrorDeclarationBudget'),
  declarationCount('genuiErrorDeclarationCount'),
  componentCount('genuiErrorComponentCount'),
  inputCount('genuiErrorInputCount'),
  componentDepth('genuiErrorComponentDepth'),
  expressionDepth('genuiErrorExpressionDepth'),
  unknownFunction('genuiErrorFunction'),
  invalidAction('genuiErrorAction'),
  nestedSample('genuiErrorNestedSample'),
  invalidSample('genuiErrorSample'),
  dataBudget('genuiErrorDataBudget'),
  duplicateRowKey('genuiErrorRowKey'),
  domain('genuiErrorDomain'),
  divisionByZero('genuiErrorDivisionByZero'),
  nonFinite('genuiErrorNonFinite'),
  operationsBudget('genuiErrorOperationsBudget');

  const UiDiagnosticCode(this.messageKey);
  final String messageKey;
}

final class UiDiagnostic {
  const UiDiagnostic(
    this.code, {
    required this.line,
    this.column = 1,
    this.symbol,
    this.detail = '',
  });
  final UiDiagnosticCode code;
  final int line;
  final int column;
  final String? symbol;
  final String detail;
  Map<String, Object?> toJson() => {
    'code': code.name,
    'line': line,
    'column': column,
    if (symbol != null) 'symbol': symbol,
    if (detail.isNotEmpty) 'detail': detail,
  };
}
