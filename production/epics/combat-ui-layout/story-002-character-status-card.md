# Story 002: 角色状态卡组件（L0-L5 分层）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: HP条与视觉反馈 AC + 角色状态视觉标记（前后排）AC + UX 角色状态卡 L0-L5 规格表
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 图集合批（按 story 009a 定型方案实现）；HP 条 draw_rect 批量绘制；零状态所有权（角色数据从战斗系统读取）。UX 规格：前排 120×168px 100% 实线边框 / 后排 85% 虚线。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: L2 图标竖排（功法左/法宝右各最多 3）+ L4 角标（buff 左下最多 5/境界右下）+ L5 待命标记——按 009a 的 3-4 DC/位 分组方案组织节点。

**Control Manifest Rules (this layer)**:
- Required: `hp_bar_color()`/`formation_row_scale()` 纯函数单测；角色卡按 009a 合批分组
- Forbidden: 独立纹理图标（走图集）；硬编码 HP 阈值
- Guardrail: 单角色位渲染成本 ≤009a 定型的 DC 分组预算

---

## Acceptance Criteria

*From GDD + UX，scoped to this story:*

- [ ] 角色卡 L0-L5 分层渲染：头像全幅背景（L0）→ 底部渐变遮罩 40-60%（L1）→ 功法图标竖排左侧/法宝竖排右侧各最多 3 个 20×20px（L2）→ HP条+ATK 底部条 40px（L3）→ buff/debuff 左下角标最多 5 个+境界图标右下（L4）→ 待命/已行动左上标记（L5）
- [ ] HP 变化 0.3s 线性过渡（Tween）；HP 数字 ≤100ms 更新终值
- [ ] HP 颜色阈值：>60% 绿、30%~60% 黄、≤30% 红（HP=30% 为红）
- [ ] 前排 100% 缩放+实线金色边框；后排 85% 缩放+虚线蓝色边框
- [ ] 角色卡上文字对比度 ≥4.5:1（渐变遮罩保证）
- [ ] 境界标记仅高于玩家境界时显示（悬停显示境界名归 interaction）
- [ ] 角色数据信号驱动更新（HP/buff/绑定图标变更），非轮询

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `hp_bar_color(hp_ratio) -> Color`——>0.6 绿 / >0.3 黄 / ≤0.3 红。
- `formation_row_scale(is_front_row) -> float`——1.0 / 0.85。
- 字号经 story 001 的共享 `font_size_responsive()`（不得内联）。

- L2 功法/法宝图标数据从绑定系统 `get_binding_ids_by_character()` 零分配查询（ADR-0013）。
- HP 条实现按 009a 方案（draw_rect 纯色批量绘制，非纹理 ProgressBar）。
- 待命标记 L5 的**渲染**在本 story；**信号切换逻辑**（待命→已行动状态机）归 story 003——两 story 互引。
- 境界图标用不同图标区分境界（UX 决策），数据从境界系统读取。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: 待命/已行动信号切换、阵亡动画、飘字、HP 批量过渡
- Story 001: 布局容器（本组件填充己方/敌方区）
- interaction epic: 角色卡点击/悬停详情
- 音效（伤害命中声）：audio-manager epic

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_hp_bar_color.gd` + `test_formation_row_scale.gd`）

- **AC-1**: HP 颜色阈值
  - Given: hp_ratio
  - When: 调用 `hp_bar_color()`
  - Then: 0.61/1.0 → 绿；0.6 → 黄；0.31 → 黄；0.30 → 红；0.0 → 红
  - Edge cases: 0.6 恰好黄（>0.6 才绿）、0.3 恰好红（AC 明文）、max_hp=0 调用侧守卫（防除零）

- **AC-2**: 前后排缩放
  - Given: is_front_row true/false
  - When: 调用 `formation_row_scale()`
  - Then: 1.0 / 0.85
  - Edge cases: 边框样式为独立属性不在此函数测

**[Integration — automated test specs]:**

- **AC-3**: 信号驱动更新
  - Given: 角色卡已渲染
  - When: 战斗系统发射 HP 变更信号
  - Then: HP 条/数字更新；无 `_process` 轮询
  - Edge cases: 同帧多次信号（终值生效）

**[UI — manual verification steps]:**

- **AC-4**: L0-L5 分层与可读性
  - Setup: 16 角色位满场（前排+后排各阵营）
  - Verify: 六层元素齐备（功法/法宝各≤3、buff≤5、境界、待命）；文字在遮罩上可读
  - Pass condition: 前排实线/后排虚线+85% 视觉可区分；对比度抽检 ≥4.5:1；每角色位渲染成本在 009a 预算内

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_hp_bar_color.gd` + `test_formation_row_scale.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_character_card_signal.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/character-card-evidence.md` + sign-off（截图）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（容器与共享纯函数）、Story 009a（合批分组方案）
- Unlocks: Story 003（状态标记消费本组件接口）
