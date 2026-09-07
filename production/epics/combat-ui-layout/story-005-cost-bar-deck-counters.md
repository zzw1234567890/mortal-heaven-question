# Story 005: 费用栏与牌库/弃牌计数

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 费用表现 AC 4 条 + 牌库与弃牌堆 AC（计数 1 条）+ 费用消耗动画
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: cost_color 纯函数（含 base_max=0 双守卫）；费用信号驱动显示动画（QL-STORY-READY 2026-09-07 裁决归本 story）；点击展开牌库/弃牌详情归 interaction。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: D3D12 烟雾测试项「费用消散粒子」（CPUParticles2D + modulate.a）落在本 story——本地关卡脚本验证（009b 统一执行）。

**Control Manifest Rules (this layer)**:
- Required: `cost_color()` 纯函数单测（含 GDD 明文守卫例）；费用信号驱动断言
- Forbidden: 硬编码阈值；轮询费用
- Guardrail: 费用消耗动画 0.2s；粒子按 009a 方案预算

---

## Acceptance Criteria

*From GDD，scoped to this story:*

- [ ] 费用栏显示 `实际可用/基础上限` 大字 + 临时费用绿色额外数字（如 0/0 [+3临时]）
- [ ] 费用颜色按 cost_color() 公式（含 base_max=0 守卫：仅临时→黄、全无→红）
- [ ] 费用消耗：数字跳动减少+光粒消散动画 0.2s（费用信号驱动）
- [ ] 临时费用用完消失：绿色数字淡出动画，基础费用不变
- [ ] 牌库剩余/弃牌堆计数数字显示正确（点击展开归 interaction）
- [ ] 费用变更信号驱动更新，非轮询

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`cost_color(available, base_max, temporary) -> Color`——GDD 公式 4 完整实现（含双守卫：base_max=0 且 temporary=0 → RED；base_max=0 且 temporary>0 → YELLOW）。

- 费用数据：订阅战斗系统/费用系统信号（可用/上限/临时变更）。
- 消耗动画：cost 变更信号 → 数字跳动 Tween 0.2s + 粒子消散（D3D12 烟雾项）。
- 临时费用消失：temporary 归零信号 → 绿色数字淡出。
- 牌库/弃牌计数：订阅卡牌系统信号更新数字。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 底部条容器
- interaction epic: 牌库/弃牌点击展开详情、面板间 0ms 切换
- audio-manager epic: 费用消耗音
- 手牌灰显判定（费用不足的手牌状态）：story 006

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_cost_color.gd`）

- **AC-1**: cost_color 完整覆盖（含 GDD 明文三守卫例）
  - Given: (available, base_max, temporary)
  - When: 调用 `cost_color()`
  - Then: (3,0,3) → YELLOW（GDD AC 明文）；(0,0,0) → RED（守卫）；(5,5,0) → WHITE；(3,5,0)→WHITE；(5,10,0) → YELLOW（ratio=0.5 恰黄）；(0,5,0) → RED；(4,3,3) → WHITE（ratio≈0.67）
  - Edge cases: available 负值（实现定义 clamp 或断言失败，测试固化决策）；temporary 负值

**[Integration — automated test specs]:**

- **AC-2**: 费用信号驱动显示
  - Given: 费用栏显示 5/5
  - When: 费用系统发射变更（扣 2）
  - Then: 显示更新为 3/5（数字断言，动画归手动验证）
  - Edge cases: 临时费用加入（+3 显示绿色段）；同帧多次变更终值生效

**[UI — manual verification steps]:**

- **AC-3**: 费用动画
  - Setup: 出牌消耗费用
  - Verify: 数字跳动+光粒消散 0.2s；临时费用用完绿色淡出
  - Pass condition: 动画即时感、D3D12 下粒子无 alpha 异常

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_cost_color.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/combat_ui/test_cost_display.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/cost-bar-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（底部条容器与共享纯函数模块）
- Unlocks: Story 006（手牌灰显消费 cost 数据）
