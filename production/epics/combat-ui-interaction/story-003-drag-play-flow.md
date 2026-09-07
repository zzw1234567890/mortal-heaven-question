# Story 003: 鼠标拖拽出牌流转

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 手牌交互 AC 4 条 + 边界情况（拖拽中阶段切换/手牌溢出）+ 边界澄清补充二（结束出牌按钮点击/撤退排队）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0004: 输入管理器（GAMEPLAY 动作 + 鼠标设备判定）
**ADR Decision Summary**: 路径 C——鼠标交互走 `_gui_input()`，入口先查 `is_input_allowed(GAMEPLAY, MOUSE)`。玩家操作发语义信号，系统执行后广播回来。

**ADR 次要参考**: ADR-0008（Phase 2→3 推进条件 player_confirmed_end）、ADR-0009（出牌→CardEffectEngine.resolve）
**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: 拖拽中半透明 modulate.a=0.7 的 Control 在 D3D12 下的表现——三档（0.3/0.5/0.7）烟雾归 story 009。

**Control Manifest Rules (this layer)**:
- Required: 拖拽点击过锁栈（GAMEPLAY+MOUSE）；出牌经 CombatSystem API（UI 不扣费不结算）
- Forbidden: UI 直接写 GSM/费用（CostSystem.spend 由系统侧执行）
- Guardrail: 输入驱动的纯视觉变换（拖拽跟随）不视为轮询

---

## Acceptance Criteria

*From GDD 手牌交互 AC + 边界情况，scoped to this story:*

- [ ] 拖拽启动阈值 8px：按住卡牌移动 ≥8px 启动拖拽（<8px 视为点击/悬停，不误触）
- [ ] 拖拽中：卡牌跟随鼠标、半透明 0.7、可用目标区域高亮（角色位/阵法位）
- [ ] 阵法位为有效拖拽目标（阵法部署：卡牌飞向阵法区 0.3s + 光环 0.4s）；已 3 阵法时释放 → 拒绝（回弹+提示）
- [ ] 释放在有效目标 → 出牌执行：`card_played` 事件（CombatSystem.play_card 委托——费用扣减经 CostSystem、效果结算经 CardEffectEngine，UI 不做任何数值操作）
- [ ] 释放在无效区域 → 卡牌回弹手牌原位（0.2s 动画），无费用扣减
- [ ] 拖拽进行中阶段结束（玩家点结束出牌/全角色已行动）→ 卡牌飞回手牌原位（0.2s），阶段正常切换，卡牌不出场（GDD 边界情况）
- [ ] 拖拽进行中弹出 MODAL（如撤退确认）→ 拖拽中止、卡牌回弹（边界情况，A6 裁决）
- [ ] 费用不足卡牌不可拖拽（消费 layout story 006 灰显渲染——灰显态 drag 启动即拒绝）
- [ ] 阶段 2 外（灵能预览态）不可拖拽（仅悬停查看——layout 006 渲染，本 story 锁定交互拒绝）
- [ ] 「结束出牌」按钮（layout story 005 渲染位）鼠标点击 → `player_confirmed_end` 推进 Phase 2→3（ADR-0008）
- [ ] 悬停预览与拖拽的次序：拖拽启动时关闭悬停预览面板（story 002 状态机联动）

---

## Implementation Notes

*Derived from ADR-0004/0008 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：拖拽状态机纯函数/纯类 `DragStateMachine`——`should_start(press_pos, current_pos) -> bool`（8px 阈值）、`evaluate_release(drop_target) -> ReleaseResult`（枚举：PLAY_CARD / DEPLOY_FORMATION / FORMATION_FULL / RETURN_HAND）。

- 出牌调用链：释放有效 → `CombatSystem.play_card(card_instance_id, targets)`——费用/效果/手牌移除全部系统侧完成，UI 收 Cat 1/Cat 2b 信号刷新。
- 阶段结束回弹：phase_changed 信号到达且拖拽中 → 触发回弹（不等释放）。
- 目标区域高亮：拖拽启动时向有效目标列表的节点发高亮请求（目标合法性从 CombatSystem 查询，UI 不自算）。
- A1 修正：灰显消费方是 **layout story 006**（手牌静态状态），非 005。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 悬停预览本体（本 story 仅联动关闭）
- Story 004: 键盘数字键/手柄出牌路径（含结束按钮的 Enter/A 确认）
- layout story 006: 灰显/灵能预览渲染
- layout story 005: 结束出牌按钮渲染位
- Story 009: 拖拽半透明 D3D12 三档烟雾
- 阵法部署的效果结算（FormationSystem 域）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_drag_state_machine.gd`）

- **AC-1**: 拖拽状态机
  - Given: 按下卡牌
  - When: 位移 7px / 8px / 9px
  - Then: 7px 不启动；8px 启动；9px 启动（阈值含边界）
  - Edge cases: 释放目标为空/无效区域 → RETURN_HAND；阵法区满 → FORMATION_FULL；角色目标 → PLAY_CARD

**[Integration — automated test specs]:**

- **AC-2**: 出牌委托调用
  - Given: 阶段 2，可出牌
  - When: 拖拽有效目标释放
  - Then: CombatSystem.play_card 被调用（mock 断言，含 card_instance_id 与 targets）；UI 无费用写操作
  - Edge cases: 拖拽中 phase_changed 到达 → 回弹且 play_card 未调用；拖拽中 MODAL push → 回弹

- **AC-3**: 结束出牌按钮
  - Given: 阶段 2
  - When: 点击「结束出牌」
  - Then: player_confirmed_end 触发（CombatSystem.advance_phase 委托调用断言）
  - Edge cases: 非阶段 2 点击 → 无效（按钮隐藏，消费 layout 005 渲染态）

**[UI — manual verification steps]:**

- **AC-4**: 拖拽手感
  - Setup: 阶段 2 手牌
  - Verify: 8px 启动、0.7 半透明跟随、目标高亮、回弹动画 0.2s
  - Pass condition: 无误触、无丢卡、视觉反馈完整

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_drag_state_machine.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_drag_play_card.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/drag-play-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（锁栈）、Story 002（悬停联动）、layout story 006（手牌渲染）
- Unlocks: Story 004（快捷路径复用出牌调用链）、Story 009（拖拽烟雾）
