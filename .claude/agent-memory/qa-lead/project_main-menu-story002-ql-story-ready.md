---
name: main-menu-story002-ql-story-ready
description: main-menu Story 002（设置面板+音量控制）QL-STORY-READY 测试规格审查 2026-10-04——GAPS 2 项（手动可听验证依赖 audio 002 未交付、SFX 滑条零自动覆盖）
metadata:
  type: project
---

# main-menu Story 002 QL-STORY-READY 审查（2026-10-04）

裁决：**GAPS（2 项，均为一行修订级）**。Logic/Integration 规格本体质量高（db_from_percent 边界值对照 linear_to_db 实际行为全部正确；总线前置已核实）。

**GAP-1（ADVISORY 影响）**：AC-4 手动验证「拖动总音量滑条时 BGM 即时可听变化」依赖 BGM 实际发声，但 audio-manager 002（BGM 交叉淡化）仅 Ready，`play_bgm()` 为 pass 桩——主菜单当前无声。依赖声明（仅 Story 001 + audio 001）不含可听源。需补验证手段（临时测试流 / AudioServer 表读数）或声明 audio 002 前置。

**GAP-2（BLOCKING 规格缺口）**：AC-3 Integration 仅覆盖 BGM 滑条（50%）与 Master（0% 边缘），SFX 滑条布线在「开发者不得自创新测试用例」约束下将零自动覆盖——三滑条是三条独立布线，应对 BGM/SFX/Master 参数化轮换。

**已核实无缺口项**：db_from_percent 全部边界值（0→-80、50→≈-6.02、100→0.0 is_equal_approx、1→-40dB 非 -80 有限负值、±1 超界钳制）与 Godot linear_to_db 实际行为一致；BGM/SFX 总线已交付（resources/audio/default_bus_layout.tres + project.godot 自动应用）；回滚/启动真值/0.3s/0.2s 均有归属声明（回滚在 002、启动加载归 audio 005、动画在 AC-4）；tests/unit/main_menu 与 tests/integration/main_menu 路径先例成立。

**Why:** 测试规格是开发者的唯一实现靶（story 明文禁止自创用例），覆盖缺口=永久盲区；可听验证依赖未交付系统会阻塞 ADVISORY 证据收集。
**How to apply:** 修订落地后无需整轮重审（纯增量、不动既有规格）；实现期复查 SFX 滑条是否真被参数化覆盖。相关：[[main-menu-story002-003-ql-review]]、[[audio-story001-ql-review]]。
