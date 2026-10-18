/// Status of a single execution step in a task plan.
enum TaskStepStatus {
  pending,
  inProgress,
  completed,
  failed,
}

extension TaskStepStatusWire on TaskStepStatus {
  String get wireName => switch (this) {
        TaskStepStatus.pending => 'pending',
        TaskStepStatus.inProgress => 'in_progress',
        TaskStepStatus.completed => 'completed',
        TaskStepStatus.failed => 'failed',
      };

  static TaskStepStatus fromWire(Object? raw) {
    return switch (raw?.toString()) {
      'in_progress' || 'inProgress' => TaskStepStatus.inProgress,
      'completed' || 'done' => TaskStepStatus.completed,
      'failed' || 'error' => TaskStepStatus.failed,
      _ => TaskStepStatus.pending,
    };
  }
}

/// A single step in an approved task execution plan.
class TaskStep {
  final String id;
  final String title;
  final TaskStepStatus status;
  final String? note;

  const TaskStep({
    required this.id,
    required this.title,
    this.status = TaskStepStatus.pending,
    this.note,
  });

  TaskStep copyWith({
    String? id,
    String? title,
    TaskStepStatus? status,
    String? note,
  }) {
    return TaskStep(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status.wireName,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory TaskStep.fromJson(Map<String, dynamic> json) {
    return TaskStep(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: TaskStepStatusWire.fromWire(json['status']),
      note: json['note']?.toString(),
    );
  }
}

/// An execution plan containing multiple steps and tracking aggregate progress.
class TaskExecutionPlan {
  final String id;
  final String title;
  final List<TaskStep> steps;
  final int createdAt;
  final int? completedAt;

  const TaskExecutionPlan({
    required this.id,
    required this.title,
    required this.steps,
    required this.createdAt,
    this.completedAt,
  });

  int get totalCount => steps.length;
  int get completedCount =>
      steps.where((s) => s.status == TaskStepStatus.completed).length;

  double get progressFraction {
    if (steps.isEmpty) return 0.0;
    return (completedCount / totalCount).clamp(0.0, 1.0);
  }

  bool get isCompleted =>
      steps.isNotEmpty && steps.every((s) => s.status == TaskStepStatus.completed);

  TaskStep? get activeStep {
    for (final s in steps) {
      if (s.status == TaskStepStatus.inProgress) return s;
    }
    for (final s in steps) {
      if (s.status == TaskStepStatus.pending) return s;
    }
    return null;
  }

  TaskExecutionPlan copyWith({
    String? id,
    String? title,
    List<TaskStep>? steps,
    int? createdAt,
    int? completedAt,
  }) {
    return TaskExecutionPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  TaskExecutionPlan updateStepStatus(
    String stepId,
    TaskStepStatus status, {
    String? note,
  }) {
    final nextSteps = steps.map((s) {
      if (s.id == stepId) {
        return s.copyWith(status: status, note: note);
      }
      return s;
    }).toList();

    final allDone = nextSteps.isNotEmpty &&
        nextSteps.every((s) => s.status == TaskStepStatus.completed);

    return copyWith(
      steps: nextSteps,
      completedAt: allDone ? DateTime.now().millisecondsSinceEpoch : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'steps': steps.map((s) => s.toJson()).toList(),
        'createdAt': createdAt,
        if (completedAt != null) 'completedAt': completedAt,
      };

  factory TaskExecutionPlan.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final stepsList = <TaskStep>[];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is Map<String, dynamic>) {
          stepsList.add(TaskStep.fromJson(item));
        } else if (item is Map) {
          stepsList.add(TaskStep.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return TaskExecutionPlan(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Execution Plan',
      steps: stepsList,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      completedAt: json['completedAt'] as int?,
    );
  }
}

/// Conversation extras view for per-chat Task Execution and Progress Tracking.
class TaskExecutionBinding {
  static const String keyPlan = 'task_execution.plan';

  final TaskExecutionPlan? plan;

  const TaskExecutionBinding({this.plan});

  bool get hasActivePlan => plan != null && !plan!.isCompleted;

  factory TaskExecutionBinding.fromExtras(Map<String, dynamic> extras) {
    final raw = extras[keyPlan];
    if (raw == null) return const TaskExecutionBinding();
    if (raw is Map<String, dynamic>) {
      return TaskExecutionBinding(plan: TaskExecutionPlan.fromJson(raw));
    }
    if (raw is Map) {
      return TaskExecutionBinding(
        plan: TaskExecutionPlan.fromJson(Map<String, dynamic>.from(raw)),
      );
    }
    return const TaskExecutionBinding();
  }

  Map<String, dynamic> applyTo(Map<String, dynamic> extras) {
    final next = Map<String, dynamic>.from(extras);
    if (plan == null) {
      next.remove(keyPlan);
    } else {
      next[keyPlan] = plan!.toJson();
    }
    return next;
  }
}
