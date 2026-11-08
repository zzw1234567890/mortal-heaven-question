# Story 008: 结算与撤退面板框架（视觉与状态判定）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: 2.0d（sprint-17 排期）
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-11-08

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

- [x] 胜利面板：战利品三选一网格（卡牌正面/灵石图标+数值/消耗品），均匀等宽网格+垂直居中
- [x] 战利品展示 0.5s 后才变为可点击状态（防误触——先看清再选择）
- [x] 点击战利品高亮选中（非立即确认）——渲染态；[确认选择] 按钮未选中时灰色不可点
- [x] 卡组已满时战利品中卡牌选项灰色标注「卡组已满」不可选中
- [x] 战败面板：损失摘要（修为损失 50%/阵亡角色列表/绑定卡失去提示）+ 确认返回按钮
- [x] 撤退确认面板（普通变体）：撤退后果说明（保留非绑定物品/阵亡角色绑定卡失去）+ 确认/继续战斗按钮
- [x] 撤退确认面板（渡劫变体）：红色边框+「畏劫而退，修为散尽」+ 损失 80% 修为+失去渡劫机会警示
- [x] 渡劫战前 warning：备战界面弹出「天劫在前，退路将断。确认进战？」+ 确认进战/返回按钮
- [x] 撤退按钮（右上角常驻，story 001 位）的启用渲染态——战斗中始终可点（交互流转归 interaction）
- [x] 结算面板不自动关闭（需手动确认——GDD 调优参数「无穷」）

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

**Status**: [x] Created and passing

| 证据 | 路径 | 结果 |
|---|---|---|
| 单元（Logic 内核，47 例） | `tests/unit/combat_ui/test_settlement_rules.gd` | 47/47 通过 |
| 集成（0.5s 延迟可点 + 键盘可达 + 宿主接线，48 例，BLOCKING） | `tests/integration/combat_ui/test_loot_delay_clickable.gd` | 48/48 通过 |
| UI 五场景走查 + 签收（ADVISORY） | `production/qa/evidence/settlement-retreat-evidence.md` | 文档已创建；§2 十项待 QA 走查签收 |
| 走查宿主 | `tests/manual/settlement_panel_debug.tscn` | 可 F6 运行（按键 1~6/0/T/M） |

- combat_ui 单元 **152/152**（11 脚本 427 asserts）、集成 **210/210**（14 脚本 566 asserts）。
- 全量基线：单元 **2433 tests / 2432 passing / 1 pending**（存量 `test_migration_chain`）/ 1 orphan（存量）；集成 **1004/1004 passing**（60 脚本 3847 asserts）。较 S17-3 基线（单元 2430 / 集成 956）集成净增 48 例，零回归。

---

## Dependencies

- Depends on: Story 001（骨架与撤退按钮位）、Story 003（全灭信号）
- Unlocks: interaction epic（确认流转消费本 story 框架）

---

## Completion Notes
**Completed**: 2026-11-08
**Criteria**: 10/10 通过（AC-1~AC-10 全部由自动化覆盖；AC-1/AC-5/AC-6/AC-7/AC-8 的视觉可辨识性与动画手感另需 §2 十项 D3D12 走查，按项目口径记为 ADVISORY）
**Deviations**:
- ADVISORY：战利品选项只透传不补足到「三选一」——`SettlementHost._victory_options()` 按 `rewards` 实际数量排布，补足逻辑归战斗/资源系统（Out of Scope）。登记 DEBT-CUI-008-3。
- ADVISORY：`combat_layout.gd` 370 行超 300 行软上限（本 story 新增约 57 行装配）——结算面板本身已拆为 9 个文件（最大 321 行，为注释密度高的内核——有效代码约 140 行）。登记 DEBT-CUI-008-2（与 DEBT-CUI-007-2 合并处理）。
- ADVISORY：中文文案硬编码在两个内核（同 S16/S17 各 story 豁免口径）。登记 DEBT-CUI-008-1。
- ADVISORY：`reduce_motion` 需宿主显式 `set_reduce_motion()` 下发，尚无全局偏好读取入口。登记 DEBT-CUI-008-4。
- ADVISORY：战利品「卡牌正面 / 灵石图标」按 GDD §9 线框用文字标记承载（标题+副标题+角标），未绘制卡面美术与图标——项目当前无对应图标资产，绘制资产归美术管线；文字口径已逐字对齐线框，语义完整。登记 DEBT-CUI-008-5。
**Test Evidence**: Logic：`tests/unit/combat_ui/test_settlement_rules.gd`（47 例，BLOCKING 通过）+ `tests/integration/combat_ui/test_loot_delay_clickable.gd`（48 例，BLOCKING 通过）；UI：`production/qa/evidence/settlement-retreat-evidence.md`（§2 十项待 QA 走查）+ `tests/manual/settlement_panel_debug.tscn` 走查宿主。
**Code Review**: full 模式双关卡已执行并完成整改。
- **LP-CODE-REVIEW → CONCERNS**（12 项建议）。已整改 9 项：响应式字号收口到 `SettlementFrame.apply_font`（原先三面板各自 `add_theme_font_size_override`，违反 story 001「共享纯函数唯一落地处」强制条款）；`_connect_signals` 换源前断开旧源 + `NOTIFICATION_PREDELETE` 断开（防一次战斗开两次面板）；`reduce_motion` 在面板构建后统一继承（原先被默认值吞掉）；空战利品提示兜底 `victory_hint_text`（原先对空网格显示「点击战利品选中」）；宿主映射 `consumables` 字段；`combat_layout` 两处静默 return 补 `push_warning`（对齐 007 先例）；删除 `KIND_PRE_BATTLE_WARNING` 死常量与 `rebuild_loot_cards` 死参数；修正 `combat_layout.gd` 注释错位。**未整改 3 项已转技术债/后续**：`combat_layout.gd` 面板挂载拆分（DEBT-CUI-008-2）、`Rules.loot_clickable` 消费口径（本次已改为内核裁决，见下）、战利品美术资产（DEBT-CUI-008-5）。
- **QL-TEST-COVERAGE → INADEQUATE（阻塞 2 项）**。已全部闭环：①「等宽网格」原先只重算内核值自证——改为 `await process_frame` 后断言三卡真实 `size.x` 相等且等于内核对宽、且三卡宽+两列间隔恰好铺满内容宽；②「不自动关闭」原先只断言延迟到点后仍打开——补 `test_panel_holds_only_the_loot_delay_timer`（结构性证明面板只持有这一个 Timer）与 `test_delay_timer_started_on_show_and_stopped_on_close`（计时器真接线，避免手工 `emit` 掩盖漏 `start()`）。另按同一口径补齐：垂直居中几何进内核 `loot_card_content_top`（原先 UI 内散写无法断言）、渡劫红框改为读回真实 `StyleBoxFlat.border_color`（原先只断言内核常量）、键盘可达（`FOCUS_ALL` + 焦点环 + Enter 经焦点通道，原先前一版自绘卡对键盘完全不可达）、灰显卡 `get_selected_index() == -1` + 真实 `InputEventMouseButton` 双路径断言。
