# Story 007: 结算与撤退确认流（持久写入）

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 结算面板 AC（含 2026-09-07 补记的 loot_skipped 条目）+ 撤退 AC 4 条
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: §2 持久变更（loot_selected/retreat_confirmed）必须先经确认弹窗再触发系统 API——UI 只发语义信号，系统执行后广播回来；§2.1 持久写入委托路径显式声明。

**ADR 次要参考**: ADR-0023（卡牌入卡组走 DeckEditingSystem 统一 API——禁止绕过）、ADR-0008（retreat() 撤退流程——RETREAT=DEFEAT 语义，损失计算系统侧）
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (this layer)**:
- Required: loot_selected 持久写入委托 DeckEditingSystem/ResourceSystem；retreat 委托 CombatSystem.retreat()（UI 层零数值计算）
- Forbidden: 卡牌增删绕过 DeckEditingSystem；UI 计算修为损失数值
- Guardrail: 结算面板渲染成本计入 R-02 峰值预算（layout 009b/009 域）

---

## Acceptance Criteria

*From GDD 结算/撤退 AC + UX #10/#11，scoped to this story:*

- [ ] 战利品点击选中（消费 layout 008 选中态/0.5s 延迟/卡组满灰显渲染态）→ [确认选择] → `loot_selected` 持久写入：卡牌类经 DeckEditingSystem 统一 API 入卡组、灵石经 ResourceSystem、消耗品入背包——委托路径断言
- [ ] [跳过] 按钮 → 「放弃所有奖励？」二次确认弹窗 → 确认后 `loot_skipped`（放弃全部奖励，面板关闭）；取消则回到战利品面板（GDD 2026-09-07 补记 AC）
- [ ] 战利品面板键盘/手柄：数字键 1-3 选中、Enter/A 确认、ESC/B 跳过路径（UX #10）
- [ ] 撤退按钮点击（story 003 排队基建——ANIMATION 锁期间排队执行）→ 确认弹窗（layout 008 框架）→ [确认撤退] → `CombatSystem.retreat()` 调用——修为损失/绑定卡失去等全部数值系统侧计算（RETREAT=DEFEAT 语义，ADR-0008）
- [ ] 渡劫变体撤退：确认弹窗红色警示文案（layout 008 渲染变体）→ 确认后同样委托 retreat()——80% 损失由系统按 is_tribulation 计算
- [ ] [继续战斗]/[取消] → 弹窗关闭，MODAL 锁 pop，战斗恢复
- [ ] 战败面板 [返回探索] → SceneManager 转场
- [ ] 战利品确认后返回探索（转场链路复用 battle_ended 消费）

---

## Implementation Notes

*Derived from ADR-0031/0023/0008 Implementation Guidelines:*

- 无纯函数单测目标（判定纯函数归 layout 008；本 story 是委托链集成）——**Integration BLOCKING** 为主。
- 委托链（A5 裁决）：loot_selected → 卡牌：`DeckEditingSystem` 统一 API；灵石：`ResourceSystem.add_resource()`；消耗品：背包系统 API。retreat_confirmed → `CombatSystem.retreat()`（唯一入口）。
- UI 层不出现任何损失/奖励数值计算——数值全部来自系统返回/信号载荷。
- MODAL 锁：弹窗打开 push（source=&"loot_screen"/&"retreat_dialog"）、关闭 pop——story 001 封装。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- layout story 008: 三面板视觉框架、0.5s 延迟判定、选中态/灰显渲染
- CombatSystem/DeckEditingSystem/ResourceSystem 域: 持久写入的执行逻辑与数值
- audio-manager epic: 胜利号角/失败音/确认音
- Story 009: 结算面板峰值场景 DC 复测

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 战利品确认委托链
  - Given: 胜利面板弹出且 0.5s 已过
  - When: 选中卡牌选项 → 确认选择
  - Then: DeckEditingSystem 统一 API 调用断言（mock 边界）；灵石选项 → ResourceSystem.add_resource 断言；卡组满时卡牌选项不可选（灰显传递）
  - Edge cases: 0.5s 内确认按钮禁用；未选中点确认 → 无调用

- **AC-2**: 跳过战利品
  - Given: 胜利面板
  - When: 点击跳过 → 二次确认
  - Then: 确认后零持久写入（无 DeckEditing/Resource 调用断言）+ 面板关闭；取消 → 回到面板
  - Edge cases: 二次确认弹窗的 MODAL 锁配对

- **AC-3**: 撤退流
  - Given: 战斗中
  - When: 点击撤退 → 确认
  - Then: CombatSystem.retreat() 恰调用 1 次（UI 层无数值计算断言）；取消 → retreat 未调用且锁 pop
  - Edge cases: ANIMATION 锁期间点击 → 排队（锁释放后执行——story 001 基建断言）；渡劫变体文案切换（is_tribulation）

**[UI — manual verification steps]:**

- **AC-4**: 三面板确认流走查
  - Setup: 构造胜利（含卡组满）/战败/普通撤退/渡劫撤退场景
  - Verify: 选中→确认两步、跳过二次确认、撤退变体文案、MODAL 冻结底层
  - Pass condition: 全部确认流零误触、持久变更正确落库（试玩检查存档）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/combat_ui/test_loot_retreat_flow.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/loot-retreat-flow-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（MODAL 锁/排队基建）、layout story 008（面板框架）
- Unlocks: Story 009（结算面板入峰值复测）
