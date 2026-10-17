final class TaskMarker {
  const TaskMarker(this.start, this.end, this.checked, this.radio);
  final int start;
  final int end;
  final bool checked;
  final bool radio;
}

final _taskMarker = RegExp(r'^(\[([ \txX])\]|\(([ \txX])\))(?=[ \t]|$)[ \t]*');

TaskMarker? matchTaskMarker(
  String source,
  int start,
  int end, {
  bool radioItems = true,
  bool checkboxItems = true,
}) {
  final match = _taskMarker.firstMatch(source.substring(start, end));
  if (match == null) return null;
  final radio = match[3] != null;
  if (radio ? !radioItems : !checkboxItems) return null;
  return TaskMarker(
    start,
    start + match.end,
    (match[2] ?? match[3])!.toLowerCase() == 'x',
    radio,
  );
}
