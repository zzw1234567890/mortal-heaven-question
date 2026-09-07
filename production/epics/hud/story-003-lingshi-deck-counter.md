# Story 003: 灵石+卡组计数组件（右上）

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-004 / AC-hud-005 / AC-hud-006 / AC-hud-007
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（UI 只读）；事件驱动更新（Cat 1 信号 `resource_changed` / `batch_updated`）；格式化与状态判定提取纯函数单测（Logic 内核模式）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 本组件纯显示+悬停，无焦点交互。数字跳动动画用 Tween，不涉及 4.6 双焦点 API。

**Control Manifest Rules (this layer)**:
- Required: 格式化/阈值判定逻辑提取为纯函数（可单测）
- Forbidden: UI 脚本内联硬编码游戏数值（k 格式阈值、卡组上限来自配置）
- Guardrail: 数字跳动动画 0.3s；卡组超限闪烁不得逐帧重绘整个右上区域

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md`，scoped to this story:*

- [ ] 所有场景显示灵石数量；数字超过 999 显示「1.2k」格式（AC-hud-004）
- [ ] 探索/商店场景显示卡组数量（战斗中 HUD 不渲染，见 Story 001）（AC-hud-005）
- [ ] 卡组达到上限数字变黄；超过上限变红+闪烁+「超限！」标记（AC-hud-006）
- [ ] 灵石变更时数字短暂跳动动画（+xx/-xx）（AC-hud-007）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `format_lingshi(amount: int) -> String` 纯函数——<1000 返回原数字；≥1000 返回「1.2k」格式（9999 以内精确、10000+ 格式待 game-designer 澄清，见下方待澄清项）。k 格式阈值来自配置常量。
- `get_deck_count_state(count: int, cap: int) -> Dictionary` 纯函数——返回 `{color: "normal"|"yellow"|"red", flashing: bool, overlimit: bool, label: String}`（count==cap 黄色；count>cap 红色+闪烁+「超限！」）。

**待澄清项（实现前确认）**：灵石 10000+ 显示格式（「10.0k」？「1.0w」？）——GDD 边界澄清 2026-09-07 标注规格待补，story 实现前由 game-designer 确认。确认前纯函数按「≥10000 显示 4 位 k 格式（如 12.3k）」临时实现并在单测中锁定行为。

- 信号绑定：订阅 `GSM.resource_changed(type, delta, balance)`（过滤灵石类型）与卡组变更信号；卡组数量从卡牌系统/卡组编辑系统读取。
- 灵石跳动动画：Tween 0.3s 数字滚动 + (+xx/-xx) 浮动文本，属 Visual/Feel 手动验证。
- 卡组 0/20（未获得卡牌）正常显示「0/20」，不触发异常（GDD 边界情况）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载与可见性
- Story 002: 境界+修为条
- 超限弃牌界面本体：归 deck-editing-ui epic（本 story 只显示警报状态）
- 音效（灵石碰撞声）：归 audio-manager epic，本组件仅触发音频事件

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: 灵石 k 格式化
  - Given: 灵石数量 amount
  - When: 调用 `format_lingshi(amount)`
  - Then: 999 → "999"；1000 → "1.0k"；1250 → "1.2k"；9999 → "9.9k"
  - Edge cases: 0、999、1000、9999、10000+（按待澄清项的临时实现锁定）、负数输入（防御性）

- **AC-2**: 卡组计数状态判定
  - Given: 卡组数量 count 与上限 cap
  - When: 调用 `get_deck_count_state(count, cap)`
  - Then: count<cap → color "normal"；count==cap → "yellow"；count>cap → "red"+flashing+overlimit 标记
  - Edge cases: 0/20、28/30、30/30、32/30、cap=0

- **AC-3**: 灵石数据绑定
  - Given: HUD 已挂载且灵石显示当前值
  - When: GSM 发射 `resource_changed`（灵石 +25）
  - Then: HUD 灵石显示在信号处理后更新为新余额（自动化断言显示文本，不含动画）
  - Edge cases: 连续多次变更（最后一次生效）、变更时 HUD 处于战斗隐藏状态（恢复可见后显示最新值）

**[Visual/Feel — manual verification steps]:**

- **AC-4**: 灵石数字跳动
  - Setup: 触发灵石获得事件
  - Verify: 数字 0.3s 滚动 + 「+25」浮动文本
  - Pass condition: 动画流畅、方向正确（增加向上浮/减少向下浮或等效区分）

- **AC-5**: 卡组超限闪烁
  - Setup: 卡组数量超过上限（如 32/30）
  - Verify: 数字红色闪烁 + 「超限！」标记持续显示
  - Pass condition: 闪烁持续到玩家处理超限弃牌，标记清晰可见

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/hud/test_lingshi_formatter.gd` + `tests/unit/hud/test_deck_count_state.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/hud/test_gsm_signal_binding.gd`（AC-3 数据绑定）— must exist and pass（BLOCKING）
- Visual/Feel: `production/qa/evidence/lingshi-deck-counter-evidence.md` + sign-off（动画手动验证）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（挂载点）
- Unlocks: None（超限弃牌界面归 deck-editing-ui epic，非本 epic）
