# Kelivo 聊天数据库与消息系统 v2 重构进度

> - 方案基线：[chat-database-v2-refactoring-plan.md](./chat-database-v2-refactoring-plan.md)
> - 追踪基线：分支 `sql`，本轮实现基线 `502130aa`
> - 最后更新：2026-07-09
> - 当前结论：正常备份使用自校验、默认排除应用已知认证凭据的 SQLite snapshot + settings/assets ZIP，不再生成 `chats.json`；旧 JSON ZIP 仍只读导入，迁移页灾难备份仍使用 JSON。v2 overwrite 已改为运行期只做同卷 durable preparation，且 candidate 只复制用户选择与 bundle 能力交集中的 DB/assets；下一次启动先持有进程级 business lease，再在首次业务持久化读取前完成 unpublished cleanup、WAL 归一化、previous 冻结、DB/settings/assets operation-ahead 切换、完整验证与显式 `rollingBack` 回滚。terminal settings 通过绑定 receipt/native PID/lease token 的 cold ack 保留 active admission，同 PID 或同 token 都不能自确认；Android 自动重启使用 process mode。当前 macOS 逻辑故障注入、真实子进程 lease 竞争/kill 与完整 bundle 集成回归已覆盖，但真实跨进程 settings readback、cutover 各落盘点 kill/断电、磁盘满/权限/锁库和 Android/iOS/Windows/Linux 仍未验收，因此 P0-02 保持进行中

## 1. 文档使用规则

本文件是本次重构的唯一动态状态源。设计目标、架构和验收合同以[重构方案](./chat-database-v2-refactoring-plan.md)为准。

状态只使用以下固定枚举：

| 状态 | 含义 |
| --- | --- |
| `未开始` | 尚无满足验收条件的工作产物 |
| `进行中` | 已开始实施或验证，但尚未满足全部验收条件 |
| `阻塞` | 缺少产品决定、权限、平台或外部状态，无法继续有效推进 |
| `已完成` | 实现、要求的验证和交付证据全部完成 |
| `已取消` | 经明确决定不再实施，并已记录原因和替代方案 |

更新规则：

1. 不记录主观百分比；只有分母明确时才记录完成项计数。
2. `已完成` 必须同时填写完成日期、commit/PR、验证命令和结果。
3. “代码完成”“验证完成”“灰度完成”是不同门槛，不得提前合并为 Done。
4. 当前已有的 SQLite v1 代码是审计基线，不自动计入任何 v2 工作项完成度。
5. 每个实施 PR 必须引用一个或多个稳定工作项 ID，并更新本文件。
6. 若实现需要改变领域语义、schema 或回滚协议，先更新方案/决策记录，再修改代码。
7. 性能目标在 Phase 0 基准完成前均标记为“初始候选 SLO”。
8. 失败、跳过或只在单一平台完成的验证必须如实记录。

## 2. 当前总览

| 工作流 | 完成计数 | 状态 | 当前结论 |
| --- | ---: | --- | --- |
| 架构与代码审计 | 6 / 6 | `已完成` | 数据完整性、消息版本、timeline/渲染、迁移、测试覆盖和目标架构已审计 |
| 正式方案与进度文档 | 1 / 1 | `已完成` | 两份 Markdown 已创建并通过 whitespace、相对链接、ID 和表格结构检查 |
| Phase 0：止血与基线 | 2 / 9 | `进行中` | P0-01/P0-08 已完成；P0-02 overwrite 主链已联通 business lease、durable preparation、startup forward/rollback cutover、terminal revalidation/archive 与故障 UI，待 cutover 真实 kill 和五平台验收 |
| Phase 1：Database Kernel v2 | 0 / 8 | `未开始` | 尚未建立 v2 schema snapshot 或单一异步通路 |
| Phase 2：Message Graph | 0 / 7 | `未开始` | 受 PD-01/02/04 和 PD-13 影响 |
| Phase 3：Generation State Machine | 0 / 7 | `未开始` | 依赖 Message Graph 与 Database Kernel |
| Phase 4：Timeline 与 Renderer | 0 / 8 | `未开始` | 依赖逻辑 slot/cursor；不继续扩展物理 revision 滑窗 |
| Phase 5：Data Operations 与退役 | 0 / 9 | `未开始` | 部分可在 Database Kernel 后并行，最终退役依赖灰度证据 |

## 3. 已完成的审计工作

| ID | 工作项 | 状态 | 日期 | Commit/PR | 验证或证据 |
| --- | --- | --- | --- | --- | --- |
| AUD-01 | 仓库、schema、Hive → SQLite 迁移拓扑和 git 历史基线 | `已完成` | 2026-07-09 | 只读审计，无提交 | 基线 `sql` / `df1dae8a`；审计开始时 `git status --short` 为空 |
| AUD-02 | 数据完整性、恢复、备份、事务、WAL 和秘密边界审计 | `已完成` | 2026-07-09 | 只读审计，无提交 | 确认 overwrite restore、count-only validation、明文秘密等风险 |
| AUD-03 | 多版本、上下文、重生成、删除和流式状态审计 | `已完成` | 2026-07-09 | 只读审计，无提交 | 建立旧 revision 重生成包含未来消息的确定性反例 |
| AUD-04 | Timeline、双向滑窗、锚点、Markdown、图片和 cache 审计 | `已完成` | 2026-07-09 | 只读审计，无提交 | 证明 extent-delta 在 prepend + trim 时少补偿，append + trim 时无补偿 |
| AUD-05 | 当前测试覆盖与缺失故障场景审计 | `已完成` | 2026-07-09 | 只读审计，无提交 | 确认 repository 事务、fault injection、真实像素 anchor 等测试缺失 |
| AUD-06 | 目标架构、迁移协议、阶段计划和初始 SLO 收敛 | `已完成` | 2026-07-09 | 只读审计，无提交 | 方案见同目录重构方案文档 |
| DOC-01 | 创建正式重构方案与动态进度台账 | `已完成` | 2026-07-09 | `1a75f3da` | 两文件 `git diff --no-index --check`；相对链接、工作项 ID、表格列和 Mermaid fence 已检查 |

## 4. 当前验证基线

### 4.1 已执行

| 验证 | 状态 | 结果 | 日期 | 说明 |
| --- | --- | --- | --- | --- |
| `flutter gen-l10n` + untranslated check | `已完成` | 生成成功；`desiredFileName.txt` 为 `{}` | 2026-07-09 | 四份 ARB 同步，恢复失败提示已本地化 |
| `flutter analyze` | `已完成` | No issues found | 2026-07-09 | 当前工作区静态分析通过 |
| `flutter test` | `已完成` | 874 tests passed | 2026-07-09 | `b232ad8b` 提交前当前工作区全量测试通过 |
| `flutter analyze` + `flutter test`（本轮 P0-02） | `已完成` | No issues found；1012 tests passed | 2026-07-09 | 当前 macOS 主机全量通过；不等于 Android/iOS/Windows/Linux 或真实 kill/断电验证 |
| `flutter build macos --debug` | `已完成` | Debug `kelivo.app` 构建成功 | 2026-07-09 | 覆盖 main 启动 gate、fail-closed/cold-restart shell、迁移提示 overlay 与桌面窗口接线；其他桌面/移动平台未由本机构建 |
| 迁移、懒加载、滚动、版本选择、重生成上下文、流订阅等定向测试 | `已完成` | 73 tests passed | 2026-07-09 | 只证明现有断言成立，不覆盖审计反例 |
| SQLite bundle/秘密边界/legacy/migration 灾备定向测试 | `已完成` | 55 tests passed | 2026-07-09 | 覆盖 snapshot round trip、manifest/hash/schema/count、秘密清洗、settings 补偿、同卷 staging/链接拒绝/空资源根、v2 merge 安全拒绝、旧 JSON 与迁移灾备兼容 |
| Restore receipt/journal 定向测试 | `已完成` | 24 tests passed | 2026-07-09 | 覆盖 canonical checksum、append-only sequence/hash chain、非法跳转、损坏/超限/缺口拒绝、链接目录拒绝、初始 run/marker/topology/candidate/selection 复验、prepared retry 残留拒绝，以及跨 worker-isolate publish/discard 互斥；不等于目录 fsync 或 kill 验证 |
| Restore candidate/run identity + SQLite 只读复验 | `已完成` | 21 tests passed | 2026-07-09 | 16 个 staging 与 5 个 SQLite inspector 用例覆盖 run ID/固定路径/manifest hash、descriptor/manifest/未知字段篡改、canonical path、16 MiB settings 上限、settings 语义、DB、entry/hash、精确目录/空资源根、普通失败清理，以及 worker-isolate 单 run 仲裁；不等于 startup cutover 或目录 durability |
| Restore workspace lock/admission | `已完成` | 6 tests passed | 2026-07-09 | 覆盖同 isolate FIFO、跨进程 advisory lock、action 异常释放、root/lock link 与错误类型拒绝；POSIX 同进程多 isolate 另由原子 `.active_run → .publishing/.discarding` rename claim、staging admission 与 publish/discard worker-isolate 用例约束 |
| Restore admission/phase + DataSync 集成回归 | `已完成` | 89 tests passed | 2026-07-09 | `f33c9019` 提交前 workspace lock、staging、receipt、DataSync 四组定向用例通过；覆盖 worker-isolate staging/staging 与 publish/discard 竞态 |
| Restore preparation 协调器 | `已完成` | 5 direct / 47 DataSync tests passed | 2026-07-09 | staging→prepared receipt 已接入 DataSync v2 overwrite；方法返回时 live 设置/DB/assets 不变，只复制用户选择与 bundle 能力交集中的 DB/assets，candidate 与 receipt 组件精确相等；全选仍保留 SQLite 与真实 asset，旧 JSON 路径行为不变 |
| Restore startup gate / terminal archive | `已完成` | 35 direct tests passed；纳入 246 项聚焦回归 | 2026-07-09 | 本轮在同一 workspace 锁内完成 inspect→claim→forward/rollback→cold readback→terminal archive；8 个正向逻辑中断点、3 个回滚中断点、同 PID/同 token 拒绝、settings 重写再冷启、terminal 顶层未知项及 archiving marker 中断均可续跑，completed evidence 不阻塞下一次 restore；逻辑故障注入由测试侧 durability adapter 在真实 marker/receipt 发布边界触发，不向生产 API 暴露 failpoint，但仍不等于真实进程 kill/断电证明 |
| Restore previous plan/builder/store + durability | `已完成` | 24 tests passed | 2026-07-09 | 7 plan、8 builder、5 store、4 当前 macOS durability 用例；有界流式 hash、精确 DB/assets topology、immutable previous control、0700/0600、POSIX directory fsync、Apple `F_FULLFSYNC` 与 Windows write-through 实现已接入；Windows/移动端/Linux 尚未运行 |
| Restore live SQLite normalization | `已完成` | 4 tests passed | 2026-07-09 | raw SQLite checkpoint/TRUNCATE、journal DELETE、sidecar 拒绝/消失、main/parent barrier；包含带 WAL committed row 的复制恢复用例，不通过普通业务 repository 执行迁移 |
| Restore settings transition/store/cold ack | `已完成` | 纳入 246 项聚焦回归 | 2026-07-09 | 从 durable plan 重建 before/target、fresh reload、可恢复投影、apply/rollback/fingerprint；canonical cold ack 绑定 run/terminal receipt/expected/native PID/lease token，同 PID 或同 token 均不放行，替换丢失窗口安全回到“需冷启”；SharedPreferences 插件本身不宣称跨平台 fsync |
| Restore operation-ahead mover / cutover integration | `已完成` | 4 mover + 5 full-bundle tests passed | 2026-07-09 | DB、四资源根和 settings 每项只接受 descriptor 可证明的位置；candidate 与 receipt 组件双向精确绑定；完整 SQLite/settings/assets 正向提交与“已安装后验证失败→rollingBack→rolledBack”均回读精确旧/新数据；cutover 原始错误会结构化记录，补偿回滚再次失败时同时保留两组错误/堆栈且 receipt 停在可续跑的 `rollingBack`；committed 等待 cold ack 时 DB/asset 篡改只 fail-closed、不回 previous |
| Restore receipt/workspace protocol | `已完成` | 36 tests passed | 2026-07-09 | append-only receipt、6-record rollback chain、精确 receipt temp、candidate/receipt 双向组件绑定、共享锁、publishing/discarding/archiving claim、terminal 顶层白名单、evidence 归档和下一 run 准入；真实多进程 kill 与 Windows rename 仍待验证 |
| Restore business lease / unpublished / terminal hardening | `已完成` | 246 focused tests passed | 2026-07-09 | 非阻塞进程/跨 isolate lease、真实子进程竞争与 kill 后重获；gate 在 lease 冲突时不触碰 prepared/live；strict no-receipt staging 耐久 discard；terminal cold ack 要求 native PID 与 token 均变化，需重写时继续阻止业务；fail-closed/rolled-back/cold-restart/restart-failure UI 均覆盖。真实跨进程 settings readback、cutover 每个落盘点 kill 与四个其他平台仍待验证 |
| Migration restart failure surface | `已完成` | 2 relevant widget tests passed | 2026-07-09 | 1 项真实点击 `MigrationApp` 完成页重启按钮并验证 Android process-mode channel、失败上报与本地化 snackbar，1 项 restart helper 验证失败后保留重试入口；不初始化业务 provider，也未为测试扩大生产 API |
| DataSync v2/legacy backup-import regression | `已完成` | 47 tests passed | 2026-07-09 | v2 导入只 prepare，启动经 terminal+cold readback 后整体生效/回滚；selected-only/full-selected candidate、SQLite snapshot、空 assets roots、secret-free cleanup、ZIP 边界、v2 merge 安全拒绝及旧 JSON 导入全部通过 |
| Backup settings 纯校验器与现有恢复回归 | `已完成` | 56 tests passed | 2026-07-09 | 4 个纯校验器用例覆盖 legacy string-list 规范化、合法值、本地键跳过及非法结构拒绝；连同 v2/legacy restore 和凭据边界回归通过，为 candidate 与启动 gate 复用同一规则建立基础 |
| 审计前生产工作区检查 | `已完成` | clean | 2026-07-09 | 文档创建前 `git status --short` 为空 |

定向测试命令：

```bash
flutter test \
  test/features/migration/hive_to_sqlite_migration_service_test.dart \
  test/features/home/controllers/chat_controller_lazy_history_test.dart \
  test/features/home/controllers/scroll_controller_test.dart \
  test/features/home/widgets/message_list_view_padding_test.dart \
  test/home_view_model_version_selection_test.dart \
  test/features/home/controllers/chat_actions_regeneration_context_test.dart \
  test/features/home/controllers/chat_actions_stream_subscription_test.dart \
  test/features/home/controllers/stream_controller_content_split_test.dart

flutter test \
  test/core/services/backup/data_sync_backup_file_test.dart \
  test/shared_preferences_async_backup_filter_test.dart \
  test/features/migration/hive_to_sqlite_migration_service_test.dart

flutter test test/core/services/backup/restore_receipt_test.dart

flutter test \
  test/core/services/backup/restore_bundle_staging_test.dart \
  test/core/database/chat_database_repository_snapshot_test.dart

flutter test \
  test/core/services/backup/backup_settings_validator_test.dart \
  test/core/services/backup/data_sync_backup_file_test.dart \
  test/shared_preferences_async_backup_filter_test.dart

flutter test \
  test/core/services/backup/restore_settings_store_test.dart \
  test/core/services/backup/restore_settings_transition_test.dart \
  test/core/services/backup/restore_previous_plan_test.dart \
  test/core/services/backup/restore_startup_gate_test.dart \
  test/core/services/backup/restore_bundle_preparation_test.dart \
  test/core/services/backup/restore_workspace_lock_test.dart \
  test/core/services/backup/restore_bundle_staging_test.dart \
  test/core/services/backup/restore_receipt_test.dart \
  test/core/services/backup/data_sync_backup_file_test.dart

flutter test \
  test/core/services/backup \
  test/features/backup/backup_restore_error_message_test.dart \
  test/features/migration/migration_app_test.dart \
  test/shared/widgets/restore_cold_restart_screen_test.dart \
  test/shared/widgets/restore_failure_screen_test.dart \
  test/shared/widgets/restore_outcome_notice_test.dart \
  test/shared/widgets/restart_app_action_test.dart
```

### 4.2 尚未执行

| 验证 | 状态 | 未执行原因 | 风险 |
| --- | --- | --- | --- |
| 真实设备 profile 与 RSS/frame/DB/WAL 基线 | `未开始` | P0-09 harness、参考设备和数据 seed 尚未建立 | 尚不能冻结性能 SLO 或 cache budget |
| Android/iOS/macOS/Windows/Linux 五平台能力验证 | `未开始` | 本轮只运行当前 macOS 主机的根目录分析与单测，未运行五平台 runner | FTS5、Backup API、rename/fsync、SQLite ABI 仍有平台边界 |
| kill -9/断电/磁盘满/权限/锁库故障注入 | `进行中` | 已有同进程正向/回滚/rename-after failpoint，但尚无独立子进程强杀和资源故障 harness | 当前只能证明逻辑幂等与歧义时 fail-closed，不能宣称真实断电安全 |
| 真实旧 Hive/SQLite v1/备份 fixture 全矩阵 | `未开始` | fixture 尚未整理 | 不能证明已发布数据可无损迁移 |
| 稳定 slot + localDy 的 widget/integration test | `未开始` | 目标 timeline 尚未实现 | 当前列表跳动问题无自动化保护 |

## 5. 产品与架构决策登记

所有决定完成后应填写“最终决定、日期、负责人/批准记录”。

| ID | 决策 | 当前推荐 | 状态 | 阻塞工作项 | 最终决定/证据 |
| --- | --- | --- | --- | --- | --- |
| PD-01 | 多版本是否采用真实分支 | 真实分支；旧未来保留在旧 branch | `未开始` | MSG-01～07 | — |
| PD-02 | 编辑、重生成、删除 revision 后的后代策略 | 新建/切换 branch，旧后代延迟 GC | `未开始` | MSG-01、MSG-04 | — |
| PD-03 | 中断输出的展示和重试策略 | 保留 partial，显示 interrupted，可重试/删除 | `未开始` | GEN-01～07 | — |
| PD-04 | 在历史位置发送时的交互 | 创建 branch，不强制立即跳底部 | `未开始` | MSG-01、TL-03/04 | — |
| PD-05 | 离开底部时的新内容提示 | 保持 anchor，显示“有新内容” | `未开始` | TL-04、TL-08 | — |
| PD-06 | 搜索当前 branch 还是全部 revision | 默认当前 branch，可显式扩大范围 | `未开始` | OPS-04 | — |
| PD-07 | 统计当前 branch 还是全部版本 | 分开呈现 active usage 与 total generation usage | `未开始` | OPS-05 | — |
| PD-08 | 完整备份是否含失败/中断 revision 和全部 branch | 完整备份包含，便携导出可裁剪 | `未开始` | OPS-01～03 | — |
| PD-09 | restore merge 的同 ID 冲突规则 | hash 相同去重，不同则 remap + report | `未开始` | P0-05、OPS-02/03 | — |
| PD-10 | 旧 DB 保留期与清理授权 | 至少一次成功启动 + 明确保留周期 | `未开始` | DB2-06、OPS-08/09 | — |
| PD-11 | 聊天 DB 加密和秘密导出政策 | 独立评估；普通备份排除秘密是无需等待该决定的安全底线 | `未开始` | OPS-07 | — |
| PD-12 | 损坏数据恢复体验 | 只读恢复页 + rejects/脱敏诊断包 | `未开始` | DB2-06、OPS-02 | — |
| PD-13 | SQLite v1 是否已发布给真实用户 | 以发布事实为准；若已发布，v1 为主源 | `未开始` | P0-09、DB2-01、MSG-05 | — |
| PD-14 | 正常完整备份的聊天主数据格式 | SQLite 一致快照 ZIP；不再写 `chats.json` | `已完成` | P0-02、OPS-01～03 | `4d810e21`；2026-07-09 用户确认，旧 JSON 只读导入，迁移页灾难备份继续 JSON |

## 6. Phase 0：止血与基线

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| P0-01 | 恢复错误向上传播，移除假成功 | 无 | `已完成` | 任一聊天/设置/资源失败时 provider 返回失败且 live 数据不被误报成功 | `117f8386`（2026-07-09） | `flutter analyze`；`flutter test`（801）；相关定向 34 项通过 |
| P0-02 | overwrite staging restore | 无 | `进行中` | 运行期 durable prepare 不改 live；下次启动在业务放行前收敛为完整新 bundle 或经验证旧 bundle，并跨冷启动确认 settings | 既有提交 + 本里程碑提交 | DataSync v2 已停止运行期在线覆盖，只在后台 isolate 生成同卷 selected-only candidate + prepared receipt，未选 DB/assets 不二次复制或归档；main/gate 先持有进程级 business lease，严格清理可证明未发布且无 final receipt 的半成品，再冻结并复验 previous、无条件退出 live WAL mode、同步旧 assets、逐对象移动 DB/assets、可重入 apply settings，按 `prepared→oldRenamed→newInstalled→verified→committed` 前向收敛；失败经 `rollingBack→rolledBack` 恢复 previous。terminal 继续留在 active admission，canonical cold ack 绑定 native PID 与 lease token，同 PID/同 token 均不能自确认；下一真实进程从平台持久层精确读回 settings 后才归档放行，需重写则再次冷启动。当前 macOS 逻辑故障注入、真实 lease 竞争/kill、完整 bundle 与 DataSync/legacy 回归通过；真实跨进程 settings readback、cutover 各落盘点 kill -9/断电、磁盘满/权限/锁库及 Android/iOS/Windows/Linux 尚未验证，因此不提前 Done |
| P0-03 | 单 writer latest-wins checkpoint + final barrier | 无 | `未开始` | 网络不等待 commit；≤4 writes/s + final；旧 checkpoint 不可越过 final | — | — |
| P0-04 | prepare/cancel/stale streaming 收尾 | 无 | `未开始` | prepare failure、off-window cancel、重启均无永久 loading | — | — |
| P0-05 | 事务化 merge ID/order 与冲突诊断 | PD-09 | `进行中` | merge 不生成重复 ID/order；冲突有报告和确定性处理 | `900811ec`、`6c3618b8`（安全门） | 所有 v2 bundle merge（含 settings-only）在冲突/凭据语义完成前显式拒绝且不修改目标；hash 去重、remap、report 和事务化 merge 尚未实现 |
| P0-06 | DB identity/installation receipt 与安全拒绝 | 无 | `未开始` | 既有 DB 缺失/损坏/版本过新时不自动创建或写入空库 | — | — |
| P0-07 | sandbox path migration version 化 | 无 | `未开始` | 正常启动不扫描全库；migration 幂等且失败可见 | — | — |
| P0-08 | 普通备份排除秘密 | 无 | `已完成` | ZIP 默认不含应用已知 API key/password/token；secret-free overwrite 清理目标旧凭据；旧 JSON/迁移灾备兼容明确 | `6c3618b8`（2026-07-09） | `flutter analyze`；`flutter test`（820）；相关定向 50 项通过；manifest 标记 `secretsIncluded: false`，结构化 provider/search/TTS/MCP/WebDAV/S3/assistant 与 URL 凭据均覆盖 |
| P0-09 | 基准生成器、legacy fixture 与性能基线 | PD-13 | `未开始` | D1～D6、参考设备、before metrics 和 failpoint harness 可重复 | — | — |

推荐实施顺序：

1. 为 P0-01/P0-02 写会失败的恢复测试和 staging 骨架。
2. 完成 P0-01，立即消除假成功。
3. 完成 P0-03/P0-04，解除输出与数据库的逐 chunk 串联。
4. 完成 P0-05/P0-06/P0-07/P0-08。
5. 冻结 P0-09 基线，作为后续阶段的回归门槛。

## 7. Phase 1：Database Kernel v2

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| DB2-01 | Schema snapshots 与逐版本 migration tests | PD-13、P0-09 | `未开始` | v1→每个 v2 版本 migrateAndValidate | — | — |
| DB2-02 | 删除 `_syncDb` 和同步数据库 API | P0-03 | `未开始` | profile 中 UI isolate SQLite 调用为 0 | — | — |
| DB2-03 | 单一 gateway、single-flight init、异步 DAO | DB2-02 | `未开始` | 应用内只有一个受控数据库通路 | — | — |
| DB2-04 | FK/UNIQUE/CHECK/微秒时间/索引 | DB2-01 | `未开始` | schema 强制领域不变量；query plan 使用索引 | — | — |
| DB2-05 | 事务化领域 commands | DB2-03/04 | `未开始` | send/version/delete/fork 等不再由 service 拼多步提交 | — | — |
| DB2-06 | DB identity、receipt、integrity/recovery | P0-06、DB2-03 | `未开始` | unclean/missing/corrupt DB 进入确定性恢复流程 | — | — |
| DB2-07 | 五平台 SQLite/FTS/Backup/文件能力 | DB2-03 | `未开始` | 五平台能力矩阵有实际运行证据 | — | — |
| DB2-08 | DB/query/WAL/checkpoint 脱敏观测 | DB2-03 | `未开始` | 可测 p50/p95、WAL 和失败，不记录正文/秘密 | — | — |

## 8. Phase 2：Message Graph

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| MSG-01 | 批准 branch 语义与 ADR | PD-01/02/04 | `未开始` | 产品示例与数据语义无歧义 | — | — |
| MSG-02 | Conversation/Branch/Slot/Revision schema | DB2-04、MSG-01 | `未开始` | parent/branch/slot 不变量由 FK/CHECK/事务强制 | — | — |
| MSG-03 | Active path projector 与 context boundary | MSG-02 | `未开始` | prompt 只含真实 ancestor path | — | — |
| MSG-04 | Edit/regenerate/select/delete/fork commands | DB2-05、MSG-03 | `未开始` | 全部使用稳定 revision/branch ID 且单事务 | — | — |
| MSG-05 | Hive/SQLite v1 → graph/legacy projection adapter | DB2-01、MSG-02、PD-13 | `未开始` | selection 双解释、因果歧义、truncate/orphan/duplicate 均保留 issue，不伪造真实历史 | — | — |
| MSG-06 | Legacy fixtures 与 digest 对比 | MSG-05、P0-09 | `未开始` | 可见序列、选中版本、prompt、parts/assets 均验证 | — | — |
| MSG-07 | 删除旧业务依赖 | MSG-03～06 | `未开始` | 业务不再依赖 `messageIds/versionSelectionsJson/truncateIndex` | — | — |

## 9. Phase 3：Generation State Machine

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| GEN-01 | `GenerationRun` schema 与条件 transition | MSG-02、DB2-05 | `未开始` | 终态不可被迟到事件回退 | — | — |
| GEN-02 | 原子 begin send/regeneration | GEN-01、MSG-04 | `未开始` | user/assistant/run/branch 一次提交 | — | — |
| GEN-03 | 网络/UI/DB 三链解耦 | P0-03、GEN-01 | `未开始` | 网络不 await UI/DB；UI frame paced；DB latest-wins | — | — |
| GEN-04 | Complete/fail/cancel/interrupted 收尾 | GEN-01～03 | `未开始` | 所有 failure path 清 loading 并保留正确 partial | — | — |
| GEN-05 | Ordered message parts/provider artifacts | MSG-02、GEN-04 | `未开始` | reasoning/tool/signature 与 final 同事务一致 | — | — |
| GEN-06 | 启动恢复非终态 run | GEN-01/04 | `未开始` | 删除 active ID JSON；启动原子转 interrupted | — | — |
| GEN-07 | 竞态、乱序、kill 与长响应验证 | GEN-02～06、P0-09 | `未开始` | 规定矩阵全部有自动化和 profile 证据 | — | — |

## 10. Phase 4：Timeline 与 Renderer

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| TL-01 | Active ancestry cursor 逻辑分页 | MSG-03、DB2-03 | `未开始` | page 单位为 slot；无 OFFSET/物理 revision 坐标 | — | — |
| TL-02 | 行数 + 字节双预算窗口 | TL-01 | `未开始` | 版本数不击穿窗口；切会话/浏览后内存回落 | — | — |
| TL-03 | Slot ID + localDy 锚点协调器 | TL-01/02 | `未开始` | 规定 mutation 后漂移 ≤1 logical px | — | — |
| TL-04 | Following/user anchored/jump 状态机 | PD-04/05、TL-03 | `未开始` | 用户阅读历史时 stream 不强制跳动 | — | — |
| TL-05 | `MessageRenderModel` 与细粒度订阅 | TL-01 | `未开始` | 无每行全列表扫描和无关整页 rebuild | — | — |
| TL-06 | 增量 Markdown、字节 LRU、图片尺寸 | TL-05 | `未开始` | 长输出无平方级退化；图片不造成无控高度跳变 | — | — |
| TL-07 | 长表格/代码/tool 虚拟化 | TL-05/06 | `未开始` | D5 不一次构造全部大 widget 树 | — | — |
| TL-08 | 移动/桌面交互与可访问性 | TL-03～07 | `未开始` | 五平台 touch/mouse/keyboard/resize 验证 | — | — |

## 11. Phase 5：Data Operations 与退役

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| OPS-01 | 默认 SQLite snapshot ZIP + manifest/hash | DB2-03/07 | `进行中` | 活动库备份一致；完成前重开验证；新格式不写 `chats.json` | `4d810e21`、`e179737c`、`900811ec`、`6c3618b8` | Online Backup、独立重开/integrity/FK/schema/count、DB/settings/assets 流式 hash、ZIP 自校验、round trip 与应用已知认证凭据排除已实现；五平台/大数据 profile 与 Zip64 尚未完成 |
| OPS-02 | Staging restore/merge + crash-safe bundle swap | P0-02、DB2-06/07 | `进行中` | DB/settings/assets 切换时阻止业务访问，receipt 恢复后只开放完整旧/新 bundle | 既有提交 + 本里程碑提交 | overwrite 主链已实现 selected-only candidate、candidate/receipt 双向绑定、business lease、strict secret-free/unknown-topology 校验、append-only receipt、bounded previous、平台 durability、WAL normalization、operation-ahead forward/rollback、PID+token cold ack/archive 和 DataSync/startup/failure/restart UI；Android 请求 process restart，重启失败保留重试入口。仍未完成真实跨进程 settings readback、cutover kill/断电与五平台验证；v2 merge 在 PD-09 完成前继续安全拒绝，不随 overwrite 路径提前 Done |
| OPS-03 | 旧 JSON 只读 adapter + 显式 portable NDJSON v2 | MSG-05、OPS-01 | `进行中` | 新完整备份不写 JSON；旧 ZIP/迁移 JSON 可导入且尽力保持有界内存 | `117f8386`、`900811ec` | 新备份不再生成 JSON；旧 `chats.json` 和无 manifest settings-only 导入仍可用；Recovered/rejects、单次解析 candidate 与流式 parser 未完成 |
| OPS-04 | FTS5/短中文 fallback/branch navigation | PD-06、DB2-07、MSG-03 | `未开始` | D2 正确率和 p95 达标，五平台一致性已验证 | — | — |
| OPS-05 | SQL stats 与口径 | PD-07、MSG-03 | `未开始` | current branch/total usage 定义和查询均明确 | — | — |
| OPS-06 | Assets FK、尺寸、缩略图、延迟 GC | MSG-02、TL-06 | `未开始` | 删除消息不扫全库；资源 hash/reference 可验证 | — | — |
| OPS-07 | 平台安全存储与秘密备份策略 | P0-08、PD-11 | `进行中` | 普通备份移除应用已知认证凭据；五平台 secure storage 通过 | `6c3618b8`（备份边界） | 普通 bundle sanitizer、目标旧凭据清除、旧 JSON/迁移灾备兼容已覆盖；凭据尚未迁入五平台 secure storage，自由文本仍可能含用户粘贴的秘密 |
| OPS-08 | 灰度、支持、v2-compatible rollback | OPS-01～07 | `未开始` | 迁移/恢复/性能指标达标且回滚演练通过 | — | — |
| OPS-09 | 移除 Hive/v1 写路径和旧文件 | PD-10、OPS-08 | `未开始` | 保留期、成功启动、清理授权和支持方案全部满足 | — | — |

## 12. 数据迁移覆盖台账

| 实体/字段 | 来源 | v2 目标 | 转换/异常策略 | 状态 | 验证证据 |
| --- | --- | --- | --- | --- | --- |
| Conversation metadata | Hive / SQLite v1 | `conversations` | ID 稳定；时间转 UTC 微秒；同秒加 ID tiebreaker | `未开始` | — |
| `messageIds` / `message_order` | Hive / SQLite v1 | revision parent path | group 最小 order + timestamp + ID 确定性映射 | `未开始` | — |
| `groupId` / `version` | Hive / SQLite v1 | slot/revision | `COALESCE(group_id,id)`；重复/缺口写 warning/rejects | `未开始` | — |
| `versionSelections` / `versionSelectionsJson` | Hive / SQLite v1 | active branch concrete revision + migration issue | 同时按 ordinal/version 解释；冲突保留两候选并标记歧义 | `未开始` | — |
| `truncateIndex` | Hive / SQLite v1 | context start revision | 落在 group 内记录 warning，不猜测 | `未开始` | — |
| Streaming state | Hive / SQLite v1 | generation run | 所有活动 bool 转 `interrupted`，保留 partial | `未开始` | — |
| Content/model/provider/tokens | Hive / SQLite v1 | revision metadata + authoritative message parts | content 转 text part；hash/count 验证，不保留双份正文真相 | `未开始` | — |
| Reasoning/translation | Hive / SQLite v1 | revision/parts | 保留顺序和时间，坏 JSON 进入 rejects | `未开始` | — |
| Tool events | Hive / SQLite v1 | ordered message parts | message/revision FK 与 ordinal 验证 | `未开始` | — |
| Gemini signature | Hive / SQLite v1 | provider artifacts | revision FK + hash | `未开始` | — |
| MCP servers | Hive / SQLite v1 | conversation MCP mapping | ordinal 唯一 | `未开始` | — |
| Attachments/uploads | 正文路径/目录 | assets/message_assets | hash、mime、尺寸；缺文件明确状态 | `未开始` | — |
| Orphan messages/events | Hive boxes / SQLite v1 | Recovered conversation/rejects | 全量 key 差集，不静默丢弃 | `未开始` | — |
| Search/stats cache | 当前派生数据 | v2 派生索引 | 不迁移为主数据，验证后重建 | `未开始` | — |
| Draft/temporary conversation | 运行时/Hive | 待明确持久化边界 | 不默认混入永久 branch | `未开始` | — |

## 13. 版本兼容台账

| 场景 | 预期支持 | 状态 | 验证/说明 |
| --- | --- | --- | --- |
| Hive → SQLite v2 | 必须 | `未开始` | 需要所有 adapter fixture、orphan/坏数据场景 |
| SQLite v1 → SQLite v2 | 必须 | `未开始` | PD-13 确认后视为主迁移路径 |
| 旧 ZIP/chats.json → v2 | 必须 | `进行中` | 当前接受缺少 `chats.json` 的 legacy settings-only 包，并严格拒绝引用缺失；无 manifest 时无法区分 settings-only 与截断包，受损 Hive 迁移备份仍缺 Recovered/rejects adapter 和真实 fixture |
| 默认 SQLite snapshot ZIP → 当前应用 | 必须 | `进行中` | 已覆盖生成后自校验、hash/size/schema/count 拒绝、normalized candidate、运行期 prepare、下次启动完整 SQLite/settings/assets commit 或 rollback；真实 kill/断电和五平台尚未验证 |
| 迁移页 JSON 灾难备份 | 必须 | `进行中` | `900811ec` 回归锁定仍含 `chats.json` 且不含 manifest/SQLite payload；受损 fixture、分批扫描和 OOM profile 尚未完成 |
| Chatbox/Cherry import → v2 | 必须 | `未开始` | staging + ID conflict policy |
| v2 full backup round trip | 必须 | `进行中` | 当前 SQLite v1 conversation/message/artifact/assets round trip 已覆盖；未来 branch/run/parts schema 尚未实现 |
| v2 portable export | 必须 | `未开始` | NDJSON/chunk，明确裁剪内容 |
| v2 export → 旧应用 | 仅显式兼容导出 | `未开始` | 不伪装为旧格式 |
| v2 schema 代码回滚 | 必须 | `未开始` | 回滚版本仍能读写当前 v2 schema |
| v2 写入后直接回 `.previous` | 禁止作为无损回滚 | `进行中` | startup gate 仅在业务从未放行的 pre-commit 状态允许 `rollingBack`；`committed` 无回滚边，terminal previous 只归档保留；v2-compatible code rollback 与灰度演练仍未开始 |
| DB schema 高于当前二进制 | 只读/拒绝打开并要求升级 | `未开始` | 禁止 down migration、空库初始化和写入 |

## 14. 性能基线台账

所有“目标”为初始候选 SLO；`重构前` 和 `重构后` 必须记录设备、build mode、数据 seed 和采样方法。

| 数据集/指标 | 设备 | 重构前 | 目标 | 重构后 | 状态 | 证据 |
| --- | --- | ---: | ---: | ---: | --- | --- |
| D2 打开会话 p95 | 待定 | 未测 | <300ms | 未测 | `未开始` | — |
| 50 slot 分页 p95 | 待定 | 未测 | <100ms | 未测 | `未开始` | — |
| UI isolate SQLite calls | 全平台 | 未测 | 0 | 未测 | `未开始` | — |
| 60Hz build+raster p95 | 待定 | 未测 | <12ms | 未测 | `未开始` | — |
| >16.7ms frame 比例 | 待定 | 未测 | <1% | 未测 | `未开始` | — |
| Anchor drift | 待定 | 已知算法错误，未量化 | ≤1 logical px | 未测 | `未开始` | — |
| D4 chunk→visible p95 | 待定 | 未测 | <100ms | 未测 | `未开始` | — |
| D4 DB writes/s | 待定 | 当前逐 chunk，未量化 | ≤4 + final | 未测 | `未开始` | — |
| D3 双向浏览 RSS | 待定 | 未测 | 回落且不单调增长 | 未测 | `未开始` | — |
| D2 搜索 p95 | 待定 | 未测 | <150ms | 未测 | `未开始` | — |
| Backup/restore extra RSS | 待定 | 未测 | 新 SQLite snapshot 为 O(page/chunk)，初始 <32MiB | 未测 | `进行中` | 新默认格式移除全库 JSON；v2 settings 在复制前限制 16 MiB，并以 1 MiB chunk 有界读取，但 JSON DOM 仍需 profile；旧 `chats.json`/迁移 JSON 仍可能全量解码，允许较慢但继续优化 OOM 边界 |
| WAL peak/checkpoint p95 | 全平台 | 未测 | Phase 0 冻结 | 未测 | `未开始` | — |

## 15. 故障注入台账

| Failpoint | 预期有效状态 | 允许损失边界 | 状态 | 实际结果/证据 |
| --- | --- | --- | --- | --- |
| Migration building kill | live 旧库完整 | candidate 未提交工作 | `未开始` | — |
| Candidate validation failure | live 旧库完整 | 无用户数据损失 | `进行中` | `22044e46` 已覆盖 descriptor/manifest 篡改、非 canonical path、settings 超限、非法 SQLite、sidecar、精确拓扑/逐项 hash，并保留 live；尚无磁盘满、目录 fsync 或 kill 验证 |
| Checkpoint/close/fsync kill | live 旧库完整 | candidate 可丢弃/重试 | `未开始` | — |
| live→previous 后 kill | 启动按 receipt 恢复 previous 或继续安装 candidate | 无半库 | `进行中` | previous plan/store 与逐 DB/root operation-ahead rename 已覆盖 rename 后抛异常和 8 个正向逻辑中断点；尚未运行独立进程 kill |
| candidate→live 后首次启动 kill | 校验 new 或回 previous | 尚未提交的 v2 尾部 | `进行中` | 完整 SQLite/settings/assets commit、验证失败 rollback、3 个 rollback 逻辑中断点与 terminal archive 中断通过；尚未运行独立进程 kill |
| v2 已写新消息后代码回滚 | 使用 v2-compatible rollback | 最多一个未 checkpoint stream 尾部 | `未开始` | — |
| Restore 任一阶段 kill | 破坏性切换前旧 live 不变；开始切换后 gate 收敛到完整 new 或经验证 old，绝不放行混合 | 无已放行业务写入 | `进行中` | 同进程 failpoint 覆盖 forward/rollback/terminal archive，未知位置 fail-closed；真实 kill/断电仍未验证 |
| Streaming checkpoint 前 kill | 最后已提交 checkpoint 可读，run interrupted | 一个 checkpoint 窗口尾部 | `未开始` | — |
| Final transaction 中 kill | 完整 streaming checkpoint 或完整 final | 无半 final 状态 | `未开始` | — |
| Cancel/onDone/late chunk 竞态 | 唯一终态且不可回退 | 无已提交内容倒退 | `未开始` | — |
| Disk full during DB/WAL | 当前事务 rollback，错误可见 | 未提交事务 | `未开始` | — |
| Disk full during backup | 旧数据不变，不发布损坏备份 | 临时备份文件 | `未开始` | — |
| Read-only/permission change | 不创建空库，不假成功 | 未提交事务 | `未开始` | — |
| DB/WAL/SHM 损坏/缺失 | 进入只读恢复/诊断 | 不覆盖现场 | `未开始` | — |
| `user_version` 高于二进制支持版本 | 只读/拒绝打开并要求升级 | 不执行任何写入或降级 | `未开始` | — |
| ZIP/manifest/hash 损坏 | 拒绝恢复，live 不变 | staging | `进行中` | DataSync/candidate/receipt/previous 测试覆盖 ZIP 预算、manifest/hash/schema/count/topology 篡改；只读恢复 UI 尚未实现 |
| Receipt 损坏/缺失/sequence 回退 | 进入只读恢复，不按文件名猜测 | 不开放混合 bundle | `进行中` | `7053ea5e` 已覆盖 checksum/hash-chain 损坏、缺口、超限、非法状态与链接目录的 fail-closed journal 读取；只读恢复入口、多个 run 仲裁和真实 kill 尚未实现 |
| 多组 previous/candidate 同时存在 | 根据有效 manifest/receipt 诊断，无法唯一确定则阻塞 | 不自动删除任何候选 | `未开始` | — |
| Duplicate ID/order/version | 确定性报告/隔离，不覆盖 | rejects 中的数据 | `未开始` | — |
| Missing parent/selection | 阻止 active graph 切换 | rejects 中的数据 | `未开始` | — |
| Attachment half copy/missing | DB 与 asset receipt 一致；缺失明确标记 | 未提交 staging asset | `未开始` | — |
| Two desktop processes | 单实例或明确拒绝第二 writer | 无半事务 | `进行中` | macOS 已有真实子进程 business-lease 竞争、拒绝第二 writer 与持有者 kill 后重获证据；Windows/Linux 和业务启动全链路仍待验证 |

## 16. 五平台验证台账

| 验证 | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| `flutter analyze` / unit tests | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Drift schema migration | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| FTS5/tokenizer | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Online Backup API | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| WAL/FULL 实际 PRAGMA | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| File close/rename/fsync | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Kill/restart recovery | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Timeline profile/anchor | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Secure storage/backup boundary | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Build/package ABI | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |

说明：本轮根目录 `flutter analyze` 和 `flutter test` 仅作为当前主机的代码基线，不等于上述五平台目标验证已完成。

## 17. 风险登记

| ID | 风险 | 严重度 | 检测方式 | 缓解/回滚 | 状态 |
| --- | --- | --- | --- | --- | --- |
| R-01 | Branch 产品语义未定导致 schema 返工 | 高 | PD-01/02/04 未批准 | Phase 2 前用交互实例批准 ADR | `未开始` |
| R-02 | SQLite v1 已发布却错误以 Hive 为主源 | 高 | 发布记录/真实用户数据核对 | 先完成 PD-13；source precedence 测试 | `未开始` |
| R-03 | v2 写入后直接回 previous 丢新消息 | 高 | 记录 cutover 后 write epoch | v2-compatible rollback build | `未开始` |
| R-04 | Windows handle/杀软导致 swap 失败 | 高 | Windows failpoint/锁库测试 | 单一连接、关闭 handle、receipt 恢复 | `未开始` |
| R-05 | `synchronous=FULL` 低端设备延迟 | 中 | 五平台 benchmark | 合并 checkpoint；公开记录取舍 | `未开始` |
| R-06 | FTS5 与短中文行为跨平台不同 | 中 | 五平台语料正确率/p95 | capability gate；明确行为 | `未开始` |
| R-07 | Graph ancestry 查询在超长会话退化 | 中 | D3 query plan/benchmark | parent 索引；必要时受控物化 view | `未开始` |
| R-08 | Cache 只限制条目不限制字节再次 OOM | 高 | RSS/cache bytes telemetry | 所有 cache 字节 LRU | `未开始` |
| R-09 | 普通备份继续泄露秘密 | 高 | ZIP 内容审计 | P0-08 + OPS-07 | `进行中`：应用已知认证凭据已排除；自由文本与 secure storage 边界待 OPS-07 |
| R-10 | 测试全绿掩盖需求反例未覆盖 | 高 | 需求矩阵与现有测试 diff | 已补恢复/candidate/rollback 反例；其余按工作项继续先红后绿 | `进行中` |
| R-11 | overwrite 直接依次写 settings/DB/assets 形成混合 bundle | 高 | settings、DB、各资源目录 failpoint 与重启指纹 | 同卷 staging + previous + durable receipt + business lease + 启动恢复 | `进行中`：v2 DataSync 已移除运行期在线覆盖；参与新协议的旧/第二业务进程由 lease 排除，unpublished/forward/rollingBack/terminal 主链已联通；settings 在 native PID 与 lease token 均变化后的冷读确认前持续阻止业务。PID 复用与同 PID stale owner 当前保守 fail-closed；真实 cutover kill/断电、五平台 durability 与升级时旧版本进程退出策略仍开放 |
| R-12 | 受损 Hive 迁移 ZIP 被严格引用校验整体拒绝 | 高 | 缺 message/orphan 的真实旧备份 fixture | Recovered conversation/rejects adapter，保留原始问题报告 | `未开始` |
| R-13 | 旧 `chats.json`/迁移 JSON 全量解码导致 OOM/主 isolate 卡顿 | 高 | 600–800MB legacy fixture 的 RSS/frame profile | 新备份改 SQLite snapshot；legacy adapter 使用 chunk reader 与增量导入 | `进行中` |
| R-14 | ZIP32 与恢复展开边界导致超大备份失败或磁盘耗尽 | 中 | >4GiB compressed、8GiB 单项、16GiB 总展开 fixture | 当前显式拒绝超限并在写出时计数中止；后续评估 Zip64 和按可用磁盘预算 | `进行中` |
| R-15 | terminal evidence 长期占用空间且 previous settings 含旧凭据 | 高 | completed runs 数量/字节/权限审计 | 0700/0600 受限归档；PD-10 明确保留期、成功启动 acknowledgement 与可恢复清理 | `进行中`：active admission 已释放且 evidence 保留；自动 retention/诊断脱敏尚未实现 |

风险状态表示缓解工作状态，不代表风险是否已经发生。P0-01/P0-02 已开始降低部分风险，但尚未满足整包崩溃安全、旧数据恢复和有界内存验收。

## 18. 当前阻塞与待输入

以下事项尚未阻塞 Phase 0 的全部工作，但会阻塞对应阶段进入实现或验收：

1. 确认 SQLite v1 是否已发布及覆盖的 app version（PD-13）。
2. 确认真实 branch 与后代处理语义（PD-01/02）。
3. 确认 interruption、历史位置发送和离底提示 UX（PD-03/04/05）。
4. 指定五平台参考设备、最低支持 OS 和可用 CI runner。
5. 确认旧数据库保留周期、恢复支持流程和清理授权（PD-10/12）。
6. 确认秘密备份、平台安全存储和聊天数据库加密政策（PD-11）。

## 19. 下一步

推荐下一轮只启动 Phase 0，不同时改消息图和 timeline：

1. 收尾 `P0-02` 验收：在已通过真实 business-lease 子进程竞争/kill 的基础上，增加独立 cutover 子进程 kill/重启 harness，覆盖 receipt/full-barrier、每个 DB/root rename、settings partial apply/rollback 与 terminal archive；补磁盘满、只读目录、锁库，并在 Android/iOS/Windows/Linux runner 验证 durability ABI/rename。
2. 按 PD-10/12 设计 completed evidence 的成功启动 acknowledgement、保留周期、脱敏诊断与可恢复清理；在此之前保留受限 evidence，不无记录删除 previous。
3. 启动 `P0-03` 单 writer latest-wins checkpoint + final barrier；同时完成 PD-13 调查和 P0-09 fixture/性能基线。
4. 保留旧 `chats.json` 只读 adapter 与迁移页 JSON 灾难备份；用真实 legacy fixture 做 OOM/坏数据回归。`P0-05` v2 merge 继续安全拒绝，待 PD-09 后单独实现 hash 去重、remap 与 report。

## 20. 变更日志

| 日期 | 变更 | 工作项 | Commit/PR | 作者 |
| --- | --- | --- | --- | --- |
| 2026-07-09 | 将 v2 overwrite 改为 selected-only durable preparation + 启动整包 cutover；实现 business lease、strict topology、bounded previous、WAL normalization、平台 durability、operation-ahead forward/rollingBack、PID+token cold ack/archive、恢复/冷重启/故障 UI 与 DataSync/main 接入；Android 使用 process restart 且失败保留重试；未选 DB/assets 不复制归档，伪 secret-free 在 receipt 前拒绝，旧 JSON 导入和迁移页 JSON 灾备保持兼容 | P0-02、OPS-02/03 | 本里程碑提交 | Codex |
| 2026-07-09 | 创建审计基线、重构方案和进度台账 | AUD-01～06、DOC-01 | `1a75f3da` | Codex |
| 2026-07-09 | 实现恢复错误传播与本地化失败提示；推进 overwrite payload/candidate 预检和 live SQLite 单事务替换 | P0-01、P0-02 | `117f8386` | Codex |
| 2026-07-09 | 冻结正常备份使用 SQLite snapshot ZIP、旧 JSON 只读导入、迁移页灾难备份继续 JSON 的格式边界 | PD-14、OPS-01～03 | `4d810e21` | 用户 / Codex |
| 2026-07-09 | 实现 SQLite Online Backup 一致快照及 WAL/sidecar、重开、integrity/FK/count 验证 | OPS-01、P0-02 | `e179737c` | Codex |
| 2026-07-09 | 正常备份切换为 SQLite snapshot bundle；加入全 entry manifest/hash、自校验、严格新旧分发、DB overwrite round trip 与 ZIP 展开预算；迁移灾备继续 JSON | OPS-01～03、P0-02、P0-05 | `900811ec` | Codex |
| 2026-07-09 | 普通 bundle 排除应用已知认证凭据；secret-free overwrite 清除目标旧凭据；旧 JSON 导入与迁移灾备保留历史设置兼容；v2 merge 在语义完成前安全拒绝 | P0-08、P0-05、OPS-01/07 | `6c3618b8` | Codex |
| 2026-07-09 | 为 v2 overwrite 增加 settings touched-key 异常补偿；覆盖部分写入、DB 调用前失败、旧凭据恢复与无关并发 key 保留；冻结运行期 staging、下次启动 cutover 的实现落点 | P0-02、OPS-02 | `da9d2d13` | Codex |
| 2026-07-09 | 将完整 v2 candidate 复制到 AppData 同卷并重写规范化 manifest；增加链接/junction 防护、跨目录 rename probe、空 assets 根 overwrite 语义，复制/hash 在后台 isolate 完成 | P0-02、OPS-02 | `1460a64c` | Codex |
| 2026-07-09 | 固化 restore receipt canonical codec 与 append-only journal；加入 checksum/hash chain、严格状态跳转、独占 final 创建、有界读取、链接拒绝及进程内/跨进程写入序列化；目录 fsync 与 staging 集成继续后续工作 | P0-02、OPS-02 | `7053ea5e` | Codex |
| 2026-07-09 | 将 candidate workspace 统一为 `run_<128-bit-id>/candidate`，返回规范化 manifest 的实际 SHA-256，并锁定普通失败清理；仍保持当前即时恢复行为，不宣称 prepared/durable | P0-02、OPS-02 | `c28f74cc` | Codex |
| 2026-07-09 | 冻结 normalized manifest descriptor 并严格匹配复制；加入文件 flush、16 MiB settings 前置上限、post-copy settings/SQLite/sidecar/topology/逐项 hash 复验与只读 snapshot inspector；仍不宣称目录 fsync 或 prepared | P0-02、OPS-02 | `22044e46` | Codex |
| 2026-07-09 | 将备份设置的 legacy list 规范化、类型/JSON shape 校验和本地键边界抽为无 I/O 单一实现，供现有导入、candidate 预检与未来启动 gate 共用；旧 JSON 行为保持兼容 | P0-02、OPS-02/03 | `570b6b20` | Codex |
| 2026-07-09 | 在 candidate 返回前执行完整设置语义校验；非法结构在 receipt 发布前拒绝并清理本次 run，不再只检查 `settings.json` 可解析性 | P0-02、OPS-02 | `340a0b0a` | Codex |
| 2026-07-09 | 提取共享 restore workspace lock，并用原子 `.active_run` marker 关闭 POSIX 同进程多 isolate admission 窗口；任意残留/未知 run fail closed；candidate 与初始 receipt 统一执行 manifest/settings/DB/entry/hash/精确目录复验，当前即时恢复 cleanup 改由仲裁执行 | P0-02、OPS-02 | `b232ad8b` | Codex |
| 2026-07-09 | 用 `.active_run → .publishing/.discarding` 同目录原子 rename claim 串行化 POSIX 同进程 worker-isolate 的 publish/discard；prepared 幂等重试增加 candidate+receipts 精确 topology，拒绝 `previous` 等已开始切换残留；cleanup 失败仍保证尝试清理解压目录 | P0-02、OPS-02 | `f33c9019` | Codex |
| 2026-07-09 | 增加 staging→prepared receipt 逻辑协调器；组件选择取用户请求与 bundle 能力交集，发布前失败清理、发布开始后 fail-closed 保留，并保持完整 candidate 供启动恢复；尚未接 DataSync、目录 fsync 或 startup gate | P0-02、OPS-02 | `8b7d0e3a` | Codex |
| 2026-07-09 | 收紧 startup gate 提交边界：`verified` 期间仍禁止业务读写，必须在 `runApp` 前进入 `committed`；提交后 previous 只按独立保留策略清理，不再自动回退，避免恢复后新写入丢失 | P0-02、OPS-02 | `3ed993d9` | Codex |
| 2026-07-09 | 在 `main()` 首次 SharedPreferences、窗口、SandboxPathResolver、Hive/SQLite 和业务 provider 初始化前接入 startup admission gate；用单一 workspace 锁稳定检查 marker/run/receipt/candidate，任何 active run 或异常拓扑均 fail-closed；cutover 执行器仍待实现 | P0-02、OPS-02 | `76241cbc` | Codex |
| 2026-07-09 | 定义 `previous.pending` canonical 计划与 operation-ahead 恢复约束：绑定 prepared/candidate、区分 missing/empty/unselected、逐对象唯一位置验证，并冻结 SharedPreferences touched-key/fingerprint 兼容语义与旧凭据保留风险 | P0-02、OPS-02 | `34585587` | Codex |
| 2026-07-09 | 实现 immutable `previous.pending` plan codec：构造/解析必须绑定真实 prepared receipt，settings snapshot/tombstone/fingerprint 可重算验证，DB 与四资源根区分未选/缺失/空/有内容，并严格拒绝 checksum、类型、路径和组件不一致 | P0-02、OPS-02 | `50529cfe` | Codex |
| 2026-07-09 | 实现纯 settings transition builder：按现有 overwrite/secret policy 推导 touched、旧值 snapshot/tombstone、目标 set/remove 与 before/target fingerprint；保留 local-only 和无关普通 key，拒绝伪 secret-free/非法结构并深冻结 string-list | P0-02、OPS-02 | `575611e7` | Codex |
| 2026-07-09 | 增加可恢复 SharedPreferences adapter：每次读取先 reload，apply/rollback 只接受 touched key 处于 before/target 状态，支持部分写入续跑、同 isolate FIFO 串行及最终 fingerprint 复验；明确不把插件写入宣称为 fsync/断电持久化 | P0-02、OPS-02 | `502130aa` | Codex |
