# progress.md

> Kelivo 施工进度流水账。仅在末尾追加，不改写历史记录。
> 记录规则参见根目录 `AGENTS.md` 的进度日志约定。

## 2026-06-20 - Task: 搬入远端第一批补丁（MCP STDIO / 懒加载尾窗 / 消息导出分片）

### What was done
- 从远端按用户指定边界搬入“第一批”共 4 个提交（`68e87e3`、`0eb65c7`、`89bba80`、`76687b2`）对应的代码变更，落地到当前工作树，未提交。
- 功能点：
  - `ChatController` 修复懒加载聊天尾窗，打开会话时落到含可见消息的窗口，而非只剩旧版本影子消息。
  - `HomePageController` 修正无会话时入口逻辑，直接初始化空会话。
  - `message_export_sheet.dart` 为超长消息图片导出增加整图优先、超长再分片路径，并补对应测试。
  - MCP STDIO 链路新增 `McpStdioCommandResolver` 与 Windows shim 启动解析，补齐 PATH 合并、命令存在性检查与 batch/shim 启动行为。
- 涉及文件（11 个）：
  - 修改：`dependencies/mcp_client/lib/src/transport/transport.dart`
  - 修改：`lib/core/providers/mcp_provider.dart`
  - 修改：`lib/features/chat/widgets/message_export_sheet.dart`
  - 修改：`lib/features/home/controllers/chat_controller.dart`
  - 修改：`lib/features/home/controllers/home_page_controller.dart`
  - 修改：`test/features/chat/widgets/message_export_sheet_test.dart`
  - 修改：`test/features/home/controllers/chat_controller_lazy_history_test.dart`
  - 新增：`dependencies/mcp_client/lib/src/transport/stdio_launch.dart`
  - 新增：`dependencies/mcp_client/test/stdio_launch_test.dart`
  - 新增：`lib/core/services/mcp/stdio_command_resolver.dart`
  - 新增：`test/core/services/mcp/stdio_command_resolver_test.dart`

### Testing
- 本机非交互 shell 无可用 `flutter` / `dart`（`command -v` 均为 not found），无法执行 `flutter analyze` / `flutter test` / `dart format` / `flutter gen-l10n`。
- 仅完成静态验证闭环：`git diff --check` 通过；新增文件做了无索引 diff check；对新旧调用链、测试落点、接口签名做静态自查。
- 风险缺口：未经 `flutter test` 实跑验收，不能声称“已可用”，只能声称“静态一致”。

### Notes
- 未验证边界：缺 Flutter/Dart SDK，l10n / 生成代码 / analyze / test 全链路均未跑。后续若要真验收，必须先提供 SDK 路径或在 shell 启动补 PATH。
- 回滚点：第一批改动未提交。回滚方式——
  - 撤销已跟踪文件改动：`git checkout -- <上列 7 个 modified 文件>`
  - 删除新增文件：`rm <上列 4 个新增文件>`

## 2026-06-21 - Task: 第二批边界纠偏 + 保留安全 Windows 构建补丁

### What was done
- 纠偏第二批误搬：此前误把更早的祖先/前置提交（`c5dcd47`、`ec8c64b`、`d5933f7`、`2a06bbf`、`5628935`、`8a91034`、`db0e0f3`）当成“紧跟第一批”搬入，已按依赖反序全部 reverse 撤回，避免污染第一批 scope。
- 确认第一批边界 `68e87e3` 之后的真实连续提交为：`5d8df08`、`64da091`、`b0e78ee`。
- 仅保留其中真正安全且边界内的 `b0e78ee`：修改 `windows/CMakeLists.txt`，加入 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`，不碰 Dart / l10n / 生成文件。
- 未搬 `5d8df08`（会扩到 settings/reasoning UI、4 个 ARB、`app_localizations*.dart` 生成文件，缺工具链无法合规 `flutter gen-l10n`）与 `64da091`（仅 `pubspec.yaml` 版本号 bump）。

### Testing
- 同上：本机无 Flutter/Dart SDK，未跑 analyze/test。
- reverse 操作均先做 `--check` 全绿再执行；纠偏后 `git status` 收口为“第一批 11 文件 + `windows/CMakeLists.txt`”。

### Notes
- 改动文件（本轮新增项相对第一批）：`windows/CMakeLists.txt` —— 追加 MSVC 协程实验警告静默宏。
- 回滚点：`git checkout -- windows/CMakeLists.txt` 即可撤回本批唯一保留改动。
- 教训：搬“紧跟第一批”的批次，必须先用本地提交 DAG / ancestry 钉边界，禁止按主题相近或能贴上来猜。
