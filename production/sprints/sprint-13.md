# Sprint 13: 表现层启动——双焦点 spike + HUD 系统

> **Sprint**: 13
> **Start Date**: 2026-09-08
> **End Date**: 2026-09-19
> **Status**: In Progress
> **Focus**: 关闭 R-01/R-06 红色风险 + HUD 系统 8 stories 全量交付
> **Milestone**: presentation-layer-complete
> **Review Mode**: full
> **Last Updated**: 2026-09-08（PR-SPRINT 裁决后写入）

## Sprint Goal

以 R-01 双焦点 spike 开闸，交付 HUD 系统（依赖枢纽）并关闭三个技术风险（R-01 双焦点/R-06 Ogg 循环/R-02 合批方案定型/R-03 D3D12 冒烟），为 Sprint 14 的 combat-ui + main-menu + audio 铺平道路。

## 容量

- 总天数：10 个日历日（2026-09-08 至 2026-09-19）
- 缓冲（20%）：2 天
- 可用：7.5-8 工作日
- 速度基准：1.0-1.4 story/天（注意：新实现 UI story 比拆分类 story 实际耗时高 30-50%——PR-SPRINT 2026-09-08）

## 任务

### 必须完成（关键路径）—— 7 项（6.0d）

| ID | 任务 | 文件/Spike | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|-----------|------|:--:|:--:|---------|
| S13-1 | R-01 双焦点 spike | `production/spikes/r01-dual-focus-spike.md`（待产出） | Spike | 0.5d | — | 目标硬件实测 `_gui_input()`/`_unhandled_input()` 响应差异、`grab_focus()` 对鼠标 hover 的影响；结论写入 OQ-02 关闭；双视觉策略确认或修正 |
| S13-2 | hud 001 CanvasLayer 挂载与可见性 | `production/epics/hud/story-001-hud-canvas-mount-and-visibility.md` | Integration | 1.5d | S13-1 | PersistentLayer+register_persistent 补齐；12 值可见性矩阵；PauseOverlay 豁免分支骨架；SceneManager 信号驱动（2026-09-08 GAP 裁决后） |
| S13-3 | hud 002 境界+修为条 | `production/epics/hud/story-002-realm-cultivation-bar.md` | UI+Logic | 1.0d | S13-2 | 阈值颜色切换纯函数单测+平滑填充动画+80% 呼吸闪烁 |
| S13-4 | hud 003 灵石+卡组计数 | `production/epics/hud/story-003-lingshi-deck-counter.md` | UI | 0.5d | S13-2 | 事件驱动更新+数值跳动动画+千分位格式化 |
| S13-5 | hud 004 通知系统 | `production/epics/hud/story-004-notification-system.md` | Logic | 1.0d | S13-2 | 队列/优先级/时长纯函数单测+堆叠上限 3 条+FIFO 丢弃 |
| S13-6 | hud 005 暂停菜单 | `production/epics/hud/story-005-pause-menu.md` | UI | 1.0d | S13-2 | PROCESS_MODE_ALWAYS 三态+确认对话框+键盘 Tab 顺序 |
| S13-7 | Sprint 13 QA 签收 | `production/epics/qa/story-001-sprint-13-qa.md`（待创建） | QA | 0.5d | 全部 | 2455 既有测试零回归+新增测试通过+UI 截图证据归档+冒烟检查 |

### 应该完成 —— 5 项（2.5d）

| ID | 任务 | 文件/Spike | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|-----------|------|:--:|:--:|---------|
| S13-8 | R-06 Ogg 循环间隙 spike | `production/spikes/r06-ogg-loop-spike.md`（待产出） | Spike | 0.5d | — | 目标硬件实测间隙时长；WAV/Ogg 格式裁决记录；R-06 风险关闭；audio 002 前置解锁 |
| S13-9 | hud 006 探索 HUD 右下信息组 | `production/epics/hud/story-006-exploration-hud-info.md` | UI | 0.5d | S13-3 | AP/地图名/层数事件驱动显示 |
| S13-10 | hud 007 场景切换过渡提示 | `production/epics/hud/story-007-scene-transition-hints.md` | UI | 0.5d | S13-2 | 过渡覆盖层按场景对显示文字+图标 |
| S13-11 | R-02 合批方案定型 | `production/epics/combat-ui-layout/story-009a-batching-scheme.md` | Visual/Feel | 0.5d | — | 图集结构/HP 条绘制/DC 分组方案文档化+原型实测 4 DC/位可行性——保护 Sprint 14 combat-ui 不被 R-02 阻塞 |
| S13-12 | R-03 D3D12 冒烟 | spike（待产出记录） | Spike | 0.5d | — | 目标硬件 D3D12 vs Vulkan 渲染对比冒烟+截图工具链验证；回退策略确认或排除 |

### 可以完成 —— 2 项（1.5d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|:--:|:--:|:--:|---------|
| S13-13 | hud 008 F1 静音图标 | `production/epics/hud/story-008-mute-icon.md` | UI | 0.5d | S13-5 | 图标状态切换+InputManager 联动 |
| S13-14 | audio 001 总线+骨架 PersistentLayer | `production/epics/audio-manager/story-001-bus-layout-manager-skeleton.md` | Integration | 1.0d | — | AudioBusLayout 资产+总线按名称访问+AudioServer 包装层可注入（无 UI 依赖，可并行） |

**总计**：14 项，预估 10.0d（必须 6.0d + 应该 2.5d + 可以 1.5d）——必须+应该 8.5d 恰在容量内（2026-09-08 调整：hud 001 扩 scope +0.5d——PersistentLayer/register_persistent 补齐，GAP-2 裁决；audio 001 同步受益）；可以项按实际进度弹性填充。

## 推迟到 Sprint 14（PR-SPRINT 裁决记录）

| 任务 | 原因 | 新预估 |
|------|------|--------|
| main-menu 001-005（5 stories） | 全量方案 230% 容量超载；main-menu 可平移且无跨 epic 阻塞 | 5.0d |
| audio 002-004（3 stories） | 同上；002 依赖 R-06 spike 结论（本冲刺 spike 先行） | 3.0d |
| combat-ui-layout 009b Draw Call 满场实测 | 依赖 009a 合批方案（本冲刺应该项）+ combat-ui stub 场景 | 0.5d |

> ⚠️ **Sprint 14 负载预警**（PR-SPRINT 2026-09-08）：Sprint 14 将承载 main-menu 5d + audio 3d + combat-ui-layout 开端——预估 12d+ 容量，届时需二次裁剪。里程碑「2-3 个冲刺」预估应在 Sprint 13 回顾时修正为「3 个冲刺起」。

## 上一个冲刺的结转项

无——Sprint 12（技术债务清理）已 Done 且 QA 签收 APPROVED（2026-09-05）。

## 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|---------|
| R-01 spike 结论不利（双焦点行为与 UX 规范假设不符） | 中 | 高 | spike 严格 timebox 0.5d、第 1 天执行、结论当日写入 OQ-02；若重大不利，本冲刺降级为「spike 报告+hud 001 骨架」，其余顺延——不让下游 story 带错误假设实现 |
| 新实现 UI story 耗时超预估（+30-50%） | 高 | 中 | 必须+应该 8.0d 预留了可以项弹性；hud 006/007 为可降级小 story |
| D3D12 冒烟发现渲染异常 | 低 | 高 | R-03 spike 含回退策略验证（`--rendering-driver vulkan`）；异常时记录 control-manifest |
| 合批方案原型实测不达标 | 中 | 中 | 009a 含备选路径（LOD/简化图标）；不达标则 Sprint 14 combat-ui 排期重估 |

## 外部因素依赖

- R-01/R-03/R-06 spike 均需目标硬件本地运行（headless 不可代表）——Windows 目标机可用
- 无美术资产依赖（HUD 用占位图形——图集规范在 combat-ui-layout 009a 定型）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（7 项）
- [ ] 所有任务通过验收标准
- [ ] R-01 双焦点 spike 结论写入 OQ-02 关闭（里程碑关口条件）
- [ ] R-06 Ogg spike 结论记录+格式裁决（audio 002 前置解锁）
- [ ] QA 计划已存在（`production/qa/qa-plan-sprint-13.md`——**实现开始前运行 /qa-plan sprint**）
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试（hud 002/004 Logic 内核+001/005 集成测试）
- [ ] 冒烟检查已通过（`/smoke-check sprint`）
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] 零回归——2455 个既有测试全部通过
