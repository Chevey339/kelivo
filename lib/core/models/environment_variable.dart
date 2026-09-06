class EnvironmentVariable {
  const EnvironmentVariable({
    required this.name,
    required this.value,
    this.note = '',
  });

  final String name;
  final String value;
  final String note;

  static final namePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  Map<String, dynamic> toJson() => {'name': name, 'value': value, 'note': note};

  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) =>
      EnvironmentVariable(
        name: json['name'] as String,
        value: json['value'] as String,
        note: json['note'] as String? ?? '',
      );
}

enum EnvironmentVariableError { invalidName, invalidValue, duplicateName }

/// One immutable snapshot, shared by execution and output redaction.
class EnvironmentExecutionConfig {
  EnvironmentExecutionConfig({
    Map<String, String> variables = const {},
    this.privacyMode = true,
  }) : variables = Map.unmodifiable(variables);

  final Map<String, String> variables;
  final bool privacyMode;
}
