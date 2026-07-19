# Kelivo 业务数据 SQLite 迁移方案（统一 Schema 1）

> - 文档状态：正式 Schema 1 设计与实施基线；产品决策已冻结（2026-07-18，用户裁决），代码实现与自动化门禁已完成
> - 历史前置事实：聊天数据 Hive → SQLite 改造曾以未发布的 `currentSchemaVersion = 11` 存在；该中间契约从未成为兼容边界
> - 当前事实：`kelivo.db` 以 **schema 1** 作为首个正式 SQLite 契约，同时承载聊天数据与全部业务数据
> - 实施记录：[迁移进度](./business-data-sqlite-migration-progress.md)；用户可见变化：[发布说明](./business-data-sqlite-migration-release-notes.md)
> - 参考实现：cherry-studio v2 数据重构（preference KV 表 + 类型化实体表 + 一次性插件迁移器）

## 1. 目标与范围

### 1.1 目标

把当前存于 SharedPreferences 的全部业务数据（助手、提示词注入、Provider 配置、MCP、世界书、记忆、快捷短语、搜索/TTS、备份配置、用户资料、显示与行为设置等，约 172 个键）迁入既有的 `kelivo.db`（Drift/SQLite），与聊天数据统一为单一数据库、单一正式 schema：

- `AppDatabase.currentSchemaVersion = 1`，是对外发布的**唯一**正式 schema；
- 用户可见行为与产品逻辑**零变化**（例外项在 §2 决策中逐条列明）；
- 备份继续包含完整业务数据、明文含敏感凭据，包含/排除范围与已发布版本一致。

### 1.2 兼容边界（冻结）

- **唯一正式升级来源是已发布的 Hive + SharedPreferences 版本（≤ v1.1.17）**。验收只覆盖两条路径：正式 Hive 版直接升级到本版本、全新安装。
- **不兼容任何未发布的中间版本**：chat-only SQLite 库（user_version 2～11）不升级、不读取、不改写，安装门原地 fail-closed（沿用现有行为，开发机数据由开发者自行从 Hive/旧备份重迁移）；未发布中间版产生的备份 ZIP 同样不承诺兼容。
- 已发布 Hive 版的备份 ZIP（`settings.json` + `chats.json` [+ assets]）与 Cherry/Chatbox 导入继续支持。

### 1.3 不在范围内

- 聊天数据模型、消息交互、滚动等一切聊天侧行为（已由聊天 v2 方案冻结）；
- 备份加密、secure storage（沿用 PD-11：凭据明文、用户自行保管备份）；
- 各设置页面的视觉与交互改动。

## 2. 冻结决策（2026-07-18，用户裁决）

| ID | 决策 |
| --- | --- |
| BD-01 | **混合建模**：列表型业务实体建独立表（每表 = 行键 + 排序列 + 原样 JSON payload + 少量必要投影列），其余标量与映射类设置进一张 `preference_rows` KV 表。不做全字段强类型建模。 |
| BD-02 | **SharedPreferences 保留极小残留集**：仅设备本地/启动引导键继续留在 prefs 且不参与备份（清单见 §3.3）。其中 `flutter_log_enabled_v1` 因需在数据库打开前读取，从"可备份"改为"设备本地不备份"（唯一一处备份范围收窄，用户已确认）。其余键全部进库。 |
| BD-03 | **备份保持 `settings.json` 载体**：新备份 ZIP 仍为 `settings.json`（从数据库导出，键形与已发布版一致，明文含凭据）+ `manifest.json` + `database/kelivo.db`（includeChats 时）+ assets（includeFiles 时）。不采用"整库快照即业务备份"方案。 |
| BD-04 | **删除 ChatProvider 遗留孤儿键**：`pinned_chat_ids`、`chat_titles_map` 不迁移，连同 `ChatProvider` 一起删除（置顶/标题早已由聊天库负责，无实际消费者）。 |
| BD-05 | **迁移成功后立即删除 prefs 旧业务键**：收据落库后直接清理，不留双源、不做用户手动清理入口（正式升级来源的备份 ZIP 随时可重导）。 |
| BD-06 | **备份范围维持现状**：`app_launch_count_v1`、日志设置、备份提醒时间戳等继续随备份走，不新增设备本地排除项。 |
| BD-07 | **schema 重编号为 1**：现有 schema 11 的聊天表结构原样并入 schema 1，仅版本号与安装门判定收口；不提供 11 → 1 的升级路径。 |

## 3. 数据分层与键归宿总表

分层规则：

| 层 | 存储 | 内容 |
| --- | --- | --- |
| 启动引导/设备本地 | SharedPreferences | 数据库打开前必须可读、或本来就不随备份的设备痕迹 |
| 业务数据 | SQLite `kelivo.db`（schema 1） | 全部可备份业务数据：实体表 + preference KV |
| 文件资产 | `upload/`、`avatars/`、`images/`、`fonts/` | 不变；payload 内的路径引用与 `SandboxPathResolver` 语义不变 |
| 可再生数据 | `cache/`、`logs/`、FTS/统计等派生表 | 不变；不迁移、不备份 |

### 3.1 实体表（11 个源键 → 11 张表）

| 源 prefs 键 | 目标表 | 排序来源 |
| --- | --- | --- |
| `assistants_v1` | `assistant_rows` | 列表顺序 |
| `provider_configs_v1`（Map，键为 providerKey） | `provider_rows` | `providers_order_v1`；未入列的 key 按原 Map 顺序补尾 |
| `provider_groups_v1` | `provider_group_rows` | 列表顺序 |
| `mcp_servers_v1` | `mcp_server_rows` | 列表顺序 |
| `world_books_v1`（entries 嵌套保留在 payload 内） | `world_book_rows` | 列表顺序 |
| `assistant_memories_v1` | `assistant_memory_rows` | 列表顺序 |
| `quick_phrases_v1` | `quick_phrase_rows` | 列表顺序 |
| `search_services_v1` | `search_service_rows` | 列表顺序 |
| `tts_services_v1` | `tts_service_rows` | 列表顺序 |
| `instruction_injections_v1` | `instruction_injection_rows` | 列表顺序 |
| `assistant_tags_v1` | `assistant_tag_rows` | 列表顺序 |

`providers_order_v1` 被 `provider_rows.sort_order` 吸收，不再单独存储（备份导出时按 sort_order 重建该键，见 §7.1）。

### 3.2 preference KV（其余全部可备份键）

按类别（键名与现值语义均不变，值以 JSON 字面量编码保留 bool/int/double/string/List\<String\> 类型）：

- **选择与关系映射**：`current_assistant_id_v1`、`selected_model_v1`、`pinned_models_v1`、`provider_group_map_v1`、`provider_group_collapsed_v1`、`provider_ungrouped_position_v1`、`assistant_tag_map_v1`、`assistant_tag_collapsed_v1`、`instruction_injections_active_ids_by_assistant_v1`、`instruction_injection_group_collapsed_v1`、`world_books_active_ids_by_assistant_v1`、`world_books_collapsed_v1`
- **搜索**：`search_common_v1`、`search_selected_v1`、`search_enabled_v1`、`search_auto_test_on_launch_v1`
- **TTS**：`tts_selected_v1`、`tts_auto_play_assistant_replies_v1`、`tts_text_selection_mode_v1`、`tts_speech_rate_v1`、`tts_pitch_v1`、`tts_engine_v1`、`tts_language_v1`
- **备份**：`webdav_config_v1`、`s3_config_v1`、`backup_reminder_enabled_v1`、`backup_reminder_interval_days_v1`、`backup_reminder_minutes_of_day_v1`、`backup_reminder_enabled_at_v1`、`backup_reminder_last_backup_at_v1`
- **用户资料**：`user_name`、`avatar_type`、`avatar_value`
- **主题/语言**：`theme_mode_v1`、`theme_palette_v1`、`use_dynamic_color_v1`、`app_locale_v1`
- **功能模型与提示词**：`title_model_v1`、`title_prompt_v1`、`title_generation_thinking_enabled_v1`、`translate_model_v1`、`translate_prompt_v1`、`translate_target_lang_v1`、`ocr_model_v1`、`ocr_prompt_v1`、`ocr_enabled_v1`、`summary_model_v1`、`summary_prompt_v1`、`suggestion_model_v1`、`suggestion_prompt_v1`、`suggestion_insert_on_tap_only_v1`、`compress_model_v1`、`compress_prompt_v1`、`thinking_budget_v1`
- **显示与聊天 UI**：全部 `display_*` 键（**除** `display_chat_font_scale_v1`，见 §3.3）、`image_cropper_enabled_v1`
- **桌面布局与输入**：`desktop_topic_position_v1`、`desktop_right_sidebar_open_v1`、`desktop_sidebar_width_v1`、`desktop_sidebar_open_v1`、`desktop_right_sidebar_width_v1`、`desktop_send_shortcut_v1`
- **后台生成**：`android_background_chat_mode_v1`、`ios_background_generation_enabled_v1`、`ios_background_task_refresh_enabled_v1`、`ios_live_activity_enabled_v1`、`ios_background_notifications_enabled_v1`
- **字体**：`display_app_font_family_v1`、`display_code_font_family_v1`、`display_app_font_is_google_v1`、`display_code_font_is_google_v1`、`display_app_font_local_path_v1`、`display_code_font_local_path_v1`、`display_app_font_local_alias_v1`、`display_code_font_local_alias_v1`
- **全局代理**：`global_proxy_enabled_v1`、`global_proxy_type_v1`、`global_proxy_host_v1`、`global_proxy_port_v1`、`global_proxy_username_v1`、`global_proxy_password_v1`、`global_proxy_bypass_v1`
- **日志与杂项**：`request_log_enabled_v1`、`log_save_output_v1`、`log_auto_delete_days_v1`、`log_max_size_mb_v1`、`app_launch_count_v1`、`mcp_request_timeout_ms_v1`、`learning_mode_enabled_v1`、`learning_mode_prompt_v1`
- **未注册键兜底**：迁移与旧备份导入时遇到不在本清单、也不在丢弃/残留清单中的键，若类型受支持则原样存入 KV 并照常备份，不得静默丢弃。

### 3.3 SharedPreferences 残留集（不迁移、不备份）

| 键 | 理由 |
| --- | --- |
| `window_width_v1`、`window_height_v1`、`window_pos_x_v1`、`window_pos_y_v1`、`window_maximized_v1` | 桌面窗口初始化在数据库打开前；本来就是 local-only |
| `desktop_hotkeys_commands_v1`、`desktop_hotkeys_enabled_v1` | 本来就是 local-only |
| `display_chat_font_scale_v1` | 本来就是 local-only |
| `flutter_log_enabled_v1` | `main.dart` 在数据库打开前读取（BD-02：改为设备本地不备份；旧备份导入时该键忽略） |
| 恢复门/业务租约内部键（`restore_*` 等机制键） | 恢复协议基础设施，先于数据库存在 |

### 3.4 丢弃键（不迁移、不备份、导入旧备份时忽略）

| 键 | 理由 |
| --- | --- |
| `pinned_chat_ids`、`chat_titles_map` | BD-04：孤儿键，职责已在聊天库 |
| `instruction_injections_active_id_v1`、`instruction_injections_active_ids_v1` | 旧格式；迁移时先执行现有归一逻辑并入 `..._by_assistant_v1` 最终形态 |
| `migrations_version_v1`、`provider_configs_backup_v1` | prefs 时代的迁移机制键，入库后无意义 |

### 3.5 迁移时执行的归一化

迁移器读取 prefs 后、写库前，复用各 provider/store 现有的 legacy 归一逻辑，只把**最终形态**入库：

1. 提示词注入 active id：单 id / 全局 ids → `by_assistant` map；
2. learning mode 双所有者（SettingsProvider 与 LearningModeStore 读写同一键）收敛为单一所有者，数据本身不变；
3. `pinned_models_v1`、`providers_order_v1` 的 legacy JSON-string 形态按现有 `BackupSettingsValidator.normalizeLegacyStringLists` 规则归一为 StringList 语义；
4. 助手 `search_enabled_v1` 的 legacy 播种逻辑照现状执行一次后不再保留 legacy 分支。

## 4. Schema 1 设计

### 4.1 版本与安装门

- `AppDatabase.currentSchemaVersion = 1`；数据库文件名 `kelivo.db` 不变；PRAGMA 契约（WAL、FK、busy_timeout、synchronous=FULL 等）不变。
- 打开时 `user_version != 0 && != 1` → 一律抛 `database_schema_version` fail-closed（覆盖所有未发布中间版 2～11 与未来更高版本），`MigrationStrategy.onUpgrade` 继续直接抛错，无任何升级路径。
- 现有 schema 11 的测试快照替换为 schema 1 快照（`schema_v1.dart`），拒绝矩阵改为"任何非 0/1 版本"。
- `DatabaseV2RollbackCompatibility` / rollout ledger 的可读窗口自动跟随为恰好 1。

### 4.2 聊天表（原样并入，仅版本号变化）

schema 11 的全部 11 张 Drift 表原样成为 schema 1 的一部分：`conversation_rows`、`message_rows`、`conversation_mcp_server_rows`、`tool_event_rows`、`gemini_thought_signature_rows`、`chat_storage_meta_rows`、`message_part_rows`、`provider_artifact_rows`、`migration_run_rows`、`migration_issue_rows`、`generation_run_rows`，含全部索引/约束。FTS 与 asset GC 的运行期懒建表规则不变。

### 4.3 业务表（新增 12 张）

统一模板（Drift 声明，微秒 UTC 时间）：

```sql
CREATE TABLE <entity>_rows (
  id         TEXT NOT NULL PRIMARY KEY,   -- 取 payload.id；源项无 id 时生成 UUID，仅作行键，不回写 payload
  sort_order INTEGER NOT NULL CHECK (sort_order >= 0),
  payload    TEXT NOT NULL,               -- 与今日 prefs 列表项完全相同的 JSON 对象，原样存储
  updated_at INTEGER NOT NULL
);
-- 读取一律 ORDER BY sort_order, id（稳定 tiebreaker）
```

具体表与偏离模板的差异：

| 表 | 差异 |
| --- | --- |
| `assistant_rows` | 无 |
| `provider_rows` | 主键为 `provider_key`（原 Map 键） |
| `provider_group_rows` | 无 |
| `mcp_server_rows` | 无 |
| `world_book_rows` | entries 嵌套保留在 payload，不拆子表 |
| `assistant_memory_rows` | 增加投影列 `assistant_id TEXT NOT NULL` + 索引 `idx_assistant_memories_assistant(assistant_id, id)`；无 sort_order 语义时按插入序编号 |
| `quick_phrase_rows` | 无 |
| `search_service_rows` | 选中项仍以下标存 `search_selected_v1`（保持现有语义） |
| `tts_service_rows` | 同上（`tts_selected_v1`） |
| `instruction_injection_rows` | 无 |
| `assistant_tag_rows` | 无 |
| `preference_rows` | `key TEXT PRIMARY KEY, value TEXT NOT NULL /* JSON 字面量 */, updated_at INTEGER NOT NULL` |

设计约束：

- payload 是唯一权威，投影列只用于查询/排序，可由 payload 重建；
- 不建跨表 FK（`assistant_id`、`mcpServerIds` 等引用维持今日的应用层弱引用语义，删除助手不级联删记忆——与现状一致）；
- 迁移收据等元数据写入现有 `chat_storage_meta_rows`（新增键 `business_migration_complete_v1`），不另建 meta 表。

## 5. 数据访问层与启动序列

### 5.1 仓储层

- 新增 `BusinessRepository`（与 `ChatDatabaseRepository` 并列，共享同一 `AppDatabase`/gateway 连接与事务边界）：实体表 CRUD（整表读、按序重写、单行 upsert/delete）、preference get/set/snapshot、迁移与备份导入导出的批量事务接口。
- 全部访问异步、走 Drift 后台 isolate；禁止新增任何同步 SQLite 旁路（沿用聊天 v2 Guardrails）。

### 5.2 Provider/Store 改造原则

各 provider/store 的**公共 API、内存模型、通知时机不变**，仅把持久化后端从 `SharedPreferences` 换成 `BusinessRepository`：

| 现有文件 | 改造 |
| --- | --- |
| `settings_provider.dart` | `_load()` 改为读 KV snapshot + `provider_rows`/`provider_group_rows`/`search_service_rows`/`tts_service_rows`；各 setter 改写对应表/KV |
| `assistant_provider.dart` | `assistant_rows` + KV（current id） |
| `mcp_provider.dart` | `mcp_server_rows` + KV（timeout） |
| `world_book_store.dart`、`memory_store.dart`、`quick_phrase_store.dart`、`instruction_injection_store.dart` | 对应实体表 + KV |
| `tag_provider.dart`、`user_provider.dart`、`tts_provider.dart`、`backup_reminder_provider.dart`、`instruction_injection_group_provider.dart`、`learning_mode_store.dart` | KV（learning mode 收敛为单一所有者） |
| `chat_provider.dart` | 删除（BD-04），`main.dart` 移除注册 |
| `hotkey_provider.dart`、`window_size_manager.dart` | 不动（残留 prefs） |
| `cherry_importer.dart`、`chatbox_importer.dart` | 写入目标改为 `BusinessRepository` |

写放大说明：整表重写仅发生在列表重排/导入等低频操作；单项增删改走单行事务，优于今日"整列表 JSON 重写"，属纯内部优化，不改变行为。

### 5.3 启动序列（`main.dart`）

```text
binding → logger → appDataDir
→ 业务租约 + 恢复门（协议见 §7.3，收敛为 DB + assets）
→ 早期 prefs：flutter_log 开关（残留集）
→ 桌面窗口初始化（残留集 window 键）
→ SandboxPathResolver.init
→ Hive 聊天迁移检查：需要 → MigrationApp（目标库建为 schema 1），完成后要求重启
→ DatabaseInstallationGate.ensureReady（schema 1）
→ [新增] 业务数据迁移门（§6）：需要则迁移，失败 fail-closed
→ runApp(MyApp)：providers 注入 BusinessRepository，异步 _load() 模式与现状相同
```

关键变化：gateway 在 gate 通过后、`runApp` 前打开并持有（现状是 `ChatService.init()` 时才打开）；`ChatService` 复用同一实例。数据库打开时机前移不引入全库扫描（PD-17 的零扫描承诺不受影响）。

## 6. 迁移协议（正式 Hive 版 → schema 1）

### 6.1 触发与顺序

- **聊天迁移**：沿用现有 Hive → SQLite 迁移页与协议，唯一变化是目标库 schema 为 1（自动跟随 `currentSchemaVersion`）。
- **业务迁移**：在正常启动路径的安装门之后、`runApp` 之前同步执行（数据量 < 数 MB，秒内完成，无独立 UI）。判定：`chat_storage_meta_rows` 无 `business_migration_complete_v1` 收据 → 检查 prefs 是否存在业务键 → 有则迁移，无（全新安装）则直接写收据。
- 顺序保证：升级用户先走聊天迁移页并重启，业务迁移必然发生在其后的正常启动中；聊天迁移页的灾难备份仍从 prefs 读取设置，此时业务数据尚未离开 prefs，行为不变。

### 6.2 迁移器（单事务，幂等）

```text
read prefs 全量快照
→ 归一化（§3.5）
→ 单事务：清空 12 张业务表 → 按 §3 映射写入实体表 + KV → 写收据
→ validate（事务外）：
   a) 每张实体表 count == 源列表长度；
   b) 等值校验：立即执行 §7.1 的 settings.json 导出，与迁移前 prefs 快照
      经 §3.5 归一化后的形态按键深度比较（丢弃键、残留键除外），必须完全相等；
→ 通过后删除 prefs 旧业务键（丢弃键一并删除）
```

- **幂等**：事务失败回滚后 prefs 未动，下次启动重试（重试先清目标表，cherry 模式）；收据已存在但 prefs 旧键仍在（删除阶段被杀）→ 只重跑删除清理，绝不重迁移（防止旧值覆盖新数据）。
- **失败 fail-closed**：迁移或校验失败时不得以空设置放行业务（沿用"数据存在性"不变量），进入与恢复失败页同风格的错误页，保留可定位错误信息；prefs 数据原样保留，修复版本可重试。
- 损坏的单键 JSON：无法解析的实体键按"整键拒绝 + 报错 fail-closed"处理，不静默跳过（业务键损坏意味着真实数据事故）；未注册键类型不支持时同样报错。

## 7. 备份与恢复

### 7.1 新备份格式（BD-03）

ZIP 结构与未发布 v2 聊天格式一致，仅 `settings.json` 的产生方式改变：

| Entry | 内容 |
| --- | --- |
| `settings.json` | **从数据库导出**：实体表按 `sort_order` 重建原键形 JSON 字符串（`assistants_v1` 等 11 键 + 由 `provider_rows.sort_order` 重建的 `providers_order_v1`）+ 全部 KV 键。键形、值类型与已发布 Hive 版逐字节同构；明文含全部凭据（API key、代理密码、WebDAV/S3/搜索/TTS） |
| `manifest.json` | 照旧，`secretsIncluded: true` |
| `database/kelivo.db` | includeChats 时的一致快照（快照内业务表内容允许存在，导入端一律忽略，见 §7.2） |
| `upload/`、`avatars/`、`images/`、`fonts/` | includeFiles 时照旧 |

备份包含/排除范围与升级前完全一致（BD-06）；残留 prefs 键（§3.3）照旧不出现在备份中。

### 7.2 恢复

**业务数据在一切导入路径中的唯一权威是 `settings.json`**；DB 快照中的业务表在导入时被覆盖、不作为来源（避免双源分歧）。

| 场景 | 行为 |
| --- | --- |
| overwrite + includeChats | staging 阶段以 ZIP 的 DB 快照为 candidate，并把 `settings.json` 业务数据在 staging 内写入 candidate 业务表；重启门内 DB + assets 整体切换（现有 crash-safe swap 协议） |
| overwrite 仅设置 | 不触碰聊天数据；重启门内单事务替换 live 库业务表（清空 + 写入），WAL 保证原子性，无文件切换 |
| merge | 聊天 merge 照旧；业务 merge 保持现有键级合并规则（特殊合并键集合不变：`assistants_v1`、`assistant_memories_v1`、`provider_configs_v1`、`pinned_models_v1`、`providers_order_v1`、`mcp_servers_v1`、`provider_groups_v1`、`provider_group_map_v1`、`provider_group_collapsed_v1`、`search_services_v1`、`assistant_tags_v1`、`assistant_tag_map_v1`、`assistant_tag_collapsed_v1`；其余键整体覆盖），在单事务内落库 |
| 旧 Hive 版 ZIP（`settings.json` + `chats.json`） | `settings.json` 走同一键路由器入库（丢弃键忽略、未知键进 KV、local-only 键忽略）；`chats.json` 走既有 legacy 只读导入 |
| 任意导入完成 | 一律弹"需要重启"对话框（PD-16 不变） |

### 7.3 恢复协议简化

业务数据入库后，恢复不再需要写 SharedPreferences，crash-safe 协议从三条腿（DB/settings/assets）收敛为两条腿（DB/assets）：

- **退役**：settings staging/previous touched-keys、`settings_cold_ack.json`、跨进程 settings readback、二次冷启动确认等 settings 专属机制（未发布协议，无兼容负担）；
- **保留**：receipt journal、operation-ahead marker、previous bundle、fail-closed 仲裁、重启对话框、恢复失败页、`.kelivo_restore` 痕迹清理项等 DB/assets 侧全部既有语义。

用户可见交互不变（导入完成 → 重启对话框 → 重启后生效）。

## 8. 行为不变量

1. 所有设置、助手、Provider、MCP、世界书、记忆、快捷短语、搜索/TTS、代理、备份配置的读写语义、默认值、生效时机与升级前一致；
2. 备份 ZIP 的包含范围、明文凭据策略、merge/overwrite 语义、重启要求与升级前一致（唯一例外：`flutter_log_enabled_v1` 不再备份，BD-02）；
3. 残留 prefs 键继续不参与备份恢复；
4. 文件资产目录结构与 payload 中的路径引用不变；
5. 正常启动零全库扫描（PD-17）不回退；业务表读取为 O(业务数据量)，与聊天库大小无关；
6. 迁移、恢复错误可见且 fail-closed，不静默创建空数据、不假成功；
7. `settings.json` 导出与 prefs 时代键形逐字节同构，是迁移等值校验与备份兼容的共同锚点。

## 9. 验收标准

### 9.1 正式 Hive 版直接升级

- 造数：真实结构的 prefs 全量快照（含全部 §3 键、legacy 形态键、未注册键、多凭据 Provider）+ Hive 聊天数据；
- 升级后：聊天迁移 + 业务迁移完成；导出 `settings.json` 与升级前 prefs 快照深度相等（丢弃/残留键除外）；prefs 中仅剩残留集；再次冷启动无重复迁移、无全库扫描；
- 故障注入：迁移事务中途 kill → 重试成功；收据后删除键阶段 kill → 只重跑清理；损坏实体键 JSON → fail-closed 错误页且 prefs 保留。

### 9.2 全新安装

- 直接建 schema 1（user_version = 1），业务迁移门直接写收据；所有默认值与现版本一致；MCP 内置 `@kelivo/fetch` 等播种逻辑照常。

### 9.3 备份与恢复

- 新格式 round trip：备份 → 全新安装恢复（overwrite，两种 includeChats × includeFiles 组合）→ 导出等值；
- merge：特殊合并键与整体覆盖键行为与现版本逐键一致；
- 旧 Hive 版 ZIP 导入：overwrite 与 merge 均可用，凭据可直接使用；
- 恢复各 failpoint 重启后只见完整旧/新 bundle。

### 9.4 Fail-closed 矩阵

- user_version ∈ {2..11} 的开发中间库 → 拒绝且不改写；
- user_version > 1 → `database_schema_too_new`；
- 业务迁移失败 → 错误页，不放行业务。

### 9.5 全量门禁

`flutter analyze` 全绿；全量测试通过；用户真机确认升级后设置/助手/凭据完整、备份恢复可用。

## 10. 实施阶段

| 阶段 | 内容 | 退出条件 |
| --- | --- | --- |
| B1 schema 收口 | 版本重编号 11→1、新增 12 张业务表、schema 快照与拒绝矩阵更新、`BusinessRepository` | 快照/拒绝测试通过；聊天全量测试不回归 |
| B2 读写切换 | gateway 前移；providers/stores 逐个切换到仓储（settings_provider 最后、拆多个 PR）；删除 `ChatProvider`；learning mode 收敛 | 各 provider 单测 + 手工回归；prefs 业务键零读写（残留集除外，`rg` 门禁） |
| B3 迁移门 | 业务迁移器 + 收据 + 等值校验 + prefs 清理 + fail-closed 错误页 | §9.1 全部通过 |
| B4 备份恢复 | `settings.json` 从库导出/导入路由器、merge 落库、恢复协议两条腿收敛、settings 机制退役、importers 改造 | §9.3、§9.4 通过 |
| B5 收尾 | 死代码清理（`SharedPreferencesAsync.snapshotForRegularBackup` 等）、文档更新、真机验收 | §9.5 |

每阶段独立可测试、可回滚；B2 期间允许"部分 provider 在库、部分在 prefs"的**开发期**中间态，但 B3 合入前必须全部切完（迁移器一次性搬全量）。

## 11. 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| `settings_provider.dart`（5071 行）改造回归面大 | 分 PR 切换 + 等值校验作为机器可验的总闸；键清单以 §3 为唯一注册表 |
| 键清单遗漏导致数据丢失 | 未注册键兜底进 KV（§3.2）；等值校验按"prefs 实际快照"对比而非清单对比 |
| 恢复协议改动引入回归 | 只退役 settings 腿，DB/assets 腿的状态机与测试矩阵不动；fail-closed 语义不变 |
| gateway 前移影响启动性能 | 打开路径 O(1)（PD-17 已保证）；以固定设备冷启动实测守门 |
| 双源期（B2 中间态）数据分叉 | 中间态仅存在于开发分支；发布门禁要求 B3 收据机制合入后才可出包 |
