# Story 001: 输入锁栈接入基座与 ESC 仲裁（基建 story）

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 交互侧 AC——弹窗冻结/暂停转发/输入锁（边界澄清补充二 2026-09-07：ESC 仲裁/撤退排队/MOUSE_FILTER_STOP 统一）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0004: 输入管理器（四级锁栈 + 设备类型独立判定）
**ADR Decision Summary**: 路径 B（`_input()` 拦截）+ `is_input_allowed(action_type, device)` O(1) 判定 + push/pop 配对（source 追踪）。4.6 双焦点：`grab_focus()` 仅影响键盘/手柄焦点，鼠标焦点独立。

**ADR 次要参考**: ADR-0031（§4 双焦点双视觉——焦点环松石青 2px/悬停墨色边框，同时激活优先悬停态）
**Engine**: Godot 4.6 | **Risk**: HIGH（R-01 双焦点 spike 前置——本 story 消费其结论）
**Engine Notes**: 双焦点在自定义 Control 上的行为属引擎参考验证范围（ADR-0004 OQ-02）；ESC 拦截用 `_input()` 在 GUI 派发前（路径 B）。

**Control Manifest Rules (this layer)**:
- Required: 交互入口先查 `is_input_allowed(action_type, device)`；锁 push/pop 配对（StringName source 追踪）
- Forbidden: 绕过锁栈直接监听 `_gui_input()` 做游戏行为（焦点高亮可以，改变游戏状态的点击必须过锁栈）
- Guardrail: `is_input_allowed()` <0.005ms/调用

---

## Acceptance Criteria

*From GDD 边界澄清补充二 + ADR-0004，scoped to this story:*

- [ ] ESC 仲裁规则实现并单测：面板/弹窗打开时 ESC 归**最上层面板**（依 `get_current_lock()` 判定——MODAL 锁拥有者优先）；全部关闭时 ESC 归暂停菜单
- [ ] ESC/暂停按钮转发 hud 暂停菜单（hud epic story 005 全局层）——战斗 UI 不自建暂停菜单
- [ ] MODAL 锁 push/pop 配对封装 API：弹窗打开 `push_lock(MODAL, source)` / 关闭 `pop_lock(source)`——供 006/007/008 的弹窗复用
- [ ] stub 弹窗冻结验证：临时 stub 弹窗 push MODAL 后，底层 Control `_gui_input` 不触发（递归禁用 `process_mode` + `mouse_filter` 与锁栈双保险）
- [ ] GAMEPLAY 动作排队基建：锁期间到达的 GAMEPLAY 点击（如撤退）**排队**（锁释放后执行）而非丢弃——GDD「撤退按钮战斗中始终可点击」= 渲染态常驻可点+排队执行
- [ ] 双焦点双视觉样式基建：键盘/手柄焦点环（松石青 2px）与鼠标悬停（墨色边框加粗+微发光）主题资源/StyleBox——同时激活优先悬停态（ADR-0031 §4）
- [ ] 锁栈判定接入全部交互入口的模式封装（`CombatUIInputGuard` 或等效）——实际逐组件接入由 002-008 落地，009 全量回归收口

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`resolve_esc_target(lock_stack: Array) -> StringName`——ESC 仲裁纯函数：锁栈含 MODAL → 返回其拥有者 source（最上层即最后 push 的）；空栈 → 返回 `&"pause_menu"`。

- 本 story 是**基建基座**（QL-STORY-READY B10 收窄裁决）：不实现业务弹窗/业务组件的输入接入——002-008 各自接入，009 回归。stub 弹窗仅为验证机制。
- ESC 拦截路径 B（`_input()`，GUI 派发前 `accept_event()`）。
- 撤退按钮动作归类 GAMEPLAY（B11 裁决）：ANIMATION 锁（阶段 4/5）期间点击排队。
- R-01 双焦点 spike 结论落地时若焦点环/悬停策略需修正，本 story 的样式基建是修正点。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002-008: 各组件/弹窗的实际输入接入
- hud epic story 005: 暂停菜单本体（含 PROCESS_MODE_ALWAYS）
- Story 009: 全量输入回归
- R-01 spike 本身（Sprint 14 前置任务，非 story）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_esc_arbitration.gd`）

- **AC-1**: ESC 仲裁纯函数
  - Given: 各种锁栈状态
  - When: 调用 `resolve_esc_target()`
  - Then: 空栈 → pause_menu；[MODAL(loot_screen)] → loot_screen；[DIALOGUE, MODAL(retreat)] → retreat（最上层）；[ANIMATION] → pause_menu（ANIMATION 不拦截 ESC）
  - Edge cases: 同层多 MODAL（后 push 者胜）；TRANSITION 锁（归 scene_manager，ESC 无效——返回值标识忽略）

**[Integration — automated test specs]:**

- **AC-2**: stub 弹窗冻结
  - Given: stub 弹窗 push MODAL
  - When: 向底层 Control 发送 `_gui_input` 鼠标点击
  - Then: 底层不响应（信号未触发断言）；pop 后恢复响应
  - Edge cases: push/pop 配对——重复 push 警告；未 push 的 pop 警告

**[UI — manual verification steps]:**

- **AC-3**: 双焦点视觉基建
  - Setup: 测试场景中 stub 按钮，分别用键盘 Tab 与鼠标悬停激活
  - Verify: 键盘焦点→松石青 2px 焦点环；悬停→墨色边框加粗+微发光；同时激活→悬停态优先
  - Pass condition: 两态视觉可区分且同时激活规则生效（R-01 spike 结论一致）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_esc_arbitration.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_modal_freeze_stub.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/combat-input-base-evidence.md` + sign-off（双焦点视觉）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: layout story 001（布局骨架）、R-01 双焦点 spike（Sprint 14 前置）
- Unlocks: Story 002-008（各交互 story 消费锁栈封装与双焦点样式基建）
