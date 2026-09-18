---
name: qa-lead-working-conventions
description: QA Lead 在本项目的裁决标准与项目测试目录结构（hud 先例、GDD AC 编号占位、测试目录尚未建立）
metadata:
  type: project
---

本项目 QA Lead 工作约定（截至 2026-09-07）：

- **hud epic 先例即裁决标准**：UI story 埋没确定性逻辑 → 提取 Logic 内核纯函数 + `tests/unit/[system]/` 单测（BLOCKING）。story-002-realm-cultivation-bar.md 是参照模板（QA Test Cases 章节由 qa-lead 在 story 创建时写入）。
- **TR 注册表无表现层条目**：Presentation 层 story 需求以 GDD AC 编号占位（如 AC-main-menu-001~022）。
- **测试目录现状**（2026-09-08 复核）：`tests/unit/[system]/` 与 `tests/integration/[system]/` 均已大规模建立（166+ 测试文件，覆盖 gsm/scene_manager/combat/event_system 等）。scene_manager 集成测试先例：`tests/integration/scene_manager/test_loading_screen.gd` —— mock GSM/IM/SL + `sm._test_mode = true` + 手动调 `_execute_post_load` 绕过异步转场。
- **控制清单版本**：2026-09-07；story 嵌入此版本，/story-readiness 检查过期。
- **项目强制中文交流**（CLAUDE.md），测试文件/函数命名遵循 `[system]_[feature]_test.gd` / `test_[scenario]_[expected]`。

**Why:** 这些是多次裁决共享的上下文，不在代码中直接可见。

**How to apply:** 做 story readiness / QA 计划时先核对 hud story-002 结构与 control-manifest 版本戳；承诺测试前先确认 `tests/unit/[system]/` 目录是否已创建。

补充（2026-09-08 hud story-001 审查发现）：
- **ADR-0031 §1.2 契约与代码现状存在缺口**：ADR 定死 SceneManager 须暴露 `register_persistent(node)` API + 启动时创建 `PersistentLayer` 持久节点（HUD/音频节点池挂入）。但 `src/foundation/scene_manager.gd` 与 `scene_transition.gd` 均无 `register_persistent`/PersistentLayer 实现。HUD story-001 若按 ADR 实现，需先确认该 API 由本 story 补齐还是另行排期。
- **GDD hud-system「地图选择」场景无 SceneID 映射**：SceneID 枚举（11 值 + LOADING）没有 map_select；GDD 场景可见性矩阵含地图选择，story 验收标准也引用了它。测试规格写「按目标 SceneID 映射可见性」时会踩到这个缺口。

相关：[[main-menu-ql-review-2026-09]]
