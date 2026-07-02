# 1. 标题预设采用 Hash Fingerprint 方案

- **日期：** 2026-06-18
- **状态：** 已采纳

## 上下文

标题生成系统提示词需要支持多种风格（标准版、Emoji 版等）的一键切换，同时保持最低的持久化侵入。现有 `title_prompt_v1` 字段存储完整提示词文本。

## 决策

采用 **Hash Fingerprint 匹配**方案：运行时 trim 后精确比对，判断当前存储的提示词是否匹配某个预设 ID。预设定义在独立常量文件中，不新增 `SharedPreferences` 字段。

## 权衡

### 方案 A：Sentinel Value（已拒绝）
用同一个字段存 `"preset:standard"` 预设引用，仅当用户自定义时才存全文。
- **优点：** 版本迁移自动解决、可反显预设身份
- **缺点：** 需要 dirty 追踪逻辑、编解码分支、破坏了「文本框是唯一状态源」的简单性

### 方案 B：Hash Fingerprint ✅（已选）
运行时 `detect()` 做 trim-only 精确比对。
- **优点：** 零持久化改动、零消费端改动、文本框仍然是唯一状态源
- **缺点：** 预设文本更新后旧用户退化为「自定义」（可接受的 graceful degradation）

### 方案 C：纯 Template Fill（备选）
预设只负责填入文本框，不存储预设身份。
- **优点：** 最透明
- **缺点：** UI 无法反显「当前使用哪个预设」、版本迁移无解

## 影响

- `home_view_model.dart` 和 `side_drawer.dart` 零改动
- 预设定义集中在 `lib/core/prompts/` 下，便于未来扩展到翻译/摘要/压缩场景
- 浅层抽象（`PromptPreset` 数据类 + `PresetSelector` 通用组件）为下一场景做准备，但不强制泛化
