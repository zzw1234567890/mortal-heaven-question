---
name: sprint17-qa-signoff
description: Sprint 17 签收裁决与未闭环视觉走查债——APPROVED WITH CONDITIONS、6 条件、36 项走查零执行
metadata:
  type: project
---

# Sprint 17 QA 签收（2026-11-08）

报告：`production/qa/qa-signoff-sprint-17-2026-11-08.md`。裁决 **APPROVED WITH CONDITIONS**。

**事实口径**：
- 四 must（17-1/17-2/17-3/17-4）BLOCKING 自动化全绿；合并 3437 tests / 3436 passing / 1 pending（存量 `test_migration_chain`），较 S16 净增 333 例，零回归。
- 17-5~17-9（should 4 + nice 1）**全部 UNSTARTED**。
- 走查实数为 **36 项**（10/8/8/10），不是冒烟报告写的 37 项（11/9/9/10）——台账口径待决策者裁定。
- **零 GUI 人工走查**；`production/qa/bugs/` 目录不存在（本冲刺零缺陷是"未走查"而非"验证无缺陷"）。
- QA 专项 **QA-17-1（D3D12 视觉路径）与 QA-17-4（模糊帧率抽查）均未交付**；QA-17-2 依赖 QA-17-1 未执行。

**Why**：项目自 S16 起「UI 故事视觉走查」连续三个冲刺结转，根因（无 D3D12 截图路径）未解决，导致自动化绿但产品可玩性无证据。

**How to apply**：下一冲刺 QA 计划讨论时，先确认 QA-17-1 是"交付"还是"显式放弃改人工走查"，不得默认结转；判定后续 UI story 完成度时，把"证据文档 §2 走查条目已填实测结果"而非"文档存在"视为签收依据。

相关：[[project_sprint17-qa-plan]]、[[project_qa_conventions]]
