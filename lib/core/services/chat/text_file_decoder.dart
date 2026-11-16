import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chinese_codec/chinese_codec.dart';

import '../../../utils/unicode_sanitizer.dart';
import '../../../utils/utf16_safe_cut.dart';
import 'chinese_text_frequency.dart';

const kMaxDocumentExtractBytes = 16 * 1024 * 1024;
const kMaxAttachmentTextCharacters = 100000;

class DocumentText {
  const DocumentText(this.text, {this.truncated = false, this.count = 0});
  final String text;
  final bool truncated;
  final int count;
}

enum AttachmentProblem { encoding, notText, tooLarge, missing, workspace }

class AttachmentReadError implements Exception {
  const AttachmentReadError(this.problem, this.name);
  final AttachmentProblem problem;
  final String name;

  // Chat action results also travel through string-only error channels.
  @override
  String toString() => 'attachment_read:${problem.name}:$name';

  static AttachmentReadError? fromMessage(String message) {
    if (!message.startsWith('attachment_read:')) return null;
    for (final problem in AttachmentProblem.values) {
      final prefix = 'attachment_read:${problem.name}:';
      if (message.startsWith(prefix)) {
        return AttachmentReadError(problem, message.substring(prefix.length));
      }
    }
    return null;
  }
}

/// Decodes only the supplied bytes. A partial character may be dropped at the
/// end only when there are more bytes on disk.
DocumentText decodeTextFile(
  Uint8List bytes, {
  required String name,
  bool byteLimit = false,
}) {
  bool starts(List<int> signature) {
    if (signature.length > bytes.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  final encodingError = AttachmentReadError(AttachmentProblem.encoding, name);
  if (starts(const [0, 0, 0xfe, 0xff]) || starts(const [0xff, 0xfe, 0, 0])) {
    throw encodingError;
  }
  final utf8Bom = starts(const [0xef, 0xbb, 0xbf]);
  final le = starts(const [0xff, 0xfe]);
  if (le || starts(const [0xfe, 0xff])) {
    final data = ByteData.sublistView(bytes, 2);
    final length = data.lengthInBytes ~/ 2;
    // Two units per rune suffice to find the prompt limit plus one lookahead.
    final units = Uint16List(
      math.min(length, 2 * kMaxAttachmentTextCharacters + 2),
    );
    for (var i = 0; i < units.length; i++) {
      units[i] = data.getUint16(i * 2, le ? Endian.little : Endian.big);
    }
    var end = units.length;
    final cut = byteLimit || length > end;
    if (cut &&
        end > 0 &&
        units[end - 1] >= 0xd800 &&
        units[end - 1] <= 0xdbff) {
      end--;
    }
    return _bounded(
      UnicodeSanitizer.sanitize(String.fromCharCodes(units, 0, end)),
      cut,
    );
  }
  if (!utf8Bom && bytes.isNotEmpty) {
    final n = math.min(bytes.length, 8192);
    var zeros = 0;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) zeros++;
    }
    if (zeros * 10 >= n * 3 ||
        starts(const [0x50, 0x4b, 3, 4]) ||
        starts(const [0x50, 0x4b, 5, 6]) ||
        starts(const [0x50, 0x4b, 7, 8])) {
      throw AttachmentReadError(AttachmentProblem.notText, name);
    }
  }
  try {
    // The strict chunk decoder checks the entire prefix, strips its BOM, and
    // holds back a trailing incomplete sequence until close.
    final buffer = StringBuffer();
    final sink = utf8.decoder.startChunkedConversion(
      StringConversionSink.fromStringSink(buffer),
    );
    sink.add(bytes);
    if (!byteLimit) sink.close();
    return _bounded(buffer.toString(), byteLimit);
  } on FormatException {
    if (utf8Bom) throw encodingError;
  }

  final gb = _candidate(
    bytes,
    const Gb18030Codec(allowInvalid: true),
    byteLimit,
  );
  final tw = _candidate(bytes, const Big5Codec(allowInvalid: true), byteLimit);
  if (gb == null && tw == null) throw encodingError;
  if (gb == null) return tw!.output;
  if (tw == null) return gb.output;
  if (gb.roundTrip != tw.roundTrip) return gb.roundTrip ? gb.output : tw.output;
  return tw.penalty < gb.penalty ? tw.output : gb.output;
}

DocumentText _bounded(String text, bool cut) {
  final runes = text.runes.iterator;
  var count = 0;
  var end = 0;
  while (count < kMaxAttachmentTextCharacters && runes.moveNext()) {
    end += runes.current > 0xffff ? 2 : 1;
    count++;
  }
  return DocumentText(
    truncateHeadUtf16Safe(text, end),
    truncated: cut || end < text.length,
    count: count,
  );
}

// Unigram frequency alone cannot distinguish common characters in nonsense
// combinations (e.g. CP950 測試 and GBK 代刚 are the *same bytes*). Give
// familiar word pairs in written Chinese a little extra evidence.
final _commonPairs = {
  for (final word
      in '中文 文章 文件 今天 明天 現在 现在 你好 世界 天氣 天气 問題 问题 可以 我們 我们 因為 因为 所以 如果 這個 这个 資料 资料 使用 閱讀 阅读 內容 内容 文字 訊息 信息 成功 失敗 失败 連線 连线 程式 程序 設計 设计 測試 测试 新聞 新闻 臺灣 台湾'
          .split(' '))
    (word.codeUnitAt(0) << 16) | word.codeUnitAt(1),
};

typedef _Candidate = ({DocumentText output, bool roundTrip, double penalty});

_Candidate? _candidate(Uint8List bytes, Encoding codec, bool cut) {
  var text = codec.decode(bytes);
  var byteEnd = bytes.length;
  if (cut) {
    // Both lenient codecs replace one invalid byte at a time and preserve
    // ASCII digits. Only discard an actual unfinished final character.
    final gb = codec is Gb18030Codec;
    bool lead(int i) =>
        i >= 0 &&
        (gb
            ? bytes[i] >= 0x81 && bytes[i] <= 0xfe
            : bytes[i] >= 0xa1 && bytes[i] <= 0xf9);
    bool digit(int i) => i >= 0 && bytes[i] >= 0x30 && bytes[i] <= 0x39;
    var tail = 0;
    if (gb &&
        lead(byteEnd - 3) &&
        digit(byteEnd - 2) &&
        lead(byteEnd - 1) &&
        text.endsWith(
          '\uFFFD${String.fromCharCode(bytes[byteEnd - 2])}\uFFFD',
        )) {
      tail = 3;
    } else if (gb &&
        lead(byteEnd - 2) &&
        digit(byteEnd - 1) &&
        text.endsWith('\uFFFD${String.fromCharCode(bytes[byteEnd - 1])}')) {
      tail = 2;
    } else if (lead(byteEnd - 1) && text.endsWith('\uFFFD')) {
      tail = 1;
    }
    if (tail > 0) {
      byteEnd -= tail;
      text = text.substring(0, text.length - tail);
    }
  }
  var n = 0, replacement = 0, private = 0, controls = 0, prose = 0;
  var previous = 0;
  for (final c in text.runes) {
    n++;
    if (c == 0xfffd) replacement++;
    if (c >= 0xe000 && c <= 0xf8ff) private++;
    if (c < 32 && c != 9 && c != 10 && c != 13) controls++;
    if (c >= 0x3400 && c <= 0x9fff) {
      prose += chineseProseFrequency(c);
      if (_commonPairs.contains((previous << 16) | c)) prose += 2;
      previous = c;
    } else {
      previous = 0;
    }
  }
  if (n == 0 ||
      replacement * 100 > n ||
      private * 100 > n * 5 ||
      controls * 100 > n * 2) {
    return null;
  }
  return (
    output: _bounded(text, cut),
    roundTrip: _roundTrips(codec, text, bytes, byteEnd),
    penalty: (replacement * 100 + private * 20 + controls * 50 - prose) / n,
  );
}

bool _roundTrips(Encoding codec, String text, Uint8List bytes, int end) {
  var offset = 0;
  // The package's encoders return growable integer lists. Encode in chunks
  // rather than allocating a second 16 MiB file as boxed integers.
  try {
    for (var start = 0; start < text.length;) {
      final stop = utf16SafeHeadEnd(text, math.min(start + 8192, text.length));
      for (final byte in codec.encode(text.substring(start, stop))) {
        if (offset >= end || bytes[offset++] != byte) return false;
      }
      start = stop;
    }
  } on FormatException {
    return false;
  }
  return offset == end;
}
