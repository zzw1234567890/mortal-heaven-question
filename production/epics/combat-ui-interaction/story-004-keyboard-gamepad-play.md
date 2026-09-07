# Story 004: 键盘快捷与手柄出牌路径

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 待解决问题 #3（键盘快捷键——本 story 落地并标记已解决）+ 边界澄清补充二（数字键需目标卡子流程/>7 张映射）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0004: 输入管理器（双路径：GAMEPLAY 键盘 Input Map 轮询 + UI_NAV `_input()` 拦截）
**ADR Decision Summary**: GAMEPLAY 键盘动作 → Input Map 轮询（`Input.is_action_just_pressed()`——不受 GUI 焦点影响）；UI_NAV 快捷键 → `_input()` 在 GUI 派发前拦截；4.6 双焦点设备独立判定。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `grab_focus()` 仅影响键盘/手柄焦点（4.6）；焦点循环 Tab/Shift+Tab 走标准 FocusMode。

**Control Manifest Rules (this layer)**:
- Required: 数字键/方向键交互过 `is_input_allowed(GAMEPLAY, KEYBOARD/GAMEPAD)`
- Forbidden: 假设键盘与鼠标焦点同源（4.6 双焦点——各自独立判定）
- Guardrail: 快捷键判定 O(1)

---

## Acceptance Criteria

*From UX 交互地图 #6/#8/#9/#10 + GDD 边界澄清补充二，scoped to this story:*

- [ ] 数字键 1-7 快捷选牌：按下选中对应卡牌（选中态闪烁+高亮——UX #6）
- [ ] 无目标需求卡牌：数字键按下 → 直接出牌（复用 story 003 的 CombatSystem.play_card 调用链）
- [ ] **需目标卡牌子流程（B8a 裁决）**：数字键按下 → 进入临时目标选择态——焦点移至可选目标区（敌方/己方角色高亮），Enter/A 确认出牌，ESC/B 取消返回手牌（不出牌、不扣费）
- [ ] **>7 张窗口偏移映射（B8b 裁决）**：数字键 1-7 映射**当前可见窗口内**的 7 张卡（滚轮浏览后映射随之偏移），非固定前 7 张
- [ ] Tab/Shift+Tab 焦点循环：所有可交互元素（顶部条→敌方区→己方区→底部条→手牌区——UX 无障碍章节顺序）键盘可达，焦点环可见
- [ ] 手柄全流程出牌（无需鼠标）：方向键/左摇杆选手牌 → A 键选中 → 方向键选目标 → A 确认打出
- [ ] 滚轮（鼠标）/LB RB（手柄）翻页：>7 张溢出卡牌左右滚动浏览
- [ ] 「结束出牌」按钮 Enter/手柄 A 确认 → player_confirmed_end（layout story 005 渲染位）
- [ ] 手柄 B 键：取消当前选择/返回上级（与 ESC 语义一致——经 story 001 仲裁）
- [ ] 数字键在阶段 2 外无效（灵能预览态只读——与拖拽锁定一致）

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`digit_key_to_card_index(digit, window_offset, hand_size) -> int`——数字键+当前窗口偏移 → 手牌索引（越界返回 -1 不出牌）。

- 键盘路径 A（Input Map 轮询）：数字键 1-7 定义为 Input Map 动作（可重映射，ADR-0004 惯用法）。
- 焦点循环：各区域容器 focus_neighbor 设置顺序链——UX 无障碍章节的手柄顺序（顶部条→敌方→己方→底部条→手牌）。
- 临时目标选择态：复用 story 005 的目标高亮基建（可选目标列表查询同一 API）。
- GDD 待解决问题 #3 随本 story 关闭——标记「已解决（2026-09-07，采用 UX 数字键设计）」。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: 鼠标拖拽路径（出牌调用链共享）
- Story 005: 攻击目标选择的完整交互（本 story 的临时目标选择态仅用于出牌目标）
- Story 002: 焦点环视觉基建（story 001 已建，本 story 应用）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_digit_key_mapping.gd`）

- **AC-1**: 数字键窗口映射
  - Given: 手牌 9 张，窗口偏移 0 / 1 / 2
  - When: 按数字键 1 与 7
  - Then: 偏移 0 → 索引 0/6；偏移 1 → 索引 1/7；偏移 2 → 索引 2/8
  - Edge cases: 手牌 3 张时按 5 → -1（不出牌）；手牌 0 张任意键 → -1；窗口末尾（偏移 = hand_size-7）恰映射最后 7 张

**[Integration — automated test specs]:**

- **AC-2**: 数字键出牌
  - Given: 阶段 2，卡 1 无目标需求
  - When: 按数字键 1
  - Then: CombatSystem.play_card 调用断言（同 story 003 AC-2 模式）
  - Edge cases: 需目标卡按数字键 → 临时目标选择态进入（无 play_card 调用直至 Enter 确认）；ESC 取消 → 无调用无扣费

- **AC-3**: 焦点循环
  - Given: 战斗 UI 激活
  - When: 依次 Tab
  - Then: 焦点按 UX 定义顺序遍历全部可交互元素（节点序列断言），焦点环可见
  - Edge cases: Shift+Tab 反向；焦点在手牌区时数字键仍全局生效

**[UI — manual verification steps]:**

- **AC-4**: 手柄全流程
  - Setup: 断开鼠标，手柄连接，阶段 2
  - Verify: 方向键+A 完成「选手牌→选目标→出牌」全流程；B 取消正确
  - Pass condition: 全流程无鼠标依赖

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_digit_key_mapping.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_keyboard_shortcut_play.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/keyboard-gamepad-play-evidence.md` + sign-off（手柄走查）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（焦点环/锁栈基建）、Story 003（出牌调用链）
- Unlocks: Story 005（复用焦点基建与目标选择基建）
