# Epic: 探索 UI

> **Layer**: Presentation
> **GDD**: design/gdd/exploration-ui-system.md
> **Architecture Module**: 探索 UI 系统（地图视图、节点渲染——`render_map()` / `show_event(event)`）
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories exploration-ui`

## Overview

探索 UI 实现双层界面：地图选择（地图卡片横向滚动、重入确认弹窗）与节点图主界面（节点图节点/路径连线/迷雾遮罩、滚轮缩放 50%-150%+平移、AP 分段格指示器、节点悬停预览与交互弹窗、通关结算/探索结束面板）。两个 GDD 阻塞项已决策（缩放=滚轮+平移、路径选择=直接点击自动路由）并经 ux-review APPROVED。

**结构条件**（PR-EPIC 2026-09-07 A2）：节点图性能 story（R-05）必须是本 epic 的**第一个 story**，带基准验收关卡——最坏情况（6 层×4 节点）缩放平移 60fps。基准不过关时优化迭代（图集/合批/LOD）在 epic 内部消化。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0031: 表现层架构基线 | 场景内 Control + 零状态所有权 + 迷雾合批渲染 | HIGH（4.6 双焦点） |
| ADR-0014: 探索系统 | DAG 生成、GSM 主存储（`exploration.*` 域）、重入经济公式 | LOW |
| ADR-0005: 场景管理器 | 地图选择↔节点图↔战斗的场景切换编排 | LOW |

## GDD Requirements

TR 注册表暂无表现层条目——需求以 GDD 验收标准编号占位：

| AC 编号 | Requirement | ADR Coverage |
|-------|-------------|--------------|
| AC-exploration-ui-001~050 | exploration-ui-system.md §验收标准（50 条） | ADR-0031 ✅ |
| AC-exploration-ui-ux | design/ux/exploration-ui.md（APPROVED）——11 界面全覆盖、AP 分段格、Boss 推荐战力、节点交互 17 事件 | ADR-0031 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/exploration-ui-system.md` are verified（50 条）
- **R-05 关卡：节点图最坏情况基准通过（首个 story，60fps 验收）**
- 11 个 GDD 界面全部可演示（地图选择→节点图→节点交互→结算闭环）
- All UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories exploration-ui` to break this epic into implementable stories.

**排期提示**（PR-EPIC 2026-09-07）：Sprint 14/15 进入——需三个 spike（R-01/R-02/R-03）出结论、hud 落地之后。节点图性能 story 排首位。
