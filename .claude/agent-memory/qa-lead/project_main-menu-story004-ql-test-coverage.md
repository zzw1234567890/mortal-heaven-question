---
name: project-main-menu-story004-ql-test-coverage
description: main-menu Story 004（按键绑定）QL-TEST-COVERAGE 2026-10-20 裁决 ADEQUATE——AC-1/2/4 全规格场景自动化锁定、断言质量核实为真；3 条 ADVISORY
metadata:
  type: project
---

# main-menu Story 004 QL-TEST-COVERAGE（2026-10-20）——ADEQUATE

**裁决**：ADEQUATE。AC-1（冲突检测全部 edge cases）、AC-2（往返+快照法）、AC-4（注册机制含产品路径）全部规格场景有直接对应测试函数，断言为行为性（经 `_current_codes` 查真实 InputMap 事件列表、文件侧回读、注册表 keys 遍历——非名义断言）。AC-3 手动证据 12 项已签收（keybind-evidence.md，3/3 签批）。

**逐场景核实**：
- AC-1 多 action 同绑/自己绑自己（含对照用例）/ESC 防御（keycode+physical 双形态）/修饰键分槽 → 单测 13 例全 COVERED
- AC-1 键鼠混绑：单测 PARTIAL（test_find_conflicts_keyboard_vs_mouse_not_conflict 未隔离跨设备——新事件与占用者同名被 ignore 掩盖），集成层行为性 COVERED（test_rebind_same_device_class_keeps_other_device：键盘 F1 vs 纯鼠标占用 action → bound 非 conflict）
- AC-2 单键往返/多键多 action/快照法恢复默认/空文件 skip 分支/merge 保留他分类 → 全 COVERED
- AC-4 注册表含 keybinds + InputMap 归位 + 文件写回（直调与 H-3 产品路径双例）→ COVERED
- 方案 B 4 例（2026-10-18 裁定）+ H-1/H-2/M-A 回归带断言，核实为真

**Why**：全量 2875/2874 passing/1 pending（save_load 存量占位）；LP-CODE-REVIEW 修复均有回归测试且断言真实行为（H-2 用 dialog.canceled/confirmed.emit() 真实信号路径，非直调私有方法）。

**How to apply**：复审 004 相关缺陷时先查上述测试是否已锁定；3 条 ADVISORY 未阻塞——(1) 跨设备非冲突缺独立单测用例；(2) MainMenu._load_keybinds 非空分支（启动加载自定义键的入口级端到端）无自动化——当前靠 store 级往返拼接；(3) AC-4「界面刷新」半边（_on_reset_all_pressed → refresh_bindings）无断言，归手动证据口径。相关：[[project-main-menu-story002-ql-story-ready]]、[[project-qa-conventions]]。
