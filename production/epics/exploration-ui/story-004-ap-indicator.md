# Story 004: 行动力指示器

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 行动力指示器 6 条 AC + 公式 2（ap_bar_color——已含 GRAY 分支与恰界语义，2026-09-08 B2 裁决）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（AP 值从 GSM `exploration.action_points` Cat 1 信号读取——与 HUD 右下 AP 同数据源，A1）；ap_bar_color 为纯函数（Logic 内核单测 BLOCKING）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 分段格（每格 1 AP，最大 13 格化神上限）；逐格熄灭 0.2s/回复逐格亮起 0.5s 动画。

**Control Manifest Rules (this layer)**:
- Required: 消费 GSM `batch_updated` 的 `exploration.action_points` 路径（与 HUD AP 同一信号——禁止第二套数据通路，A1）
- Forbidden: UI 自行计算 AP 颜色以外的任何数值；闪烁动画无「减少动态」替代（静态红边框——UX AC）
- Guardrail: 13 格最大显示在 1280×720 不溢出

---

## Acceptance Criteria

*From GDD 行动力 AC（B2 修正后语义），scoped to this story:*

- [ ] AP 以分段格+数字显示（current/max，每格=1 AP）
- [ ] 行动力变更时逐格熄灭（0.2s）；灵泉回复时从空到满逐格亮起（0.5s）
- [ ] 颜色阈值（ap_bar_color 纯函数）：ratio > 0.3 蓝 / 0.1 < ratio ≤ 0.3 黄 / ratio ≤ 0.1 红+闪烁 / **current == 0 灰+闪烁（GRAY 守卫优先于红）** / max == 0 守卫 RED
- [ ] 恰界行为锁定：ratio = 0.3 → 黄；ratio = 0.1 → 红；current = 0 → 灰（B2 裁决语义）
- [ ] 黄色/红色阶段伴随文字+图标提示（不依赖颜色单独传达——UX 无障碍）
- [ ] 悬停显示详情：「剩余行动力：X/Y | 到Boss还需N步」（步数数据从探索系统读取）
- [ ] AP 归零：~1s 延迟后自动触发探索结束流程（信号通知——面板本体归 story 008）
- [ ] 「减少动态」开启时危急态改为静态红边框（无闪烁）

---

## Implementation Notes

*Derived from ADR-0031 + hud epic AP 先例:*

- `ap_bar_color(current, max) -> Color` 纯函数独立可测（GDD 公式 2 修正版）——`tests/unit/exploration_ui/` 单测 BLOCKING，边界用例（0.3/0.1/0/max=0）是测试点。
- 数据通路：GSM `batch_updated` 的 `exploration.action_points`/`exploration.max_action_points` 路径——hud story AP 显示同一信号源（A1），两处 UI 均为监听方。
- 逐格动画：熄灭/亮起用 Tween 逐格延迟；「减少动态」全局设置（hud epic 无障碍设置）读取后切换静态表现。
- 到 Boss 步数：探索系统 API 查询（悬停时按需读取，非轮询）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: AP 归零后的探索结束面板（本 story 只发归零信号通知）
- Story 006: 灵泉弹窗确认（本 story 只做回复后的指示器动画响应）
- hud epic: HUD 右下 AP 显示（同数据源，不同界面归属）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: ap_bar_color 边界用例
  - Given: (current, max) 对 (7,10) (3,10) (1,10) (0,10) (5,5) (3,0)
  - When: 调用 ap_bar_color
  - Then: (7,10)→BLUE；(3,10)→YELLOW（ratio=0.3 恰界属黄）；(1,10)→RED（ratio=0.1 恰界属红）；(0,10)→GRAY（守卫优先）；(5,5)→BLUE；(3,0)→RED（max=0 守卫）
  - Edge cases: current > max 的非法输入（防御性返回 BLUE 或 clamp——实现定义后测试锁定）

- **AC-2**: 指示器格数同步
  - Given: max=13 的化神角色，AP 从 13 消耗至 0
  - When: 每次消耗信号到达
  - Then: 分段格逐格熄灭（动画后格数=current），数字同步
  - Edge cases: 连续快速消耗（动画中断直接到位）；回复全部（0→13 逐格亮起）

**[UI — manual verification steps]:**

- **AC-3**: 颜色态走查
  - Setup: 分别构造 AP >30%/10~30%/≤10%/=0 四种状态
  - Verify: 颜色+闪烁+文字图标提示+减少动态替代
  - Pass condition: 四态视觉与 B2 裁决语义一致 + 签批

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic: `tests/unit/exploration_ui/test_ap_bar_color.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/ap-indicator-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003（界面宿主——或与 003 并行，指示器为独立控件）
- Unlocks: Story 008（AP 归零自动结束流程消费归零信号）
