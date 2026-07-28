# 异步化改造与 SQLite 迁移遗留问题审计及修复方案

> 状态：全部三批 + 观察项已实施 —— 第一批（B1/B2/B3/B4、A1/A2/A3、A5、屏障自死锁）、第三批 C1/C2/C3（含 B5）及措施 19（asset 五表收编 Drift schema v1）、A6/A9、第二批 A4/A7/A8/B6 均已落地；观察项：屏障自死锁（第一批已修）、退出 flush（桌面 onExitRequested+托盘路径，2 秒超时兜底）、附件管线（压缩队列不删用户源文件 + OCR hash 缓存）、completed/ 归档 N 次冷启动自动修剪均已处理；18 条确认问题 + 4 条观察项全部处理完毕，经全量测试（1484 个）与对抗评审
> 范围：同步→异步改造引入的缺陷、Hive→SQLite 迁移与备份/恢复链路、基于发版前提可删除的过渡代码
> 前提：最后发布版本为 **1.1.17+61（纯 Hive）**，此后的 SQLite 迁移（#792/#800）与异步化改造均未发版。因此**只需支持"1.1.17 Hive 数据 → 当前版本"一次性迁移**，未发版期间的中间格式/灰度/回滚机制可删除。两个必须保留的兼容面：① 1.1.17 时代的备份文件必须仍可恢复；② Cherry/ChatBox 第三方导入是独立功能，不是过渡代码。
> 产出方式：6 路审计面深读（Hive 迁移 / 过渡代码 / 核心异步化 / UI 异步化 / 备份恢复 / DB 完整性）→ 70 个问题去重为 14 条（已剔除与 `docs/chat_cache_optimization_plan.md` 12 条重复项）→ 逐条对抗验证 → 完整性批评家补漏二轮（API 流式层 / 退出期持久化 / 附件管线）→ 最终 **18 条确认、1 条驳回**
> 与缓存优化方案的关系：两文档问题集互斥，实施可并行；本文档 C 组简化项与缓存方案 P1 措施 10（legacy 回退查询跳过）相交，采纳本文档 C-2 后缓存方案措施 10 直接作废（连表一起删）。

## 1. 结论先行

三类问题都实锤存在，且有多条**发版阻断级**：

1. **迁移与旧备份对 1.1.17 真实数据零容忍**：悬空 messageIds、跨会话引用、重复 id 这些 1.1.17 运行时静默容忍的脏数据形态，会让用户**永久锁死在迁移页**（无跳过路径），或让 1.1.17 的备份文件被新增的严格校验直接拒绝恢复——恰好违反必须保留的兼容面。每个升级用户都要过这两道门。
2. **生成链路的停止/错误语义在异步化后是坏的**：停止按钮从不真正中止 HTTP（取消登记表实践中全盘失效）；弱网僵死连接下停止路径无限挂起；三个 provider 家族集体忽略 SSE 带内 error 事件，把截断内容按"正常完成"落库；`openai_common` 一个 catch 横跨 1900 行吞掉 follow-up 请求的全部错误。
3. **恢复/导入与资产注册表脱钩**：覆盖恢复 1.1.17 备份约 7 天后，资产 GC 会**物理删除仍被消息引用的图片/附件**——真删用户文件。
4. **过渡代码可大量删除**：灰度/回滚台账（自身还有两个 bug，会让 Hive 清退闸门永久关闭）、legacy 双表及其热路径永续双写、整条未接线的快照覆盖路径 + migration 记账表族——趁 schema v1 未发布零迁移成本清掉。

## 2. 已确认问题清单

18 条全部经独立怀疑者对抗验证，描述为修正后的准确机制。编号分三组：A 异步化/生成链路，B 迁移/备份/恢复，C 可删过渡代码。

### A. 异步化与生成链路缺陷

**A1【高】停止按钮从不真正中止 HTTP，生成在后台跑完**
`ChatApiService.sendMessageStream` 按 requestId(=conversationId) 在静态表 `_activeCancelTokens` 登记 CancelToken（`chat_api_service.dart:574-581`），`cancelRequest`（`:71-79`）是唯一能真正断网的路径——但停止按钮走的 `cancelStreaming`（`chat_actions.dart:1324-1326`）只 `await sub?.cancel()`，从不调用 `cancelRequest`；`DioHttpClient.close()` 刻意不 force、`StreamController.onCancel` 刻意为空（`dio_http_client.dart:135-153`、`:254-265`），全链路零超时（`:64-74`）。净效果：点停止只是不再消费流，HTTP 连接与 token 消耗照旧跑完。登记表唯一能触发 `prev?.cancel('replaced')` 的路径依赖取消流程自身被网络卡死，实践中形同死代码。

**A2【高】僵死连接下停止路径无限挂起**
`async*` 生成器只能在挂起点响应取消：若流正卡在 `await` 等下一个网络 chunk（TCP 半开、NAT 超时、代理挂死；SOCKS5 路径同样无超时），`await sub.cancel()` 要等到下一个 chunk 到达才返回——停止不仅不断网，其后续清理（finalize checkpoint 等）也被网络停滞拖延。同模式共 4 处：`chat_actions.dart:1324-1326`、`:1456`、`:1821`、`:2003`。修复方向：先 `cancelRequest`（让 CancelToken 使字节流出错、生成器解除 await）再 `await sub.cancel()`，并给 cancel 加超时兜底。

**A3【高】SSE 带内 error 事件被三个 provider 家族集体忽略，截断内容按"正常完成"落库**
OpenAI 兼容流的 `{"error": ...}` 帧 jsonDecode 成功后不进入任何错误分支（`openai_common.dart:2373-4277` 无 error 键处理）；Claude 的 `event: error`（`claude_official.dart:594-945`）与 Gemini 的带内 error（`google_common.dart:1225-1612`）同样无分支。流随后关闭时兜底 `isDone:true`（`openai_common.dart:4281-4291`、`claude_official.dart:963-969`、`google_common.dart:1645-1651`）把截断当正常完成落库——用户看到半截回复且无任何错误提示（限流/超额/内容过滤都表现为"回复变短"）。

**A4【高】`openai_common` 单个 catch 横跨 1900 行，吞掉 follow-up 的全部错误**
`openai_common.dart:2373` 的 try 到 `:4275-4277` 才 catch，注释是 "Skip malformed JSON"，实际把工具续跑的二轮请求非 2xx（`:2785-2787`、`:3453-3455` 的 throw）与 follow-up 流网络中断（`:2673`、`:2963` 的 await for）全部静默吞掉，随后 `:4281` 兜底 `isDone:true` 假性完成。对照 `[DONE]` 分支（`:2059-2061`）在 try 外能正常上抛，行为不一致。（验证修正：工具执行本身抛错不会走到这里——`tool_handler_service.dart:361-468` 的 handler 全身 try/catch 并转 `_toolError` JSON 返回，不上抛。）

**A5【高】流式生成中删除消息/会话不取消生成，checkpoint 撞外键使生成以 SqliteException 中止**
删除路径（`home_view_model.dart:495-666`）与活动流零耦合：删除后 250ms 内的下一个 checkpoint 写向已删行，触发 SQLITE_CONSTRAINT_FOREIGNKEY(787)（立即 FK 来自 tool_event_rows，或 DEFERRABLE FK 在 commit 时来自 message_part_rows，`app_database.dart:209-216`），`LatestWinsCheckpointWriter` 记 failure 后下次 add 同步抛（`latest_wins_checkpoint_writer.dart:32-39`、`:74-78`），生成以数据库错误中止，错误 snackbar 可能弹在已切走的无关页面。修复方向：删除路径先 `cancelStreaming` + 终结 checkpoint writer，把"删除即停止生成"变成不变量。

**A6【高】会话切换/窗口分页在 await 后不校验会话身份，并发重入可致窗口错配**
`ChatController` 的窗口变异方法（`setCurrentConversationAndLoad :110-122`、`loadMoreBefore :221-252`、`loadMoreAfter :254-283`、`refreshTimelineAfterMutation :350-370`，均在 `lib/features/home/controllers/chat_controller.dart`）在 await DB 之后不复查"当前会话还是不是发起时那个"：快速连续切换 A→B 时，A 的窗口结果可能晚到并覆盖 B 的窗口——用户看着 A 的消息把内容发进 B。错态会在下一次窗口重建（发送/编辑）时自愈，非字面永久，但决策时刻的错配已造成。`appendPersistedTailMessages`（`:553-557`）同族。注意：缓存方案 P0 措施 3 的"请求序号"只覆盖切换入口，这里要求**所有**窗口变异方法统一加身份复查（`appendPersistedTailMessages :548-551` 已有范式可抄）。

**A7【高】`updateMessage`/`updateMessageSilent` 全行读-改-写无并发保护**
`chat_service.dart:2052-2118`、`:2123-2180`：`getMessage → copyWith → 整行写回`，两个并发写者互相覆盖对方字段。已确认的碰撞对：翻译终写（`translation_service.dart:131-134`）与图片消毒回写（`home_page_controller.dart:2160-2166`）互为陈旧快照覆盖（窗口为单次写的读-写间隙，概率低但存在）。修复方向：改为 SQL 局部列 UPDATE（只更新传入的非 null 字段），既消竞态又省一次读；合并两方法时注意 Silent 版还缺资产脏标记。

**A8【高】MemoryStore/QuickPhraseStore/InstructionInjectionStore 整表 JSON blob 读-改-写：并发丢写 + 解码失败后静默清空全表**
三个 store（`lib/core/services/memory_store.dart:13-61` 等）把整表序列化为单个 JSON blob 做 RMW。竞态面：跨会话并行生成的记忆工具写入（`chat_actions.dart:2003` 的 `_conversationStreams` 允许多会话同时流式）、或用户 UI 编辑与工具写并发——后写者使前一条记录整行消失（`synchronizeEntities` 删除缺失行）。更重的尾部风险：blob 解码失败（如异常备份恢复出损坏 payload）后下一次保存会经 `business_repository.dart:52-56` **物理清空整表**。修复方向：仿 `BusinessPreferences._writeTail`（`business_preferences.dart:153-163`）的串行写队列抽统一 RMW 基类；解码失败时拒写而非清空。

**A9【中】发送/重生成防抖守卫在 4 个 await 之后才置位，特定入口双击产生重复消息 + isStreaming 孤儿占位**
loading 守卫（`home_view_model.dart:321`）在 `chat_actions.dart:839` 置位前有 4 个 await 的竞态窗口（`:779/:797/:803/:824`）。主输入框有 `ChatInputBar._isSubmitting` 重入锁（`chat_input_bar.dart:537-541`）保护，**可触发入口是建议词点击**（`home_page_controller.dart:705-713`）**与重新生成**（`home_view_model.dart:421-454`，`:988` 的 cancelStreaming 对近同时双击无效）。并发进入后各持久化一份（重复 user 消息 + 两个 isStreaming 占位），`_activeAssistantMessages` 后者覆盖前者，失败方早退不清理（`chat_actions.dart:915-917`、`:1172-1174`）：本次运行期内孤儿占位转圈、`_safeNotifyStateChanged`（`lib/features/home/controllers/stream_controller.dart:52-77`）沉默（推理折叠等通知失效）；下次冷启动由 `_resetStaleStreamingFlags` 清除，非永久。修复方向：per-conversation in-flight 标记在**首个 await 之前**同步置位。

### B. 迁移 / 备份 / 恢复缺陷

**B1【高·发版阻断】迁移对 1.1.17 脏数据零容忍且无逃生门：任一脏数据形态即永久锁死在迁移页**
迁移逐批 `putMigrationBatch` 落库（`hive_to_sqlite_migration_service.dart:393-450`），1.1.17 运行时静默容忍的三类脏数据任一存在即整体失败：① 悬空/跨会话 messageIds 引用（Hive box 尾部截断损坏正是其常见来源）；② 计数校验 `_validate`（`:1087-1100`）要求精确相等；③ 重复消息 id 撞 PK。失败后**没有任何跳过路径**——迁移页只有重试（`hive_to_sqlite_migration_page.dart:256-260`），`main.dart:130-138` 在迁移完成前不放行主应用：用户永久锁死。修复方向：装批时归一 conversationId、去重/重排版本、`_validate` 改以实际成功读取数为期望；失败 N 次后提供"跳过并保留 .hive 为 .hive.retired"逃生门；备份阶段 chats.json 导出降级为 best-effort（失败仍打包原始 .hive）。

**B2【高·发版阻断】1.1.17 真实备份被新增严格校验拒绝 overwrite 恢复**
legacy 备份（无 manifest 的 zip）恢复路径新增的 `_validateBackupReferences`（`data_sync.dart:1292-1339`）要求 messageIds 与消息集完全一致——但 1.1.17 全 app 按设计静默容忍悬空引用，这类用户的备份在当时完全可用，现在整份被拒（失败发生在写入前，无数据损坏，但最依赖备份兜底的人群恰好被拦）。且该校验的作用范围**恰好只有** legacy 备份这一必须保留的兼容面（v2 备份走另一条路径）。修复方向：对 legacy 备份将悬空引用降级为告警 + 按实际消息修剪 messageIds（SQLite 侧本就不存 messageIds 列，顺序由 message_order 派生，与 1.1.17 运行时行为等价）。

**B3【高·发版阻断】恢复/导入与 asset 注册表脱钩：覆盖恢复约 7 天后 GC 物理删除仍被引用的附件**
新会话批量落库路径不登记资产：`restoreConversation → putMigrationBatch`（`chat_database_repository.dart:3241-3262`）、`commitParsedImport` 的 conversationBatches（`:3319-3325`）、`mergeBackupSnapshot`/NDJSON 导入（`:3677-3727`）。恢复的消息引用着 upload/ 下的文件，但 asset_rows 无记录 → `runAssetMaintenance`（`chat_service.dart:1360-1434`，`_assetGcDelay` 7 天）判定无引用，**物理删除用户的图片/附件**。（追加到已存在会话的路径经 `addMessageDirectly`/`_replaceMessageParts` 是登记的，不受影响。）修复方向（db-integrity 面给出的统一不变式）：任何绕过 `_replaceMessageParts` 写入 message_rows 的路径，必须 (a) 为新 revision 打 asset_reference_dirty 标，或 (b) 使 assetReferenceBackfillVersion 收据失效——二者任一即可让现有 backfill 机制自愈。

**B4【高】v2 备份在"不恢复聊天"时静默跳过全部文件恢复**
用户勾选恢复设置但不恢复聊天时，upload/avatars/images/fonts 四类文件在 overwrite 与 merge 两种模式下均被静默跳过（`data_sync.dart:1514-1524` 的 return 与 `:1551-1554` 的 return；`:1503` 计算的 `restoreFiles` 在这两条路径上是死值）。头像/字体等"设置类资产"随之丢失。

**B5【中】merge 恢复只搬 5 张表：`message_part_rows`/`provider_artifact_rows`/`generation_run_rows` 被静默丢弃**
`mergeBackupSnapshot`（`chat_database_repository.dart:3641-3731`）合并进来的消息靠 shadow 列 + legacy 双表回退在读路径补偿，但 **OCR 工件（image_ocr_v1）永久丢失**（每张图要重新 OCR 计费）。注意该补偿正是与 C-2"删除 legacy 双表"互斥的依赖——两项必须一起改：merge 补 `INSERT...SELECT` 拷贝 parts/artifacts（含 revision_id 重映射）。同病的 `_importBackupSnapshot`（`:3746-3759`）在 lib 内无生产调用方，见 C-3 直接删除。

**B6【中】启动门对"存在但损坏/半成品的 kelivo.db"不自愈**
首启建库中途崩溃留下的残缺 DB、或截断/垃圾文件，下次启动被 `DatabaseInstallationGate`（`database_installation_gate.dart:70-94`）以 `database_schema_version`/`database_corrupt`（`chat_database_repository.dart:217-218`）拦截 → `_RestoreFailureApp` 失败页只有"重启"按钮 → 永久死循环，尽管此时明确无数据可丢（或 Hive 源数据完好可重迁移）。修复方向：细化 diagnosticCode → 用户动作映射（`database_schema_too_new`=请升级；首启无收据且 userVersion=0=自动重建；损坏且 Hive 源在=引导重迁移）；`.migrating` 临时文件失败路径补清理。

### C. 可删除的过渡代码（趁 schema v1 未发布，零迁移成本）

**C1【高】`DatabaseV2RolloutLedger` 灰度/回滚脚手架整块删除——且现状自身有两个 bug**
489 行的按 basis-points 分桶灰度（`main.dart:167-189`，默认 10000=100%，首个 SQLite 版本即全量发布，灰度维度无意义）+ 冷启动收据链。现状 bug：① 每次冷启动追加一个收据文件且 fsync，**无限增长**；链上任一文件缺损即 `read()` 返回 null → 存储页的 Hive 清退闸门（`storage_usage_service.dart:515-522`）**永久关闭**；② 用户恢复 1.1.17 备份重迁移时 `recordMigrationCompleted` 抛 `database_v2_rollout_already_tracked`（`database_v2_rollout_ledger.dart:174-179`）被吞，同样永锁清退。其"3 次冷启动 + 30 天"退休判定在 lib 内零调用（死代码）。**替代**：迁移完成凭证已有 DB 内 meta key `hive_migration_complete_v1`，存储页闸门改查 `repo.isMigrationComplete()`（需把 repository/lease 传入存储页链路，或直查 `chat_storage_meta_rows`）；冷启动路径不再做任何收据 I/O（顺带消除迁移检测每次启动为读一个 key 而完整启动 drift isolate 的开销——可改只读 sqlite3 直查）。

**C2【高】legacy 双表（`tool_event_rows`/`gemini_thought_signature_rows`）连同热路径永续双写整体退役**
现状是永久 split-brain：运行期新数据写 parts/provider_artifacts 且**同时双写** legacy 表（`chat_database_repository.dart:3906-3913`、`:4423-4430`），读取 parts 优先 + legacy 回退（`:4119-4127`、`:4184-4196`）；而 Hive 迁移器（`:3829-3848`）、legacy 备份恢复（`chat_service.dart:1531`）、merge/快照（`:3717-3728`、`:3748-3754`）**只写 legacy 表**。退役方案（一揽子，不可只删一半）：
1. 迁移器与 legacy 备份恢复改为直接物化 parts/artifacts（`:2949` 处编辑路径已有"经 getToolEvents 回退惰性物化"的先例，证明可行）；
2. merge 补 parts/artifacts 拷贝（与 B5 同一改动）；merge 指纹读（`:3515-3527`）目前**只读 legacy 表**，必须同步改为读 parts，否则指纹静默丢失工具事件维度；
3. 热路径删双写、删回退读；
4. 删两张表 + `_validateRawStructure` 期望清单同步再生成。
落地后缓存方案 P1 措施 10（回退查询跳过）作废，每次翻页少 2 条查询的收益直接由删除获得。

**C3【中】未接线脚手架死代码族**
- `restoreDatabaseSnapshot` 整条 ATTACH 覆盖路径（`chat_service.dart:1555-1559` → `chat_database_repository.dart:3732-3788`）：lib 内无生产调用方（仅测试直测），且其五表拷贝同病于 B5；删除后连带检查 `_resetAfterOverwriteRestore` 是否成为死代码；
- `migration_run_rows`/`migration_issue_rows` 表族（`app_database.dart:247-298`、`chat_database_repository.dart:866-901`）：`completeMigrationRun` 零调用方，记账职责已被文件 ledger 取代（而 ledger 本身也在 C1 中删除）——表、访问方法、`_validateRawSchema` 期望、`test/core/database/generated_schema/schema_v1.dart` 固件一并清理；
- 同批次卫生：各文件级回执 formatVersion=2 常量归一；`activeStreamingIds` 元键残留检查。

## 3. 观察项（来自补漏轮总结，未单独对抗验证，实施时先复核）

- **屏障取消自死锁泄漏**：顺序监听器在 drain 回调内 `await` 自身 barrier cancel，正常完成路径每次自死锁；作者已在错误路径注释中意识到并规避（`chat_actions.dart:1964-1967`），但正常路径未修。修 A1/A2 时一并处理。
- **退出期无任何 flush 机制**：桌面三条退出路径直接销毁进程，无 `AppLifecycleListener`/`onExitRequested`。SQLite 侧靠 WAL+FULL 不丢已提交事务，实际丢失窗口集中在 Dart 内存侧（`BusinessPreferences._writeTail` 队列中未落库的设置写、250ms 节流窗口内的流式 checkpoint）。可选改进：桌面 `onWindowClose` 时 flush 写队列 + 终结 checkpoint writer（低成本高确定性）。
- **附件压缩队列的丢弃路径会物理删除用户文件**：`ChatInputBar` 内嵌压缩队列（`chat_input_bar.dart:306-393`）在发送后清空/restoreInput/dispose 三个触发点共享同一删除机制，失败对用户完全静默；OCR 的 `resolveImageContentHashes` 每次发送对全上下文历史图片逐文件重算 sha256（`chat_service.dart:2499-2529`）。建议列入后续专项。
- **`.kelivo_restore/completed/` 归档无自动修剪**：每次 overwrite 恢复后旧库+旧资产永久滞留，大库用户磁盘翻倍；可在 N 次成功冷启动后自动清理。
- **驳回记录**（避免后续误判重查）："Claude/Vertex 工具抛错被吞后重复执行"不成立——全项目唯一 onToolCall 实现（`tool_handler_service.dart:361-468`）全身 try/catch 恒返回非空 JSON，从不抛出。

## 4. 修复方案分批

原则与缓存方案一致：每项独立提交、独立回滚；发版阻断项优先。

### 第一批：发版阻断（升级/恢复走不通 or 真删用户数据）

| # | 措施 | 对应 | 工作量 |
|---|---|---|---|
| 1 | 迁移宽容化 + 逃生门：装批归一/去重、`_validate` 以实际读取数为准、失败 N 次可跳过（.hive 改名保留）、备份导出 best-effort | B1 | 中 |
| 2 | legacy 备份恢复宽容化：悬空引用降级为告警 + 修剪 messageIds | B2 | 小 |
| 3 | 恢复/导入路径统一资产不变式：绕过 `_replaceMessageParts` 的写路径打 dirty 标或失效 backfill 收据 | B3 | 小-中 |
| 4 | v2 恢复的文件恢复与聊天解耦：`restoreFiles` 在 `restoreChats=false` 路径上生效 | B4 | 小 |
| 5 | 停止真正断网：`cancelStreaming` 先 `cancelRequest(cid)` 再 `await sub.cancel()`（4 处），cancel 加超时兜底 | A1/A2 | 小-中 |
| 6 | SSE 带内 error 处理：三家 provider 补 error 分支（yield error 或抛出），消除"截断当完成" | A3 | 中 |
| 7 | 删除即停止生成：删除消息/会话路径先取消流 + 终结 checkpoint writer | A5 | 小-中 |

### 第二批：正确性加固

| # | 措施 | 对应 | 工作量 |
|---|---|---|---|
| 8 | `openai_common` 大 catch 收窄：follow-up 请求/流单独 try 并走错误路径；对齐 `[DONE]` 分支行为 | A4 | 中 |
| 9 | 窗口变异方法统一"await 后会话身份复查"守卫（抄 `appendPersistedTailMessages :548-551` 范式） | A6 | 小 |
| 10 | `updateMessage` 改局部列 UPDATE，合并 Silent 版（补资产脏标记差异） | A7 | 中 |
| 11 | 三个 JSON blob store 抽串行 RMW 基类；解码失败拒写不清空 | A8 | 中 |
| 12 | send/regenerate 首个 await 前同步置位 per-conversation in-flight 标记；失败方清理占位 | A9 | 小-中 |
| 13 | merge 恢复补 parts/artifacts 拷贝（与 C2 绑定同批） | B5 | 中 |
| 14 | 启动门自愈：diagnosticCode 细分 → 自动重建/引导重迁移/升级提示；清理 `.migrating` 残留 | B6 | 中 |
| 15 | 屏障取消自死锁：正常完成路径套用错误路径的既有规避 | 观察项 | 小 |

### 第三批：过渡代码清理（发版前完成，错过 schema v1 窗口成本剧增)

| # | 措施 | 对应 | 工作量 |
|---|---|---|---|
| 16 | 删 `DatabaseV2RolloutLedger` 全家；存储页闸门改查 `repo.isMigrationComplete()`；迁移检测改只读直查 | C1 | 中 |
| 17 | legacy 双表退役一揽子（迁移/恢复改物化 parts → merge 指纹改读 parts → 删双写/回退 → 删表 → 校验清单再生成）；分 4-5 个顺序提交 | C2 | 中-大 |
| 18 | 删 `restoreDatabaseSnapshot` 路径 + migration 表族 + 回执版本号归一；同步更新测试与 schema 固件 | C3 | 小-中 |
| 19 | asset 五表从运行时裸 SQL 懒建收编进 drift schema v1，纳入 `_validateRawStructure`（已完成） | 机会项 | 中 |
| 20 | 删除 portable NDJSON v2 实现、`ChatService` 专属导入/导出 API 与专项测试 | C3 关联 | 已完成 |

## 5. 验收与测试建议

1. **迁移矩阵**（B1）：用 1.1.17 真实形态构造夹具——尾部截断的 messages.hive、悬空 messageIds、跨会话引用、重复 id、groupId 空/非空重复版本——迁移必须全部成功进入主应用，跳过数入日志；
2. **旧备份夹具**（B2）：含悬空引用的 1.1.17 zip 备份 overwrite/merge 恢复各一遍，恢复后消息数与 1.1.17 运行时可见数一致；
3. **资产存活**（B3）：覆盖恢复含图片的备份 → 把 `_assetGcDelay` 调为 0 跑 `runAssetMaintenance` → 引用文件必须存活；
4. **停止语义**（A1/A2）：代理断流（收到部分 chunk 后挂起不关连接）下点停止：HTTP 必须在超时兜底内中止、UI 必须收敛；抓包确认停止后无继续下载；
5. **SSE error**（A3）：mock 三家 provider 的带内 error 帧，断言消息落库为 error 态且 UI 有提示；
6. **删除即停止**（A5）：流式中删除会话/消息，断言无 SqliteException、无孤儿 checkpoint failure；
7. **双写退役**（C2）：退役后全库 grep 两张表名零引用；merge 指纹对含工具事件的会话仍能正确去重；
8. **清退闸门**（C1）：迁移完成 → 恢复 1.1.17 备份 → 再迁移 → 存储页 Hive 清理项仍可用。
