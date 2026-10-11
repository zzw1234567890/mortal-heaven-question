# Story 009a: R-02 合批方案定型（前置架构 spike）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel（架构定型）
> **Estimate**: 0.5d
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-10-11

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: Draw Call 预算段（GDD 修正估算：16 位×14 items≈280-300 峰值 → 优化后 ≈169）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§5 渲染预算）
**ADR Decision Summary**: 图集合批是 **Required pattern 而非事后优化**（ADR-0031 §5）——QL-STORY-READY 2026-09-07 裁决：本 story 拆分前置，**排在 story 002 之前**，产出合批实现规范供 002-006 按此实现，避免先独立纹理实现再全局返工。

**Engine**: Godot 4.6 | **Risk**: HIGH（D3D12 默认渲染器 + Draw Call 测量 API 待核验）
**Engine Notes**: `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` **引擎参考当前零覆盖**（QL-STORY-READY 2026-09-19 实测查证）——核验以**官方文档为源**（docs.godotengine.org 4.6 stable：RenderingServer.get_rendering_info + RenderingInfo 枚举），核验结论**回写 `docs/engine-reference/godot/modules/rendering.md`**；API 不可用则降级 Godot 内置调试器 Monitor 面板人工读数。D3D12 下测量须窗口模式本地运行（headless DC 数不具代表性）。

**Control Manifest Rules (this layer)**:
- Required: 合批方案文档化（图集结构/HP 条绘制方式/DC 分组方案）；基准原型场景实测
- Forbidden: 角色位独立纹理图标（方案定型后）
- Guardrail: 原型实测 4 DC/位可行性确认后才放行 002

---

## Acceptance Criteria

*From GDD Draw Call 预算段，scoped to this story:*

- [x] TextureAtlas 结构定型：状态图标/阵营指示器/卡牌边框/角标图标合并方案（图集划分与命名规范）
- [x] HP 条绘制方式定型：draw_rect() 纯色批量绘制（单一 CanvasItem `_draw()` 调用）替代纹理 ProgressBar——**R-02 实测修正：3 个 draw_rect = 3 DC（非 1），边框 outline 可裁剪省 1 DC/条**
- [x] 角色位 DC 分组方案定型：14 items → **6 draw call/位（R-02 实测修正 2026-10-11）**（头像 1+状态图标图集 1+HP条 3+文字 1）
- [x] **基准原型场景**（纯节点无游戏逻辑）：16 角色卡原型实测 96 DC / **6.0 DC·位**——每位 ≤4 不可行，整场景 <200 达标（用户裁决 2026-10-11 接受 6 DC/位）
- [x] 合批实现规范文档产出（002-006 的实现依据）——`production/qa/evidence/r02-batching-spec.md`
- [x] fallback 裁剪优先级确认：1) 日志纯文字 Label 2) 飘字批量 RichTextLabel 3) 状态图标显示上限——**升级为峰值场景硬约束（实测贴 200 线）**
- [x] DC 测量方法核验：`get_rendering_info` + `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`（=2）存在性核验通过，结论回写 `docs/engine-reference/godot/modules/rendering.md`；产出本地测量脚本 `prototypes/r02-batching-spike/benchmark.gd`（009b 消费）；降级路径 Godot 内置调试器 Monitor 人工读数

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

**Status**: [x] 合批实现规范 + 原型实测记录已产出（`production/qa/evidence/r02-batching-spec.md`）

---

## Dependencies

- Depends on: None（与 story 001 并行为 epic 前置——两者无依赖；002-006 须在本 story 放行后实现）
- Unlocks: Story 002-006（按方案实现）；Story 009b（复用测量方法）

---

## Completion Notes

**Completed**: 2026-10-11
**Criteria**: 7/7 通过（AC-1 原型实测 + AC-2 规范文档完备——Visual/Feel 手动验证）
**Deviations**（ADVISORY 级，非阻塞）:
- **「每角色位 ≤4 DC」不可行**：R-02 实测 16 卡 96 DC / 6.0 DC·位（HP 条 3 个 draw_rect=3 DC + 文字渲染非单次 draw call）。用户裁决 2026-10-11 接受 6 DC/位——整场景仍达标（96 << 200）
- 峰值场景重算 ≈201 DC 贴 200 线——fallback 裁剪优先级升级为硬约束（非可选）
- 实测环境为 Vulkan Forward+（RTX 3050），非 D3D12 默认后端——headless 与 D3D12 差异在 009b 满场实测时复核
**Test Evidence**: `production/qa/evidence/r02-batching-spec.md`（五节齐备 + 实测结果）+ `prototypes/r02-batching-spike/`（spike.gd + benchmark.gd + README.md）
**Code Review**: SKIPPED——架构 spike 无 `src/` 实现文件（原型代码按放宽标准 `prototypes/` 隔离，不进入生产审查），Visual/Feel 证据关卡 ADVISORY 级
