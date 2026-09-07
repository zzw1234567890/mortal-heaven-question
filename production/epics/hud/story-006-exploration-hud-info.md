# Story 006: 探索 HUD 右下信息组（AP/地图名/层数）

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-001（探索场景维度）+ §5 探索中 HUD
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权；事件驱动更新（Cat 1 信号 `action_points_changed` / `batch_updated`）。AP 颜色阈值判定实现为共享纯函数（HUD 与 exploration-ui 双消费），helper 落地须先于 exploration-ui 的 AP story（QL-STORY-READY 裁决）。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 本组件纯显示，无焦点交互。GSM 既有信号：`action_points_changed(delta, current, max_val)`；`GSM.exploration` Dictionary 含 `action_points` 字段，`set_exploration_ap(current, max_ap)` API 可用于测试驱动状态。

**Control Manifest Rules (this layer)**:
- Required: AP 阈值判定为共享纯函数（HUD 与 exploration-ui 共用），单测一次双消费
- Forbidden: UI 脚本内联阈值；UI 写入 GSM
- Guardrail: AP 变更刷新即时（信号驱动），无逐帧轮询

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md` §5，scoped to this story:*

- [ ] 探索场景右下显示：当前地图名、AP（当前/最大）、当前层/总层数（如 3/5）
- [ ] AP 变更时显示即时更新（信号驱动，非轮询）
- [ ] AP 颜色阈值判定使用共享纯函数（HUD 与 exploration-ui 同一实现）
- [ ] AP 分段格显示（每格 = 1 AP，已消耗格子熄灭）——与 exploration-ui UX 规范的 AP 强化显示共用判定逻辑
- [ ] 离开探索场景（进战斗/商店）该区域隐藏或按 Story 001 可见性规则处理

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`get_ap_color_threshold(current: int, max_val: int) -> Dictionary` 共享纯函数——返回 AP 颜色状态（正常/警告/紧急，阈值数据驱动）。该 helper 是 HUD 与 exploration-ui 的共享判定源——**落地须先于 exploration-ui 的 AP story**，本 story 是它的第一消费者与归属实现方。共享位置建议 `src/ui/shared/` 或等效公共模块（具体由实现时架构确认，须在两 epic 间可见）。

- 信号绑定：订阅 `GSM.action_points_changed(delta, current, max_val)`，显示时从 `GSM.exploration.action_points` 读取。
- 地图名/层数从探索系统状态读取（`GSM.exploration` 或探索系统公共接口）。
- AP 分段格渲染（每格 1 AP、已消耗熄灭）为 UI 手动验证部分；分段判定（当前/最大/已消耗）可并入纯函数返回。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载与可见性
- exploration-ui epic: 探索场景中央节点图、AP 强化显示组件本体（消费本 story 的共享 helper）、AP 悬停详情浮窗
- 战斗中右下费用/牌库显示：归 combat-ui（HUD 战斗中不渲染）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]:**

- **AC-1**: AP 颜色阈值判定（共享纯函数）
  - Given: AP current/max_val
  - When: 调用共享 `get_ap_color_threshold(current, max_val)`
  - Then: 按阈值返回颜色状态（阈值来自配置常量，如 ≤20% 紧急、≤50% 警告、>50% 正常——以配置为准）
  - Edge cases: 0/5、1/5、3/5、5/5、max_val=0（防除零）、current>max_val（临时 AP 超上限的防御性处理）

- **AC-2**: AP 数据绑定
  - Given: HUD 已挂载且显示当前 AP
  - When: 调用 `GSM.set_exploration_ap(2, 5)` 触发 `action_points_changed`
  - Then: HUD AP 显示更新为 2/5（自动化断言显示文本）
  - Edge cases: 连续变更（最后一次生效）、进战斗隐藏期间变更（恢复可见后显示最新值）

**[UI — manual verification steps]:**

- **AC-3**: 探索右下信息组完整性
  - Setup: 进入探索场景（如青云剑宗 层3/5）
  - Verify: 显示地图名「青云剑宗」、AP「3/5」、层数「层3/5」
  - Pass condition: 三项信息与游戏状态一致，布局不遮挡中央内容区

- **AC-4**: AP 分段格显示
  - Setup: AP 从 5 消耗到 3
  - Verify: 5 格分段中 3 格点亮、2 格熄灭
  - Pass condition: 已消耗格子熄灭明显可辨，颜色阈值状态正确

---

## Test Evidence

**Story Type**: UI（含 Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/hud/test_ap_color_threshold.gd`（共享 helper）— must exist and pass（BLOCKING）
- Integration: AP 数据绑定断言并入 `tests/integration/hud/test_gsm_signal_binding.gd`（与 Story 003 共用文件，追加用例）— must exist and pass（BLOCKING）
- UI: `production/qa/evidence/exploration-hud-info-evidence.md` + sign-off（信息组/分段格手动验证）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（挂载点）
- Unlocks: exploration-ui epic 的 AP 显示 story（消费共享 helper）
