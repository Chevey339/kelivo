# Kelivo 根包 Analyzer Issue 清零计划

## Summary

- 主控制目标：把根包 flutter analyze 当前的 3132 条诊断清到 0，并保持 flutter test 持续为绿。
- 已确认基线：根包 3132 条 issue，其中 2757 info / 375 warning / 0 error；4 个 path dependency 独立 flutter analyze 均
  为 0；根包 flutter test 当前全绿。
- 本轮口径已锁定：只治理根包 flutter analyze 诊断，不把 dependency 自身的独立 analyze 纳入主队列。
- 当前主症状是可批量处理的三类：deprecated_member_use 1996 条，use_build_context_synchronously 336 条，
  curly_braces_in_flow_control_structures 211 条。
- 队列不是一次性写死，采用“每完成一个文件就全量重算”的动态优先级，避免基于过期排序推进。

## Mini Control Contract

- Primary Setpoint：根包 flutter analyze 结果从 3132 降到 0，且每次收口后目标文件自身不再产生新诊断。
- Acceptance：最终执行 flutter analyze 为 No issues found；flutter test 全绿；如果本轮触达过 lib/desktop/**，最终额外执
  行一次 flutter build macos --debug 通过。
- Guardrails：不处理 path dependency 自身问题；不把当前已有未提交改动并入本轮；不引入新功能、新文案、新 fallback、新公
  开配置；不为过 lint 扩大公共 API。
- Boundary：以根包 lib/、test/、根级 analyzer/config 为边界；唯一允许触碰 dependency 的情形，是消除根包 analyze 冒出的
  那 1 条 tray_manager 配置警告时，用根侧排除或根侧配置修正解决，不进入 dependency 包内部做清理。
- Risks：大批量 deprecation 替换可能带来 UI 行为偏移；use_build_context_synchronously 修复可能牵动异步流程；个别文件可
  能需要最小伴随修改到共享 helper，导致动态排序发生变化。

## Implementation Changes

- 建立唯一优先级事实源：每轮都基于整仓 flutter analyze 输出重建 file -> issue_count 队列；排序规则固定为 issue_count
  desc、warning_count desc、path asc。
- 执行粒度固定为“单文件闭环”：每次只认领当前排名第一的文件，目标是把该文件 issue 清到 0，完成后再重算全队列决定下一个文
  件。
- 允许最小伴随修改：如果目标文件无法单独清零，允许顺带改动 1 到 2 个直接依赖的共享文件，但伴随修改只服务于当前文件收
  口，不能顺手扩成跨模块重构。
- 文件内修复顺序固定：先处理行为/正确性风险项，如 use_build_context_synchronously、空断言/空比较/无效类型判断、死代码；
  再处理 API 漂移项，如 deprecated_member_use；最后处理纯样式卫生项，如花括号、插值、无用 import、未用局部变量。
- 所有 Flutter API deprecation 替换优先遵循现有主题与组件语义，不允许为了消 lint 把桌面逻辑塞进移动入口，也不允许引入新
  的 Material 默认交互反馈。
- 每个文件收口后立即 dart format 已改文件，并刷新整仓 analyze 排名；不等到最后统一格式化。
- 根包 analyze 中那 1 条 [dependencies/tray_manager/packages/tray_manager/analysis_options.yaml](/Users/caowenyi.3/
  StudioProjects/kelivo/dependencies/tray_manager/packages/tray_manager/analysis_options.yaml) 警告放在所有 lib/ 文件清
  零后处理，修法限定为根侧 analyzer 边界收口，不进入 dependency 清理。
- 当前队列头部按现状依次是：lib/features/provider/pages/provider_detail_page.dart 100、lib/features/assistant/pages/
  assistant_settings_edit_page.dart 97、lib/desktop/setting/display_pane.dart 96、lib/features/chat/widgets/
  message_export_sheet.dart 90、lib/features/chat/widgets/chat_message_widget.dart 90。

## Public APIs / Interfaces / Types

- 默认不新增、不扩大任何 public API、provider 接口、模型字段或配置项。
- 允许的接口变更仅限当前目标文件所依赖的私有 helper、本地方法签名或文件内局部类型整理。
- 如果某个 analyzer issue 逼迫修改共享接口、持久化模型、l10n、桌面入口路由或 path dependency 公共面，本轮停止在该文件，
  先单独升级为“跨边界问题”，不继续按 lint 清理名义推进。

## Test Plan

- L0 每文件：dart format <touched files>，然后对目标文件和伴随文件做局部 analyze，确认该文件集不留 issue。
- L1 每文件收口：执行整仓 flutter analyze，刷新优先级队列；执行整仓 flutter test，把测试绿灯作为持续护栏。
- L2 桌面护栏：每完成 5 个文件，如果这 5 个里触达过 lib/desktop/**，执行一次 flutter build macos --debug；最终全部清零
  后再执行一次。
- 回归判定：只要某次修复让整仓 issue 总数不降反升、测试转红、或引入新的 analyzer 类型簇，立即停在当前文件做根因回查，不
  继续切到下一个文件。

## Assumptions

- “issue” 明确定义为根包 flutter analyze 诊断，不含 GitHub issue、需求缺陷、dependency 自身独立 analyze 结果。
- 优先级采用动态重算，不使用一次性的静态排行榜。
- 当前已有的两处未提交改动文件维持冻结；因它们当前不在 issue 队列内，本轮不主动触碰。
- 本轮不做顺手升级依赖、不做 UI 重设计、不做无关重构；唯一目标是按文件优先级把 analyzer issue 清零并保持验证闭环。  # Kelivo 根包 Analyzer Issue 清零计划

## Summary

- 主控制目标：把根包 flutter analyze 当前的 3132 条诊断清到 0，并保持 flutter test 持续为绿。
- 已确认基线：根包 3132 条 issue，其中 2757 info / 375 warning / 0 error；4 个 path dependency 独立 flutter analyze 均
  为 0；根包 flutter test 当前全绿。
- 本轮口径已锁定：只治理根包 flutter analyze 诊断，不把 dependency 自身的独立 analyze 纳入主队列。
- 当前主症状是可批量处理的三类：deprecated_member_use 1996 条，use_build_context_synchronously 336 条，
  curly_braces_in_flow_control_structures 211 条。
- 队列不是一次性写死，采用“每完成一个文件就全量重算”的动态优先级，避免基于过期排序推进。

## Mini Control Contract

- Primary Setpoint：根包 flutter analyze 结果从 3132 降到 0，且每次收口后目标文件自身不再产生新诊断。
- Acceptance：最终执行 flutter analyze 为 No issues found；flutter test 全绿；如果本轮触达过 lib/desktop/**，最终额外执
  行一次 flutter build macos --debug 通过。
- Guardrails：不处理 path dependency 自身问题；不把当前已有未提交改动并入本轮；不引入新功能、新文案、新 fallback、新公
  开配置；不为过 lint 扩大公共 API。
- Boundary：以根包 lib/、test/、根级 analyzer/config 为边界；唯一允许触碰 dependency 的情形，是消除根包 analyze 冒出的
  那 1 条 tray_manager 配置警告时，用根侧排除或根侧配置修正解决，不进入 dependency 包内部做清理。
- Risks：大批量 deprecation 替换可能带来 UI 行为偏移；use_build_context_synchronously 修复可能牵动异步流程；个别文件可
  能需要最小伴随修改到共享 helper，导致动态排序发生变化。

## Implementation Changes

- 建立唯一优先级事实源：每轮都基于整仓 flutter analyze 输出重建 file -> issue_count 队列；排序规则固定为 issue_count
  desc、warning_count desc、path asc。
- 执行粒度固定为“单文件闭环”：每次只认领当前排名第一的文件，目标是把该文件 issue 清到 0，完成后再重算全队列决定下一个文
  件。
- 允许最小伴随修改：如果目标文件无法单独清零，允许顺带改动 1 到 2 个直接依赖的共享文件，但伴随修改只服务于当前文件收
  口，不能顺手扩成跨模块重构。
- 文件内修复顺序固定：先处理行为/正确性风险项，如 use_build_context_synchronously、空断言/空比较/无效类型判断、死代码；
  再处理 API 漂移项，如 deprecated_member_use；最后处理纯样式卫生项，如花括号、插值、无用 import、未用局部变量。
- 所有 Flutter API deprecation 替换优先遵循现有主题与组件语义，不允许为了消 lint 把桌面逻辑塞进移动入口，也不允许引入新
  的 Material 默认交互反馈。
- 每个文件收口后立即 dart format 已改文件，并刷新整仓 analyze 排名；不等到最后统一格式化。
- 根包 analyze 中那 1 条 [dependencies/tray_manager/packages/tray_manager/analysis_options.yaml](/Users/caowenyi.3/
  StudioProjects/kelivo/dependencies/tray_manager/packages/tray_manager/analysis_options.yaml) 警告放在所有 lib/ 文件清
  零后处理，修法限定为根侧 analyzer 边界收口，不进入 dependency 清理。
- 当前队列头部按现状依次是：lib/features/provider/pages/provider_detail_page.dart 100、lib/features/assistant/pages/
  assistant_settings_edit_page.dart 97、lib/desktop/setting/display_pane.dart 96、lib/features/chat/widgets/
  message_export_sheet.dart 90、lib/features/chat/widgets/chat_message_widget.dart 90。

## Public APIs / Interfaces / Types

- 默认不新增、不扩大任何 public API、provider 接口、模型字段或配置项。
- 允许的接口变更仅限当前目标文件所依赖的私有 helper、本地方法签名或文件内局部类型整理。
- 如果某个 analyzer issue 逼迫修改共享接口、持久化模型、l10n、桌面入口路由或 path dependency 公共面，本轮停止在该文件，
  先单独升级为“跨边界问题”，不继续按 lint 清理名义推进。

## Test Plan

- L0 每文件：dart format <touched files>，然后对目标文件和伴随文件做局部 analyze，确认该文件集不留 issue。
- L1 每文件收口：执行整仓 flutter analyze，刷新优先级队列；执行整仓 flutter test，把测试绿灯作为持续护栏。
- L2 桌面护栏：每完成 5 个文件，如果这 5 个里触达过 lib/desktop/**，执行一次 flutter build macos --debug；最终全部清零
  后再执行一次。
- 回归判定：只要某次修复让整仓 issue 总数不降反升、测试转红、或引入新的 analyzer 类型簇，立即停在当前文件做根因回查，不
  继续切到下一个文件。

## Assumptions

- “issue” 明确定义为根包 flutter analyze 诊断，不含 GitHub issue、需求缺陷、dependency 自身独立 analyze 结果。
- 优先级采用动态重算，不使用一次性的静态排行榜。
- 当前已有的两处未提交改动文件维持冻结；因它们当前不在 issue 队列内，本轮不主动触碰。
- 本轮不做顺手升级依赖、不做 UI 重设计、不做无关重构；唯一目标是按文件优先级把 analyzer issue 清零并保持验证闭环。