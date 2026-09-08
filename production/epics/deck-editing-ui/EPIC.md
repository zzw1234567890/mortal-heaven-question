# Epic: 卡组编辑 UI

> **Layer**: Presentation
> **GDD**: design/gdd/deck-editing-ui-system.md
> **Architecture Module**: 卡组编辑 UI（卡组编辑界面——`render_deck()` / `show_collection()`）
> **Status**: Ready
> **Stories**: 7 stories — 见下表

## Overview

卡组编辑 UI 实现卡牌管理相关界面：商店购买/出售/删卡界面（坊市三标签页）、卡组浏览界面（双维度筛选+排序+历史标签）、超限弃牌界面（仅事件结算触发——2026-09-08 B5 裁决）。逻辑层（deck-editing-system）已 Complete——本 epic 是纯 UI 薄层。

**前置依赖已满足**（2026-09-08）：`design/ux/deck-editing-ui.md` 已创建并通过 `/ux-review`（20 AC，Approved）；商品卡/散功选择网格/超限弃牌网格 3 模式已入交互模式库；卡牌详情面板在缺口表（story 002 交付时入库——sprint 前置项）。

**2026-09-08 create-stories QL-STORY-READY 裁决落地**（8 BLOCKING 全裁决）：
- **B1**：出售价 = 拆解基准价 × 0.5（终裁——×0.8 与「100% 拆解」两旧版废弃；机制 GDD/ADR-0023/UI GDD 三处同步）
- **B2/B3a**：UI 直调分域 API（库存归 ExplorationSystem；execute_purchase/execute_sell_batch 编排归 DeckEditingSystem）；UX 规范「意图信号」修正为通知性 Cat 2b 信号
- **B4**：四处确定性逻辑提取纯函数+`tests/unit/deck_editing_ui/` BLOCKING 单测（灰态判定/选择约束/筛选排序/超限多选状态机——hud story-002 先例）
- **B5**：超限弃牌仅事件入口（战利品不可能超限——GDD 边界情况已记录）
- **B6**：卡组浏览补稀有度筛选维度（类型 7×稀有度 6 双维度）
- **B7**：系统 API 缺口 stub+上报+真实接线后复验（execute_purchase/execute_sell_batch/get_sell_total/handle_overflow/库存查询）
- **B8**：exploration-ui story 009 缩窄为探索侧入口，卡组浏览界面本体归本 epic story 005

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
- **UX 规范（`design/ux/deck-editing-ui.md`）已创建并通过 `/ux-review`** ✅（2026-09-08 Approved）
- 卡牌详情面板模式入交互模式库（story 002 交付时——ADR-0031 §6 前置项）；商品卡/散功选择网格/超限弃牌网格 ✅ 已入库
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/deck-editing-ui-system.md` are verified（**本域 9 条**——13 条中 4 条战利品 AC 归 combat-ui，2026-09-05 边界澄清）
- 战利品三选一入口与 combat-ui-interaction 的结算流程对接正确（story 007 待验项——combat 侧实现后补验）
- All UI stories have evidence docs with sign-off in `production/qa/evidence/`
- 四个 Logic 内核纯函数单测（tests/unit/deck_editing_ui/）全部通过（B4 裁决）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 坊市 overlay 基建与三标签页导航 | UI | Ready | ADR-0031 |
| 002 | 卡牌详情浮窗（跨界面复用组件） | UI | Ready | ADR-0031 |
| 003 | 买卡标签页——商品网格与购买流 | UI+Logic | Ready | ADR-0031/0023/0014 |
| 004 | 散功与售卡标签页 | UI+Logic | Ready | ADR-0031/0023 |
| 005 | 卡组浏览界面（只读+稀有度筛选+历史标签） | UI+Logic | Ready | ADR-0031/0023 |
| 006 | 超限弃牌界面 | UI+Logic | Ready | ADR-0031/0023 |
| 007 | 终验——三界面闭环+分辨率双输入 | UI | Ready | ADR-0031 |

## Next Step

`/story-readiness production/epics/deck-editing-ui/story-001-shop-overlay-foundation.md` → `/dev-story`

**排期提示**（PR-EPIC 2026-09-07）：Sprint 14/15 实现。**依赖上报清单**（Feature 层跟进）：execute_purchase / execute_sell_batch（原子批量）/ get_sell_total / handle_overflow / 库存查询与标记已售 / 刷新商店编排。
