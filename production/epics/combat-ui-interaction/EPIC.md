# Epic: 战斗 UI——手牌与交互流程

> **Layer**: Presentation
> **GDD**: design/gdd/combat-ui-system.md
> **Architecture Module**: 战斗 UI 系统（手牌显示、攻击目标选择——`show_hand()` / `highlight_targets()`）
> **Status**: Ready
> **Stories**: 9 stories — see below

## Overview

战斗 UI 交互侧实现：手牌交互（悬停放大/拖拽出牌/数字键 1-7 快捷/滚轮翻页）、攻击目标选择层（阶段 3：蓝色脉冲/红色高亮/箭头连线/点击与拖拽双模式）、三大面板的**交互流程**（备战面板的阵位拖拽与角色点选流转、战利品三选一的选中与确认流、撤退/渡劫确认的按钮流）以及 7 阶段的输入锁交互（弹窗冻结、暂停）。**本 epic 承载 R-01 双焦点行为关卡**——双焦点 spike（OQ-02）结论必须在此之前落地，焦点环/悬停双视觉策略按实测修正。

拆分依据（PR-EPIC 2026-09-07 A1）：与 `combat-ui-layout`（静态布局侧）共享一份 GDD。本 epic 为交互侧，依赖 layout epic 的布局框架。

**划界裁决（2026-09-07，QL-STORY-READY）**：备战/结算/撤退三大面板的**视觉框架+状态判定纯函数+信号驱动渲染归 layout epic**（含 0.5s 延迟/选中态/灰显/4 态判定）；**本 epic 负责输入锁栈+点击/拖拽流转+确认后的系统 API 调用与持久写入**（character_deployed/loot_selected/retreat_confirmed 等事件流）。创建本 epic story 时不得重复实现面板框架。

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 输入锁栈接入基座与 ESC 仲裁（基建 story） | Integration | Ready | ADR-0004, ADR-0031 |
| 002 | 手牌悬停预览与悬浮详情面板互斥 | UI（Logic 内核） | Ready | ADR-0031 |
| 003 | 鼠标拖拽出牌流转 | Integration | Ready | ADR-0004, ADR-0008 |
| 004 | 键盘快捷与手柄出牌路径 | Integration | Ready | ADR-0004 |
| 005 | 攻击目标选择交互（模式 A 点击式） | Integration | Ready | ADR-0008, ADR-0016 |
| 006 | 备战面板交互流（瞬态+一次性提交） | Integration | Ready | ADR-0016, ADR-0031 |
| 007 | 结算与撤退确认流（持久写入） | Integration | Ready | ADR-0031, ADR-0023 |
| 008 | 牌库/弃牌堆/日志面板交互 | UI | Ready | ADR-0031 |
| 009 | 峰值场景复测与拖拽 D3D12 烟雾（R-01/R-02 收口） | Visual/Feel | Ready | ADR-0031 |

**QL-STORY-READY 裁决落地（2026-09-07）**：12 项 BLOCKING 全部裁决——结束出牌按钮（layout 005 补渲染位）、备战瞬态+一次性提交+替换二次选择（B3/B4/B5）、数字键需目标卡子流程+>7 张窗口映射（B8）、ESC 仲裁归 001（B9）、story 001 收窄为基建基座（B10）、撤退 GAMEPLAY 排队（B11）、MOUSE_FILTER_STOP 统一（B1）、loot_skipped 补 GDD AC（B12）、战斗日志交互并入 008（B6）、键盘/手柄路径补入 005/006（B7）。GDD 边界澄清补充二（9 条）已写入。

## Next Step

Run `/story-readiness production/epics/combat-ui-interaction/story-001-input-lock-base.md` then `/dev-story` 开始实现（前置：R-01 双焦点 spike）。
