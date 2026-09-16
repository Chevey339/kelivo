import 'package:flutter/foundation.dart';

/// Input/output modalities a model accepts or produces.
enum CapabilityModality { text, image, audio, video, pdf }

/// The shape of a model's reasoning control, mirroring models.dev
/// `reasoning_options[].type`.
enum ReasoningOptionType { effort, toggle, budgetTokens }

/// Lifecycle marker mirroring models.dev `status`.
enum ModelLifecycleStatus { beta, deprecated }

/// Model-level wire quirks that cannot be derived from plain capabilities.
enum CapabilityQuirk {
  /// Temperature/top_p/n/penalties must be stripped from the request.
  stripSamplingParameters,

  /// Remote image URLs must not be forwarded as such.
  noRemoteImages,

  /// Tool definitions force the reasoning effort to `none`.
  toolsForceEffortNone,

  /// Thinking cannot be disabled; an `off` request must clamp to the lowest
  /// legal level instead.
  reasoningAlwaysOn,

  /// Sampling parameters are only accepted while thinking is disabled
  /// (`none`/`off`).
  samplingRequiresNoThinking,

  /// `auto` effort also blocks sampling parameters.
  autoDisallowsSampling,

  /// The provider's endpoint has no effort parameter at all; every requested
  /// effort collapses to `auto`.
  effortParameterUnsupported,

  /// An `xhigh` request maps to the model's `max` tier rather than `high`.
  xhighEffortMapsToMax,
}

/// One reasoning control a model exposes.
@immutable
class ReasoningOption {
  const ReasoningOption.effort(this.values)
    : type = ReasoningOptionType.effort,
      minTokens = null,
      maxTokens = null;

  const ReasoningOption.toggle()
    : type = ReasoningOptionType.toggle,
      values = const <String>[],
      minTokens = null,
      maxTokens = null;

  const ReasoningOption.budgetTokens({this.minTokens, this.maxTokens})
    : type = ReasoningOptionType.budgetTokens,
      values = const <String>[];

  final ReasoningOptionType type;

  /// Effort names in ascending order; only populated for [ReasoningOptionType.effort].
  final List<String> values;

  final int? minTokens;
  final int? maxTokens;

  @override
  bool operator ==(Object other) =>
      other is ReasoningOption &&
      type == other.type &&
      listEquals(values, other.values) &&
      minTokens == other.minTokens &&
      maxTokens == other.maxTokens;

  @override
  int get hashCode =>
      Object.hash(type, Object.hashAll(values), minTokens, maxTokens);

  @override
  String toString() => switch (type) {
    ReasoningOptionType.effort => 'effort(${values.join('/')})',
    ReasoningOptionType.toggle => 'toggle',
    ReasoningOptionType.budgetTokens =>
      'budgetTokens(${minTokens ?? '*'}-${maxTokens ?? '*'})',
  };
}

/// Every field a rule can declare, used for provenance and conflict reporting.
enum CapabilityField {
  group,
  icon,
  family,
  toolCall,
  reasoning,
  reasoningOptions,
  temperature,
  inputModalities,
  outputModalities,
  contextLimit,
  outputLimit,
  status,
  quirks,
}

/// Presentation fields that [ModelRule.mask] does not suppress.
const Set<CapabilityField> kIdentityFields = <CapabilityField>{
  CapabilityField.group,
  CapabilityField.icon,
  CapabilityField.family,
};

/// Fields that [ModelRule.mask] suppresses.
const Set<CapabilityField> kCapabilityFields = <CapabilityField>{
  CapabilityField.toolCall,
  CapabilityField.reasoning,
  CapabilityField.reasoningOptions,
  CapabilityField.temperature,
  CapabilityField.inputModalities,
  CapabilityField.outputModalities,
  CapabilityField.contextLimit,
  CapabilityField.outputLimit,
  CapabilityField.status,
  CapabilityField.quirks,
};

/// A resolved capability record. Every field is nullable, and `null` means
/// "absent" rather than "false".
@immutable
class ModelCapabilities {
  const ModelCapabilities({
    this.group,
    this.icon,
    this.family,
    this.toolCall,
    this.reasoning,
    this.reasoningOptions,
    this.temperature,
    this.inputModalities,
    this.outputModalities,
    this.contextLimit,
    this.outputLimit,
    this.status,
    this.quirks,
  });

  static const ModelCapabilities empty = ModelCapabilities();

  final String? group;
  final String? icon;
  final String? family;

  final bool? toolCall;
  final bool? reasoning;
  final List<ReasoningOption>? reasoningOptions;

  /// Whether the model accepts `temperature`/sampling parameters.
  final bool? temperature;

  final List<CapabilityModality>? inputModalities;
  final List<CapabilityModality>? outputModalities;

  final int? contextLimit;
  final int? outputLimit;
  final ModelLifecycleStatus? status;
  final Set<CapabilityQuirk>? quirks;

  bool get isEmpty => CapabilityField.values.every(
    (field) => readCapabilityField(this, field) == null,
  );

  @override
  bool operator ==(Object other) {
    if (other is! ModelCapabilities) return false;
    for (final field in CapabilityField.values) {
      if (!capabilityValuesEqual(
        readCapabilityField(this, field),
        readCapabilityField(other, field),
      )) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    for (final field in CapabilityField.values)
      _hashValue(readCapabilityField(this, field)),
  ]);

  @override
  String toString() => 'ModelCapabilities(${_describe(this)})';
}

/// A single declarative rule: a match pattern plus the fields it declares.
///
/// Fields left unset are "absent" and let the cascade continue to lower-priority
/// rules. [clear] explicitly unsets fields from lower-priority rules, while
/// [mask] is shorthand for clearing every capability field.
@immutable
class ModelRule {
  const ModelRule(
    this.match, {
    this.on,
    this.mask = false,
    this.clear = const <CapabilityField>{},
    this.group,
    this.icon,
    this.family,
    this.toolCall,
    this.reasoning,
    this.reasoningOptions,
    this.temperature,
    this.inputModalities,
    this.outputModalities,
    this.contextLimit,
    this.outputLimit,
    this.status,
    this.quirks,
  });

  /// Pattern DSL; see `rule_pattern.dart`.
  final String match;

  /// Optional provider scope pattern. When set, the rule only applies while
  /// resolving against a matching provider context.
  final String? on;

  final bool mask;
  final Set<CapabilityField> clear;

  final String? group;
  final String? icon;
  final String? family;

  final bool? toolCall;
  final bool? reasoning;
  final List<ReasoningOption>? reasoningOptions;
  final bool? temperature;
  final List<CapabilityModality>? inputModalities;
  final List<CapabilityModality>? outputModalities;
  final int? contextLimit;
  final int? outputLimit;
  final ModelLifecycleStatus? status;
  final Set<CapabilityQuirk>? quirks;

  /// Fields this rule explicitly unsets in lower-priority rules.
  Set<CapabilityField> get effectiveClear =>
      mask ? <CapabilityField>{...kCapabilityFields, ...clear} : clear;

  /// The capability record declared by this rule.
  ModelCapabilities get capabilities => ModelCapabilities(
    group: group,
    icon: icon,
    family: family,
    toolCall: toolCall,
    reasoning: reasoning,
    reasoningOptions: reasoningOptions,
    temperature: temperature,
    inputModalities: inputModalities,
    outputModalities: outputModalities,
    contextLimit: contextLimit,
    outputLimit: outputLimit,
    status: status,
    quirks: quirks,
  );
}

/// Reads a single declared field from [c].
Object? readCapabilityField(ModelCapabilities c, CapabilityField field) =>
    switch (field) {
      CapabilityField.group => c.group,
      CapabilityField.icon => c.icon,
      CapabilityField.family => c.family,
      CapabilityField.toolCall => c.toolCall,
      CapabilityField.reasoning => c.reasoning,
      CapabilityField.reasoningOptions => c.reasoningOptions,
      CapabilityField.temperature => c.temperature,
      CapabilityField.inputModalities => c.inputModalities,
      CapabilityField.outputModalities => c.outputModalities,
      CapabilityField.contextLimit => c.contextLimit,
      CapabilityField.outputLimit => c.outputLimit,
      CapabilityField.status => c.status,
      CapabilityField.quirks => c.quirks,
    };

/// Deep-equality for capability field values (handles lists and sets).
bool capabilityValuesEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) return listEquals(a, b);
  if (a is Set && b is Set) return setEquals(a, b);
  return a == b;
}

Object _hashValue(Object? value) {
  if (value is List) return Object.hashAll(value);
  if (value is Set) return Object.hashAllUnordered(value);
  return value ?? Object();
}

String _describe(ModelCapabilities c) {
  final parts = <String>[
    for (final field in CapabilityField.values)
      if (readCapabilityField(c, field) != null)
        '${field.name}=${readCapabilityField(c, field)}',
  ];
  return parts.join(', ');
}
