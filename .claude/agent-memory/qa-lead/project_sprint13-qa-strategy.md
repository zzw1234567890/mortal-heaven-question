---
name: project-sprint13-qa-strategy
description: Sprint 13 QA 策略验证（2026-09-12）——must-have 全绿；TD-006/TD-013 视觉证据缺口与冒烟报告"0 manual 缺失"矛盾；试玩笔记缺失为 ADVISORY
metadata:
  type: project
---

Sprint 13 /team-qa 阶段 2 策略验证结论（2026-09-12）：

- 5 个 must-have story（hud 001-005）BLOCKING 证据全 ADEQUATE：unit/hud 4 文件 + integration/hud 5 文件实测存在且冒烟全绿（2598 tests / 2597 pass / 1 pending 预存 flake）。
- **关键发现**：冒烟报告 smoke-2026-09-11.md Coverage 表称"0 manual 缺失"，但 `production/qa/evidence/` 仅有 notification-stack / pause-menu 两份证据——hud 002（TD-006）与 hud 003（TD-013）的视觉证据文档（cultivation-bar-evidence.md / lingshi-deck-counter-evidence.md）不存在，且技债登记册明文"冲刺 QA 签收前须补"。冒烟的"manual 缺失"口径只数测试文件，不数 story 级视觉证据。
- 裁决建议：APPROVED WITH CONDITIONS——条件 = 补齐 TD-006/TD-013 两份视觉证据（可共用 tests/manual/hud_debug.tscn 一次会话，tests/manual/ 目录 2026-09-12 时尚不存在）。
- QA 计划要求 hud 004/005 试玩笔记（production/session-logs/playtest-sprint13-hud.md）——文件不存在；两份 ADVISORY 证据已由独立开发者全角色签收（2026-09-11），建议记为已裁决偏差（独立开发模式下试玩会话与手动验证合并），ADVISORY 不阻塞。
- 冒烟三项警告（主流程 E2E N/A 归 main-menu epic / 性能 Profiler 递延 R-03 spike / CI 未配置）均非本冲刺引入，可接受进签收报告。
- Story 005 AC-2 的 HP/费用/牌库断言 DEFERRED（战斗数据模型未建模）——用户裁决 2026-09-11 递延，须在签收报告列为已记录偏差。

**Why:** 下阶段（签收报告生成 / Sprint 14）需要知道哪些缺口已被裁决、哪些是真正待补条件；冒烟"0 manual 缺失"口径与 story 级证据的差异容易在 Sprint 14 复发。
**How to apply:** Sprint 14 起冒烟检查的 Coverage 表应分列"测试文件覆盖"与"story 级手动证据"两列；签收 hud 002/003 视觉证据前先查 tests/manual/hud_debug.tscn 是否已建。关联 [[project_qa_conventions]]。
