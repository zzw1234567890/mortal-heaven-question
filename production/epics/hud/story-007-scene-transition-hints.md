# Story 007: 场景切换过渡提示

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: §7 过渡提示（边界澄清 2026-09-07 归属裁决：过渡提示归 HUD）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 过渡提示由 SceneManager `pre_transition` 信号驱动（ADR-0031 引用）；通关结算面板、新地图解锁提示归 exploration-ui（不在本 story）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 过渡提示为非交互瞬时显示（无点击/焦点需求）。SceneManager 既有信号：`pre_transition(from, to, type)`、`post_transition`（src/foundation/scene_manager.gd L58/L62）。

**Control Manifest Rules (this layer)**:
- Required: 提示显示由转场信号驱动，非轮询；无交互元素则不设焦点
- Forbidden: 用过渡提示承载游戏逻辑（纯信息展示）
- Guardrail: 过渡动画计入转场总时长（探索→战斗 1s 内完成）

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md` §7 过渡提示表，scoped to this story:*

- [ ] 探索→战斗：「进入战斗」+ 战斗名称，持续 1s
- [ ] 探索→商店：「坊市」图标浮现，持续 0.5s
- [ ] 战斗→探索：无过渡提示（直接过渡）
- [ ] 地图加载：「加载中...」进度指示，按加载时间显示
- [ ] 提示由 SceneManager `pre_transition` 信号驱动，自动消失无需玩家交互

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- 订阅 `SceneManager.pre_transition(from, to, type)`，按 (from, to) 组合查提示映射表（数据驱动常量：组合 → {文本/图标, 时长}）。未映射组合（如战斗→探索）不显示。
- 地图加载提示挂接 SceneManager 加载阶段（若加载为异步阶段则显示进度指示，加载完成由 `post_transition` 关闭）。
- 提示层为 HUD CanvasLayer 内独立子容器，转场期间不受 Story 001 战斗隐藏规则影响（过渡发生在转场中，HUD 可见性切换前后均可显示）。
- 与 Story 004 通知队列**相互独立**——过渡提示不进通知队列（不同生命周期与触发源）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载骨架（本 story 消费 CanvasLayer 容器）
- Story 004: 通知/提示队列（道具/灵石等游戏事件通知）
- exploration-ui epic: 通关结算面板、新地图解锁提示（「新地图已解锁」3s/点击关闭）
- 地图选择→探索的转场细节渲染：归 SceneManager 既有转场管线

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic — automated test specs]:**

- **AC-1**: 转场组合→提示映射
  - Given: 过渡映射表（数据驱动常量）
  - When: 以 (exploration, combat) 组合查询
  - Then: 返回「进入战斗」提示配置（1s）；(exploration, shop) 返回「坊市」（0.5s）；(combat, exploration) 返回空（无提示）
  - Edge cases: 未映射组合返回空不报错；同一转场类型不同 TransitionType 的行为

- **AC-2**: 信号驱动显示与自动消失
  - Given: HUD 已挂载
  - When: SceneManager 发射 `pre_transition(exploration, combat, ...)`
  - Then: 提示容器 visible 且内容正确；时间推进 1s 后自动隐藏
  - Edge cases: 提示显示期间再次转场（旧提示替换/关闭，确定性规则）

**[UI — manual verification steps]:**

- **AC-3**: 过渡提示视觉效果
  - Setup: 从探索进入一场战斗
  - Verify: 「进入战斗」+ 战斗名称浮现约 1s 后消失，随后战斗场景就绪
  - Pass condition: 提示不遮挡关键信息、不延长总转场时长、无闪烁残留

---

## Test Evidence

**Story Type**: UI（含 Logic 映射判定）
**Required evidence**:
- Logic: `tests/unit/hud/test_transition_hint_mapping.gd`（AC-1 映射纯函数）— must exist and pass（BLOCKING）
- Integration: AC-2 信号驱动断言并入 `tests/integration/hud/hud_scene_visibility_test.gd`（与 Story 001 共用文件，追加用例）— must exist and pass（BLOCKING）
- UI: `production/qa/evidence/transition-hint-evidence.md` + sign-off（视觉效果手动验证）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（HUD CanvasLayer 容器）
- Unlocks: None
