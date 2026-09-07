# Epic: 卡组编辑 UI

> **Layer**: Presentation
> **GDD**: design/gdd/deck-editing-ui-system.md
> **Architecture Module**: 卡组编辑 UI（卡组编辑界面——`render_deck()` / `show_collection()`）
> **Status**: Blocked（UX 规范前置依赖）
> **Stories**: Not yet created — run `/create-stories deck-editing-ui`（UX 规范完成后）

## Overview

卡组编辑 UI 实现卡牌管理相关界面：战利品三选一面板（combat-ui 结算后的卡牌奖励入口）、商店购买/出售/删卡界面、卡组浏览界面（筛选排序+卡牌详情）、超限弃牌界面（>30 张强制触发）。逻辑层（deck-editing-system）已 Complete——本 epic 是纯 UI 薄层，体量小（13 AC）。

**前置依赖**（PR-EPIC 2026-09-07 A3）：`design/ux/` 无 deck-editing-ui 的 UX 规范，且交互模式库缺口表列有卡组编辑网格、卡牌详情面板（高优先级）两个未定义模式。**story 创建前须先运行 `/ux-design deck-editing-ui`**——缺口明确（两个模式 + 11 个已入库模式可复用），预估 1-2 天设计工作量，已排入 Sprint 13 并行轨道。决策点：若 Sprint 14 开始时 UX 规范仍未完成，本 epic 整体推迟至 Sprint 15+，不阻塞其他表现层 epic（仅依赖 hud，不在关键路径上）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0031: 表现层架构基线 | 场景内 Control + 瞬态交互状态（筛选器/选中项）+ §6 模式库前置依赖 | HIGH（4.6 双焦点） |
| ADR-0023: 卡组编辑系统 | 四渠道统一入口、`Array[int]` 卡组存储、经济公式委托 ResourceSystem | LOW |

## GDD Requirements

TR 注册表暂无表现层条目——需求以 GDD 验收标准编号占位：

| AC 编号 | Requirement | ADR Coverage |
|-------|-------------|--------------|
| AC-deck-editing-ui-001~013 | deck-editing-ui-system.md §验收标准（13 条，含超限弃牌 >30 张触发） | ADR-0031 ✅ |

## Definition of Done

This epic is complete when:
- **UX 规范（`design/ux/deck-editing-ui.md`）已创建并通过 `/ux-review`**
- 卡组编辑网格、卡牌详情面板两个模式已入交互模式库
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/deck-editing-ui-system.md` are verified（13 条）
- 战利品三选一入口与 combat-ui-interaction 的结算流程对接正确
- All UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

1. 先运行 `/ux-design deck-editing-ui`（Sprint 13 并行轨道）
2. 然后运行 `/create-stories deck-editing-ui`

**排期提示**（PR-EPIC 2026-09-07）：Sprint 13 完成 UX 设计；Sprint 14/15 实现（视决策点）。
