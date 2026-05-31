import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/skill.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/skill_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tactile.dart';

/// 技能详情页 — 预览/编辑/导出
class SkillDetailPage extends StatefulWidget {
  const SkillDetailPage({super.key, required this.skillName});

  final String skillName;

  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  late Skill _skill;
  bool _showRaw = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SkillProvider>();
    _skill = provider.getByName(widget.skillName) ?? _fallback();
  }

  Skill _fallback() => Skill(
    name: widget.skillName,
    description: '未找到',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  void _refresh() {
    final provider = context.read<SkillProvider>();
    final updated = provider.getByName(widget.skillName);
    if (updated != null) {
      setState(() => _skill = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skill = _skill;

    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(skill.name, style: const TextStyle(fontSize: 16)),
        actions: [
          // 切换原始/渲染视图
          IosIconButton(
            icon: _showRaw ? Lucide.Eye : Lucide.FileText,
            onTap: () => setState(() => _showRaw = !_showRaw),
          ),
          // 导出
          IosIconButton(
            icon: Lucide.Download,
            onTap: () => _exportSkill(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 元数据卡片 =====
            _MetaCard(skill: skill, cs: cs, isDark: isDark),

            const SizedBox(height: 16),

            // ===== 助手绑定信息 =====
            _AssistantBindInfo(
              skillName: skill.name,
              cs: cs,
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // ===== 子文件列表 =====
            if (skill.files.isNotEmpty) ...[
              _SubFilesCard(skill: skill, cs: cs, isDark: isDark),
              const SizedBox(height: 16),
            ],

            // ===== 内容预览 =====
            Text(
              '技能内容',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (_showRaw)
              _RawContent(content: skill.content, cs: cs, isDark: isDark)
            else
              _MarkdownPreview(content: skill.content, cs: cs, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSkill(BuildContext context) async {
    final skillName = widget.skillName;
    final home = Platform.environment['HOME'] ?? '/data/data/com.termux/files/home';
    final defaultPath = '$home/$skillName.skill.md';

    final controller = TextEditingController(text: defaultPath);
    final path = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('导出 SKILL.md'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '保存路径',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(controller.text),
            child: const Text('导出'),
          ),
        ],
      ),
    );

    if (path != null && path.trim().isNotEmpty) {
      final skillProvider = context.read<SkillProvider>();
      final ok = await skillProvider.exportToFile(skillName, path.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '已导出到: $path' : '导出失败'),
            backgroundColor: ok ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ===========================================================================
// 子部件
// ===========================================================================

/// 元数据卡片
class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.skill,
    required this.cs,
    required this.isDark,
  });

  final Skill skill;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metaRow('版本', skill.version.isNotEmpty ? 'v${skill.version}' : '-'),
          const SizedBox(height: 6),
          _metaRow('描述', skill.description.isNotEmpty ? skill.description : '-'),
          if (skill.author.isNotEmpty) ...[
            const SizedBox(height: 6),
            _metaRow('作者', skill.author),
          ],
          if (skill.triggers.isNotEmpty) ...[
            const SizedBox(height: 6),
            _metaRow('关键词', skill.triggers.join(', ')),
          ],
          if (skill.filePath != null) ...[
            const SizedBox(height: 6),
            _metaRow('源文件', skill.filePath!),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

/// 助手绑定信息
class _AssistantBindInfo extends StatelessWidget {
  const _AssistantBindInfo({
    required this.skillName,
    required this.cs,
    required this.isDark,
  });

  final String skillName;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final assistantProvider = context.watch<AssistantProvider>();
    final boundAssistants = assistantProvider.assistants
        .where((a) => a.enabledSkills.contains(skillName))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Lucide.User, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '绑定助手',
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (boundAssistants.isEmpty)
            Text(
              '未绑定到任何助手 — 前往助手设置中启用此技能',
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
            )
          else
            ...boundAssistants.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Lucide.Check, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      a.name,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

/// 原始 Markdown 文本
class _RawContent extends StatelessWidget {
  const _RawContent({
    required this.content,
    required this.cs,
    required this.isDark,
  });

  final String content;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

/// 子文件列表卡片
class _SubFilesCard extends StatelessWidget {
  const _SubFilesCard({
    required this.skill,
    required this.cs,
    required this.isDark,
  });

  final Skill skill;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Lucide.Folder, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '子文件 (${skill.files.length})',
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...skill.files.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Lucide.FileText, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f.relativePath,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: cs.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatSize(f.sizeBytes),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          )),
          if (skill.files.isEmpty)
            Text(
              '无子文件',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({
    required this.content,
    required this.cs,
    required this.isDark,
  });

  final String content;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final trimmed = line.trim();
          final isHeader = trimmed.startsWith('##') || trimmed.startsWith('#');
          final isCode = trimmed.startsWith('```');
          final isListItem = trimmed.startsWith('- ') || trimmed.startsWith('* ');
          final isEmpty = trimmed.isEmpty;

          if (isCode) return const SizedBox.shrink();
          if (isEmpty) return const SizedBox(height: 8);

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: isHeader ? 14 : 12,
                fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
                color: cs.onSurface,
                fontFamily: isListItem ? 'monospace' : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}