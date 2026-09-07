# Story 002: 境界+修为条组件（左上）

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-001 / AC-hud-002 / AC-hud-003
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（UI 只读）；事件驱动更新（Cat 1 信号 `realm_changed` / `batch_updated`）；阈值类确定性逻辑提取为纯函数单测（Logic 内核模式）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 本组件交互仅鼠标悬停 tooltip，无键盘/手柄焦点需求。悬停检测用 Control 内建 mouse_filter，不涉及 4.6 双焦点 API。

**Control Manifest Rules (this layer)**:
- Required: 阈值/状态判定逻辑提取为纯函数（可单测），UI 节点只消费判定结果
- Forbidden: UI 脚本内联硬编码游戏数值（阈值必须来自数据驱动配置）
- Guardrail: 修为条平滑填充动画 0.3s 内完成，不得逐帧重绘整条

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md`，scoped to this story:*

- [ ] 所有 HUD 可见场景显示当前境界名称 + 修为进度条（AC-hud-001）
- [ ] 修为≥90% 时进度条金色脉动动画（AC-hud-002）
- [ ] 炼气·落难状态境界名称显示「炼气·落难」+ 破碎光效（AC-hud-003）
- [ ] 进度条颜色：<50% 蓝色、50~90% 紫色、≥90% 金色
- [ ] 鼠标悬停显示具体数值（如 1800/2250）
- [ ] 化神期满修为显示「可飞升」替代进度条
- [ ] 修为条平滑填充动画 0.3s

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`get_cultivation_bar_state(realm_id, is_fallen, current, max_val) -> Dictionary` 纯函数，返回 `{color: "blue"|"purple"|"gold", pulsing: bool, label: String, show_bar: bool}`。阈值（50%/90%）来自数据驱动配置常量。该函数是本 story 的必测逻辑内核——UI 节点只消费其返回值。

- 信号绑定：订阅 `GSM.realm_changed(old, new)` 与 `batch_updated(changes)`（过滤修为字段），信号到达时从 GSM 读取当前值并调用纯函数刷新显示。
- 禁止在 UI 脚本内联阈值 if-else——判定必须走纯函数。
- 落难状态：境界名称与光效由 `is_fallen` 输入驱动；破碎光效为 Visual/Feel 部分，手动验证。
- 悬停 tooltip：仅数值文本，无跨屏导航，不涉及焦点管理。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载与可见性（本组件假定挂载点存在）
- Story 003: 灵石+卡组计数
- 敌方境界标记（⬆）：归 combat-ui（边界澄清 2026-09-07）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: 进度条颜色阈值判定
  - Given: 修为进度百分比 p
  - When: 调用 `get_cultivation_bar_state()` 并检查返回的 color 字段
  - Then: p<50% 返回 "blue"、50%≤p<90% 返回 "purple"、p≥90% 返回 "gold"
  - Edge cases: p=49.9%、p=50%、p=89.9%、p=90%、p=100%、max_val=0（防除零）、负数输入

- **AC-2**: 脉动动画触发判定
  - Given: 修为进度 p
  - When: 检查返回的 pulsing 字段
  - Then: p≥90% 为 true，否则 false
  - Edge cases: p=89.99%、p=90%

- **AC-3**: 落难状态显示判定
  - Given: is_fallen == true
  - When: 检查返回的 label 字段
  - Then: label 为「炼气·落难」
  - Edge cases: is_fallen == true 且修为满（label 仍为落难显示）

- **AC-4**: 化神期满修为
  - Given: realm 为化神期且 current == max_val
  - When: 检查 show_bar 与 label
  - Then: show_bar == false，label 为「可飞升」
  - Edge cases: 化神期未满、非化神期满

**[Visual/Feel — manual verification steps]:**

- **AC-5**: 金色脉动动画
  - Setup: 修为调至 ≥90%
  - Verify: 进度条金色脉动光效持续播放
  - Pass condition: 动画循环播放无卡顿，颜色为金色系

- **AC-6**: 修为条平滑填充
  - Setup: 触发一次修为变更事件
  - Verify: 进度条 0.3s 内平滑过渡到新值
  - Pass condition: 无瞬跳、无超过 0.5s 的延迟感

- **AC-7**: 悬停数值显示
  - Setup: 鼠标悬停境界区域
  - Verify: tooltip 显示「1800/2250」格式数值
  - Pass condition: 悬停即现、移开即消、数值与 GSM 一致

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/hud/test_cultivation_bar_state.gd` — must exist and pass（BLOCKING）
- Visual/Feel: `production/qa/evidence/cultivation-bar-evidence.md` + sign-off（动画/光效/tooltip 手动验证）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（挂载点）
- Unlocks: None（独立组件）
