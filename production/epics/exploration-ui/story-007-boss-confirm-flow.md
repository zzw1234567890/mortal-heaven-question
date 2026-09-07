# Story 007: Boss 战前确认与进入战斗流

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: Boss 战前确认 3 条 AC（B3 修正后语义——角色数战力+50% 修为警示）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0005: 场景管理器（主要——EXPLORE_TO_COMBAT 转换）+ ADR-0014（次要——boss_node_reached 信号）
**ADR Decision Summary**: Boss 节点经 boss_node_reached 信号触发专属确认弹窗（非 node_interaction_triggered 分发）；「进入战斗」经 SceneManager 5 阶段管线切换（EXPLORE_TO_COMBAT 快速切入 0.5s BGM 过渡）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Boss 节点放大闪烁 0.4s 后弹出确认面板（GDD 动画表）；TransitionType.EXPLORE_TO_COMBAT 已存在于 ADR-0005 枚举。

**Control Manifest Rules (this layer)**:
- Required: 场景切换必须经 SceneManager.request_scene_change()（禁止直接 change_scene_to_file）；转场输入锁由 SceneManager 管线处理
- Forbidden: UI 自行计算战力或卡组数量（推荐角色数从地图配置读、卡组数量从卡牌系统读）
- Guardrail: 转场期间探索场景状态不泄漏（加载画面独立场景——ADR-0005 Phase 3）

---

## Acceptance Criteria

*From GDD Boss 确认 AC（B3 修正后），scoped to this story:*

- [ ] 到达 Boss 节点 → Boss 节点放大闪烁（0.4s）→ 弹出 Boss 战确认窗口（boss_node_reached 信号驱动）
- [ ] 确认窗口内容：地图名+Boss 敌人信息+推荐上场角色数（如「至少2个角色上场」）+卡组数量（如 28/30 张）
- [ ] 警示文案：「进入 Boss 战后撤退将视为战败处理——保留 50% 本局修为」（朱砂红高亮；80% 为渡劫专属不得混用——B3 裁决）
- [ ] 点击「进入战斗」→ SceneManager.request_scene_change(EXPLORE_TO_COMBAT) → 战斗场景加载（加载画面+转场锁全由 SceneManager 管线处理）
- [ ] 点击「再准备一下」→ 返回节点图，玩家停留在 Boss 节点（AP 已消耗不回退）
- [ ] 转场期间输入锁定验证：从确认点击到战斗场景就绪，无探索输入响应

---

## Implementation Notes

*Derived from ADR-0005 5 阶段管线 + ADR-0014:*

- Boss 信号区分：boss_node_reached（ADR-0014 L215）独立于 node_interaction_triggered——Boss 弹窗为专属规格（更大、危险样式、警示行）。
- 推荐角色数：探索系统地图配置（boss_data 载荷或 get_node_detail）；卡组数量：卡牌系统 API 只读。
- 场景切换：request_scene_change(from=EXPLORATION, to=COMBAT, type=EXPLORE_TO_COMBAT)——本 story 只发请求，5 阶段管线（自动存档/输入锁/加载画面）为 SceneManager 既有行为。
- 「再准备一下」：仅关弹窗——玩家停留 Boss 节点可再次点击弹窗（GDD 边界情况：AP=0 时 Boss 节点仍可交互）。
- 战斗胜利（非 Boss？Boss 胜利即通关）返回路径归 story 008（B8 裁决——返回恢复流在 008 认领）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: 战斗结束后返回探索的恢复流+战败路径（B8 归属）
- Story 006: 非 Boss 节点弹窗（本 story 仅 Boss 专属）
- 战斗 UI epic: 战斗场景本体

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: Boss 确认弹窗触发
  - Given: 玩家移动到达 Boss 节点
  - When: boss_node_reached 信号发射
  - Then: Boss 弹窗打开（非 node_interaction_triggered 路径）；内容含地图名/敌人/推荐角色数/卡组数/50% 警示文案
  - Edge cases: AP=0 时到达 Boss 节点（仍可交互——GDD 边界情况）

- **AC-2**: 进入战斗转场
  - Given: Boss 弹窗打开
  - When: 点击「进入战斗」
  - Then: request_scene_change(EXPLORATION→COMBAT, EXPLORE_TO_COMBAT) 被调用恰好一次；转场期间探索 UI 输入无响应
  - Edge cases: 双击「进入战斗」（转场中二次请求被 SceneManager 拒绝——_transitioning 守卫）

**[UI — manual verification steps]:**

- **AC-3**: Boss 弹窗走查
  - Setup: 到达 Boss 节点
  - Verify: 0.4s 放大闪烁→弹窗（危险样式）→警示行朱砂红→「再准备一下」返回节点图
  - Pass condition: 与 GDD §5 线框+UX 危险样式规范一致 + 签批

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/exploration_ui/test_boss_confirm_flow.gd` — must exist and pass
- UI: `production/qa/evidence/boss-confirm-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005（到达通知）、Story 006（弹窗冻结基建复用）
- Unlocks: Story 008（战斗结束返回恢复流）、Story 010（全流程终验）
