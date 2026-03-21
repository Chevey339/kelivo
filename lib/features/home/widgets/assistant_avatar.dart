import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/models/assistant.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/sandbox_path_resolver.dart';

class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({
    super.key,
    required this.assistant,
    this.fallbackName,
    this.size = 28,
  });

  final Assistant? assistant;
  final String? fallbackName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarValue = assistant?.avatar?.trim() ?? '';
    final name = (assistant?.name ?? fallbackName ?? '').trim();

    Widget avatar;
    if (avatarValue.isNotEmpty) {
      if (avatarValue.startsWith('http')) {
        avatar = FutureBuilder<String?>(
          future: AvatarCache.getPath(avatarValue),
          builder: (context, snapshot) {
            final path = snapshot.data;
            if (path != null && File(path).existsSync()) {
              return ClipOval(
                child: Image(
                  image: FileImage(File(path)),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              );
            }
            return ClipOval(
              child: Image.network(
                avatarValue,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _AssistantInitialAvatar(cs: cs, name: name, size: size),
              ),
            );
          },
        );
      } else if (!kIsWeb &&
          (avatarValue.startsWith('/') || avatarValue.contains(':'))) {
        final fixedPath = SandboxPathResolver.fix(avatarValue);
        final file = File(fixedPath);
        if (file.existsSync()) {
          avatar = ClipOval(
            child: Image(
              image: FileImage(file),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        } else {
          avatar = _AssistantInitialAvatar(cs: cs, name: name, size: size);
        }
      } else {
        avatar = _AssistantEmojiAvatar(cs: cs, emoji: avatarValue, size: size);
      }
    } else {
      avatar = _AssistantInitialAvatar(cs: cs, name: name, size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: avatar,
    );
  }
}

class _AssistantInitialAvatar extends StatelessWidget {
  const _AssistantInitialAvatar({
    required this.cs,
    required this.name,
    required this.size,
  });

  final ColorScheme cs;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: cs.primary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AssistantEmojiAvatar extends StatelessWidget {
  const _AssistantEmojiAvatar({
    required this.cs,
    required this.emoji,
    required this.size,
  });

  final ColorScheme cs;
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: EmojiText(
        emoji.characters.take(1).toString(),
        fontSize: size * 0.5,
        optimizeEmojiAlign: true,
      ),
    );
  }
}
