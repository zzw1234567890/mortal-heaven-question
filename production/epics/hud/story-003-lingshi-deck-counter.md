# Story 003: 灵石+卡组计数组件（右上）

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 0.5d（sprint-13 S13-4）
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-10（/story-readiness QL-STORY-READY G1-G4 裁决落地）

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
- `format_lingshi(amount: int) -> String` 纯函数——<1000 返回原数字；≥1000 返回「1.2k」格式；**10000+ 裁决（2026-09-10 用户裁决，关闭 GDD L237 待澄清项）：延续 k 格式**——10000 →「10.0k」、12500 →「12.5k」（与 9999 内「9.9k」自然衔接，不引入万单位）。k 格式阈值来自配置常量。
- `get_deck_count_state(count: int, cap: int) -> Dictionary` 纯函数——返回 `{color: "normal"|"yellow"|"red", flashing: bool, overlimit: bool, label: String}`（count==cap 黄色；count>cap 红色+闪烁+「超限！」）。

- 信号绑定（G1 裁决 2026-09-10）：订阅 `GSM.resource_changed`（过滤灵石类型）**及** `GSM.batch_updated`——过滤 `player.resources.ling_shi` 前缀（同帧多变更时域信号不发射，batch_updated 为唯一入口——gsm_signal_router 单变更路由规则）与 `deck.current_deck` 前缀（**卡组变更唯一刷新入口**；`deck_modified` 信号当前全库无发射方，不作为依赖）。参照 `src/ui/hud/realm_bar.gd` G-H3 先例。卡组数量与上限经 DeckEditingSystem `get_deck_summary() -> {total, limit, ...}` 读取（UI 数据源接口，ADR-0023）。
- 灵石跳动动画：Tween 0.3s 数字滚动 + (+xx/-xx) 浮动文本，属 Visual/Feel 手动验证。
- 卡组 0/20（未获得卡牌）正常显示「0/20」，不触发异常（GDD 边界情况）。
- **cap<=0 防御分支（G3 裁决）**：`get_deck_count_state` 对 cap<=0 返回 normal（系统 `get_deck_limit()` 最低返回 20，此分支不可达，单测仅防御性锁定行为——count==cap==0 不得落入 yellow）。

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
  - Then: 999 → "999"；1000 → "1.0k"；1250 → "1.2k"；9999 → "9.9k"；**10000 → "10.0k"；12500 → "12.5k"（2026-09-10 裁决：延续 k 格式）**
  - Edge cases: 0、999、1000、9999、10000、12500、负数输入（防御性）

- **AC-2**: 卡组计数状态判定
  - Given: 卡组数量 count 与上限 cap
  - When: 调用 `get_deck_count_state(count, cap)`
  - Then: count<cap → color "normal"；count==cap → "yellow"；count>cap → "red"+flashing+overlimit 标记
  - Edge cases: 0/20、28/30、30/30、32/30、cap=0（G3 裁决：count==cap==0 防御返回 normal，不入 yellow）

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

**Integration 测试前提（G4 裁决 2026-09-10）**：共享 `tests/integration/scene_manager/mocks/mock_gsm.gd` 仅 session 域、无 resource_changed 信号——AC-3 集成测试可复用 `tests/unit/cultivation_system/` 直连真实 GSM 实例的测试模式（写 `player.resources.ling_shi` + 断言信号/显示文本），免建 hud 专用 mock。

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（挂载点）
- Unlocks: None（超限弃牌界面归 deck-editing-ui epic，非本 epic）
