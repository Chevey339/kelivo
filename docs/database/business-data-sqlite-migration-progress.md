# Kelivo 业务数据 SQLite 迁移进度

> 状态：21 个实施 ticket 的代码与自动化门禁已完成（2026-07-18）。正式发布前仍需在目标真机上完成升级与凭据可用性验收。

## 实施结果

| 阶段 | Ticket | 结果 |
| --- | --- | --- |
| Schema 与连接基础 | 01–03 | `kelivo.db` 重编号为唯一正式 Schema 1；保留 11 张聊天表，新增 11 张业务实体表和 `preference_rows`；聊天与业务仓储共享同一 `AppDatabase` 连接和事务边界。 |
| 业务读写切换 | 04–12 | 助手、标签、上下文数据、MCP、Provider/模型、搜索/TTS、用户/主题/字体、显示/输入、功能模型、后台生成、日志、学习模式、代理及备份配置均改由 `BusinessPreferences`/`BusinessRepository` 持久化；`ChatProvider` 已删除。 |
| 正式升级门 | 13–14 | 启动时在 provider 构造前完成一次性 prefs → SQLite 迁移、持久化等值校验、收据写入和旧业务键清理；失败保持 prefs 原样并 fail-closed；收据后的清理可幂等重试。 |
| 备份、导入与恢复 | 15–20 | `settings.json` 只从 SQLite 导出并仍保持已发布键形；settings-only overwrite/merge、旧 Hive ZIP、Cherry、Chatbox 和 full overwrite 全部走数据库事务；恢复协议收缩为 DB + assets 两条腿。 |
| 发布收口 | 21 | SharedPreferences 静态允许清单、schema 拒绝矩阵、恢复 failpoint、备份兼容和文档门禁已落地；旧 settings restore/cold-ack 代码与不可达测试夹具已删除。 |

## 关键契约

- `AppDatabase.currentSchemaVersion = 1`。全新安装创建 Schema 1；`user_version` 2～11 及未来更高版本均在写入前拒绝，且不原地改写数据库。
- Schema 1 同时包含聊天和业务表。业务列表实体保留原始 JSON payload，稳定行键只用于数据库身份；源 payload 缺少 `id` 时不会把生成值发布回备份。
- 业务迁移的全量替换、持久化回读校验和迁移收据在同一 SQLite 事务中完成，避免“收据已发布但数据尚未验证”的窗口。
- Chatbox 导入先完整解析，再在同一个共享 SQLite 事务中提交聊天与业务 patch；仓储不属于同一 `AppDatabase` 实例时在任何写入前拒绝。
- `settings.json` 在解压和 JSON 解析前执行 16 MiB 大小上限；解析在 isolate 中完成。
- Provider 内置配置、顺序和搜索默认值在冷启动后保持稳定；新排序中首次出现的内置 Provider 会先持久化默认配置。

## SharedPreferences 收口

生产代码只允许继续访问以下本机/启动期数据：

- 桌面窗口位置、尺寸、最大化状态与桌面快捷键；
- `display_chat_font_scale_v1`；
- `flutter_log_enabled_v1`；
- 恢复门、业务租约及 Hive → SQLite 正式升级所需的基础设施键。

`pinned_chat_ids`、`chat_titles_map`、旧提示词注入激活键、`migrations_version_v1` 和 `provider_configs_backup_v1` 只允许出现在路由过滤或迁移测试中，不再作为运行期业务状态读写。

## 自动化验证

| 门禁 | 结果 |
| --- | --- |
| Drift/source generation | `dart run build_runner build` 成功，生成代码与 Schema 1 表定义一致。 |
| 本地化生成 | `flutter gen-l10n` 成功。 |
| 静态分析 | `flutter analyze`：0 issue。 |
| 全量单元/Widget 测试 | `flutter test`：1232 项通过。 |
| 业务 prefs 与 schema 聚焦门禁 | 静态允许清单、Schema 1 快照/约束、2～11/未来版本拒绝、迁移与启动门测试全部通过。 |
| 备份与导入聚焦门禁 | 新格式 round trip、settings-only overwrite/merge、旧 Hive ZIP、Cherry/Chatbox、超大 settings 拒绝及事务回滚测试全部通过。 |
| 恢复状态机 | DB/assets mover、receipt、startup gate、commit/rollback/terminal/partial-marker 与全部 failpoint 可达性测试通过。 |
| macOS 多进程 harness | smoke tier 4/4；full tier 21/21（30:55）。真实独立进程覆盖 commit、rollback、terminal、partial-marker 及 DB/assets 全部物理边界。 |
| macOS 平台能力 | DB2-07 与 OPS-08 集成测试通过：Schema 1、WAL/FULL、在线备份、锁、文件 durable rename 及凭据数据库→备份 round trip 均正常。 |
| macOS profile 基线 | `p0_performance_baseline_test.dart` 以 profile 构建通过。 |

测试中 Drift 会对少数刻意同时打开同一测试数据库的兼容/恢复夹具输出 multiple-database 警告；相关测试均显式控制生命周期并通过，生产接线由共享 gateway 保证单一实例。

## 发布前人工验收

以下项目需要在真实发布构建和目标设备上完成，不能由仓库内自动化代替：

- 从已发布 Hive 版本（≤ v1.1.17）带完整 prefs、聊天和文件资产直接升级；
- 检查设置、助手、Provider/MCP、搜索/TTS、代理、WebDAV/S3 及全部凭据可直接使用；
- 覆盖 includeChats/includeFiles 组合的备份恢复，并核对头像、上传、图片和字体资产；
- 二次冷启动确认无重复迁移、无业务 prefs 回写、无聊天全库扫描；
- iOS、Android、macOS 各目标发布构建的 UI 冒烟与恢复重启流程。

真机验收完成前，本实现可合入测试分支，但不应把“发布验收完成”标记为已签署。
