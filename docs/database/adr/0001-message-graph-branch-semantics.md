# ADR-0001：消息图分支、版本选择与删除语义

- 状态：`已接受`
- 日期：2026-07-11
- 修订：2026-07-12（PD-01/PD-02 改为默认 graft、显式截断才 fork）
- 工作项：`MSG-01`
- 决策来源：`PD-01`、`PD-02`、`PD-04`
- 后续实现：`MSG-02`～`MSG-07`

## 背景

旧消息模型把会话表示为物理消息列表，并用 `groupId`、版本号、数组下标和 conversation JSON selection 共同解释“当前版本”。这个模型无法可靠回答一条 revision 的真实 parent，也会让编辑旧消息或重生成旧回答时，把旧未来轮次错误地带入新 prompt。

本 ADR 把已经冻结的产品决策转成 schema、领域 command 和 UI 投影都能直接执行的语义。若后续实现需要偏离本文，必须先修订 ADR 和重构方案，不得只在 controller 或 repository 中增加例外。

## 决策

### 1. 身份与因果关系

- conversation、branch、slot、revision 都使用稳定且互不混用的 ID。
- slot 是时间线中的稳定逻辑位置，也是 UI item identity；切换同一 slot 的 revision 不改变 slot ID。
- revision 是一个 slot 的具体内容版本。`revision_no` 只用于显示和排序，允许有缺口，不能作为 selection、parent、cursor 或 context boundary。
- 每个 revision 至多有一个 `parent_revision_id`。parent 必须属于同一 conversation，并构成从 branch leaf 到 root 的无环链。
- branch 是一条因果路径的可恢复 head，只保存 leaf 和 fork 元数据，不复制共同祖先正文。
- active branch 的 leaf 沿 parent 反向遍历并反转，就是唯一 active path；同一路径不得出现同一 slot 的两个 revision。
- selection 不再单独保存为 ordinal/version JSON。一个 slot 在 active path 上实际出现的 revision，就是该 branch 对该 slot 的选择。

### 2. 新轮次发送

发送永远追加到当前 active branch leaf：

1. 新 user revision 的 parent 指向原 active leaf；
2. 新 assistant revision 的 parent 指向新 user revision；
3. active branch leaf 移到 assistant revision；
4. 数据事务只负责图状态；GenerationRun 的创建和状态机由 `GEN-01/02` 完成。

用户即使正在阅读历史位置，普通“发送”也不从视口位置 fork。UI 在 `TL-04` 中 programmatic jump 到新 user slot 顶部附近；视口位置不是数据库因果输入。

### 3. 重生成 assistant

重生成 assistant 复用原 assistant slot并创建 sibling revision。默认设置 `regenerateDeleteTrailingMessages=false` 时执行 graft：新 revision 的 parent 等于旧 revision 的 parent，active path 上旧 revision 的直接 child 改挂到新 revision，active branch 与全部后续 slot 保持不变。设置开启时才执行截断 fork：创建以新 revision 为 leaf 的 native branch并激活，旧 branch 和旧后续完整保留，不先物理删除尾随消息。

示例：

```text
旧 branch: U1 -> A1(v1) -> U2 -> A2
默认重生成 A1:
active branch: U1 -> A1(v2) -> U2 -> A2

开启删除尾随后重生成 A1:
new branch: U1 -> A1(v2)
```

无论 graft 还是 fork，新生成请求的 prompt 只能包含目标 slot 之前的真实祖先与新 revision placeholder，不得把 graft 后保留的 `U2/A2` 当成生成输入。

### 4. 编辑 user

编辑 user 时执行 graft：复用原 user slot创建 sibling revision，新 revision 的 parent 等于旧 revision 的 parent，active path 上旧 revision 的直接 child 原子改挂到新 revision；若目标是 leaf，则 active branch leaf 改为新 revision。branch ID 不变、旧 revision 保留、后续 slot 原样保留，conversation state revision 只推进一次。新 assistant placeholder/run 属于 `GEN-02`，不在纯编辑 command 中制造半个生成状态。

示例：

```text
旧 branch: U1 -> A1 -> U2(v1) -> A2 -> U3 -> A3
编辑 U2:
active branch: U1 -> A1 -> U2(v2) -> A2 -> U3 -> A3
```

UI 保持被编辑 user slot 的锚点；锚点行为由 Timeline Coordinator 实现，不改变图语义。

### 5. 切换 revision

用户在 `< n/m >` 控件选择同 slot 的另一个 native revision 时，输入必须是目标 revision ID，并执行 graft-select：目标 revision 必须与当前 on-path revision 同 slot；把当前 on-path revision 的直接 child 改挂到目标 revision，或在该 slot 为 leaf 时更新 active branch leaf。下方 slot、active branch ID 与视口逻辑 identity 均不改变，只推进 state revision。legacy ambiguous alternate 因 parent 不可证明，仍按安全边界创建截止于目标 revision 的 branch，不得猜接后续。

### 6. 删除

删除请求先计算所有 ancestry 包含目标 revision 的 branch；物理行可延迟 GC，但这些 branch 必须在同一事务中退出可导航集合，不能留下引用已删除内容的可见 path。删除分为三种显式语义：

1. 删除不在 active path 的 revision：移除受影响的非 active branch head并把目标/依赖段送入延迟 GC；当前 active path 不变。
2. 删除 active path 上、且同 slot 仍有其它 revision：选择 `revision_no` 最大的有效 alternate，按其真实 ancestry 创建/切换修复 branch；依赖已删除 revision 的旧 branch 段退出可导航集合。
3. 删除 slot 的最后一个 revision：调用方必须先获得“将同时移除依赖它的后代 branch 段”的显式确认；事务修复或移除受影响 branch head，并选择仍有效的 active head。

任何删除都不得调用旧 `_rewriteMessageOrder`，不得把整个会话 compact 为 `0..n-1`，不得让写入量随无关的会话消息总数线性增长。稳定 slot/revision ID 永不因删除重排；物理 GC 延迟批量执行并保留审计入口。

### 7. Fork conversation

fork conversation 接受稳定 source branch/revision ID：

- source revision 必须位于指定 source branch 的 ancestry；
- 新 conversation 只包含截止 source revision 的路径语义，不包含其后代；
- 初始实现可以批量克隆图元数据和权威 parts，但必须在单事务中完成，失败不能留下半个 conversation；
- 新实体 ID 必须属于新 conversation，所有 composite FK 仍需成立。

### 8. Context boundary

- boundary 保存稳定 `context_start_revision_id`，不保存 `truncateIndex`。
- boundary 为空表示从 root 开始；非空 boundary 必须位于当前 active branch ancestry。
- prompt projector 从 leaf 追溯，到 boundary 为止（包含 boundary）后反转，再应用 token budget。
- 切 branch 后若旧 boundary 不在新 ancestry，事务必须清除它或替换为新 path 上经用户/策略明确指定的 revision；不得按数组位置猜测。

## 事务和分层边界

- UI/ViewModel 只提交稳定 ID command 并消费不可变投影，不计算 parent、不解释 legacy selection，也不执行多步数据库写入。
- repository/domain command 在一个事务内校验 conversation 归属、path、active state version，并完成 branch/state 变更。
- projector 只从数据库图生成 active path/context，不依赖当前 UI 窗口或物理行顺序。
- migration adapter 可以产生 `legacy_visible_projection` 或 `legacy_ambiguous`，但不得把未知 parent 宣称为 native 因果关系。
- GenerationRun、stream checkpoint 和终态转移属于 Phase 3；Timeline anchor 和分页属于 Phase 4。

## 必须由 schema/事务强制的不变量

1. 所有跨表 graph 引用包含 conversation ID 的 composite FK。
2. 同一 slot 的 revision number 唯一但允许缺口。
3. branch leaf、fork revision、revision parent、context boundary 不得跨 conversation。
4. branch/revision ancestry 无环。
5. 一个 active path 内同一 slot 最多出现一次。
6. conversation state 的 active branch 与 context boundary 必须引用同一 conversation。
7. command 使用 state revision 做并发条件更新或在同一 writer transaction 中串行化。

SQLite FK/CHECK 能直接表达 1～3 和 6；4～5 必须由事务验证和候选库完整性检查共同强制。

## 验收实例

| 操作 | 新 active path | 必须保留 | 禁止行为 |
| --- | --- | --- | --- |
| 普通发送 | 原 leaf + 新 user + 新 assistant | 原 branch ancestry | 从当前视口位置隐式 fork |
| 默认重生成旧 assistant | 原 active path，以新 assistant revision 替换同 slot | 旧 revision 与全部后续 slot | 从 active timeline 移除后续或把后续加入 prompt |
| 删除尾随重生成 | 目标 parent + 新 assistant revision 的新 branch | 旧 branch、旧 revision与旧后续 | 先物理删除尾随再 fork |
| 编辑旧 user | 原 active path，以新 user revision 替换同 slot | 旧 user 与全部后续 slot | 原地覆盖正文或截断 active path |
| 切换 revision | 原 active path，以目标 sibling 替换同 slot | 其它 sibling 与全部后续 slot | 按 ordinal 猜 selection或切断后续 |
| 删除当前 revision | 最新有效 alternate 的真实 path | 不受影响 branch | 全会话 order compact |
| 删除最后 revision | 经确认后修复受影响 branch | 不受影响 branch | 静默级联或留下悬空 head |
| fork conversation | source path 截止目标 revision | source conversation 全部数据 | 复制 source revision ID 到新 conversation |

## 后果

正面影响：prompt 因果关系可证明；版本选择、删除和分页使用稳定 ID；默认编辑/重生成保持 Kelivo 既有“slot 版本 + 后续保留”合同，显式截断仍有可恢复 branch；UI slot identity 与 revision 数量解耦。

成本：schema 和 migration 更复杂；branch 无环、path slot 唯一需要事务级验证；legacy 数据只能声明可见投影，无法恢复未知真实因果；旧 controller/list 读取必须在 MSG-07 退役。

## 不在本 ADR 范围

- GenerationRun 完整状态机与网络流协调；
- Timeline 的窗口、滚动和像素锚点实现；
- branch-aware 搜索、统计和延迟资源 GC；
- legacy adapter 的具体批处理与 rejects 文件格式。
