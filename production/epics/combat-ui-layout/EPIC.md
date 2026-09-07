# Epic: 战斗 UI——静态布局与角色状态卡

> **Layer**: Presentation
> **GDD**: design/gdd/combat-ui-system.md
> **Architecture Module**: 战斗 UI 系统（战场布局、手牌显示——`render_field()` / `show_hand()` / `highlight_targets()`）
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories combat-ui-layout`

## Overview

战斗 UI 静态侧实现：经典对峙布局（1920×1080，上敌下我）、顶部条（阶段指示器/阵法槽位）、16 角色位的角色状态卡（L0-L5 六层：头像背景/渐变遮罩/功法法宝图标竖排/HP-ATK 条/buff 境界角标/待命标记）、前后排区分（前排 100% 实线/后排 85% 虚线）以及结算面板框架。**本 epic 承载 R-02 Draw Call 关卡**——角色卡合批/图集方案在此定型并实测（16 角色满场 <200 Draw Call）。

拆分依据（PR-EPIC 2026-09-07 A1）：combat-ui-system.md 一份 GDD 拆为两个 epic（先例：systems-mapping 拆 input-manager + scene-manager）。本 epic 为静态布局侧；交互侧见 `combat-ui-interaction`。

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

## Next Step

Run `/create-stories combat-ui-layout` to break this epic into implementable stories.

**排期提示**（PR-EPIC 2026-09-07）：Sprint 14/15 进入——需 R-01 双焦点 spike、R-02 Draw Call 基准、hud 落地之后。
