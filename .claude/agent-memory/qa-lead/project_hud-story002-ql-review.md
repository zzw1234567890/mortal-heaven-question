---
name: hud-story002-ql-review
description: hud Story 002（境界+修为条）对抗性复核 2026-09-09——主审 READY 被推翻为 GAPS，8 项缺口（is_fallen 无数据源、label 正常态未定义等）
metadata:
  type: project
---

hud Story 002（境界+修为条组件）QL 对抗性复核（2026-09-09）：判定 **GAPS**，推翻主审查的 READY（21/21）。

**Why**: 主审查只核验了"引用存在性"（信号、挂载点、ADR），未核验"可实现性"。对抗性复核发现 8 项缺口，其中 2 项会导致实现中期中断：
- G1（最重）：`is_fallen` 在整个代码库无数据源——GSM player 域（gsm_serializer.gd L93-107）无此字段，src/ 全库 grep 无 is_fallen/落难。纯函数可测但 UI 接线无法获得输入。
- G2：纯函数返回 label，但 is_fallen=false 且非化神满时 label 语义未定义（realm_table 在 RealmSystem autoload，纯函数不可访问）。
- G3：GDD L66「可突破！」文字提示被 story 静默丢失。
- G4：AC-5~7 手动验证无可运行宿主场景（"修为调至≥90%" 无达成机制）。
- G5：动画时长 0.3s（GDD/story）vs 0.4s（design/ux/hud.md L195）冲突。
- G6：batch_updated 需过滤两条路径 player.cultivation + player.max_cultivation。
- G7：edge cases 缺失（realm_id 非法、current>max_val、化神 90-100% 组合）。
- G8（低）：RealmBarArea mouse_filter=IGNORE，组件根需自行设置悬停 filter。

**How to apply**: 对 Presentation 层 story 的就绪审查，除引用存在性外必须核验：(1) 纯函数每个输入参数在 GSM/代码库中是否真的有来源；(2) 返回值每个字段在所有状态下是否都有定义；(3) 手动验证 Setup 在当前可运行场景状态下是否可达。主审查 21/21 通过 ≠ 实现不会中途停摆。相关先例见 [[project_qa_conventions]]（hud 先例标准）。

**追加（2026-09-10 QL-TEST-COVERAGE）**：Logic 内核单测（27 函数，tests/unit/hud/test_cultivation_bar_state.gd）逐条核验 AC-1/2/3/4/8/9 全部规格+edge cases COVERED，且抽查断言与 cultivation_bar_state.gd 实现语义一致（含 HIGH-2 溢出即满修复的两条新断言）——BLOCKING 证据 ADEQUATE。剩余缺口全为 ADVISORY：手动验证路径（tests/manual/hud_debug.tscn + production/qa/evidence/cultivation-bar-evidence.md）仍未建、realm_bar.gd 信号接线（batch 过滤/setup 重入/G-H1 合成翻转）零自动化覆盖。整体裁决 GAPS（仅 ADVISORY 缺口，无 BLOCKING）。
