# Story 005: 攻击目标选择交互（模式 A 点击式）

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 攻击目标选择 AC 7 条 + §7 攻击目标选择（模式 A）+ 待解决问题 #1（点击式为默认 MVP）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0008: 战斗系统七阶段状态机
**ADR Decision Summary**: Phase 3 推进条件 `all_characters_targeted || player_confirmed_skip || _attack_queue.is_empty()`——空攻击队列时空真自动跳过（首回合全待命）。待命/已行动角色不可攻击（UI 灰显）。advance_phase() 验证前置条件，返回 false 时 UI 高亮未分配目标。

**ADR 次要参考**: ADR-0016（is_targetable 前后排保护 O(1) 查询——UI 目标合法性不自算）
**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: 蓝色脉冲/红色高亮用 Tween 循环动画；箭头连线为 2D 线条绘制（Line2D 或等效）。

**Control Manifest Rules (this layer)**:
- Required: 目标合法性从 DeploymentSystem.is_targetable() 查询（UI 不自算前后排保护）
- Forbidden: 跳过 advance_phase() 验证（全声明完由系统判定推进，UI 仅委托）
- Guardrail: 阶段 3 交互响应 <1 帧

---

## Acceptance Criteria

*From GDD 攻击目标选择 AC + §7，scoped to this story:*

- [ ] 进入阶段 3：模式指示器提示文字「点击选择攻击目标」——动画出现 0.2s → 停留 1s → 淡出 0.3s
- [ ] 可攻击己方角色（READY 态）头像外圈蓝色脉冲光效；待命/已行动角色灰显不可选（A3——ADR-0008 明文）
- [ ] 点击己方角色 → 该角色可攻击的敌方目标红色边框+脉冲；不可攻击目标（前排保护后排——`is_targetable()` false）灰色+🔒
- [ ] 点击敌方目标 → attack_declared（委托 CombatSystem）→ 角色→目标箭头连线显示
- [ ] 点击已声明目标的角色 → 清除已有目标，可重新选择
- [ ] 已声明角色显示标记提示；多个角色攻击声明可任意顺序进行
- [ ] 每个角色旁「跳过」按钮 → 该角色不攻击，显示「跳过」标记
- [ ] 所有己方角色声明完（或跳过完）→ 自动进入阶段 4（ADR-0008 推进条件——系统侧判定，UI 委托后收 phase_changed）
- [ ] **键盘/手柄路径（B7 补）**：Tab+Enter / 方向键+A 完成选择攻击者→选目标全流程；右键/ESC/B 取消当前选择（UX #9）
- [ ] 空攻击队列（首回合全待命）→ 阶段 3 空真自动跳过——UI 无目标选择展示、直接收 phase_changed（A3 注记）

---

## Implementation Notes

*Derived from ADR-0008/0016 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`TargetSelectionModel`（或等效纯类）——`can_select_attacker(character_state) -> bool`（排除待命/已行动）、`select_target(attacker_id, target_id, declarations) -> Dictionary`（更新声明集）、`all_declared(attackers, declarations) -> bool`（空真语义）。

- 目标合法性：`DeploymentSystem.is_targetable(target_id, penetration)` 查询——穿透标记从攻击者绑定/效果查询。
- 声明提交：每条 attack_declared 委托 CombatSystem（系统记录攻击队列）；全部完成由系统 advance_phase 判定（UI 不自推）。
- 箭头连线：已声明对的视觉连线（攻击者→目标），重选时旧线移除。
- 键盘/手柄复用 story 004 焦点循环基建。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: 出牌的临时目标选择态（出牌目标，非攻击目标）
- layout story 002/003: 角色卡渲染与状态标记（灰显渲染基础）
- ADR-0008 域: 攻击结算（Phase 4）的执行逻辑
- 待解决问题 #1 的 A/B 测试（原型阶段任务，非 story）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_target_selection_model.gd`）

- **AC-1**: 目标选择模型
  - Given: 攻击者集（READY/STANDBY/ACTED 混合）与声明集
  - When: 调用 can_select_attacker / all_declared
  - Then: STANDBY/ACTED 不可选；空攻击者集 all_declared → true（空真）；全 READY 未声明 → false
  - Edge cases: 1 个攻击者声明后 all_declared → true；跳过标记视同已声明

**[Integration — automated test specs]:**

- **AC-2**: 声明委托与推进
  - Given: 阶段 3，2 个 READY 攻击者
  - When: 依次声明 2 个目标
  - Then: attack_declared 委托调用 ×2（mock 断言）；全声明后 advance_phase 由系统触发（phase_changed 到 4 断言）
  - Edge cases: is_targetable=false 目标点击 → 无调用+🔒视觉；重选清除旧声明再提交

**[UI — manual verification steps]:**

- **AC-3**: 目标选择视觉
  - Setup: 阶段 3，构造前排保护/待命/已声明场景
  - Verify: 蓝色脉冲/红色高亮/灰色🔒/箭头连线/跳过标记全部正确；提示文字动画时序
  - Pass condition: 全状态可区分、键盘手柄路径可用

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_target_selection_model.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_attack_declaration.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/target-selection-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（锁栈/焦点基建）、Story 004（焦点循环）、layout story 003（角色标记渲染）
- Unlocks: Story 009（箭头元素入峰值复测）
