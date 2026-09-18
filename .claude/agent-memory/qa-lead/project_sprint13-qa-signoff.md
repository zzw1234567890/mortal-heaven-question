---
name: project-sprint13-qa-signoff
description: Sprint 13 QA 签收报告已写入（2026-09-12）——APPROVED WITH CONDITIONS；TD-006/013 已补齐；4 项遗留条件与 2 项已裁决偏差
metadata:
  type: project
---

Sprint 13 QA 签收最终状态（2026-09-12，报告：`production/qa/qa-signoff-sprint-13-2026-09-12.md`）：

- **判定 APPROVED WITH CONDITIONS**——must-have（S13-1~6）DoD 8/8 达成，可进 `/gate-check`；S13-7 QA 签收 story 由该报告关闭（写入时为 backlog，待 /story-done）。
- TD-006/TD-013 视觉证据缺口已补齐（提交 56ce7ea：debug 宿主 tests/manual/hud_debug.tscn + 两份证据文档 8/8 签收 2026-09-12；TD 登记 ~~划线~~）；TD-013 验证中新增负值 delta 朱砂红 #B3424A 裁决 + 回归测试 test_ac004_negative_delta_shows_red_color（提交 6b20687）。
- 4 项遗留条件：A 主流程 E2E N/A（归 main-menu epic）／B CI 未配置／C 性能 Profiler 递延 S13-12 spike（完成即解除）／D realm test_ac010 预存 flaky 建议 Sprint 14 根治。
- 2 项已裁决偏差（非条件）：试玩笔记与手动验证合并（独立开发模式）；hud 005 AC-2 战斗数据断言 DEFERRED。

**Why:** Sprint 14 规划与 gate-check 需要知道哪些条件已裁决、哪些真正待补；原策略记忆中的 TD 缺口状态已过时（已补齐），避免重复追讨。
**How to apply:** Sprint 14 冒烟 Coverage 表应分列"测试文件覆盖"与"story 级手动证据"两列（冒烟"0 manual 缺失"口径只数测试文件的教训——见 [[project-sprint13-qa-strategy]]）；hud 002/003 视觉证据勿再标记缺失。关联 [[project_qa_conventions]]。
