# Story 004: 散功与售卡标签页

> **Epic**: 卡组编辑 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（含 Logic 内核：选择约束纯函数）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/deck-editing-ui-system.md` §3 删卡服务 + §4 出售卡牌
**Requirement**: 散功 AC 3 条 + 出售 AC 1 条（机制层 GDD 公式 2/3/4 支撑）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0023: 卡组编辑系统（次要——散功/出售 API）
**ADR Decision Summary**: UI 直调 `DeckEditingSystem.get_delete_cost()/execute_delete(card_id)/execute_sell_batch(card_ids)`（B2/B3a 裁决）；散功费用递增与出售价（拆解基准价×0.5——2026-09-08 B1 终裁）全部系统返回，UI 零计算。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 散功/售卡共享网格组件（模式库-散功选择网格单选/多选变体）；碎裂/熔炼动画 0.3s。

**Control Manifest Rules (this layer)**:
- Required: 选择约束逻辑提取纯函数（`tests/unit/deck_editing_ui/`）——B4 裁决
- Forbidden: UI 计算 50+25×N 递增、×0.5 折扣、总价求和（`get_sell_total` 系统返回——OQ#2 裁决）
- Guardrail: 二次确认弹窗焦点默认「取消」侧；卡组 ≤5 张保护为系统侧判定+UI 禁用展示

---

## Acceptance Criteria

*From GDD §3/§4 + UX 规范，scoped to this story:*

**Logic 内核（自动化单测，BLOCKING）：**
- [ ] `removal_selection_state(deck_count, selected_count, mode, session_removed) → 结构` 纯函数：
  - 散功模式（单选）：selected ≤1；确认可用 = 已选 1 张 且 deck_count-1 ≥5 且（费用≤余额——余额由调用方传入）
  - 售卡模式（多选）：确认可用 = 已选 ≥1 且 deck_count-selected ≥5
  - 边界用例：deck_count=5 散功 → 禁用+「卡组至少保留5张」；deck_count=5 售卡选 1 张 → 禁用；deck_count=6 售卡选 1 张 → 可用；散功已选 A 再点 B → 换选（非多选）
  - 测试文件：`tests/unit/deck_editing_ui/removal_selection_state_test.gd`（GUT）

**UI（手动验证）：**
- [ ] 散功页：当前卡组网格（单选 ✓）+底部「散功费用：50灵石（第1次）」→ 删 1 次后显示「75灵石（第2次）」——数值与系统 `get_delete_cost()` 返回一致（UI 未计算）
- [ ] 散功选中卡牌 → 「确认散功」激活；点击 → 二次确认（含费用金额——A3 修复）→ 确认后卡牌碎裂动画+灵石扣减+卡组计数-1
- [ ] 售卡页：多选网格+每卡出售价标注（系统 `get_sell_price` 返回——×0.5 后值）+底部「已选 N 张 = X 灵石」实时累计（`get_sell_total` 返回，UI 不求和）
- [ ] 售卡确认 → 二次确认含总金额+「出售后不可恢复」→ 确认后熔炼动画+灵石增加+卡牌移除
- [ ] 卡组 ≤5 张：散功/售卡确认按钮禁用+「卡组至少保留5张」提示
- [ ] 卡组 <5 张打开散功/售卡页：标签页内提示条替代网格操作（UX 边界变体）
- [ ] 散功费用 > 灵石：「确认散功」禁用+「灵石不足」提示
- [ ] 所有确认弹窗焦点默认落于「取消」侧
- [ ] stub 数值声明：`get_sell_price` 现桩恒返回 10（rarity=1,level=1）——stub 阶段验收以 stub 返回值为准，真实接线后复验（B7/A4 裁决）

---

## Implementation Notes

*Derived from ADR-0023 + B1/B7/OQ#2 裁决:*

- **依赖上报（stub+复验）**：`execute_sell_batch(card_ids)`（原子批量——B3b 裁决：防逐卡循环半完成）与 `get_sell_total(card_ids)` **尚未实现**——stub 先行+缺口上报+真实接线后复验。`get_delete_cost()/execute_delete()` 已实现（deck_shop.gd）可直接对接。
- 出售价 ×0.5（B1 终裁）：UI 只显示系统返回值——stub 期间显示 stub 值，不自行计算 ×0.5。
- 单选/多选共用网格组件（模式库-散功选择网格两变体），选择状态为瞬态（UI 本地）。
- 变更日志（DeckChangeLog）由系统侧写入——「历史」标签展示归 story 005。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: overlay 框架与标签页宿主
- Story 005: 卡组浏览与历史标签（日志展示）
- Feature 层: execute_sell_batch/get_sell_total 实现（依赖上报项）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic — automated test specs]:**

- **AC-1**: 选择约束纯函数
  - Given: deck_count=5, mode=散功
  - When: `removal_selection_state(...)`
  - Then: 确认可用=false，reason=「卡组至少保留5张」
  - Edge cases: (6, 售卡, selected=1)→可用；(5, 售卡, selected=1)→禁用；(散功已选A再点B)→换选；(30,散功,未选)→确认禁用

**[UI — manual verification steps]:**

- **AC-2**: 散功流
  - Setup: 灵石充足存档，散功 0 次与 1 次两种状态
  - Verify: 费用显示 50（第1次）/75（第2次）与系统返回一致、单选换选、二次确认含金额、动画联动
  - Pass condition: 双状态费用正确 + 取消路径无副作用

- **AC-3**: 售卡流与保护
  - Setup: 多卡存档（>6 张）与 5 张存档
  - Verify: 多选+总价累计（系统返回）、5 张保护双页禁用、<5 提示条变体、二次确认金额
  - Pass condition: 三存档路径正确 + stub 数值与 stub 返回一致

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- `tests/unit/deck_editing_ui/removal_selection_state_test.gd` — 必须存在且通过（BLOCKING）
- `production/qa/evidence/shop-remove-sell-tabs-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（overlay 宿主）
- Unlocks: Story 007（终验含散功/售卡闭环）
