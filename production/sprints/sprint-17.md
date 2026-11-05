# Sprint 17: 核心循环第二跳 —— 节点交互 + 部署/结算面板 + QA 视觉路径落地

> **Sprint**: 17
> **Start Date**: 2026-11-03
> **End Date**: 2026-11-12
> **Focus**: 探索节点交互（移动+弹窗）+ combat 部署/结算撤退面板 + S16 nice 结转三项 + QA 视觉走查根因解决
> **Milestone**: presentation-layer-complete（两段式第二段——里程碑文档已顺手勘误）
> **Review Mode**: full
> **Last Updated**: 2026-11-02

## 冲刺目标

核心循环 MVP 第二段：节点图从「可看」到「可玩」（移动交互 + 5 类弹窗），战斗侧补齐部署面板与结算/撤退面板；同步建立 D3D12 窗口截图视觉验证路径，终结 S16 遗留的 5 个 UI 证据文档回填空转。

## 范围仲裁（PR-SPRINT 2026-11-02）

制作人判定 CONCERNS（6 项），经裁决处理：
- **C1 must 利用率 87.5%** → 显式接受，风险靠 Day-4 硬化检查点管理（不降负载）
- **C2 17-3 预估偏紧** → 背景模糊 40% D3D12 性能抽查从 must 拆出，登记 ADVISORY 复测项（QA-17-4）
- **C3 QA 走查根因** → 本冲刺建 D3D12 视觉验证路径（QA-17-1），不第三次空结转
- **C4 伪并行** → 接受（S16 先例：3 深链 4 日历日跑通；本冲刺两条链均 2 深更浅）
- **C5 interaction 001 放 should** → 保留 should，丢弃顺序写死为首丢项
- **C6 里程碑文档漂移** → 本冲刺顺手勘误

## 容量

- 总天数：10 个日历日（2026-11-03 至 2026-11-12）
- 缓冲（20%）：2 天（其中 1 天为显式风险缓冲——must 高集中风险）
- 可用：8 工作日
- 速度基准（S15/S16 双冲刺实证）：UI story = 2 日历日/story；Logic/Integration = 1.0-1.5d
- MUST 利用率：7.0d / 8d = **87.5%（显式接受——风险靠 Day-4 硬化检查点管理，不降负载）**

## 任务

### 必须完成（关键路径）—— 4 项（7.0d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 | 验收标准 |
|----|------|------|------|:--:|:--:|---------|
| 17-1 | exploration-ui 005 节点移动交互 | `story-005-node-move-interaction.md` | Integration | 1.5d | 003 ✅ | 可达节点点击确认移动 + 移动动画 + AP 扣减联动 + 行动力不足拦截 |
| 17-2 | combat-ui-layout 007 部署面板框架 | `story-007-deploy-panel-framework.md` | UI（Logic 内核） | 2.0d | 001 ✅ | 部署面板骨架 + 卡牌列表 + 槽位映射 + 拖入预览（静态） |
| 17-3 | exploration-ui 006 节点交互弹窗 | `story-006-node-interaction-popups.md` | Integration | 1.5d | 17-1 | 5 类节点弹窗（战斗/事件/商店/灵泉/渡劫）+ 分发表 + 载荷渲染。**背景模糊 40% D3D12 性能抽查拆出**（ADVISORY 复测项 QA-17-4） |
| 17-4 | combat-ui-layout 008 结算/撤退面板 | `story-008-settlement-retreat-panels.md` | UI（Logic 内核） | 2.0d | 17-2 | 结算面板（战利品三选一）+ 撤退确认 + 结算数值渲染 |

**Day-4 硬化检查点（预定义丢弃顺序——写入即生效）**：
- 17-1 未在 **Day-3（11-05）** 落地 → 丢 17-3，must 收敛至 5.5d
- 17-2 未在 **Day-4（11-06）** 落地 → 丢 17-4，must 收敛至 5.0d
- 丢弃时 story 状态回 backlog，不带入下一冲刺隐性结转

### 应该完成 —— 4 项（3.5d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 |
|----|------|------|------|:--:|:--:|
| 17-5 | combat-ui-interaction 001 输入锁基座 | `story-001-input-lock-base.md` | Integration | 1.5d | layout 001 ✅ + R-01 ✅ |
| 17-6 | audio 005 暂停/静音/总线控制（S16 结转） | `story-005-pause-mute-bus-control.md` | Logic+Integration | 0.5d | audio 004 ✅ |
| 17-7 | main-menu 005 语言切换（S16 结转） | `story-005-language-switch.md` | UI+Integration | 1.0d | 002/003 ✅ |
| 17-8 | hud 008 静音图标 F1（S16 结转） | `story-008-mute-icon.md` | UI | 0.5d | **17-6（原子对）** |

**should 丢弃顺序（写死）**：17-5 首丢（非演示关键路径，解锁 interaction 后续 8 story 但不阻塞第二段）→ 17-7 → 17-6+17-8 **原子对**（跨 owner mini 链：audio 005 再滑则 hud 008 级联丢弃，二者要么都做要么都丢）。

### 可以完成 —— 1 项（1.5d）

| ID | 任务 | 文件 | 类型 | 预估 | 依赖 |
|----|------|------|------|:--:|:--:|
| 17-9 | exploration-ui 004 AP 指示器 | `story-004-ap-indicator.md` | UI（Logic 内核） | 1.5d | 003 ✅ |

### QA 专项（非编码容量——qa-lead/qa-tester 并行，不占 ui-programmer）

| ID | 任务 | 负责人 | 说明 |
|----|------|--------|------|
| QA-17-1 | **D3D12 视觉验证路径搭建**（根因解决） | qa-lead | 窗口模式截图脚本 + 图像 diff，沿用 R-05/R-02 已跑通的 D3D12 基准方法；产出后回填 S16 遗留 5 个证据文档 |
| QA-17-2 | S16-3 三条缺陷风险走查确认 | qa-tester | 依托 QA-17-1 路径；不符则开缺陷报告 |
| QA-17-3 | tech-debt-register 补登（S15-9 四项 + audio 004 四项 S 建议） | qa-lead | 留痕闭环 |
| QA-17-4 | ADVISORY 复测项登记：17-3 背景模糊 40% D3D12 性能抽查 | qa-lead | 从 17-3 must 拆出，story 006 注明「不达标记录上报，不在 story 内优化」 |

## 上一个冲刺的结转项

| 任务 | 原因 | 新预估 | 去向 |
|------|------|--------|------|
| 5 个 UI 证据文档回填 | headless 无视觉路径（根因） | 0.5d（依托 QA-17-1） | 本冲刺 QA 专项 |
| audio 005 | S16 被手牌弧形换出 | 0.5d | 本冲刺 should（17-6） |
| main-menu 005 | nice 未排 | 1.0d | 本冲刺 should（17-7） |
| hud 008 | nice 未排 | 0.5d | 本冲刺 should（17-8） |
| R-02 组件级复测 + R-05 复测 | combat 004-006 / exploration 主体实现优先 | — | Sprint 18（组件齐备后） |
| QA 计划 S16-7 条目勘误 | 文档漂移 | 0 | 新 QA 计划（qa-plan-sprint-16-2026-11-02）已按正确主体书写 |

## 风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:--:|:--:|---------|
| must 利用率 87.5% + 2 HIGH 风险 story（17-2/17-4） | 中 | 高 | Day-4 硬化检查点预定义丢弃顺序；1d 显式缓冲不挪用 |
| 17-3 伪并行（同 ui-programmer 串行 7.0d） | 中 | 中 | S16 先例（3 深链 4 日历日跑通）；两条链均为 2 深浅于 S16 |
| 17-3 预估偏紧（11 AC + 5 类弹窗） | 中 | 中 | 性能抽查已拆出（QA-17-4）；超 Day-3 检查点即触发丢弃 |
| D3D12 截图路径搭建本身超时 | 低 | 中 | 沿用 R-05/R-02 已跑通方法（非从零探索）；S17 首周启动 |

## 外部因素依赖

- 无（Godot 4.6.3 本地环境齐备，CI 已上线）

## 此冲刺的完成定义

- [ ] 所有必须完成的任务已完成（或经 Day-4 检查点显式丢弃并记录）
- [ ] 所有任务通过验收标准
- [ ] QA 计划已存在（`production/qa/qa-plan-sprint-17-*.md`）
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过（`/smoke-check sprint`）
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
- [ ] **story-done 关闭前校验 git 提交状态**（S16 流程改进——无本 story 文件残留工作区才可关）

## 里程碑文档勘误（本冲刺顺手完成）

`presentation-layer-complete.md` 关口条件标注两段式路径：S16-17 核心循环 MVP（deck-editing-ui 后置，非关口阻塞项）。
