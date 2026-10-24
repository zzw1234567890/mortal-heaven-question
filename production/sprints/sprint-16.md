# Sprint 16: 核心循环可演示第一跳 —— 身份选择 + 探索主体启动

> **Sprint**: 16
> **Start Date**: 2026-10-24
> **End Date**: 2026-11-02
> **Status**: Planned
> **Focus**: 身份选择 UI 场景落地（消除冒烟留桩）+ exploration-ui 002/003（地图选择 + 节点图数据接入）+ audio 004 过渡矩阵
> **Milestone**: presentation-layer-complete（范围仲裁已裁决：核心循环 MVP 两段式——见下方）
> **Review Mode**: full
> **Last Updated**: 2026-10-24

## Sprint Goal

打通核心循环可演示的第一跳：主菜单「新游戏」→ **身份选择**（消除 SCENE_PATHS 占位留桩）→ **地图选择** → **节点图数据接入**。这是里程碑范围仲裁裁决「核心循环 MVP」的开门段——全流程可演示链路（主菜单→身份→地图→节点图→战斗→结算→通关）的前三跳。音频过渡矩阵（audio 004）与 combat 顶部条/费用栏作为并行轨道，不阻塞核心循环链路。

## 范围仲裁（PR-SPRINT 2026-10-24）

里程碑「presentation-layer-complete」原完整范围 45 story ≈ 10-11 冲刺，经裁决**砍范围：核心循环 MVP 两段式**：
- **本段（Sprint 16-17）**：核心循环可演示——主菜单→身份选择→地图选择→节点图探索→战斗→结算→通关
- **降级/后置**：deck-editing-ui（0/7）、exploration-ui 后半（004-009 部分）、audio 后半（006-007）、combat-ui-interaction 全部（0/9，依赖 layout epic 完成）

## 容量

- 总天数：10 个日历日（2026-10-24 至 2026-11-02）
- 缓冲（20%）：1.5 天
- 可用：7.5 工作日
- 速度基准（Sprint 15 兑现校准）：**UI story = 2 日历日/story**；Logic/Integration = 1.0-1.5d
- MUST 利用率：5.5d / 7.5d = 73%（收敛——S16-4 降 should 后为身份选择 UX 不确定性与节点图数据接入集成风险留 2d 缓冲）

## 任务

### 必须完成（关键路径）—— 3 项（5.5d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S16-1 | 身份选择 UI 场景落地（含 SCENE_PATHS 串联） | `production/epics/identity-selection-system/`（UI story，新建） | UI（Logic 内核） | 2.0d | identity story 001-003 关闭（Day-1） | 6 身份卡 2×3 网格 + 底部详情面板 + 确认按钮 + 解锁遮罩；「新游戏」→身份选择导航打通（消除冒烟留桩）；SCENE_PATHS 目标场景落盘 |
| S16-2 | exploration-ui 002 地图选择界面 | `production/epics/exploration-ui/story-002-map-select-screen.md` | UI | 2.0d | S16-1（仅导航串联段） | 地图卡片横向滚动 + 重入确认弹窗；身份选择完成→地图选择导航串联 |
| S16-3 | exploration-ui 003 节点图数据接入与节点状态渲染 | `production/epics/exploration-ui/story-003-node-graph-data-states.md` | Integration | 1.5d | S16-2 | 节点图数据接入 GSM 存储 + 节点状态渲染；消费 001 基座 |

### 应该完成 —— 3 项（5.5d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S16-4 | audio 004 set_state 编排与过渡矩阵 | `production/epics/audio-manager/story-004-state-matrix.md` | Logic + Integration | 1.5d | audio 002/003 ✅ | 24 条 BGM 过渡矩阵 + SceneManager TRANSITION_AUDIO_PARAMS 对齐 + 两个既有单测同步更新；承接 S15-9 四项 S 建议 |
| S16-5 | combat-ui-layout 004 顶部条三组件 | `production/epics/combat-ui-layout/story-004-topbar-indicator-formation-log.md` | UI（Integration） | 2.0d | S15-3/4 ✅ | 阶段指示器 + 阵法区 + 战斗日志三组件渲染 |
| S16-6 | combat-ui-layout 005 费用栏与牌库/弃牌计数 | `production/epics/combat-ui-layout/story-005-cost-bar-deck-counters.md` | UI（Logic 内核） | 2.0d | S15-3/4 ✅ | 费用栏 + 牌库/弃牌计数 + 纯函数单测 |

### 可以完成 —— 3 项（2.0d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S16-7 | audio 005 暂停/静音/总线音量控制 | `production/epics/audio-manager/story-005-pause-mute-bus-control.md` | Logic + Integration | 0.5d | audio 004 | 暂停三态 + mute_state_changed 信号 + debounce 200ms |
| S16-8 | hud 008 静音图标 F1 | `production/epics/hud/story-008-mute-icon.md` | UI | 0.5d | S16-7 | F1 热键静音 + HUD 静音图标信号联动 |
| S16-9 | main-menu 005 语言切换 | `production/epics/main-menu/story-005-language-switch.md` | UI + Integration | 1.0d | main-menu 002/003 ✅ | 语言切换即时生效（locale 信号）+ 翻译管线 |

**总计**：9 项，预估 13.0d（必须 5.5d + 应该 5.5d + 可以 2.0d）——must 利用率 73%；should 为弹性层（Day-4 检查点丢弃顺序：combat 004 → combat 005 → audio 004）。

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 | 去向 |
|------|------|--------|------|
| 身份选择 UI 场景（冒烟留桩「新游戏无法开始」） | SCENE_PATHS 占位路径，identity 选择 epic Backlog | 2.0d | **本冲刺 must（S16-1）**——核心循环第一跳 |
| identity story 001-003 状态翻转 | 实现+测试已落盘，Status 卡 In Progress | 0（Day-1 关闭项） | S16-1 前置 |
| audio 004 set_state 编排 | S15-9 四项 S 建议挂账 | 1.5d | 本冲刺 should（S16-4） |
| exploration-ui 002-003 | 001 基座先行（Sprint 15 完成） | 3.5d | 本冲刺 must（S16-2/3） |
| combat-ui-layout 004-008 | 001-002 主体先行（Sprint 15 完成） | — | 本冲刺 should 004/005（S16-5/6），006-008 顺延 |
| R-02 组件级复测 | 真实组件 + D3D12 复测义务 | — | layout epic 004-008 完成后（Sprint 17） |
| R-05 复测义务 | exploration-ui 010 真实图标 + 揭雾动画复跑 | — | Sprint 17（exploration 主体完成后） |
| deck-editing-ui 001-007、combat-ui-interaction 001-009 | 范围仲裁砍后降级 | — | 核心循环 MVP 后段 |

## 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|---------|
| S16-1 无 UX 规格（GDD 仅标 UI 需求未跑 /ux-design） | 中 | 中 | DoD 锁定「按 GDD §用户界面需求实现」；focus/gamepad/a11y 三项显式 defer 登记；正式 UX 规格后续补 |
| must 串行链（S16-1→2→3）任一超时阻塞后续 | 中 | 高 | S16-2 地图选择本体与 S16-1 并行开工（仅导航串联段依赖）；S16-1 先落地「最小可点通版」尽早解除链头 |
| identity story 001-003 状态翻转超时 | 低 | 高 | Day-1 关闭项：测试全绿 + story-done 翻转；未完成则 S16-1 全程阻塞 |
| audio 004 回归（SceneManager 数值修正） | 中 | 中 | 同步更新两个既有单测，CI 连续两跑绿才闭环 |

## 外部因素依赖

- identity story 001-003 关闭需 GUT 全量测试通过（本地已可运行）
- 身份选择 UI 场景需 D3D12 窗口模式截图验证（沿用 main-menu/combat-ui 证据方法）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（3 项）
- [ ] 所有任务通过验收标准
- [ ] 「新游戏无法开始」冒烟留桩消除——identity_select 场景落盘 + SCENE_PATHS 串联
- [ ] 核心循环前三跳可演示：主菜单→身份选择→地图选择→节点图
- [ ] identity story 001-003 关闭（3 测试文件全绿 + story-done 翻转）
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过（`/smoke-check sprint`）
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] 零回归——2920 个既有测试全部通过

## PR-SPRINT 裁决记录（2026-10-24）

**REALISTIC WITH CONDITIONS**——must 3 项 5.5d / 7.5d = 73%（收敛于 S16-4 降 should）。三项监督条件：
1. **Day-4 检查点**（2026-10-27）：S16-1 场景未落地（identity_select.tscn + 6 卡 2×3 可点通）→ 按序丢 should（combat 004 → combat 005）；S16-1 + S16-2 双超 → S16-3 降 should，must 收敛至 4d
2. **identity 001-003 关闭闭环标准**：Day-1 关闭项——3 测试文件（templates/apply_identity/query）全绿 + story-done 翻转，未完成则 S16-1 全程阻塞
3. **audio 004 回归闭环标准**：SceneManager 数值修正同步更新 test_audio_transition_matrix.gd + test_transition_type.gd，CI 连续两跑绿才闭环
