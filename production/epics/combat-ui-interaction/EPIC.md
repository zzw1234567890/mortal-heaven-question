# Epic: 战斗 UI——手牌与交互流程

> **Layer**: Presentation
> **GDD**: design/gdd/combat-ui-system.md
> **Architecture Module**: 战斗 UI 系统（手牌显示、攻击目标选择——`show_hand()` / `highlight_targets()`）
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories combat-ui-interaction`

## Overview

战斗 UI 交互侧实现：手牌弧形区（悬停放大/拖拽出牌/数字键 1-7 快捷）、攻击目标选择层（阶段 3：蓝色脉冲/红色高亮/箭头连线）、备战面板（阶段 0：角色选择+阵位拖拽）、战利品三选一网格、撤退/渡劫确认弹窗以及 7 阶段的输入锁交互（弹窗冻结、暂停）。**本 epic 承载 R-01 双焦点行为关卡**——双焦点 spike（OQ-02）结论必须在此之前落地，焦点环/悬停双视觉策略按实测修正。

拆分依据（PR-EPIC 2026-09-07 A1）：与 `combat-ui-layout`（静态布局侧）共享一份 GDD。本 epic 为交互侧，依赖 layout epic 的布局框架。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0031: 表现层架构基线 | 双焦点双视觉策略 + 输入锁栈判定 `is_input_allowed()` + 瞬态交互状态（拖拽中间态） | HIGH（4.6 双焦点——R-01 spike 前置） |
| ADR-0004: 输入管理器 | 四级锁栈 + 设备类型判定；路径 B（`_input()` 拦截） | HIGH |
| ADR-0009: 卡牌效果引擎 | 出牌→`card_played` 事件流 | LOW |
| ADR-0016: 上场阵位系统 | 备战面板阵位规则（6 固定阵位、待命规则） | LOW |

## GDD Requirements

TR 注册表暂无表现层条目——需求以 GDD 验收标准编号占位：

| AC 编号 | Requirement | ADR Coverage |
|-------|-------------|--------------|
| AC-combat-ui-交互侧 | combat-ui-system.md §验收标准中手牌/出牌/目标选择/备战/战利品/弹窗相关（约 33-38 条） | ADR-0031 ✅ |
| AC-combat-ui-ux | design/ux/combat-ui.md（APPROVED）交互地图、状态与变体（15 状态）、18 事件 | ADR-0031 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- 交互侧 AC 全部验证：拖拽出牌、键盘快捷、目标选择三输入路径（鼠标/键盘/手柄）、备战流程、战利品三选一
- **R-01 关卡：双焦点 spike（OQ-02）完成且双视觉策略按实测修正或确认**
- 纯键盘与手柄路径全覆盖（combat-ui.md 无障碍章节）
- All UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories combat-ui-interaction` to break this epic into implementable stories.

**排期提示**（PR-EPIC 2026-09-07）：Sprint 14/15 进入——依赖 combat-ui-layout 布局框架 + R-01 spike 结论。
