import 'package:flutter/foundation.dart';

import 'model_capabilities.dart';
import 'model_tokenizer.dart';
import 'rule_pattern.dart';

/// Where a rule came from. Higher origins always beat lower ones, regardless of
/// pattern specificity, mirroring CSS origin precedence.
enum CapabilityOrigin { builtin, online, user }

/// A rule tagged with its origin and source order.
@immutable
class CapabilityRuleEntry {
  const CapabilityRuleEntry(
    this.rule, {
    required this.origin,
    required this.order,
  });

  final ModelRule rule;
  final CapabilityOrigin origin;
  final int order;
}

/// Identity of the provider currently being resolved against.
@immutable
class ProviderContext {
  const ProviderContext({
    required this.providerId,
    this.displayName,
    this.baseUrl,
  });

  final String providerId;
  final String? displayName;
  final String? baseUrl;

  /// Host of [baseUrl], when parseable.
  String? get host {
    final url = baseUrl;
    if (url == null || url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
    final resolved = uri?.host ?? '';
    return resolved.isEmpty ? null : resolved;
  }

  /// Whether [scope] matches any identifying facet of this provider.
  bool matches(RulePattern scope) {
    for (final candidate in _candidates()) {
      if (candidate.isEmpty) continue;
      if (scope.matches(candidate)) return true;
    }
    return false;
  }

  List<List<String>> _candidates() => <List<String>>[
    ModelTokenizer.splitTokens(providerId),
    if (displayName != null) ModelTokenizer.splitTokens(displayName!),
    if (baseUrl != null) ModelTokenizer.splitTokens(baseUrl!),
    if (host != null) ModelTokenizer.splitTokens(host!),
  ];
}

/// Two same-specificity rules disagreed about a field.
@immutable
class CapabilityConflict {
  const CapabilityConflict({required this.field, required this.values});

  final CapabilityField field;
  final List<Object?> values;

  @override
  String toString() => 'CapabilityConflict(${field.name}: $values)';
}

/// The merged capabilities plus diagnostics.
@immutable
class CapabilityResolution {
  const CapabilityResolution({
    required this.capabilities,
    required this.matched,
    required this.conflicts,
    required this.provenance,
  });

  static const CapabilityResolution none = CapabilityResolution(
    capabilities: ModelCapabilities.empty,
    matched: false,
    conflicts: <CapabilityConflict>[],
    provenance: <CapabilityField, CapabilityOrigin>{},
  );

  final ModelCapabilities capabilities;

  /// Whether any rule matched at all.
  final bool matched;

  /// Equal-specificity disagreements; expected to be empty in a healthy table.
  final List<CapabilityConflict> conflicts;

  /// Which origin supplied each declared field, for debugging.
  final Map<CapabilityField, CapabilityOrigin> provenance;
}

/// Resolves a model id against an ordered set of rules using a CSS-like
/// cascade: origin, then provider scope, then pattern specificity, then source
/// order. Fields merge individually; unset fields let lower rules contribute.
class CapabilityCascade {
  CapabilityCascade(Iterable<CapabilityRuleEntry> entries)
    : _entries = List<CapabilityRuleEntry>.unmodifiable(entries);

  /// Builds a cascade from builtin rules in table order.
  factory CapabilityCascade.builtin(List<ModelRule> rules) {
    return CapabilityCascade(<CapabilityRuleEntry>[
      for (var i = 0; i < rules.length; i++)
        CapabilityRuleEntry(
          rules[i],
          origin: CapabilityOrigin.builtin,
          order: i,
        ),
    ]);
  }

  final List<CapabilityRuleEntry> _entries;

  CapabilityResolution resolve(String modelId, {ProviderContext? provider}) {
    final tokenized = ModelTokenizer.tokenizeModelId(modelId);
    final matches = <_Match>[];
    for (final entry in _entries) {
      final scope = entry.rule.on;
      if (scope != null) {
        if (provider == null) continue;
        if (!provider.matches(RulePattern.parse(scope))) continue;
      }
      final match = RulePattern.parse(entry.rule.match).bestMatch(
        tokenized.tokens,
        date: tokenized.date,
        colonBoundaries: tokenized.colonBoundaries,
      );
      if (match == null) continue;
      matches.add(
        _Match(entry: entry, match: match, providerScoped: scope != null),
      );
    }

    if (matches.isEmpty) return CapabilityResolution.none;

    matches.sort((a, b) {
      final bySpecificity = b.specificity.compareTo(a.specificity);
      if (bySpecificity != 0) return bySpecificity;
      return a.entry.order.compareTo(b.entry.order);
    });

    final conflicts = _collectConflicts(matches);
    final resolved = <CapabilityField, Object?>{};
    final provenance = <CapabilityField, CapabilityOrigin>{};

    for (final match in matches) {
      final capabilities = match.entry.rule.capabilities;
      final clear = match.entry.rule.effectiveClear;
      for (final field in CapabilityField.values) {
        if (resolved.containsKey(field)) continue;
        final value = readCapabilityField(capabilities, field);
        if (value != null) {
          resolved[field] = value;
          provenance[field] = match.entry.origin;
        } else if (clear.contains(field)) {
          resolved[field] = null;
        }
      }
    }

    return CapabilityResolution(
      capabilities: _build(resolved),
      matched: true,
      conflicts: conflicts,
      provenance: Map<CapabilityField, CapabilityOrigin>.unmodifiable(
        provenance,
      ),
    );
  }

  static List<CapabilityConflict> _collectConflicts(List<_Match> matches) {
    final seen = <CapabilityField, Map<_Specificity, Object?>>{};
    final conflicts = <CapabilityConflict>[];
    for (final match in matches) {
      final capabilities = match.entry.rule.capabilities;
      for (final field in CapabilityField.values) {
        final value = readCapabilityField(capabilities, field);
        if (value == null) continue;
        final byKey = seen.putIfAbsent(field, () => <_Specificity, Object?>{});
        if (byKey.containsKey(match.specificity)) {
          if (!capabilityValuesEqual(byKey[match.specificity], value)) {
            conflicts.add(
              CapabilityConflict(
                field: field,
                values: <Object?>[byKey[match.specificity], value],
              ),
            );
          }
        } else {
          byKey[match.specificity] = value;
        }
      }
    }
    return List<CapabilityConflict>.unmodifiable(conflicts);
  }

  static ModelCapabilities _build(Map<CapabilityField, Object?> values) {
    return ModelCapabilities(
      group: values[CapabilityField.group] as String?,
      icon: values[CapabilityField.icon] as String?,
      family: values[CapabilityField.family] as String?,
      toolCall: values[CapabilityField.toolCall] as bool?,
      reasoning: values[CapabilityField.reasoning] as bool?,
      reasoningOptions:
          values[CapabilityField.reasoningOptions] as List<ReasoningOption>?,
      temperature: values[CapabilityField.temperature] as bool?,
      inputModalities:
          values[CapabilityField.inputModalities] as List<CapabilityModality>?,
      outputModalities:
          values[CapabilityField.outputModalities] as List<CapabilityModality>?,
      contextLimit: values[CapabilityField.contextLimit] as int?,
      outputLimit: values[CapabilityField.outputLimit] as int?,
      status: values[CapabilityField.status] as ModelLifecycleStatus?,
      quirks: values[CapabilityField.quirks] as Set<CapabilityQuirk>?,
    );
  }
}

class _Match {
  _Match({
    required this.entry,
    required this.match,
    required this.providerScoped,
  }) : specificity = _Specificity(
         origin: entry.origin,
         providerScoped: providerScoped,
         anchored: match.anchored,
         endAnchored: match.endAnchored,
         consumed: match.consumedTokens,
         literals: match.literalTokens,
       );

  final CapabilityRuleEntry entry;
  final PatternMatch match;
  final bool providerScoped;
  final _Specificity specificity;
}

@immutable
class _Specificity implements Comparable<_Specificity> {
  const _Specificity({
    required this.origin,
    required this.providerScoped,
    required this.anchored,
    required this.endAnchored,
    required this.consumed,
    required this.literals,
  });

  final CapabilityOrigin origin;
  final bool providerScoped;
  final bool anchored;
  final bool endAnchored;
  final int consumed;
  final int literals;

  @override
  int compareTo(_Specificity other) {
    if (origin.index != other.origin.index) {
      return origin.index.compareTo(other.origin.index);
    }
    if (providerScoped != other.providerScoped) {
      return providerScoped ? 1 : -1;
    }
    if (anchored != other.anchored) return anchored ? 1 : -1;
    if (endAnchored != other.endAnchored) return endAnchored ? 1 : -1;
    if (consumed != other.consumed) return consumed.compareTo(other.consumed);
    return literals.compareTo(other.literals);
  }

  @override
  bool operator ==(Object other) =>
      other is _Specificity &&
      origin == other.origin &&
      providerScoped == other.providerScoped &&
      anchored == other.anchored &&
      endAnchored == other.endAnchored &&
      consumed == other.consumed &&
      literals == other.literals;

  @override
  int get hashCode => Object.hash(
    origin,
    providerScoped,
    anchored,
    endAnchored,
    consumed,
    literals,
  );
}
