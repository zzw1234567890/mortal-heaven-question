# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: Sprint 13
Task: S13-2 hud 001 实现完成（20/20 测试通过）——下一步 /code-review + /story-done
<!-- /STATUS -->

<!-- QA-PLAN：2026-09-08 | System：sprint-13 | Plan written：production/qa/qa-plan-sprint-13-2026-09-08.md -->
<!-- SPIKE：2026-09-08 | S13-1 R-01 | Report：production/spikes/r01-dual-focus-spike.md | OQ-02 已关闭 | R-01 已关闭 -->

## 当前任务

**S13-2 hud 001 story-readiness 完成**（2026-09-08，QL-STORY-READY 首轮 GAPS → 3 项用户裁决落地）：

- **GAP-1 暂停归属**：HUD 拥有——HUD CanvasLayer 内独立 PauseOverlay 分支（PROCESS_MODE_ALWAYS），战斗隐藏只作用于 ContentLayer。ADR-0031 §1.1 已修订（原「各场景挂载」→「HUD 拥有的全局层分支」）
- **GAP-2 挂载机制**：本 story 扩 scope +0.5d——补齐 SceneManager PersistentLayer + register_persistent()（ADR-0031 §1.2 契约，audio 001 同步受益）
- **GAP-3 可见性矩阵**：按 GDD 收紧——12 值 SceneID 全矩阵（显示：EXPLORATION/SHOP/EVENT_PANEL/DECK_EDITING/CULTIVATION；隐藏：COMBAT/TRIBULATION/RESULT_SCREEN/DEFEAT_SCREEN/MAIN_MENU/IDENTITY_SELECT；LOADING 保持前一状态）；地图选择=探索内部状态
- story 文件已重写（AC 6 条+矩阵+QA 规格 6 条对齐裁决）；sprint-13.md/sprint-status.yaml 预估更新 1.0d→1.5d（总计 10.0d，必须+应该 8.5d 仍在容量内）
- **ADVISORY 一并解决**：AC-3 PauseOverlay 骨架测试规格、AC-1 信号驱动挂载验证（test_loading_screen.gd 先例）、AC-4/6 grep 正则明确、风险 HIGH→MEDIUM

## Git 状态

- 95e9973：S13-1 spike（已提交）
- 工作树未提交：story-001 重写 + ADR-0031 §1.1/§1.2 修订 + sprint-13.md + sprint-status.yaml + active.md

## 会话摘录——/dev-story 2026-09-08
- 故事：production/epics/hud/story-001-hud-canvas-mount-and-visibility.md——HUD CanvasLayer 挂载与可见性切换
- 更改的文件：src/foundation/scene_manager.gd（+register_persistent API）、src/foundation/scene_persistent_layer.gd（新建 76 行）、src/ui/hud/hud.gd+HUD.tscn（新建）、tests/integration/hud/test_hud_scene_visibility.gd（新建 20 测试）
- 编写的测试：tests/integration/hud/test_hud_scene_visibility.gd——20/20 通过
- 阻塞项：无
- 偏差：测试文件名 test_hud_scene_visibility.gd（非规格的 hud_scene_visibility_test.gd——GUT test_ 前缀约定）
- 已知事项：test_ac010_realm_up_triggers_gsm_realm_changed 在全量套件中偶发失败——**预先存在**（已验证 master 基线无 hud 改动时同样失败，测试顺序相关 flake，非本 story 引入；hud 改动移除后仍失败）。需单独 story/修复跟进，不阻塞 hud 001。
- 下一步：/code-review src/foundation/scene_manager.gd src/foundation/scene_persistent_layer.gd src/ui/hud/hud.gd 然后 /story-done

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
