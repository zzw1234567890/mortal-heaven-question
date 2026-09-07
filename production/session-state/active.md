# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: Sprint 13 表现层前置行动
Task: 7 个表现层 epic + 里程碑文件已写入——待提交 git + /create-stories
<!-- /STATUS -->

## 当前任务

Sprint 13 表现层（UI）开发的前置行动执行中。5 项前置行动：

1. ✅ 边界澄清——战斗场景 HUD 隐藏/combat-ui 接管；战利品三选一归属 combat-ui
2. ✅ GDD 评审闭环——6 个 UI GDD 全部已批准（combat-ui 13 BLOCKER、exploration-ui 6、main-menu 3、其余 lean 通过）
3. ✅ UX 设计——combat-ui 与 exploration-ui 均已完成并通过 ux-review（APPROVED）；11 个新模式已入交互模式库
4. ✅ 风险登记册——`production/risk-register/presentation-layer-risks.md`（10 项：R-01 双焦点🔴、R-02 Draw Call🔴、R-05 节点图性能🔴、R-03 D3D12🟡、R-04 AccessKit🟡、R-06 Ogg 循环🟡、R-09 手柄范围🟡、R-07 Glow🟢、R-08 Autoload🟢已缓解、R-10 所有权🟡已缓解）
5. ✅ control-manifest 补充——Presentation 层规则已写入（8 必需 + 7 禁止 + 5 护栏）

## combat-ui UX 规范关键决策（2026-09-07）

- 布局：经典对峙布局（上敌下我），**分辨率基准 1920×1080**（用户决策：不支持 1280×720 以下）
- 角色状态卡：头像占满卡牌背景（L0）+ 底部渐变遮罩（L1）+ 功法图标竖排左侧/法宝竖排右侧（最多各3个，L2）+ HP/ATK 底部条（L3）+ buff/debuff 左下角标（L4）+ 境界图标右下角标（L4，用户决策：不同境界用不同图标，悬停显示文字）+ 待命/已行动左上角标（L5）
- 角色卡尺寸：前排 120×168px 100%缩放实线边框；后排 85% 缩放虚线边框
- 引入 5 个新模式待添加到交互模式库：角色状态卡、阵法槽位、备战阵位预览、攻击目标选择、战利品选择网格

## Git 状态

- fe03ab8：表现层 GDD 评审闭环 + combat-ui UX 规范（15 文件，+1638/-100）

## 下一步

- **全部 5 项前置行动已完成**（2026-09-07）
- 运行 `/create-epics layer: presentation` → `/create-stories` → `/sprint-plan`

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
