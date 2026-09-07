# 里程碑：Presentation Layer Complete

> **目标日期**：待 Sprint 排期确认（Sprint 13 起，预估 2-3 个冲刺）
> **状态**：In Progress
> **依赖里程碑**：meta-layer-complete（已 Completed，2026-09-02）
> **覆盖冲刺**：Sprint 13 起

## 关口条件

- [ ] 7 个 Presentation 层 epic（hud / main-menu / audio-manager / combat-ui-layout / combat-ui-interaction / exploration-ui / deck-editing-ui）全部 Complete
- [ ] 三个红色风险关闭：
  - [ ] R-01 双焦点 spike 完成，OQ-02 关闭（Sprint 13 首周前置 story）
  - [ ] R-02 Draw Call 基准：战斗满场实测 <200 且 60fps
  - [ ] R-05 节点图最坏情况基准：6 层×4 节点缩放平移 60fps
- [ ] ADR-0031 验证标准全部通过（PersistentLayer 音频连续、暂停三态、CI Autoload 计数 ==25）
- [ ] 全部 6 个 UI GDD 验收标准经 QA 验证（combat-ui 73 / exploration-ui 50 / audio 31 / main-menu 22 / deck-editing-ui 13 / hud 11）
- [ ] 游戏全流程可演示：主菜单 → 身份选择 → 地图选择 → 节点图探索 → 战斗 → 结算 → 通关

## 前置行动（已完成，2026-09-07）

1. ✅ 边界澄清——战斗场景 HUD 隐藏/combat-ui 接管；战利品三选一归属 combat-ui
2. ✅ GDD 评审闭环——6 个 UI GDD 全部已批准
3. ✅ UX 设计——combat-ui + exploration-ui APPROVED，11 个新模式入库
4. ✅ 风险登记册——`production/risk-register/presentation-layer-risks.md`（10 项）
5. ✅ control-manifest 表现层规则 + ADR-0031 基线（三轮对抗性审查后 Accepted）

## Epic 排期指引（PR-EPIC 2026-09-07）

| 冲刺 | 内容 |
|------|------|
| Sprint 13 | 双焦点 spike（必须）+ hud（必须）+ main-menu（必须）+ Draw Call/D3D12 基准（应该）+ audio-manager 前半（应该）+ deck-editing-ui UX 设计（可以，1-2d） |
| Sprint 14/15 | combat-ui-layout → combat-ui-interaction（依赖 layout）、exploration-ui（节点图性能 story 排首位）、audio-manager 后半、deck-editing-ui 实现（视决策点） |

**deck-editing-ui 决策点**：Sprint 14 开始时 UX 规范仍未完成则整体推迟至 Sprint 15+，不阻塞关键路径。

## 风险登记

见 `production/risk-register/presentation-layer-risks.md`——🔴 高 3 项（R-01 双焦点、R-02 Draw Call、R-05 节点图）、🟡 中 5 项、🟢 低 2 项。每个冲刺结束时复查。
