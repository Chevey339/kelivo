# ADR-0003: SKILLS 采用文件系统存储方案

## Context

需要在 Cuplivo 中实现 AgentSkills 兼容的 SKILLS 机制。存在两个存储方向：① 沿用现有 `InstructionInjectionStore` / `WorldBookStore` 的 SharedPreferences 模式，将 SKILL.md 正文序列化为 JSON blob；② 采用文件系统原生存储，每个 skill 一个目录，SKILL.md 作为独立文件。

## Decision

采用文件系统方案。Skill 目录位于 `<appData>/skills/<name>/SKILL.md`，目录名即 skill 标识。

## Rationale

1. **AgentSkills 规范是文件系统原生的**：spec 定义的 `scripts/`、`references/`、`assets/` 目录结构无法无损压平为 JSON。选择文件系统就是选择与规范对齐，非 JSON blob 能模拟。
2. **RikkaHub 的先例验证**：同领域项目 RikkaHub 采用纯文件系统方案，路径安全（`SkillPaths` 防 `../` 遍历）、原子写入（staging→rename→backup→rollback）等模式可直接移植。
3. **v1 小投入为 v2 预留能力**：辅助文件（scripts/references/assets）v1 不使用但全量落盘，v2 仅需在 `load_skill` 工具中增加文件清单返回逻辑，无需迁移数据和重新导入。
4. **补丁式备份接入**：现有 `_packZipSync` 加一行 `_addDirectoryToZip` 即可覆盖，增量 mtime 过滤自动生效。无需在 `_exportSettingsJson` 中开新序列化通道。
5. **Assistant 绑定侵入最小**：只在 `Assistant` 模型加一个 `skillIds` 字段（与 `localToolIds` 同构），无新 table 或 DataStore。

## Considered Options

- **SharedPreferences 方案**（已拒绝）：`InstructionInjectionStore` 同款模式，body 存 prefs key。优点是备份零改动（随 settings.json 自动走）、无文件系统 IO。缺点是：① 无法支持辅助文件；② 粘贴导入需拆 frontmatter 为独立字段，与用户手中有完整 .md 文件的习惯冲突；③ body 体积膨胀后 prefs 读写效率下降；④ 未来加辅助文件时需全量迁移到文件系统——v1 的"捷径"就是 v2 的迁移债。

## Consequences

- **正向**：规范对齐、导入体验自然、v1→v2 前向兼容、备份增量无缝
- **反向**：新增 `lib/features/skills/` 模块 + `SkillManager` + `SkillPaths`
- **风险**：路径安全校验必须到位，否则目录遍历攻击可经 ZIP 条目进入 filesDir。已有 `_extractZipSync` 的 `..` 剥离作为第二防线
