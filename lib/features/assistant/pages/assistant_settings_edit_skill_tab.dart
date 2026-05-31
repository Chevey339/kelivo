part of 'assistant_settings_edit_page.dart';

/// 技能 Tab — 在 Assistant 编辑页中管理技能绑定
class _SkillTab extends StatefulWidget {
  const _SkillTab({required this.assistantId});
  final String assistantId;

  @override
  State<_SkillTab> createState() => _SkillTabState();
}

class _SkillTabState extends State<_SkillTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skillProvider = context.watch<SkillProvider>();
    final assistantProvider = context.watch<AssistantProvider>();
    final assistant = assistantProvider.getById(widget.assistantId);
    final allSkills = skillProvider.skills;

    if (allSkills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Lucide.Sparkles,
                size: 64,
                color: cs.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                '暂无可用技能',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '前往「更多 → 技能」导入 SKILL.md 技能包',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 过滤 + 排序：已绑定的排前面，按名称字母序
    final filtered = allSkills.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.triggers.any((t) => t.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) {
        final aBound = a.assistantIds.contains(widget.assistantId);
        final bBound = b.assistantIds.contains(widget.assistantId);
        if (aBound && !bBound) return -1;
        if (!aBound && bBound) return 1;
        return a.name.compareTo(b.name);
      });

    final boundCount = allSkills
        .where((s) => s.assistantIds.contains(widget.assistantId))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _SkillSearchBar(
            query: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v),
            cs: cs,
            isDark: isDark,
          ),
        ),
        // 统计
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '已绑定 $boundCount / ${allSkills.length} 个技能',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 列表
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? '无匹配技能' : '暂无技能',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final skill = filtered[index];
                    final isBound = skill.assistantIds.contains(
                      widget.assistantId,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SkillBindingCard(
                        skill: skill,
                        isBound: isBound,
                        onToggle: () {
                          final provider = context.read<SkillProvider>();
                          final currentIds = List<String>.from(
                            skill.assistantIds,
                          );
                          if (isBound) {
                            currentIds.remove(widget.assistantId);
                          } else {
                            currentIds.add(widget.assistantId);
                          }
                          provider.setAssistantIds(
                            skill.id,
                            currentIds,
                          );
                        },
                        cs: cs,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 搜索栏
class _SkillSearchBar extends StatelessWidget {
  const _SkillSearchBar({
    required this.query,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.12),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Lucide.Search,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: query,
                  selection: TextSelection.collapsed(offset: query.length),
                ),
              ),
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '搜索技能名称、描述或触发词...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              onTap: () => onChanged(''),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Lucide.X,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// 技能绑定卡片
class _SkillBindingCard extends StatelessWidget {
  const _SkillBindingCard({
    required this.skill,
    required this.isBound,
    required this.onToggle,
    required this.cs,
    required this.isDark,
  });

  final Skill skill;
  final bool isBound;
  final VoidCallback onToggle;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white10
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isBound
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
            width: isBound ? 1.2 : 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 图标
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isBound
                      ? cs.primary.withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : const Color(0xFFF2F3F5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _emojiForSkill(skill.name),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 10),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (skill.description.isNotEmpty)
                      Text(
                        skill.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (skill.triggers.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: skill.triggers.take(3).map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 9,
                                color: cs.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // 开关
              IosSwitch(
                value: isBound,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
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
