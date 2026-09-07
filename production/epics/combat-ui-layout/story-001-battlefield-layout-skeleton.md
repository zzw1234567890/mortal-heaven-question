# Story 001: 战场四区域布局骨架与共享纯函数模块

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（含 Integration）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 战斗HUD初始化 AC + UX `design/ux/combat-ui.md` Layout Zones
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 场景内 Control 零新增 Autoload；anchor 百分比响应式布局；零状态所有权。边界澄清 2026-09-07：顶部条组成按 UX 规范（日志+阶段指示器+阵法区+暂停按钮），撤退按钮右上角独立常驻，暂停按钮转发 hud 暂停菜单。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: **前置：R-01 双焦点 spike + story 009a 合批方案定型**。宽屏/超宽屏用 anchor_* 预设百分比布局。

**Control Manifest Rules (this layer)**:
- Required: 建立共享纯函数模块（`font_size_responsive()` 等在此落地供后续 story 消费）；HUD 隐藏信号对接
- Forbidden: 新增 Autoload；像素硬编码布局（百分比 anchor）
- Guardrail: 进场过渡总时长内 HUD 完全可见 ≤2s

---

## Acceptance Criteria

*From GDD + UX，scoped to this story:*

- [ ] 战斗场景四区域容器搭建：顶部条 60px / 敌方区 ~340px / 中线分隔 / 己方区 ~340px / 底部条 ~180px（1920×1080 基准，anchor 百分比响应式）
- [ ] 顶部条容器：日志入口按钮 + 回合阶段指示器位 + 阵法区位 + 暂停按钮位（内容归 004）
- [ ] 右上角撤退按钮常驻（内容/点击行为归 008/interaction）
- [ ] 进入战斗时 HUD 隐藏对接（消费 hud story 001 可见性信号，战斗场景 HUD 不渲染）
- [ ] 暂停按钮位预留：点击/ESC 转发 hud 暂停菜单（菜单本体归 hud story 005）
- [ ] 进场过渡动画：顶部条上方滑入 0.3s / 敌方区淡入 0.4s / 己方区淡入 0.4s / 底部条下方滑入 0.3s；「进入战斗到 HUD 完全可见 ≤2s」（UX AC）
- [ ] **共享纯函数模块建立**：`font_size_responsive()` 提取落地 + `tests/unit/combat_ui/` 目录初始化
- [ ] 音频对接：进入战斗触发 `set_state(IN_COMBAT)` 音频事件（消费 audio-manager API）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- 战斗 UI 场景根节点 Control，五区域子容器按 UX Layout Zones 表搭建。区域内容（角色卡/手牌/阶段指示器等）由后续 story 填充，本 story 只搭容器与过渡。
- **共享纯函数模块**（QL-STORY-READY 裁决上移）：`src/ui/combat/shared/`（或等效路径）建立 `font_size_responsive(base_font_size, screen_height)`——≥1080 原值 / ≥720 ×0.85 / <720 保底 12pt。002/004/005/006 消费，**不得各自内联实现**。
- HUD 隐藏：消费 SceneManager 转场信号/场景状态（hud story 001 同源），战斗场景 HUD 不渲染。
- 进场过渡按 UX Transitions & Animations 编排（含减少动态替代：直接就位无动画）。
- 音频事件：仅触发 `set_state(IN_COMBAT)` 请求（audio-manager epic 的 API）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002/003: 角色卡组件与状态标记
- Story 004: 顶部条内容（阶段指示器/阵法区/日志）
- Story 005/006: 费用栏与手牌区内容
- Story 008: 撤退/结算面板本体（本 story 仅按钮位）
- interaction epic: 拖拽/悬停/点击流转
- R-01 双焦点 spike（前置任务，非 story）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_font_size_responsive.gd`）

- **AC-1**: 字号响应式
  - Given: base_font_size 与 screen_height
  - When: 调用 `font_size_responsive()`
  - Then: 1080 → 原值；1079 → 85%；720 → 85%；719 → 12
  - Edge cases: base=14@720 → max(11.9, 12)=12（保底截断）；base=100@720 → 85；base=12@1080 → 12

**[Integration — automated test specs]:**

- **AC-2**: 区域容器存在性与锚定
  - Given: 战斗场景加载完成
  - When: 检查节点树
  - Then: 五区域容器存在且 anchor 为百分比预设（非像素绝对定位）
  - Edge cases: 1280×720 下区域不溢出/不重叠

- **AC-3**: HUD 隐藏联动
  - Given: 进入战斗
  - When: 场景就绪
  - Then: HUD CanvasLayer visible == false（消费 hud story 001 信号）
  - Edge cases: 战斗退出后 HUD 恢复

**[UI — manual verification steps]:**

- **AC-4**: 进场过渡与布局
  - Setup: 从探索进入战斗
  - Verify: 各区域按序滑入/淡入（顶部条 0.3s→敌方区 0.4s→己方区 0.4s→底部条 0.3s）；从点击进入战斗到 HUD 完全可见 ≤2s
  - Pass condition: 动画流畅、减少动态开关生效时直接就位、1920×1080 与 1280×720 均无溢出

---

## Test Evidence

**Story Type**: UI（含 Integration + Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_font_size_responsive.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_layout_skeleton.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/combat-layout-skeleton-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: R-01 双焦点 spike、Story 009a（合批方案定型）、hud story 001（可见性信号）
- Unlocks: Story 002~008（容器与共享纯函数模块）
