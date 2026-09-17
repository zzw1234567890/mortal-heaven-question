# Sprint 14: 主菜单 + R-02 关闭——表现层关键路径推进

> **Sprint**: 14
> **Start Date**: 2026-09-21
> **End Date**: 2026-10-02
> **Status**: In Progress
> **Focus**: main-menu 001-003 + R-02 Draw Call 关闭（stub 版）+ CI 回归网 + audio 骨架
> **Milestone**: presentation-layer-complete（预估修正：3 个冲刺起——见里程碑预估修正节）
> **Review Mode**: full
> **Last Updated**: 2026-09-13（PR-SPRINT REALISTIC 裁决后写入）

## Sprint Goal

交付主菜单前三个 story（全流程可演示关键路径开局）、关闭 R-02 红色风险（stub 版实测，复测义务登记）、配置 CI 回归网（QA 签收条件 B 兑现）、落成 audio-manager 骨架——Sprint 15 承载 exploration-ui + combat-ui 主体前，先把「菜单可达 + 性能基线 + 回归网」三块地基打好。

## 容量

- 总天数：10 个日历日（2026-09-21 至 2026-10-02）
- 缓冲（20%）：1.5 天
- 可用：7.5 工作日
- 速度基准：1.0-1.4 story/天；UI story +30-50% 校准已计入预估（Sprint 13 实证偏差 <20%）
- MUST 利用率：6.0d / 7.5d = 80%（符合 20% 缓冲协议）

## 任务

### 必须完成（关键路径）—— 8 项（6.0d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S14-1 | CI 配置（GitHub Actions + GUT headless） | `.github/workflows/tests.yml`（待产出） | 工具 | 0.5d | — | push/PR 触发全量测试（2598+）零失败即绿；Godot headless runner 镜像选定；坏测试即红（CI/CD 规则：测试是阻塞关卡）。超 1.0d 膨胀则拆分：runner 冒烟先行、覆盖率报告后补（PR-SPRINT 监督条件 #2） |
| S14-2 | main-menu 001 主菜单场景与按钮组 | `production/epics/main-menu/story-001-main-menu-scene.md` | UI | 1.0d | R-01 ✅ | 7 AC——场景+按钮组+制作人员界面；双焦点策略（R-01 结论）落地 |
| S14-3 | main-menu 002 设置面板框架与音量控制 | `production/epics/main-menu/story-002-settings-audio.md` | UI | 1.0d | S14-2 | 5 AC——面板框架+音量滑条实时生效+手动持久化（未保存关闭回滚） |
| S14-4 | main-menu 003 画面设置与应用/回退 | `production/epics/main-menu/story-003-settings-graphics.md` | UI | 1.0d | S14-3 | 6 AC——分辨率枚举（API 查证前置）+应用/回退机制+全局恢复默认+720p 支持下限 |
| S14-5 | combat-ui-layout 009a 合批方案定型 | `production/epics/combat-ui-layout/story-009a-batching-scheme.md` | Visual/Feel | 0.5d | — | 7 AC——图集结构/HP 条绘制/DC 分组方案文档化+原型实测可行性（Sprint 13 结转 S13-11） |
| S14-6 | combat-ui-layout 009b R-02 Draw Call 满场实测（stub 版） | `production/epics/combat-ui-layout/story-009b-drawcall-benchmark.md` | Visual/Feel | 0.5d | S14-5 | 7 AC——标准场景（16 位满+7 手牌+2 阵法）DC ≤200；峰值场景 stub 版 DC ≤200；帧时间人工签批。**QL-STORY-READY 2026-09-07 stub 裁决**：峰值场景占位 stub 先行；**R-02 只能有条件关闭（provisional）——interaction 完成后复测通过才正式关闭，复测义务登记到 combat-ui-interaction epic（PR-SPRINT 监督条件 #3）** |
| S14-7 | audio-manager 001 总线+AudioManager 骨架 | `production/epics/audio-manager/story-001-bus-layout-manager-skeleton.md` | Integration | 1.0d | — | 5 AC——AudioBusLayout 资产+总线按名称访问+AudioServer 包装可注入（Sprint 13 结转 S14-14；R-06 结论落地：Ogg loop=true 即无缝，BGM 维持 WAV MVP） |
| S14-8 | Sprint 14 QA 签收 | `production/epics/qa/story-001-sprint-14-qa.md`（待创建） | QA | 0.5d | 全部 | 2598+ 既有测试零回归+新增测试通过+视觉证据归档+冒烟检查+CI 工作流验证 |

### 应该完成 —— 4 项（3.0d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S14-9 | TD-007/012 测试缺口 + test_ac010 flaky 根治（打包） | `docs/tech-debt-register.md`（追踪） | 测试 | 1.0d | — | TD-007 realm_bar 信号接线四路径覆盖+TD-012 超限态集成断言（font_color==#B3424A+overlimit visible）+test_ac010 GSM 信号时序隔离——技术总监关卡条件兑现 |
| S14-10 | main-menu 004 按键绑定界面 | `production/epics/main-menu/story-004-keybind-remapping.md` | UI | 1.0d | S14-3 | 含启动加载；等待输入 ESC=取消 |
| S14-11 | hud 006 探索 HUD 右下信息组 | `production/epics/hud/story-006-exploration-hud-info.md` | UI | 0.5d | S13-3 ✅ | AP/地图名/层数事件驱动显示（Sprint 13 结转） |
| S14-12 | hud 007 场景切换过渡提示 | `production/epics/hud/story-007-scene-transition-hints.md` | UI | 0.5d | S13-2 ✅ | 过渡覆盖层按场景对显示文字+图标（Sprint 13 结转） |

### 可以完成 —— 2 项（1.5d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S14-13 | main-menu 005 语言切换 | `production/epics/main-menu/story-005-language-switch.md` | UI | 1.0d | S14-3 | locale 信号即时刷新 |
| S14-14 | hud 008 F1 静音图标 | `production/epics/hud/story-008-mute-icon.md` | UI | 0.5d | S13-5 ✅ | 图标状态切换+InputManager 联动（Sprint 13 结转） |

**总计**：14 项，预估 10.5d（必须 6.0d + 应该 3.0d + 可以 1.5d）——must 利用率 80%；should 为弹性层（Day-4 检查点丢弃顺序：main-menu 004 → hud 006/007）。

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 | 去向 |
|------|------|--------|------|
| hud 006/007/008（S13-9/10/13） | must 优先 + 验收链耗时 | 0.5d × 3 | 本冲刺 should/nice |
| R-02 合批定型 009a（S13-11） | 同上 | 0.5d | 本冲刺 must（R-02 关闭前置） |
| audio 001 骨架（S13-14） | 同上 | 1.0d | 本冲刺 must（audio 链解锁前置） |
| main-menu 001-005 | Sprint 13 计划期 PR-SPRINT 推迟（230% 超载） | 5.0d | 本冲刺 must 001-003 + should 004 + nice 005 |
| audio 002-004 | 同上 | 3.0d | Sprint 15 |
| exploration-ui 全 epic（10 stories） | 容量裁剪（R-05 触发条件未至——节点图渲染未实现） | — | Sprint 15（001 基准 story 排首位——里程碑文档要求） |
| combat-ui-layout 001-008 | 依赖 009a 方案定型 | — | Sprint 15 |

## 里程碑预估修正（PR-PHASE-GATE + PR-SPRINT 共识）

- 原预估「2-3 个冲刺」→ **「3 个冲刺起」**：Sprint 13（HUD 枢纽，已完成）→ Sprint 14（菜单+地基，本计划）→ Sprint 15（exploration + combat-ui 主体 + audio 002-004）→ Sprint 16 收尾（deck-editing-ui + 全流程演示 + R-02 复测）
- **Sprint 15 结转负载预警**（PR-SPRINT 2026-09-17）：exploration 全 epic + combat-ui 001-008 + audio 002-004 ≈ 12d+——Sprint 15 的 PR-SPRINT 必然再次裁剪，建议届时将 combat-ui-interaction 部分推入 Sprint 16
- 里程碑文件下次更新时正式写入

## 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|---------|
| main-menu 001-003 耗时超预估（UI +30-50%） | 高 | 中 | Day-4 检查点（2026-09-26）：main-menu 002 未完成即按序丢 should（main-menu 004 → hud 006/007）保 must（PR-SPRINT 监督条件 #1） |
| CI 首次搭建膨胀（headless runner 环境问题） | 中 | 高 | 0.5d timebox——超 1.0d 拆分：runner 冒烟先行、覆盖率报告后补（PR-SPRINT 监督条件 #2）；CI 是 QA 条件 B 兑现不可砍 |
| 009b stub 实测不达标（DC >200） | 中 | 中 | 009a 含备选路径（LOD/简化图标）；不达标则 combat-ui 001-008 实现时降级方案启动，R-02 维持开放 |
| 009b stub 代表性不足（真实纹理切换成本未覆盖） | 中 | 中 | R-02 只能有条件关闭（provisional）；复测义务登记到 combat-ui-interaction epic 关口（PR-SPRINT 监督条件 #3） |
| R-05 晚关（exploration-ui 归 Sprint 15） | 低 | 中 | 触发条件未至（节点图渲染未实现）；009a 合批方案与节点图渲染同源，本冲刺实际做了部分前置去风险 |

## 外部因素依赖

- 009b 实测需目标硬件窗口模式运行（D3D12）——Windows 目标机可用
- CI 需 GitHub Actions + Godot headless runner（自托管或容器镜像——S14-1 内选定）
- main-menu 003 分辨率枚举 API 需实现前查证（story 内已标注前置，Godot 4.6 DisplayServer API）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（8 项）
- [ ] 所有任务通过验收标准
- [ ] CI 工作流上线且全量测试绿（QA 条件 B 兑现）
- [ ] R-02 有条件关闭（stub 实测 DC ≤200 达标 + 复测义务登记）
- [ ] main-menu 可从启动到达设置面板（全流程可演示的第一段）
- [ ] audio 骨架落成（audio 002-004 解锁）
- [ ] QA 计划已存在（**实现开始前运行 /qa-plan sprint**）
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过（`/smoke-check sprint`）
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] 零回归——2598 个既有测试全部通过

## PR-SPRINT 裁决记录（2026-09-13）

**REALISTIC**——MUST 容量匹配（80% 利用率 + Sprint 13 同构先例支撑）；009b stub 先行有已裁决决策路径；里程碑预估修正诚实反映现实。三项监督条件：
1. **Day-4 检查点**（2026-09-26）：main-menu 002 未完成 → 按序丢 should
2. **CI 0.5d timebox**：超限拆分 runner 冒烟先行
3. **R-02 provisional 关闭**：复测义务登记到 combat-ui-interaction epic
