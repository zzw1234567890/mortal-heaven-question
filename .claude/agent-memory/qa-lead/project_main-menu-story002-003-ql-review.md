---
name: main-menu-story002-003-ql-review
description: QL-STORY-READY 对 main-menu Story 002/003 的裁决（2026-09-19，均 GAPS）——总线命名 Music≠BGM、UX spec 未同步应用/即时裁决、分辨率 API 引擎参考零覆盖、减少动态效果无归属
metadata:
  type: project
---

2026-09-19 对 `story-002-settings-audio.md` 与 `story-003-settings-graphics.md`（Sprint 14 预备，09-21 启动）执行 QL-STORY-READY，裁决均 **GAPS**（002：3 BLOCKING + 3 ADVISORY；003：3 BLOCKING + 5 ADVISORY）。

**Why:** 复审发现跨文档矛盾与无人认领的规格：Story 002 Engine Notes/QA AC-3 写「Music」总线，而 audio 001（S14-7）定义 BGM 命名（6 总线），且 `default_bus_layout.tres` 尚不存在（fallback 不可实现）；UX spec `design/ux/main-menu.md`（L217-219/L310/L355 AC-SET-01）仍是「即时生效+实时写入」模式，未同步 2026-09-07「实时总线+手动应用持久化」裁决，且 UX 设置面板无「应用」按钮；引擎参考 `docs/engine-reference/godot/` 全目录 Grep 无 resolution/DisplayServer/screen_get 任何覆盖——分辨率枚举 spike 从条件性变确定性前置但 sprint yaml 无条目；UX #10d「减少动态效果」（UX Open Q#1 已解决）GDD 设置表与 003 AC 均无。

**How to apply:** story 修复后复审 BLOCKING 是否解决：
- 002：总线名改 BGM/SFX 并声明 audio 001 依赖（yaml 14-3 加 blocker 14-7）；UX 回写音量裁决；启动时音量加载归属裁决（002 或 audio 005）
- 003：分辨率 spike 排期；全屏/分辨率「即时 vs 点应用」三方矛盾裁决（GDD L252-253 vs UX 10e/10f vs story 措辞）；减少动态效果入 scope 或明确移出 MVP
- 2026-09-07 四项 epic 裁决落地确认：#1/#2 已入 GDD 边界澄清+story AC（但 UX 未同步）；#3 已成 003 前置条款、查证结果=零覆盖；#4 计数不涉及

相关：[[main-menu-ql-review-2026-09]] [[main-menu-story001-ql-review]] [[hud-story005-ql-review]]（音频总线不存在先例）
