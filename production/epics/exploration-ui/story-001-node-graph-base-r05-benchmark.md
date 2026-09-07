# Story 001: 节点图渲染基座与 R-05 性能基准（stub 数据）

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel（性能关卡——EPIC 结构条件首个 story）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 性能（非功能性）AC 4 条中的基准部分 + UX Open Question #5（节点图性能——架构阶段验证）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 渲染预算（图集合批 <200 DC）+ 场景内 Control 节点；本 story 是 R-05（节点图性能风险）的行为关卡——最坏情况基准先行，不过关时优化迭代（图集/合批/LOD）在本 epic 内消化。

**Engine**: Godot 4.6 | **Risk**: HIGH（D3D12 默认渲染器 + 大量 Control 节点缩放平移）
**Engine Notes**: DC 测量用 `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`（combat-ui layout 009a 已核验方法）；缩放平移基于 Control scale/position 或 Camera2D——4.6 均可用，实测裁决。

**Control Manifest Rules (this layer)**:
- Required: 实测记录 + 主管签批；基准数据作为 epic 后续 story 的参照基线
- Forbidden: 以少量节点实测替代最坏情况（6 层×4 节点 = 含入口/Boss 共 22+ 节点）
- Guardrail: 缩放平移期间帧时间 ≤16.6ms；1280×720 下限分辨率可用

---

## Acceptance Criteria

*From GDD 性能 AC + EPIC 结构条件，scoped to this story:*

- [ ] stub 数据最坏情况节点图（6 层×4 节点 + 连线 + 迷雾覆盖 + 10 类节点图标）渲染基座搭建完成
- [ ] 滚轮缩放 50%-150% + 中键/边缘平移 + 空格复位交互可用（UX 已批准决策）
- [ ] 最坏情况缩放平移 60fps：连续 60 帧帧时间采样 p95 ≤16.6ms
- [ ] 节点图渲染 DC ≤200（stub 版基准值记录，story 010 真实元素复测对照）
- [ ] 基准不过关时的优化路径验证：图集合批/LOD（缩放 <75% 时切换低精度图标）至少一项可行性记录
- [ ] 迷雾遮罩合批渲染（ADR-0031）：迷雾覆盖不逐节点产生独立 DC

---

## Implementation Notes

*Derived from ADR-0031 §5 + EPIC 结构条件:*

- stub DAG 数据构造：6 层×4 节点（极高难度上限），含全部 10 种节点类型图标、完整连线、迷雾覆盖未访问区域。
- 缩放平移容器：推荐 Control 内部 scale/position 变换（节点为 Control 子节点）；若实测有锯齿/性能问题，评估 Camera2D 方案——本 story 实测裁决并记录。
- 迷雾合批：迷雾作为整体覆盖层（单节点或少数大块），不逐节点实例化——ADR-0031 迷雾合批决策的直接验证。
- DC/帧时间采样脚本复用 combat-ui layout 009a 的方法（get_rendering_info）。
- 本 story 交付的渲染基座（节点控件/连线/迷雾/缩放容器）是 003 数据接入的宿主。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: 真实 DAG 数据接入与节点状态渲染（本 story 用 stub 数据）
- Story 005: 点击移动交互（本 story 仅缩放平移交互）
- Story 010: 真实元素性能复测与 720p 自适应终验

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Visual/Feel — manual verification steps（本地关卡脚本辅助）]:**

- **AC-1**: 最坏情况缩放平移帧率
  - Setup: stub 最坏情况节点图（6 层×4 节点），D3D12 窗口模式
  - Verify: 连续缩放（50%↔150%）+ 平移操作 60s，帧时间采样 p95 ≤16.6ms
  - Pass condition: 帧率稳定 60fps；超标项定位并记录优化路径

- **AC-2**: DC 基准
  - Setup: 同上场景静态 + 缩放中两种状态
  - Verify: DC 采样 ≤200
  - Pass condition: 两状态均 ≤200，基准值写入 evidence（供 010 复测对照）

- **AC-3**: 迷雾合批
  - Setup: 迷雾覆盖 50% 节点的 stub 场景
  - Verify: 迷雾区域增减时 DC 变化量（逐节点实例化会导致 DC 随节点数线性增长）
  - Pass condition: DC 变化与迷雾覆盖节点数无强线性关系

---

## Test Evidence

**Story Type**: Visual/Feel（性能关卡）
**Required evidence**:
- `production/qa/evidence/r05-node-graph-benchmark-evidence.md`（帧时间分布 p50/p95/p99 + DC 基准 + 优化路径记录）+ sign-off
- `production/risk-register/presentation-layer-risks.md` R-05 状态更新

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（本 epic 首个 story——EPIC 结构条件）
- Unlocks: Story 003（渲染基座宿主）、Story 005（缩放平移交互）、Story 010（复测对照）
