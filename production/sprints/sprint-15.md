# Sprint 15: R-05 关闭 + combat-ui 布局主体启动 + 技术债务根治

> **Sprint**: 15
> **Start Date**: 2026-10-13
> **End Date**: 2026-10-23
> **Status**: In Progress
> **Focus**: exploration-ui 001（R-05 红色风险关闭）+ combat-ui-layout 001-002（布局主体启动）+ TD-014 flaky 根治（QA 条件 A 兑现）
> **Milestone**: presentation-layer-complete（预估修正：5 个冲刺起——见里程碑预估修正节）
> **Review Mode**: full
> **Last Updated**: 2026-10-13

## Sprint Goal

关闭 R-05 红色风险（节点图基准 story——里程碑三红风险最后一关的前置）、启动 combat-ui-layout 主体（001 骨架 + 002 角色卡，是 R-02 组件级复测的核心单元）、兑现 QA 条件 A（TD-014 flaky + TD-007/012 测试缺口——连续第三冲刺结转，本冲刺必须根治）。三项地基为表现层剩余 epic 的主体交付铺路。

## 容量

- 总天数：10 个日历日（2026-10-13 至 2026-10-23）
- 缓冲（20%）：1.5 天
- 可用：7.5 工作日
- 速度基准（Sprint 14 实证校准——回顾行动项 #1）：**UI story = 2 日历日/story**（非 1.0d，Sprint 14 连续两冲刺低估的教训）；spike/集成/Logic = 1.0-1.5d
- MUST 利用率：7.0d / 7.5d = 93%（偏高——Day-4 检查点裁剪决策强制执行，见风险节）

## 任务

### 必须完成（关键路径）—— 4 项（7.0d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S15-1 | TD-014 flaky 根治 + TD-007/012 测试缺口（打包） | `docs/tech-debt-register.md`（追踪） | Logic/测试 | 1.0d | — | TD-007 realm_bar 信号接线四路径覆盖 + TD-012 超限态集成断言（font_color==#B3424A + overlimit visible）+ test_ac010 GSM 信号时序隔离——QA 条件 A 兑现（连续第三冲刺结转，本冲刺必须根治） |
| S15-2 | exploration-ui 001 节点图渲染基座与 R-05 性能基准 | `production/epics/exploration-ui/story-001-node-graph-base-r05-benchmark.md` | Visual/Feel（性能关卡） | 2.0d | — | 6 AC——stub 最坏情况节点图（6 层×4 节点+连线+迷雾+10 类图标）渲染基座；滚轮缩放 50%-150%+平移+复位；最坏缩放平移 p95 ≤16.6ms；DC ≤200 基准值；优化路径验证（图集/LOD 至少一项）；迷雾合批渲染。**R-05 红色风险关闭前置（里程碑三红风险）** |
| S15-3 | combat-ui-layout 001 战场四区域骨架与共享纯函数模块 | `production/epics/combat-ui-layout/story-001-battlefield-layout-skeleton.md` | UI（含 Integration） | 2.0d | R-01 ✅, 009a ✅, hud 001 ✅ | 建立四区域布局骨架（顶部条/战场/底部条/面板）+ 共享纯函数模块（font_size_responsive——落地 720p ≥12pt 规范）+ `tests/unit/combat_ui/` 目录。解锁 layout epic 全部下游 story |
| S15-4 | combat-ui-layout 002 角色状态卡 L0-L5 六层渲染 | `production/epics/combat-ui-layout/story-002-character-status-card.md` | UI（Logic 内核） | 2.0d | S15-3 | 消费 009a 合批方案实现 L0-L5 六层（头像背景/渐变遮罩/功法法宝图标竖排/HP-ATK 条/buff 境界角标/待命标记）+ 前后排区分（前排实线/后排虚线）；R-02 组件级复测核心单元 |

### 应该完成 —— 3 项（4.0d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S15-5 | audio 002 BGM 双播放器交叉淡化 | `production/epics/audio-manager/story-002-bgm-crossfade.md` | Logic | 1.0d | audio 001 ✅, R-06 ✅ | 双 AudioStreamPlayer 交叉淡化原语 + 单测；解锁 audio 004 set_state |
| S15-6 | combat-ui-layout 003 状态标记切换、阵亡处理与飘字 | `production/epics/combat-ui-layout/story-003-state-markers-death-floaters.md` | UI（Integration 核心） | 2.0d | S15-4 | 状态标记消费角色卡接口 + 阵亡处理 + 飘字；解锁 008 全灭信号 |
| S15-7 | main-menu 004 按键绑定界面（含启动加载） | `production/epics/main-menu/story-004-keybind-remapping.md` | UI（Logic 内核） | 1.0d | S14-3 ✅, S14-4 ✅ | 按键绑定界面 + 启动加载 + ESC=取消 |

### 可以完成 —— 2 项（1.5d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| S15-8 | hud 006 探索 HUD 右下信息组 | `production/epics/hud/story-006-exploration-hud-info.md` | UI | 0.5d | S13-3 ✅ | AP/地图名/层数事件驱动显示（Sprint 13 结转） |
| S15-9 | audio 003 SFX 池——16 节点池与淘汰/冷却/随机化 | `production/epics/audio-manager/story-003-sfx-pool.md` | Logic | 1.0d | audio 001 ✅ | 16 节点池 + 淘汰/冷却/随机化纯函数单测 |

**总计**：9 项，预估 12.5d（必须 7.0d + 应该 4.0d + 可以 1.5d）——must 利用率 93%；should 为弹性层（Day-4 检查点丢弃顺序：main-menu 004 → combat-ui 003 → audio 002）。

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 | 去向 |
|------|------|--------|------|
| TD-014 flaky + TD-007/012（S14-9） | must 优先 + 连续第三冲刺 | 1.0d | **本冲刺 must（S15-1）**——QA 条件 A 兑现，不能再拖 |
| exploration-ui 001-010 | R-05 触发条件未至（Sprint 14 前）；容量裁剪 | — | 本冲刺 must 001（S15-2，R-05 基准）+ 002-010 顺延 |
| combat-ui-layout 001-008 | 依赖 009a（Sprint 14 已解除） | — | 本冲刺 must 001-002（S15-3/4）+ 003-008 顺延 |
| audio 002-004 | 依赖 001 骨架（Sprint 14 已解除） | 3.0d | 本冲刺 should 002（S15-5）+ nice 003（S15-9）+ 004 顺延 |
| main-menu 004/005、hud 006/007/008 | Sprint 13/14 must 优先 | — | 本冲刺 should 004（S15-7）+ nice 006（S15-8）+ 其余顺延 |
| combat-ui-interaction 001-009 | 依赖 layout epic 完成 | — | Sprint 16（R-01/R-02 复测关口） |
| deck-editing-ui 001-007 | UX 规范已批准（2026-09-08），实现顺延 | — | Sprint 16 收尾 |

## 里程碑预估修正（PR-SPRINT 实证校准）

- Sprint 14 计划期预估「3 个冲刺起」（Sprint 13/14/15/16），回顾实证 UI story 真实成本 2 日历日/story 后，里程碑预估修正为 **「5 个冲刺起」**：Sprint 13（HUD 枢纽 ✅）→ Sprint 14（菜单+地基 ✅）→ Sprint 15（R-05 关闭 + layout 启动 + TD 根治，本计划）→ Sprint 16（layout 主体 003-008 + exploration 002-010 + audio 004）→ Sprint 17 收尾（interaction epic + deck-editing-ui + 全流程演示 + R-02/R-05 复测）。
- **剩余负载诚实评估**：presentation 层剩余 8 story（layout）+ 9（interaction）+ 10（exploration）+ 6（audio）+ 2（main-menu）+ 3（hud）+ 7（deck-editing）= 45 stories。按 UI 2d / Logic-Integration 1-1.5d 加权，剩余 ≈ 70-80 工作日 → 10-11 个冲刺。里程碑「3 个冲刺」为严重低估，正式修正为「5+ 个冲刺」，里程碑文件下次更新时写入。

## 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|---------|
| R-05 基准不过关（节点图最坏情况缩放平移 >60fps） | 中 | 高 | exploration-ui 001 含优化路径验证（图集/LOD）；不过关则 epic 内迭代，R-05 维持开放，不阻塞 layout |
| combat-ui 001/002 超预估（UI 2d 校准仍可能低估，多文件+tscn+shader） | 高 | 中 | Day-4 检查点（2026-10-17）：001 未完成即按序丢 should（main-menu 004 → combat-ui 003 → audio 002）保 must；回顾行动项 #1 的裁剪决策必须产生可见记录 |
| MUST 利用率 93% 偏高 | 中 | 中 | 回顾校准为「must 上限 6-7d」，本冲刺 7d 触上限；Day-4 检查点若 001/002 双超则 004（角色卡）降 should，must 收敛至 5d |
| TD-014 根治涉及线程竞态（load_threaded 非确定性） | 中 | 低 | 改顺序不敏感断言（ac009）+ 延长/重试驱动（ac006）；根治后 CI 连续两跑绿才算闭环 |

## 外部因素依赖

- R-05 节点图基准需目标硬件窗口模式运行（D3D12）——Windows 目标机可用（combat-ui 009a/009b 已建立测量方法复用）
- TD-014 根治需 CI 复跑验证（Linux CI 两跑两红复现证据已登记 TD-014）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（4 项）
- [ ] 所有任务通过验收标准
- [ ] R-05 红色风险关闭（exploration-ui 001 基准通过，risk-register 更新）
- [ ] TD-014 flaky 根治 + TD-007/012 测试缺口补齐（QA 条件 A 兑现，CI 连续两跑绿）
- [ ] combat-ui-layout 001 骨架 + 002 角色卡落成（共享纯函数模块 + tests/unit/combat_ui/）
- [ ] QA 计划已存在（**实现开始前运行 /qa-plan sprint**）
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过（`/smoke-check sprint`）
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] 零回归——2723 个既有测试全部通过

## PR-SPRINT 裁决记录（2026-10-13）

**REALISTIC WITH CONDITIONS**——must 4 项 7.0d 触上限（回顾校准「6-7d」），但 TD-014（QA 条件 A）+ R-05（里程碑红风险）+ combat-ui 001/002（R-02 复测核心）均为不可砍的关键路径，故接受 93% 利用率并以 Day-4 检查点裁剪协议兜底。三项监督条件：
1. **Day-4 检查点**（2026-10-17）：combat-ui 001 未完成 → 按序丢 should（main-menu 004 → combat-ui 003 → audio 002）；001/002 双超 → 004 降 should，must 收敛至 5d
2. **TD-014 根治闭环标准**：CI 连续两跑绿（非单次），flaky 视为未闭环
3. **R-05 关闭**：exploration-ui 001 基准通过 + risk-register R-05 状态更新（关闭条件：最坏情况缩放平移 60fps）
