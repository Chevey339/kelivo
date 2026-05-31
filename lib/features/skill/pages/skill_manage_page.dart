import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../../core/models/skill.dart';
import '../../../core/providers/skill_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../widgets/skill_card.dart';
import '../widgets/skill_import_sheet.dart';
import 'skill_detail_page.dart';

class SkillManagePage extends StatelessWidget {
  const SkillManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skillProvider = context.watch<SkillProvider>();
    final skills = skillProvider.skills;

    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text('🧩 技能'),
        actions: [
          IosIconButton(
            icon: Lucide.Import,
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                backgroundColor: cs.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => const SkillImportSheet(),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: skills.isEmpty
          ? _EmptyState(cs: cs)
          : Column(
              children: [
                // 统计栏
                _StatsBar(cs: cs, skills: skills),
                // 列表
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: skills.length,
                    itemBuilder: (context, index) {
                      final skill = skills[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Slidable(
                          key: ValueKey('skill-${skill.id}'),
                          endActionPane: ActionPane(
                            motion: const StretchMotion(),
                            extentRatio: 0.42,
                            children: [
                              // 删除操作
                              CustomSlidableAction(
                                autoClose: true,
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? cs.error.withValues(alpha: 0.22)
                                        : cs.error.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: cs.error.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Lucide.Trash, color: cs.error, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          '删除',
                                          style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                onPressed: (_) async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dctx) => AlertDialog(
                                      backgroundColor: cs.surface,
                                      title: const Text('删除技能'),
                                      content: Text('确定删除「${skill.name}」吗？此操作不可恢复。'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(dctx).pop(false),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(dctx).pop(true),
                                          child: const Text('删除'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true && context.mounted) {
                                    await context.read<SkillProvider>().delete(skill.id);
                                    if (context.mounted) {
                                      showAppSnackBar(
                                        context,
                                        message: '已删除: ${skill.name}',
                                        type: NotificationType.info,
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          child: SkillCard(
                            skill: skill,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SkillDetailPage(skillId: skill.id),
                                ),
                              );
                            },
                            onToggle: () {
                              context.read<SkillProvider>().toggleEnabled(skill.id);
                            },
                            onDelete: () {},
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// 统计栏
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.cs, required this.skills});
  final ColorScheme cs;
  final List<Skill> skills;

  @override
  Widget build(BuildContext context) {
    final total = skills.length;
    final enabled = skills.where((s) => s.enabled).length;
    final global = skills.where((s) => s.assistantIds.isEmpty).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.08,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('共 $total', '总技能数'),
          _stat('$enabled 活跃', '已启用'),
          _stat('$global 全局', '全局生效'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.Brain, size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            '还没有技能',
            style: TextStyle(fontSize: 18, color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 导入 SKILL.md',
            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                backgroundColor: cs.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => const SkillImportSheet(),
              );
            },
            icon: Icon(Lucide.Import, size: 18),
            label: const Text('导入技能'),
          ),
        ],
      ),
    );
  }
}