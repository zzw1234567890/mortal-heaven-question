# Story 006: 节点交互弹窗（战斗/商店/灵泉/回复/渡劫台）

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`（含 2026-09-08 补充的 §4b 渡劫台弹窗 + §4c 分发表）
**Requirement**: 节点交互弹窗 AC（B5 修正后 9 条）+ 节点弹窗背景模糊性能 AC
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0014: 探索系统（主要——node_interaction_triggered 分发）+ ADR-0031（次要——弹窗冻结/渲染）
**ADR Decision Summary**: node_interaction_triggered 信号按 interaction_type 分发到对应弹窗（B5 裁决：五类弹窗+显式排除事件节点+传送暂缓）；商店为 UI overlay 非场景切换（B9 裁决）；先移动后弹窗（B4 裁决）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（背景实时模糊 40% 的 D3D12 性能——A8）
**Engine Notes**: 弹窗从节点位置放大淡入 0.2s/关闭缩小淡出 0.15s；背景模糊 40% 用 ColorRect+shader 或 CanvasLayer 方案实测。

**Control Manifest Rules (this layer)**:
- Required: 弹窗打开时节点图输入冻结（缩放/平移/点击无效——输入锁或 mouse_filter）；弹窗在节点附近弹出（不覆盖全屏）
- Forbidden: 事件节点弹窗（EventSystem 面板接管——显式排除规则）；UI 计算回复量/商店价格（系统 API 返回）
- Guardrail: 背景模糊 40% 开启时帧率不低于 60fps（A8——本 story 完成时即抽查，不等 010）

---

## Acceptance Criteria

*From GDD 节点弹窗 AC（B5/B9 修正后），scoped to this story:*

- [ ] node_interaction_triggered 信号 → 按 interaction_type 分发：战斗/精英→战斗确认弹窗、商店→商店弹窗、灵泉→灵泉弹窗、回复点→回复弹窗、渡劫台→渡劫台弹窗（§4c 分发表）
- [ ] 战斗确认弹窗：敌人名称+数量+境界+推荐战力（角色数）+「进入战斗/先等等」按钮
- [ ] 点击「先等等」/「离开」→ 弹窗关闭，玩家停留在该节点（AP 已消耗不回退——B4 裁决）
- [ ] 灵泉弹窗「使用灵泉」→ 行动力回复全部（探索系统 API）→ 指示器从空到满逐格亮起（0.5s，004 响应）
- [ ] 回复点弹窗「休息」→ 全队回复 50% 已损失 HP（系统 API；文案与公式 7 一致——B1 修正）
- [ ] 渡劫台弹窗（修为已满）：80% 修为损失警示（朱砂红高亮——渡劫专属，不与 Boss 50% 混用）+「挑战渡劫/再等等」；「挑战渡劫」→ SceneManager TRIBULATION 转换
- [ ] 渡劫台修为未满：无弹窗，节点显示「修为尚未圆满」不可触发状态（003 渲染联动）
- [ ] 商店弹窗「进入商店」→ 商店以 UI overlay 呈现（B9 裁决——节点图冻结，非场景切换）；商店内容渲染归商店 UI 后续 epic，本 story 提供 overlay 容器与冻结
- [ ] 事件节点：无探索 UI 弹窗——EventSystem 事件面板接管（显式排除，防双面板回归断言）
- [ ] 传送节点：无交互实现（B5 裁决——机制未闭合，按普通节点渲染）
- [ ] 弹窗打开时背景节点图可见但不可操作；背景模糊 40% 且帧率 ≥60fps（A8 抽查）

---

## Implementation Notes

*Derived from ADR-0014 决策 3 + B4/B5/B9 裁决:*

- 分发表数据驱动：interaction_type → 弹窗场景映射（§4c 表为规格）——可提纯函数单测（类型→弹窗→确认动作三元组）。
- 渡劫台走 `node_interaction_triggered`（ADR-0014 L216 含渡劫台）而非独立信号——与 Boss（boss_node_reached，归 007）区分。
- 商店 overlay：CanvasLayer 或全屏 Control 弹层；节点图冻结用 InputManager 锁或 mouse_filter 树切换（与 combat-ui 弹窗冻结先例一致——MOUSE_FILTER_STOP 策略）。
- 背景模糊：实现后立即在 D3D12 下抽查帧率（A8）——不达标记录并上报（不在本 story 内优化到 010）。
- 灵泉/回复的确认调用探索系统 API（效果数值系统侧返回）——UI 零数值计算。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: Boss 战前确认弹窗（独立规格——boss_node_reached 信号）
- Story 005: 移动交互与到达通知触发
- 商店 UI epic: 商店内容渲染（本 story 仅 overlay 容器）
- 探索系统域: 灵泉回复/回复点治疗的效果执行

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 分发表路由
  - Given: 五种 interaction_type 信号依次到达（combat/shop/spring/rest/tribulation）
  - When: node_interaction_triggered 发射
  - Then: 各自弹窗打开且仅一个弹窗实例存在；事件节点类型不在分发表中（event_node_reached 信号不产生任何探索 UI 弹窗——防双面板断言）
  - Edge cases: 渡劫台修为未满——信号载荷含 not_ready 标记时无弹窗

- **AC-2**: 确认/取消流
  - Given: 战斗弹窗打开
  - When: 点击「先等等」
  - Then: 弹窗关闭；玩家位置/AP 不变（停留该节点）；无场景切换
  - Edge cases: 弹窗期间 ESC（关闭弹窗等效「先等等」——UX AC）

**[UI — manual verification steps]:**

- **AC-3**: 五类弹窗走查
  - Setup: 依次到达五类节点
  - Verify: 弹窗内容（敌人信息/80% 警示朱砂红/50% 回复文案）+ 节点附近弹出+背景模糊可拖影
  - Pass condition: 与 §4/§4b 线框逐项一致 + 模糊开启时 60fps 抽查记录 + 签批

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/exploration_ui/test_node_interaction_popups.gd` — must exist and pass
- UI: `production/qa/evidence/node-popups-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005（到达通知）、Story 003（节点状态——渡劫台不可触发态）
- Unlocks: Story 010（全流程终验）、商店 UI epic（overlay 容器宿主）
