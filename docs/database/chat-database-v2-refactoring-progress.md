# Kelivo 聊天数据库与消息系统 v2 重构进度

> - 方案基线：[chat-database-v2-refactoring-plan.md](./chat-database-v2-refactoring-plan.md)
> - 追踪基线：分支 `sql`，本轮实现基线 `f7e11373`
> - 最后更新：2026-07-12（第三轮复审：四个用户症状逐一定位，新登记 §10.3 MSG-R1～R3 / TL-R14～R15；PD-01/PD-02/§7.2 修订为默认 graft 语义）
> - 当前结论：Phase 0/1/3 保持关闭。§10.3 MSG-R1～R3、TL-R14/R15 已全部完成自动化实现；Phase 2/4 的第三轮真机矩阵按用户决定暂缓，不阻塞 Phase 5 实现。Phase 5 已完成 OPS-01～07；OPS-08 实现完成、发布平台矩阵 1/5

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
| Phase 2：Message Graph | 6 / 7 | `进行中` | PD-01 修订后的 MSG-R1/R2 graft/fork 命令与设置分流已实现并自动化通过，schema 不变；MSG-04 与 Phase 2 只待第三轮真机产品矩阵确认后恢复完成 |
| Phase 3：Generation State Machine | 7 / 7 | `已完成` | GenerationRun、原子 begin/final、三链解耦、ordered parts、启动 interruption recovery 与竞态/长响应矩阵全部闭环 |
| Phase 4：Timeline 与 Renderer | 8 / 8 | `进行中`（实现完成，待第三轮真机确认） | TL-R1～R6 已获第一轮真机确认；§10.2 TL-R7～R13 与 §10.3 TL-R14/R15 自动化闭环；经真机四症状矩阵前不关闭 |
| Phase 5：Data Operations 与退役 | 7 / 9 | `进行中` | OPS-01～07 已完成；OPS-08 代码/runner 已完成但五平台发布证据为 1/5；继续 OPS-09 可执行的退役门禁/API 收口，不提前删除保留数据 |

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
| MSG-02 graph schema/invariants | `已完成` | analyze 通过；database 82/82；全量 1187/1187 | 2026-07-11 | v4 snapshot 与 1→2→3→4 任意起点 migration 验证；graph happy/boundary/failure、稀疏 revision、跨 conversation composite FK、自引用/枚举/时间/级联、关键索引计划覆盖 |
| MSG-03 active path/context projector | `已完成` | analyze 通过；database 94/94；全量 1199/1199 | 2026-07-11 | main/alternate/target projection、旧 assistant target 排除未来、context 原子更新/幂等/冲突、revision/branch cycle、duplicate slot、deleted path、missing state、invalid boundary 与 v4 raw table 缺失覆盖 |
| MSG-04 graph transaction commands | `已完成` | analyze 通过；database 104/104；全量 1209/1209 | 2026-07-11 | v5 message part migration/FK/ordinal/kind；edit/regenerate/select/delete/fork happy、boundary、rollback、state conflict；旧未来排除、旧 branch 保留、cascade confirm、200 unrelated revisions 删除放大反例覆盖 |
| MSG-05 deterministic legacy adapter | `已完成` | analyze 通过；database 110/110；全量 1215/1215 | 2026-07-11 | Hive/SQLite v1 共用 typed adapter；selection ordinal/version ambiguity、invalid fallback、duplicate ID/order/version、truncate inside/outside、streaming partial、orphan Recovered、stable ID/parts/issue ledger 原子持久化覆盖 |
| MSG-06 frozen legacy fixture/digests | `已完成` | analyze 通过；database 112/112；全量 1217/1217 | 2026-07-11 | released Hive JSON projection fixture + frozen SQLite v1 schema；visible/selection/prompt/asset SHA-256、reasoning/text part order、ambiguous selection/truncate、streaming orphan Recovered 全部一致 |
| MSG-07 graph business cutover | `已完成` | analyze 通过；database 113/113；全量 1216/1216 | 2026-07-11 | Hive migration 逐 conversation 生成 graph/parts/ledger 后才完成；immutable timeline projection 忽略故意冲突的 legacy JSON/order；append/edit/regenerate/select/context/delete/fork/checkpoint 均走 stable graph ID。删除 inactive alternate 后物理 order 保持 `0,2`，不 compact；Cherry/legacy JSON/overwrite 回归通过 |
| GEN-01 generation run state machine | `已完成` | analyze 通过；database 121/121；全量 1224/1224 | 2026-07-11 | schema v7 与 frozen/generated migration helper；8 状态、terminal timestamp/error/target composite FK/CHECK、每 target 最多一个 active run 的 partial UNIQUE、state/update 索引；repository 以 state + stateRevision CAS transition，竞争终态仅一个成功，终态无出边。happy/boundary/FK/schema 缺失/任意旧版本升级覆盖 |
| GEN-02 atomic generation begin | `已完成` | analyze 通过；database 125/125；全量 1229/1229 | 2026-07-11 | persistent send 在一个外层事务写 user/assistant legacy shadow、graph slot/revision/text part、branch/state、active compatibility receipt 与 preparing run；regeneration 同事务写 alternate revision/branch/run。run insert 故障回滚所有消息和 branch mutation；UI 在 commit 后一次发布 user/assistant pair，无 false tail reload。temporary conversation 保持明确的 in-memory 路径 |
| GEN-03 network/UI/DB decoupling | `已完成` | analyze 通过；database 127/127；聚焦 36/36；全量 1232/1232 | 2026-07-11 | stream subscription 不再 pause/resume 网络源；chunk 进入本地 FIFO 后由单 consumer 串行处理，done/error 排在已接收 chunk 后。UI 沿用 50ms coalesced publisher，DB 沿用 250ms latest-wins + final barrier，iOS 沿用 500ms latest-wins。run CAS 进入 requesting/streaming；message/parts/tool snapshot 与单调 checkpoint_seq 同事务，stale seq 全回滚 |
| GEN-04 atomic terminal finalization | `已完成` | analyze 通过；database 130/130；全量 1235/1235 | 2026-07-11 | final message/graph parts/tool snapshot、最后 checkpoint seq、compat active receipt 清理与 completed/failed/cancelled run CAS 同事务；preparing failure 直接 failed 且 seq 保持 0。terminal CAS 故障整包回滚，late checkpoint 不覆盖 final；错误详情仅走 UI channel，不写正文；所有 UI loading/notifier/iOS cleanup 使用 finally |
| GEN-05 ordered parts/provider artifacts | `已完成` | analyze 通过；database 132/132；Phase 3 最终全量 1240/1240 | 2026-07-11 | schema v8 provider artifacts migration；reasoning/tool call/result/text 有序 parts 与 final signature 同事务；shadow 篡改反例证明 parts/artifacts 是正常读取唯一权威 |
| GEN-06 startup interruption recovery | `已完成` | analyze 通过；聚焦 25/25；Phase 3 最终全量 1240/1240 | 2026-07-11 | 非终态 run 单事务转 interrupted、state revision 递增、partial/checkpoint 保留、streaming flag 清理；active ID JSON 写入口删除且 run rows 成为唯一 active truth |
| GEN-07 race/long-response matrix | `已完成` | analyze 通过；竞态/长响应聚焦 26/26；全量 1240/1240 | 2026-07-11 | cancel 等待在途 chunk barrier 并丢弃 queued late chunks；error/onDone FIFO terminal；1 MiB/1024 chunks 在首 checkpoint 阻塞时全部被网络侧消费且最终仅首个在途+final 两写；CAS late checkpoint、cancel/completed terminal、cold-start logical kill/partial recovery、switch snapshot latest-wins barrier 与既有 P0-09 macOS D4/profile 证据共同覆盖矩阵 |
| TL-01 active ancestry cursor contract | `已完成` | analyze 通过；projector/coordinator/stream 聚焦 24/24 | 2026-07-11 | repository 以 active branch leaf recursive ancestry + stable before/after revision cursor 返回逻辑 slot page；只取 selected revision、按 slot 聚合 versionCount，500 alternates 仍占 1 timeline row。Timeline Coordinator 首先落成纯逻辑契约，View 不接触 OFFSET/物理 revision 坐标；无效/非 active cursor fail closed。顺手保护 stream onError 二阶异常，通过 FlutterError 可观测而不逃逸 drain |
| TL-02 bounded/cancellable timeline window | `已完成` | analyze 通过；timeline/lazy/service/projector 聚焦 47/47 | 2026-07-11 | coordinator 同时执行 360 logical slots 与 4 MiB decoded text 双预算，向前页裁尾、向后页裁头并把被淘汰 revision/artifact 从 ChatService cache 释放；conversation request epoch 丢弃切会话后的晚到 page，同方向 single-flight。ChatController initial tail=40 slots，before/after/head/tail 主分页均走 stable cursor；page 暴露 active logicalIndex/totalSlotCount 仅作 UI 状态，不作为 SQL 坐标；500 alternates 无额外 page。同步 cached seed 仅为尚未 async open 的兼容投影 |
| TL-03 unified visual anchor | `已完成` | analyze 通过；anchor/widget/lazy 聚焦 36/36 | 2026-07-11 | `TimelineViewportAnchor(slotId, localDy)` 选择首个完整可见 slot，布局后按同 slot 新 localDy 计算唯一 scroll correction，≤1 px 不修正。MessageList item 外层 GlobalKey 改用稳定 slot ID；before/after page 均在 mutation 前 capture、下一布局后 restore，替换旧 maxScrollExtent 差值近似。双预算裁窗检测 anchor，候选为 anchor 时改裁另一端；reasoning/版本/图片等后续高度变化可复用同一 API |
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
| PD-01 | 多版本是否采用真实分支 | schema 保留分支；默认语义为同 slot graft（保留后代） | `已完成`（2026-07-12 修订） | MSG-01～07、MSG-R1/R2 | 2026-07-10 冻结为纯 fork；2026-07-12 依用户真机反馈修订：纯 fork 与既有产品合同（"仅保存"、`regenerateDeleteTrailingMessages` 默认关闭、版本切换不影响下方）冲突。默认变更/版本切换走 graft（同 slot sibling + on-path child re-parent，branch 不变）；仅删除尾随重生成与显式截断走 fork。详见方案 §5.1/§7.2 |
| PD-02 | 编辑、重生成、删除 revision 后的后代策略 | 默认 graft 保留后代；fork 时旧后代留在旧 branch；延迟 GC | `已完成`（2026-07-12 修订） | MSG-01、MSG-04、MSG-R1/R2 | 2026-07-12 随 PD-01 修订：默认（graft）语义下旧 revision 作为同 slot sibling 保留、可随时切回；fork 语义下旧后续留在旧 branch。删除仍为显式操作（删当前选中版本自动 graft-select 最新剩余；删 slot 最后 revision 提示连带后代）；延迟批量 GC。详见方案 §5.1 |
| PD-03 | 中断输出的展示和重试策略 | 保留 partial，显示 interrupted，可重试/删除 | `已完成` | GEN-01～07 | 2026-07-10 冻结：保留 partial + "已中断"标识 + 重新生成/删除；不做"继续生成"（provider 续写不可靠，列为 v2 后评估）。详见方案 §5.1 |
| PD-04 | 在历史位置发送时的交互 | 创建 branch，不强制立即跳底部 | `已完成` | MSG-01、TL-03/04 | 2026-07-10 冻结：发送永远追加到 active leaf 并 programmaticJump 把新 user 消息置于 viewport 顶部附近；编辑历史消息走分支语义并保持原锚定。详见方案 §5.1/§7.4 |
| PD-05 | 离开底部时的新内容提示 | 保持 anchor，复用右侧到底按钮 | `已完成` | TL-04、TL-08 | 2026-07-12 最终冻结：绝不违背用户意图移动 viewport；滚动/选择文本/键盘/链接/搜索均退出尾随；恢复尾随复用右侧既有到底按钮，不新增胶囊；重开会话定位最后一条 user 消息。详见方案 §5.1/§7.4 |
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
| MSG-02 | Conversation/Branch/Slot/Revision schema | DB2-04、MSG-01 | `已完成` | parent/branch/slot 不变量由 FK/CHECK/事务强制 | 本里程碑提交（2026-07-11） | schema v4 + frozen snapshot/generated verifier；`conversation_state_rows`、`conversation_branch_rows`、`message_slot_rows`、`message_revision_rows` 使用稳定 ID、稀疏 revision number、同 conversation composite FK、role/causality/time/state CHECK、UNIQUE 与 parent/slot/branch indexes。v3→v4 保留旧行并创建空 graph，公开 Hive/开发机 v1 的实体映射留给 MSG-05；database 82/82 与全量 1187/1187 通过 |
| MSG-03 | Active path projector 与 context boundary | MSG-02 | `已完成` | prompt 只含真实 ancestor path | 本里程碑提交（2026-07-11） | `MessageGraphProjector` 仅接受 conversation/branch/target revision stable ID；单次 recursive CTE 取 ancestry set 后在 Dart 重建 parent chain，检测 revision/branch cycle、missing/deleted node、同 path 重复 slot和 fork metadata。active projection 以稳定 revision boundary 裁剪 context；repository command 在同一事务按 `state_revision` 条件更新，非法 alternate boundary 回滚。raw snapshot 必须含全部 v4 graph tables/columns/composite FK；database 94/94、全量 1199/1199 通过 |
| MSG-04 | Edit/regenerate/select/delete/fork commands | DB2-05、MSG-03 | `进行中`（实现完成，待第三轮真机确认） | 全部使用稳定 revision/branch ID 且单事务；默认变更走 graft（保留后代），仅删除尾随走 fork；删除不得复用 `_rewriteMessageOrder` 或全会话 compact，D3 删除更新量不得随会话总消息数线性增长 | 本里程碑提交（2026-07-11） | MSG-R1 的 edit/graft-select 与 MSG-R2 的 generation begin 分流均已完成：默认 regeneration 在创建 run 的同一外层事务中 graft 新 assistant revision并保留 future；`truncateFuture=true` 创建截止新 revision 的 branch，旧 branch/message rows 不删。设置值从 ChatActions → MessageGenerationService → ChatService → repository 显式传递；持久会话删除尾随前置链已移除。临时会话没有数据库 branch 且整体不落盘，开启设置时仅对本次内存会话保持原截断行为。既有 delete/fork 语义与 OPS-06 债务不变 |
| MSG-05 | Hive/SQLite v1 → graph/legacy projection adapter | DB2-01、MSG-02、PD-13 | `已完成` | selection 双解释、因果歧义、truncate/orphan/duplicate 均保留 issue，不伪造真实历史 | 本里程碑提交（2026-07-11） | `LegacyMessageGraphAdapter` 对 Hive model 与 SQLite v1 row projection 使用同一 typed input；group anchor 按 order/time/ID，revision 按 version/time/ID，selection 同算 ordinal/version，冲突用旧 UI ordinal 保画面并写 `selection_ambiguous`，均非法 latest fallback + issue。duplicate version 分配稳定稀疏号，truncate slot 内/越界、streaming partial、cross-conversation orphan/recovered 均显式记录。v6 `migration_run/issues` ledger 与 graph/parts 同事务持久化；不生成 native causality |
| MSG-06 | Legacy fixtures 与 digest 对比 | MSG-05、P0-09 | `已完成` | 可见序列、选中版本、prompt、parts/assets 均验证 | 本里程碑提交（2026-07-11） | `legacy_message_graph_v1.json` 冻结 released Hive backup JSON projection（物理尾部旧 assistant alternate、ordinal/version 冲突、truncate 落组内、reasoning、asset path、streaming orphan）；同一 payload 写入 frozen SQLite v1 schema 后再读取，二者 adapter active IDs/context/digest 一致。visible `832ec2…`、selection `db078e…`、prompt `289d88…`、asset `47066c…` 均冻结 |
| MSG-07 | 删除旧业务依赖 | MSG-03～06 | `已完成` | 业务不再依赖 `messageIds/versionSelectionsJson/truncateIndex` | 本里程碑提交（2026-07-11） | 新 `MessageGraphTimelineProjection` 以 slot/revision/branch/context stable ID 输出 active path、alternates、ordered text/reasoning parts；故意把 legacy `version_selections_json`/`truncate_index` 写成冲突值仍得到 graph selection/context。ChatService 启动只加载 conversation summaries + SQL counts，不构造所有 conversation `messageIds`；选择、context、搜索选中版本、统计计数改从 graph/DAO projection 获取。运行期普通追加、revision branch、checkpoint parts、stable-ID selection、sparse delete、fork shadow projection 均闭环；正式 Hive migration 每 conversation 有界转换并完成 ledger，未发布 SQLite v1/旧 JSON 仅 best-effort backfill。允许旧字段继续存在的范围仅为 `Conversation`/`ChatMessage` 兼容 model、legacy adapter、Hive/旧 JSON/备份导入导出和旧 schema migration；正常 controller/service 不读取其持久语义。analyze、database 113/113、全量 1216/1216 通过 |

## 9. Phase 3：Generation State Machine

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| GEN-01 | `GenerationRun` schema 与条件 transition | MSG-02、DB2-05 | `已完成` | 终态不可被迟到事件回退 | 本里程碑提交（2026-07-11） | schema v7 冻结 `generation_run_rows`：target composite FK、状态/时间/error/CHECK、state revision 与 checkpoint 非负、每 target 最多一个 active run 的 partial UNIQUE、state/update 索引。不可变 domain model + repository command 只允许 ADR 状态图边，更新按 `(id, expected state, expected stateRevision)` CAS；两个竞争终态仅一个成功，terminal 无出边。migration、结构缺失、FK、非法 transition、active uniqueness 与完整状态路径测试通过 |
| GEN-02 | 原子 begin send/regeneration | GEN-01、MSG-04 | `已完成` | user/assistant/run/branch 一次提交 | 本里程碑提交（2026-07-11） | repository 以外层 transaction 组合现有 graph command：persistent send 原子创建 user + assistant shadow/slot/revision/text part、推进 active branch/state、登记兼容 streaming receipt 并创建 preparing run；regeneration 原子创建同 slot alternate、native branch 与 run。ChatService 只在 commit 后更新 cache，ChatActions 以单次 tail mutation 发布 send pair；重复 run ID 故障证明消息、parts、branch/state 全回滚。临时会话不写数据库，继续显式 in-memory 路径 |
| GEN-03 | 网络/UI/DB 三链解耦 | P0-03、GEN-01 | `已完成` | 网络不 await UI/DB；UI frame paced；DB latest-wins | 本里程碑提交（2026-07-11） | `listenSequentiallyToStream` 改为不 pause source 的本地 FIFO/单 consumer：producer 可在 handler await 时继续读取，chunk 处理仍严格有序，done/error 经过同一 barrier。GenerationRun 在请求前 CAS `preparing→requesting`、首 chunk CAS `requesting→streaming`；checkpoint cursor 可跳号但只前进，message shadow、graph parts、tool events 与 run `checkpoint_seq` 同事务，重复/倒退序号整体回滚。UI 50ms、DB 250ms、iOS 500ms 三个 latest/coalesced publisher 相互不 await；100 token/s/1MiB profile 留 GEN-07，不在本项复制证明强度 |
| GEN-04 | Complete/fail/cancel/interrupted 收尾 | GEN-01～03 | `已完成` | 所有 failure path 清 loading 并保留正确 partial | 本里程碑提交（2026-07-11） | repository `finalizeGenerationRun` 在单事务写 final message shadow、graph parts、tool events、可选最后 checkpoint、清兼容 active receipt并按 expected state/revision CAS terminal；CAS 失败证明正文、parts、receipt 全回滚。preparing 可无 checkpoint 直接 failed；streaming 可 completed/failed/cancelled，terminal 后 late checkpoint 被拒。ChatActions 为 run 保留 state/revision cursor，final barrier 丢弃 pending snapshot；错误文本不再写正文，complete/error/cancel/prepare failure 均在 finally 清 loading/notifier/runtime cursor，interrupted 启动恢复留 GEN-06 |
| GEN-05 | Ordered message parts/provider artifacts | MSG-02、GEN-04 | `已完成` | reasoning/tool/signature 与 final 同事务一致；parts 成为唯一正文权威 | 本里程碑提交（2026-07-11） | schema v8 增加 composite FK 的 `provider_artifact_rows` 并从 legacy Gemini signature shadow 回填；checkpoint/final 以 `reasoning → tool_call/result → text` 顺序原子替换 parts，terminal transaction 同步落最终 signature。所有 repository 正文读取批量投影 parts，故人为篡改 `message_rows.content/reasoning_text` 后仍返回权威正文；公开 update/put 路径同时维护 graph，不再存在 repository 内只写 shadow 的生产入口。`tool_event_rows`/signature 旧表仅保留为未发布 SQLite v1 与 JSON 导入兼容 shadow |
| GEN-06 | 启动恢复非终态 run | GEN-01/04 | `已完成` | 删除 active ID JSON；启动原子转 interrupted | 本里程碑提交（2026-07-11） | cold start 单事务枚举 `preparing/requesting/streaming/waiting_tool` run，统一写 `interrupted + app_restart + terminal_at`、递增 state revision、finalize 对应 revision 并清所有 legacy `is_streaming` flag；partial parts/checkpoint 不改。active generation 查询只投影 run rows，所有 active ID JSON 写 API/生产调用已删除；旧 meta key 仅用于升级、snapshot/clear 时清扫历史残留 |
| GEN-07 | 竞态、乱序、kill 与长响应验证 | GEN-02～06、P0-09 | `已完成` | 规定矩阵全部有自动化和 profile 证据 | 本里程碑提交（2026-07-11） | stream adapter 为 cancel 增加 barrier：等待当前 handler 后清空 queued chunks，保证 cancel terminal 之后无本地迟到 checkpoint；error/onDone 与 chunk 共用 FIFO terminal，terminal 后 producer event 被拒。确定性 1 MiB（1024×1 KiB）burst 在首个模拟 DB write 阻塞期间仍完整消费、source 不 paused，latest-wins 仅执行首个在途 checkpoint + final 两写；100 token/s 属更低压力同路径。结合 GEN-04 terminal CAS/late checkpoint、GEN-06 logical kill partial recovery、switch progress 的 writer barrier 测试，以及 P0-09 已冻结的 macOS D4/profile（UI isolate SQLite=0）完成矩阵；真实进程 kill/断电仍按范围纪律留 OPS-02/DB2-07，不在此复制 P0-02 强度 |

## 10. Phase 4：Timeline 与 Renderer

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| TL-01 | Active ancestry cursor 逻辑分页 | MSG-03、DB2-03 | `已完成` | page 单位为 slot；无 OFFSET/物理 revision 坐标 | 本里程碑提交（2026-07-11） | 新 `ActiveTimelinePage/Slot` 契约从 active leaf 递归 ancestry，以 `beforeRevisionId`/`afterRevisionId` 查询相邻逻辑 slot，cursor 不在 active path 时拒绝；page 只加载 selected revision identity，版本仅聚合 `versionCount`，500 alternates 证明仍为单 slot。`LoadedTimelinePage` 在 service 层批量装配权威 message/parts/artifacts；`TimelineCoordinator` 只持 stable slot/revision cursor，不暴露数据库 OFFSET。按“契约先行”暂未改 View，TL-02 起由 coordinator 接管窗口 |
| TL-02 | 行数 + 字节双预算窗口 | TL-01 | `进行中`（实现完成，待真机确认） | 版本数不击穿窗口；切会话/浏览后内存回落 | 本里程碑提交（2026-07-11） | `TimelineWindowBudget` 同时限制 logical slots/decoded bytes；page merge 后从视觉移动相反一侧裁窗并恢复相应 cursor，至少保留一个超大 slot。retainer 立即清理 ChatService 窗口外 selected message/tool/signature cache，但 retained message cache 必须保持 growable，因为 generation begin/append 会在 commit 后继续发布到同一工作集；该不变量已有“裁窗后再次发送”真实 service 回归。open/clear 递增 epoch，陈旧 conversation page 不发布。TL-R5 将同会话 open 改为 stale-while-revalidate，查询期间不清空窗口；TL-R6 将 stateRevision 不一致从静默拒绝改为保留视觉 anchor 的权威窗口重建，后续分页可继续。ChatController 的打开、向前/向后、首/尾窗口切到 coordinator；固定初始 40 slots，版本不参与容量。双预算 eviction、旧会话晚到结果、5000 slot 双向有界浏览及 graph mutation 后继续分页均有测试 |
| TL-03 | Slot ID + localDy 锚点协调器 | TL-01/02 | `已完成` | 规定 mutation 后漂移 ≤1 logical px | 本里程碑提交（2026-07-11） | coordinator 新增 geometry→首个完整可见 slot capture 与同 slot correction；localDy 漂移 `≤1` 视为稳定，测试覆盖 0.75 px 不动与 137.25 px 精确补偿。MessageList 用 `groupId/slotId` GlobalKey 测量 RenderBox，在所有双向分页前后统一 capture/restore，不再按 content extent 猜 prepend 高度；预算裁剪绝不删除当前 anchor。窗口 resize、版本/reasoning/图片 mutation 的主动触发在 TL-04/06/08 接入同契约 |
| TL-04 | Following/user anchored/jump 状态机 | PD-04/05、TL-03 | `进行中`（实现完成，待第二轮真机确认） | 用户阅读历史时 stream 不强制跳动；coordinator/scroll/widget/lazy 聚焦回归通过 | 本里程碑提交（2026-07-11） | `TimelineViewportMode` 冻结 followingTail/userAnchored/programmaticJump/loading 四态；滚轮/触摸离底立即退出尾随，分页 loading 恢复原意图，stream 只更新未读/生成态而不移动 anchored viewport。TL-R7 移除 send 的两处到底指令并将真实输入与程序滚动分流；TL-R8 以完整 viewport 差额先布局 spacer、下一帧再把 user slot 精确置顶，生成期恒定。锚定模式与 bottom-pin 互斥，内容底部判定明确扣除 spacer；仅右侧既有到底按钮或真实到达内容底部恢复 following。TL-R4 统一 terminal snapshot，终态将 spacer 收敛到避免 clamp 的最小残量。TL-R13 已删除重复的独立“跳到最新”胶囊，未新增替代控件。TL-R9/R10 已将地图、搜索、问题导航及 revision 重建统一到 stable cursor；TL-R11/R12 已完成会话隔离与 coordinator 单一窗口真相源，当前仅待真机关闭证据 |
| TL-05 | `MessageRenderModel` 与细粒度订阅 | TL-01 | `已完成` | 无每行全列表扫描和无关整页 rebuild；render/lazy/widget 聚焦 35/35 | 本里程碑提交（2026-07-11） | `ChatController.messageRenderModels` 对 bounded snapshot 一次性投影 stable slot、排序 revisions、selected index、context divider 与 latest complete assistant，并随既有 snapshot cache 一起失效；row builder 删除反向全列表扫描、逐行 revision sort 和逐行 provider watch。Settings/Assistant 值只在 Home 列表边界订阅并作为窄 presentation 输入下传；每个非 stream slot 使用 stable-key RepaintBoundary，stream 继续只由对应 notifier 刷新 |
| TL-06 | 增量 Markdown、字节 LRU、图片尺寸 | TL-05 | `已完成` | 长输出无平方级退化；图片不造成无控高度跳变；analyze + markdown/cache/stream 109/109 | 本里程碑提交（2026-07-11） | 4 KiB+ streaming Markdown 按 fence-aware blank boundary 切 stable source blocks，completed block 保持 identity/已渲染子树，仅 tail 随 120ms publish checkpoint 重建；1 MiB append 证明 scanner 累计只读 1 MiB 而非前缀和。新增通用 `ByteLruCache`，normalization 输入按 4 MiB decoded bytes、Mermaid bitmap 按 24 MiB 管理并暴露 bytes/evictions。Markdown 有宽高元数据时继续固定预留布局；所有支持图片按实际 logical size × DPR 包装 `ResizeImage`，避免 4K 原图按原尺寸 decode |
| TL-07 | 长表格/代码/tool 虚拟化 | TL-05/06 | `已完成` | D5 不一次构造全部大 widget 树；analyze + markdown/tool/chat 128/128 | 本里程碑提交（2026-07-11） | 完成态 Markdown 表格默认只构造 header+39 body rows，按 100 rows 显式增量展开，copy/CSV/image export 仍使用全量数据；10,000 行 code 无论用户是否禁用自动折叠，超过 1,000 行即进入固定 420 px、每 chunk 200 行的 lazy ListView，高亮与选择仅作用于可见 chunks。tool arguments/result 超过 40 行或 12 KiB 默认 preview，展开为每 40 行/16 KiB chunk 的独立 selectable lazy viewport；桌面 dialog 与移动 bottom sheet 的两套 detail 路径全部接入。折叠/展开按钮含中英本地化与 expanded semantics |
| TL-08 | 移动/桌面交互与可访问性 | TL-03～07 | `已完成` | 5/5 TargetPlatform contract；analyze + 全量 1271/1271 | 本里程碑提交（2026-07-11） | Android/iOS 保持 drag-dismiss keyboard，macOS/Windows/Linux 保持 manual dismiss 并验证平台 ScrollBehavior scrollbar；桌面 timeline Focus 捕获 Arrow/Page/Home/End 并退出 followingTail，滚轮、主键拖选、右键、问题导航、mini-map/search jump 同样冻结 user anchor。`WidgetsBindingObserver.didChangeMetrics` 在 userAnchored/programmatic 状态下执行 mutation 前 capture + 下一 frame slotId/localDy correction，followingTail resize 不与 bottom pin 竞争。跳到最新、超长内容 toggle 均具 button/live/expanded semantics。5/5 指 TargetPlatform widget contract matrix；真实五 OS 的 touch/mouse/keyboard/resize 复测仍按 §16 发布门禁记录，不伪装为本机实测。Phase 4 提交后的真实启动发现 scroll callbacks 早于 `_chatController` 初始化，已交换为 chat/controller → scroll 顺序并用直接构造 `HomePageController` 的 widget regression 锁定 |

### 10.1 Phase 4 复审返工清单（2026-07-11，真机实测反馈驱动）

用户真机实测报告两类症状：(a) 输出中或输出完成后一滑动，消息内容消失，只剩加载动画；(b) 自动滚动时不断小幅上下弹跳。复审确认这些不是零散 bug，而是 Phase 4 集成层的两个结构性缺陷，以下缺陷全部闭环并由用户复测确认前，Phase 4 不得视为完成，Phase 5 不得开工。

| ID | 缺陷 | 严重度 | 根因链（已核实到行级） | 验收标准 |
| --- | --- | --- | --- | --- |
| TL-R1 | 单一真相源违规：流式与终态内容从不写回 coordinator 窗口，任何 coordinator 通知都会用过期 slots 覆盖 UI，内容永久退化为加载动画 | P0（用户可见数据"丢失"） | 发送时 `appendPersistedTailMessages` → `open()` 载入的 assistant slot 是数据库空壳（content 为空、`isStreaming=true`）。此后整个流式期间与 `_finishStreaming`（`chat_actions.dart` `_messages[index] = finalizedMessage`）只原地改 `ChatController._messages` 与 StreamingContentNotifier，**没有任何路径调用 `timelineCoordinator.replaceMessage`**，slots 永久过期。终态后 notifier 被 `removeStreamingNotifier` 移除。用户一滑动 → `userAnchored()` → `notifyListeners()` → `_syncTimelineWindow()` 把 `_messages` 整体替换为过期 slots → 助手消息变回空内容 + `isStreaming=true` 且无 notifier → `chat_message_widget.dart` 空内容 streaming 分支只渲染 `LoadingIndicator`，且无自愈路径 | 窗口内消息必须只有一个真相源：要么 checkpoint/final/流式 UI tick 同步更新 coordinator slot，要么 slots 成为唯一窗口数据、ChatActions/HomeViewModel 不再绕开 coordinator 原地改 `_messages`。新增回归：发送 → 流式 → 完成 → 依次触发 `userAnchored()`/`followTail()`/`loadBefore` → 断言可见内容与终态一致、无 `isStreaming` 残留、无空壳行 |
| TL-R2 | 视口模式通知与数据窗口通知混流：每个 pointer move 都触发全窗口重同步 + 整页 rebuild | P0（性能 + 放大 TL-R1） | `userAnchored()`/`followTail()`/`noteContentChanged()` 与 slots 数据变更共用同一个 `notifyListeners()`；`ChatController._syncTimelineWindow` 对每次通知无条件重建 `_messages` + `invalidateCache` + `notifyListeners`。`MessageListView.onPointerMove` 每个拖动事件都调 `userAnchored()`，拖动期间每帧全量重建。`updateMessageInList` 一次调用连发 `replaceMessage` + `noteContentChanged` 两次通知，双重 resync | 视口模式变化与窗口数据变化分离（独立 Listenable 或 slots revision 对比短路）；纯模式切换不得触发 `_syncTimelineWindow`/整页 rebuild；拖动期间帧构建成本有 profile 证据 |
| TL-R3 | 生成期两套滚动范式并存 + spacer 修正晚一帧 → 自动滚动持续小幅上下弹跳 | P0（用户可见抖动） | ① spacer 收缩依赖 `SizeChangedLayoutNotifier` → post-frame `setState`：第 N 帧内容长高 X（extent +X），第 N+1 帧 spacer 收缩 X（extent −X），offset 处于 max 附近时被反复 clamp。② `ChatAutoFollowScrollController` 在 layout 期把 pixels 钉到含 spacer 空白的 `maxScrollExtent`，与"用户消息置顶 + spacer"锚定范式直接冲突：jump 后 offset 天然贴近 max，`_handleUserScrollActivity` 以"距底 ≤24px"判定重新 `followTail()`，把视口钉进 spacer 空白。③ `UserScrollNotification` 对程序驱动动画也报非 idle 方向，`scrollToBottom` 的 animateTo 中途误触发 `userAnchored()`，模式在 followTail/userAnchored 间来回翻转，每次翻转又经 TL-R2 触发整页 rebuild | 生成期锚定模式下：bottom-pin 与 followTail 重入必须禁用，followTail 只能由显式"跳到最新"或用户真实拖到**内容底部**（判定排除 spacer 区域）触发；spacer 调整必须与内容增长同帧生效（layout 期计算），或生成期保持恒定、终态一次性回收并做锚点补偿；程序驱动滚动不得被当作用户滚动改变视口模式。验收含真机流式输出全程无 ±1 帧以上的 extent/offset 振荡证据 |
| TL-R4 | 流结束后 coordinator `isGenerating` 永久为 true | P1 | 终态路径不调用 `noteContentChanged(isGenerating: false)` 也不更新 slot 的 `isStreaming`（TL-R1 同源）；`_isGenerating` 只会在下次 `open()`/`clear()` 重置。后果：终态后底部 spacer 永不回收（大片空白）、`didUpdateWidget` 的 spacer 清理分支永不生效 | 生成终态（completed/failed/cancelled）必须同步 coordinator 生成态；spacer 回收伴随锚点补偿，不产生可见跳动 |
| TL-R5 | `open()` 先同步清空 slots 再异步加载 → 每次发送整页闪空 | P1 | `open()` 同步 `_slots = const []` + `notifyListeners()`，DB roundtrip 期间 `_syncTimelineWindow` 已把 `_messages` 清空，UI 显示空列表直到 page 返回 | 换窗口期间保留旧窗口内容（stale-while-revalidate）；发送路径优先增量 append 新 slot 而不是全量 reopen；无可见空白帧 |
| TL-R6 | `stateRevision` 守卫使分页在图变更后静默失效 | P2 | regenerate/edit/selection 推进 `conversation_state.state_revision`，coordinator 只在 `open()/seed()` 刷新 `_stateRevision`；此后 `loadBefore/loadAfter` 命中 `page.stateRevision != _stateRevision` 永远返回 false 且无任何重载动作，分页悄悄卡死 | 守卫失败必须触发窗口重建（保持视觉锚点）而不是静默丢弃；新增"regenerate 后继续向上分页"回归 |

复审结论：Phase 4 各 TL 工作项的单元测试全部为绿（1274/1274），但集成断层（ChatActions 流式路径 ↔ coordinator 窗口）没有任何测试覆盖，正是 R-10 所述"测试全绿掩盖需求反例未覆盖"的实例。返工顺序建议：TL-R1/R2 一起做（真相源与通知分离是同一改动面），然后 TL-R3/R4（滚动范式收敛），最后 TL-R5/R6。每项修复必须先写红色回归再修，且最终以用户真机复测（流式长输出 + 滑动 + 自动跟随）作为关闭证据。

实现收敛（2026-07-11）：TL-R1～R6 均已按上述顺序先补失败回归再修复；新增回归覆盖 snapshot 经视口/分页不回退、纯 intent 不重发窗口、恒定生成 spacer、全 terminal generation 收口、同会话 refresh 不闪空、graph revision 变化后重建并继续分页。`flutter analyze` 与全量 1279/1279 通过。此处只记录“实现与自动化完成”，用户真机复测前不把 Phase 4 标为完成。

### 10.2 Phase 4 第二轮返工清单（2026-07-12，用户真机复测反馈驱动）

用户真机复测确认：内容消失与流式抖动已消除，但仍存在 (a) 发送新消息"顶上去又弹回来"；(b) 迷你地图点击不能正常跳转；(c) "跳到最新"胶囊与既有右侧导航"到底"按钮功能重复。复审定位如下，全部闭环并经用户复测前 Phase 4 保持进行中。

| ID | 缺陷 | 严重度 | 根因链（已核实到行级） | 验收标准 |
| --- | --- | --- | --- | --- |
| TL-R7 | 发送路径同时下达"置顶"与"到底"两个互斥滚动指令 → 顶上去又弹回来（主因） | P0 | `HomeViewModel.sendMessage` 在 `_chatActions.sendMessage` 前后**各调一次** `onScrollToBottom?.call()`（home_view_model.dart 367/383 行）→ `_scrollToBottomSoon()` → `scrollToBottomSoon` 注册 post-frame **加 120ms 延迟**两次 `scrollToBottom`，每次都 `_autoStickToBottom = true` + `onFollowingTail()`（= `coordinator.followTail()`）并 animateTo 底部。与此同时 `appendPersistedTailMessages` 正确执行 `programmaticJump(user slot)` 置顶。结果：跳到顶（programmaticJump）→ 延迟的 scrollToBottom 到达 → followTail 清空 anchor/spacer（`didUpdateWidget` followingTail 分支）→ extent 收缩 + animateTo 底部 → 弹回。辅因：`ChatScrollController._onScrollControllerChanged`（scroll_controller.dart 208 行）以 `userScrollDirection != idle` 判定用户滚动，而 `animateTo` 的 DrivenScrollActivity 同样产生非 idle 方向 → 程序动画途中误触发 `onUserAnchored` → 模式再次翻转 | 发送路径**彻底移除**两处 `onScrollToBottom`（PD-04 置顶是发送滚动行为的唯一所有者）；`_onScrollControllerChanged` 的用户滚动判定改为只认真实手势（drag/wheel/键盘），程序驱动滚动不得进入 `userAnchored`/`_isUserScrolling`。回归：发送 → 断言 400ms 内无任何 followTail/scrollToBottom 被调度、user slot 稳定位于 viewport 顶部 |
| TL-R8 | spacer 数学上限 0.75×viewport + "先跳后缩"两阶段顺序 → 置顶物理上不可达且必然回弹（次因） | P0 | `_programmaticTailViewportFraction = 0.75`：`_calculateProgrammaticSpacer` 返回 `0.75v − occupied − fixedBottom`，使锚点以下内容恒等于 0.75v < viewport 高度 v，user 消息**最高只能停在离顶部 0.25v 处**。且 `_scheduleProgrammaticJump` 的顺序是：frame A 以临时 0.75v spacer jumpTo（能到更高处）→ 同一 post-frame `setState` 把 spacer 缩到测量值 → frame B extent 收缩 `occupied + fixedBottom` → offset clamp，可见回弹幅度等于 user 消息+占位高度 | spacer 目标改为 `v − occupied − fixedBottom`（clamp `[0, v]`），使锚点可达 viewport 顶部；顺序改为**先 setState spacer、下一帧再 jump**，jump 后不再改 spacer；生成期恒定，终态按现有 `_requiredTerminalAnchorSpacer` 收敛。回归：短/长 user 消息发送后 user slot 顶到 viewport 顶部 ±1px 且后续 3 帧 offset 零位移 |
| TL-R9 | 迷你地图跳转断裂：同步数据源被窗口保留驱逐 + off-window 跳转走 legacy offset seed | P0 | ① `_openMiniMap` 用 `allCollapsedMessagesForCurrentConversation()` → 同步 `getMessagesRange(0, count)`，其结果按 `_messagesCache` 过滤，而 `retainTimelineWindow` 已把窗口外消息全部驱逐 → 地图列表缺失旧消息；`getMessageIndex` 依赖懒加载的 `_messageOrderIds`，纯 coordinator 路径打开的会话可能从未填充 → 返回 -1 → 跳转静默失败。② 目标在窗口外时走 `loadWindowAroundMessage` → `_loadWindow` → `_seedTimelineFromMessages` → `seed(stateRevision: 0)`；落点靠近窗口顶部立即触发 `loadBefore` → revision 0 ≠ 真实值 → TL-R6 的 `_rebuildAfterStateRevisionChange` 固定 `fromStart:false` 重载**尾部窗口** → 视口被弹回底部，表现为"跳了又弹回去/跳不动" | coordinator 新增 `openAround(revisionId)` stable-cursor API（目标 slot 居中 + 双向 hasMore），跨窗口定位（迷你地图、搜索、问题导航、spotlight）全部走它；迷你地图数据源改为异步全量投影（graph timeline），不依赖被驱逐的同步 cache；退役 `_loadWindow`/`_seedTimelineFromMessages`/`reloadMessages` 的 legacy offset 窗口。回归：500 条会话跳转第 10 条 → 落点正确、继续向上分页不弹回 |
| TL-R10 | `_rebuildAfterStateRevisionChange` 固定重载尾部窗口 → 任何图变更后的下一次分页把阅读位置弹回底部 | P1 | TL-R6 修复选择了 `fromStart:false`（尾部）作为重建目标；用户在历史位置切版本/编辑/删除后继续滚动 → 窗口整体替换为尾部 → 视口跳底 | 重建必须围绕当前视觉 anchor（或触发分页的 cursor）恢复窗口并保持 `slotId+localDy`；回归：中部锚定 + regenerate → loadBefore → 视口漂移 ≤1px |
| TL-R11 | generation 生命周期信号未按会话隔离 → 后台会话终态清掉前台会话的生成态/spacer | P1 | `publishTerminalMessage` 无条件调 `timelineCoordinator.noteContentChanged(isGenerating:false)`；`continueAssistantMessageAfterToolAnswer` 无条件调 `noteContentChanged(isGenerating:true)`。coordinator 只属于当前会话：会话 A 后台完成会关闭正在生成的会话 B 的 isGenerating → `didUpdateWidget` 收 spacer → extent 收缩 clamp 跳动 | 所有 generation 信号先校验 `coordinator.conversationId == message.conversationId` 才写入；回归：双会话并发流式，后台终态不改变前台 viewport/spacer/isGenerating |
| TL-R12 | 删除/局部重载仍绕开 coordinator → 幽灵消息复活 | P1 | `deleteMessages`/`_deleteMessageVersions` → `chatController.reloadMessages()` 直接改 `_messages`，不更新 slots；`removeMessageIds`/`removeMessagesAfter` 同样只改 `_messages`。下一次 windowRevision 变更的 resync 会从仍含已删消息的 slots 重建 → 已删除消息重新出现 | 删除走 coordinator（移除对应 slot 或 stable-cursor 窗口重建 + anchor 保持）；`reloadMessages`/`removeMessageIds`/`removeMessagesAfter` 与 TL-R9 的 legacy 窗口一并退役。回归：删除中部消息 → 触发分页/模式切换 → 无幽灵行 |
| TL-R13 | 产品重复："跳到最新"胶囊与右侧导航"到底"按钮功能重复 | P2 | TL-04 新增 `TimelineJumpToLatest` overlay，但既有 `_buildScrollButtons` 的到底按钮已覆盖该场景（用户明确不需要胶囊） | 移除胶囊（home_page.dart `showJumpToLatest` 分支与 `timeline_jump_to_latest.dart`）；未读/生成中提示如需保留，以现有到底按钮 badge 呈现。纪律：新增任何 UI 控件前必须先盘点既有等价物并在进度文档记录取舍 |

第二轮复审结论（消息系统最终形态合同，方案 §7.4 已同步修订）：
1. **窗口唯一真相源**——coordinator slots 是可见窗口唯一数据；`ChatController._messages` 只是派生视图，禁止任何绕过 coordinator 的写入（发送/流式/终态/删除/重载全部收口，TL-R1 已收口流式与终态，TL-R9/R12 收口其余）。
2. **滚动唯一指挥**——视口意图只有三种来源：用户真实手势、显式按钮、PD-04 发送置顶；程序动画与布局修正永不产生意图（TL-R7）；同一轮交互内互斥指令（置顶 vs 到底）只允许一个所有者。
3. **extent 变化同帧原则**——spacer/padding 任何调整与触发它的布局变化同帧生效，禁止 post-frame 二段修正（TL-R8）。
4. **跨窗口定位统一 stable cursor**——openAround 是唯一跨窗口定位入口，legacy offset 窗口全部退役（TL-R9/R10）。
5. **会话隔离**——generation 信号、spacer、anchor 全部绑定 conversationId（TL-R11）。
返工顺序：TL-R7/R8（发送弹回，改动面最小、用户感知最强）→ TL-R13（删胶囊，顺手）→ TL-R9/R10（openAround + legacy 窗口退役）→ TL-R11/R12。每项先写红色回归再修，关闭证据为用户真机复测。

实现收敛（2026-07-12）：TL-R7～R13 已按上述顺序逐项提交。TL-R12 新增 `refreshAfterMutation`，围绕当前视觉 anchor 的最近存活 revision 原子重建权威窗口；数据库返回实际级联删除 ID，单条/批量/版本/重生成尾部删除据此清理 UI 状态，旧 `reloadMessages`、`removeMessageIds`、`removeMessagesAfter`、同步 recent-window 与 `seed(stateRevision: 0)` 路径全部退役。普通、draft 与临时会话的发送/流式快照均先写 coordinator slots，`_messages` 只从 slots 派生；临时会话新增同构 logical-slot cursor page，且窗口 retain 不驱逐其唯一内存历史。回归覆盖删除中部消息后分页/模式切换无幽灵、临时会话有界窗口/完整历史/批量删除/版本投影和发送均不旁路 coordinator。TL-R12 相关聚焦 83/83、`flutter analyze` 与全量 1288/1288 通过。这里仍只记录“实现与自动化完成”，用户真机矩阵通过前不把 Phase 4 标为完成。

### 10.3 第三轮返工清单（2026-07-12，第三轮复审：四个用户症状逐一定位）

第三轮复审逐一排查四个症状：无限上下跳动、发送上弹距离、"仅保存"删掉下面消息、多版本切换器不显示/重新生成设置失效。核实结论：前两个是 §10.2 合同"滚动唯一指挥"仍有两处漏网的执行器级冲突；后两个不是 timeline 缺陷，而是 **PD-01 纯 fork 语义与 Kelivo 既有产品合同（"仅保存"、`regenerateDeleteTrailingMessages` 默认关闭、slot 内版本切换不影响下方）冲突**，方案 PD-01/PD-02/§7.2 已于本日修订为"默认 graft（保留后代）+ 仅删除尾随时 fork"。全部闭环并经用户真机复测前 Phase 4 与 Phase 2 语义项保持进行中。

| ID | 缺陷 | 严重度 | 根因链（已核实到行级） | 验收标准 |
| --- | --- | --- | --- | --- |
| MSG-R1 | "仅保存"编辑 user 消息后，下方全部消息从时间线消失 | P0 | `saveUserMessageEditOnly` → `_saveEditedUserMessageVersion` → `ChatService.appendMessageVersion` → repository `_appendMessageVersion` 固定调 `MessageGraphCommands.createRevisionBranch(mutation: editUser)`（chat_database_repository.dart 2661 行）：创建以新 user revision 为 leaf 的**新 branch 并激活**。active path = leaf 的祖先链（message_graph_projector.dart `projectActiveTimelinePage` 递归 CTE），新 leaf 没有任何后代 → 时间线截止于被编辑消息，下方 assistant 及后续轮次全部离开 active path。数据未丢（在旧 branch），但切换器又不显示（MSG-R3）→ 用户感知为删除 | 按修订后 PD-01：新增 graft 命令（同 slot 新 revision + 把旧 revision 的 on-path child re-parent 到新 revision，branch 不变，单事务 + stateRevision 递增）；"仅保存"/"保存并发送"走 graft。回归：中部编辑仅保存 → 下方 slots 原样保留、切换器显示 `<1/2>`、切回旧版本下方仍不变 |
| MSG-R2 | `regenerateDeleteTrailingMessages=false`（默认）时重生成仍"删掉"下方消息 → 用户判定"重新生成设置失效" | P0 | `beginRegeneration` → `_appendGraphMessageToConversation(selectVersion: true)`（chat_database_repository.dart 2201-2257 行）：同 slot 插入新 revision 后**无条件 fork 新 branch 并激活**（forkedFromRevisionId = target.parentRevisionId）→ 不管设置开关，下方消息都离开 active path。设置为 true 时 chat_actions 982 行还先物理删除尾随再 fork，双重语义叠加 | 重生成按设置分流：false → graft（下方保留，新旧回答同 slot 可切换）；true → 保留现有 fork（尾随进入旧 branch，不再叠加物理删除，或按产品确认保留物理删除但不 fork，二选一并记录）。回归：默认设置下中部重生成 → 下方 slots 不变；开启设置 → 下方消失且可经版本切回旧 branch 恢复 |
| MSG-R3 | 多版本切换器不显示（重生成/编辑后 `< n/m >` 不出现） | P0 | 切换器可见性 = `MessageRenderModel.versions.length > 1`，来源是 `ChatController._messagesWithVisibleGroups` → 同步 `ChatService.getMessagesForGroups`（仅查 `_messagesCache`）。而 ① coordinator 每次窗口发布都调 `retainTimelineWindow`，把 active path 之外的 sibling revisions 从 `_messagesCache` 驱逐；② 发送/重生成路径 `appendPersistedTailMessages` → `open()` 后**不调用** `_preloadVisibleGroupData`，siblings 永远不会回填 → versions 恒为 1 → 切换器隐藏。DB 权威计数 `ActiveTimelineSlot.versionCount`（projector 已按 slot 聚合）从未被 render model 使用 | 切换器可见性与 `n/m` 改用窗口自带的 `slot.identity.versionCount`（DB 权威值，不依赖可驱逐 cache）；sibling 明细仅在用户点击切换时按 slot 懒加载（`loadMessagesForGroups`）。回归：重生成完成即显示 `<1/2>`；窗口分页/裁窗后仍显示；切换动作在懒加载完成前不丢失 |
| TL-R14 | 无限上下跳动（流式期间"到底"动画/手势与 layout pin 逐帧对抗） | P0 | ① `forceScrollToBottom`/`scrollToBottom` 在流式期间用 `animateTo(旧 maxScrollExtent)`（scroll_controller.dart 388 行）驱动 250-450ms 动画；同时 followingTail 下 `_AutoFollowScrollPosition.applyContentDimensions`（同文件 57 行）在每次布局把 pixels `correctPixels` 到**新** max。动画每 tick 把位置拉回曲线值（低于 max）、布局又顶到 max → 逐帧上下对抗直至动画结束，流式 chunk 持续到达时表现为连续弹跳。② 一次拖拽手势内 `onPointerMove`（message_list_view.dart 487 行）每个 move 事件发布 `userAnchored()`，而同手势的 `ScrollUpdateNotification(dragDetails≠null)` → `_handleUserScrollActivity` 在贴近内容底部时发布 `followTail()`（同文件 603-608 行）→ 单次手势内模式反复翻转；任何一次翻到 followingTail 都会在 `didUpdateWidget` 里销毁生成期 anchor/spacer（294-301 行）→ extent 收缩 clamp 跳动，且 anchor 不可恢复 | 按 §7.4 新增合同：followingTail + 流式期间"到底"不再 `animateTo`（直接交给 layout pin，必要时一次 `jumpTo`）；驱动动画存活期间挂起 layout pin。手势内不结算意图：pointer move 只记录"手势进行中"，意图在手势结束（ScrollEnd/pointer up）一次性结算。回归：流式中点"到底"按钮 → 位置单调趋向底部无反向位移；流式中慢速拖拽贴底 → 模式最多翻转一次、spacer 不被手势中间态销毁 |
| TL-R15 | 发送上弹距离不对/一次可见修正（jump 管线跨 3 帧使用陈旧输入） | P1 | `_scheduleProgrammaticJump` 管线跨 3 个 post-frame（全 viewport 临时 spacer → 测量并 setState 最终 spacer → 标记 ready → ensureVisible）。期间以下输入可变化而不重测：发送后输入框清空 → `inputBarHeight` 收缩 → `bottomContentPadding` 变小；移动端键盘 inset 动画；首个流式 chunk 改变 tail 高度。spacer/jump 用陈旧 `fixedBottom`/occupied → 落点偏差随后被 clamp/修正一次 = 可见"弹一下"。另：目标 slot 不在 cacheExtent 内时 `_slotKeys[targetId].currentContext == null` → 管线**静默 return**（633 行），模式滞留 programmaticJump、全 viewport spacer 滞留 | 测量与执行使用同帧输入：执行帧校验 `bottomContentPadding`/viewport/键盘 inset 与测量帧一致，不一致则重测；管线压缩为"布局 spacer → 下一帧计算目标 offset 并 jumpTo"两帧。目标未布局时用估算 offset 先 `jumpTo` 迫使布局再精确修正，禁止静默停摆。回归：多行草稿发送（输入框收缩）+ 键盘收起同帧 → 最终落点 user slot 顶部 ±1px、无二次修正；目标在 cacheExtent 外时管线仍收敛 |

第三轮复审结论：
1. 症状 3/4 的根因是**产品语义层**而非实现层——PD-01 纯 fork 与既有"slot 版本 + 保留后代"合同冲突；已修订 PD-01/PD-02/§7.2（默认 graft、仅删除尾随 fork），graph schema 无需变更（graft 只是受控的 `parent_revision_id` 改写 + 事务）。MSG-R1/R2/R3 属于 Phase 2 命令层返工 + Phase 4 render model 数据源纠正。
2. 症状 1/2 是 §10.2 合同第 2/3 条的**执行器级**残留：意图层已收口（TL-R7），但位置写入层仍有五种执行器（layout pin、animateTo、anchor jumpTo、observer animateTo、ensureVisible）可在同帧对抗；§7.4 已补充"同帧唯一执行器"与"手势内不翻转意图"两条合同。
3. 返工顺序：MSG-R3（切换器数据源，纯读侧、最小风险）→ MSG-R1/R2（graft 命令 + 调用点分流，先写红色回归：中部编辑仅保存/默认重生成后下方保留）→ TL-R14 → TL-R15。每项先红后绿，关闭证据为用户真机复测四症状矩阵。

实现收敛（2026-07-12，MSG-R3）：`MessageRenderModel` 新增独立于已解码 sibling 列表的权威 `versionCount`；ChatController 从当前 coordinator slots 投影每个 stable slot 的 DB 聚合计数，selected index 以 active revision/version selection 在权威范围内计算。MessageList 的切换器、上一版/下一版边界与“删除全部版本”入口均读取该计数，不再以 `versions.length` 决定可见性；已加载 `versions` 只作为明细，点击切换仍由 `setSelectedVersion → loadMessagesForGroups` 懒加载缺失 sibling。红色回归复现“cache 只剩 active v1，但 slot count=2”时旧实现无权威参数，绿化后立即得到 `<2/2>`；render/controller/widget 聚焦 64/64 与 analyze 通过。MSG-R1/R2、TL-R14/R15 仍按冻结顺序待执行。

实现收敛（2026-07-12，MSG-R1）：新增 `graftRevision` 单事务 command，校验目标在 active path/角色/state revision 后创建同 slot sibling 与 text part；中部目标把 active path 的唯一直接 child从旧 revision 改挂到新 revision，leaf 目标只更新当前 branch leaf，context boundary 若指向被替换 revision 则映射到新 revision，最后以 CAS 单次推进 state revision。`editMessageGraphUser` 与用户编辑实际入口 `appendMessageVersion(user)` 均改走 graft。`selectRevision` 对 parent 可证明的 native same-slot sibling 同样执行 graft-select；legacy ambiguous/不同 parent 仍走安全 branch 边界。两轮红色回归分别证明旧编辑与旧切换都会截断 future，绿化后均保持 `U1/A1/U2(or sibling)/A2`、branch ID/数量不变、旧 revision 仍在；assistant 生成分流未提前改动并留给 MSG-R2。ADR-0001 同步修订为默认 graft 合同。

实现收敛（2026-07-12，MSG-R2）：`beginRegeneration` 增加显式 `truncateFuture` 领域输入并贯穿 action/service/repository。false 时 generation run、message shadow、新 assistant revision、on-path child re-parent 与 state revision 在同一外层事务完成，active branch/future 不变；true 时创建截止新 assistant 的新 branch，旧 branch 与旧 future message rows 完整保留且 message count 不减少。ChatActions 的 `regenerateDeleteTrailingMessages` 不再触发持久会话 `removeTrailingMessages`，避免“先物理删再 fork”；仅不落盘、无可恢复 branch 的临时会话保留内存截断边界。红色回归先因缺少分流参数失败，绿化后默认得到 `U1/A1(v2)/U2/A2`，开启设置得到 `U1/A1(v2)` 且旧 branch 仍为 `U1/A1(v1)/U2/A2`；generation/context 18/18 与 analyze 通过。

实现收敛（2026-07-12，TL-R14）：`ChatScrollController` 接入会话生成态，生成期显式“到底”只执行一次 `jumpTo`，随后由 layout-time tail pin 独占像素；非生成期驱动动画存活时显式挂起 layout pin，消除两个执行器同帧争抢。MessageList 将一次 pointer drag 收口为手势事务：move/scroll update 仅记录最新 metrics 与视觉锚点，pointer up/ScrollEnd 仅一次结算 `followTail` 或 `userAnchored`，不再在同手势中反复翻转模式/销毁 spacer。红色回归分别证明旧生成期到底仍启动动画、两次 move 发布 5 次意图；绿化后生成增长位置单调贴 max，手势结束前 0 次、结束后恰 1 次意图。controller/widget 聚焦 18/18 与 analyze 通过。

实现收敛（2026-07-12，TL-R15）：programmatic jump 从“全 viewport spacer → 最终 spacer → ready flag → ensureVisible”的三次 post-frame 压缩为“布局 spacer → 下一执行帧用最新 viewport/底部覆盖重新计算并 jump”的两阶段管线；若执行帧输入变化则保持目标并重测，不使用陈旧值。目标尚未进入 cacheExtent 时先通过 observer 的稳定 index `jumpTo` 促使目标布局，再回到同一精确管线；目标已不在窗口则显式完成，任何路径都不再静默滞留 programmatic 模式。回归覆盖底部输入在两阶段间从 16px 变为 80px 后仍以 ±1px 置顶，以及 cacheExtent 外历史 slot 最终收敛并清空 target；widget 13/13 与 analyze 通过。

第三轮返工整体验证（2026-07-12）：仓库全量 `flutter test` 1294/1294 通过，全量 `flutter analyze` 无问题。自动化门禁已关闭，MSG-04 与 Phase 2/4 仅保留用户真机四症状矩阵证据。

## 11. Phase 5：Data Operations 与退役

| ID | 工作项 | 依赖 | 状态 | 验收摘要 | Commit/PR | 验证证据 |
| --- | --- | --- | --- | --- | --- | --- |
| OPS-01 | 默认 SQLite snapshot ZIP + manifest/hash | DB2-03/07 | `已完成` | 活动库备份一致；完成前重开验证；新格式不写 `chats.json` | 既有提交 + 本里程碑提交（2026-07-12） | Online Backup、独立重开/integrity/FK/schema/count、DB/settings/assets 分块压缩与流式 hash、ZIP 自校验、round trip、秘密排除均已实现；writer 现发布 ZIP64 entry/central/end records，不再受 ZIP32 的 4 GiB/65,535 条目格式上限，restore 仍以 8 GiB/entry、16 GiB total、100,000 entries 显式拒绝资源滥用。五平台 SQLite snapshot 能力沿用 DB2-07 的 5/5 设备 runner；backup/restore 聚焦 47/47 与 analyze 通过 |
| OPS-02 | Staging restore/merge + crash-safe bundle swap | P0-02、DB2-06/07 | `已完成` | DB/settings/assets 切换时阻止业务访问，receipt 恢复后只开放完整旧/新 bundle | 既有提交 + 本里程碑提交（2026-07-12） | overwrite 已由 P0-02 完成 selected-only staging、business lease、strict topology、append-only receipt、bounded previous、WAL normalization、operation-ahead forward/rollback、cold ack/archive 与启动恢复；240 real-process phases/58 SIGKILL 及逻辑 failpoint 均只开放完整 before/target。SQLite merge 以 ATTACH + 单事务导入，hash 相同去重、冲突整会话确定性 remap/report、重复执行幂等，非法 source 全回滚；settings merge 现先完整验证并以 touched-key snapshot 补偿批次应用，后续 key 写失败不再留下前缀，assets merge 为 only-if-absent 幂等补齐。merge/backup/startup 聚焦 110/110 与 analyze 通过；raw syscall/硬件断电和资源耗尽仍属于发布环境故障注入，不重复扩大应用实现门槛 |
| OPS-03 | 旧 JSON 只读 adapter + 显式 portable NDJSON v2 | MSG-05、OPS-01 | `已完成` | 新完整备份不写 `chats.json`；旧 ZIP/迁移 JSON 可导入且尽力保持有界内存 | 既有提交 + 本里程碑提交（2026-07-12） | 完整备份保持 SQLite，不写 `chats.json`；旧 `chats.json`、Cherry `data.json` ZIP、无 manifest settings-only 与迁移页 JSON 灾备仍为只读兼容入口。新增 `kelivo-portable-chat` NDJSON v2：默认 active branch + 非 streaming 终态，显式 `allRevisions` 导出全部 revision shadow；100 条分页写出，每行独立 JSON，footer 绑定 conversation/message count 与前文 SHA-256。导入逐行解析到临时 SQLite，完整 footer/hash 校验和 graph backfill 后才复用事务 merge/remap 发布，篡改/截断不触碰 live。portable/legacy 聚焦 5/5 与 analyze 通过 |
| OPS-04 | FTS5/短中文 fallback/branch navigation | PD-06、DB2-07、MSG-03 | `已完成` | D2 正确率和 p95 达标，五平台一致性已验证 | 本里程碑提交（2026-07-12） | `message_search_fts` 是可重建派生 FTS5 索引，insert/delete/content-update triggers 保持同步，首次 count drift 时事务重建；普通词用 quoted FTS `AND` query，含 CJK/Japanese/Korean token 确定性走 escaped substring fallback，解决 DB2-07 五平台 `中文` 零命中。默认 SQL join 直接约束 active ancestry，显式 `includeAllRevisions` 才扩大范围；结果携带 conversation + stable revision(messageId) + slot(groupId)，现有搜索点击统一进入 coordinator `openAround`。英文/CJK/更新同步、观测与 timeline 聚焦 15/15、analyze 通过；五平台 FTS5 可用性沿用 DB2-07 5/5 runner |
| OPS-05 | SQL stats 与口径 | PD-07、MSG-03 | `已完成` | current branch/total usage 定义和查询均明确 | 本里程碑提交（2026-07-12） | StatsPage 不再为每个会话 `loadMessages` 并常驻全库对象图。repository 用 active ancestry CTE + SQL GROUP BY 直接返回范围 summary、365 天 heatmap、day/provider trend、model/assistant/topic ranks；另以 message_rows 全 revisions 单独聚合全部生成 message/input/output/cached。页面仅保留天/分组级聚合，用“当前分支 / 全部生成用量”双值明确展示两套口径，日期范围在 DB 裁剪。回归以同 slot v1/v2 证明 active 只计选中 v2、all revisions 计 v1+v2；stats repository/service/page 21/21 与 analyze 通过 |
| OPS-06 | Assets/branch/revision FK、尺寸、缩略图、延迟 GC | MSG-02、TL-06 | `已完成` | 删除消息不扫全库；高 branch-count 会话不逐 branch 重跑完整路径投影；资源 hash/reference 可验证 | 本里程碑提交（2026-07-12） | `deleteRevision` 的 branch 影响检测改为单个集合化 recursive CTE：一次构造 descendants、所有 live branch ancestry 与 parent-branch closure，不再循环调用 projector；200 个派生 branch 删除回归一次得到 201 affected。新增 assets/reference/GC maintenance schema：content hash/path/bytes/宽高/thumbnail 元数据，revision composite FK，link 会取消待清理；unreferenced 只进入 delayed ledger，空闲任务 claim 后删除文件并二次确认无引用才删除 DB 元数据。soft-deleted branch/revision 以 cutoff+limit 小批、branch-first/revision leaf-first 回收并写 audit，不在用户删除事务扫描文件系统。graph/assets 10/10 与 analyze 通过 |
| OPS-07 | 平台安全存储与秘密备份策略 | P0-08、PD-11 | `已完成` | 普通备份移除应用已知认证凭据；五平台 secure storage 通过 | `6c3618b8` + 本里程碑提交（2026-07-12） | 引入 `flutter_secure_storage` 的 Android Keystore/iOS+macOS Keychain/Linux Secret Service/Windows credential protection/WebCrypto 平台实现。Provider/search/TTS/WebDAV/S3 配置以“SharedPreferences 非秘密 shape + secure credential leaf overlay”拆分，global proxy password 完全移出 prefs；首次读取旧明文时先写 secure storage，再持久化 sanitizer 结果/删除 scalar，运行时按 path overlay 水合。provider migration 临时 backup 也只写 sanitized 内容并立即删除。普通备份继续只读取已脱敏 prefs；自由文本按 PD-11 明确不做秘密猜测。credential/settings/backup 聚焦 13/13 与 analyze 通过；无插件测试 runner 仅 memory fallback、绝不退回明文持久化，五平台实际 smoke 纳入 OPS-08 发布矩阵 |
| OPS-08 | 灰度、支持、v2-compatible rollback | OPS-01～07 | `进行中`（实现完成，发布矩阵 1/5） | 迁移/恢复/性能指标达标且回滚演练通过 | 本里程碑提交（2026-07-12） | 新增 secret-free append-only rollout ledger：记录 source/run hash、schema、迁移会话/消息数、warning/recovered/rejected 数与去重冷启动次数，损坏/断链 fail closed；`KELIVO_DATABASE_V2_ROLLOUT_BASIS_POINTS` 以 installation ID 稳定分 cohort。rollback contract 冻结 storage v2、schema 8..8、禁止 down migration/Hive writer。统一 release runner 真机执行 secure-store write/read/overwrite/delete + rollback contract；macOS 26.5.2 PASS，并据首轮 `-34018` 修复 unsigned build 为 login Keychain stdin fallback。Android/iOS/Windows/Linux 尚未执行，故不关闭 OPS-08；详见 [OPS-08 发布能力证据](./baselines/ops-08-release-capabilities-2026-07-12.md) |
| OPS-09 | 移除 Hive/v1 写路径、旧文件和 legacy repository API | PD-10、OPS-08 | `未开始` | 保留期、成功启动、清理授权和支持方案全部满足；新业务无法调用全会话 compact | — | 待退役或先标注 `@Deprecated('legacy/test only')`：`updateMessageOrder`、`updateConversationMessages`、legacy `deleteMessages`、legacy `appendMessageToConversation`；删除后确认生产调用图为零，并清理仅测试依赖 |

## 12. 数据迁移覆盖台账

| 实体/字段 | 来源 | v2 目标 | 转换/异常策略 | 状态 | 验证证据 |
| --- | --- | --- | --- | --- | --- |
| Conversation metadata | Hive / SQLite v1 | `conversations` | ID 稳定；时间转 UTC 微秒；同秒加 ID tiebreaker | `未开始` | — |
| `messageIds` / `message_order` | Hive / SQLite v1 | revision parent path | group 最小 order + timestamp + ID 确定性映射 | `已完成` | MSG-05 adapter deterministic ordering tests |
| `groupId` / `version` | Hive / SQLite v1 | slot/revision | `COALESCE(group_id,id)`；重复/缺口写 warning/rejects | `已完成` | duplicate version 显式 issue + deterministic sparse allocation |
| `versionSelections` / `versionSelectionsJson` | Hive / SQLite v1 | active branch concrete revision + migration issue | 同时按 ordinal/version 解释；冲突保留两候选并标记歧义 | `已完成` | ordinal/version conflict 与 invalid fallback tests |
| `truncateIndex` | Hive / SQLite v1 | context start revision | 落在 group 内记录 warning，不猜测 | `已完成` | inside/out-of-range issue tests |
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
| Timeline profile/anchor | PASS：TargetPlatform widget touch/drag contract；真机交互待发布复测 | PASS：TargetPlatform widget touch/drag contract；真机交互待发布复测 | PASS：主机 unit/widget；mouse/wheel/keyboard/scrollbar/resize contract | PASS：TargetPlatform widget mouse/keyboard/scrollbar contract；真机交互待发布复测 | PASS：TargetPlatform widget mouse/keyboard/scrollbar contract；真机交互待发布复测 |
| Secure storage/backup boundary | 未开始 | 未开始 | PASS：真实 write/read/overwrite/delete；普通备份边界单测 | 未开始 | 未开始 |
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
| R-10 | 测试全绿掩盖需求反例未覆盖 | 高 | 需求矩阵与现有测试 diff | 已发生实例：Phase 4 全量 1274/1274 绿但真机流式+滑动即触发 §10.1 TL-R1/R3。TL-R1～R6 修至 1279/1279 后第一轮真机确认原症状消除，又由第二轮复测发现 §10.2；TL-R7～R13 已逐项补失败回归并修至全量 1288/1288。风险继续保持进行中，直到用户第二轮真机矩阵证明新增测试覆盖实际交互 | `进行中` |
| R-11 | overwrite 直接依次写 settings/DB/assets 形成混合 bundle | 高 | settings、DB、各资源目录 failpoint 与重启指纹 | 同卷 staging + previous + durable receipt + business lease + 启动恢复 | `进行中`：P0-02 应用层实现已移除运行期在线覆盖并完成 operation-ahead 主链；macOS 25/25 forward、两个 terminal projection 各 6/6、rollback 18/18、legacy marker 3/3 高层 SIGKILL，以及 terminal settings 混合态 2/2 跨进程修复均收敛；selected missing/unselected payload 回归通过。风险仍保留为进行中，因为 raw durability、硬件断电、其余 topology、五平台与升级时旧版本进程退出策略属于 OPS/发布门禁且尚未完成 |
| R-12 | 受损 Hive 迁移 ZIP 被严格引用校验整体拒绝 | 高 | 缺 message/orphan 的真实旧备份 fixture | Recovered conversation/rejects adapter，保留原始问题报告 | `未开始` |
| R-13 | 旧 `chats.json`/迁移 JSON 全量解码导致 OOM/主 isolate 卡顿 | 高 | 600–800MB legacy fixture 的 RSS/frame profile | 新备份改 SQLite snapshot；legacy adapter 使用 chunk reader 与增量导入 | `进行中` |
| R-14 | ZIP32 与恢复展开边界导致超大备份失败或磁盘耗尽 | 中 | >4GiB compressed、8GiB 单项、16GiB 总展开 fixture | 当前显式拒绝超限并在写出时计数中止；后续评估 Zip64 和按可用磁盘预算 | `进行中` |
| R-15 | terminal evidence 长期占用空间且 previous settings 含旧凭据 | 高 | completed runs 数量/字节/权限审计 | 0700/0600 受限归档；PD-10 明确保留期、成功启动 acknowledgement 与可恢复清理 | `进行中`：active admission 已释放且 evidence 保留；自动 retention/诊断脱敏尚未实现 |

风险状态表示缓解工作状态，不代表风险是否已经发生。P0-01/P0-02 已开始降低部分风险，但尚未满足整包崩溃安全、旧数据恢复和有界内存验收。

## 18. 当前阻塞与待输入

PD-01/PD-02 已于 2026-07-12 修订，方案与 ADR-0001 均已同步；MSG-R3/R1/R2 自动化实现已完成。Phase 2 的 MSG-04 只待第三轮真机产品矩阵确认，Phase 4 继续等待 TL-R14/R15。完成前 Phase 5 不开工。Windows/Linux 的 `DB2_CAPABILITY_RESULT` 原始行与 TL-08 非 macOS 实机交互仍留在发布门禁。

## 19. 下一步

§10.3 自动化实现已全部收敛，用户决定暂缓第三轮真机四症状矩阵并先执行 Phase 5。Phase 2/4 仍保持“实现完成，待真机确认”，不伪造关闭证据。Phase 5 当前 OPS-01～07 已关闭；OPS-08 实现完成、五平台发布矩阵 1/5，继续 OPS-09 的门禁和 API 退役，但在 OPS-08 其余平台及 PD-10 双条件/授权满足前不物理删除 Hive/v1 evidence。

## 20. 变更日志

| 日期 | 变更 | 工作项 | Commit/PR | 作者 |
| --- | --- | --- | --- | --- |
| 2026-07-12 | 完成 OPS-08 应用实现：迁移后发布 secret-free append-only rollout ledger，冷启动按 process token 去重计数，灰度按 installation ID + basis points 稳定分 cohort；rollback build 明确继续读写 storage v2/schema 8、禁止 down migration/Hive writer。统一五平台 release runner 实测安全存储 CRUD 与 rollback contract；macOS 首轮捕获 Keychain entitlement `-34018`，修为 unsigned macOS 使用 login Keychain 且秘密只经 stdin，复跑 PASS。平台矩阵目前 1/5，Android/iOS/Windows/Linux 未测，OPS-08 保持进行中 | OPS-08、PD-10、R-03 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 MSG-R2：`truncateFuture` 从 ChatActions 显式贯穿 generation service/ChatService/repository；默认 false 的 generation begin 在同一事务 graft 新 assistant 并保留全部后续，true 只创建截断 branch且旧 branch/旧 message rows 完整保留。持久会话不再先调用 `removeTrailingMessages`，临时不落盘会话保留内存截断边界。回归覆盖默认 future/branch 不变、开启设置 active path 截断但旧 branch 可恢复且 message count 不减，以及持久会话永不物理删除的决策；generation/context 18/18 与 analyze 通过。MSG-04 实现收敛，待真机确认 | MSG-R2、MSG-04、PD-01/02、GEN-02 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R14：生成期显式“到底”改为一次 jump，后续只由 layout pin 跟随；普通驱动动画期间 layout pin 挂起。pointer drag 改为手势结束时一次性结算视口意图，move/update 不再发布互斥模式。回归覆盖流式到底随内容增长单调贴 max，以及慢拖多次 move 在结束前 0 次、结束后恰 1 次意图；controller/widget 18/18 与 analyze 通过 | TL-R14、TL-02、TL-04 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R15：programmatic jump 压缩为 spacer 布局与最新输入执行两阶段；执行前底部覆盖变化会重测，cacheExtent 外目标通过 observer index 先促使布局再精确置顶，缺失目标也显式结束而不滞留。回归覆盖 16→80px 动态底部输入仍 ±1px 置顶及 cache 外目标收敛；widget 13/13 与 analyze 通过。Phase 4 实现 8/8，待第三轮真机矩阵关闭 | TL-R15、TL-02、TL-04、Phase 4 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 OPS-01：默认备份保持 SQLite Online Backup + manifest/全 entry hash + 自校验，新增 ZIP64 entry/central/end records，取消 ZIP32 格式上限；恢复仍以显式 entry/total/count 预算防止资源攻击。公开 prepareBackupFile 回归同时验证 ZIP64 签名、archive 解码、manifest hash 与清理；backup/restore 47/47 与 analyze 通过。用户授权暂缓 Phase 2/4 真机矩阵，Phase 5 正式启动 | OPS-01、PD-08、PD-14、Phase 5 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 OPS-02：复用 P0-02 已闭环的 staging/receipt/lease/forward+rollback/cold-ack 整包切换及 240 phases/58 SIGKILL 证据，不重复扩大证明强度。SQLite merge 已是单事务、冲突整会话 remap/report、重试幂等；本里程碑将 settings merge 从逐 key 半提交改为完整预验 + touched-key snapshot 补偿批次，第二个 key 失败后第一个不再残留；assets merge 保持 only-if-absent 幂等。merge/backup/startup 110/110 与 analyze 通过 | OPS-02、PD-09、P0-02 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 OPS-03：新增显式 portable NDJSON v2，默认分页导出 active branch 非 streaming 终态，可选 allRevisions 保留全部 revision shadow；footer 绑定记录数与前文 SHA-256。导入先逐会话写临时 SQLite，完整校验/backfill 后才事务 merge，篡改文件不写 live。ChatService 提供显式 export/import API；旧 chats.json、Cherry data.json ZIP、settings-only 与迁移页 JSON 合同不变。portable/legacy 5/5 与 analyze 通过 | OPS-03、PD-08/09/14 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 OPS-04：建立可重建 message_search_fts 派生索引与 insert/delete/update triggers；普通词走 FTS5 quoted AND，任一 CJK/日文/韩文 token 走 escaped substring fallback，关闭短中文零命中。默认查询在 SQL 内限制 active ancestry，只有显式 includeAllRevisions 才扩域；结果继续携带 stable revision/slot 并复用 openAround 导航。英文/CJK/更新同步、观测与 timeline 15/15、analyze 通过；五平台 FTS5 能力沿用 DB2-07 5/5 | OPS-04、PD-06、DB2-07 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 OPS-05：StatsPage 删除整库 loadMessages/Future.wait，改由 repository 用 active ancestry CTE + SQL GROUP BY 返回 summary/365-day heatmap/day-provider trend/model-assistant-topic ranks，另聚合 all revisions 全部生成消耗。页面常驻量只与天数/分组数相关，并以“当前分支 / 全部生成用量”双值展示。同 slot v1/v2 回归证明 active 只计 v2、all 计 v1+v2；stats 21/21 与 analyze 通过 | OPS-05、PD-07 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 OPS-06：deleteRevision 受影响 branch 检测改为 descendants + branch ancestry + parent closure 单个 recursive CTE，不再对每个 branch 投影完整路径；200 个派生 branch 压测正确一次处理 201 affected。新增 asset content-hash/path/bytes/dimensions/thumbnail 与 revision FK 引用、delayed ledger/claim/recheck/complete 两阶段 GC，以及 soft-deleted branch/revision cutoff+limit 小批 leaf-first GC 和 audit；用户删除不扫文件系统。graph/assets 10/10 与 analyze 通过 | OPS-06、MSG-04、TL-06 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 OPS-07：引入 flutter_secure_storage，Provider/search/TTS/WebDAV/S3 改为 prefs 非秘密 shape + secure leaf overlay，global proxy password 完全移出 prefs。旧明文首读先写 secure storage，再将 prefs 改为 sanitizer 结果/删除 scalar；path overlay 精确水合多 key/嵌套 URI credential。provider migration backup 也只保留脱敏值并删除。普通备份仍不读 secure storage；测试 runner 无插件时只 memory fallback，不回退明文。credential/settings/backup 13/13 与 analyze 通过；五平台实际 smoke 转 OPS-08 发布矩阵 | OPS-07、PD-11、R-09 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 MSG-R1：新增单事务 graft command，创建同 slot sibling 后把 active path 直接 child 改挂到新 revision（leaf 时移动原 branch leaf），映射 boundary 并 CAS 推进 state revision；branch ID/数量与全部后续 slot 不变，旧 revision 保留。稳定 graph edit API 与 Home `appendMessageVersion(user)` 均接入；native same-slot `selectRevision` 也改为 graft-select，切回旧版本不再截断后续，legacy ambiguous 保持安全 branch。两轮红色回归复现编辑/切换的旧截断，绿化后 domain/repository 均保持完整未来。ADR-0001 同步修订，analyze 通过 | MSG-R1、MSG-04、PD-01/02、MSG-01 | 本里程碑提交 + follow-up | Codex |
| 2026-07-12 | 完成 MSG-R3：render model 的版本总数与选中索引改用 coordinator slot 的 DB 权威 `versionCount`/active revision，不再依赖会被窗口 retain 驱逐的 sibling cache；MessageList 的切换器、导航边界与删除全部入口统一读取权威 count，缺失 sibling 继续在用户点击时通过现有异步 group loader 懒加载。红色回归覆盖只剩 active v1、权威 count=2，绿化后立即投影 `<2/2>`；render/controller/widget 64/64 与 analyze 通过。第三轮方案/进度修订一并纳入本里程碑，Phase 2/4 保持进行中 | MSG-R3、PD-01/02、MSG-04、TL-R14/R15 | 本里程碑提交 | Codex |
| 2026-07-12 | 第三轮复审：逐一定位四个用户症状。"仅保存"删下方消息与"重新生成设置失效"根因为 PD-01 纯 fork 语义与既有产品合同冲突——`appendMessageVersion`/`beginRegeneration` 无条件 `createRevisionBranch`/fork 激活新 branch，active path（leaf 祖先链）随即截止于变更 slot，下方消息全部离开时间线（MSG-R1/R2）；切换器不显示根因为 render model 版本数依赖被 `retainTimelineWindow` 驱逐的 `_messagesCache` 而非窗口自带 DB 权威 `versionCount`，且发送/重生成路径不回填 siblings（MSG-R3）；无限跳动根因为流式期间 `animateTo(旧 max)` 与 layout `correctPixels(新 max)` 逐帧对抗，及单次拖拽内 pointer-move `userAnchored` 与贴底判定 `followTail` 交替翻转并销毁生成期 spacer（TL-R14）；发送弹距根因为 jump 管线跨 3 帧使用陈旧 `bottomContentPadding`/键盘 inset/occupied，且目标未布局时静默停摆（TL-R15）。修订 PD-01/PD-02/§7.2/§8.3 为"默认 graft 保留后代、仅删除尾随 fork"（schema 不变），§7.4 补充"同帧唯一执行器"“手势内不翻转意图”“jump 同帧输入"三条合同；MSG-04 重开，§10.3 冻结返工顺序与验收 | MSG-R1～R3、TL-R14/R15、MSG-04、PD-01/02 | 本复审提交 | 用户 / Fable |
| 2026-07-12 | Phase 4 第二轮复审：确认 TL-R1～R6 对原症状有效后，用户真机复测暴露发送弹回与迷你地图断裂。定位发送路径在 programmaticJump 置顶同时两次调度 scrollToBottom（含 120ms 延迟）且程序动画被误判为用户滚动（TL-R7）、spacer 0.75×viewport 上限使置顶物理不可达且"先跳后缩"两阶段必然回弹（TL-R8）、迷你地图依赖被窗口保留驱逐的同步 cache 且 off-window 跳转走 legacy `seed(stateRevision:0)` 触发尾部重建弹回（TL-R9）、revision 变更重建固定回尾部（TL-R10）、generation 信号未按会话隔离（TL-R11）、删除路径绕开 coordinator 产生幽灵复活风险（TL-R12）、"跳到最新"胶囊与既有到底按钮重复（TL-R13）。§10.2 冻结消息系统最终形态五条合同，方案 §7.4 实现要点同步修订 | TL-R7～R13、TL-02、TL-04 | 本复审提交 | 用户 / Fable |
| 2026-07-12 | 完成 TL-R7 实现：发送入口删除调用前/成功后的两处 `onScrollToBottom`，PD-04 的 coordinator programmaticJump 成为本轮唯一滚动所有者，120ms 延迟到底不再夺取锚点。ChatScrollController 不再从 position direction 推测用户意图，新增只由 MessageList 真实 drag/wheel/keyboard 输入调用的显式入口；程序 animate/jump/layout correction 只更新位置与按钮可见性，不发布 userAnchored。红绿回归覆盖发送后 400ms 仍保持 anchored、程序到底动画不产生用户意图、显式真实输入才进入 user scrolling；相关 startup/scroll/widget/platform 23/23 与 analyze 通过 | TL-R7 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R8 实现：programmatic jump 的 provisional spacer 上限由 `0.75×viewport` 改为完整 viewport，最终差额严格为 `viewport − occupied − fixedBottom`；流程拆为“完整 provisional 布局 → 测量并布局最终 spacer → 下一帧 jump”，jump 后不再修改 spacer，生成期继续恒定、终态沿用最小合法残量收敛。定位改用 ScrollPosition 对目标 RenderObject 的 reveal 语义。红绿 widget 回归覆盖带 12 条历史的短/长 user：目标确实到 viewport 顶部 ±1px，之后三帧 offset/top 零漂移，流式正文增长仍不改变 spacer；相关 timeline/scroll/platform 32/32 与 analyze 通过 | TL-R8 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R13：盘点确认右侧 `ScrollNavButtonsPanel` 的到底按钮已是显式恢复尾随入口，补充其点击行为契约；删除 HomePage 的 `showJumpToLatest` overlay 分支、`TimelineJumpToLatest` 实现及固化旧产品形态的测试，不新增替代 UI。方案 PD-05/§7.4/Phase 4 描述统一改为复用既有按钮；widget 2/2 与 analyze 通过 | TL-R13 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R9：数据库 active ancestry page 新增 `aroundRevisionId` 有界游标查询，Coordinator 增加 `openAround(targetRevisionId)` 并在权威 page 原子替换后以 stable slot 发布 programmatic jump。ChatController 的窗口外定位删除同步 `getMessageIndex`/offset 路径，迷你地图与选择地图改为异步 active-graph 全量投影，不依赖窗口 cache；搜索/spotlight 统一经 `scrollToMessageId → openAround`，问题导航在本窗口无相邻 user 时从异步 active timeline 找目标后走同入口。移除 `_loadWindowAroundIndex`、`_loadWindow` 及其物理 offset fallback，窗口外 jump 不再发第二个 observer 动画。红绿回归覆盖 repository around page、coordinator target、500 条会话第 10 条跨窗口定位（同步 index 调用为 0）与 5000 条异步地图不扩张窗口；相关 graph/coordinator/controller/scroll 58/58 与 analyze 通过。持久删除/reload 与 draft-only seed 的最后收口归 TL-R12 | TL-R9 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R10：分页发现 `stateRevision` 变化时，Coordinator 先把 `visualAnchor.slotId` 解析为当前 revision，并通过 `loadAroundPage` 围绕该 revision 重建同等大小窗口；anchor revision 已离开 active path 时回退到本次分页的 stable cursor，而不是尾部。只有未注入 around loader 的兼容测试实例保留 tail fallback，生产 ChatController 始终注入 around loader。重建不进入 programmaticJump、不清 visual anchor，后续仍按 `slotId+localDy` 修正；回归确认请求目标为 anchor revision、重建窗口不含尾部、localDy 修正为 0 且下一次 loadBefore 继续合并。coordinator/graph/controller 51/51 与 analyze 通过 | TL-R10 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R11：ChatController 新增 conversation-aware `publishGenerationStarted/publishGenerationState`，只有 current conversation 与 coordinator conversation 同时匹配事件 conversationId 才能写 generation 生命周期；terminal snapshot 仍可完成自身窗口镜像，但后台会话不能清前台 generation。regenerate/start、无 active message 的 cancel、completed/failed/cancelled/preparation-failed 全部经统一入口，普通 update 同样执行会话校验；snapshot replacement 额外校验 message conversation，避免理论上的跨会话 ID 碰撞。双会话回归证明后台 start/terminal 均不改变前台 isGenerating，前台窗口外 terminal 仍能正确关闭；controller/actions/widget 53/53 与 analyze 通过 | TL-R11 | 本里程碑提交 | Codex |
| 2026-07-12 | 完成 TL-R12 与第二轮自动化收口：Coordinator 新增 mutation refresh，围绕当前 visual anchor 最近存活 revision 通过 stable cursor 原子重建窗口；ChatService 返回实际级联删除 ID，批量/版本/重生成尾部删除据此同步 stream 状态与 slots。退役 `reloadMessages`、`removeMessageIds`、`removeMessagesAfter`、同步 recent-window 和公开 seed；持久会话只能异步打开，空 draft 使用专用 setter。普通、draft、临时会话发送与流式 snapshot 均先写 coordinator，临时会话补同构有界 cursor page 且 retain 不驱逐唯一内存历史。红绿回归覆盖中部删除后模式切换无幽灵、临时窗口/删除/版本投影/发送不旁路；TL-R12 聚焦 83/83、全量 1288/1288 与 analyze 通过。TL-R7～R13 实现与自动化全部闭环，Phase 4 只待用户第二轮真机矩阵 | TL-R12、TL-R7～R13、TL-02、TL-04、R-10 | 本里程碑提交 | Codex |
| 2026-07-11 | Phase 4 复审重新打开：用户真机实测（内容滑动后消失变加载动画、自动滚动小幅弹跳）驱动的行级根因分析确认两个结构性缺陷——流式/终态内容从不写回 coordinator 窗口且任何 coordinator 通知都会用过期 slots 覆盖 `_messages`（TL-R1/R2）、生成期 bottom-pin 与 programmatic anchor+spacer 两套滚动范式并存且 spacer 修正晚一帧（TL-R3/R4），另登记发送闪空（TL-R5）与 stateRevision 分页静默失效（TL-R6）。TL-02/TL-04 状态回退为进行中，§10.1 冻结返工验收标准与顺序，Phase 5 暂缓 | TL-R1～R6、TL-02、TL-04、R-10 | 本复审提交 | 用户 / Fable |
| 2026-07-11 | 完成 TL-R1 实现：新增统一窗口 snapshot 更新入口，同时写入 `ChatController._messages` 与 coordinator slot；ChatActions 的 preparing/regenerate/cancel/chunk/completed/failed 和 HomeViewModel 的 throttled tick/restore cleanup 不再绕开 coordinator 原地改消息。流式高频镜像不发布全窗口通知，终态 notifier 移除前 slot 已含完整正文与 `isStreaming=false`。红绿回归覆盖 partial→`userAnchored`→`loadBefore`→completed→`followTail`，可见正文和 slot 终态均不回退；controller/stream 32/32 与 analyze 通过。真机复测仍作为 Phase 4 总关闭证据 | TL-R1 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 TL-R2 实现：TimelineCoordinator 增加结构窗口 revision，ChatController 仅在 revision 推进时执行 `_syncTimelineWindow`；follow/userAnchored/programmatic/content intent 改为幂等，纯视口通知不再重建 `_messages`、失效 render cache 或通知整页。确定性 profile contract 连续触发 120 次 anchored + 120 次 follow，controller window publish 为 0、coordinator 仅发布两次真实状态转换；coordinator/controller 32/32 与 analyze 通过 | TL-R2 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 TL-R3 实现：生成锚定期 spacer 改为 jump 当帧计算后恒定持有，删除 `SizeChangedLayoutNotifier` 的下一帧收缩链，避免每个 chunk 产生 extent `+X/-X` 振荡；锚定模式与 bottom-pin 互斥，显式 followTail 会移除 spacer，程序驱动的 `UserScrollNotification` 不再冒充用户输入切换模式，真实内容底部判定扣除 spacer 空白。回归覆盖长流式增长两帧 spacer/用户锚点均稳定及程序通知不夺回模式；相关交互 28/28 与 analyze 通过，真机无抖动仍作为 Phase 4 总关闭证据 | TL-R3 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 TL-R4 实现：ChatController 新增 terminal snapshot 收口，preparation failed、completed、failed、cancelled 全路径（包括 terminal persistence 抛错的 finally）先把最终正文/`isStreaming=false` 镜像进窗口，再移除窄流式 notifier，并无条件关闭 coordinator generation；窗口外终态同样清标记。regenerate 开始显式重新打开 generation。MessageList 在终态帧一次性计算避免 offset clamp 所需的最小残余 spacer，正文足够时直接归零，显式 followTail 必定清零；回归覆盖终态内容、窗口外终态和锚点无跳动。相关 controller/widget/actions 52/52 与 analyze 通过，真机仍为总关闭证据 | TL-R4 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 TL-R5 实现：`TimelineCoordinator.open()` 对同一会话改为 stale-while-revalidate，数据库 tail page 返回前保留当前 slots、分页标记、generation 与视觉锚点，不推进 window revision、也不通知 ChatController 清空窗口；新 page 到达后原子替换。发送仍需 tail query 获取权威 graph identity，但等待期间旧窗口持续可见，因此不再出现同步空列表帧。Completer 回归锁定 refresh 未完成时 slots/revision 不变、完成后只发布一次新窗口；coordinator/controller 34/34 与 analyze 通过 | TL-R5 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 TL-R6 实现：`loadBefore/loadAfter` 发现 page `stateRevision` 已变化时不再静默返回 false，而是在同一 request epoch 内重新读取权威 tail window、更新 revision/total、保留 visual anchor 并原子发布；重建后的下一次分页继续使用新 cursor/revision。回归模拟 regenerate/edit 式 graph mutation，验证第一次触发三次请求完成自愈、anchor 仍为原 slot，随后向上分页正常合并。coordinator/controller 35/35、analyze 与全量 1279/1279 通过；TL-R1～R6 自动化实现闭环，Phase 4 只待用户真机矩阵 | TL-R6、Phase 4 rework | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 generation terminal 收口：新增单事务 final command，把最终 legacy shadow、graph parts、tool events、最后 checkpoint seq、兼容 active receipt 清理和 run terminal CAS 一起提交；准备失败不伪造 checkpoint，terminal CAS 故障整包回滚，late checkpoint 不能覆盖 final。ChatActions 持有 run state/revision cursor，complete/failed/cancelled 均经 final barrier；错误详情只走 UI error channel，正文保留真实 partial 或空串；所有 loading/notifier/iOS/runtime cursor 清理置于 finally，持久化失败也不永久 loading | GEN-04 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 generation 三链解耦：stream listener 不再 pause/resume source，网络事件只进入本地 FIFO，由单 consumer 顺序处理，terminal event 排在已接收 chunk 后；UI 继续 50ms coalesced、DB 继续 250ms latest-wins/final barrier、iOS 继续 500ms latest-wins，三者不阻塞网络读取。run 在请求/首 chunk 以 CAS 进入 requesting/streaming；checkpoint cursor 单调前进，message/graph parts/tool snapshot 与 `checkpoint_seq` 同事务，stale checkpoint 失败时正文也回滚 | GEN-03 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 atomic generation begin：persistent send 的 user/assistant legacy shadow、graph slots/revisions/parts、branch/state、兼容 active receipt 和 preparing run 在同一外层事务提交；regeneration 的 alternate revision/native branch/run 同事务提交。ChatService commit 后才发布 cache，ChatActions 将 user/assistant pair 作为一次 tail mutation，避免原子落库后被逐条 UI 更新误判为缺口；重复 run ID fault 证明所有 message/part/branch/state 回滚。temporary conversation 保持明确的内存路径 | GEN-02 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 GenerationRun kernel：schema v7 新增 target composite FK、8 状态与时间/error CHECK、state revision/checkpoint 非负约束、active-target partial UNIQUE 和恢复查询索引；冻结 v7 JSON/generated schema 与 1→7 任意起点 migration。新增不可变 run model 和 repository commands，合法边由冻结状态图校验，持久更新以 state + stateRevision CAS，竞争 terminal 只有一个成功且 terminal 不可回退；raw snapshot 结构/FK 同步纳入验证 | GEN-01 | 本里程碑提交 | Codex |
| 2026-07-11 | 记录 Phase 2 后三项非阻塞债务：`deleteRevision` 受影响 branch 检测的 `O(branch × path)` 成本归入 OPS-06 branch/GC；四个旧 compaction/legacy repository API 归入 OPS-09 显式退役清单；`message_rows`/`message_part_rows` 正文双写明确为 GEN-05 前的 repository-only 过渡态，GEN-05 必须完成 parts 唯一权威切换 | MSG-04、GEN-05、OPS-06、OPS-09 | 本台账提交 | Codex |
| 2026-07-11 | GEN-05 完成 schema v8 ordered parts/provider artifacts 权威切换：tool/reasoning/text 与 generation checkpoint/final 同事务，Gemini signature final barrier 同事务；legacy body/signature/tool 表降为兼容 shadow，并以 shadow 篡改反例证明正常读取只认 parts/artifacts | GEN-05 | 本里程碑提交 | Codex |
| 2026-07-11 | GEN-06 删除 active ID JSON 真相源：启动恢复以 generation run 为唯一输入，在一个事务内 terminalize 所有非终态 run、保留 partial parts、关闭 streaming projection；legacy meta key 只读清扫不再写入 | GEN-06 | 本里程碑提交 | Codex |
| 2026-07-11 | GEN-07 完成 generation 竞态/长响应矩阵并修复 cancel 后本地队列迟到写：cancel barrier 等待在途 handler、丢弃 queued chunks；1 MiB 阻塞 checkpoint 压测证明网络持续读取、latest-wins 两写收敛。结合 terminal CAS、startup interruption 与既有 macOS profile，Phase 3 以 analyze + 26 项聚焦 + 1240 项全量通过退出 | GEN-07、Phase 3 | 本里程碑提交 | Codex |
| 2026-07-11 | TL-01 先冻结 Timeline Coordinator 数据契约：active ancestry recursive cursor page 以 slot 为单位，500 revisions 不占 page 容量；service 批量装配 selected message，coordinator 不接触 OFFSET。顺手修复 stream error handler 二阶失败，改为可观测报告且不形成未处理异步错误 | TL-01、GEN-07 follow-up | 本里程碑提交 | Codex |
| 2026-07-11 | TL-02 将 stable cursor 接入 ChatController 主分页，并在 coordinator 落成 slot+decoded-byte 双预算、conversation epoch 取消、同向 single-flight 和窗口外 cache 释放；初始页固定 40 logical slots，head/tail/before/after 不使用 OFFSET，500 revisions 仍占一行 | TL-02 | 本里程碑提交 | Codex |
| 2026-07-11 | TL-03 以 slot ID + viewport localDy 替换 content extent 差值锚点：MessageList 双向分页统一 capture/restore，同 slot correction 精确到 ≤1 logical px；item key 稳定为 slot ID，双预算裁窗主动避开当前视觉 anchor | TL-03 | 本里程碑提交 | Codex |
| 2026-07-11 | TL-04 落成 followingTail/userAnchored/programmaticJump/loading 滚动意图状态机：用户离底后 stream 仅累计未读并显示带生成态的“跳到最新”胶囊；发送新轮次与重开会话按 stable user slot 定位顶部，显式到底才恢复尾随；分页 loading 不丢原滚动意图 | TL-04 | 本里程碑提交 | Codex |
| 2026-07-11 | TL-05 将 stable slot 的 versions/selection/context divider/latest assistant 一次性预计算为 `MessageRenderModel`；row builder 不再扫描全列表或排序版本，Settings/Assistant provider 订阅提升至列表边界，stream 与非 stream slot 分别由 message notifier 和 stable RepaintBoundary 隔离刷新 | TL-05 | 本里程碑提交 | Codex |
| 2026-07-11 | TL-06 将长 streaming Markdown 拆为 fence-aware stable blocks，仅重建最后一个未闭合 block；1 MiB append scanner 为线性累计工作量。新增 decoded-byte LRU 并迁移 Markdown normalization 与 Mermaid bitmap，图片按布局尺寸×DPR resize，带原始宽高的 Markdown 图片固定预留尺寸 | TL-06 | 本里程碑提交 | Codex |
| 2026-07-11 | TL-07 为 D5 建立硬渲染边界：1,000 行表格首批 40 行并按 100 行分页，10,000 行 code 按 200 行 chunk 在固定 lazy viewport 中构建，超大 tool arguments/result 默认 40 行 preview、展开后按 40 行/16 KiB chunk 虚拟化；导出/复制仍保留全量原文 | TL-07 | 本里程碑提交 | Codex |
| 2026-07-11 | TL-08 完成 5/5 TargetPlatform 交互契约矩阵：移动 drag-dismiss、桌面 manual keyboard/scrollbar、Arrow/Page/Home/End、wheel/selection/right-click/navigation 均与 followingTail/userAnchored 合同一致；窗口与软键盘 metrics 变化接入统一 slotId+localDy 恢复，折叠/跳转控件补齐 expanded/live/button semantics。根目录 analyze 全绿、全量 1270/1270；真实非 macOS 交互明确留在发布门禁而未虚报 | TL-08、Phase 4 | 本里程碑提交 | Codex |
| 2026-07-11 | 修复 TL-04/08 接线造成的真实启动崩溃：`HomePageController._initialize` 原先在 `_chatController` 赋值前构造 scroll callbacks，启动即触发 `LateInitializationError`；现仅交换 controller/scroll 两个初始化步骤，并新增直接构造控制器的启动回归。根目录 analyze 与全量 1271/1271 通过 | TL-08 follow-up | 本里程碑提交 | Codex |
| 2026-07-11 | 修复 TL-02 retained-window 回归：cache retainer 曾把仍需接收 generation begin/append 的 `_messagesCache` 写成 fixed-length，导致下一轮发送在数据库原子 begin 已提交后、内存发布 `addAll` 时抛 `Unsupported operation`，继而表现为旧正文重载后复现和幽灵 loading。裁窗结果现保持 growable，并新增真实 ChatService 序列锁定“load→retain→begin send→user/assistant pair 可见”；定向 29/29、analyze 与全量 1272/1272 通过 | TL-02、GEN-02 follow-up | 本里程碑提交 | Codex |
| 2026-07-11 | 修复 programmatic jump 的两阶段回归：第一版在 target 清空时直接删除 spacer，短回复会“顶上去又弹回来”；后续固定保留 `0.85 × viewport` 又导致自动滚动落入大片空白、消息/正文被推离视口。最终实现改为会话绑定的动态差额并把上限降为 `0.75 × viewport`：测量 user anchor 到当前回复尾部的实际高度，只补足剩余空间，streaming 尺寸增长时等量收缩，长回复降到基础 16px，user 屏幕位置保持在 1px 内；generation 终态或切会话清零。page replace 仍从 streaming slot 推导 `isGenerating`，覆盖首 chunk 前与重开活跃会话。核心 19/19、相关交互 26/26、analyze 与全量 1274/1274 通过 | TL-04 follow-up | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 graph 业务切换：新增不可变 timeline/parts projection，selection/context/search/count 不再读取旧 conversation JSON/list 字段；正式 Hive migration 在 mark complete 前逐 conversation 生成 graph 与 ledger，开发 SQLite v1/旧 JSON 只走显式 best-effort adapter。普通 append、edit/regenerate、stable revision selection、context boundary、sparse delete、fork 与 streaming/final checkpoint 同步 graph；inactive alternate 删除保留物理 order 缺口且不调用 compact。controller fork/selection 提交 stable revision ID，旧字段限制在兼容 model/adapter/迁移与备份边界。Cherry/legacy JSON/overwrite 兼容回归、database 113/113、全量 1216/1216、analyze 全绿，Phase 2 7/7 关闭 | MSG-07、Phase 2 | 本里程碑提交 | Codex |
| 2026-07-11 | 冻结真实 legacy fixture/digest：新增 released Hive backup JSON projection fixture，包含物理尾部旧 assistant alternate、ordinal/version selection 冲突、truncate 落 group 内、reasoning/text part、asset path 与 streaming orphan。fixture 直接走 Hive model JSON adapter，并另写入 frozen SQLite v1 schema 后读回走同一 adapter；两路径 active IDs/context 一致。冻结 visible/selection/prompt/asset 四个 SHA-256，验证旧可见序列、selected revision、stable prompt boundary、part order、资源引用和 Recovered orphan，不比较无法获知的 native ancestor history | MSG-06 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 deterministic legacy graph adapter 与审计 ledger：Hive/SQLite v1 共用 typed ordered-message input，slot/group/revision stable ID 与排序确定；selection 同时按 ordinal/version 解释，歧义保留两候选并沿旧 UI ordinal 可见投影，非法值 latest fallback，均写 issue。duplicate ID/order/version、truncate 落 slot/越界、streaming partial、cross-conversation orphan reject 与显式 Recovered conversation 均覆盖；v6 新增 migration run/issue 表，graph/parts/issues 单事务替换并由 projector 复验。所有 legacy branch 仅标 `legacy_visible_projection`/`legacy_ambiguous` | MSG-05 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 graph transaction commands 与最小权威 text part：schema v5 新增 `message_part_rows` composite FK、unique ordinal、kind/time CHECK 和逐版本 migration；edit user/regenerate assistant 原子创建 revision+part+native branch 并切 active state，旧 branch/后代保留且不进新 prompt；selection 只接受 stable revision ID；delete 仅递归标记目标因果子树及受影响 branch-parent 子树，自动选最新 alternate或经确认截断到 parent，未调用 `_rewriteMessageOrder`。200 个无关 alternates 的删除反例证明只标记目标 1 revision；fork 单事务 remap 截止 target 的 slot/revision/parts/context | MSG-04 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 active path/context projector：branch leaf 使用 recursive CTE 获取有限 ancestry set，再按 parent stable ID 重建 root→target 路径；支持指定历史 target 并证明未来 revision 不进入结果。active context boundary 使用 revision ID，repository 在同一事务以 state revision 乐观条件更新，幂等不增 revision、冲突/alternate boundary 不落库。深度验证覆盖 revision/branch cycle、同 path 重复 slot、missing/deleted node、fork point 不在 parent/child path及 persisted boundary 漂移；raw snapshot 结构验证补齐全部 v4 graph tables/columns/composite FK | MSG-03 | 本里程碑提交 | Codex |
| 2026-07-11 | 完成 v4 Message Graph kernel schema：新增 conversation state、branch、slot、revision 四表和 frozen schema/generated migration helper；v3→v4 原子建表，旧 v3 行原样保留作为未发布开发库 adapter 输入。稳定 identity、稀疏 revision number、同 conversation slot/parent/branch/leaf/context composite FK、role/causality/time/state CHECK、UNIQUE 与 ancestry/slot/branch 索引落库；跨会话、自引用、非法枚举/时间、级联和 query plan 反例覆盖。无环、同 path slot 唯一和 boundary membership 明确留给 MSG-03 transaction validator | MSG-02 | 本里程碑提交 | Codex |
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
