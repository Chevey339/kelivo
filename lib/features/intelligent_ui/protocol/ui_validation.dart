import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'ui_diagnostic.dart';
import 'ui_expression_walk.dart';

final class UiValidationResult {
  UiValidationResult({
    required Map<String, UiDeclaration> declarations,
    required Iterable<UiDiagnostic> diagnostics,
    required Set<String> failedSymbols,
    required Set<String> pendingSymbols,
    required Map<String, Set<String>> dependencies,
    required Map<String, List<String>> children,
  }) : declarations = Map.unmodifiable(declarations),
       diagnostics = List.unmodifiable(diagnostics),
       failedSymbols = Set.unmodifiable(failedSymbols),
       pendingSymbols = Set.unmodifiable(pendingSymbols),
       dependencies = Map.unmodifiable(
         dependencies.map(
           (key, value) => MapEntry(key, Set<String>.unmodifiable(value)),
         ),
       ),
       children = Map.unmodifiable(
         children.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       );
  final Map<String, UiDeclaration> declarations;
  final List<UiDiagnostic> diagnostics;
  final Set<String> failedSymbols;
  final Set<String> pendingSymbols;
  final Map<String, Set<String>> dependencies;
  final Map<String, List<String>> children;
}

enum _Kind { number, string, boolean, array, record, nullValue, pending, error }

typedef _Type = ({_Kind kind, bool nullable});
const _number = (kind: _Kind.number, nullable: false);
const _string = (kind: _Kind.string, nullable: false);
const _boolean = (kind: _Kind.boolean, nullable: false);
const _array = (kind: _Kind.array, nullable: false);
const _record = (kind: _Kind.record, nullable: false);
const _null = (kind: _Kind.nullValue, nullable: true);
const _pending = (kind: _Kind.pending, nullable: false);
const _errorType = (kind: _Kind.error, nullable: false);

/// Validates the current complete records. Missing forward refs are not errors
/// until closure. Structural errors do not poison unrelated parent subtrees.
final class UiValidator {
  UiValidator(
    Map<String, UiDeclaration> declarations, {
    required this.closed,
    Iterable<UiDiagnostic> diagnostics = const [],
    Set<String> failedSymbols = const {},
  }) : _declarations = Map.of(declarations),
       _diagnostics = List.of(diagnostics),
       _failed = Set.of(failedSymbols);
  final bool closed;
  final Map<String, UiDeclaration> _declarations;
  final List<UiDiagnostic> _diagnostics;
  final Set<String> _failed;
  final Set<String> _pendingSymbols = {};
  final Map<String, Set<String>> _dependencies = {};
  final Map<String, List<String>> _children = {};
  final Map<String, _Type> _types = {};

  UiValidationResult validate() {
    for (final declaration in _declarations.values.toList()) {
      final name = declaration.name;
      if (const {
            'ui',
            'catalog',
            'let',
            'true',
            'false',
            'null',
            'Ask',
            'Reset',
          }.contains(name) ||
          (name == 'root' && declaration is! UiNodeDeclaration)) {
        _error(name, UiDiagnosticCode.reservedName);
      }
      if (declaration is UiStateDeclaration) {
        _validateState(declaration);
      } else if (declaration is UiValueDeclaration) {
        _checkExpression(name, declaration.expression);
        _dependencies[name] = uiExpressionDependencies(declaration.expression);
      }
    }
    final values = uiDependencyOrder({
      for (final value in _declarations.values.whereType<UiValueDeclaration>())
        value.name: _dependencies[value.name] ?? {},
    });
    for (final name in values.cyclic) {
      _error(name, UiDiagnosticCode.cycle);
    }
    for (final name in values.order) {
      final value = _declarations[name]! as UiValueDeclaration;
      _types[name] = _failed.contains(name)
          ? _errorType
          : _infer(name, value.expression, const {});
    }
    for (final declaration in _declarations.values.toList()) {
      if (declaration is UiNodeDeclaration) _validateNode(declaration);
    }
    _validateTree();
    // Computed-value errors propagate through data dependencies, not children.
    var changed = true;
    while (changed) {
      changed = false;
      for (final entry in _dependencies.entries) {
        if (_failed.contains(entry.key)) continue;
        final bad = entry.value.where(_failed.contains).firstOrNull;
        if (bad != null) {
          _error(entry.key, UiDiagnosticCode.dependency, bad);
          changed = true;
        }
      }
    }
    return UiValidationResult(
      declarations: _declarations,
      diagnostics: _diagnostics,
      failedSymbols: _failed,
      pendingSymbols: _pendingSymbols,
      dependencies: _dependencies,
      children: _children,
    );
  }

  void _error(
    String name,
    UiDiagnosticCode code, [
    String detail = '',
    int? sourceLine,
  ]) {
    _failed.add(name);
    final bounded = detail.length > 160 ? detail.substring(0, 160) : detail;
    if (_diagnostics.length >= UiBudgets.declarations ||
        _diagnostics.any(
          (e) => e.symbol == name && e.code == code && e.detail == bounded,
        )) {
      return;
    }
    _diagnostics.add(
      UiDiagnostic(
        code,
        line: sourceLine ?? _declarations[name]?.location.line ?? 1,
        symbol: name,
        detail: bounded,
      ),
    );
  }

  void _validateState(UiStateDeclaration state) {
    final value = state.initialValue;
    if (value == null) {
      if (!state.nullable) _error(state.name, UiDiagnosticCode.typeMismatch);
    } else if (value is num && !value.isFinite) {
      _error(state.name, UiDiagnosticCode.nonFinite);
    } else if (!switch (state.type) {
      UiScalarType.number => value is num,
      UiScalarType.string => value is String,
      UiScalarType.boolean => value is bool,
    }) {
      _error(state.name, UiDiagnosticCode.typeMismatch);
    }
  }

  bool _checkExpression(String owner, UiExpression expression) {
    var valid = true;
    final pending = <(UiExpression, int, bool)>[(expression, 1, false)];
    while (pending.isNotEmpty) {
      final (value, depth, inSample) = pending.removeLast();
      if (depth > UiBudgets.expressionDepth) {
        _error(owner, UiDiagnosticCode.expressionDepth);
        return false;
      }
      if (value case UiLiteral(value: num value) when !value.isFinite) {
        _error(owner, UiDiagnosticCode.nonFinite);
        valid = false;
      }
      if (value is UiSample && inSample) {
        _error(owner, UiDiagnosticCode.nestedSample);
        valid = false;
      }
      for (final child in uiExpressionChildren(value)) {
        pending.add((child, depth + 1, inSample || value is UiSample));
      }
    }
    return valid;
  }

  void _validateNode(UiNodeDeclaration node) {
    final spec = UiCatalog.components[node.component];
    if (spec == null) {
      _error(node.name, UiDiagnosticCode.unknownComponent, node.component);
      return;
    }
    final values = Map.of(node.arguments);
    final deps = _dependencies.putIfAbsent(node.name, () => {});
    for (final name in values.keys) {
      if (!spec.properties.containsKey(name)) {
        _error(node.name, UiDiagnosticCode.unknownProperty, name);
      }
    }
    for (final entry in spec.properties.entries) {
      final key = entry.key;
      final property = entry.value;
      var value = values[key];
      if (value == null) {
        if (property.required) {
          _error(node.name, UiDiagnosticCode.missingProperty, key);
        }
        if (property.defaultValue != null) {
          values[key] = UiLiteral(property.defaultValue);
        }
        continue;
      }
      switch (property.slot) {
        case UiSlot.children:
          if (value is! UiArray ||
              value.items.any((item) => item is! UiRead || item.state)) {
            _error(node.name, UiDiagnosticCode.invalidReference, key);
            continue;
          }
          final names = value.items
              .cast<UiRead>()
              .map((item) => item.name)
              .toList();
          _children[node.name] = names;
          values[key] = UiChildRefs(names);
          for (final name in names) {
            final target = _declarations[name];
            if (target == null) {
              if (_failed.contains(name)) continue;
              if (closed) {
                _error(
                  name,
                  UiDiagnosticCode.missingReference,
                  node.name,
                  node.location.line,
                );
              } else {
                _pendingSymbols.add(name);
              }
            } else if (target is! UiNodeDeclaration) {
              _error(node.name, UiDiagnosticCode.invalidReference, name);
            }
          }
        case UiSlot.form:
          if (value is! UiRead || value.state) {
            _error(node.name, UiDiagnosticCode.invalidReference, key);
            continue;
          }
          final target = _declarations[value.name];
          deps.add(value.name);
          values[key] = UiFormRef(value.name);
          if (target == null) {
            _missing(node.name, value.name);
          } else if (target is! UiNodeDeclaration ||
              target.component != 'Form') {
            _error(node.name, UiDiagnosticCode.invalidReference, value.name);
          }
        case UiSlot.binding:
          if (value is! UiRead || !value.state) {
            _error(node.name, UiDiagnosticCode.invalidBinding, key);
            continue;
          }
          deps.add(value.name);
          values[key] = UiInputBinding(value.name);
          final target = _declarations[value.name];
          if (target == null) {
            _missing(node.name, value.name);
          } else if (target is! UiStateDeclaration ||
              !_accepts(property, _stateType(target))) {
            _error(node.name, UiDiagnosticCode.invalidBinding, value.name);
          }
        case UiSlot.action:
          if (value is! UiAction) {
            _error(node.name, UiDiagnosticCode.invalidAction, key);
            continue;
          }
          if (value is UiAsk) {
            _validateExpressionProperty(
              node.name,
              'text',
              value.text,
              UiCatalog.actions['Ask']!.arguments['text']!,
              deps,
            );
            _validateExpressionProperty(
              node.name,
              'context',
              value.context,
              UiCatalog.actions['Ask']!.arguments['context']!,
              deps,
            );
          }
        case UiSlot.value:
          if (value is! UiExpression) {
            _error(node.name, UiDiagnosticCode.typeMismatch, key);
            continue;
          }
          _validateExpressionProperty(node.name, key, value, property, deps);
      }
    }
    _declarations[node.name] = UiNodeDeclaration(
      node.name,
      node.location,
      component: node.component,
      arguments: values,
    );
  }

  void _validateExpressionProperty(
    String owner,
    String key,
    UiExpression value,
    UiPropertySpec property,
    Set<String> dependencies,
  ) {
    dependencies.addAll(uiExpressionDependencies(value));
    if (!_checkExpression(owner, value)) return;
    final type = _infer(owner, value, const {});
    if (!_accepts(property, type)) {
      _error(owner, UiDiagnosticCode.typeMismatch, key);
    }
    if (value case UiLiteral(:final value)) {
      if (property.choices.isNotEmpty && !property.choices.contains(value)) {
        _error(owner, UiDiagnosticCode.invalidValue, key);
      }
      if (value is num &&
          ((property.min != null && value < property.min!) ||
              (property.max != null && value > property.max!) ||
              (property.integer && value != value.truncateToDouble()))) {
        _error(owner, UiDiagnosticCode.invalidValue, key);
      }
    }
  }

  _Type _stateType(UiStateDeclaration state) => (
    kind: switch (state.type) {
      UiScalarType.number => _Kind.number,
      UiScalarType.string => _Kind.string,
      UiScalarType.boolean => _Kind.boolean,
    },
    nullable: state.nullable,
  );

  bool _accepts(UiPropertySpec property, _Type type) {
    if (type.kind == _Kind.pending || type.kind == _Kind.error) return true;
    if (type.nullable && !property.nullable) return false;
    if (type.kind == _Kind.nullValue) return property.nullable;
    return switch (property.type) {
      UiValueType.number => type.kind == _Kind.number,
      UiValueType.string => type.kind == _Kind.string,
      UiValueType.boolean => type.kind == _Kind.boolean,
      UiValueType.scalar => {
        _Kind.number,
        _Kind.string,
        _Kind.boolean,
      }.contains(type.kind),
      UiValueType.array => type.kind == _Kind.array,
      UiValueType.record => type.kind == _Kind.record,
      UiValueType.sampleBody => false,
    };
  }

  _Type _missing(String owner, String name) {
    if (_failed.contains(name)) {
      _error(owner, UiDiagnosticCode.dependency, name);
      return _errorType;
    }
    if (closed) {
      _error(owner, UiDiagnosticCode.missingReference, name);
      return _errorType;
    }
    _pendingSymbols.add(name);
    return _pending;
  }

  _Type _typeOfValue(String name) {
    if (_failed.contains(name)) return _errorType;
    return _types[name] ?? _errorType;
  }

  _Type _infer(String owner, UiExpression expression, Set<String> locals) {
    _Type bad() {
      _error(owner, UiDiagnosticCode.typeMismatch);
      return _errorType;
    }

    bool isKind(_Type type, _Kind kind) => type.kind == kind && !type.nullable;
    switch (expression) {
      case UiLiteral(:final value):
        return switch (value) {
          null => _null,
          num() => _number,
          String() => _string,
          bool() => _boolean,
          _ => bad(),
        };
      case UiRead(:final name, :final state):
        if (!state && locals.contains(name)) return _number;
        final target = _declarations[name];
        if (target == null) return _missing(owner, name);
        if (_failed.contains(name)) {
          _error(owner, UiDiagnosticCode.dependency, name);
          return _errorType;
        }
        if (state && target is UiStateDeclaration) return _stateType(target);
        if (!state && target is UiValueDeclaration) return _typeOfValue(name);
        return bad();
      case UiUnary(:final operator, :final operand):
        final type = _infer(owner, operand, locals);
        if (type.kind == _Kind.pending || type.kind == _Kind.error) return type;
        final expected = operator == '!' ? _Kind.boolean : _Kind.number;
        return isKind(type, expected) ? type : bad();
      case UiBinary(:final operator, :final left, :final right):
        final a = _infer(owner, left, locals), b = _infer(owner, right, locals);
        if (a.kind == _Kind.error || b.kind == _Kind.error) return _errorType;
        if (a.kind == _Kind.pending || b.kind == _Kind.pending) return _pending;
        if (operator == '==' || operator == '!=') {
          if ({_Kind.array, _Kind.record}.contains(a.kind) ||
              {_Kind.array, _Kind.record}.contains(b.kind)) {
            return bad();
          }
          return a.kind == b.kind ||
                  a.kind == _Kind.nullValue ||
                  b.kind == _Kind.nullValue
              ? _boolean
              : bad();
        }
        if (operator == '&&' || operator == '||') {
          return isKind(a, _Kind.boolean) && isKind(b, _Kind.boolean)
              ? _boolean
              : bad();
        }
        if (!isKind(a, _Kind.number) || !isKind(b, _Kind.number)) return bad();
        return {'<', '<=', '>', '>='}.contains(operator) ? _boolean : _number;
      case UiConditional(:final condition, :final whenTrue, :final whenFalse):
        final test = _infer(owner, condition, locals);
        final a = _infer(owner, whenTrue, locals),
            b = _infer(owner, whenFalse, locals);
        if (test.kind == _Kind.error ||
            a.kind == _Kind.error ||
            b.kind == _Kind.error) {
          return _errorType;
        }
        if (test.kind == _Kind.pending ||
            a.kind == _Kind.pending ||
            b.kind == _Kind.pending) {
          return _pending;
        }
        if (!isKind(test, _Kind.boolean)) return bad();
        if (a.kind == b.kind) {
          return (kind: a.kind, nullable: a.nullable || b.nullable);
        }
        if (a.kind == _Kind.nullValue) return (kind: b.kind, nullable: true);
        if (b.kind == _Kind.nullValue) return (kind: a.kind, nullable: true);
        return bad();
      case UiArray(:final items):
        for (final item in items) {
          _infer(owner, item, locals);
        }
        return _array;
      case UiObject(:final fields):
        for (final item in fields.values) {
          _infer(owner, item, locals);
        }
        return _record;
      case UiCall(:final function, :final arguments):
        final spec = UiCatalog.functions[function];
        if (spec == null || function == 'sample') {
          _error(owner, UiDiagnosticCode.unknownFunction, function);
          return _errorType;
        }
        if (arguments.length < spec.minimumArguments ||
            arguments.length > spec.maximumArguments) {
          return bad();
        }
        for (var i = 0; i < arguments.length; i++) {
          final type = _infer(owner, arguments[i], locals);
          if (!_accepts(UiPropertySpec(spec.parameters[i]), type)) return bad();
        }
        return spec.result == UiValueType.string ? _string : _number;
      case UiSample(
        :final parameter,
        :final body,
        :final start,
        :final end,
        :final count,
      ):
        for (final argument in [start, end, count]) {
          if (!_accepts(
            const UiPropertySpec(UiValueType.number),
            _infer(owner, argument, locals),
          )) {
            return bad();
          }
        }
        if (!_accepts(
          const UiPropertySpec(UiValueType.number),
          _infer(owner, body, {...locals, parameter}),
        )) {
          return bad();
        }
        if (count case UiLiteral(value: num n)
            when n < UiBudgets.sampleMin ||
                n > UiBudgets.sampleMax ||
                n != n.truncateToDouble()) {
          _error(owner, UiDiagnosticCode.invalidSample);
        }
        return _array;
    }
  }

  void _validateTree() {
    final layoutOrder = uiDependencyOrder({
      for (final node in _declarations.values.whereType<UiNodeDeclaration>())
        node.name: (_children[node.name] ?? const <String>[]).toSet(),
    });
    for (final name in layoutOrder.cyclic) {
      _error(name, UiDiagnosticCode.cycle);
    }
    final root = _declarations['root'];
    if (root is! UiNodeDeclaration) {
      if (closed) _error('root', UiDiagnosticCode.missingRoot);
      return;
    }
    final parents = <String, String>{};
    for (final entry in _children.entries) {
      for (final child in entry.value) {
        if (parents.containsKey(child)) {
          _error(child, UiDiagnosticCode.duplicateParent);
        }
        parents[child] = entry.key;
      }
    }
    final visited = <String>{};
    final path = <String>[];
    void visit(String name, int depth) {
      if (depth > UiBudgets.componentDepth) {
        _error(name, UiDiagnosticCode.componentDepth);
        return;
      }
      final cycleStart = path.indexOf(name);
      if (cycleStart >= 0) {
        for (final member in path.skip(cycleStart)) {
          _error(member, UiDiagnosticCode.cycle);
        }
        return;
      }
      if (!visited.add(name)) return;
      path.add(name);
      for (final child in _children[name] ?? const <String>[]) {
        visit(child, depth + 1);
      }
      path.removeLast();
    }

    visit('root', 1);
    if (closed) {
      for (final node in _declarations.values.whereType<UiNodeDeclaration>()) {
        if (!visited.contains(node.name)) {
          _error(node.name, UiDiagnosticCode.unreachableNode);
        }
      }
    }
  }
}
