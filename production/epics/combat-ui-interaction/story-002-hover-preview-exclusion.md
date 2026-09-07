# Story 002: 手牌悬停预览与悬浮详情面板互斥

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 悬停详情 AC 4 条 + §12 悬浮提示规则 + 公式 7（悬停延迟）+ 边界澄清补充二（MOUSE_FILTER_STOP 统一/弹窗期冻结）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（详情数据每信号周期从源系统读取）+ 瞬态交互状态（面板开关/当前悬停目标为 UI 本地合法）+ 输入驱动的纯视觉变换不视为轮询。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: 悬停触发用 `mouse_entered`/`mouse_exited` + SceneTreeTimer（300ms 首次/0ms 切换）；命中区域 10px margin 防边缘抖动（GDD §12）。

**Control Manifest Rules (this layer)**:
- Required: 悬停面板互斥（同一时刻最多一个）；300ms 首次触发/0ms 面板间切换（公式 7）
- Forbidden: 轮询游戏状态刷新面板（悬停是输入驱动，数据读取在触发时一次）
- Guardrail: 信号响应 → 视觉更新 <1 帧

---

## Acceptance Criteria

*From GDD §12 + 悬停详情 AC，scoped to this story:*

- [ ] 悬停手牌卡牌 300ms（hover_trigger_delay）→ 放大 120% + 上浮 10px + 详情全文（效果/稀有度/类型/费用）——**全阶段可用**（含灵能预览态，7 阶段内）
- [ ] 面板间切换 0ms：悬停元素 A 面板展开后鼠标移到元素 B → A 立即关闭、B 立即弹出（不等待 300ms）
- [ ] 互斥实现：手牌放大预览区域 `MOUSE_FILTER_STOP` 阻止穿透到角色区；角色区 `mouse_entered` 检查手牌预览展开则不触发（应用层互斥双保险）
- [ ] 手牌预览 z_index +1 高于角色详情面板（空间重叠时手牌预览优先渲染）
- [ ] 悬停场上角色/敌方角色 → 角色详情面板（HP/ATK/DEF、绑定卡效果、buff/debuff 详情）300ms 触发
- [ ] 悬停状态图标 → 状态名称+效果描述+剩余回合数（300ms）
- [ ] 悬停阵法卡 → 阵法效果详情（触发条件、效果描述、阵营条件）300ms
- [ ] 原始卡牌 `mouse_exited` 关闭预览（命中区域 10px margin 防抖）
- [ ] 弹窗（MODAL 锁）打开时：悬停详情面板冻结不触发、已展开的立即关闭（边界澄清补充二）
- [ ] 同一时刻最多一个详情面板展开（任意输入序列下不变量）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`HoverExclusionMachine`（或等效纯类）——输入事件序列（enter A/exit A/timer 300ms 到期/enter B/modal_open）→ 唯一活动面板状态。无真实时钟依赖（时间注入）。

- 详情数据：触发时从源系统读取（卡牌模板经 CardSystem.get_template、角色状态经 GSM 第一层/DeploymentSystem、阵法经 FormationSystem）——面板不缓存。
- 300ms/0ms 区分：首次悬停起 SceneTreeTimer 300ms；已有面板打开时新 enter 立即切换（清零 timer）。
- 长时间悬浮：预览保持直到 mouse_exited，不自动关闭（GDD 边界情况）。
- A9 落地：弹窗期冻结——面板状态机监听 MODAL 锁（story 001 封装）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- layout story 006: 灵能预览态的渲染（60% 饱和度+🔒——本 story 仅保证悬停在其上仍可用）
- layout story 004: 阵法区本体渲染
- Story 003: 拖拽（拖拽启动时悬停预览应让位——交互次序在 003 处理）
- Story 008: 牌库/弃牌堆展开面板（点击触发，非悬停）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_hover_exclusion.gd`）

- **AC-1**: 悬停互斥状态机
  - Given: 面板状态机初始无面板
  - When: 注入事件序列（enter_card → 300ms 到期 → enter_character）
  - Then: card 面板开（300ms 后）→ enter_character 时 card 面板立即关、character 面板立即开（0ms 切换）
  - Edge cases: 300ms 内 exit（面板不开）；300ms 内切换目标（新目标重新计时）；modal_open 时 enter（不触发）+ 已开面板立即关；mouse_exited 10px margin 内（不关）

**[Integration — automated test specs]:**

- **AC-2**: 300ms 触发时序
  - Given: 悬停卡牌
  - When: SceneTreeTimer 推进 299ms / 300ms
  - Then: 299ms 时未弹出；300ms 时弹出
  - Edge cases: 恰 300ms 边界（实现定义固化）

**[UI — manual verification steps]:**

- **AC-3**: 互斥与穿透阻断
  - Setup: 手牌预览展开（覆盖角色区位置）后鼠标移入角色区
  - Verify: 角色详情不弹出（STOP 阻断）；移出预览后角色详情正常
  - Pass condition: 任意操作序列下同时最多一个面板；预览与角色面板重叠时预览在上

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_hover_exclusion.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_hover_timing.gd` — must exist and pass
- UI: `production/qa/evidence/hover-preview-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（锁栈封装——弹窗冻结）、layout story 006（手牌渲染）
- Unlocks: 无直接下游（003 拖拽与悬停的次序处理引用本 story 状态机）
