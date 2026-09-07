# Story 007: 备战面板（视觉框架与状态判定）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 备战阶段 AC 6 条（静态侧 5 条）+ §8 备战界面规则
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 划界裁决 2026-09-07：**视觉框架+状态判定纯函数+信号驱动渲染归本 story**；输入流转（点选/拖拽阵位/替换确认流）归 interaction epic。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 阵位布局按境界动态调整（炼气前2后1/筑基前2后2/金丹前2后2/元婴前3后2/化神前3后3）；max_deploy 炼气2~化神6。

**Control Manifest Rules (this layer)**:
- Required: 4 态判定/max_deploy 阵位映射/确认按钮状态纯函数单测
- Forbidden: 硬编码境界→阵位映射（数据驱动配置）
- Guardrail: 阵位预览更新 ≤1 帧（渲染侧；拖拽触发归 interaction）

---

## Acceptance Criteria

*From GDD，scoped to this story:*

- [ ] 备战面板视觉框架：战斗名称标题、角色缩略卡列表（头像/HP/ATK/绑定概览）、阵位布局预览（前后排）、确认出战/返回按钮
- [ ] 角色选择 4 态渲染：已选（✓+金色高亮）/可选未选（☐）/可替换（⊕，名额满时）/不可用（💀灰色，阵亡）
- [ ] 4 态判定纯函数：输入 (is_dead, is_selected, selected_count, max_deploy) → 4 态之一（阵亡优先）
- [ ] 阵位布局映射：境界 → (前排位数, 后排位数) 数据驱动（炼气 2/1 … 化神 3/3）；slots 总数 ≥ max_deploy
- [ ] 已选人数不满上限显示「还可以选择X人」；确认按钮在 ≥1 已选角色时才可点
- [ ] 阵位预览随选择状态实时更新（信号驱动渲染）
- [ ] 悬停角色显示协同信息概览（渲染态；tooltip 交互归 interaction）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `deploy_selection_state(is_dead, is_selected, selected_count, max_deploy) -> String`——4 态判定（阵亡优先于可替换）。
- `formation_slot_layout(realm_id) -> Dictionary`——境界→前后排位数映射（数据驱动常量；slots ≥ max_deploy 不变量校验；未知 realm 显式报错）。
- `confirm_button_enabled(selected_count) -> bool`——≥1 可点。

- 可选角色列表从上场系统/卡牌系统读取（含阵亡状态）；选择状态为**瞬态交互状态**（UI 本地合法，ADR-0031 §2.1）——确认出战前不写回系统。
- 「返回探索」触发 SceneManager 转场。
- 替换确认弹窗（名额满点 ⊕）：弹窗框架归本 story，替换决策流与 character_undeployed/deployed 事件归 interaction。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- interaction epic: 角色点选流转/阵位拖拽调整（1 帧更新交互侧）/替换确认决策/数字键选择
- Story 008: 渡劫战前 warning（在备战面板前弹出的对话框——归 008 弹窗框架）
- Story 002: 角色卡组件（备战用缩略卡独立实现）
- audio-manager epic: 选择/确认音

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_deploy_selection_state.gd` + `test_formation_slot_layout.gd`）

- **AC-1**: 4 态判定
  - Given: (is_dead, is_selected, selected_count, max_deploy)
  - When: 调用 `deploy_selection_state()`
  - Then: 阵亡 → 不可用（优先）；已选 → ✓；未选+未满 → ☐；未选+已满+未阵亡 → ⊕
  - Edge cases: 阵亡且名额未满（仍不可用——阵亡优先）；selected_count==max 恰好边界；max=1

- **AC-2**: 境界→阵位映射
  - Given: realm_id
  - When: 调用 `formation_slot_layout()`
  - Then: 炼气(2,1)/筑基(2,2)/金丹(2,2)/元婴(3,2)/化神(3,3)；slots 总数 ≥ max_deploy（炼气 3≥2）
  - Edge cases: 未知 realm → 显式报错（非静默默认）

- **AC-3**: 确认按钮状态
  - Given: selected_count
  - When: 调用 `confirm_button_enabled()`
  - Then: 0 → false；1 → true；满员 → true
  - Edge cases: 0/1 边界

**[UI — manual verification steps]:**

- **AC-4**: 备战面板视觉
  - Setup: 五个境界分别进入备战
  - Verify: 4 态标记正确（构造阵亡/满员场景）；五个阵位布局截图对比；「还可以选择X人」提示
  - Pass condition: 布局与境界映射表一致、4 态视觉可区分、确认按钮灰态正确

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_deploy_selection_state.gd` + `test_formation_slot_layout.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/deploy-panel-evidence.md` + sign-off（五境界截图）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（布局骨架）
- Unlocks: interaction epic（备战交互流消费本 story 框架与判定函数）
