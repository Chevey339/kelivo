import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/skill.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/skill_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tactile.dart';

/// 技能详情页 — 预览/编辑/绑定助手/导出
class SkillDetailPage extends StatefulWidget {
  const SkillDetailPage({super.key, required this.skillId});

  final String skillId;

  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  late Skill _skill;
  bool _showRaw = false; // toggle between rendered / raw markdown
  final bool _showAssistantPicker = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SkillProvider>();
    _skill = provider.getById(widget.skillId) ?? _fallback();
  }

  Skill _fallback() => Skill(
    id: widget.skillId,
    name: '未找到',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  void _refresh() {
    final provider = context.read<SkillProvider>();
    final updated = provider.getById(widget.skillId);
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

            // ===== 开关控制 =====
            _ToggleRow(
              value: skill.enabled,
              onChanged: (v) {
                context.read<SkillProvider>().toggleEnabled(skill.id);
                _refresh();
              },
              cs: cs,
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // ===== 助手绑定 =====
            _AssistantBindRow(
              skill: skill,
              cs: cs,
              isDark: isDark,
              onTap: () => _showAssistantPickerDialog(context),
            ),

            const SizedBox(height: 16),

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
    final skillProvider = context.read<SkillProvider>();
    final skill = skillProvider.getById(widget.skillId);
    if (skill == null) return;

    final home = Platform.environment['HOME'] ?? '/data/data/com.termux/files/home';
    final defaultPath = '$home/${skill.name}.skill.md';

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
      final ok = await skillProvider.exportToFile(widget.skillId, path.trim());
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

  Future<void> _showAssistantPickerDialog(BuildContext context) async {
    final assistantProvider = context.read<AssistantProvider>();
    final skillProvider = context.read<SkillProvider>();
    final assistants = assistantProvider.assistants;
    final currentIds = Set<String>.from(_skill.assistantIds);

    final selected = <String>[...currentIds];

    await showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('绑定助手'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 全局选项
              CheckboxListTile(
                title: const Text('🌐 全局生效（所有助手）'),
                subtitle: const Text('技能对所有助手都可用'),
                value: selected.isEmpty,
                onChanged: (v) {
                  if (v == true) {
                    selected.clear();
                    setState(() {});
                  }
                  Navigator.of(dctx).pop();
                },
              ),
              const Divider(),
              // 各助手
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: assistants.length,
                  itemBuilder: (ctx, i) {
                    final a = assistants[i];
                    final isSelected = selected.contains(a.id);
                    return CheckboxListTile(
                      title: Text(a.name),
                      subtitle: Text('ID: ${a.id.substring(0, 8)}...'),
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            selected.add(a.id);
                          } else {
                            selected.remove(a.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await skillProvider.setAssistantIds(widget.skillId, selected);
              _refresh();
              if (dctx.mounted) Navigator.of(dctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
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
          _metaRow('作者', skill.author.isNotEmpty ? skill.author : '-'),
          const SizedBox(height: 6),
          _metaRow('优先级', skill.priority.toString()),
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

/// 开关行
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.value,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(value ? Lucide.Zap : Lucide.X, size: 20, color: value ? Colors.green : cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ? '已启用' : '已禁用',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              Haptics.light();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

/// 助手绑定行
class _AssistantBindRow extends StatelessWidget {
  const _AssistantBindRow({
    required this.skill,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final Skill skill;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(Lucide.User, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '绑定助手',
                    style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                  Text(
                    skill.assistantIds.isEmpty ? '全局生效（所有助手）' : '已绑定 ${skill.assistantIds.length} 个助手',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
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

/// 简化的 Markdown 渲染预览（用 Text 展示，保留格式标记）
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
    // 简单分行展示，保留可见的 markdown 标记
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

