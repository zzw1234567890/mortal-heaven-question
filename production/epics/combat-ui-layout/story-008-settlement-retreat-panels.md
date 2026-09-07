# Story 008: 结算与撤退面板框架（视觉与状态判定）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 结算面板 AC 6 条 + 撤退 AC 4 条 + §9/§10 面板规格
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 划界裁决 2026-09-07：面板视觉框架+状态判定（0.5s 延迟/选中态/卡组满灰显）+信号驱动渲染归本 story；选中/确认的输入流转与 loot_selected/retreat_confirmed 持久写入归 interaction。渡劫 warning 时机统一为备战界面（边界澄清 2026-09-07）。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 战利品三选一网格布局：均匀网格 `(panel_width - margins) / 3` 等宽（GDD 边界情况）；渡劫变体红色边框。

**Control Manifest Rules (this layer)**:
- Required: 0.5s 延迟可点判定集成测试（自动化）；卡组满灰显判定
- Forbidden: 自动关闭结算面板（须手动确认）
- Guardrail: 结算面板渲染成本计入 R-02 峰值预算

---

## Acceptance Criteria

*From GDD，scoped to this story:*

- [ ] 胜利面板：战利品三选一网格（卡牌正面/灵石图标+数值/消耗品），均匀等宽网格+垂直居中
- [ ] 战利品展示 0.5s 后才变为可点击状态（防误触——先看清再选择）
- [ ] 点击战利品高亮选中（非立即确认）——渲染态；[确认选择] 按钮未选中时灰色不可点
- [ ] 卡组已满时战利品中卡牌选项灰色标注「卡组已满」不可选中
- [ ] 战败面板：损失摘要（修为损失 50%/阵亡角色列表/绑定卡失去提示）+ 确认返回按钮
- [ ] 撤退确认面板（普通变体）：撤退后果说明（保留非绑定物品/阵亡角色绑定卡失去）+ 确认/继续战斗按钮
- [ ] 撤退确认面板（渡劫变体）：红色边框+「畏劫而退，修为散尽」+ 损失 80% 修为+失去渡劫机会警示
- [ ] 渡劫战前 warning：备战界面弹出「天劫在前，退路将断。确认进战？」+ 确认进战/返回按钮
- [ ] 撤退按钮（右上角常驻，story 001 位）的启用渲染态——战斗中始终可点（交互流转归 interaction）
- [ ] 结算面板不自动关闭（需手动确认——GDD 调优参数「无穷」）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 集成测试目标）**：0.5s 延迟可点判定——胜利面板弹出后 Timer 0.5s 内确认按钮 disabled、之后 enabled（SceneTreeTimer 推进断言，非真实等待）。

- 面板触发：胜利/战败信号（story 003 全灭信号目标端）、撤退按钮点击信号。
- 卡组满判定：从卡组系统读取当前数量 vs 上限——灰显数据驱动。
- 选中态：UI 本地瞬态交互状态（未确认前不写系统）。
- 渡劫战标识：从战斗进入参数读取（is_tribulation），切换两变体渲染。
- 确认/选择按钮点击后的系统调用（loot 应用/retreat 执行/返回转场）归 interaction epic。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- interaction epic: 战利品选中/确认流（loot_selected/loot_skipped 事件与持久写入）、撤退确认决策（retreat_confirmed）、渡劫 warning 按钮流转
- Story 003: 全灭信号源
- Story 007: 备战面板（渡劫 warning 在其前弹出，本 story 实现弹窗本体）
- audio-manager epic: 胜利号角/失败音
- 战利品选项生成逻辑：战斗系统/资源系统

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 0.5s 延迟可点（`tests/integration/combat_ui/test_loot_delay_clickable.gd`）
  - Given: 胜利面板弹出
  - When: 0.5s 内与之后分别检查
  - Then: 内 disabled、后 enabled；未选中任何项时确认按钮灰
  - Edge cases: 恰 0.5s 边界（实现定义固化）；卡组满时卡牌选项 disabled

- **AC-2**: 面板触发信号
  - Given: 战斗进行中
  - When: 胜利信号 / 战败信号 / 撤退按钮点击信号
  - Then: 对应面板 visible；撤退渡劫变体由 is_tribulation 切换红框文案
  - Edge cases: 面板不自动关闭（推进时间仍 visible）

**[UI — manual verification steps]:**

- **AC-3**: 面板视觉与变体
  - Setup: 构造胜利（含卡组满场景）/战败/普通撤退/渡劫撤退/渡劫进入
  - Verify: 三选一等宽网格垂直居中；渡劫撤退红框+特殊文案；warning 在备战界面弹出
  - Pass condition: 五场景截图对比通过、0.5s 延迟体感正确、无自动关闭

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Integration: `tests/integration/combat_ui/test_loot_delay_clickable.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/settlement-retreat-evidence.md` + sign-off（五场景截图）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（骨架与撤退按钮位）、Story 003（全灭信号）
- Unlocks: interaction epic（确认流转消费本 story 框架）
