final _scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]{1,31}:[^\x00-\x20<>]*$');
final _email = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$",
);
const _webPrefixPattern = r'https?://|www\.';
final _webPrefix = RegExp(_webPrefixPattern, caseSensitive: false);
final _bareStart = RegExp(
  '($_webPrefixPattern)|'
  r'[A-Za-z0-9.+_-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}',
  caseSensitive: false,
);
final _gfmBody = RegExp(r'[^\s<>]+');
const _pairs = [
  '（）',
  '【】',
  '「」',
  '『』',
  '《》',
  '〈〉',
  '〔〕',
  '〖〗',
  '［］',
  '｛｝',
  '“”',
  '‘’',
];
const _sentenceMarks = '，。、；：！？～…—';
final _proseMarks = _sentenceMarks + _pairs.join();
const _eastAsian =
    r'\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}';
const _dnsLabelChar = r'[\p{L}\p{M}\p{N}-]';
const _idnDots = '。．｡';
final _pairedMarks = [
  for (final pair in _pairs) '${pair[0]}[^\\s<>$pair]*${pair[1]}',
].join('|');
final _urlToken = RegExp(
  '($_pairedMarks)|([\\s<>$_proseMarks$_idnDots])|([./:?#@&=]+)|'
  '(?:[$_eastAsian\\p{Extended_Pictographic}\\p{Regional_Indicator}][\\p{M}ーｰ]*)+',
  unicode: true,
);
final _userInfo = RegExp('[^\\s<>/?#@\\[\\]$_proseMarks]+@');
final _closedAuthority = RegExp(
  r'\[[^\s<>/?#@\[\]]+\](?::[0-9]+)?|[\p{L}\p{M}\p{N}_.%．｡。-]+:[0-9]+',
  unicode: true,
);
final _iriContinuation = RegExp(
  r'/|[.?#&=@](?=[\p{L}\p{N}%_~-])|:\d',
  unicode: true,
);
final _pairedContinuation = RegExp(
  '(?:$_pairedMarks)+(?=${_iriContinuation.pattern})',
  unicode: true,
);
final _hostLabel = RegExp('$_dnsLabelChar+', unicode: true);
final _asciiTld = RegExp(r'^[A-Za-z]{2,63}$');
final _hostLabelTail = RegExp(
  '$_dnsLabelChar*[.$_idnDots](?=[\\p{L}\\p{N}])',
  unicode: true,
);
final _punctuatedComponent = RegExp(
  '([\\p{L}\\p{M}\\p{N}%_~+$_sentenceMarks-]*)'
  r'(?:[?&][\p{L}\p{M}\p{N}_.%~-]+=|[/#]|\.[A-Za-z][A-Za-z0-9]*)',
  unicode: true,
);

bool _continuesIdnHost(
  String text,
  int offset, {
  required bool internationalLabel,
  required bool firstLabel,
}) {
  if (_webPrefix.matchAsPrefix(text, offset) != null) return false;
  final next = _hostLabel.matchAsPrefix(text, offset);
  if (next == null) return false;
  if (internationalLabel) return true;
  if (firstLabel && _asciiTld.hasMatch(next[0]!)) return true;
  return next.end < text.length && './:?#$_idnDots'.contains(text[next.end]);
}

int _chatUrlEnd(String text, int start) {
  final hostStart = _userInfo.matchAsPrefix(text, start)?.end ?? start;
  final authorityEnd = _closedAuthority.matchAsPrefix(text, hostStart)?.end;
  // A closed IPv6 literal or numeric port can only be followed by a path,
  // query or fragment. Prose after it cannot extend the host.
  if (authorityEnd != null &&
      (authorityEnd == text.length || !'/?#'.contains(text[authorityEnd])))
    return authorityEnd;
  var componentStart = authorityEnd ?? hostStart;
  var componentHasCjk = false;
  var inAuthority = true;
  var protectedUntil = componentStart;
  for (final match in _urlToken.allMatches(text, componentStart)) {
    if (match.end <= protectedUntil) continue;
    final pair = match[1];
    if (pair != null) {
      if (!inAuthority &&
          (componentHasCjk ||
              match.start == componentStart ||
              _iriContinuation.matchAsPrefix(text, match.end) != null) &&
          !_webPrefix.hasMatch(pair))
        continue;
      return match.start;
    }
    final mark = match[2];
    if (mark != null) {
      // IDNA recognizes all three non-ASCII forms of the DNS label separator.
      if (inAuthority &&
          _idnDots.contains(mark) &&
          _continuesIdnHost(
            text,
            match.end,
            firstLabel: componentStart == hostStart,
            internationalLabel:
                (componentStart == hostStart && componentHasCjk) ||
                (componentStart > hostStart &&
                    _idnDots.contains(text[componentStart - 1])),
          )) {
        componentStart = match.end;
        componentHasCjk = false;
        continue;
      }
      if (!inAuthority && componentHasCjk && _sentenceMarks.contains(mark)) {
        final rest = _punctuatedComponent.matchAsPrefix(text, match.end);
        if (rest != null) {
          final separator = match.end + rest[1]!.length;
          // The dot in first.last@example.com belongs to the next address.
          if (_webPrefix.hasMatch(rest[0]!) ||
              (text[separator] == '.' &&
                  _bareStart.matchAsPrefix(text, separator + 1) != null)) {
            return match.start;
          }
          // Protect the text through the last punctuation, leaving the next
          // URL separator for the scanner (including runs such as "=/").
          protectedUntil = separator;
          continue;
        }
      }
      return match.start;
    }
    final separators = match[3];
    if (separators != null) {
      if (separators.contains('/') ||
          separators.contains('?') ||
          separators.contains('#')) {
        inAuthority = false;
      }
      componentStart = match.end;
      componentHasCjk = false;
      continue;
    }
    final followsWord =
        !componentHasCjk &&
        match.start > componentStart &&
        !'([{-_+~'.contains(text[match.start - 1]);
    if (_webPrefix.matchAsPrefix(text, match.end) != null) {
      return followsWord ? match.start : match.end;
    }
    if (followsWord &&
        _iriContinuation.matchAsPrefix(text, match.end) == null) {
      // Only immediate URL structure can establish a mixed-script component.
      // A slash or decimal point later in the prose cannot extend the link.
      final continuation = (inAuthority ? _hostLabelTail : _pairedContinuation)
          .matchAsPrefix(text, match.end);
      if (continuation == null || _webPrefix.hasMatch(continuation[0]!))
        return match.start;
    }
    componentHasCjk = true;
  }
  return text.length;
}

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

({int end, String destination})? readBareAutolink(
  String text,
  int start, {
  required bool cjkBoundaries,
}) {
  if (start > 0 && RegExp(r'[A-Za-z0-9_@]').hasMatch(text[start - 1]))
    return null;
  final match = _bareStart.matchAsPrefix(text, start);
  if (match == null) return null;
  final prefix = match[1];
  if (prefix == null)
    return (end: match.end, destination: 'mailto:${match[0]}');
  var end = cjkBoundaries
      ? _chatUrlEnd(text, match.end)
      : _gfmBody.matchAsPrefix(text, match.end)?.end ?? match.end;
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
  while (end > match.end) {
    final last = text.codeUnitAt(end - 1);
    if ((balances[last] ?? 0) < 0) {
      balances[last] = balances[last]! + 1;
    } else if (!'?!.,:*_~"\'。！，；'.contains(text[end - 1])) {
      break;
    }
    end--;
  }
  if (end <= match.end) return null;
  final label = text.substring(start, end);
  return (
    end: end,
    destination: prefix.toLowerCase() == 'www.' ? 'http://$label' : label,
  );
}

Iterable<({int start, int end, String destination})> bareAutolinks(
  String text, {
  required bool cjkBoundaries,
}) sync* {
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
    final link = readBareAutolink(text, i, cjkBoundaries: cjkBoundaries);
    if (link != null) {
      yield (start: i, end: link.end, destination: link.destination);
      i = link.end - 1;
    }
  }
}
