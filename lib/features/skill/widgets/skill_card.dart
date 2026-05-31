import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/skill.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';

/// 技能卡片 — 显示单个技能信息
class SkillCard extends StatefulWidget {
  const SkillCard({
    super.key,
    required this.skill,
    required this.onTap,
    required this.onDelete,
  });

  final Skill skill;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<SkillCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skill = widget.skill;

    return _buildCard(cs, isDark, skill);
  }

  Widget _buildCard(ColorScheme cs, bool isDark, Skill skill) {
    final base = cs.onSurface.withValues(alpha: 0.9);
    final pressColor = Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base;
    final color = _pressed ? pressColor : base;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        if (context.read<SettingsProvider>().hapticsOnListItemTap) {
          Haptics.soft();
        }
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white10
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.08),
            width: 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 技能图标
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _emojiForSkill(skill.name),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              // 信息区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称 + 版本
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            skill.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: color,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (skill.version.isNotEmpty && skill.version != '1.0.0')
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'v${skill.version}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 描述
                    if (skill.description.isNotEmpty)
                      Text(
                        skill.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // 标签行
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // 前3个触发词（元数据说明）
                        ...skill.triggers.take(3).map(
                          (t) => _tag(t, color: cs.tertiary, cs: cs),
                        ),
                        if (skill.triggers.length > 3)
                          _tag(
                            '+${skill.triggers.length - 3}',
                            color: cs.onSurface.withValues(alpha: 0.5),
                            cs: cs,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 右箭头
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Lucide.ChevronRight, size: 16, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, {required Color color, required ColorScheme cs}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _emojiForSkill(String name) {
    final n = name.toLowerCase();
    if (n.contains('obsidian') || n.contains('知识库') || n.contains('写作')) return '🖊️';
    if (n.contains('运维') || n.contains('homelab') || n.contains('docker') || n.contains('排障')) return '🛠️';
    if (n.contains('api') || n.contains('模型') || n.contains('ai')) return '🤖';
    if (n.contains('插件') || n.contains('plugin') || n.contains('addon')) return '📦';
    if (n.contains('firefox') || n.contains('火狐') || n.contains('浏览器')) return '🦊';
    return '🧩';
  }
}