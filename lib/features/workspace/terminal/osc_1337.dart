import 'dart:convert';
import 'dart:typed_data';

/// Strips iTerm-style OSC 1337 `KelivoOpenURL` sequences from a PTY byte
/// stream before they reach the emulator, and reports the URL.
///
/// Recognizes both BEL (`ESC ] … BEL`) and ST (`ESC ] … ESC \`) terminators.
/// Incomplete sequences are held across chunks.
class Osc1337Interceptor {
  Osc1337Interceptor({required this.onUrl});

  final void Function(Uri uri) onUrl;

  final List<int> _pending = <int>[];

  static const int maxOscLength = 4096;

  static final RegExp _kelivoOpen = RegExp(
    r'^1337\s*;\s*KelivoOpenURL=(.*)$',
    dotAll: true,
  );

  Uint8List process(Uint8List chunk) {
    if (chunk.isEmpty && _pending.isEmpty) return chunk;
    _pending.addAll(chunk);
    final out = <int>[];
    var i = 0;
    while (i < _pending.length) {
      final b = _pending[i];
      if (b != 0x1b) {
        out.add(b);
        i++;
        continue;
      }
      if (i + 1 >= _pending.length) break;
      if (_pending[i + 1] != 0x5d) {
        out.add(b);
        i++;
        continue;
      }
      final term = _findOscTerminator(_pending, i + 2);
      if (term == null) {
        if (_pending.length - i > maxOscLength) {
          // Unterminated OSC exceeded the hold cap — pass ESC ] through
          // and keep scanning the rest as ordinary bytes.
          out.add(_pending[i]);
          out.add(_pending[i + 1]);
          i += 2;
          continue;
        }
        break;
      }
      if (term.index - (i + 2) > maxOscLength) {
        out.addAll(_pending.sublist(i, term.index + term.length));
        i = term.index + term.length;
        continue;
      }
      final body = utf8.decode(
        _pending.sublist(i + 2, term.index),
        allowMalformed: true,
      );
      if (_handleKelivoOpen(body)) {
        i = term.index + term.length;
        continue;
      }
      out.addAll(_pending.sublist(i, term.index + term.length));
      i = term.index + term.length;
    }
    if (i > 0) _pending.removeRange(0, i);
    if (out.isEmpty) return Uint8List(0);
    return Uint8List.fromList(out);
  }

  bool _handleKelivoOpen(String body) {
    final match = _kelivoOpen.firstMatch(body);
    if (match == null) return false;
    final raw = match.group(1)?.trim() ?? '';
    if (raw.isEmpty) return true;
    final uri = Uri.tryParse(raw);
    if (uri != null) onUrl(uri);
    return true;
  }

  static ({int index, int length})? _findOscTerminator(
    List<int> data,
    int start,
  ) {
    for (var j = start; j < data.length; j++) {
      if (data[j] == 0x07) return (index: j, length: 1);
      if (data[j] == 0x1b) {
        if (j + 1 >= data.length) return null;
        if (data[j + 1] == 0x5c) return (index: j, length: 2);
      }
    }
    return null;
  }
}
