# 里程碑：Presentation Layer Complete

> **目标日期**：原「2-3 冲刺」已证伪（Sprint 14 回顾实证 UI story 真实成本 2 日历日/story）——剩余 ~45 story ≈ 10-11 冲刺（若按当前范围）｜**待范围仲裁**（见下方「范围仲裁决策点」，2026-10-13 gate-check 提出）
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

## 实际承载（截至 2026-10-13）

| 冲刺 | 状态 | 实际内容 |
|------|------|---------|
| Sprint 13 | ✅ Done | 双焦点 spike + HUD 系统（hud 5/8） |
| Sprint 14 | ✅ Done | CI 上线 + main-menu 001-003 + combat-ui 009a/009b + audio 001 骨架（main-menu 3/5、audio 1/7、layout 2/10） |
| Sprint 15 | ▶ 进行中 | TD-014 根治 + exploration-ui 001（R-05 关闭）+ combat-ui-layout 001/002 |
| Sprint 16/17 | 计划 | layout 003-008 + exploration 主体 + interaction 启动 + deck-editing-ui + 全流程演示收口 |

## 范围仲裁决策点（2026-10-13 gate-check 提出——待 PO/dev 裁决）

四位主管关口评估共识（创意总监 NOT READY / 技术·制作·美术 CONCERNS）：**应砍范围而非仅延里程碑**。

- **不诚实预估链**：2-3 → 3+ → 5+ 冲刺三度翻倍，仍未收敛——同文档实算剩余 45 story ≈ 70-80 工作日 ≈ 10-11 冲刺。
- **待裁决选项**：
  1. 拆关口为两段——「核心循环可演示」（主菜单→身份→地图→节点图→战斗→结算，MVP）为中间里程碑，`deck-editing-ui`(0/7)、`audio 002-007` 瘦身、`exploration-ui` 后半拆出或降级；砍至 5-6 冲刺。
  2. 接受完整范围 10-11 冲刺（明示接受，非隐性拖尾）。
- **TD-014 flaky**：连续三冲刺结转，Sprint 15 must 硬截止，未解则升表现层终验 blocker。
- **R-05 限期关闭**：Sprint 15 末仍未关则正式裁决降级路径，不接受隐性拖尾。

## 风险登记

见 `production/risk-register/presentation-layer-risks.md`——🔴 高 3 项（R-01 双焦点、R-02 Draw Call、R-05 节点图）、🟡 中 5 项、🟢 低 2 项。每个冲刺结束时复查。
