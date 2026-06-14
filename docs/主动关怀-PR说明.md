# 主动关怀（Ta 的来信）PR 说明

> 本文档为 Fork 说明页，内容与上游 PR 同步维护。

| 项目 | 内容 |
|------|------|
| 上游 PR | [Chevey339/kelivo#686](https://github.com/Chevey339/kelivo/pull/686) |
| Fork 分支 | `feat/proactive-care` |
| 平台范围 | **Android only**（设置 UI + 运行时；模型字段跨平台保留用于备份） |
| 最后更新 | 2026-06-14 |

## Fork 后续更新（Android 门控）

在初始 8 个逻辑 commit 之后，又追加 2 个 commit：

1. `fix(proactive-care): gate feature to Android only` — 非 Android 隐藏「Ta 的来信」Tab，并禁用决策 LLM 钩子
2. `refactor(proactive-care): drop unused desktop date-time picker UI` — 删除桌面日期选择器死代码

当前 PR 共 **10 个 commit**。Fork 仓库首页 About 区有中文摘要与本文档链接。

---

> Related to #354

## 概述

本 PR 新增 **主动关怀（"Ta 的来信" / Proactive Care）** 功能：为助手开启后，助手会在设定的时间主动给用户发消息，并在每次交互后重新规划下一次时间。主动关怀设置与运行时行为限定 Android；模型字段跨平台保留用于备份兼容。

核心行为：

1. **每次回复后做时间决策** —— 助手每次正常回复完用户的消息，会静默向模型发送一次请求：以 system 身份发送"携带当前时间的决策提示词"，并以 user/assisstant身份发送"人设 / 记忆 / 上下文"（刻意用 user /assisstant身份，避免人设干扰决策）。模型返回 JSON，用于更新下一次主动消息的时间。
   - 决策提示词中， `current_system_time `置于发给LLM的整条消息**底部**，以获取更高的**缓存命中率**。

2. **到点唤醒** —— 到达设定时间时唤醒程序（Android 精确闹钟），随后执行两件事：(I) 静默把"系统提示词 + 主动关怀提示词 + 记忆 + 上下文"发送给模型，并将回复写入对话；(II) 用通知把该回复推送给用户。
   - 应用存活（前台）与未存活（被杀后）两条路径，最终汇聚到同一套关怀消息流水线（`ProactiveCareMessageFlow.buildHistory → buildCareApiMessages → requestCareReply`）；二者只在数据加载/持久化层不同：存活走 `ChatService`，无头路径直写 Hive（因为后台 isolate 不能与主 isolate 并发写同一个 Hive box）。
   - 通知图标为助手头像的中心裁剪，通知标题为助手名称
   - 此时发送给LLM的消息中， `current_system_time `置于发给LLM的整条消息**底部**，以获取更高的**缓存命中率**。
   - 主动关怀提示词 以user身份，在 `current_system_time `前面发送给LLM

3. **发送后再次决策** —— 主动回复发出后，再发起一次决策请求以安排下一次时间。

## 改动内容

- **模型层**：在 `Assistant` 上新增主动关怀字段（开关、下次时间、关怀提示词、决策提示词）并支持 JSON 序列化；`AssistantProvider` 同步维护闹钟。
- **服务层**：
  - `ProactiveCareService`：纯逻辑（提示词拼装 / 决策 JSON 解析），有完整单测；
  - `ProactiveCareMessageFlow`：无头消息流水线 + 本地化快照 + Hive 直写；
  - `ProactiveCareAlarmService`：基于 `android_alarm_manager_plus` 的调度与 isolate 路由；
  - 新增主动关怀通知频道；`main.dart` 启动时初始化。
- **重构**：把世界书注入逻辑从 `MessageBuilderService` 抽取为独立的 `applyWorldBookInjections`（`world_book_injector.dart`），以便在没有 `BuildContext` 的后台 isolate 中复用。**纯提取、零行为变化**（单独作为第一个 commit，方便审核）。`world_book_injector.dart`是  `MessageBuilderService` 中被删块的逐行搬运，可 diff 两段直接核对。
- **UI**：新增「Ta 的来信」设置 Tab 与可复用的日期时间选择器，并接入助手编辑页（**仅 Android 显示**）。
- **Home 控制层**：每次回复后触发决策请求；前台通过 isolate 端口处理闹钟驱动的主动消息。
- **平台 / 依赖**：新增 `android_alarm_manager_plus` 依赖；在 `AndroidManifest.xml` 中加入精确闹钟权限与组件。
- **本地化**：在全部 4 个 ARB 文件（`en` / `zh` / `zh_Hans` / `zh_Hant`）同步新增文案，并用 `flutter gen-l10n` 重新生成本地化代码。

PR 最初按 **8 个逻辑 commit** 组织（重构 → 模型 → 服务 → UI → 控制层 → android/依赖 → 本地化 → 测试），后追加 2 个 Android 门控相关 commit（见上文「Fork 后续更新」），便于逐层审核。

## 测试

- `flutter analyze lib test` → 无任何问题。
- 对全部改动文件执行 `dart format` → 本就规范（0 处改动）。
- `flutter test` → **771 通过**。新增测试（`proactive_care_*`、`world_book_injector`、`assistant_proactive_care`）全部通过。
  - 有 1 个与本功能无关的 Windows 预存失败：`settings_provider_local_font_test.dart` 期望路径分隔符为 `/`，但 Windows 实际为 `\`（`fonts/` vs `fonts\`）。该问题与本改动无关（本 PR 未触碰字体/设置相关代码）。

## 说明 / 风险

- **`SCHEDULE_EXACT_ALARM`** 属于 Google Play 政策下的敏感权限。如需要，我可以把该功能做成可开关 / 默认关闭。
- 主动关怀的唤醒目前**仅 Android**（依赖 `android_alarm_manager_plus`）实现；iOS / 桌面 / Web 不展示设置 Tab，也不运行决策 LLM。
- 这是一个体量较大的功能；如有需要，我乐意进一步拆分或调整。

## 提交前检查清单

- [x] 所有新增用户可见文案均走 `AppLocalizations`；4 个 ARB 已同步并执行 `flutter gen-l10n`。
- [x] 已执行 `dart format`；改动代码 `flutter analyze` 无问题。
- [x] 新增了测试；既有测试通过（上面提到的 1 个 Windows 路径测试与本功能无关）。
- [x] 未提交任何密钥或构建产物。

## 截图

<img width="150" height="312" alt="IMG_20260614_174613" src="https://github.com/user-attachments/assets/6b36bb85-9b8d-43a6-8dfd-d5522e955ca2" />

<img width="150" height="228" alt="DCAA7149E3A0E0F750586D0FC6FD1F80" src="https://github.com/user-attachments/assets/aaf86fae-9a4a-4b24-b5ab-4f02b836bcab" />

<img width="150" height="303" alt="8808DCBD29D5F681B338A8A5B0BC36C7" src="https://github.com/user-attachments/assets/b20c66b8-284e-428b-b7fb-f6048903f955" />
