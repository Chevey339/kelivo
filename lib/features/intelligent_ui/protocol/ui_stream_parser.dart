import 'dart:convert';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'ui_diagnostic.dart';
import 'ui_record_parser.dart';
import 'ui_validation.dart';

final class UiParseSnapshot {
  const UiParseSnapshot({
    required this.source,
    required this.closed,
    required this.epoch,
    required this.headerAccepted,
    required this.program,
    required this.invalid,
    required this.committedRecords,
  });
  final String source;
  final bool closed;
  final int epoch;
  final bool headerAccepted;
  final UiValidationResult program;
  final bool invalid;
  final int committedRecords;
  Map<String, Object?> toJson() => {
    'source': source,
    'closed': closed,
    'header': headerAccepted,
    'invalid': invalid,
    'records': committedRecords,
    'declarations': program.declarations.values
        .map((value) => value.toJson())
        .toList(),
    'diagnostics': program.diagnostics.map((value) => value.toJson()).toList(),
    'failed': program.failedSymbols.toList()..sort(),
    'pending': program.pendingSymbols.toList()..sort(),
  };
}

/// Reduces complete physical records once. A pending tail, including a trailing
/// CR, stays uncommitted until its delimiter or actual fence closure arrives.
final class UiStreamParser {
  final _records = UiRecordParser();
  String _raw = '';
  String _source = '';
  int _consumed = 0;
  int _line = 1;
  int _epoch = 0;
  int _recordCount = 0;
  bool _closed = false;
  bool _headerAccepted = false;
  bool _fatal = false;
  final Map<String, UiDeclaration> _declarations = {};
  final List<UiDiagnostic> _diagnostics = [];
  final Set<String> _failed = {};
  UiParseSnapshot? _snapshot;

  UiParseSnapshot get snapshot => _snapshot ?? update('');

  UiParseSnapshot append(String chunk, {bool closed = false}) =>
      update('$_raw$chunk', closed: closed);

  UiParseSnapshot update(String source, {bool closed = false}) {
    if (_snapshot != null && source == _raw && closed == _closed) {
      return _snapshot!;
    }
    final oversized =
        source.length > UiBudgets.sourceBytes ||
        utf8.encode(source).length > UiBudgets.sourceBytes;
    final normalized = oversized ? source : _normalize(source, closed);
    final consumedPrefix = _source.substring(0, _consumed);
    if (!normalized.startsWith(consumedPrefix) ||
        (_closed && (source != _raw || !closed)) ||
        (_fatal && !source.startsWith(_raw))) {
      _reset();
    }
    _raw = source;
    _source = normalized;
    _closed = closed;
    if (oversized && !_fatal) _fatalError(UiDiagnosticCode.sourceBudget, 1);

    while (!_fatal) {
      final newline = normalized.indexOf('\n', _consumed);
      if (newline < 0) break;
      final record = normalized.substring(_consumed, newline);
      _consume(record, _line);
      _consumed = newline + 1;
      _line++;
    }
    if (!_fatal && _consumed < normalized.length) {
      final tail = normalized.substring(_consumed);
      if (_tooLong(tail)) {
        _fatalError(UiDiagnosticCode.declarationBudget, _line);
      } else if (closed) {
        _consume(tail, _line);
        _consumed = normalized.length;
      }
    }
    if (closed && _line == 1 && !_headerAccepted && !_fatal) {
      _fatalError(UiDiagnosticCode.invalidHeader, 1);
    }
    final validation = UiValidator(
      _declarations,
      closed: closed,
      diagnostics: _diagnostics,
      failedSymbols: _failed,
    ).validate();
    return _snapshot = UiParseSnapshot(
      source: normalized,
      closed: closed,
      epoch: _epoch,
      headerAccepted: _headerAccepted,
      program: validation,
      invalid: _fatal || validation.failedSymbols.contains('root'),
      committedRecords: _recordCount,
    );
  }

  static String _normalize(String source, bool closed) {
    final end = !closed && source.endsWith('\r')
        ? source.length - 1
        : source.length;
    return source
        .substring(0, end)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  bool _tooLong(String value) =>
      value.length > UiBudgets.declarationBytes ||
      utf8.encode(value).length > UiBudgets.declarationBytes;

  void _consume(String record, int line) {
    if (_tooLong(record)) {
      _fatalError(UiDiagnosticCode.declarationBudget, line);
      return;
    }
    if (line == 1) {
      _header(record);
      return;
    }
    if (record.trim().isEmpty) return;
    if (++_recordCount > UiBudgets.declarations) {
      _fatalError(UiDiagnosticCode.declarationCount, line);
      return;
    }
    final result = _records.parse(record, line);
    if (result.error case final error?) {
      final match = RegExp(
        r'^\s*(?:\$|let\s+)?([A-Za-z_][A-Za-z_0-9]*)',
      ).firstMatch(record);
      final symbol = match?.group(1);
      if (symbol != null) _failed.add(symbol);
      _diagnostics.add(
        UiDiagnostic(
          error.code,
          line: line,
          column: error.column,
          symbol: symbol,
        ),
      );
      return;
    }
    final declaration = result.declaration!;
    if (_declarations.containsKey(declaration.name) ||
        _failed.contains(declaration.name)) {
      _failed.add(declaration.name);
      _diagnostics.add(
        UiDiagnostic(
          UiDiagnosticCode.duplicateSymbol,
          line: line,
          symbol: declaration.name,
        ),
      );
      return;
    }
    _declarations[declaration.name] = declaration;
    if (_declarations.values.whereType<UiNodeDeclaration>().length >
        UiBudgets.components) {
      _fatalError(UiDiagnosticCode.componentCount, line);
    }
    if (_declarations.values.whereType<UiStateDeclaration>().length >
        UiBudgets.inputs) {
      _fatalError(UiDiagnosticCode.inputCount, line);
    }
  }

  void _header(String record) {
    final match = RegExp(
      r'^ui[ \t]+([0-9]+)[ \t]+catalog[ \t]+("(?:[^"\\]|\\.)*")[ \t]*$',
    ).firstMatch(record);
    if (match == null) {
      _fatalError(UiDiagnosticCode.invalidHeader, 1);
      return;
    }
    if (match.group(1) != UiCatalog.languageVersion.toString()) {
      _fatalError(UiDiagnosticCode.unsupportedVersion, 1);
      return;
    }
    try {
      if (jsonDecode(match.group(2)!) != UiCatalog.version) {
        _fatalError(UiDiagnosticCode.unsupportedCatalog, 1);
      } else {
        _headerAccepted = true;
      }
    } on FormatException {
      _fatalError(UiDiagnosticCode.invalidHeader, 1);
    }
  }

  void _fatalError(UiDiagnosticCode code, int line) {
    _fatal = true;
    _failed.add('root');
    _diagnostics.add(UiDiagnostic(code, line: line, symbol: 'root'));
  }

  void _reset() {
    _epoch++;
    _consumed = 0;
    _line = 1;
    _recordCount = 0;
    _headerAccepted = false;
    _fatal = false;
    _declarations.clear();
    _diagnostics.clear();
    _failed.clear();
  }
}
