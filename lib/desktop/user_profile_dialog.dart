import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:characters/characters.dart';

import '../core/providers/user_provider.dart';
import '../desktop/desktop_context_menu.dart';
import '../l10n/app_localizations.dart';
import '../icons/lucide_adapter.dart' as lucide;

Future<void> showUserProfileDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'user-profile-dialog',
    barrierColor: Colors.black.withOpacity(0.25),
    pageBuilder: (ctx, _, __) {
      return const _UserProfileDialogBody();
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _UserProfileDialogBody extends StatefulWidget {
  const _UserProfileDialogBody();
  @override
  State<_UserProfileDialogBody> createState() => _UserProfileDialogBodyState();
}

class _UserProfileDialogBodyState extends State<_UserProfileDialogBody> {
  final GlobalKey _avatarKey = GlobalKey();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final up = context.read<UserProvider>();
    _nameController = TextEditingController(text: up.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final up = context.watch<UserProvider>();

    Widget avatarWidget;
    final type = up.avatarType;
    final value = up.avatarValue;
    if (type == 'emoji' && value != null && value.isNotEmpty) {
      avatarWidget = Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(value, style: const TextStyle(fontSize: 40, decoration: TextDecoration.none)),
      );
    } else if (type == 'url' && value != null && value.isNotEmpty) {
      avatarWidget = ClipOval(
        child: Image.network(
          value,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialAvatar(up.name, cs, size: 84),
        ),
      );
    } else if (type == 'file' && value != null && value.isNotEmpty) {
      avatarWidget = ClipOval(
        child: Image(
          image: FileImage(File(value)),
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      );
    } else {
      avatarWidget = _initialAvatar(up.name, cs, size: 84);
    }

    final dialog = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Material(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  key: _avatarKey,
                  onTapDown: (_) => _openAvatarMenu(context),
                  onSecondaryTapDown: (_) => _openAvatarMenu(context),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.35), width: 1),
                        ),
                        child: avatarWidget,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, width: 2),
                          ),
                          child: Icon(lucide.Lucide.Pencil, size: 14, color: cs.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.backupPageUsername,
                        hintText: l10n.sideDrawerNicknameHint,
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        // Real-time save
                        context.read<UserProvider>().setName(v);
                      },
                      onSubmitted: (_) => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: dialog,
    );
  }

  Widget _initialAvatar(String name, ColorScheme cs, {double size = 84}) {
    final letter = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.none, fontSize: size * 0.44),
      ),
    );
  }

  Future<void> _openAvatarMenu(BuildContext context) async {
    final up = context.read<UserProvider>();
    final l10n = AppLocalizations.of(context)!;
    await showDesktopAnchoredMenu(
      context,
      anchorKey: _avatarKey,
      offset: const Offset(0, 8),
      items: [
        DesktopContextMenuItem(
          icon: lucide.Lucide.User,
          label: l10n.desktopAvatarMenuUseEmoji,
          onTap: () async {
            await up.setAvatarEmoji('😄');
          },
        ),
        DesktopContextMenuItem(
          icon: lucide.Lucide.Image,
          label: l10n.desktopAvatarMenuChangeFromImage,
          onTap: () async {
            // Placeholder same as rail menu for now
            await up.resetAvatar();
          },
        ),
        DesktopContextMenuItem(
          icon: lucide.Lucide.RotateCw,
          label: l10n.desktopAvatarMenuReset,
          onTap: () async {
            await up.resetAvatar();
          },
        ),
      ],
    );
  }
}
