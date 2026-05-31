import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/skill_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';

/// 技能导入底部弹窗
class SkillImportSheet extends StatefulWidget {
  const SkillImportSheet({super.key});

  @override
  State<SkillImportSheet> createState() => _SkillImportSheetState();
}

class _SkillImportSheetState extends State<SkillImportSheet> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖动指示器
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '导入技能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '支持 SKILL.md 文件、粘贴内容或扫描目录',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            _option(
              icon: Lucide.Copy,
              title: '从剪贴板导入',
              subtitle: '粘贴 SKILL.md 完整内容',
              onTap: () => _importFromClipboard(context),
            ),
            const SizedBox(height: 8),
            _option(
              icon: Lucide.FileText,
              title: '从文件导入',
              subtitle: '输入 SKILL.md 文件路径',
              onTap: () => _importFromFile(context),
            ),
            const SizedBox(height: 8),
            _option(
              icon: Lucide.FolderOpen,
              title: '从目录批量导入',
              subtitle: '扫描文件夹下所有 SKILL.md',
              onTap: () => _importFromDirectory(context),
            ),
            if (_importing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                backgroundColor: cs.outlineVariant,
                color: cs.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '导入中...',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.08),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Lucide.ChevronRight, size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromClipboard(BuildContext context) async {
    final skillProvider = context.read<SkillProvider>();
    final text = await _showInputDialog(context, '粘贴 SKILL.md 内容', hint: '将 SKILL.md 内容粘贴到这里...');
    if (text == null || text.trim().isEmpty) return;

    setState(() => _importing = true);
    try {
      final skill = await skillProvider.importFromString(text.trim());
      if (skill != null && context.mounted) {
        _showSnack(context, '已导入: ${skill.name}', Colors.green);
        Navigator.of(context).pop();
      } else if (context.mounted) {
        _showSnack(context, '解析失败，请检查 SKILL.md 格式', Colors.red);
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, '导入失败: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFromFile(BuildContext context) async {
    final skillProvider = context.read<SkillProvider>();
    final path = await _showInputDialog(
      context,
      '输入 SKILL.md 文件路径',
      hint: '/sdcard/Download/skill.md',
    );
    if (path == null || path.trim().isEmpty) return;

    setState(() => _importing = true);
    try {
      final skill = await skillProvider.importFromFile(path.trim());
      if (skill != null && context.mounted) {
        _showSnack(context, '已导入: ${skill.name}', Colors.green);
        Navigator.of(context).pop();
      } else if (context.mounted) {
        _showSnack(context, '文件不存在或格式错误', Colors.red);
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, '导入失败: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFromDirectory(BuildContext context) async {
    final skillProvider = context.read<SkillProvider>();
    final home = Platform.environment['HOME'] ?? '/data/data/com.termux/files/home';
    final path = await _showInputDialog(
      context,
      '输入技能目录路径',
      hint: '~/skills/',
      initial: '$home/skills/',
    );
    if (path == null || path.trim().isEmpty) return;

    setState(() => _importing = true);
    try {
      final count = await skillProvider.importFromDirectory(path.trim());
      if (count > 0 && context.mounted) {
        _showSnack(context, '已批量导入 $count 个技能', Colors.green);
        Navigator.of(context).pop();
      } else if (context.mounted) {
        _showSnack(context, '目录中未找到 SKILL.md 文件', Colors.orange);
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, '导入失败: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String?> _showInputDialog(
    BuildContext context,
    String title, {
    String? hint,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          maxLines: 8,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }
}

// Lucide icons we need but may not be in adapter:
// FolderOpen — use Icons.folder_open as fallback
extension _FallbackIcon on Lucide {
  static const IconData FolderOpen = Icons.folder_open;
}