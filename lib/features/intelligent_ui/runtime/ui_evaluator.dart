import 'dart:convert';
import 'dart:math' as math;

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_expression_walk.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_validation.dart';

final class UiSampleGap {
  const UiSampleGap({required this.x, required this.index, required this.code});
  final double x;
  final int index;
  final UiDiagnosticCode code;
}

final class UiComputedValue {
  UiComputedValue._({
    this.value,
    this.error,
    this.sampled = false,
    Iterable<UiSampleGap> gaps = const [],
    this._shape,
  }) : gaps = List.unmodifiable(gaps);
  final Object? value;
  final UiDiagnostic? error;

  /// The returned array itself was produced by @sample on the evaluated branch.
  final bool sampled;
  final List<UiSampleGap> gaps;
  final _ValueShape? _shape;
  bool get valid => error == null;
}

typedef _ValueShape = ({int nodes, int bytes, int depth});

final class _EvaluationFault implements Exception {
  const _EvaluationFault(this.code, [this.detail = '']);
  final UiDiagnosticCode code;
  final String detail;
}

/// Synchronous pure evaluation of one accepted input batch. Derived references
/// are resolved in dependency order, never by recursively entering another
/// declaration. The host reads all related outputs from this same batch.
final class UiEvaluationBatch {
  UiEvaluationBatch(
    this.program,
    Map<String, Object?> overrides, {
    UiEvaluationBatch? previous,
    this.operationLimit = UiBudgets.operationsPerBatch,
  }) {
    if (operationLimit < 0 || operationLimit > UiBudgets.operationsPerBatch) {
      throw ArgumentError.value(operationLimit, 'operationLimit');
    }
    final inputs = <String, Object?>{};
    for (final state
        in program.declarations.values.whereType<UiStateDeclaration>()) {
      final raw = overrides.containsKey(state.name)
          ? overrides[state.name]
          : state.initialValue;
      final scalar = raw == null || raw is num || raw is String || raw is bool;
      inputs[state.name] = raw is num
          ? (raw == 0 ? 0.0 : raw.toDouble())
          : scalar
          ? raw
          : null;
      final validType = raw == null
          ? state.nullable
          : switch (state.type) {
              UiScalarType.number => raw is num,
              UiScalarType.string => raw is String,
              UiScalarType.boolean => raw is bool,
            };
      if (!validType || (raw is num && !raw.isFinite)) {
        _inputErrors[state.name] = UiDiagnostic(
          raw is num && !raw.isFinite
              ? UiDiagnosticCode.nonFinite
              : UiDiagnosticCode.typeMismatch,
          line: state.location.line,
          symbol: state.name,
        );
      }
    }
    for (final name in overrides.keys.where(
      (name) => !inputs.containsKey(name),
    )) {
      _inputErrors[name] = UiDiagnostic(
        UiDiagnosticCode.invalidBinding,
        line: 1,
        symbol: name,
      );
    }
    this.inputs = Map.unmodifiable(inputs);
    if (previous != null && identical(previous.program, program)) {
      for (final entry in previous._values.entries) {
        if (entry.value.valid) {
          _values[entry.key] = entry.value;
        } else {
          _dirty.add(entry.key);
        }
      }
      for (final name in inputs.keys) {
        if (inputs[name] != previous.inputs[name] ||
            _inputErrors[name]?.code != previous._inputErrors[name]?.code) {
          _dirty.add(name);
        }
      }
      final reverse = <String, Set<String>>{};
      for (final entry in program.dependencies.entries) {
        for (final dependency in entry.value) {
          reverse.putIfAbsent(dependency, () => {}).add(entry.key);
        }
      }
      final pending = _dirty.toList();
      while (pending.isNotEmpty) {
        for (final dependent
            in reverse[pending.removeLast()] ?? const <String>{}) {
          if (_dirty.add(dependent)) pending.add(dependent);
        }
      }
      for (final name in _dirty) {
        _values.remove(name);
      }
    } else {
      _dirty.addAll(program.declarations.keys);
    }
  }

  final UiValidationResult program;
  final int operationLimit;
  late final Map<String, Object?> inputs;
  final Map<String, UiDiagnostic> _inputErrors = {};
  final Map<String, UiComputedValue> _values = {};
  // Containers produced by this evaluator have identity equality; scalar keys
  // use value hashes. identityHashCode is not a suitable hash for doubles and
  // turns large numeric datasets into repeated collision-chain scans.
  final Map<Object, _ValueShape> _shapes = {};
  final Set<Object> _sampledArrays = Set.identity();
  final Set<String> _dirty = {};
  bool _resolved = false;
  int _operations = 0;
  int _sampling = 0;
  int get operations => _operations;
  Set<String> get dirtySymbols => Set.unmodifiable(_dirty);
  Map<String, UiDiagnostic> get inputErrors => Map.unmodifiable(_inputErrors);
  Map<String, UiComputedValue> get values {
    _resolveDerived();
    return Map.unmodifiable(_values);
  }

  UiComputedValue readValue(String name) {
    _resolveDerived();
    return _values[name] ??
        UiComputedValue._(
          error: _diagnostic(name, UiDiagnosticCode.missingReference, name),
        );
  }

  UiComputedValue readExpression(String owner, UiExpression expression) {
    _resolveDerived();
    return _compute(owner, expression);
  }

  void _resolveDerived() {
    if (_resolved) return;
    _resolved = true;
    final ordering = uiDependencyOrder({
      for (final declaration
          in program.declarations.values.whereType<UiValueDeclaration>())
        declaration.name: program.dependencies[declaration.name] ?? {},
    });
    for (final name in ordering.order) {
      if (_values.containsKey(name)) continue;
      final declaration = program.declarations[name]! as UiValueDeclaration;
      _values[name] = _compute(name, declaration.expression);
    }
  }

  UiComputedValue _compute(String owner, UiExpression expression) {
    if (program.failedSymbols.contains(owner)) {
      return UiComputedValue._(
        error:
            program.diagnostics.where((d) => d.symbol == owner).firstOrNull ??
            _diagnostic(owner, UiDiagnosticCode.dependency),
      );
    }
    final gaps = <UiSampleGap>{};
    try {
      final value = _eval(expression, const {}, gaps);
      return UiComputedValue._(
        value: value,
        sampled: _sampledArrays.contains(value),
        gaps: gaps,
        shape: _valueShape(value),
      );
    } on _EvaluationFault catch (fault) {
      return UiComputedValue._(
        error: _diagnostic(owner, fault.code, fault.detail),
      );
    }
  }

  UiDiagnostic _diagnostic(
    String owner,
    UiDiagnosticCode code, [
    String detail = '',
  ]) => UiDiagnostic(
    code,
    line: program.declarations[owner]?.location.line ?? 1,
    symbol: owner,
    detail: detail.length > 160 ? detail.substring(0, 160) : detail,
  );

  void _tick() {
    if (_operations >= operationLimit) {
      throw const _EvaluationFault(UiDiagnosticCode.operationsBudget);
    }
    _operations++;
  }

  // A small DAG can otherwise expand exponentially when copied or serialized.
  // Cache immutable container identities and scalar values, including derived
  // values reused from the preceding batch.
  _ValueShape _valueShape(Object? value) {
    if (value == null) return (nodes: 1, bytes: 4, depth: 1);
    if (_shapes[value] case final cached?) return cached;
    late final _ValueShape result;
    if (value is List || value is Map) {
      var nodes = 1;
      var bytes = 2;
      var depth = 1;
      var count = 0;
      final entries = value is List
          ? value.map((item) => MapEntry<String?, Object?>(null, item))
          : (value as Map).entries.map(
              (entry) =>
                  MapEntry<String?, Object?>(entry.key as String, entry.value),
            );
      for (final entry in entries) {
        final shape = _valueShape(entry.value);
        nodes += shape.nodes;
        bytes += shape.bytes + (count++ == 0 ? 0 : 1);
        if (entry.key != null) bytes += _valueShape(entry.key).bytes + 1;
        depth = math.max(depth, shape.depth + 1);
        _checkShape(nodes, bytes, depth);
      }
      result = (nodes: nodes, bytes: bytes, depth: depth);
    } else {
      if (value is String && value.length > UiBudgets.sourceBytes) {
        throw const _EvaluationFault(UiDiagnosticCode.dataBudget);
      }
      final bytes = utf8.encode(jsonEncode(value)).length;
      _checkShape(1, bytes, 1);
      result = (nodes: 1, bytes: bytes, depth: 1);
    }
    return _shapes[value] = result;
  }

  void _checkShape(int nodes, int bytes, int depth) {
    if (depth > UiBudgets.expressionDepth) {
      throw const _EvaluationFault(UiDiagnosticCode.expressionDepth);
    }
    if (nodes > UiBudgets.operationsPerBatch || bytes > UiBudgets.sourceBytes) {
      throw const _EvaluationFault(UiDiagnosticCode.dataBudget);
    }
  }

  double _number(Object? value) {
    if (value is! num) {
      throw const _EvaluationFault(UiDiagnosticCode.typeMismatch);
    }
    return _finite(value);
  }

  double _finite(num value) {
    if (value.isNaN) throw const _EvaluationFault(UiDiagnosticCode.domain);
    if (!value.isFinite) {
      throw const _EvaluationFault(UiDiagnosticCode.nonFinite);
    }
    return value == 0 ? 0.0 : value.toDouble();
  }

  bool _boolean(Object? value) {
    if (value is! bool) {
      throw const _EvaluationFault(UiDiagnosticCode.typeMismatch);
    }
    return value;
  }

  Object? _eval(
    UiExpression expression,
    Map<String, double> locals,
    Set<UiSampleGap> gaps,
  ) {
    switch (expression) {
      case UiLiteral(:final value):
        if (value != null &&
            value is! num &&
            value is! String &&
            value is! bool) {
          throw const _EvaluationFault(UiDiagnosticCode.typeMismatch);
        }
        return value is num ? _finite(value) : value;
      case UiRead(:final name, :final state):
        if (!state && locals.containsKey(name)) return locals[name];
        if (program.failedSymbols.contains(name)) {
          throw _EvaluationFault(UiDiagnosticCode.dependency, name);
        }
        if (state) {
          if (_inputErrors[name] case final error?) {
            throw _EvaluationFault(error.code, name);
          }
          if (!inputs.containsKey(name)) {
            throw _EvaluationFault(UiDiagnosticCode.missingReference, name);
          }
          return inputs[name];
        }
        final value = _values[name];
        if (value == null) {
          throw _EvaluationFault(UiDiagnosticCode.missingReference, name);
        }
        if (!value.valid) {
          throw _EvaluationFault(UiDiagnosticCode.dependency, name);
        }
        if (value.value != null && value._shape != null) {
          _shapes[value.value!] = value._shape;
        }
        gaps.addAll(value.gaps);
        if (value.sampled && value.value != null) {
          _sampledArrays.add(value.value!);
        }
        return value.value;
      case UiUnary(:final operator, :final operand):
        _tick();
        final value = _eval(operand, locals, gaps);
        return switch (operator) {
          '!' => !_boolean(value),
          '-' => _finite(-_number(value)),
          _ => throw const _EvaluationFault(UiDiagnosticCode.syntax),
        };
      case UiBinary(:final operator, :final left, :final right):
        _tick();
        final a = _eval(left, locals, gaps);
        if (operator == '&&') {
          return _boolean(a) && _boolean(_eval(right, locals, gaps));
        }
        if (operator == '||') {
          return _boolean(a) || _boolean(_eval(right, locals, gaps));
        }
        final b = _eval(right, locals, gaps);
        if (operator == '==' || operator == '!=') {
          if (a is List || a is Map || b is List || b is Map) {
            throw const _EvaluationFault(UiDiagnosticCode.typeMismatch);
          }
          return operator == '==' ? a == b : a != b;
        }
        final x = _number(a), y = _number(b);
        return switch (operator) {
          '+' => _finite(x + y),
          '-' => _finite(x - y),
          '*' => _finite(x * y),
          '/' =>
            y == 0
                ? throw const _EvaluationFault(UiDiagnosticCode.divisionByZero)
                : _finite(x / y),
          '<' => x < y,
          '<=' => x <= y,
          '>' => x > y,
          '>=' => x >= y,
          _ => throw const _EvaluationFault(UiDiagnosticCode.syntax),
        };
      case UiConditional(:final condition, :final whenTrue, :final whenFalse):
        _tick();
        return _eval(
          _boolean(_eval(condition, locals, gaps)) ? whenTrue : whenFalse,
          locals,
          gaps,
        );
      case UiArray(:final items):
        _tick();
        return List<Object?>.unmodifiable(
          items.map((item) => _eval(item, locals, gaps)),
        );
      case UiObject(:final fields):
        _tick();
        return Map<String, Object?>.unmodifiable(
          fields.map((key, value) => MapEntry(key, _eval(value, locals, gaps))),
        );
      case UiCall(:final function, :final arguments):
        _tick();
        final spec = UiCatalog.functions[function];
        if (spec == null || function == 'sample') {
          throw _EvaluationFault(UiDiagnosticCode.unknownFunction, function);
        }
        if (arguments.length < spec.minimumArguments ||
            arguments.length > spec.maximumArguments) {
          throw const _EvaluationFault(UiDiagnosticCode.typeMismatch);
        }
        final args = arguments
            .map((value) => _number(_eval(value, locals, gaps)))
            .toList();
        final value = _call(function, args);
        return value is num ? _finite(value) : value;
      case UiSample(
        :final parameter,
        :final body,
        :final start,
        :final end,
        :final count,
      ):
        _tick();
        if (_sampling != 0) {
          throw const _EvaluationFault(UiDiagnosticCode.nestedSample);
        }
        final a = _number(_eval(start, locals, gaps));
        final b = _number(_eval(end, locals, gaps));
        final n = _number(_eval(count, locals, gaps));
        if (a >= b ||
            n < UiBudgets.sampleMin ||
            n > UiBudgets.sampleMax ||
            n != n.truncateToDouble()) {
          throw const _EvaluationFault(UiDiagnosticCode.invalidSample);
        }
        final points = <Map<String, Object?>>[];
        final span = b - a;
        var previousX = a;
        _sampling++;
        try {
          for (var i = 0; i < n; i++) {
            _tick();
            final t = i / (n - 1);
            var x = i == 0 ? a : b;
            if (i > 0 && i < n - 1) {
              // Prefer a single offset even across zero. Two weighted terms
              // can turn an exact grid zero into a tiny negative number and
              // invent a sqrt gap (or miss a division-by-zero gap).
              final interpolated = span.isFinite
                  ? _finite(a + span * t)
                  : _finite(a * (1 - t) + b * t);
              x = math.max(previousX, interpolated.clamp(a, b));
            }
            previousX = x;
            Object? y;
            try {
              y = _number(_eval(body, {...locals, parameter: x}, gaps));
            } on _EvaluationFault catch (fault) {
              if (!const {
                UiDiagnosticCode.domain,
                UiDiagnosticCode.divisionByZero,
                UiDiagnosticCode.nonFinite,
              }.contains(fault.code)) {
                rethrow;
              }
              gaps.add(UiSampleGap(x: x, index: i, code: fault.code));
            }
            points.add(Map.unmodifiable({'x': x, 'y': y}));
          }
        } finally {
          _sampling--;
        }
        final result = List<Map<String, Object?>>.unmodifiable(points);
        _sampledArrays.add(result);
        return result;
    }
  }

  int _digits(double value) {
    if (value < 0 || value > 10 || value != value.truncateToDouble()) {
      throw const _EvaluationFault(UiDiagnosticCode.invalidValue);
    }
    return value.toInt();
  }

  Object _call(String name, List<double> args) => switch (name) {
    'abs' => args[0].abs(),
    'min' => math.min(args[0], args[1]),
    'max' => math.max(args[0], args[1]),
    'round' => double.parse(
      args[0].toStringAsFixed(_digits(args.length == 1 ? 0 : args[1])),
    ),
    'formatNumber' => args[0].toStringAsFixed(
      _digits(args.length == 1 ? 0 : args[1]),
    ),
    'clamp' =>
      args[1] > args[2]
          ? throw const _EvaluationFault(UiDiagnosticCode.invalidValue)
          : args[0].clamp(args[1], args[2]),
    'pow' => _finite(math.pow(args[0], args[1])),
    'sqrt' =>
      args[0] < 0
          ? throw const _EvaluationFault(UiDiagnosticCode.domain)
          : _finite(math.sqrt(args[0])),
    'sin' => _finite(math.sin(args[0])),
    'cos' => _finite(math.cos(args[0])),
    _ => throw _EvaluationFault(UiDiagnosticCode.unknownFunction, name),
  };
}
