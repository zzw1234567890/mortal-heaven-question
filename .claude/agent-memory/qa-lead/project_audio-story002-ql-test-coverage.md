---
name: audio-story002-ql-test-coverage
description: audio Story 002 BGM 交叉淡化 QL-TEST-COVERAGE 2026-10-17——GAPS（2 BLOCKING：bus duck 执行层+AC-BGM-07 恢复零覆盖、sequential 执行时序无集成测试）
metadata:
  type: project
---

# audio Story 002 QL-TEST-COVERAGE（2026-10-17）

**判定：GAPS**（2 BLOCKING + 3 ADVISORY）。Type: Logic，审查模式 full。

**Why：** 13 项范围 AC/spec 中 9 项 COVERED，但 Story AC 明确含 AC-BGM-06/07（商店 Bus 降低/恢复）与 AC-BGM-08（渡劫顺序式），而这三个 AC 的 **Tween 执行层**均无测试——当初 qa-lead 写 QA spec AC-5/AC-6 时只覆盖到计划器层，属规格制定疏漏，不能作为实现免测依据。

**How to apply：**
- GAP-1 (BLOCKING)：`_bus_fade_cmd`（tween_method 总线插值）零测试；AC-BGM-07 恢复 0dB 路径计划器+执行层均无测试。需补集成（duck→restore 断言 adapter 侧 Bus 终值）+ 计划器恢复测试。
- GAP-2 (BLOCKING)：sequential=true 只验证了数据标志，`sequential_delay_sec` 累加 + `set_delay` + stop 回调 `duration + delay_sec` 组合算术无集成验证。
- ADVISORY：params_for_state MAP_CLEARED/DEFEATED 行未测（GAP-3）；play_bgm preload_next 接线无集成测试（GAP-4）；planner 实测 13 测试 vs 故事记录 12（GAP-5a）；`resolve()` 冷路径 request+立即 get 为主线程阻塞回退，依赖 preload 提前发起——Story 004 编排落地时须确认（GAP-5b）。
- 已核实无缺口：AC-1~AC-6 spec 全有实现；AC-BGM-09/10、边缘 #1/#3/#12 双层（计划器+集成）覆盖；AC-8 cache 6 测试完整；AC-1 目标 dB 边缘按"场景 dB 归 Bus 层"裁决落地（测试注释记录理由）。
- Out of Scope 边界确认：AC-BGM-01 编排归 story 004、循环归 AC-7 手动（R-06 spike 已 2026-09-13 关闭，证据归档待关闭前确认）。

关联：[[audio-story001-ql-review]]、[[qa-conventions]]
