class InstructionInjection {
  final String id;
  final String title;
  final String prompt;
  final String group;

  const InstructionInjection({
    required this.id,
    required this.title,
    required this.prompt,
    this.group = '',
  });

  InstructionInjection copyWith({
    String? id,
    String? title,
    String? prompt,
    String? group,
  }) {
    return InstructionInjection(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      group: group ?? this.group,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'prompt': prompt,
    'group': group,
  };

  static InstructionInjection fromJson(Map<String, dynamic> json) =>
      InstructionInjection(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        prompt: (json['prompt'] as String?) ?? '',
        group: (json['group'] as String?) ?? '',
      );
}
