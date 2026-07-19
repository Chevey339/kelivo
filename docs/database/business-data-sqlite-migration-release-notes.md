# 业务数据 SQLite 迁移发布说明

本版本把 Kelivo 的聊天数据和全部可备份业务设置统一存入同一个 `kelivo.db`。Schema 1 是首个正式 SQLite 契约；界面、设置含义和正常使用流程不变。

## 升级与兼容

- 支持从已发布的 Hive + SharedPreferences 版本（≤ v1.1.17）直接升级，以及全新安装。
- 首次启动会先迁移并校验业务数据，再加载应用。成功后删除旧业务 prefs；迁移中断会在下次启动安全重试。
- 未发布的 chat-only SQLite schema 2～11 不属于兼容范围；这些数据库和未来更高 schema 都会 fail-closed，且不会被原地改写。
- 旧版 Hive 备份 ZIP、Cherry Studio 和 Chatbox 导入继续受支持。

## 备份与恢复

- 备份仍使用 `settings.json` 作为业务数据载体，键名和数据形状保持兼容；包含聊天时同时写入一致的 `database/kelivo.db` 快照。
- settings-only overwrite/merge 不触碰聊天或文件；完整 overwrite 在 staging 数据库中应用 `settings.json` 后，再通过 DB + assets 的 crash-safe 协议切换。
- 恢复不再需要 settings cold-ack 或第二次冷启动确认。导入后的既有一次重启即可加载新数据。
- Chatbox 导入的聊天和业务设置现在原子提交；解析、数据库或约束失败不会清空现有聊天。

## 本机设置范围变化

`flutter_log_enabled_v1` 现在是设备本地设置，不再进入备份，也不会从旧备份恢复。这是本次迁移唯一有意收窄的备份范围。

窗口位置、桌面快捷键和聊天字体缩放等既有 local-only 设置仍不参与备份。其他业务设置，包括 `app_launch_count_v1`、请求日志设置和备份提醒时间戳，继续随备份迁移。

## 凭据与安全

Provider API key、代理密码、WebDAV/S3、搜索和 TTS 凭据仍按既有产品契约以明文包含在 `settings.json` 中；本版本没有引入备份加密。请继续把备份文件视为敏感数据并妥善保管。

## 故障行为

- 迁移、备份导入和恢复在校验失败时 fail-closed，不会以空业务数据继续启动或报告成功。
- Schema 1 同版本数据库还会校验业务表主键、排序约束和必要索引，结构缺失时拒绝打开。
- 恢复中断后只会保留完整旧 bundle 或完整新 bundle；含歧义、残缺或旧三腿协议痕迹的 workspace 会被拒绝并保留诊断信息。

实现与验收详情见 [迁移进度](./business-data-sqlite-migration-progress.md)，冻结设计见 [迁移方案](./business-data-sqlite-migration-plan.md)。
