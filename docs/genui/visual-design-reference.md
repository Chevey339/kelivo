# Kelivo IntelligentUI 设计稿（DESIGN.md）

> 范围：`plan-1023.md` 的视觉与交互规格。原型：`index.html`（纯 HTML，无 Flutter）。截图：`png/`。
> 基线：完全沿用 kelivo 现有视觉（SurfaceLadder、IosSwitch / IosCheckbox / SegmentedTabs / IosFormTextField、markstream 代码块与引用样式），**不引入新的视觉语言**。

## 1. 设计原则
1. **像 kelivo 自己长出来的**：生成界面与消息正文同一材质（card + hairline + 12px 圆角），不另造“插件感”外框。
2. **内容先于外壳**：Surface 头部只有图标、标题、状态徽标和 3 个低调操作（源码 / 展开 / 更多）；无边框嵌套超过两层。
3. **流式可预期**：未到达的节点以“等待 `id` · 类型”的虚线占位，尺寸接近终态，避免跳动。
4. **错误就地、可恢复**：节点级错误不毁整卡；整卡失败保留源码 + “修复界面”。
5. **状态只属于消息**：交互状态是该消息的本地状态；Ask 时冻结为 chip 快照，不追溯修改。
6. **不靠颜色单通道**：图表系列另有虚线样式 + 标记形状；状态徽标总有图标 + 文字。

## 2. Token 表（映射 kelivo 主题名）
| 原型变量 | kelivo 主题名 | 浅色 | 深色 | 用途 |
|---|---|---|---|---|
| --page | SurfaceLadder.page / colorScheme.surface | #F7F7F7 | #121213 | 聊天背景 |
| --card | SurfaceLadder.card | #FEFEFE | #2A2A2B | Surface 卡片 |
| --fill | SurfaceLadder.fill（IosFormTextField 底色） | #EBEBEB | #373738 | 输入框、Metric 底 |
| --hair | hairline / outlineVariant 6–8% | rgba(0,0,0,.06) | rgba(255,255,255,.08) | 分隔线、卡框 |
| --ink / ink2 / ink3 / ink4 | onSurface 100 / 72 / 50 / 30% | #202020 | #F9F9F9 | 正文 / 次要 / 说明 / 禁用 |
| --pri / --onpri | colorScheme.primary / onPrimary | #4D5C92 / #FFF | #B6C4FF / #1D2D61 | 主按钮、滑块、Metric 数字 |
| --pc / --onpc | primaryContainer / onPrimaryContainer | #DCE1FF / #05164B | #354479 / #DCE1FF | chip、选中段 |
| --err / --errc | error / errorContainer | #BB0947 / #FDDADE | #FCB4BD / #910034 | 校验、错误块 |
| --ok / --warn | kelivo 成功 / 警告色 | #16A34A / #B45309 | #75DFA3 / #FFD17B | 徽标 |
| --fblock / --fhead | markstream 代码块底 / 头 | — | — | 源码块、壁纸毛玻璃 |
| 圆角 | 卡 12、输入 10、按钮 10、chip 12、气泡 18、输入栏 20 | | | |
| 间距 | 4 的倍数；卡内边距 14、节点间 12、表单字段间 14 | | | |
| 字号 | 正文 15 / 标签 13 / 说明 12 / 徽标 11 / Metric 26（主）/ 20（次） | | | 随系统字号缩放 |

## 3. 组件规格（21 个，原型画廊 `#gal-light` / `#gal-dark` 展示全部状态）
通用：最小触控 44×44（视觉可小，命中区补足）；焦点环 2px `--pri` 外扩 2px；RTL 下用 start/end 而非 left/right，图表 X 轴不镜像（数据方向），图例与表格列顺序镜像；动效 150–200ms ease-out，`prefers-reduced-motion` 下全部取消。

| # | 组件 | 结构 / 尺寸 | 状态 | 动效 | a11y / 焦点 |
|---|---|---|---|---|---|
| 1 | Surface（外壳） | 头 40px：图标16+标题13/600+徽标+操作；体 padding 14；脚 32px（仅错误/中断时） | streaming / complete / errors / interrupted / invalid / 尚未保存 / 只读 | 徽标淡入；节点到达 160ms fade+2px 上移 | region，aria-label=标题；aria-busy=streaming |
| 2 | Column / Row | gap 12；Row 窄屏(<360)自动换行 | — | — | 无语义 |
| 3 | Card（嵌套区块） | fill 底，无框，圆角 10 | — | — | group + 标题 |
| 4 | Text / Markdown | 继承 markstream | — | — | — |
| 5 | Metric | label 12 ink3；值 26/600 pri；单位 13；副行 12 | 正常 / 空值“—” / 错误 | 数值变化 120ms 交叉淡 | live=polite（节流 500ms） |
| 6 | Slider | 轨 4px，拇指 22，刻度可选；标签行+值右对齐 | 默认 / 拖动 / 禁用 | — | slider，←→步进，PgUp/Dn 10%，Home/End |
| 7 | Switch | IosSwitch 51×31 | on / off / 禁用 | 系统 | switch |
| 8 | Checkbox | IosCheckbox 22 圆形 | on / off / 错误 | 系统 | checkbox |
| 9 | NumberInput | IosFormTextField + 单位 + −/+ | 默认 / 聚焦 / 越界错误 / 禁用 | — | spinbutton |
| 10 | TextInput / TextArea | IosFormTextField；TextArea 计数右下 | 默认 / 聚焦 / 错误 / 计数 | — | textbox，错误 aria-describedby |
| 11 | Select | 下拉 → 移动端底部 sheet，桌面 popover | 占位 / 已选 / 错误 | sheet 200ms | combobox |
| 12 | SegmentedTabs | kelivo SegmentedTabs，高 36 | 选中 / 禁用 | 滑块 180ms | radiogroup |
| 13 | Form | 字段垂直 14；必填 `*` err 色；底部汇总“还有 N 项需要修改” | 初始 / 校验失败 / 提交中 | 首个错误滚动到可见 | 提交失败焦点移到首个错误 |
| 14 | Button | 高 36，圆角 10；primary / tonal / plain | 默认 / 按下 / 禁用（附原因） / 加载 | — | button，禁用用 aria-disabled 保留焦点 |
| 15 | Chart · 折线 | 高 200（移动）/ 260（桌面）；图例上方；轴 11px ink3 | 正常 / 空值断开 / 单点 / 无数据 | 首次绘制 300ms（reduce 下无） | img + 文字摘要；切换“数据”可看表 |
| 16 | Chart · 柱 / 饼(环) | 同上；环中心总计 | 同上 | 同上 | 同上 |
| 17 | 图表/数据切换 | 小 SegmentedTabs 右上 | 图表 / 数据 | — | tablist |
| 18 | DataTable | 行高 40，表头 12/600；数字右对齐等宽；排序 ↑↓；筛选框；分页 10/页 | 默认 / 排序 / 筛选命中高亮 / 空 / 空值置底 | — | table，排序 aria-sort |
| 19 | Callout | 左图标 + 标题 + 正文；info/ok/warn/err 四色 container | 4 种 | — | note / alert(err) |
| 20 | Badge / Tag | 高 22，圆角 11 | 4 色 | — | 文本即语义 |
| 21 | Formula | KaTeX 居中，可横滚 | 正常 / 解析失败（显示源码） | — | aria-label=TeX 源 |

## 4. 布局规则
- 消息内 Surface 宽度 = 消息列宽（移动端满宽 − 2×16，桌面最大 720）。
- 嵌套最多 3 层（Surface > Card > Row）。
- 每条消息最多 **3 个** Surface；第 4 个起显示“已达上限”占位（见 `#err`）。
- 消息内高度上限：移动 1.4 屏、桌面 900px，超出折叠为“展开查看”stub；展开 = 移动端全屏 overlay，桌面对话框（最大 960×85vh），消息内留 stub“正在展开视图中操作”。
- 大字号（1.3×）：Row 自动换行，Metric 并排变堆叠，表格横向滚动而非压缩。

## 5. 图表调色板与对比度（WCAG，对 card 色计算，脚本生成）
| Token | 浅色值 | 对 card #FEFEFE | 深色值 | 对 card #2A2A2B |
|---|---|---|---|---|
| --c1 | #4D5C92 | 6.38:1 ✅AA | #B6C4FF | 8.42:1 ✅AA |
| --c2 | #C2410C | 5.13:1 ✅AA | #FDBA74 | 8.50:1 ✅AA |
| --c3 | #0F766E | 5.43:1 ✅AA | #5EEAD4 | 9.69:1 ✅AA |
| --c4 | #9D3C8F | 5.99:1 ✅AA | #F0ABFC | 8.15:1 ✅AA |
| --c5 | #A16207 | 4.88:1 ✅AA | #FDE68A | 11.51:1 ✅AA |
| --c6 | #4B7BB5 | 4.34:1 ✅图形≥3 | #93C5FD | 7.95:1 ✅AA |
| --ink | #202020 | 16.16:1 ✅AA | #F9F9F9 | 13.62:1 ✅AA |
| --pri | #4D5C92 | 6.38:1 ✅AA | #B6C4FF | 8.42:1 ✅AA |
| --err | #BB0947 | 6.42:1 ✅AA | #FCB4BD | 8.47:1 ✅AA |
| --ok | #16A34A | 3.27:1 ✅图形≥3 | #75DFA3 | 8.77:1 ✅AA |
| --warn | #B45309 | 4.98:1 ✅AA | #FFD17B | 10.01:1 ✅AA |

结论：所有系列色对卡片 ≥3:1（WCAG 1.4.11 图形对比）；除浅色 c6 外均 ≥4.5:1 可直接作数值标签。规则：
- 浅色 c6 与 --ok 只用于线/面/图标，**不作小字**；需要绿色文字时用 #15803D（5.0:1）。
- 系列 ≥4 时同时启用虚线样式（实线 / 6-3 / 2-3 / 8-3-2-3）与标记形状（圆 / 方 / 三角 / 菱形）。
- 超过 6 系列：合并为“其他”。

## 6. 流式规则
1. 首行 `ui` 到达即出现 Surface 外壳 + “生成中”徽标。
2. `root` 到达后按子节点 id 预铺虚线占位（显示 `等待 id · 类型`），占位高度用类型默认值（Metric 64、Chart 200、Table 160、Form 字段 56/项、Button 36）。
3. 节点完整解析后替换占位；**控件在 complete 前只读**（防止对未完成状态的交互）。
4. 生成中断：保留已渲染节点，未到占位转为灰色静态，徽标“已中断”，脚注“查看源码”。
5. 自动滚动只在用户位于底部时跟随。

## 7. 错误域
| 域 | 表现 | 恢复 |
|---|---|---|
| 节点错误（completeWithErrors） | 节点处显示 err 小卡：标题 + 原因 + 行号；依赖它的按钮禁用并说明原因；脚注“N 个节点无法显示” | “修复界面”：把错误清单作为新消息发给模型 |
| 整卡无效（invalid） | errorContainer 提示 + 源码块（错误行高亮）+ 修复界面 / 复制源码 | 同上 |
| 尚未保存（状态写入失败） | 头部 warn 徽标“尚未保存”，界面继续可用 | 点击徽标重试 |
| 3 个上限 | 第 4 个起替换为一行提示 | 无需操作 |
| kelivo-web 无效首行 | 卡片显示“首行元信息无效，未加载”，只提供源码 | — |

## 8. 密度
- 默认密度；桌面 ≥1024 时表格行高 36、卡内边距 16。
- 同一 Surface 内最多 1 个主按钮；其余 tonal / plain。

## 9. Ask / chip
- “解释当前参数”等 Ask 按钮 → 当前状态冻结为 chip 放入输入框（不自动发送，光标在末尾）。
- chip：图标 + 标题 + 一行参数摘要；可展开看将随消息发送的 monospace 文本；可删除。
- 源消息被删除/重新生成 → chip 变 warn 样式“来源已失效”，发送按钮仍可用但 chip 不随发。
- 每份草稿只允许 1 个 chip：已有时再点 → “替换”对话框；输入框已有文字 → “合并”对话框（保留文字 + 新 chip）。
- 发送后用户气泡顶部显示只读 chip 摘要。

## 10. kelivo-web
- 卡片三态：生成中（不可打开）/ 就绪（“打开”）/ 无效。永不内联自动加载。
- 打开：移动端全屏页（顶栏关闭 + “沙盒预览 · 关闭后不保留”，底部 CSP 提示）；桌面对话框。同一时刻只开一个，开新的关闭旧的。
- Linux（无 WebView）：不显示“打开”，改为“查看源码 / 复制 / 导出 HTML”并说明。

## 11. 计划中的歧义与建议
| # | 歧义 | 建议 |
|---|---|---|
| A1 | 流式期间控件可否交互 | 只读，complete 后解锁（避免状态被后续节点覆盖） |
| A2 | 每条消息 3 个上限是否含 kelivo-web | 不含；kelivo-web 单独计数（建议同样 3 个） |
| A3 | chip 快照取“点击时”还是“发送时”状态 | 点击时冻结；之后拖动不改变 chip（原型即如此），需要新状态再点一次走“替换” |
| A4 | 来源失效的 chip 是否阻止发送 | 不阻止，只不附带并提示 |
| A5 | 中断后是否允许“继续生成” | 本期不做，仅“修复界面”/重新生成 |
| A6 | 状态持久化失败的提示等级 | 仅头部徽标，不弹 snackbar（避免拖动时刷屏） |
| A7 | 展开视图与消息内是否同一实例 | 同一状态，消息内显示 stub，关闭后同步 |
| A8 | 图表 RTL 是否镜像 X 轴 | 不镜像时间轴；图例/表格镜像 |
| A9 | 表格空值排序 | 一律置底，与方向无关 |
| A10 | 未知组件 | 节点级错误而非整卡 invalid |
| A11 | 大字号下 Row | 自动换行而不是缩小字体 |
| A12 | 桌面展开对话框尺寸 | 最大 960×85vh，可 Esc 关闭 |
