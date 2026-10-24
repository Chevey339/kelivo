import 'package:flutter/widgets.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/theme/design_tokens.dart';
import 'ui_user_context_parts.dart';
import '../widgets/genui_context_chip.dart';

/// The chat widget delegates chip recognition and presentation to this host
/// adapter. Assistant/tool parts and marker-like ordinary text stay literal.
final class UiUserMessageContent {
  UiUserMessageContent(ChatMessage message)
    : _parts = message.role == 'user'
          ? UiUserContextParts.read(message.parts)
          : null,
      _raw = message.content;
  final UiUserContextParts? _parts;
  final String _raw;
  String get text => _parts?.bodyText ?? _raw;
  bool get hasContext => _parts?.context != null;
  Widget wrap(Widget body) {
    final context = _parts?.context;
    if (context == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GenUiContextChip(content: context, readOnly: true),
        if (text.isNotEmpty) ...[const SizedBox(height: AppSpacing.xs), body],
      ],
    );
  }
}
