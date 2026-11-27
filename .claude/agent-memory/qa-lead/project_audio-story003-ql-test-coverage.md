---
name: project_audio-story003-ql-test-coverage
description: audio Story 003 SFX 池 QL-TEST-COVERAGE 2026-10-23 — ADEQUATE；AC-1~AC-8 全 COVERED（含 80ms 最低时长 finished 分支）；2 ADVISORY
metadata:
  type: project
---

audio Story 003（sfx_pool.gd，Logic）QL-TEST-COVERAGE 复审结论：**ADEQUATE**（2026-10-23）。

- AC-1~AC-8 全部 16+2 项断言逐文件核实为真，语义与实现对得上。
- 上轮标记的 BLOCKING 缺口（AC-8 80ms 最低时长 `_on_ui_finished` 分支零覆盖）已由新增两测试修复：
  `test_ui_sfx_natural_finish_below_min_duration_replays_silence`（t=30 emit finished → stream 置 null）与
  `test_ui_sfx_natural_finish_at_min_duration_no_silence`（t=100 emit finished → stream 保留）。
  覆盖方式：手动 `ui_player.finished.emit()` 驱动——打断路径（stop→play）不触发 finished，这是唯一能触达 `_on_ui_finished` 的路径。
- 剩余 2 ADVISORY：
  1. `test_sfx_pool.gd` 第 25 行 `SfxPoolConfigScript` preload 声明后从未使用（dead preload，实现已引入 SfxPoolConfig 数据驱动重构但测试仍用本地常量 POOL_SIZE=16）。
  2. 边缘 #15「异步加载失败→标记不可用→后续静默丢弃」的可观测行为已被 `test_missing_resource_*` 覆盖（resolver 返回 null 即告警一次），但「标记不可用」状态机与「从未加载」在实现/测试层面不可区分（实现选择每次 null 即告警一次，`_missing_warned` 只是去重表，无独立不可用缓存）。

**Why**: 实现已从「SfxPool 内硬编码调优常量」重构为「SfxPoolConfig 数据驱动资产注入」（[[project_qa_conventions]] 的 Forbidden 硬编码规则落地）；测试 POOL_SIZE 从 `SfxPoolScript.POOL_SIZE` 改为本地常量 16，断言值依赖 config 出厂默认（cooldown 50/attack 100/ui_min 80/max 12）。
**How to apply**: 后续若改 SfxPoolConfig 出厂默认值，须同步检查 test_sfx_pool.gd 的硬编码边界断言（49/50、99/100、12 槽满、16 节点）；边缘 #15 若要求独立状态机语义，需在 SfxPool 增加不可用缓存并由新测试区分，当前实现属可接受简化。
