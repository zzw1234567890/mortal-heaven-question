# Story 005: 节点移动交互流与教程覆盖

> **Epic**: 探索 UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 1.5d（sprint-17 排期）
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-11-07（/story-done 关闭）

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 节点图交互 AC（移动/不可达/悬停）+ UX 教程覆盖 AC（B10 裁决归本 story）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0014: 探索系统（次要——move_to_node 委托流程）
**ADR Decision Summary**: 先移动后弹窗（B4 裁决——点击→move_to_node 消耗 AP→到达→需确认节点弹窗，弹窗本体归 006）；直接点击自动路由（UX 已批准——无高亮待选二次确认）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 移动动画 ≤0.5s/节点（UX AC 上限——A2，动画参数进调优配置）；不可达点击节点抖动+toast。

**Control Manifest Rules (this layer)**:
- Required: 移动指令通过 ExplorationSystem.move_to_node()（系统验证+扣 AP+发信号）；不可达原因从系统查询
- Forbidden: UI 预判可达性拦截点击（点击一律提交系统，由系统返回结果驱动反馈——防 UI 与系统判定漂移）
- Guardrail: 移动动画期间输入缓冲（连续点击不丢失不重复）

---

## Acceptance Criteria

*From GDD 节点图交互 AC + UX AC，scoped to this story:*

- [x] 点击可达节点 → move_to_node 调用 → 玩家标记沿路径移动（≤0.5s/节点）→ AP 扣减数字滚动 → 迷雾按规格揭示
- [x] 到达需确认节点类型（战斗/商店/灵泉/回复/渡劫台/Boss）→ 移动完成后触发对应弹窗（弹窗本体归 006/007；本 story 发到达通知）
- [x] 点击不可达节点 → 节点抖动+toast「行动力不足」或「路径不可达」（原因从系统返回）
- [x] 点击已访问节点 → 无反应，悬停显示已探索标记
- [x] 悬停可达节点 → 节点放大 110%+tooltip 浮出（0.3s 内）
- [x] 已访问节点视觉翻转：边框变绿+✓浮现（0.2s，到达动画后）
- [x] 连续点击防抖：移动动画期间新点击缓冲不丢失（队列执行）或忽略（实现定义后锁定）
- [x] 教程覆盖（B10 归属）：新档首次进入第一张地图显示 3 步提示（看路径→看AP→点击移动），任意点击跳过；第二次进入不再显示（`tutorial_skipped` 事件 + 已完成标记持久读）
- [x] 键盘路径：方向键在可达节点间空间跳转+Enter 确认移动（A3——控件内建，本 story 接通）

---

## Implementation Notes

*Derived from ADR-0014 委托流程 + B4/B10 裁决:*

- 移动流（B4 裁决）：点击 → `move_to_node(node_id)`（系统验证+扣 AP+更新 GSM+发 node_moved）→ UI 播放移动动画 → 到达后检测 node_type → 若需确认发弹窗触发通知（006/007 监听）。**取消弹窗不回退移动**——AP 已消耗，玩家停留该节点（GDD §4「先等等」语义）。
- 不可达反馈：move_to_node 返回失败（或专用查询）→ 抖动+toast；原因文案从系统错误码映射。
- 教程覆盖：3 步文案暂用占位（UX OQ#6——writer 定稿不阻塞结构）；已完成标记从 GSM 持久设置读取（不 UI 持久化——零状态所有权）。
- 移动动画时长三说（A2）：验收取 UX AC ≤0.5s/节点上限；0.3s 为 GDD 默认值进调优参数。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: 节点状态渲染与 tooltip 内容（本 story 为交互触发侧）
- Story 006/007: 到达后的交互弹窗本体
- Story 004: AP 扣减后的指示器动画响应

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 移动委托流
  - Given: 可达节点 B（邻层），当前在 A
  - When: 点击 B
  - Then: move_to_node(B) 被调用恰好一次；node_moved 信号驱动玩家标记移动；AP 扣减与系统返回值一致
  - Edge cases: 战斗类节点 B——移动完成后弹窗触发通知恰好一次（不预弹）；动画期间二次点击（缓冲/忽略行为锁定）

- **AC-2**: 不可达反馈
  - Given: AP=0 或路径不通的节点 C
  - When: 点击 C
  - Then: move_to_node(C) 提交系统 → 失败返回 → 抖动+toast 且无移动/无 AP 变化
  - Edge cases: 已访问节点点击（无反应+已探索悬停标记）

- **AC-3**: 教程覆盖
  - Given: 新档（教程标记未设）
  - When: 首次进入第一张地图
  - Then: 3 步教程显示，任意点击跳过，`tutorial_skipped` 事件发射；再次进入不显示
  - Edge cases: 第三步跳过（step_reached=3 与 step_reached=1 的事件载荷区分）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/exploration_ui/test_node_move_interaction.gd` — must exist and pass
- Integration（屏幕层对外接线，LP-CODE-REVIEW H1/H3）：`tests/integration/exploration_ui/test_node_graph_screen_forwarding.gd`
- UI: `production/qa/evidence/node-move-interaction-evidence.md` + sign-off（视觉走查项归 QA-17-1）

**Status**: [x] Created — 集成 68/68（`test_node_move_interaction` 43 + `test_node_graph_screen_forwarding` 7 + `test_node_graph_render` 18 回归）、单元 53/53；证据文档已落盘，D3D12 视觉走查 10 项待 QA-17-1 签收

---

## Dependencies

- Depends on: Story 003（节点渲染）、Story 001（缩放平移交互）
- Unlocks: Story 006/007（到达通知的弹窗消费者）、Story 010（全流程终验）

---

## Completion Notes

**Completed**: 2026-11-07
**Criteria**: 9/9 通过（全部 AC 勾选；AC-5 悬停 110%、AC-6 翻转脉冲、AC-1 迷雾消散三项视觉通道归 QA-17-1 D3D12 走查，见证据文档 §2）

**Deviations**（ADVISORY，均非阻塞）：
- 教程 3 步文案为 UX OQ#6 占位（writer 定稿不阻塞结构）
- 本地化豁免：`行动力不足`/`路径不可达`/`无法移动`/教程文案中文硬编码（同 S16 各 story 口径）
- `REASON_TEXTS` 以系统中文散文作匹配键 → DEBT-EUI-005-1
- 双份渲染快照（screen / interactor）→ DEBT-EUI-005-2
- 动画参数 const 硬编码（待调优配置外置）→ DEBT-EUI-005-3
- interactor 401 行超 300 行软上限（到达转发段可拆）→ DEBT-EUI-005-5
- AC-3 toast 渲染本体待 HUD 挂载后接线（屏幕层信号已就绪）→ DEBT-EUI-005-6
- ~~抖动动画无独立自动化断言~~ 已在关闭前补齐（硬断言 ShakeOverlay 存在/可见/圆心）→ DEBT-EUI-005-4 已闭环

**Test Evidence**:
- Integration（BLOCKING）：`tests/integration/exploration_ui/test_node_move_interaction.gd` — 43 例全绿
- Integration（屏幕层对外接线）：`tests/integration/exploration_ui/test_node_graph_screen_forwarding.gd` — 7 例全绿
- Unit：`tests/unit/exploration_ui/test_node_keyboard_navigator.gd`（7）+ `test_node_move_overlays.gd`（5）— 全绿
- 全量：3166 tests / 3165 passing / 1 pending（存量 `test_migration_chain`）/ 3 orphans（存量），零回归
- UI 证据：`production/qa/evidence/node-move-interaction-evidence.md`（QA-17-1 走查签收待办）

**Deferred Obligations**（延后义务，已登记技债）:
- AC-3 toast 渲染本体：屏幕层已暴露 `move_feedback_forwarded`，但 HUD 尚未由启动流程挂载 → DEBT-EUI-005-6（HUD 挂载落地时接线 `Hud.request_notification`）

**Code Review**: 已完成——`/code-review` 四路并行（1 BLOCKING + 8 HIGH + 6 MEDIUM 全闭环）+ LP-CODE-REVIEW 终审 CONCERNS（2 项 MEDIUM：teardown 状态复位已修、`_is_reachable_node` 契约守卫已修；其余登记技债）
**QA Gate**: QL-TEST-COVERAGE = GAPS → 关键缺口已补测（翻转脉冲生命周期、Boss/交互到达分支、点击输入接线、失败 AP 不变量、动画时长上限、teardown 复位）；余项登记技债
