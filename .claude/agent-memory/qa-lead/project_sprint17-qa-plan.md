---
name: sprint17-qa-plan
description: Sprint 17 QA 计划生成裁决要点（2026-11-05）——9 story 证据路径、17-3 模糊拆出非阻塞、Day-3/4 硬化检查点、QA-17-1 视觉路径
metadata:
  type: project
---

Sprint 17（2026-11-03~11-12）QA 计划于 2026-11-05 生成（qa-lead，/team-qa 前置）。计划以文本返回编排者，文件落盘归编排流程。

关键裁决（后续 QL-TEST-COVERAGE 审查时按此口径核对）：
- **17-3（exploration 006 弹窗）背景模糊 40% D3D12 性能抽查不是 17-3 的阻塞测试**——PR-SPRINT C2 裁决拆出为 QA-17-4 ADVISORY 复测项。冲刺评审时不得因该帧率项阻塞 17-3 完成；但 Guardrail 本身仍写入测试计划（记录上报，不优化）。
- Day-3（11-05）17-1 未落地丢 17-3；Day-4（11-06）17-2 未落地丢 17-4——QA 计划的自动化/手动条目随之作废并记录。
- 17-6+17-8 为原子对（audio 005 滑则 hud 008 级联丢）——hud 008 的集成证据是**追加**到既有 `tests/integration/hud/test_gsm_signal_binding.gd`，非新文件；若原子对丢弃则无追加。
- 17-2/17-4 是 "UI（Logic 内核）" 混合类型：Logic 内核单测/集成测试为 BLOCKING，UI 走查为 ADVISORY 签收。
- QA-17-1（D3D12 窗口截图视觉验证路径）是本冲刺 QA 专项根因解决项，S16 五个遗留证据文档（identity-select/map-select/node-graph-render/topbar/cost-bar）回填依赖此路径；QA-17-2（S16-3 三缺陷走查）串行依赖 QA-17-1。
- 回归基线：S16 全量 3104 tests / 3103 passing / 1 pending 存量（test_migration_chain）——S17 新增测试后以「存量零回归 + 新增全通过」口径判定。

**Why**：PR-SPRINT 2026-11-02 裁决 C1-C6 + S16 QA 计划先例格式。
**How to apply**：S17 冲刺评审签收、story-done 证据核查、QL-TEST-COVERAGE 复核时对齐上述口径；相关先例见 [[qa_conventions]]。
