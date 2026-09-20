---
name: combat-ui-layout-009-ql-review
description: combat-ui-layout 009a/009b QL-STORY-READY 审查（2026-09-19）——009a GAPS 仅 ADVISORY；009b GAPS 3 BLOCKING（stub 场景矛盾/provisional 语义/依赖声明）
metadata:
  type: project
---

2026-09-19 对 combat-ui-layout 009a（合批方案定型）/009b（R-02 Draw Call 满场实测）执行 QL-STORY-READY 关卡审查（Sprint 14 前最后两个 must story）。

**裁决**：009a = GAPS（1 BLOCKING：引擎参考无 get_rendering_info 覆盖，AC-7 前提不实）；009b = GAPS（3 BLOCKING，写入前须修正）。

009a BLOCKING：
1. AC-7「引擎参考查证 get_rendering_info」前提不实——`docs/engine-reference/godot/` 无此 API 覆盖；须改官方文档为源 + 回写引擎参考义务（测量脚本被 009b 消费，未验证 API 会污染整条证据链）。
009a ADVISORY：Dependencies「本 epic 内最先执行」与 EPIC.md「001 最先」矛盾；Estimate 占位（yaml 已填 0.5d）。

009b 三项 BLOCKING：
1. Dependencies 写「Story 001~008（全部组件完成）」与 Sprint 14 排期直接矛盾（001-008 在 Sprint 15）——须改为依赖 009a + stub 场景构造说明。
2. AC-1「标准战斗场景实测」的构成物（16 角色卡/7 手牌/阵法/费用栏/日志）在 Sprint 14 全部是占位原型——story 未诚实声明「实测为原型级而非组件级」。
3. AC-7 写「R-02 风险关闭」与 PR-SPRINT 监督条件 #3 矛盾——只能「有条件关闭（provisional）」；复测义务双登记：combat-ui-layout epic DoD（001-008 完成后）+ combat-ui-interaction epic（交互元素完成后）。

**关键查证**：`docs/engine-reference/godot/` **未覆盖** `RenderingServer.get_rendering_info` / `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`（rendering.md 仅有 D3D12 默认/Glow/SMAA/draw_list_begin）。009a AC-7 须以官方文档为源核验并**回写引擎参考**。

**Why**: 009a/009b 是 Sprint 14 must（S14-5/14-6），但 EPIC 顺序原定「009b 在 001-008 完成后执行」；stub 版提前是 PR-SPRINT 监督条件 #3 的既定裁决，story 文本未跟上。
**How to apply**: 009b 修正后复核对三项 BLOCKING；Sprint 15 001-008 完成时检查 epic DoD 的 R-02 复测是否触发；见 [[combat-ui-interaction-ql-review]]（stub 路径裁决来源）。
