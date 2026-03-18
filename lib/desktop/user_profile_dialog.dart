import 'dart:io' show File;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../core/providers/user_provider.dart';
import '../desktop/desktop_context_menu.dart';
import '../l10n/app_localizations.dart';
import '../icons/lucide_adapter.dart' as lucide;
import '../shared/widgets/emoji_text.dart';
import '../shared/widgets/emoji_picker_dialog.dart';
import '../shared/widgets/snackbar.dart';
import '../utils/sandbox_path_resolver.dart';

Future<void> showUserProfileDialog(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'user-profile-dialog',
    barrierColor: Colors.black.withValues(alpha: 0.25),
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
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: EmojiText(
          value,
          fontSize: 40,
          optimizeEmojiAlign: true,
          nudge: Offset.zero, // dialog avatar: no extra nudge
        ),
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
      final fixed = SandboxPathResolver.fix(value);
      final f = File(fixed);
      if (f.existsSync()) {
        avatarWidget = ClipOval(
          child: Image(
            image: FileImage(f),
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        );
      } else {
        avatarWidget = _initialAvatar(up.name, cs, size: 84);
      }
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : cs.outlineVariant.withValues(alpha: 0.25),
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
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                            width: 1,
                          ),
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
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1C1C1E)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            lucide.Lucide.Pencil,
                            size: 14,
                            color: cs.onPrimary,
                          ),
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
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
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

    return Material(type: MaterialType.transparency, child: dialog);
  }

  Widget _initialAvatar(String name, ColorScheme cs, {double size = 84}) {
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
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
          fontSize: size * 0.44,
        ),
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
            final emoji = await showEmojiPickerDialog(
              context,
              title: l10n.assistantEditEmojiDialogTitle,
              hintText: l10n.assistantEditEmojiDialogHint,
            );
            if (emoji != null && emoji.isNotEmpty) {
              await up.setAvatarEmoji(emoji);
            }
          },
        ),
        DesktopContextMenuItem(
          icon: lucide.Lucide.Image,
          label: l10n.desktopAvatarMenuChangeFromImage,
          onTap: () async {
            // Desktop: choose an image file and persist it into app's avatars folder
            try {
              final res = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                withData: false,
                type: FileType.custom,
                allowedExtensions: const [
                  'png',
                  'jpg',
                  'jpeg',
                  'gif',
                  'webp',
                  'heic',
                  'heif',
                ],
              );
              final f = (res != null && res.files.isNotEmpty)
                  ? res.files.first
                  : null;
              final path = f?.path;
              if (path != null && path.isNotEmpty) {
                await up.setAvatarFilePath(path);
              }
            } catch (_) {
              // no-op on failure
            }
          },
        ),
        DesktopContextMenuItem(
          icon: lucide.Lucide.Link,
          label: l10n.sideDrawerEnterLink,
          onTap: () async {
            await _inputAvatarUrl(context);
          },
        ),
        DesktopContextMenuItem(
          svgAsset: 'assets/icons/tencent-qq.svg',
          label: l10n.sideDrawerImportFromQQ,
          onTap: () async {
            await _inputQQAvatar(context);
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

  Future<void> _inputAvatarUrl(BuildContext context) async {
    final up = context.read<UserProvider>();
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) =>
            s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.sideDrawerImageUrlDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.sideDrawerImageUrlDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                onChanged: (v) => setLocal(() => value = v),
                onSubmitted: (_) {
                  if (valid(value)) Navigator.of(ctx).pop(true);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.sideDrawerCancel),
                ),
                TextButton(
                  onPressed: valid(value)
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    l10n.sideDrawerSave,
                    style: TextStyle(
                      color: valid(value)
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (ok == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await up.setAvatarUrl(url);
      }
    }
  }

  Future<void> _inputQQAvatar(BuildContext context) async {
    final up = context.read<UserProvider>();
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        String value = '';
        bool valid(String s) => RegExp(r'^[0-9]{5,12}$').hasMatch(s.trim());
        String randomQQ() {
          final lengths = <int>[5, 6, 7, 8, 9, 10, 11];
          final weights = <int>[1, 20, 80, 100, 500, 5000, 80];
          final total = weights.fold<int>(0, (a, b) => a + b);
          final rnd = math.Random();
          int roll = rnd.nextInt(total) + 1;
          int chosenLen = lengths.last;
          int acc = 0;
          for (int i = 0; i < lengths.length; i++) {
            acc += weights[i];
            if (roll <= acc) {
              chosenLen = lengths[i];
              break;
            }
          }
          final sb = StringBuffer();
          final firstGroups = <List<int>>[
            [1, 2],
            [3, 4],
            [5, 6, 7, 8],
            [9],
          ];
          final firstWeights = <int>[128, 4, 2, 1];
          final firstTotal = firstWeights.fold<int>(0, (a, b) => a + b);
          int r2 = rnd.nextInt(firstTotal) + 1;
          int idx = 0;
          int a2 = 0;
          for (int i = 0; i < firstGroups.length; i++) {
            a2 += firstWeights[i];
            if (r2 <= a2) {
              idx = i;
              break;
            }
          }
          final group = firstGroups[idx];
          sb.write(group[rnd.nextInt(group.length)]);
          for (int i = 1; i < chosenLen; i++) {
            sb.write(rnd.nextInt(10));
          }
          return sb.toString();
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.sideDrawerQQAvatarDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.sideDrawerQQAvatarInputHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                onChanged: (v) => setLocal(() => value = v),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Try multiple times until a valid avatar is fetched
                    const int maxTries = 20;
                    bool applied = false;
                    for (int i = 0; i < maxTries; i++) {
                      final qq = randomQQ();
                      final url =
                          'https://q2.qlogo.cn/headimg_dl?dst_uin=$qq&spec=100';
                      try {
                        final resp = await http
                            .get(Uri.parse(url))
                            .timeout(const Duration(seconds: 5));
                        if (resp.statusCode == 200 &&
                            resp.bodyBytes.isNotEmpty) {
                          if (!mounted) return;
                          await up.setAvatarUrl(url);
                          applied = true;
                          break;
                        }
                      } catch (_) {}
                    }
                    if (applied) {
                      if (!ctx.mounted) return;
                      if (Navigator.of(ctx).canPop()) {
                        Navigator.of(ctx).pop(false);
                      }
                    } else {
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        message: l10n.sideDrawerQQAvatarFetchFailed,
                        type: NotificationType.error,
                      );
                    }
                  },
                  child: Text(l10n.sideDrawerRandomQQ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.sideDrawerCancel),
                    ),
                    TextButton(
                      onPressed: valid(value)
                          ? () => Navigator.of(ctx).pop(true)
                          : null,
                      child: Text(
                        l10n.sideDrawerSave,
                        style: TextStyle(
                          color: valid(value)
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.38),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (ok == true) {
      final qq = controller.text.trim();
      if (qq.isNotEmpty) {
        final url = 'https://q2.qlogo.cn/headimg_dl?dst_uin=$qq&spec=100';
        await up.setAvatarUrl(url);
      }
    }
  }
}
