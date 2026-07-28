# 聊天记录缓存与加载优化方案

> 状态：全部落地 —— P0（措施 1-6）、P1（措施 7/8/9/11/13 + 12.1/12.4 骨架；措施 10 随 C2 作废；12.2/12.3 按用户决定回退）、P2（措施 14 桌面 hover 预取+启动预热、15 滚动渲染缓存、16 侧栏 conversationListRevision 精细订阅、17 checkpoint 减写两步含崩溃回补）均已实施，经全量测试（1479 个）与对抗评审；措施 18 为数据驱动候选项，留待后续立项
> 范围：`ChatService` 内存缓存、DB 读写路径、会话切换/启动流水线、消息列表与侧边栏渲染
> 产出方式：6 路子系统深读 → 51 个问题合并去重为 12 条 → 逐条对抗验证（12/12 确认，含精度修正）→ 三角度方案设计 + 交叉评审综合

## 1. 背景与结论先行

用户的抱怨：**"聊天记录缓存现在有问题"**

扫描验证后的结论是：这个抱怨不仅成立，而且低估了问题——当前实现下缓存对"打开会话"这一最高频操作**收益为零**，原因有三层：

1. **缓存被写空（bug）**：打开会话的加载路径 `loadTimelinePage` 从不先加载消息顺序骨架 `_messageOrderIds`，而 `_cacheLoadedMessages` 以该骨架取交集重建缓存——首次打开会话时骨架为 null，交集为空，**刚从 DB 读出的 40 条消息被写成空列表**，根本没进缓存（问题 1）。
2. **缓存只写不读（架构缺陷）**：即使缓存里有数据，`loadTimelinePage` 也无条件直查 DB，`_messagesCache` 在打开/翻页路径上只被回填、从不被消费。切回 1 秒前刚看过的会话，仍是全额 DB 冷加载（问题 2）。
3. **没有预取/补全（策略缺失）**：`setCurrentConversation` 只记录 ID；选中会话后没有任何后台补全或相邻会话预取，缓存常年只有 40+20n 的分页残片，导致依赖"全量缓存"的功能（摘要、建议、`loadMessages` 命中）连锁失效（问题 3/5）。

在此之外，DB 读写放大（每页 O(N) 版本折叠、每次发送 360 条整窗重载、流式 checkpoint 全删全插）、切换会话的纯串行流水线、以及 UI 层的过度重建，共同构成了"感觉有挺多问题"的全貌。

本方案按 P0（止血）/ P1（削减放大 + 加载可见化）/ P2（预取与渲染收敛）三阶段推进，每项措施可独立提交、独立回滚；架构级深水区改动（缓存 Store 收敛、timeline 影子表、DB 读写分离）明确列为**数据驱动的候选项**，不预先承诺。

## 2. 现状架构速览

```
UI（MessageListView / SideDrawer / ChatMessageWidget）
  ↓ 消费 ChatController 的窗口投影（_messages，上限 360 条）
ChatController / HomeViewModel / HomePageController
  ↓ loadTimelinePage(初始 40 slot，翻页 20)          ←—— 打开会话唯一路径
ChatService（内存缓存层）
  _messagesCache        按会话消息列表（LRU，720 条 / 8MB，当前会话豁免）
  _conversationsCache   全部会话摘要（启动时全量加载）
  _messageOrderIds      每会话消息 id 顺序骨架（懒加载）
  _messageCounts / _toolEventsCache / _geminiThoughtSigsCache / _firstGroupIndicesCache
  ↓
ChatDatabaseRepository → drift/SQLite（单后台 isolate 单连接，WAL + synchronous=FULL）
```

关键常量（`chat_service.dart:68-75`）：初始窗口 40 slot、翻页 20、控制器窗口上限 360、缓存 720 条 / 8MB。

## 3. 已确认的问题清单

以下 12 条全部经过"读者发现 → 独立怀疑者逐条反驳验证"流程确认，描述均为验证修正后的准确机制。

### 3.1 缓存核心（用户抱怨的直接根源）

**问题 1【高】打开会话时缓存被写成空列表**
`loadTimelinePage`（`chat_service.dart:278-351`）不调用 `_loadMessageOrder`；`_cacheLoadedMessages`（`:506-522`，关键在 `:517` 的 `?? const <String>[]`）以 order 为骨架取交集重建缓存。首次打开会话（order 未加载）或 `deleteMessages` 之后（`:2779-2780` 丢弃 order）时，交集为空，`_messagesCache` 被写成 `[]`——刚从 DB 读出的 40 条不进缓存。次生深坑：`loadMessages`（`:747`）全量写缓存但**不回填 order**，之后任意一次翻页会把整个全量缓存清空归零。UI 不因此白屏（`ChatController` 用返回页维护自己的 `_messages` 窗口，`chat_controller.dart:206-219`），受害的是服务层缓存与全部同步 getter。对照组：`loadMessagesRange`（`:926`）与 `loadMessagesForGroups`（`:681`）都正确地先加载 order。

**问题 2【高】打开/翻页路径从不读缓存，缓存只写不读**
`ChatController` 的会话打开（`_loadInitialMessageWindow`，`chat_controller.dart:196-204`）与全部四个翻页方法都经 `loadTimelinePage` 无条件冷查 DB：`loadLinearMessageWindow` + `getMessagesByIds` 串行两轮，再加 `_cacheMessageArtifacts`（`chat_service.dart:492-495`）并行两个 artifacts 查询——共 4 个查询、约 3 轮串行跨 isolate 往返。`_messagesCache` 在此路径只被回填。唯一例外是临时/draft 会话（`:287-295` 走纯内存分页 `_loadTemporaryTimelinePage`），恰好证明"从缓存合成 timeline 页"技术上完全可行。

**问题 3【高】同步 getter 无完整性语义，多个功能拿到错误数据**
`getMessages`/`getMessagesRange`/`getRecentMessages` 无法区分"空会话"与"未加载"，长会话切入后缓存只有尾部 ~40 条，按"全量列表"消费的调用方全部静默出错：
- **会话摘要永久停更**：`home_view_model.dart:1210` 用全量计数判触发、`:1247` 用窗口缓存取内容、`:1262` `take(lastSummarizedMessageCount)` 绝对索引错位——长会话下新用户消息集恒空，摘要不再更新；
- **聊天建议永不落库**：`:1366-1370` 的 `getMessageCount != msgs.length` 校验在窗口化缓存或任何多版本会话下恒不等，生成的建议被静默丢弃；
- **清空上下文计数不准**：`:1059-1069` 窗口列表配全量 truncateIndex，计数偏小或偏大。
（验证修正：reasoning 回捞、版本计数、`getConversation` 三个子项不成立或已有补偿，不列为问题。）

### 3.2 DB 层

**问题 4【高】分页读路径每页对整会话做 O(N) 工作**
`loadLinearMessageWindow`（`chat_database_repository.dart:1654-1813`）的三层 CTE（group_rows → ranked → ordered）每次分页都对**整个会话的全部 revision** 重算分组、版本折叠、ROW_NUMBER 编号与 COUNT(*) OVER() 总数；JOIN 谓词 `COALESCE(m.group_id, m.id)` 是表达式，用不上 `idx_messages_group`。翻一页 40 条的代价与会话总长成正比。次要放大：legacy 双表回退（`:4119-4127`、`:4184-4194`）把"没有工具事件的正常消息"也当作缺失，几乎每页多发 2 条回退查询；`getMessagesRange` 用 OFFSET（深页 O(offset)）。（验证修正：probe 双跑只存在于生产无调用方的 `loadActiveTimelineMessages` 与低频 fork 路径；发送上下文实际走 `getSelectedContextMessages` 单条限量 SQL，不存在"整会话 hydrate"。）

**问题 5【高】`loadMessages` 全量读几乎永不命中，被多处为小需求调用**
命中条件 `cached.length == getMessageCount`（`chat_service.dart:726`）对超过窗口的会话恒 miss → 全表读 + 整体替换缓存（且不回填 order，与问题 1 联动）。浪费型调用方：侧边栏手动重生成标题（`side_drawer.dart:667`，为 3000 字符 prompt 全量加载整会话，且与自动标题实现不一致——不应用 truncateIndex）；批量删除计划（`home_view_model.dart:636`，只需选中组却全量物化）；三个导入器 merge 分支（`data_sync.dart:1620`、`cherry_importer.dart:972`、`chatbox_importer.dart:255`，对全库每个会话 loadMessages 只为取 id，`repo.getMessageIds` 已存在可直接替代，且遍历会把非当前会话缓存冲刷一遍）。（验证修正：自动标题有"已有自定义标题即早退"守卫，实际通常只在首条回复后触发一次；"完整历史上下文每次发送全表读"不成立。）

**问题 6【高】流式写放大 + 单连接串行，写事务让读排队**
每个 streaming checkpoint（经 `LatestWinsCheckpointWriter` 节流，约 250ms 一次）：UPDATE `message_rows` 写入累计全文 → DELETE 该 revision 全部 parts 后逐条重插（`chat_database_repository.dart:2941-3018`）→ FTS5 触发器对旧全文 delete + 新全文 insert 整段重分词（`:2685-2696`）→ `synchronous=FULL`（`app_database.dart:619`）每次 commit 都 fsync。对长回复累计代价近似 O(长度²/节流间隔)。且 `NativeDatabase.createInBackground` 单连接（`:595-626`），流式期间的每个写事务都让切换会话/翻页的读在同一队列排队——WAL 的一写多读能力完全未被利用。（验证修正："每 tick 读写"不成立——`updateMessageSilent` 无调用方，实际路径无 read-before-write。）

### 3.3 交互流水线

**问题 7【高】切换会话纯串行且无任何加载反馈**
移动端时序（`home_page_controller.dart:836-876`）：flush 会话进度 →（同 id 短路检查竟在 flush 之后，点当前会话也白跑一次）→ **180ms 淡出动画 await 完成后才开始查 DB** → `HomeViewModel.switchConversation`（`home_view_model.dart:712-740`）内**再 flush 一次**（`:716`，与 `hpc:838` 重复）→ 串行 `await setCurrentAssistant`（偏好持久化）→ 40 条窗口 DB 加载 → endOfFrame + settle（最多 3 帧 attach + 4 轮 jumpToItem）→ 180ms 淡入。全程列表 opacity=0，典型总延迟 450-900ms 纯空白。桌面端跳过动画但裸 await，无任何 loading 指示，DB 延迟直接表现为点击无响应；且 `setCurrentConversationAndLoad`（`chat_controller.dart:110-118`）先置新会话再 await 加载，"新会话标题 + 旧会话消息"的错配帧在桌面端可见。`MessageListView` 没有骨架/空态/分页 loading 任何分支（`message_list_view.dart:516-552`、`:645-664`）。另有死代码 `ChatController.switchConversation`（`:169-180`）绕过滚动定位与 flush，属潜在陷阱。

**问题 8【高】每次发送以 limit=360 整窗重载时间线**
`appendPersistedTailMessages`（`chat_controller.dart:545-561`）不做增量 append，每次发送（`chat_actions.dart:845`）都 `loadTimelinePage(limit: 360)`：一条 O(N) 折叠 SQL + 最多 360 行含 parts + 2 个 artifacts 批查询，开销随会话长度线性放大，直接坐在"点发送 → 气泡上屏"的关键路径上。preset 注入（`home_view_model.dart:784`）逐条重载 + 逐条 notify。

**问题 10【中】冷启动串行链 + N+1 查询 + 首帧空态**
`initChat`（`home_page_controller.dart:625-654`）串行：`await assistantProvider.loaded` → `chatService.init()`（内含 `getAllConversationSummaries` 的 **N+1**：每个会话在 Dart 循环里单独 await 一条 MCP server 查询，`chat_database_repository.dart:4607-4611`；外加全表 GROUP BY 消息计数）→ setCurrentAssistant 持久化 → 40 条窗口。首帧渲染空态无任何占位，体感是"什么都没有 → 突然全部出现"的两段式跳变。

### 3.4 一致性与生命周期

**问题 9【中】`includeMessageIds:true` 默认全行读整会话只为拼 id 列表**
`_conversationFromRow`（`chat_database_repository.dart:4612-4617`）默认把整会话消息**全列**（含 content/reasoning/translation 全文）读出只为 `:4623` 拼 messageIds；`_setSelectedVersion`（`:3223`）在写事务内触发——用户点一次版本切换箭头，就在写事务里搬运数 MB 文本并独占单连接队列。`:3167-3169` 已证明 `includeMessageIds:false` 足够，一行可修。

**问题 11【中】缓存生命周期系统性缺陷**
- `retainTimelineWindow`（`chat_service.dart:461-484`）生产代码零调用（死代码），Controller 只裁剪自己的窗口副本，Service 侧当前会话豁免上限——滚完一遍长会话即全量驻留，直到切走才可逐出；
- `_enforceMessageCacheLimits`（`:529-568`）以**整会话**为粒度逐出：一次载入超大非当前会话会先把其它所有会话逐光（级联清空全缓存）；字节估算漏掉 reasoningSegmentsJson 与整个 `_toolEventsCache`；
- 写路径（`addMessage :1915`、流式 update、`appendMessageVersion :2489`）不 `_touchMessageCache`，LRU 排序失真；后台流式会话被逐出后 `_replaceCachedMessage`（`:2044-2050`）静默早退（DB 仍写，仅内存失联）；
- `_deletePersistedConversation`（`:1596-1610`）残留 order/count/toolEvents/签名/组索引五类缓存，`getMessageCount` 返回旧值；`_firstGroupIndicesCache` 无任何失效路径；`loadSelectedContextMessages`/`loadMessagesByIds` 回填的 artifacts 不隶属任何会话条目，容量逐出永远扫不到。

### 3.5 UI 渲染

**问题 12【中】渲染层重复计算与过度重建**
- 侧边栏 `context.watch<ChatService>()`（`side_drawer.dart:1196`，ChatService 有 54 处 notifyListeners），每次通知全量 `toList+sort`（`chat_service.dart:570-575`）+ 非懒加载 Column 重建全部 tile（`:3387-3499`）；PageTransitionSwitcher 的 key 是全部会话 id 拼接（`:3383-3384`），会话增删/置顶即整列表转场 + 逐 tile 动画重放（验证修正：流式期间有 50ms 节流的独立通知通道，重放约每次发送一次而非持续闪动）；
- `_restoreMessageUiState` 在 `home_page_controller.dart:2104` 与 `home_view_model.dart:1009` 双实现，每条 assistant 消息对同一 JSON 三次独立反序列化（`stream_controller.dart:1317/1323/1331`）；每翻页 20 条对整个窗口（≤360 条）重跑一遍，并伴随两次 notifyListeners、两轮全列表 build；
- `HomePageController`/`ChatController` 的 notifyListeners 无条件 `invalidateCache`（`home_page_controller.dart:286-292`），拖拽侧栏宽度每帧 notify 导致 render model 每帧失效重投影（`:1721-1727`）;
- `ChatMessageWidget` 每 build 重跑 think 标签解析与 assistant 正则（`chat_message_widget.dart:2089-2096`）；markdown widget 级缓存仅覆盖"流式且 ≥4096 字符"（`markdown_with_highlight.dart:153-158`），历史消息滚出 600px cacheExtent 再滚回时 markdown 构建 + `highlight.parse` 在 UI 线程全部同步重来。

## 4. 优化方案

设计原则（来自三方案交叉评审的共识）：
- **渐进优先**：先用可独立回滚的小改动止血并埋点，架构级重构（Store/影子表/读写分离）由数据决定是否立项，不作为前置依赖；
- **宁可 miss 不可错命中**：缓存快路径采用 stale-free 保守判定（判不了就落库），不做 stale-while-revalidate 的后台校验（写路径已同步维护缓存，后台校验抵消 IO 收益还引入二次跳变）；
- **P0 起先加埋点**：DB 查询计数、缓存命中率、切换耗时三项埋点随第一批提交落地，作为后续所有验收与立项决策的依据。

### P0：止血——让缓存存在、被读到、切换不再串行空转（约 1 周）

#### 措施 1：修复缓存写空（问题 1）★ 全场收益/风险比最高
- **做法**（`chat_service.dart`）：
  1. `loadTimelinePage` 在 `:336` 调用 `_cacheLoadedMessages` 前补 `await _loadMessageOrder(conversationId)`（与 `loadMessagesRange :926`、`loadMessagesForGroups :681` 既有做法对齐；`_loadMessageOrder` 自带缓存短路，仅首开多一条覆盖索引 id 查询）；
  2. `loadMessages` 在 `:747` 写缓存前回填 `_messageOrderIds[cid] = messages.map((m) => m.id).toList()`（全量读结果按 message_order 排序，本身就是权威顺序，零额外查询）；
  3. `deleteMessages` 在 `:2780` 丢弃 order 后立即 `await _loadMessageOrder` 重建（与 truncate 路径 `:1994-1998` 对齐）；
  4. `_cacheLoadedMessages` 加防御分支：order 缺失时按传入消息自身顺序合并，不做交集过滤（防未来新读路径再踩坑）。
- **风险**：极低。防御分支行为是"保留数据"，严格优于现状。**工作量**：小（~5 行核心 + 单测）。

#### 措施 2：`loadTimelinePage` 缓存快路径，stale-free 保守版（问题 2）★ 用户抱怨的字面答案
- **做法**（`chat_service.dart` `loadTimelinePage` 入口、`:296` 临时会话分支之后）：第一期仅覆盖最高频的"打开会话取尾窗"场景（`fromStart=false` 且三个游标均空）。命中条件全部满足才走内存：① `_messageOrderIds` 已就绪；② 缓存尾部连续覆盖 order 末尾 ≥ limit 个 slot 所需 revision；③ 多版本组要求选中 revision 在缓存中——任何一条判不了就直接落库。命中时从内存合成 `LoadedTimelinePage` 同步返回（`_loadTemporaryTimelinePage :353-459` 的纯内存分页已证明可行，可抽公共实现）。翻页命中（before 游标在缓存覆盖区间内）作为第二步单独提交。
- **兜底**：debug/profile 构建加对拍断言（命中时后台再查 DB 比对）；总开关可一键回滚。
- **风险**：中（本方案唯一中风险项，被苛刻命中条件与开关兜住）。**工作量**：中（~100 行 + 对拍测试）。
- **依赖**：措施 1（否则缓存里没数据可命中）。

#### 措施 3：切换流水线重排，fetch-then-commit（问题 7）
- **做法**（`home_page_controller.dart:836-876`、`home_view_model.dart:712-740`）：
  1. 同 id 短路提到 flush 之前（点当前会话不再白跑 flush）；
  2. 删除 `hvm:716` 的重复 flush（保留 hpc 一处）；
  3. 移动端淡出动画与"flush + DB 取数"并行，但**取数到局部变量、淡出完成后一次性提交状态**（fetch-then-commit，把 `setCurrentConversationAndLoad` 拆成 fetch 与 commit 两段）——避免裸 `Future.wait` 在 opacity 未到 0 时 notify 造成新数据闪现；
  4. 请求序号防竞态：淡出期间用户再点另一会话时丢弃过期结果（现有 `:858/:864` 检查已有雏形）；
  5. `setCurrentAssistant`（`hvm:730`）的偏好持久化与消息加载 `Future.wait` 并行（其 notifyListeners 在写盘前已发出）。
- **预期**：移动端切换从 `flush+180+DB+settle+180` 变为 `max(180, flush+DB)+settle+180`；配合措施 2 命中时 DB≈0，稳定 ~360ms 纯动画（后续可再缩动画时长）。
- **风险**：低-中（竞态测试为主）。**工作量**：中（1-2 天）。

#### 措施 4：错配帧消除 + 显式加载状态（问题 7 桌面端）
- **做法**：`chat_controller.dart` `setCurrentConversationAndLoad`（`:110`）置新会话的同时同步清 `_messages` 并置新增的 `_isLoadingWindow` 标志（仅 `_loadInitialMessageWindow`/`loadWindowAroundMessage` 置位），`_replaceWindow` 完成后清除；`HomePageController` 暴露给 UI 供措施 12 的骨架消费。顺带删除死代码 `ChatController.switchConversation`（`:169-180`）。
- **风险**：低。**工作量**：小（半天）。

#### 措施 5：一行级 DB 调参（问题 6/9）
- **做法**：
  1. `app_database.dart:619`：`synchronous=FULL → NORMAL`。WAL 下 NORMAL 即保证崩溃一致性，掉电最坏丢最后一个 checkpoint（250ms 节流窗口内容），与 generation_run 恢复机制兼容；流式期间 fsync 次数大降、写事务变短、读排队变短；
  2. `chat_database_repository.dart:3223` `_setSelectedVersion` 改传 `includeMessageIds:false`（`:3167-3169` 已证明足够）——版本切换不再在写事务内搬运整会话全文。
- **风险**：低（NORMAL 是 drift/WAL 标准推荐组合）。**工作量**：小。

#### 措施 6：同步消费者正确性修复（问题 3）——摘要停更/建议丢失是用户可感知的功能失效，必须进 P0
- **做法**：
  1. `chat_service.dart` 新增 `bool isConversationFullyCached(String id)`（把 `:726` 的既有判断暴露出来，不新造状态机）；
  2. `home_view_model.dart` 摘要（`:1247`）与建议（`:1335`）把同步 `getMessages` 改为 `await loadMessages`——与 commit `0d523a31` 对标题生成的修法完全同款（项目已验证的模式）；落地措施 7 后这两处大概率直接缓存命中；
  3. 建议落库校验（`:1366-1370`）改用 `isConversationFullyCached` 或基于折叠后语义，消除多版本会话下建议永不保存；
  4. 清空上下文计数（`:1059-1069`）改用 `_messageCounts` + truncateIndex 纯计数计算——不需要消息正文，零 IO 且必准。
- **风险**：低。**工作量**：小-中。

### P1：削减读写放大 + 加载可见化（第 2 周）

#### 措施 7：当前会话空闲期静默补全（问题 2/3/5 的共同根源；用户"选中就该整体进缓存"的正面满足）
- **做法**：`chat_controller.dart` `_loadInitialMessageWindow` 完成、首屏渲染后，用 `SchedulerBinding.scheduleTask(Priority.idle)` 触发 `chatService.loadMessages(conversationId)` 补全当前会话。三个守卫：① "仍是当前会话"校验，切走即放弃；② 条数阈值（如 5000 条）以上跳过，防极端会话内存失控；③ `isGenerating` 时暂停（避免与流式写事务抢单连接队列）。当前会话本就豁免逐出（`:534-537`），驻留成本可控；补全后措施 2 的快路径、措施 6 的同步命中、`loadMessages` 命中全部生效，向上滚动翻页也全部内存命中。
- **风险**：低-中。**工作量**：小。

#### 措施 8：发送改增量 append（问题 8）
- **做法**：`chat_controller.dart` `appendPersistedTailMessages`（`:545-561`）：调用方已持有刚持久化的完整消息对象，正常路径直接 append 进 `_messages` 并增量维护 `_totalMessageCount`；仅当检测到计数缺口时回退现有 360 整窗重载兜底。preset 注入（`home_view_model.dart:784`）改批量一次 append 一次 notify。
- **⚠ 关键陷阱（评审发现，两份方案都踩了）**：缺口检测**禁止**拿 `_totalMessageCount`（折叠后 slot 数，`chat_controller.dart:217`）对比 `getMessageCount`（含全部 revision 的行数）——任何多版本会话两者恒不等，检测恒真，优化在最需要它的长会话上恒回退。必须用同口径：本地维护 slot 计数增量，或对比 `_messageOrderIds` 长度增量。
- **风险**：中低（算错的最坏后果 = 退化回现状）。**工作量**：中（1-2 天）。

#### 措施 9：窄查询替换宽查询（问题 5）
- **做法**（三个独立提交）：
  1. 标题生成统一实现：抽 `generateTitleSource(conversationId)`（先试 `isConversationFullyCached` 走缓存，miss 时 `getMessagesRange` 从尾部分页拼到 3000 字符即止），`home_view_model.dart:1147` 与 `side_drawer.dart:667` 共用，顺带修掉后者不应用 truncateIndex 的不一致；
  2. 批量删除（`home_view_model.dart:636`）改 `loadMessagesForGroups` 按选中组取；
  3. 三个导入器 merge 分支改 `repo.getMessageIds`（`chat_database_repository.dart:1886`，已存在），删掉 N+1 全量 loadMessages 与 LRU 冲刷。
- **风险**：低（全部是"用已存在的窄 API 替换宽 API"）。**工作量**：中。

#### 措施 10：legacy 双表回退退役第一步（问题 4 次要项）
- **做法**：`getToolEventsForMessages`/`getGeminiThoughtSignaturesForMessages` 加内存布尔标记"legacy 表已确认为空"，标记就绪后进程内跳过回退分支（每次打开/翻页少 2 条查询）；一次性数据迁移 + meta 标记（迁移完成后停写 `tool_event_rows` 双份 JSON）作为后续独立提交，meta 标记只在全部搬完后写入以保幂等。
- **风险**：低。**工作量**：小（标记版）/ 中（迁移版）。

#### 措施 11：启动并行化 + N+1 合并（问题 10）
- **做法**：
  1. `initChat`（`home_page_controller.dart:625`）：`await Future.wait([assistantProvider.loaded, _chatService.init()])`（两者无依赖）；
  2. `getAllConversationSummaries`（`chat_database_repository.dart:1249-1269`）：一条 `SELECT * FROM conversation_mcp_server_rows` 在 Dart 端按 conversationId 分桶，替换逐会话查询（`:4607-4611`），启动查询数 1+N → 2；
  3. 恢复最近会话时 `setCurrentAssistant` 与 `setCurrentConversationAndLoad` 并行（`chat_message_widget.dart:896-912` 的 assistant 缺失降级路径已存在，一帧 fallback 可接受）。
- **风险**：低。**工作量**：小-中。

#### 措施 12：MessageListView 三态占位 + 侧栏初始化骨架（问题 7/10 的"无反馈空白"）
- **做法**（`message_list_view.dart`）：
  1. `itemCount == 0 && isLoading`（措施 4 的标志）→ 3-4 个气泡形 shimmer 骨架；
  2. `itemCount == 0 && !loading` → 空会话 empty state；
  3. `hasMoreBefore` → 列表顶部固定高度 loading 行（分页触发 `:645-664` 已存在，只缺可见反馈）。注意 SuperListView 的 extent 缓存按 slotId 定位（`:531`），loading 行用固定哨兵 key，插入/移除走既有前缀增删路径（`:310-349`）避免滚动跳动；
  4. 侧栏/历史对话框在 `chatService` 未初始化时渲染 tile 骨架。
- **原则**：骨架只在真正冷加载（快路径 miss）时显示，命中缓存直接渲染，避免闪烁。感知延迟不只是真实延迟——无反馈的 300ms 比有骨架的 500ms 更"卡"。
- **风险**：低（顶部行的滚动位置补偿需真机验证）。**工作量**：中。

#### 措施 13：缓存生命周期修漏（问题 11；措施 2 快路径与措施 14 预取的前置安全条件）
- **做法**（`chat_service.dart`）：
  1. `_enforceMessageCacheLimits`：单个会话自身超预算时对其**尾部截断**（保留最近 N 条）而非级联逐出其它所有会话；字节估算补上 reasoningSegmentsJson 与对应 toolEvents 条目；
  2. 写路径（`addMessage`、`_publishGenerationBegin`、`appendMessageVersion`、`_replaceCachedMessage`）统一调 `_touchMessageCache`，让 LRU 反映真实访问；
  3. `_deletePersistedConversation` 补清五类残留（order/count/toolEvents/签名/组索引）；`deleteMessages`/truncate/`clearAllData`/覆盖恢复按会话清 `_firstGroupIndicesCache`；
  4. 删除死代码 `retainTimelineWindow`（评审选择：避免与措施 7 的补全形成"刚补全又被裁掉"的拉锯；当前会话驻留由措施 7 的条数阈值兜底，注释写明"当前会话缓存上界 = 会话全量或阈值"）。
- **风险**：低-中（逐出与 touch 只影响驻留策略不影响正确性）。**工作量**：中。

### P2：预取、渲染收敛与按需深水区（第 3-4 周起）

#### 措施 14：预取管线轻量版（问题 2 体验面；依赖措施 1/2/13）
- **做法**：桌面端侧栏 tile hover 触发 `unawaited(loadTimelinePage(id, limit: 40))` 只填缓存不动 UI；启动恢复完成后 idle 调度对最近 3-5 个会话串行预热。预热计入缓存预算、检测到用户操作即放弃队列。**明确砍掉**移动端 pointerDown 预取（滚动手势误触发）。
- **风险**：低（idle 调度 + 可弃，不依赖读写分离）。**工作量**：中。

#### 措施 15：滚动渲染缓存（问题 12）
- **做法**：
  1. `markdown_with_highlight.dart`：非流式路径也套 `_CachedMarkdownBlock`（`:537-552` 放宽启用条件，key = content hash + 主题/字号/正则配置签名）；
  2. `highlight.parse` 加全局 LRU（key = lang + code hash，复用现有 `ByteLruCache :88` 基础设施）；
  3. `chat_message_widget.dart` 的 think 解析与 assistant 正则 memo 进 State 或上移到 render model 投影阶段（`message_list_view.dart:259-272` 管道已存在）；
  4. `stream_controller.dart:1317-1331` 三次 JSON 反序列化合一并按 messageId 记忆化；`_restoreMessageUiState` 双实现合并为一处、只对新进窗口消息执行；翻页去掉双 notifyListeners。
- **风险**：低-中（缓存 key 必须纳入主题/配置签名，否则换主题出现陈旧渲染）。**工作量**：中（2-3 天，分小提交）。

#### 措施 16：侧边栏精细订阅（问题 12）
- **做法**：ChatService 增加 `conversationListRevision` 计数（仅会话增删/改名/置顶/顺序变化时自增），侧栏 `Selector` 订阅替代 `context.watch`；选中态单独 Selector 监听 currentConversationId；`getAllConversations` 内部维护已排序列表 + 脏标记；PageTransitionSwitcher key 改轻量签名。列表虚拟化（Column → SliverList）作为独立二期（UI 回归成本高）。
- **风险**：低-中（revision 遗漏某写路径会导致列表不刷新，需清点 54 处 notify 语义，集中经 revision 管理）。**工作量**：中。

#### 措施 17：流式 checkpoint 减写第一步（问题 6）
- **做法**：`_replaceMessageParts`（`chat_database_repository.dart:2941-3018`）在 checkpoint 路径先比对，tool_call/tool_result parts 未变化（事件数与末条指纹一致）时只重写 text/reasoning part，跳过工具 parts 的全删全插。第二步（`message_rows.content` shadow 推迟到流结束 finalize 一次性写、FTS 整个流式期只跑一次）**必须先核实崩溃恢复路径以 parts 为权威**后才做，独立提交。
- **风险**：第一步低；第二步中（涉及崩溃恢复语义）。**工作量**：中。

#### 措施 18：数据驱动的候选项（不预先承诺，以 P0 埋点数据决策）

| 候选 | 内容 | 立项条件 |
|---|---|---|
| timeline 影子表 + keyset 分页 | 新表 `timeline_slot_rows(conversation_id, slot_order, group_id, selected_revision_id, version_count)` 由写路径增量维护，`loadLinearMessageWindow` 退化为 O(limit) 索引扫描，彻底消除每页 O(N) 折叠（问题 4 主体） | 措施 2/7/8 落地后，超长会话冷打开首帧仍超标（影子表引入新一致性不变式：备份/导入旁路必须强制重建 + debug 断言，schema 迁移不可逆降级） |
| drift 读写分离（一写多读连接） | 分页读不再排在流式写事务之后（问题 6 队列阻塞的治本） | 措施 5/17 落地后，写事务排队仍可测量地阻塞切换 |
| `ConversationMessageStore` 收敛 | per-conversation 状态机（unloaded → window(区间) → complete），6 个平行 Map 收敛为单一 entry，artifacts 随消息同生命周期（问题 1/2/3/11 的系统性终态；当前会话改独立更大预算 + 会话内裁剪语义） | 措施 13 的散落失效维护在后续迭代反复出 bug，证明手工维护成本过高时，作为已验证行为的等价重构启动 |

### 明确放弃的选项（评审结论）

| 放弃项 | 理由 |
|---|---|
| stale-while-revalidate 后台校验（命中后仍后台查 DB 比对） | 写路径已同步维护缓存，后台校验让每次命中仍发一轮查询，缓存 IO 收益归零；小概率不一致时二次 notify 造成内容跳变 |
| settle-at-bottom 提前淡入 | 收益仅 33-50ms，风险是复现"底部闪跳"专修 bug，全方案收益/风险比最差 |
| 移动端 pointerDown 预取 | 滚动手势误触发 |
| Store 大重构作为全部措施的前置地基 | 止血项不应依赖最大单点改动；~1 天的措施 1/6 已覆盖 Store 要解决的主要症状 |

## 5. 问题 ↔ 措施对照

| 问题 | 严重度 | 措施 |
|---|---|---|
| 1 缓存写空 | 高 | **1** |
| 2 缓存只写不读 | 高 | **2**、7、14 |
| 3 同步 getter 无完整性语义 | 高 | **6**、7 |
| 4 每页 O(N) CTE / legacy 回退 | 高 | 10、18(影子表候选) |
| 5 loadMessages 恒 miss + 宽调用 | 高 | 7、**9** |
| 6 流式写放大 + 单连接排队 | 高 | **5**、17、18(读写分离候选) |
| 7 切换串行 + 无反馈 + 错配帧 | 高 | **3**、**4**、12 |
| 8 发送 360 整窗重载 | 高 | **8** |
| 9 includeMessageIds 全行读 | 中 | **5**(附赠一行) |
| 10 冷启动串行 + N+1 + 空态 | 中 | **11**、12 |
| 11 缓存生命周期缺陷 | 中 | **13** |
| 12 UI 重复计算与过度重建 | 中 | **15**、**16** |

## 6. 验收指标

P0 第一批提交先落埋点（DB 查询计数、缓存命中率、切换耗时），随后逐项验收：

1. 切回 5 秒内看过的会话：DB 查询数 ~6 → **0**（措施 2 命中计数）；
2. 打开会话 1 秒内 `isConversationFullyCached` 为 true（措施 7；用户抱怨的量化答案）；
3. 长会话（1000+ 条）发送一条消息：DB 查询 4+ → **0-1**（措施 8；注意用 slot 同口径验证多版本会话不回退）；
4. 流式期间每 checkpoint 的写入行数与 fsync 次数下降（措施 5/17）；
5. 移动端切换点击到首屏 ≤ 250ms，全程有骨架反馈（措施 3/4/12）；
6. 1000+ 条会话上摘要恢复更新、建议正常落库（措施 6）。

## 7. 附录：验证中被修正/驳回的常见误判

为避免后续实施时被误导，记录对抗验证阶段修正的关键认知：

- "UI 打开会话会白屏"——不成立：Controller 自持窗口副本，问题 1 只影响服务层缓存与同步 getter；
- "发送上下文构建整会话 hydrate + probe 双跑"——不成立：生产路径走 `getSelectedContextMessages` 单条限量 SQL；probe 双跑只在死代码 `loadActiveTimelineMessages` 中；
- "流式每 tick 读库写库"——不成立：实际经 `LatestWinsCheckpointWriter` 250ms 节流，且 checkpoint 路径无 read-before-write；
- "完整历史上下文每次发送全表读"——不成立：`loadMessages` 在发送链路仅用于临时会话（纯内存）与手动压缩上下文；
- "流式期间侧边栏持续闪动"——夸大：流式 token 走独立 50ms 节流通知，侧栏重建约每次发送一次；
- "自动标题每次回复后全量加载"——夸大：有"已有自定义标题即早退"守卫，通常仅首条回复后触发一次，实际痛点在侧边栏手动重生成；
- `_totalMessageCount`（slot 数）与 `getMessageCount`（revision 行数）**口径不同**，任何缺口检测/完整性判断禁止跨口径比较（措施 8 的关键陷阱）。
