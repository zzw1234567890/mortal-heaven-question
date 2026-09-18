---
name: hud-story003-ql-test-coverage
description: hud Story 003 QL-TEST-COVERAGE 审查 2026-09-10——BLOCKING 证据 ADEQUATE 不阻塞关闭；3 项 ADVISORY GAP（_apply_deck 零集成断言+无回归、手动证据路径无 TD 追踪、Status 陈旧）
metadata:
  type: project
---

hud Story 003（灵石+卡组计数）QL-TEST-COVERAGE 审查（2026-09-10，full 模式）：**GAPS（3 ADVISORY）**——BLOCKING 证据（AC-1 11 测试 / AC-2 10 测试 / AC-3 8 集成）逐条映射规格全值表、断言精确、G2 区分性断言修复有效，判定 ADEQUATE，不阻塞 /story-done。

三项缺口（冲刺 QA 签收前须闭环）：
1. **_apply_deck 视觉接线零集成断言**——deck 集成测试只断言 label 文本；三态颜色（B-1 label_settings.font_color 路径，不受 animate 门控可自动化）、OverlimitLabel.visible、H-1 翻转行为均无断言；B-1/H-1 修复无回归测试（违反测试标准回归规则）；未登记 TD（TD-007 只覆盖 story-002 的 realm_bar 同类缺口）。
2. **手动证据路径无追踪**——`production/qa/evidence/lingshi-deck-counter-evidence.md` 不存在（evidence 目录整体未建）；TD-006 是 story-002 专属条目，未覆盖 003。
3. **story Test Evidence Status 仍 "[ ] Not yet created"**——陈旧。

**Why:** 左移关卡结论需要可追溯；三项 GAP 的闭环承诺（TD 登记/补测试/更新 Status）若只在对话中达成会丢失。

**How to apply:** 冲刺 13 QA 签收（/team-qa）时核对三项是否闭环：TD-006 追加条目或新 TD、卡组超限态集成测试（可选）、story Status 勾选。batch 双键组合路径（ling_shi+deck 同帧）也无测试，严重性低，可并入同一 TD。测试运行采信会话记录（hud 单元 47/47 + 集成 35/35，提交 62669da），本机无 Godot runner 未独立复跑。

相关：[[hud-story002-ql-review]] [[qa-lead-working-conventions]]
