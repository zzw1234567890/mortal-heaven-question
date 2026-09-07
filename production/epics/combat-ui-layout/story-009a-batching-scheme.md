# Story 009a: R-02 合批方案定型（前置架构 spike）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel（架构定型）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: Draw Call 预算段（GDD 修正估算：16 位×14 items≈280-300 峰值 → 优化后 ≈169）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§5 渲染预算）
**ADR Decision Summary**: 图集合批是 **Required pattern 而非事后优化**（ADR-0031 §5）——QL-STORY-READY 2026-09-07 裁决：本 story 拆分前置，**排在 story 002 之前**，产出合批实现规范供 002-006 按此实现，避免先独立纹理实现再全局返工。

**Engine**: Godot 4.6 | **Risk**: HIGH（D3D12 默认渲染器 + Draw Call 测量 API 待引擎参考核验）
**Engine Notes**: `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` 属引擎参考验证范围——实现前核对 `docs/engine-reference/godot/`（4.4-4.6 变更风险）。D3D12 下测量须窗口模式本地运行（headless DC 数不具代表性）。

**Control Manifest Rules (this layer)**:
- Required: 合批方案文档化（图集结构/HP 条绘制方式/DC 分组方案）；基准原型场景实测
- Forbidden: 角色位独立纹理图标（方案定型后）
- Guardrail: 原型实测 4 DC/位可行性确认后才放行 002

---

## Acceptance Criteria

*From GDD Draw Call 预算段，scoped to this story:*

- [ ] TextureAtlas 结构定型：状态图标/阵营指示器/卡牌边框/角标图标合并方案（图集划分与命名规范）
- [ ] HP 条绘制方式定型：draw_rect() 纯色批量绘制（单一 CanvasItem `_draw()` 调用）替代纹理 ProgressBar
- [ ] 角色位 DC 分组方案定型：14 items → 3-4 draw call/位（头像 1+状态图标图集 1+HP条 1+文字 1）
- [ ] **基准原型场景**（纯节点无游戏逻辑）：16 角色卡原型实测每位 ≤4 DC
- [ ] 合批实现规范文档产出（002-006 的实现依据）
- [ ] fallback 裁剪优先级确认：1) 日志纯文字 Label 2) 飘字批量 RichTextLabel 3) 状态图标显示上限
- [ ] DC 测量方法核验：引擎参考查证 get_rendering_info API + 本地测量脚本（009b 消费）

---

## Implementation Notes

*Derived from ADR-0031 §5 Implementation Guidelines:*

- 本 story 是**架构 spike + 方案定型**，非完整功能实现：产出 = 图集资产结构 + 绘制方式决策 + 原型实测记录 + 实现规范文档。
- 原型场景：程序化构造 16 个角色卡原型节点（占位纹理/图标/HP条/文字），运行数帧采样 DC。
- 实测环境：D3D12 窗口模式本地运行；结果记录进 evidence（非 CI 关卡——009b 沿用此策略）。
- 文档落点：`production/qa/evidence/r02-batching-spec.md`（或 epic 内架构笔记）——002/003/004/006 引用。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009b: 16 角色满场+手牌+顶部条的整场景实测关口（组件完成后）
- Story 002-006: 按方案实现组件（消费方）
- interaction epic: 拖拽半透明 D3D12 烟雾项

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Visual/Feel — manual verification steps]:**

- **AC-1**: 原型 DC 实测
  - Setup: 基准原型场景（16 角色卡原型）本地 D3D12 窗口模式运行
  - Verify: 每角色位 DC ≤4（get_rendering_info 采样，连续 60 帧稳定值）
  - Pass condition: 16 位合计 ≤64 DC（含角色位），为整场景 <200 预算留出余量；实测记录归档 evidence

- **AC-2**: 合批规范文档完备
  - Setup: 审阅产出文档
  - Verify: 图集结构/HP 条方式/DC 分组/fallback 优先级/测量方法五节齐备
  - Pass condition: 002-006 开发者无需再做渲染决策、按文档可实现

---

## Test Evidence

**Story Type**: Visual/Feel（架构定型）
**Required evidence**:
- `production/qa/evidence/r02-batching-spec.md`（合批实现规范+原型实测记录）+ sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（本 epic 内最先执行，与 R-01 spike 同为 Sprint 14 前置）
- Unlocks: Story 001-006（按方案实现）；Story 009b（复用测量方法）
