import 'package:Kelivo/core/models/message_part.dart';
import '../models/ui_context_attachment.dart';

/// A leading, complete, separately persisted TextPart is the only chip marker.
/// A marker typed inside a normal user message remains ordinary text. Both
/// halves remain plain TextParts for providers, backups and old readers.
final class UiUserContextParts {
  UiUserContextParts._(this.context, Iterable<MessagePart> body)
    : body = List.unmodifiable(body);
  final UiContextText? context;
  final List<MessagePart> body;
  String get bodyText => body.whereType<TextPart>().map((p) => p.text).join();

  factory UiUserContextParts.read(List<MessagePart> parts) {
    if (parts.length >= 2 && parts[0] is TextPart && parts[1] is TextPart) {
      final first = parts[0] as TextPart, second = parts[1] as TextPart;
      if (second.text.startsWith('\n\n')) {
        final context = UiContextText.parseSentPart(first.text);
        if (context != null) {
          return UiUserContextParts._(context, [
            TextPart(second.text.substring(2)),
            ...parts.skip(2),
          ]);
        }
      }
    }
    return UiUserContextParts._(null, parts);
  }

  static List<MessagePart> attach(List<MessagePart> body, UiContextText text) =>
      List.unmodifiable([
        TextPart(text.exactText),
        if (body.firstOrNull case final TextPart first) ...[
          TextPart('\n\n${first.text}'),
          ...body.skip(1),
        ] else ...[
          const TextPart('\n\n'),
          ...body,
        ],
      ]);
}
