final _scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]{1,31}:[^\x00-\x20<>]*$');
final _email = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$",
);
final _bare = RegExp(
  r'''(?:https?://|www\.)[^\s<>]+|[A-Za-z0-9.+_-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}''',
  caseSensitive: false,
);

({int end, String destination, int labelStart, int labelEnd})?
readAngleAutolink(String text, int start) {
  if (text.codeUnitAt(start) != 60) return null;
  var end = start + 1;
  while (end < text.length && text.codeUnitAt(end) != 62) {
    final c = text.codeUnitAt(end);
    if (c <= 32 || c == 60) return null;
    end++;
  }
  if (end == text.length) return null;
  final label = text.substring(start + 1, end);
  final String destination;
  if (_scheme.hasMatch(label)) {
    destination = label;
  } else if (_email.hasMatch(label)) {
    destination = 'mailto:$label';
  } else {
    return null;
  }
  return (
    end: end + 1,
    destination: destination,
    labelStart: start + 1,
    labelEnd: end,
  );
}

({int end, String destination})? readBareAutolink(String text, int start) {
  if (start > 0 && RegExp(r'[A-Za-z0-9_@]').hasMatch(text[start - 1]))
    return null;
  final match = _bare.matchAsPrefix(text, start);
  if (match == null) return null;
  var end = match.end;
  while (end > start && '?!.,:*_~\"\'。！，；'.contains(text[end - 1])) end--;
  final balances = <int, int>{41: 0, 93: 0, 125: 0};
  for (var i = start; i < end; i++) {
    final c = text.codeUnitAt(i);
    if (c == 40 || c == 91 || c == 123) {
      final closer = c == 40 ? 41 : c + 2;
      balances[closer] = balances[closer]! + 1;
    } else if (balances.containsKey(c)) {
      balances[c] = balances[c]! - 1;
    }
  }
  while (end > start && (balances[text.codeUnitAt(end - 1)] ?? 0) < 0) {
    final closer = text.codeUnitAt(--end);
    balances[closer] = balances[closer]! + 1;
  }
  final label = text.substring(start, end);
  if (label.toLowerCase() == 'http://' ||
      label.toLowerCase() == 'https://' ||
      label.toLowerCase() == 'www.')
    return null;
  return (
    end: end,
    destination: label.toLowerCase().startsWith('www.')
        ? 'http://$label'
        : label.contains('://')
        ? label
        : 'mailto:$label',
  );
}

Iterable<({int start, int end, String destination})> bareAutolinks(
  String text,
) sync* {
  if (!text.contains('@') &&
      !text.contains('://') &&
      !text.toLowerCase().contains('www.'))
    return;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (!(c >= 65 && c <= 90 || c >= 97 && c <= 122 || c >= 48 && c <= 57))
      continue;
    if (i > 0) {
      final before = text.codeUnitAt(i - 1);
      if (before >= 65 && before <= 90 ||
          before >= 97 && before <= 122 ||
          before >= 48 && before <= 57 ||
          const {95, 46, 43, 64, 45}.contains(before))
        continue;
    }
    final link = readBareAutolink(text, i);
    if (link != null) {
      yield (start: i, end: link.end, destination: link.destination);
      i = link.end - 1;
    }
  }
}
