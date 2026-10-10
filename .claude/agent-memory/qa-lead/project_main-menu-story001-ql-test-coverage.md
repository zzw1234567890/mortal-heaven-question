---
name: main-menu-story001-ql-test-coverage
description: QL-TEST-COVERAGE 对 main-menu Story 001 的裁决（2026-10-04，ADEQUATE）——GAP-1/3/4/5 修复逐项核实为真；AC-1~4 全 COVERED；AC-5/6 手动证据未建（ADVISORY）
metadata:
  type: project
---

2026-10-04 对 main-menu Story 001（测试覆盖质量关，非文件存在性）执行 QL-TEST-COVERAGE，裁决 **ADEQUATE**。40 个自动化测试（单元 7+13 / 集成 9+11）逐条核对断言语义有效，无恒真断言。

**Why:** 该 story 曾因 GAP-1（焦点测试同义反复——只测 grab_focus API 不测决策分支）返工；code-review 三方修复闭环后需独立核实修复非名义补丁。

**How to apply:**
- GAP-1/3/4/5 四项修复全部核实为「真实存在且有效」：GAP-1 二次实例化让 _ready 真实执行；GAP-3 用 list_calls 计数器证明竞态分支真实穿越；GAP-4 双守卫（源码扫描排除注释 + SCENE_PATHS 大小写防 Windows 本地过/Linux CI 挂）；GAP-5 双触发源（信号/返回值）分支独立验证。
- [[main-menu-story001-ql-review]] 记录的 3 项 BLOCKING（制作人员按钮、has_continuable_save 语义、存档摘要）均已按 2026-09-19 裁决解决：4 按钮无制作人员、损坏感知收窄（meta exists 即亮，损坏点击后检测）、摘要入 scope 且覆盖。
- 残余（非阻塞）：production/qa/evidence/main-menu-scene-evidence.md 待建（AC-5/6 手动，ADVISORY）；H-3 重入守卫只断言 visible 不可观测单/双弹（需 spy，可留待后续）；SLOT_ORDER tie-break 语义超规格字面但已在常量注释文档化（story 明文要求）。
