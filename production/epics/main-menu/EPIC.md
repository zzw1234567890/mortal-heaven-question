# Epic: 主菜单与设置

> **Layer**: Presentation
> **GDD**: design/gdd/main-menu-system.md
> **Architecture Module**: 主菜单与设置（菜单层次、设置持久化——`show_menu()` / `load_save_list()` / `save_settings()`）
> **Status**: Ready
> **Stories**: 5 stories — see below

## Overview

主菜单与设置实现游戏启动入口（新游戏/继续游戏/设置/退出）与全局配置管理（音量、画面、按键绑定、语言等）。设置值按 ADR-0031 §2.1 属「持久设置」——主菜单系统的设置面板直接写设置文件，不经 GSM 存档链。主菜单是玩家对游戏的「第一印象」，无技术风险、无 UX 规范缺口。

**边界澄清落地（2026-09-07，QL-STORY-READY）**：音量实时生效+手动持久化（未保存关闭回滚）；全局「恢复默认」按钮（story 003）；720p 为支持下限（AC-21 保留）；分辨率枚举 API 实现前查证（story 003 前置）；语言刷新用 locale 信号（story 005）；等待输入 ESC=取消（story 004）；键位启动加载并入 story 004。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0031: 表现层架构基线 | 场景内 Control + 状态三分类（设置=持久设置直写文件）+ 双焦点双视觉 | HIGH（4.6 双焦点） |
| ADR-0002: 存档/读档迁移链 | 继续游戏读档入口 | LOW |
| ADR-0005: 场景管理器 | 主菜单→地图选择的场景切换编排 | LOW |

## GDD Requirements

TR 注册表暂无表现层条目——需求以 GDD 验收标准编号占位：

| AC 编号 | Requirement | ADR Coverage |
|-------|-------------|--------------|
| AC-main-menu-001~022 | main-menu-system.md §验收标准（22 条，含 dB 音量公式、存档槽、按键重绑定） | ADR-0031 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 主菜单场景与按钮组（含制作人员） | UI（Integration 核心） | Ready | ADR-0031 |
| 002 | 设置面板框架与音量控制 | UI（Logic 内核） | Ready | ADR-0031 |
| 003 | 画面设置与应用/回退（含全局恢复默认） | UI（Logic 内核） | Ready | ADR-0031 |
| 004 | 按键绑定界面（含启动加载） | UI（Logic 内核） | Ready | ADR-0031 |
| 005 | 语言切换与本地化即时生效 | UI + Integration | Ready | ADR-0031 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/main-menu-system.md` are verified（22 条，含性能 AC）
- All Logic and Integration stories have passing test files in `tests/`
- All UI stories have evidence docs with sign-off in `production/qa/evidence/`
- 设置变更即时生效并持久化（重启后保留）——AC 含此验证

## Next Step

Run `/create-stories main-menu` to break this epic into implementable stories.

**排期提示**（PR-EPIC 2026-09-07）：Sprint 13 必须完成——无依赖低风险，与 hud 并行推进。
