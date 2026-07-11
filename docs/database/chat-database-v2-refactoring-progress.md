# Kelivo 聊天数据库与消息系统 v2 重构进度

> - 方案基线：[chat-database-v2-refactoring-plan.md](./chat-database-v2-refactoring-plan.md)
> - 追踪基线：分支 `sql`，本轮实现基线 `f7e11373`
> - 最后更新：2026-07-11（Phase 2：MSG-01 已完成）
> - 当前结论：Message Graph 已进入实施，MSG-01 把 PD-01/02/04 冻结为可执行 ADR：稳定 branch/slot/revision ID、真实 ancestor path、旧后代保留、稳定 context boundary、删除不 compact 与 UI/Generation/Timeline 分层边界均已明确。下一项为 MSG-02 graph schema 与数据库不变量

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
| Phase 0：止血与基线 | 9 / 9 | `已完成` | P0-01～P0-09 全部完成；macOS baseline 已冻结，D4 renderer/RSS 超标已显式进入后续工作流 |
| Phase 1：Database Kernel v2 | 8 / 8 | `已完成` | DB2-01～08 全部闭环；五平台 capability runner 5/5 通过 |
| Phase 2：Message Graph | 1 / 7 | `进行中` | MSG-01 ADR 已接受；下一步实现 conversation/branch/slot/revision schema 与约束 |
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
| `flutter analyze` + `flutter test`（本轮 P0-02） | `已完成` | No issues found；1093/1093 tests passed | 2026-07-10 | 当前 macOS 主机全量通过；真实进程矩阵证据见下方独立宿主行，仍不等于硬件断电或其他平台验证 |
| `flutter analyze` + `flutter test`（本轮 P0-03） | `已完成` | No issues found；1100/1100 tests passed | 2026-07-10 | 当前 macOS 主机全量通过；另有 checkpoint writer + repository + stream/controller 定向 31 项通过；按 Phase 0 范围纪律未运行真实进程/断电矩阵 |
| `flutter analyze` + `flutter test`（本轮 P0-04） | `已完成` | No issues found；1107/1107 tests passed | 2026-07-10 | 当前 macOS 主机全量通过；另有 lifecycle/store/repository/service/stream 定向 44 项通过；按 Phase 0 范围纪律未运行真实进程/断电矩阵 |
| `flutter gen-l10n` + `flutter analyze` + `flutter test`（本轮 P0-05） | `已完成` | untranslated `{}`；No issues found；1112/1112 tests passed | 2026-07-11 | merge repository/DataSync 定向 52 项通过；覆盖无冲突、hash 去重、conversation/message ID 冲突整会话 remap、重复导入幂等、非法 order 事务回滚及本机凭据保留；按范围纪律未运行真实进程/断电矩阵 |
| `flutter analyze` + `flutter test`（本轮 P0-06） | `已完成` | No issues found；1121/1121 tests passed | 2026-07-11 | installation gate 定向 9 项通过；覆盖首次安装、旧库 adoption、重复启动、缺库、坏库、未来 schema、坏 receipt、identity 替换/恢复轮换；按范围纪律未运行真实进程/断电矩阵 |
| `flutter analyze` + `flutter test`（本轮 P0-07） | `已完成` | No issues found；1126/1126 tests passed | 2026-07-11 | sandbox path migration 定向 5 项通过；覆盖首次批量迁移、同根零扫描、失败事务回滚/重试、容器根变化重跑和未来 version 拒绝；按范围纪律未运行真实进程/断电矩阵 |
| P0-03 iOS MethodChannel 残留修复 | `已完成` | analyze 通过；iOS background + checkpoint 定向 22 项、P0 快速门禁 49 项、全量 1136/1136 通过 | 2026-07-11 | chunk update 非阻塞入队；原生 update 起始间隔 ≥500ms；在途期间 latest-wins；finish/cancel barrier、错误可观察、非 iOS no-op 均有测试 |
| DB2-01 schema snapshots/migration | `已完成` | analyze 通过；migration/install/snapshot/backup 定向 64 项；全量 1139/1139 通过 | 2026-07-11 | 冻结 v1/v2 JSON snapshot 与生成式 schema helper；逐版本 `migrateAndValidate`、数据保留、磁盘 v1→v2 installation gate、future schema 拒绝均覆盖 |
| DB2-02 async database path | `已完成` | analyze 通过；lazy history/chat/import/backup/stats 定向 111 项；全量 1139/1139；macOS profile probe 通过 | 2026-07-11 | `_syncDb`、同步 repository query/count/search/artifact API 与 raw row mapper 全部删除；业务 SQLite executor 唯一为 `NativeDatabase.createInBackground`；运行时 64 次 SQLite 引擎回调全部 background、opening/UI isolate 0；窗口分页和版本补载均 await，渲染 getter 只读内存，不执行 SQLite |
| DB2-03 single-flight gateway | `已完成` | analyze 通过；gateway/chat/lazy history 定向 31 项；全量 1142/1142 通过 | 2026-07-11 | 3 路并发 acquire 复用同一 repository；引用计数最后释放才 close；异路径拒绝；坏库初始化保留证据并可重试；ChatService init/失败/close/dispose 接入 lease |
| DB2-04 constraints/microsecond/indexes | `已完成` | analyze 通过；migration/constraints/order/snapshot/merge 定向 24 项；全量 1153/1153 通过 | 2026-07-11 | schema v3 冻结；FK/UNIQUE/CHECK、微秒 DateTime converter、稳定 tiebreaker 索引与 EXPLAIN QUERY PLAN 覆盖；v2→v3 秒值换算和三表重建处于同一事务，约束失败保持 v2；删除/版本重排使用两阶段临时 order，删除+压缩处于同一事务，避免唯一约束瞬时冲突与半提交 |
| DB2-05 transactional domain commands | `已完成` | analyze 通过；command/service/version/delete 定向 60 项；全量 1162/1162 通过 | 2026-07-11 | add 原子写 conversation/message/selection/streaming receipt；version 在事务内分配版本并更新 selection；batch delete 原子校验完整目标集、更新 selection/suggestion、级联 artifact 与重排；fork 任一消息失败整会话回滚；final checkpoint 同事务清 active receipt。12 路并发 append order 唯一，并发 version 得到 1/2，并发 selection+append 不丢无关状态；缓存仅在 commit 后替换 |
| DB2-06 identity/session/integrity recovery | `已完成` | analyze 通过；admission/gateway 定向 21 项；全量 1171/1171 通过 | 2026-07-11 | installation identity/receipt 沿用 P0-06；新增 gateway live session receipt，首 lease 发布、最后 lease 在 DB close 成功后清除。unclean/open error/identity mismatch 触发 quick_check/FK/schema/identity，成功才耐久消费；已验证 restore 可在复验新库后消费绑定旧 identity 的 session。missing/corrupt/FK/identity/receipt 异常保留 DB 与 receipt 并进入既有 persistence-free 恢复页。gateway identity 查询仍走后台 Drift，未重引入主 isolate raw SQLite |
| DB2-07 platform capability runner | `已完成` | 五平台 5/5 PASS | 2026-07-11 | 统一 integration runner 实跑 migration、FTS5/unicode61、WAL/FULL、Online Backup、SQLite lock contention、文件锁/full-barrier rename、ABI；macOS/iOS simulator/Android 保留机器可读结果，均为 SQLite 3.53.2。Windows/Linux 由用户在原生环境确认 runner 通过，结构化元数据未回传，未虚构具体 ABI/version；证据见 `docs/database/baselines/db2-07-platform-capabilities-2026-07-11.md` |
| DB2-08 sanitized DB observability | `已完成` | analyze 通过；observer/repository/gateway/migration/command/checkpoint 定向 29 项；全量 1178/1178 通过 | 2026-07-11 | live connection contract 启动断言 WAL/FK/FULL/busy timeout/auto-checkpoint/journal limit；按 operation 有界保存 256 个 latency samples 并计算 p50/p95/max，累计 result/failure；checkpoint 记录 WAL 前后 bytes 与 busy/log/checkpointed。snapshot/event schema 无 SQL、参数、正文、ID、secret 或 path 字段，失败只保留分类与可选数值码；原异常继续上抛 |
| P0-09 fixture/quick gate/macOS profile | `已完成` | D1～D6 full 生成成功；当前快速门禁 analyze + 49 tests；里程碑全量 1130/1130；profile integration passed | 2026-07-11 | seed `20260711`；M4 Pro/macOS 26.5.2；D2 100k、D3 10k slots/10,617 revisions、D4 1 MiB、D5 100×4K + 100 attachments、D6 fault artifacts；profile harness 已加入 DB2-02 execution-isolate 64-sample probe；报告见 `docs/database/baselines/p0-09-macos-m4-pro-2026-07-11.md` |
| `flutter build macos --debug` | `已完成` | Debug `kelivo.app` 构建成功 | 2026-07-10 | 覆盖 main 启动 gate、fail-closed/cold-restart shell、迁移提示 overlay 与桌面窗口接线；其他桌面/移动平台未由本机构建 |
| 迁移、懒加载、滚动、版本选择、重生成上下文、流订阅等定向测试 | `已完成` | 73 tests passed | 2026-07-09 | 只证明现有断言成立，不覆盖审计反例 |
| SQLite bundle/秘密边界/legacy/migration 灾备定向测试 | `已完成` | 55 tests passed | 2026-07-09 | 覆盖 snapshot round trip、manifest/hash/schema/count、秘密清洗、settings 补偿、同卷 staging/链接拒绝/空资源根、v2 merge 安全拒绝、旧 JSON 与迁移灾备兼容 |
| Restore receipt/journal 定向测试 | `已完成` | 24 tests passed | 2026-07-09 | 覆盖 canonical checksum、append-only sequence/hash chain、非法跳转、损坏/超限/缺口拒绝、链接目录拒绝、初始 run/marker/topology/candidate/selection 复验、prepared retry 残留拒绝，以及跨 worker-isolate publish/discard 互斥；不等于目录 fsync 或 kill 验证 |
| Restore candidate/run identity + SQLite 只读复验 | `已完成` | 21 tests passed | 2026-07-09 | 16 个 staging 与 5 个 SQLite inspector 用例覆盖 run ID/固定路径/manifest hash、descriptor/manifest/未知字段篡改、canonical path、16 MiB settings 上限、settings 语义、DB、entry/hash、精确目录/空资源根、普通失败清理，以及 worker-isolate 单 run 仲裁；不等于 startup cutover 或目录 durability |
| Restore workspace lock/admission | `已完成` | 13 direct tests passed | 2026-07-10 | 覆盖同 isolate FIFO、跨进程 advisory lock、action 异常释放、root/lock link 与错误类型拒绝；terminal archive 拒绝三种歧义拓扑。legacy marker 发布严格按 fixed temp create/restrict/write/full barrier/readback→canonical rename/readback；故障注入覆盖 temp durable、canonical published，以及 artifact 已删除但 workspace barrier 失败时本次停止、active terminal 保留并在下一次 markerless 收敛 |
| Restore admission/phase + DataSync 集成回归 | `已完成` | 89 tests passed | 2026-07-09 | `f33c9019` 提交前 workspace lock、staging、receipt、DataSync 四组定向用例通过；覆盖 worker-isolate staging/staging 与 publish/discard 竞态 |
| Restore preparation 协调器 | `已完成` | 5 direct / 47 DataSync tests passed | 2026-07-09 | staging→prepared receipt 已接入 DataSync v2 overwrite；方法返回时 live 设置/DB/assets 不变，只复制用户选择与 bundle 能力交集中的 DB/assets，candidate 与 receipt 组件精确相等；全选仍保留 SQLite 与真实 asset，旧 JSON 路径行为不变 |
| Restore startup gate / terminal archive | `已完成` | 51 direct tests passed；纳入聚焦回归 | 2026-07-10 | 同一 workspace 锁内完成 inspect→claim→forward/rollback→cold readback→terminal archive；除既有正向/回滚中断外，verified canonical + durable `rollingBack` temp 可重复失败后严格收敛。legacy archiving artifact 只有在唯一 active terminal、同 ID completed 缺失、无其他 marker/run/未知项且内容为空或匹配 runId 前缀时才删除并耐久重扫；empty/truncated/full temp 与旧 empty/truncated canonical 可收敛，错误前缀/ID、temp+canonical、非终态均原地 fail-closed。旧 canonical fixture 与 deterministic adapter 不等于外部 SIGKILL/断电证明 |
| Restore previous plan/builder/store + durability | `已完成` | 24 tests passed | 2026-07-09 | 7 plan、8 builder、5 store、4 当前 macOS durability 用例；有界流式 hash、精确 DB/assets topology、immutable previous control、0700/0600、POSIX directory fsync、Apple `F_FULLFSYNC` 与 Windows write-through 实现已接入；Windows/移动端/Linux 尚未运行 |
| Restore live SQLite normalization | `已完成` | 4 tests passed | 2026-07-09 | raw SQLite checkpoint/TRUNCATE、journal DELETE、sidecar 拒绝/消失、main/parent barrier；包含带 WAL committed row 的复制恢复用例，不通过普通业务 repository 执行迁移 |
| Restore settings transition/store/cold ack | `已完成` | 纳入 246 项聚焦回归 | 2026-07-09 | 从 durable plan 重建 before/target、fresh reload、可恢复投影、apply/rollback/fingerprint；canonical cold ack 绑定 run/terminal receipt/expected/native PID/lease token，同 PID 或同 token 均不放行，替换丢失窗口安全回到“需冷启”；SharedPreferences 插件本身不宣称跨平台 fsync |
| Restore operation-ahead mover / cutover integration | `已完成` | 4 mover + 5 full-bundle tests passed | 2026-07-09 | DB、四资源根和 settings 每项只接受 descriptor 可证明的位置；candidate 与 receipt 组件双向精确绑定；完整 SQLite/settings/assets 正向提交与“已安装后验证失败→rollingBack→rolledBack”均回读精确旧/新数据；cutover 原始错误会结构化记录，补偿回滚再次失败时同时保留两组错误/堆栈且 receipt 停在可续跑的 `rollingBack`；committed 等待 cold ack 时 DB/asset 篡改只 fail-closed、不回 previous |
| Restore receipt/workspace protocol | `已完成` | 纳入聚焦回归 | 2026-07-10 | append-only receipt、rollback chain、精确 receipt temp、candidate/receipt 双向绑定、共享锁、operation-ahead claim 与 terminal archive；forward 矩阵对四种 receipt temp/final 共 8 点、rollback 矩阵对 `rollingBack/rolledBack` temp/final 共 4 点执行真实 SIGKILL，两个 terminal projection 各覆盖四个 archive 点。legacy markerless canonical create/write 已替换为 fixed temp→canonical，独立矩阵覆盖 empty restricted/temp durable/published 三点；unpublished later-temp 仲裁与 raw run rename admission 缺陷也已修复。raw write/rename/fsync 与 Windows rename 仍待验证 |
| Restore business lease / unpublished / terminal hardening | `已完成` | 纳入聚焦回归 | 2026-07-10 | 非阻塞进程/跨 isolate lease、真实子进程竞争与 kill 后重获；gate 在 lease 冲突时不触碰 prepared/live；terminal cold ack 要求 native PID 与 token 均变化。两个 terminal projection 的 cold-ack SIGKILL 均覆盖 temp/published；独立 settings-readback 2/2 又证明 committed/target 与 rolledBack/before 的真实混合设置可由新 PID/token 冷读修复、轮换 ACK，再由下一 Runner 零写归档。其他平台待验证 |
| macOS forward restore process SIGKILL harness | `已完成` | 25/25 强类型 failpoint；100 个成功 Runner phase；25 次外部 SIGKILL；13/13 support tests | 2026-07-09 | forward control v2 提供 smoke/core/full、`--failpoint` 与 `--from`；每 case 独立 scenario/prefix/AppData/run，由四个真实 Runner 完成 setup→kill→resume→cold finalize。25 个 case 来自跨 core 分段与 full-only targeted 成功运行，不记作一次单命令 full run；覆盖 claim、normalize final barrier、previous、DB/四 roots、四种 receipt temp/final、settings 部分态与 candidate 安装 |
| macOS committed terminal restore SIGKILL harness | `已完成` | 6/6 强类型 failpoint；24 个成功 Runner phase；6 次外部 SIGKILL；13/13 support tests | 2026-07-09 | terminal control v1 的一次完整 `--scenario=terminal` 运行耗时 673.925 秒；每 case 独立 scenario/prefix/AppData/run，并由四个 Runner 完成 setup→commitToColdAck→recoverTerminal→verifyBusinessReady。cold ACK 两点在 R2 kill；archive 四点由 R2 正常发布 ACK、R3 kill、R4 恢复。覆盖 ACK temp/publish、completed root、archiving marker、terminal run archive、marker durable removal；最终严格回读 receipt/ACK/previous/settings/DB/assets/sidecar/PID/token。oracle 收紧后另以 exact case 重跑 ACK temp（118.264 秒）和 ACK published（111.517 秒）均通过，重复运行不计入主口径；显式 settings 部分态由独立 readback matrix 覆盖。高层 hook仍不证明 raw durability、硬件断电或其他平台 |
| macOS verified-origin rollback restore SIGKILL harness | `已完成` | 18/18 强类型 failpoint；72 个成功 Runner phase；18 次外部 SIGKILL；15/15 control/hooks tests | 2026-07-10 | rollback control v1 的四阶段为 setup→triggerRollbackKill→recoverToColdAck→verifyBusinessReady；覆盖 `rollingBack` receipt temp/final、DB 反向移动与 previous/database parent barrier、四个资源根各自反向移动、settings first/secret/target-only tombstone、`rolledBack` receipt temp/final。首轮在第 13 点执行期间被交互中断，只有前 12 点具有明确 PASS；随后用 `--scenario=rollback --from=previousFontsRestoredToLive` 完整通过余下 6/6，因此按 12+6 分段证据记账，不宣称一次未中断 full。每点 R3 mutation>0 且用新 PID/token 到达 `rolledBack/before` ACK，R4 拒绝任何 settings mutation 并零写归档；`rollingBack` temp case 必须再次制造 verified failure，不能自然前向 commit。高层 hook 不证明 raw syscall、断电、missing/empty/unselected previous、其他 rollback 起点或其他平台 |
| macOS rolledBack/before terminal restore SIGKILL harness | `已完成` | 6/6 projection-case；24 个成功 Runner phase；6 次外部 SIGKILL；3/3 control tests；44/44 combined control/hooks tests | 2026-07-10 | `rolledBackTerminalRecoveryMatrix` control v1 的一次未中断完整 `--scenario=rolledback-terminal` 运行耗时 728.342 秒；每 case 独立 scenario/prefix/AppData/run，由四个 Runner 完成 setup→rollbackToColdAck→recoverTerminal→verifyBusinessReady。复用 terminal 六个物理高层边界：ACK 两点由 R2 kill，temp 的 R3 mutation>0 且必须轮换 ACK，published 的 R3 零写归档；archive 四点由 R2 正常发布 before ACK、R3 拒绝 settings mutation 并在边界 kill；R4 对六点均零写复验 archived/business-ready、旧 bundle live、新 bundle candidate、previous 仅余 control evidence。显式 before 混合态由独立 readback matrix 覆盖；高层 hook仍不证明 raw durability、硬件断电、其他 rollback 起点或其他平台 |
| macOS legacy archiving marker SIGKILL harness | `已完成` | 3/3 强类型 failpoint；12 个成功 Runner phase；3 次外部 SIGKILL；79/79 相关 direct tests | 2026-07-10 | `legacyArchivingMarkerRecoveryMatrix` control v1 的一次未中断完整 `--scenario=legacy-archiving-marker` 运行耗时 381.084 秒；每 case 以四个隔离 Runner 完成 setup→commitToColdAck→killLegacyMarkerPublish→verifyBusinessReady，覆盖 temp 权限收紧后为空、temp 完整内容 full barrier、temp→canonical `renameAndSync` 返回后三点。R3/R4 均拒绝 settings mutation，R4 在恢复前先复验现场，再验证原 ACK、committed receipt、installed bundle 与 archived/business-ready。裸同名 `--failpoint=archivingMarkerPublished` 另以 120.107 秒通过并确认仍路由到 `terminalRecoveryMatrix`，不重复计入 12 phases/3 kills。旧 canonical 空/截断只有 fixture 单测，raw write/rename 内部窗口、断电和其他平台未覆盖 |
| macOS terminal settings cold-readback process harness | `已完成` | 2/2 projection-case；8 个成功 Runner phase；0 次 SIGKILL；4/4 control tests | 2026-07-10 | 独立 `terminalSettingsReadbackRecoveryMatrix` control v1 的一次完整 `--scenario=settings-readback` 运行耗时 244.594 秒。R2 分别持久化 committed/target 与 rolledBack/before 的真实 before/target 混合设置并正常退出；R3 新 PID/token 首次 reload 即复验混合态，必须有写修复、轮换 ACK、保持 active 并要求再冷启；R4 新 PID/token 以 mutation rejector 零写复验并归档。该场景证明跨进程 cold readback/repair，不是 settings raw write kill 或断电证据 |
| Restore terminal milestone 定向回归 | `已完成` | 89 tests passed | 2026-07-09 | workspace lock 10、startup gate 39、cold ACK 14、forward support 13、terminal control/hooks 13；覆盖 happy path、拓扑歧义、故障恢复、严格 schema/PID/token 绑定及 mutation guard/counter |
| Restore legacy archiving marker milestone 定向回归 | `已完成` | 79 tests passed | 2026-07-10 | workspace lock 13、startup gate 51、legacy control 3、terminal/legacy durability hooks 12；覆盖 happy path、空/截断/完整 artifact、错误前缀/ID、碰撞、非终态、delete 后 barrier 失败、fixed temp 发布边界、严格 control schema/path/PID/lease/ACK 与 settings 零写入 |
| P0-02 final topology/control regression | `已完成` | 29 tests passed | 2026-07-10 | 5 组 process control 20 项保持统一 dispatcher 兼容；cutover executor 9 项中新增 4 项，覆盖 selected DB 的旧 live family missing commit/rollback，以及 settings-only 下既有 main/WAL/SHM/journal 与四类 asset roots byte/hash/拓扑完全不变 |
| Restore rollback milestone 定向回归 | `已完成` | 68 tests passed | 2026-07-10 | rollback control/hooks 15、forward support 13、startup gate 40；覆盖四阶段/18 点严格 schema、exact-set failure、post-failure blockers、DB parent matcher、receipt/ACK sequence，以及 verified + stale rollingBack temp 的重复失败收敛。前向 smoke 在夹具 v3 首次复验时发现并修正 target-only oracle 的矛盾断言，随后通过；terminal `coldAckPublished` exact case 同步通过 |
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

# Terminal harness regression (26 tests: support 13 + control/hooks 13).
flutter test \
  test/core/services/backup/restore_process_harness_support_test.dart \
  test/core/services/backup/restore_terminal_process_control_test.dart \
  test/core/services/backup/restore_terminal_process_hooks_test.dart

# Rollback milestone regression (68 tests).
flutter test \
  test/core/services/backup/restore_rollback_process_control_test.dart \
  test/core/services/backup/restore_rollback_process_hooks_test.dart \
  test/core/services/backup/restore_process_harness_support_test.dart \
  test/core/services/backup/restore_startup_gate_test.dart

# Rolled-back terminal control compatibility regression (44 tests). The new
# control has 3 direct tests and reuses the existing terminal/rollback hooks.
flutter test \
  test/core/services/backup/restore_rolled_back_terminal_process_control_test.dart \
  test/core/services/backup/restore_rollback_process_control_test.dart \
  test/core/services/backup/restore_rollback_process_hooks_test.dart \
  test/core/services/backup/restore_terminal_process_control_test.dart \
  test/core/services/backup/restore_terminal_process_hooks_test.dart \
  test/core/services/backup/restore_process_harness_support_test.dart

# Legacy archiving marker atomic publish/startup arbitration regression
# (79 tests: workspace 13 + startup 51 + control 3 + hooks 12).
flutter test \
  test/core/services/backup/restore_workspace_lock_test.dart \
  test/core/services/backup/restore_startup_gate_test.dart \
  test/core/services/backup/restore_terminal_process_hooks_test.dart \
  test/core/services/backup/restore_legacy_archiving_marker_process_control_test.dart

# macOS only; default is the core tier. Every selected failpoint gets an
# independent scenario and four isolated RestoreHarness Runner processes.
dart run tool/run_restore_process_harness.dart --tier=smoke
dart run tool/run_restore_process_harness.dart --tier=core
dart run tool/run_restore_process_harness.dart --tier=full
dart run tool/run_restore_process_harness.dart \
  --failpoint=candidateDatabaseMoved
dart run tool/run_restore_process_harness.dart \
  --tier=full --from=newInstalledReceiptTempDurable

# macOS only; six isolated committed/target cold-ack and archive cases.
dart run tool/run_restore_process_harness.dart --scenario=terminal

# macOS only; 18 isolated verified-origin rollback cases. Resume accepts the
# first remaining rollback failpoint after an interrupted host invocation.
dart run tool/run_restore_process_harness.dart --scenario=rollback
dart run tool/run_restore_process_harness.dart \
  --scenario=rollback --from=previousFontsRestoredToLive

# macOS only; the same six physical terminal boundaries projected from the
# rolledBack/before state. A bare terminal failpoint keeps committed semantics.
dart run tool/run_restore_process_harness.dart --scenario=rolledback-terminal
dart run tool/run_restore_process_harness.dart \
  --scenario=rolledback-terminal --failpoint=coldAckPublished
dart run tool/run_restore_process_harness.dart \
  --scenario=rolledback-terminal --from=completedRunsRootDurable

# macOS only; three isolated legacy markerless terminal publish boundaries.
# The same bare failpoint name below remains a committed terminal route.
dart run tool/run_restore_process_harness.dart \
  --scenario=legacy-archiving-marker
dart run tool/run_restore_process_harness.dart \
  --scenario=legacy-archiving-marker \
  --failpoint=archivingMarkerEmptyRestricted
dart run tool/run_restore_process_harness.dart \
  --failpoint=archivingMarkerPublished

# macOS only; two normal-exit process cases for explicit terminal settings
# before/target mixtures. This scenario performs no SIGKILL.
dart run tool/run_restore_process_harness.dart \
  --scenario=settings-readback
```

### 4.2 尚未执行

| 验证 | 状态 | 未执行原因 | 风险 |
| --- | --- | --- | --- |
| Android/iOS/Windows/Linux profile 与 RSS/frame/DB/WAL 基线 | `未开始` | P0-09 已完成当前 M4 Pro/macOS profile；其余四平台尚无 profile 数据 | macOS 结果不能外推；继续作为各阶段性能与五平台发布门禁 |
| Android/iOS/macOS/Windows/Linux 五平台能力验证 | `进行中` | macOS 主机、iOS simulator、Android 11 arm64 物理设备 3/5 runner 已通过；Windows/Linux 待运行 | 已验证三平台 FTS5、Backup API、rename barrier 与 SQLite ABI；不能外推 Windows/Linux |
| kill -9/断电/磁盘满/权限/锁库故障注入 | `进行中` | macOS 已完成 25 个 forward、两个 terminal projection 各 6 个、18 个 verified-origin rollback 与 3 个 legacy archiving marker 独立 Runner SIGKILL case；其余 rollback 拓扑、raw write/rename/fsync/F_FULLFSYNC、旧 canonical 空/截断的真实进程场景和资源故障尚未覆盖 | 已证明列明的高层 forward/cold-ack/archive/rollback/legacy marker durability 边界可跨真实进程 SIGKILL 收敛；仍不能宣称硬件断电、任意子步骤、所有 rollback 拓扑或五平台安全 |
| 真实旧 Hive/SQLite v1/备份 fixture 全矩阵 | `未开始` | fixture 尚未整理 | 不能证明已发布数据可无损迁移 |
| 稳定 slot + localDy 的 widget/integration test | `未开始` | 目标 timeline 尚未实现 | 当前列表跳动问题无自动化保护 |

## 5. 产品与架构决策登记

所有决定完成后应填写“最终决定、日期、负责人/批准记录”。

| ID | 决策 | 当前推荐 | 状态 | 阻塞工作项 | 最终决定/证据 |
| --- | --- | --- | --- | --- | --- |
| PD-01 | 多版本是否采用真实分支 | 真实分支；旧未来保留在旧 branch | `已完成` | MSG-01～07 | 2026-07-10 冻结：真实分支；版本切换即 branch head 切换，`< n/m >` 控件；对齐 ChatGPT/Claude 语义。详见方案 §5.1 |
| PD-02 | 编辑、重生成、删除 revision 后的后代策略 | 新建/切换 branch，旧后代延迟 GC | `已完成` | MSG-01、MSG-04 | 2026-07-10 冻结：编辑/重生成创建新 branch，不物理删除旧后代；删除为显式操作（删当前选中版本自动切最新剩余；删 slot 最后 revision 提示连带后代）；延迟批量 GC。详见方案 §5.1 |
| PD-03 | 中断输出的展示和重试策略 | 保留 partial，显示 interrupted，可重试/删除 | `已完成` | GEN-01～07 | 2026-07-10 冻结：保留 partial + "已中断"标识 + 重新生成/删除；不做"继续生成"（provider 续写不可靠，列为 v2 后评估）。详见方案 §5.1 |
| PD-04 | 在历史位置发送时的交互 | 创建 branch，不强制立即跳底部 | `已完成` | MSG-01、TL-03/04 | 2026-07-10 冻结：发送永远追加到 active leaf 并 programmaticJump 把新 user 消息置于 viewport 顶部附近；编辑历史消息走分支语义并保持原锚定。详见方案 §5.1/§7.4 |
| PD-05 | 离开底部时的新内容提示 | 保持 anchor，显示“有新内容” | `已完成` | TL-04、TL-08 | 2026-07-10 冻结：绝不违背用户意图移动 viewport；滚动/选择文本/键盘/链接/搜索均退出尾随；"跳到最新"胶囊 + 流式指示；重开会话定位最后一条 user 消息。详见方案 §5.1/§7.4 |
| PD-06 | 搜索当前 branch 还是全部 revision | 默认当前 branch，可显式扩大范围 | `已完成` | OPS-04 | 2026-07-10 冻结：默认 active branch，显式"包含所有版本"开关；结果携带 branch/revision identity。详见方案 §5.1 |
| PD-07 | 统计当前 branch 还是全部版本 | 分开呈现 active usage 与 total generation usage | `已完成` | OPS-05 | 2026-07-10 冻结：默认 active branch 口径，同页另列全部生成消耗，两口径注明定义。详见方案 §5.1 |
| PD-08 | 完整备份是否含失败/中断 revision 和全部 branch | 完整备份包含，便携导出可裁剪 | `已完成` | OPS-01～03 | 2026-07-10 冻结：完整备份含全部 branch/revision/run；便携导出默认 active branch + completed，可选全量。详见方案 §5.1 |
| PD-09 | restore merge 的同 ID 冲突规则 | hash 相同去重，不同则 remap + report | `已完成` | P0-05、OPS-02/03 | 2026-07-10 冻结：hash 相同去重；不同则导入侧整会话 remap 新 ID + 用户可见冲突报告；绝不静默覆盖。详见方案 §5.1 |
| PD-10 | 旧 DB 保留期与清理授权 | 至少一次成功启动 + 明确保留周期 | `已完成` | DB2-06、OPS-08/09 | 2026-07-10 冻结：≥3 次成功冷启动且 ≥30 天双条件；清理前可导出诊断包；清理写 retention receipt。详见方案 §5.1 |
| PD-11 | 聊天 DB 加密和秘密导出政策 | 独立评估；普通备份排除秘密是无需等待该决定的安全底线 | `已完成` | OPS-07 | 2026-07-10 冻结：v2 不引入应用层 DB 加密，依赖平台沙箱；凭据迁入安全存储（OPS-07）；SQLCipher 列为 v2 后独立评估。详见方案 §5.1 |
| PD-12 | 损坏数据恢复体验 | 只读恢复页 + rejects/脱敏诊断包 | `已完成` | DB2-06、OPS-02 | 2026-07-10 冻结：只读恢复页 + 诊断摘要 + 脱敏诊断包/rejects 导出 + 用户显式选择恢复或继续；绝不静默建空库。详见方案 §5.1 |
| PD-13 | SQLite v1 是否已发布给真实用户 | 以发布事实为准；若已发布，v1 为主源 | `已完成` | P0-09、DB2-01、MSG-05 | 2026-07-10 以 git 证据核实：全部发布 tag（≤`v1.1.17`）与 `origin/master`/`origin/beta` 均无 drift/sqlite 依赖，v1 仅存在于未发布开发分支。公开迁移主源为 Hive → v2；v1→v2 仅开发机尽力迁移；不再向用户发布 v1。详见方案 §5.1/§9.1 |
| PD-14 | 正常完整备份的聊天主数据格式 | SQLite 一致快照 ZIP；不再写 `chats.json` | `已完成` | P0-02、OPS-01～03 | `4d810e21`；2026-07-09 用户确认，旧 JSON 只读导入，迁移页灾难备份继续 JSON |

## 6. Phase 0：止血与基线

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| P0-01 | 恢复错误向上传播，移除假成功 | 无 | `已完成` | 任一聊天/设置/资源失败时 provider 返回失败且 live 数据不被误报成功 | `117f8386`（2026-07-09） | `flutter analyze`；`flutter test`（801）；相关定向 34 项通过 |
| P0-02 | overwrite staging restore | 无 | `已完成` | 运行期 durable prepare 不改 live；下次启动在业务放行前收敛为完整新 bundle 或经验证旧 bundle，并跨冷启动确认 settings | 既有提交 + 本里程碑提交（2026-07-10） | DataSync v2 只生成同卷 selected-only candidate + prepared receipt；main/gate 持有 business lease，经 operation-ahead forward/rollingBack、PID+token cold ack 和 terminal archive 收敛。macOS 25/25 forward、两个 terminal projection 各 6/6、verified-origin rollback 18/18、legacy marker 3/3 共 232 phases/58 kills；settings readback 2/2 再增加 8 个正常 Runner phase，证明两种 terminal projection 的真实混合设置可跨进程修复、轮换 ACK、再冷启并零写归档。selected missing DB 与 unselected main/WAL/SHM/journal/assets 的 commit/rollback 回归通过。应用层验收完成；raw syscall/断电/资源故障/其他平台继续由 OPS-02、DB2-07、P0-09 和发布门禁追踪，不视为已验证 |
| P0-03 | 单 writer latest-wins checkpoint + final barrier | 无 | `已完成` | 网络不等待 SQLite/MethodChannel；≤4 DB writes/s + final；旧 checkpoint/update 不可越过终态 | `09b27d41` + 本残留修复提交（2026-07-11） | content/reasoning/tool events 合为完整事务快照；SQLite writer 使用 250ms 起始间隔与 final barrier。iOS background update 另用 500ms 单 writer latest-wins：chunk 同步入队后立即恢复网络订阅，在途 Channel 期间只保留最新 token，finish/cancel 先 flush 再发终态，失败回调可观察；非 iOS 保持 no-op。原 P0-03 全量 1100 项；本修复定向 22 项、P0 快速门禁 49 项、全量 1136 项与 analyze 通过 |
| P0-04 | prepare/cancel/stale streaming 收尾 | 无 | `已完成` | prepare failure、off-window cancel、重启均无永久 loading | 本里程碑提交（2026-07-10） | send/regenerate/tool continuation 的 prepare 异常统一把 placeholder、notifier、loading 与持久 flag 收尾；会话级 active message store 使取消不依赖分页窗口，并阻止取消后的旧 prepare 重启；冷启动以单事务清除所有 stale flag 与 tracking metadata，失败向上抛。`flutter analyze`；`flutter test`（1107）；相关定向 44 项通过 |
| P0-05 | 事务化 merge ID/order 与冲突诊断 | PD-09 | `已完成` | merge 不生成重复 ID/order；冲突有报告和确定性处理 | 本里程碑提交（2026-07-11） | SQLite snapshot 以 ATTACH + 单事务按会话处理；逻辑 hash 相同去重，不同内容或任一 message ID 冲突时确定性整会话 remap，关联 group/version/tool/signature 同步映射，非法 order/FK 失败整体回滚，重复导入幂等。移动端、桌面本地/WebDAV/S3 均显示 imported/deduplicated/remapped 报告；secret-free settings merge 保留本机凭据。`flutter analyze`；`flutter test`（1112）；merge/DataSync 定向 52 项通过 |
| P0-06 | DB identity/installation receipt 与安全拒绝 | 无 | `已完成` | 既有 DB 缺失/损坏/版本过新时不自动创建或写入空库 | 本里程碑提交（2026-07-11） | `database_identity_v1` UUID 与 installation receipt 在 `runApp(MyApp)` 前匹配；旧库无 receipt 时只在完整只读校验后 adoption，首次安装才创建新库。已有 receipt 时 missing/corrupt/identity missing or mismatch/future schema/坏 receipt 全部进入 persistence-free 恢复页；verified restore 先耐久发布新 identity receipt、再清理旧 receipt并保留 installation ID。`flutter analyze`；`flutter test`（1121）；定向 9 项通过 |
| P0-07 | sandbox path migration version 化 | 无 | `已完成` | 正常启动不扫描全库；migration 幂等且失败可见 | 本里程碑提交（2026-07-11） | receipt 绑定 migration version + 当前 AppData root；同版本同根在任何 message SELECT 前返回。首次/根变化使用稳定 ID cursor、360 条批次仅扫描含 image/file marker 的候选行，在同一事务更新内容并最后写 receipt；rewrite/receipt 异常整体回滚并上抛，未来 version fail-closed。`flutter analyze`；`flutter test`（1126）；定向 5 项通过 |
| P0-08 | 普通备份排除秘密 | 无 | `已完成` | ZIP 默认不含应用已知 API key/password/token；secret-free overwrite 清理目标旧凭据；旧 JSON/迁移灾备兼容明确 | `6c3618b8`（2026-07-09） | `flutter analyze`；`flutter test`（820）；相关定向 50 项通过；manifest 标记 `secretsIncluded: false`，结构化 provider/search/TTS/MCP/WebDAV/S3/assistant 与 URL 凭据均覆盖 |
| P0-09 | 基准生成器、legacy fixture 与性能基线 | PD-13 | `已完成` | D1～D6、参考设备、before metrics 和 failpoint harness 可重复 | 本里程碑提交（2026-07-11） | 固定 seed `20260711` 生成 D1～D6 与 deterministic digest；D6 含 orphan/重复 order-version/坏 JSON/缺附件/截断 WAL-ZIP/legacy JSON 缺引用。`run_p0_regression.dart` 当前一键 analyze + 49 项 P0 快速测试；里程碑全量 1130 项通过；macOS profile 记录 SQL/query/WAL/frame/RSS。重构前没有同 harness 可比数值，报告保留为“未测”而不伪造；当前结果成为后续 before baseline。详见独立报告 |

推荐实施顺序：

1. 为 P0-01/P0-02 写会失败的恢复测试和 staging 骨架。
2. 完成 P0-01，立即消除假成功。
3. 完成 P0-03/P0-04，解除输出与数据库的逐 chunk 串联。
4. 冻结 P0-09 基线，作为后续阶段的回归门槛。

## 7. Phase 1：Database Kernel v2

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| DB2-01 | Schema snapshots 与逐版本 migration tests | PD-13、P0-09 | `已完成` | v1→每个 v2 版本 migrateAndValidate | 本里程碑提交（2026-07-11） | `drift_schema_v1/v2.json` + 生成式 step/schema helper；v1→v2 显式格式边界，物理表在 DB2-04 前保持一致；installation gate 只迁移完整校验通过的 1..current，未来/过旧/损坏 schema 拒绝。定向 64 项、全量 1139 项与 analyze 通过 |
| DB2-02 | 删除 `_syncDb` 和同步数据库 API | P0-03 | `已完成` | profile 中 live DB 的 UI isolate SQLite 调用为 0 | 本里程碑提交（2026-07-11）+ profile 补证 | 删除第二个 raw handle、全部同步 repository query/count/search/tool/signature API 与 sqlite row mapper；聊天分页/完整上下文/版本组、全局搜索、统计、导入/merge 改走后台 Drift Future，UI 同步 getter 仅访问已加载内存。macOS profile 通过生产 `AppDatabase.open` 的 SQLite direct-only callback 采样 64 次，opening/UI isolate 0、background 64；静态通路审计与运行时证据对齐。恢复/备份专用 raw SQLite 继续隔离在 maintenance API，其 isolate/RSS 预算由 OPS-02/发布门禁验证 |
| DB2-03 | 单一 gateway、single-flight init、异步 DAO | DB2-02 | `已完成` | 应用内只有一个受控数据库通路 | 本里程碑提交（2026-07-11） | `ChatDatabaseGateway.instance` 是 live DB 唯一入口；同 canonical path 的并发 acquire 与 ChatService init single-flight，lease 引用归零后串行关闭，关闭期间新 acquire 等待，持有 lease 时拒绝另一 DB；open/init 失败关闭 handle、清除 flight 后可重试且不覆盖坏文件。candidate/restore 保持明确 maintenance API。定向 31 项、全量 1142 项与 analyze 通过 |
| DB2-04 | FK/UNIQUE/CHECK/微秒时间/索引 | DB2-01 | `已完成` | schema 强制领域不变量；query plan 使用索引 | 本里程碑提交（2026-07-11） | schema v3 对 conversation/message/MCP 数值、role、order、group-version、ordinal 强制 CHECK/UNIQUE/FK；时间按 epoch 微秒无损往返，v2 秒时间原子换算；会话、消息时间、版本组查询均由 EXPLAIN 证明使用稳定复合索引；两阶段 order 改写与删除事务避免短暂 UNIQUE 冲突/半提交。逐版本 migration、失败原子性、约束 happy/boundary/error、order/snapshot/merge 定向 24 项，全量 1153 项与 analyze 通过 |
| DB2-05 | 事务化领域 commands | DB2-03/04 | `已完成` | send/version/delete/fork 等不再由 service 拼多步提交 | 本里程碑提交（2026-07-11） | repository 提供 add/version/selection/batch-delete/fork/final-checkpoint 原子 commands；service/controller 不再自行执行 order/version MAX、selection JSON RMW、逐条批删或先建空 fork。覆盖 happy/boundary/failure、12 路并发 append、2 路并发 version、selection+append 无丢更新、append/fork 约束失败全回滚、partial delete 目标全回滚、artifact/receipt 一致性；定向 60 项、全量 1162 项与 analyze 通过。user+assistant+generation run 的跨消息原子 begin send 按方案留给 GEN-01/02，不在 DB2-05 预造状态机 |
| DB2-06 | DB identity、receipt、integrity/recovery | P0-06、DB2-03 | `已完成` | unclean/missing/corrupt DB 进入确定性恢复流程 | 本里程碑提交（2026-07-11） | P0-06 installation identity/receipt 保持；gateway 首个 live lease 以受限权限、full barrier、rename 发布 session receipt，最后 lease 关闭 DB 后才耐久删除。unclean、open error 与 identity mismatch 执行 quick_check、FK、schema、identity 复验，正常启动不全库扫描；授权 restore 仅在新库复验并确认旧 session 绑定旧 installation receipt 后消费旧 session。损坏/缺失/不匹配均保留证据并路由既有只读恢复入口。happy/boundary/failure/state transition 定向 21 项、全量 1171 项与 analyze 通过 |
| DB2-07 | 五平台 SQLite/FTS/Backup/文件能力 | DB2-03 | `已完成` | 五平台能力矩阵有实际运行证据 | 本里程碑提交（完成，2026-07-11） | 设备内统一 runner 已落地并在五平台 5/5 通过；macOS arm64 真实主机、iOS arm64 simulator 与 Android 11/API 30 `android_arm64` 物理设备保留机器可读 PASS 结果，均为 SQLite 3.53.2，migration/FTS5/WAL+FULL/Online Backup/锁/full-barrier rename 通过。Windows/Linux 由用户在原生环境确认同一 runner 通过，原始结构化行未回传，因此不猜测 ABI/version/source ID/短中文数值。Android app NDK 已对齐 28.2.13676358；短中文策略继续由 OPS-04 负责。详见 [DB2-07 平台证据](./baselines/db2-07-platform-capabilities-2026-07-11.md) |
| DB2-08 | DB/query/WAL/checkpoint 脱敏观测 | DB2-03 | `已完成` | 可测 p50/p95、WAL 和失败，不记录正文/秘密 | 本里程碑提交（2026-07-11） | `ChatDatabaseObserver` 按固定 operation 枚举做 O(1) 有界聚合，每 operation 最多 256 个耗时样本，snapshot 计算 p50/p95/max/result/failure；query window/search、transaction command、stream/final checkpoint、gateway open、integrity 和 WAL checkpoint 已接线。WAL 记录 before/after bytes、busy/log/checkpointed 与失败；失败仅分类为 sqlite/remoteDatabase/filesystem/state/input/unknown 和数值码，原异常不吞。live gateway 启动断言连接 PRAGMA，并移除未获基准支持的 read pool。秘密/path/SQL/参数反例通过；定向 29 项、全量 1178 项、macOS/iOS capability 与 analyze 通过 |

## 8. Phase 2：Message Graph

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| MSG-01 | 批准 branch 语义与 ADR | PD-01/02/04 | `已完成` | 产品示例与数据语义无歧义 | 本里程碑提交（2026-07-11） | [ADR-0001](./adr/0001-message-graph-branch-semantics.md) 已接受；覆盖发送、assistant 重生成、user 编辑、稳定 ID 切版本、三类删除、fork 与 context boundary，并明确 repository/projector/UI/Generation/Timeline 边界 |
| MSG-02 | Conversation/Branch/Slot/Revision schema | DB2-04、MSG-01 | `未开始` | parent/branch/slot 不变量由 FK/CHECK/事务强制 | — | — |
| MSG-03 | Active path projector 与 context boundary | MSG-02 | `未开始` | prompt 只含真实 ancestor path | — | — |
| MSG-04 | Edit/regenerate/select/delete/fork commands | DB2-05、MSG-03 | `未开始` | 全部使用稳定 revision/branch ID 且单事务；删除不得复用 `_rewriteMessageOrder` 或全会话 compact，D3 删除更新量不得随会话总消息数线性增长 | — | 旧 v1 删除仍以两阶段更新把全会话重写为 `0..n-1`，只作为 UNIQUE 约束下的过渡实现；消息图不得继承该语义 |
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
| OPS-02 | Staging restore/merge + crash-safe bundle swap | P0-02、DB2-06/07 | `进行中` | DB/settings/assets 切换时阻止业务访问，receipt 恢复后只开放完整旧/新 bundle | 既有提交 + 本里程碑提交 | P0-02 应用层 overwrite 已完成 selected-only candidate、business lease、strict topology、receipt、bounded previous、WAL normalization、operation-ahead forward/rollback、cold ack/archive/startup UI，以及 selected missing/unselected payload 与两种 terminal settings 部分态回归。macOS 真实进程累计 240 phases/58 kills。OPS-02 仍承担 v2 merge、其他 rollback topology 的外部 kill、raw durability、旧 canonical 空/截断进程场景、硬件断电、资源故障与五平台发布验证，因此自身保持进行中 |
| OPS-03 | 旧 JSON 只读 adapter + 显式 portable NDJSON v2 | MSG-05、OPS-01 | `进行中` | 新完整备份不写 `chats.json`；旧 ZIP/迁移 JSON 可导入且尽力保持有界内存 | `117f8386`、`900811ec` | 新备份不再用 JSON 承载聊天主数据；manifest/settings 仍为 JSON，旧 `chats.json` 和无 manifest settings-only 导入仍可用；Recovered/rejects、单次解析 candidate 与流式 parser 未完成 |
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
| 默认 SQLite snapshot ZIP → 当前应用 | 必须 | `进行中` | 已覆盖生成后自校验、hash/size/schema/count 拒绝、normalized candidate、运行期 prepare、下次启动完整 SQLite/settings/assets commit 或 rollback；macOS 25 个 forward、两个 terminal projection 各 6 个与 18 个 verified-origin rollback 高层 durability case 均可从真实 SIGKILL 恢复，其余 rollback topology、raw 子窗口、硬件断电和五平台尚未验证 |
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
| D2 打开会话 p95 | M4 Pro/macOS profile 起点 | 未测 | <300ms | SQL open50 0.263ms；完整页面未测 | `进行中` | P0-09 报告；不得把 SQL 值当页面值 |
| 50 slot 分页 p95 | M4 Pro/macOS profile 起点 | 未测 | <100ms | D2 SQL 0.263ms；D4 大行 2.854ms | `进行中` | P0-09 报告；timeline cursor 未实现 |
| UI isolate SQLite calls（live DB） | M4 Pro/macOS profile | 未测 | 0 | 0/64；background 64/64 | `已完成` | P0-09 profile 使用生产 `AppDatabase.open` connection 的 direct-only SQLite callback；maintenance raw API 不在此口径 |
| 60Hz build+raster p95 | M4 Pro/macOS profile | 未测 | <12ms | D4 712.627ms；D5 3.335ms | `进行中` | D4 严重不达标；D5 隔离 surface 达标 |
| >16.7ms frame 比例 | M4 Pro/macOS profile | 未测 | <1% | D4 31/33；D5 0/27 | `进行中` | D4 严重不达标 |
| Anchor drift | 待定 | 已知算法错误，未量化 | ≤1 logical px | 未测 | `未开始` | — |
| D4 chunk→visible p95 | M4 Pro/macOS profile | 未测 | <100ms | build+raster p95 712.627ms | `进行中` | 隔离 surface 只测 frame，不含网络时间 |
| D4 DB writes/s | 单元时钟 | 当前逐 chunk，未量化 | ≤4 + final | ≤4 + final | `已完成` | P0-03 250ms 起始间隔 + final barrier 测试 |
| D3 双向浏览 RSS | 待定 | 未测 | 回落且不单调增长 | 未测 | `未开始` | — |
| D2 搜索 p95 | M4 Pro/macOS SQL | 未测 | <150ms | 中文 2 字 0.109ms；4 字 0.063ms；尾部稀有命中 7.043ms | `进行中` | 当前 LIKE microbenchmark；正确率/FTS/navigation 未完成 |
| Backup/restore extra RSS | 待定 | 未测 | 新 SQLite snapshot 为 O(page/chunk)，初始 <32MiB | 未测 | `进行中` | 新默认格式移除全库 JSON；v2 settings 在复制前限制 16 MiB，并以 1 MiB chunk 有界读取，但 JSON DOM 仍需 profile；旧 `chats.json`/迁移 JSON 仍可能全量解码，允许较慢但继续优化 OOM 边界 |
| WAL peak/checkpoint p95 | M4 Pro/macOS fixture | 未测 | 记录起点 | D2 21,819,552 bytes；单次 checkpoint 0.243ms | `进行中` | 生成器单事务压力值，非正常 stream WAL；其他平台未测 |

## 15. 故障注入台账

| Failpoint | 预期有效状态 | 允许损失边界 | 状态 | 实际结果/证据 |
| --- | --- | --- | --- | --- |
| Migration building kill | live 旧库完整 | candidate 未提交工作 | `未开始` | — |
| Candidate validation failure | live 旧库完整 | 无用户数据损失 | `进行中` | `22044e46` 已覆盖 descriptor/manifest 篡改、非 canonical path、settings 超限、非法 SQLite、sidecar、精确拓扑/逐项 hash，并保留 live；尚无磁盘满、目录 fsync 或 kill 验证 |
| Checkpoint/close/fsync kill | live 旧库完整 | candidate 可丢弃/重试 | `进行中` | macOS 已在 live DB normalization 的最终 durability barrier 后执行真实 SIGKILL 并恢复；checkpoint/close 各子步骤、`renameAndSync` 内部 raw rename/fsync 窗口、硬件断电和其他平台仍未覆盖 |
| live→previous 后 kill | 启动按 receipt 恢复 previous 或继续安装 candidate | 无半库 | `进行中` | macOS forward case 已覆盖 previous settings/manifest 发布、live DB+upload/images/avatars/fonts→`previous.pending`、`previous.pending`→`previous` 和 `oldRenamed` receipt temp/final；verified-origin rollback 又覆盖旧 DB/四资源根恢复。完整回归另覆盖 selected old DB missing、unselected DB family/assets、empty/missing asset root 的 commit/rollback；这些拓扑尚无逐项外部 SIGKILL，raw rename/fsync 与其他平台仍待验证 |
| candidate→live 后首次启动 kill | 校验 new 或回 previous | 尚未提交的 v2 尾部 | `进行中` | macOS forward case 已覆盖 settings 部分态、candidate DB+四资源根安装，以及 `newInstalled/verified/committed` receipt temp/final；verified-origin rollback 覆盖新 DB/四资源根退回 candidate、target-only tombstone 删除及 `rollingBack/rolledBack` receipt temp/final；两个 terminal projection 各覆盖 cold ACK 与 archive 六点。raw durability 子步骤与其他平台仍待覆盖 |
| v2 已写新消息后代码回滚 | 使用 v2-compatible rollback | 最多一个未 checkpoint stream 尾部 | `未开始` | — |
| Restore 任一阶段 kill | 破坏性切换前旧 live 不变；开始切换后 gate 收敛到完整 new 或经验证 old，绝不放行混合 | 无已放行业务写入 | `进行中` | macOS forward 25/25、committed/target terminal 6/6、verified-origin rollback 18/18、`rolledBack/before` terminal 6/6 与 legacy archiving marker 3/3 强类型高层 case 已完成真实 SIGKILL；rollback 是 12+6 分段证据，其余三个新增场景均有一次未中断 full。尚不能外推到其他 rollback 起点/topology、raw write/rename/fsync 子步骤、硬件断电或其他平台 |
| terminal cold-ack/archive kill | active admission 保持到跨进程 settings readback 与 archive barriers 完成 | 无已放行业务写入；evidence 保留 | `进行中` | committed/target 与 `rolledBack/before` 两个 projection 均完成六点 6/6；legacy markerless 路径另完成三点 3/3。settings-readback 2/2 以正常退出的真实 Runner 显式证明两种 before/target 混合态可冷读修复、换 ACK、再冷启并零写归档。旧 canonical 空/截断的真实进程场景、raw settings/file write/delete/rename/fsync 与断电未覆盖 |
| Streaming checkpoint 前 kill | 最后已提交 checkpoint 可读，run interrupted | 一个 checkpoint 窗口尾部 | `未开始` | — |
| Final transaction 中 kill | 完整 streaming checkpoint 或完整 final | 无半 final 状态 | `未开始` | — |
| Cancel/onDone/late chunk 竞态 | 唯一终态且不可回退 | 无已提交内容倒退 | `未开始` | — |
| Disk full during DB/WAL | 当前事务 rollback，错误可见 | 未提交事务 | `未开始` | — |
| Disk full during backup | 旧数据不变，不发布损坏备份 | 临时备份文件 | `未开始` | — |
| Read-only/permission change | 不创建空库，不假成功 | 未提交事务 | `未开始` | — |
| DB/WAL/SHM 损坏/缺失 | 进入只读恢复/诊断 | 不覆盖现场 | `未开始` | — |
| `user_version` 高于二进制支持版本 | 只读/拒绝打开并要求升级 | 不执行任何写入或降级 | `未开始` | — |
| ZIP/manifest/hash 损坏 | 拒绝恢复，live 不变 | staging | `进行中` | DataSync/candidate/receipt/previous 测试覆盖 ZIP 预算、manifest/hash/schema/count/topology 篡改；只读恢复 UI 尚未实现 |
| Receipt 损坏/缺失/sequence 回退 | 进入只读恢复，不按文件名猜测 | 不开放混合 bundle | `进行中` | checksum/hash-chain 损坏、缺口、超限、非法状态与链接目录继续 fail-closed；macOS 已真实 kill 覆盖四个前向 receipt 及 `rollingBack/rolledBack` 的 temp/final 边界，并修复 unpublished later-temp 仲裁；`rollingBack` temp case 还要求 canonical verified 重试同一失败后收敛。terminal archive 不新增 receipt，legacy marker create/write 已换成原子发布并覆盖三个高层 kill 点；只读恢复入口、raw marker 子窗口与多 run 诊断仍未完成 |
| 多组 previous/candidate 同时存在 | 根据有效 manifest/receipt 诊断，无法唯一确定则阻塞 | 不自动删除任何候选 | `未开始` | — |
| Duplicate ID/order/version | 确定性报告/隔离，不覆盖 | rejects 中的数据 | `未开始` | — |
| Missing parent/selection | 阻止 active graph 切换 | rejects 中的数据 | `未开始` | — |
| Attachment half copy/missing | DB 与 asset receipt 一致；缺失明确标记 | 未提交 staging asset | `未开始` | — |
| Two desktop processes | 单实例或明确拒绝第二 writer | 无半事务 | `进行中` | macOS 已有真实子进程 business-lease 竞争、拒绝第二 writer 与持有者 kill 后重获证据；Windows/Linux 和业务启动全链路仍待验证 |

## 16. 五平台验证台账

| 验证 | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| `flutter analyze` / unit tests | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Drift schema migration | PASS：v2→v3 真机 | PASS：simulator | PASS：主机 | PASS：用户侧 runner | PASS：用户侧 runner |
| FTS5/tokenizer | PASS：FTS5/unicode61；短中文 0 | PASS：FTS5/unicode61；短中文 0 | PASS：FTS5/unicode61；短中文 0 | PASS：用户侧 runner；短中文数值未回传 | PASS：用户侧 runner；短中文数值未回传 |
| Online Backup API | PASS | PASS：simulator | PASS：主机 | PASS：用户侧 runner | PASS：用户侧 runner |
| WAL/FULL 实际 PRAGMA | PASS | PASS：simulator | PASS：主机 | PASS：用户侧 runner | PASS：用户侧 runner |
| File close/rename/fsync | PASS：capability barrier | PASS：simulator capability barrier | PASS：主机 capability barrier | PASS：用户侧 capability runner | PASS：用户侧 capability runner |
| Kill/restart recovery | 未开始 | 未开始 | 进行中：25/25 forward + committed/target terminal 6/6 + verified-origin rollback 18/18 + `rolledBack/before` terminal 6/6 + legacy archiving marker 3/3 高层 SIGKILL，以及 settings cold-readback 2/2 正常跨进程 case 通过；其余 rollback topology 与 raw 子窗口未覆盖 | 未开始 | 未开始 |
| Timeline profile/anchor | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Secure storage/backup boundary | 未开始 | 未开始 | 未开始 | 未开始 | 未开始 |
| Build/package ABI | PASS：`android_arm64` | PASS：`ios_arm64` simulator | PASS：`macos_arm64` | PASS：runner；ABI 未回传 | PASS：runner；ABI 未回传 |

说明：本轮根目录 `flutter analyze` 和 `flutter test` 仅作为当前主机的代码基线，不等于上述五平台目标验证已完成。

## 17. 风险登记

| ID | 风险 | 严重度 | 检测方式 | 缓解/回滚 | 状态 |
| --- | --- | --- | --- | --- | --- |
| R-01 | Branch 产品语义未定导致 schema 返工 | 高 | PD-01/02/04 未批准 | PD-01/02/04 已冻结且 ADR-0001 已接受；后续偏离必须先修订 ADR 与方案 | `已完成` |
| R-02 | SQLite v1 已发布却错误以 Hive 为主源 | 高 | 发布记录/真实用户数据核对 | PD-13 已核实 v1 从未发布，Hive 即公开主源；开发机 v1/Hive 双源 precedence 仍需迁移测试 | `进行中` |
| R-03 | v2 写入后直接回 previous 丢新消息 | 高 | 记录 cutover 后 write epoch | v2-compatible rollback build | `未开始` |
| R-04 | Windows handle/杀软导致 swap 失败 | 高 | Windows failpoint/锁库测试 | 单一连接、关闭 handle、receipt 恢复 | `未开始` |
| R-05 | `synchronous=FULL` 低端设备延迟 | 中 | 五平台 benchmark | 合并 checkpoint；公开记录取舍 | `未开始` |
| R-06 | FTS5 与短中文行为跨平台不同 | 中 | 五平台语料正确率/p95 | capability gate；明确行为 | `未开始` |
| R-07 | Graph ancestry 查询在超长会话退化 | 中 | D3 query plan/benchmark | parent 索引；必要时受控物化 view | `未开始` |
| R-08 | Cache 只限制条目不限制字节再次 OOM | 高 | RSS/cache bytes telemetry | 所有 cache 字节 LRU | `未开始` |
| R-09 | 普通备份继续泄露秘密 | 高 | ZIP 内容审计 | P0-08 + OPS-07 | `进行中`：应用已知认证凭据已排除；自由文本与 secure storage 边界待 OPS-07 |
| R-10 | 测试全绿掩盖需求反例未覆盖 | 高 | 需求矩阵与现有测试 diff | 已补恢复/candidate/rollback 反例；其余按工作项继续先红后绿 | `进行中` |
| R-11 | overwrite 直接依次写 settings/DB/assets 形成混合 bundle | 高 | settings、DB、各资源目录 failpoint 与重启指纹 | 同卷 staging + previous + durable receipt + business lease + 启动恢复 | `进行中`：P0-02 应用层实现已移除运行期在线覆盖并完成 operation-ahead 主链；macOS 25/25 forward、两个 terminal projection 各 6/6、rollback 18/18、legacy marker 3/3 高层 SIGKILL，以及 terminal settings 混合态 2/2 跨进程修复均收敛；selected missing/unselected payload 回归通过。风险仍保留为进行中，因为 raw durability、硬件断电、其余 topology、五平台与升级时旧版本进程退出策略属于 OPS/发布门禁且尚未完成 |
| R-12 | 受损 Hive 迁移 ZIP 被严格引用校验整体拒绝 | 高 | 缺 message/orphan 的真实旧备份 fixture | Recovered conversation/rejects adapter，保留原始问题报告 | `未开始` |
| R-13 | 旧 `chats.json`/迁移 JSON 全量解码导致 OOM/主 isolate 卡顿 | 高 | 600–800MB legacy fixture 的 RSS/frame profile | 新备份改 SQLite snapshot；legacy adapter 使用 chunk reader 与增量导入 | `进行中` |
| R-14 | ZIP32 与恢复展开边界导致超大备份失败或磁盘耗尽 | 中 | >4GiB compressed、8GiB 单项、16GiB 总展开 fixture | 当前显式拒绝超限并在写出时计数中止；后续评估 Zip64 和按可用磁盘预算 | `进行中` |
| R-15 | terminal evidence 长期占用空间且 previous settings 含旧凭据 | 高 | completed runs 数量/字节/权限审计 | 0700/0600 受限归档；PD-10 明确保留期、成功启动 acknowledgement 与可恢复清理 | `进行中`：active admission 已释放且 evidence 保留；自动 retention/诊断脱敏尚未实现 |

风险状态表示缓解工作状态，不代表风险是否已经发生。P0-01/P0-02 已开始降低部分风险，但尚未满足整包崩溃安全、旧数据恢复和有界内存验收。

## 18. 当前阻塞与待输入

PD-01～PD-14 已全部冻结，MSG-01 ADR 已接受，产品决策和 Phase 1 平台输入均不再阻塞 Phase 2。Windows/Linux 的 `DB2_CAPABILITY_RESULT` 原始行未归档，精确 ABI/SQLite 元数据留给五平台发布门禁补证；这不重新打开已通过的 DB2-07 capability gate。

## 19. 下一步

Phase 2 当前 1/7。下一步执行 MSG-02：实现 conversation state、branch、slot、revision schema、逐版本 migration snapshot 和 composite FK/CHECK/UNIQUE/索引/事务不变量。D4 renderer/RSS 超标不在 Message Graph 阶段扩 scope。

## 20. 变更日志

| 日期 | 变更 | 工作项 | Commit/PR | 作者 |
| --- | --- | --- | --- | --- |
| 2026-07-11 | 完成 Message Graph ADR：把 PD-01/02/04 转成可执行的稳定 identity 与真实 branch 语义，逐例冻结普通发送、旧 assistant 重生成、旧 user 编辑、revision 切换、三类删除、conversation fork 和 context boundary；明确旧后代保留、active path 唯一 selection、删除不得 compact，以及 UI/Repository/Projector/Generation/Timeline 分层边界。R-01 关闭，Phase 2 进入 1/7 | MSG-01 | 本里程碑提交 | Codex |
| 2026-07-11 | 补齐 DB2-02 profile 证据并锁定 MSG-04 删除边界：生产 `AppDatabase.open` connection 注册 direct-only SQLite execution-isolate probe，P0-09 macOS `--profile` 以递归 CTE 采样 64 次，opening/UI isolate 0、Drift background isolate 64；新增 64-sample happy path 与 0-sample boundary 单测，使 DB2-02 验收摘要与 SLO 台账一致。明确该口径不覆盖 restore/backup/inspection maintenance raw SQLite。方案与进度同时规定 MSG-04 不得继承 v1 `_rewriteMessageOrder`/全会话 `0..n-1` compact，D3 删除更新量不得随会话总消息数线性增长。`flutter analyze`、database 75/75、全量 1180/1180 与 macOS profile 均通过 | DB2-02、P0-09、MSG-04 | 本补证提交 | Codex |
| 2026-07-11 | 完成 DB2-07 与 Phase 1：用户在 Windows、Linux 原生环境执行既有统一 capability runner 并确认均通过，五平台矩阵达到 5/5。macOS/iOS simulator/Android 的结构化结果已归档；Windows/Linux 原始 `DB2_CAPABILITY_RESULT` 未回传，因此只记录用户侧 PASS，不猜测机器、ABI、SQLite version/source ID 或短中文数值，并把精确元数据归档留给发布门禁。DB2-07 标记完成，Database Kernel v2 8/8 关闭，下一步进入 MSG-01 | DB2-07、Phase 1 | 本里程碑提交（完成） | 用户 / Codex |
| 2026-07-11 | 补齐 DB2-07 Android 真机证据：2112123AC / Android 11（API 30）/ `android_arm64` 在设备进程通过 v2→v3 migration、live PRAGMA contract、FTS5/unicode61、WAL+FULL、Online Backup、SQLite 双连接写锁、Dart 文件锁与 full-barrier rename，SQLite 3.53.2，短中文仍为 0。Android app NDK 从 27 对齐 `integration_test`/`jni` 所需 28.2.13676358；debug APK 构建、安装和 runner 通过。DB2-07 更新为 3/5，Windows/Linux 仍待用户侧 runner，不提前关闭 Phase 1 | DB2-07、OPS-04 | 本里程碑提交（Android 证据） | Codex |
| 2026-07-11 | 完成 DB2-08：新增无正文/SQL/参数/ID/path 承载字段的 `ChatDatabaseObserver`，固定 operation 与失败类别，每 operation 有界保留 256 个 latency samples，snapshot 计算 p50/p95/max/result/failure。gateway/query window/search/transaction command/stream+final checkpoint/integrity/WAL checkpoint 接线；真实 checkpoint 记录 WAL 前后 bytes、busy/log/checkpointed，失败保留原异常。live connection 显式设置并启动断言 WAL、FK ON、busy timeout 5000、FULL、auto-checkpoint 1000、journal limit 16 MiB，删除无基准支持的额外 read pool。敏感值反例、rollback/checkpoint failure、connection contract 通过；定向 29、全量 1178、macOS/iOS capability 与 analyze 通过 | DB2-08 | 本里程碑提交 | Codex |
| 2026-07-11 | DB2-07 部分完成并因平台输入阻塞：新增设备内统一 capability integration runner，实际执行 v2→v3 migration、FTS5/unicode61、WAL+FULL、Online Backup、SQLite 写锁冲突、Dart 文件锁、full-barrier rename 和 ABI/version 输出。macOS 26.5.2 arm64 真实主机与 iPhone 17 / iOS 26.5 arm64 simulator 2/5 PASS，SQLite 3.53.2；短中文 `中文` 为 0 命中，转 OPS-04。Flutter 实验性 SPM 因既有 iOS 插件依赖范围冲突，项目显式保持 CocoaPods 后 iOS 通过。Android 无 system image/设备、Windows/Linux 无 runner，未虚报完成 | DB2-07、OPS-04 | 本里程碑提交（部分） | Codex |
| 2026-07-11 | 完成 DB2-06：沿用 P0-06 database identity/installation receipt，并以 gateway lease 生命周期新增 durable session receipt；首个 live lease 发布、最后 lease 在 DB close 成功后清除。unclean、open error 与 identity mismatch admission 执行 quick_check、FK、schema 与 identity 复验，成功才删除 session receipt；授权 restore 只在新库复验且旧 session 精确绑定旧 installation receipt 后消费旧 session。缺库、物理/FK 损坏、identity/receipt 不符均保留证据并进入现有只读恢复页。identity 通过后台 Drift Future 获取，未恢复主 isolate raw SQLite。定向 21 项、全量 1171 项与 analyze 通过 | DB2-06 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 DB2-05：repository 收口 add/version/selection/batch-delete/fork/final-checkpoint 单事务 commands，service/controller 不再拼接 MAX/order、selection JSON RMW、逐条删除或空 fork；并发分配、回滚、artifact/receipt 与 commit 后缓存发布均有回归。定向 60 项、全量 1162 项与 analyze 通过 | DB2-05 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 DB2-04：schema v3 加入 FK/UNIQUE/CHECK、微秒时间与稳定复合索引；v2→v3 原子重建和秒值换算，约束失败保留 v2；关键查询以 EXPLAIN 验证索引，两阶段 order 改写避免瞬时唯一冲突。定向 24 项、全量 1153 项与 analyze 通过 | DB2-04 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 DB2-03：新增进程级 ChatDatabaseGateway/lease；同一路径并发 acquire 与 ChatService init single-flight，共享 repository，最后 lease 才关闭；关闭与新 acquire 串行，持有 live lease 时拒绝路径切换；初始化失败关闭 handle、保留坏库证据并允许修复后重试。定向 31 项、全量 1142 项与 analyze 通过 | DB2-03 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 DB2-02：移除 `_syncDb`、同步 repository query/count/search/tool/signature API 和 raw row mapper；ChatService/Controller 将窗口分页、版本组补载、完整 prompt、搜索、统计和导入改为后台 Drift 异步读取，渲染 getter 只读内存 cache；相关滚动锚定回调改为 await 后修正。analyze、定向 111 项、全量 1139 项通过 | DB2-02 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 DB2-01：冻结 Drift v1/v2 schema JSON、生成 step-by-step migration 与测试 schema helper；Database Kernel v2 以显式 v1→v2 format step 建立迁移边界，installation gate 在 identity/adoption 前迁移完整校验通过的开发版 v1 并复验，保留会话/meta 数据；未来、过旧和损坏 schema 继续拒绝。定向 64 项、全量 1139 项与 analyze 通过 | DB2-01 | 本里程碑提交 | Codex |
| 2026-07-11 | 清除 P0-03 的 iOS 残留阻塞：`chat_actions` 不再逐 chunk await `MethodChannel update`，service 内新增 500ms 起始间隔的单 writer latest-wins 队列；首个 update 可立即发送，在途期间只保留最新 token，finish/cancel 经 barrier 后才发送终态，update 异常通过回调记录且不阻止终态。覆盖高频合并、真实 500ms 间隔、finish/cancel 顺序、失败可观察、disabled/non-iOS no-op；定向 22 项、P0 快速门禁 49 项、全量 1136 项与 analyze 通过 | P0-03、GEN-03 | 本残留修复提交 | Codex |
| 2026-07-11 | 完成 P0-09：新增固定 seed D1～D6 SQLite/assets/fault fixture 生成器、deterministic plan digest、SQL/WAL/RSS 采样、macOS profile integration surface 与一键 P0 快速门禁。M4 Pro baseline 明确记录 D4 build+raster p95 712.627ms、31/33 长帧、RSS peak 1.56GiB，未把严重超标粉饰为通过；D5 surface 3.335ms。其他平台与完整 HomePage/timeline/backup RSS 继续在对应工作流追踪。Phase 0 9/9 完成 | P0-09 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 sandbox path migration version 化：ChatService 不再先加载 conversation 再逐会话扫描；repository 用 version + AppData root receipt 在正常启动零消息查询返回，首次、iOS 容器根变化或跨安装 restore 才按稳定 message ID cursor、360 条批次扫描 image/file 候选。内容更新与 receipt 在同一事务，rewrite/坏 receipt 失败整体回滚并上抛，未来 version 拒绝。定向 5 项、全量 1126 项与 analyze 通过 | P0-07 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成数据库 identity/installation admission：数据库 meta 持久化 UUID，AppData 使用受限权限、flush/full barrier、无覆盖 rename 发布 identity 命名 receipt；业务启动前只读执行 schema/integrity/FK/required schema/identity 校验。首次安装可建库，旧有效库可一次 adoption；已有 receipt 的缺库、损坏、未来 schema、身份缺失/不符和 receipt 损坏均 fail-closed 到恢复页且不创建空库。P0-02 验证过的 DB restore 可轮换 DB identity 并保留 installation ID，新 receipt 先发布再清旧 receipt。定向 9 项、全量 1121 项与 analyze 通过 | P0-06 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 v2 SQLite merge：使用 ATTACH + 单事务逐会话计算规范化 SHA-256，内容相同去重，conversation/message ID 冲突时确定性整会话 remap，连续 order、MCP、tool events、Gemini signature、group/version selection 与 FK 同步校验；重复导入保持幂等，失败整体回滚。移动端与桌面本地/WebDAV/S3 恢复显示导入/去重/remap 报告且 merge 后不要求重启。secret-free settings merge 应用导入侧非秘密配置并保留本机认证凭据。四份 ARB/l10n 已同步；定向 52 项、全量 1112 项与 analyze 通过 | P0-05 | 本里程碑提交 | Codex |
| 2026-07-10 | 完成 prepare/cancel/stale streaming 收尾：send、regenerate 与 tool-answer continuation 在 placeholder 建立后的任一 prepare/初始化失败都会保留 partial/占位但清除 streaming、notifier 和 conversation loading；active assistant identity 以会话级 store 独立于 lazy window，off-window cancel 仍能按稳定 ID 经 P0-03 barrier final，且 cancel 后恢复的旧 prepare 不再启动网络请求。ChatService 冷启动改为数据库单事务清除全部 `isStreaming=true` 与 tracking metadata，覆盖未登记 flag、孤儿 ID 和并发 tracking；清理失败不再 best-effort 吞掉。按范围纪律仅做逻辑/集成验收：定向 44 项、全量 1107 项与 analyze 通过 | P0-04 | 本里程碑提交 | Codex |
| 2026-07-10 | 完成单 writer latest-wins 流式 checkpoint：普通 content/reasoning/tool events 在内存聚合为完整快照，网络 chunk 只入队不等待 SQLite；writer 以 250ms 最小起始间隔限制为 ≤4 writes/s，在途写期间只保留最新 pending。final/cancel/error 关闭入队、丢弃被终态覆盖的 pending、等待旧写后提交 final；切会话 flush 走同一 barrier。repository 使用直接 UPDATE，消息与 tool events 单事务提交，移除逐 checkpoint read-before-write；checkpoint 失败可观察，后续 chunk/flush 失败上抛，成功 final 可恢复。按 Phase 0 范围纪律仅做逻辑/集成验收：定向 31 项、全量 1100 项与 analyze 通过，未复制真实进程矩阵 | P0-03 | 本里程碑提交 | Codex |
| 2026-07-10 | 冻结 PD-01～PD-13 全部产品决策：真实分支（PD-01/02）、interrupted 保留 partial 不做继续生成（PD-03）、发送追加 leaf + 新轮次置顶（PD-04）、绝不违背用户意图移动 viewport 的滚动合同（PD-05，对齐 shadcn Scroll Engineering/ChatGPT/Claude）、搜索/统计默认 active branch（PD-06/07）、完整备份全量（PD-08）、merge hash 去重 + remap（PD-09）、双条件保留期（PD-10）、v2 不做 DB 加密（PD-11）、只读恢复页（PD-12）；并以 git 证据核实 SQLite v1 从未发布（PD-13），公开迁移主源改为 Hive → v2，方案 §5.1/§7.4/§9.1/§10/§15 同步修订 | PD-01～13、MSG-01、TL-04 | 本次文档提交 | 用户 / Fable |
| 2026-07-10 | 完成 P0-02 应用层验收收尾：新增 `terminalSettingsReadbackRecoveryMatrix` v1，以四个隔离 Runner 正常退出方式一次完整通过 committed/target 与 rolledBack/before 两种真实混合设置的 2/2、8 phases、0 kill（244.594 秒）；R3 新 PID/token 冷读后必须有写修复并轮换 ACK，R4 mutation rejector 零写归档。新增 selected old DB family missing 与 settings-only/unselected main+WAL+SHM+journal+四类 assets 的 commit/rollback 回归，control+topology 29/29。真实进程累计 240 phases/58 kills。P0-02 标记完成；raw syscall/断电/资源故障/其余 topology 外部 kill/五平台继续由 OPS-02、DB2-07、P0-09 和发布门禁跟踪，不视为已验证 | P0-02、OPS-02 | 本里程碑提交 | Codex |
| 2026-07-10 | 将 legacy markerless terminal 的 archiving marker 从直接 create/write canonical 改为 fixed temp 的 restrict→write/full barrier→readback→`renameAndSync`→canonical readback；startup 仅在唯一 active terminal、无 completed 同 ID/碰撞/未知项且 artifact 为空或匹配 runId 前缀时耐久删除并重扫，错误前缀/ID、temp+canonical 与非终态保留现场 fail-closed。新增独立 `legacyArchivingMarkerRecoveryMatrix` control v1，一次未中断完成 empty restricted/temp durable/canonical published 3/3、12 Runner phases、3 次外部 SIGKILL，耗时 381.084 秒；R3/R4 settings 零写并复验 ACK/receipt/bundle/archive。裸同名 terminal exact route 另以 120.107 秒通过，不计入主口径；累计真实进程证据 232 phases/58 kills。旧 canonical 空/截断只有 fixture 单测，raw write/rename 内部窗口、断电和其他平台仍未覆盖 | P0-02、OPS-02 | 本里程碑提交 | Codex |
| 2026-07-10 | 新增独立 `rolledBackTerminalRecoveryMatrix` control v1，以 `--scenario=rolledback-terminal` 复用六个 terminal 物理高层边界验证 `rolledBack/before` projection；一次未中断完整运行通过 6/6、24 Runner phases、6 次外部 SIGKILL，耗时 728.342 秒。ACK temp 的 R3 必须 mutation>0 并轮换新 PID/token ACK，ACK published 与 archive R3 settings 零写；R4 对六点均以 mutation rejector 复验 archived/business-ready、旧 bundle live、新 bundle candidate、previous 仅余 control evidence。裸 committed terminal 与 verified-origin rollback 各 exact 回归通过，旧 CLI 路由未被新场景抢占；前置 exact rerun 不计入主口径。全部真实进程证据累计 220 phases/55 kills；仍不宣称显式 settings 部分态、其他 rollback 起点/topology、raw durability、硬件断电、资源故障或其他平台 | P0-02、OPS-02 | 本里程碑提交 | Codex |
| 2026-07-10 | 新增独立 rollback control v1、18 个 verified-origin 高层故障点与严格 host/oracle：覆盖 `rollingBack/rolledBack` receipt temp/final、DB 与四资源根反向移动、previous/database parent barrier、settings first/secret/target-only tombstone；每点以真实 Runner PID 执行外部 SIGKILL，R3 mutation>0 且到达 `rolledBack/before` ACK，R4 settings 零写归档。首轮被交互中断前有 12 个明确 PASS，再从第 13 点完整续跑 6/6，合计 72 Runner phases/18 kills，但不宣称一次未中断 full。夹具 v3 增加 target-only 键后，前向 smoke 首次复验暴露并修正测试 oracle 的矛盾断言，随后 forward smoke 与 terminal `coldAckPublished` exact case 均通过。本里程碑没有新增 `lib/` 生产改动；raw durability、其他 rollback topology、rolledBack terminal、硬件断电与其他平台仍开放 | P0-02、OPS-02 | 本里程碑提交 | Codex |
| 2026-07-09 | 新增独立 terminal control v1 与六个 committed/target 高层 cold-ack/archive failpoint；一次完整 macOS 运行取得 6/6、24 Runner phases、6 次外部 SIGKILL，oracle 收紧后两个 ACK exact case 再次通过：temp 要求 R3 重应用/轮换，published 要求 R3 零写归档，R4 始终零写验证。修复 terminal run raw rename 后 admission 过早释放：operation-ahead archiving marker 保留到 move+双 parent barrier，gate 可从 completed evidence 续跑，并兼容 legacy markerless active terminal。未宣称显式 settings 部分态、rollback/rolledBack、raw durability、legacy marker create/write、硬件断电或其他平台 | P0-02、OPS-02 | 本里程碑提交 | Codex |
| 2026-07-09 | 将 macOS RestoreHarness 升级为 control v2 的 25 个强类型前向 failpoint，提供 smoke/core/full、`--failpoint`/`--from`；host 每次生成一个 matrix run，同一 matrix run 下每 case 独立 scenario/prefix/AppData/restore run，以四个真实 Runner 完成 setup、外部 SIGKILL、前向恢复、cold finalize。跨 core 分段与 full-only targeted 运行取得 25/25、100 个成功 Runner phase、25 次 SIGKILL，support 13/13；实测修复 unpublished 仲裁误拒 later receipt temp+final receipt，无 final receipt 的 later temp 保持 fail-closed。该前向里程碑当时未宣称单次 full、硬件断电、raw rename/fsync、rollback、cold-ack/archive kill 或其他平台 | P0-02、OPS-02 | 本里程碑提交 | Codex |
| 2026-07-09 | 增加隔离正式数据的 macOS RestoreHarness bundle、四阶段真实 Runner 协议和独立宿主；在 candidate SQLite 耐久替换 live、`newInstalled` receipt 前复验 executable/PID/lstart 并执行外部 SIGKILL，再由两个新 PID 完成原生 SharedPreferences 读回、前向收敛、PID+token cold ack、settings 零写入归档；严格回读 DB/四资源根/previous/receipt/WAL/owner，以 phase baseline 安全清理未知 Runner，并用宿主单实例锁阻止 Flutter build/temp 串用 | P0-02、OPS-02 | 本里程碑提交 | Codex |
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
