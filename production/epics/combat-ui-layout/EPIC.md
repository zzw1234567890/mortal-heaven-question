# Epic: 战斗 UI——静态布局与角色状态卡

> **Layer**: Presentation
> **GDD**: design/gdd/combat-ui-system.md
> **Architecture Module**: 战斗 UI 系统（战场布局、手牌显示——`render_field()` / `show_hand()` / `highlight_targets()`）
> **Status**: Ready
> **Stories**: 10 stories — see below

## Overview

战斗 UI 静态侧实现：经典对峙布局（1920×1080，上敌下我）、顶部条（阶段指示器/阵法区）、16 角色位的角色状态卡（L0-L5 六层：头像背景/渐变遮罩/功法法宝图标竖排/HP-ATK 条/buff 境界角标/待命标记）、前后排区分（前排 100% 实线/后排 85% 虚线）以及结算/备战/撤退面板的视觉框架与状态判定。**本 epic 承载 R-02 Draw Call 关卡**——角色卡合批/图集方案在此定型（009a 前置）并满场实测（009b 关口）。

拆分依据（PR-EPIC 2026-09-07 A1）：combat-ui-system.md 一份 GDD 拆为两个 epic（先例：systems-mapping 拆 input-manager + scene-manager）。本 epic 为静态布局侧；交互侧见 `combat-ui-interaction`。

**划界裁决（2026-09-07，QL-STORY-READY）**：备战/结算/撤退三大面板的视觉框架+状态判定纯函数+信号驱动渲染归本 epic；输入锁栈+点击拖拽流转+确认后系统 API 调用归 interaction（其 EPIC.md 已同步修订）。阶段 0 指示器名=「准备」；渡劫 warning 在备战界面弹出；>7 张手牌=间距优先+角度自适应；飘字归 003/敌方手牌背面区归 006/进场动画归 001/费用动画归 005；共享纯函数模块（font_size_responsive 等）在 001 建立。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0031: 表现层架构基线 | 场景内 Control + 零状态所有权 + 图集合批渲染预算 | HIGH（4.6 双焦点） |
| ADR-0008: 七阶段战斗状态机 | 阶段指示器数据源 | LOW |
| ADR-0013: 绑定系统 | 角色卡功法/法宝图标数据（`get_binding_ids_by_character()` 零分配查询） | LOW |

## GDD Requirements

TR 注册表暂无表现层条目——需求以 GDD 验收标准编号占位：

| AC 编号 | Requirement | ADR Coverage |
|-------|-------------|--------------|
| AC-combat-ui-布局侧 | combat-ui-system.md §验收标准中静态布局/角色卡/结算面板相关（约 35-40 条） | ADR-0031 ✅ |
| AC-combat-ui-ux | design/ux/combat-ui.md（APPROVED）布局规格、角色状态卡 L0-L5 分层表、1920×1080 基准 | ADR-0031 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- 布局侧 AC 全部验证：16 角色位渲染、前后排区分、阶段指示器显示、结算面板框架
- **R-02 关卡：战斗满场（16 角色卡+手牌+顶部条+HUD 元素）实测 Draw Call <200 且 60fps**
- All UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 战场四区域布局骨架与共享纯函数模块 | Integration | Ready | ADR-0031 |
| 002 | 角色状态卡 L0-L5 六层渲染 | UI（Logic 内核） | Ready | ADR-0031 |
| 003 | 状态标记切换、阵亡处理与飘字 | UI（Integration） | Ready | ADR-0031 |
| 004 | 顶部条三组件（阶段指示器/阵法区/战斗日志） | UI（Integration） | Ready | ADR-0031, ADR-0008 |
| 005 | 费用栏与牌库/弃牌计数 | UI（Logic 内核） | Ready | ADR-0031 |
| 006 | 手牌区弧形渲染与静态状态 | UI（Logic 内核） | Ready | ADR-0031 |
| 007 | 备战面板（视觉框架与状态判定） | UI（Logic 内核） | Ready | ADR-0031 |
| 008 | 结算与撤退面板框架（视觉与状态判定） | UI（Logic 内核） | Ready | ADR-0031 |
| 009a | R-02 合批方案定型（前置架构 spike） | Visual/Feel | Ready | ADR-0031 |
| 009b | R-02 Draw Call 满场实测关口 | Visual/Feel | Ready | ADR-0031 |

**实现顺序提示**：009a 排在 002 之前（合批方案定型后 002-006 按规范实现，避免独立纹理返工）；001 最先（建立共享纯函数模块与 `tests/unit/combat_ui/` 目录）；009b 在 001-008 全部完成后执行。

## Next Step

Run `/story-readiness production/epics/combat-ui-layout/story-009a-batching-scheme.md` then `/dev-story` 开始实现。
