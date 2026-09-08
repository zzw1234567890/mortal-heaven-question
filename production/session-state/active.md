# Active Session State

<!-- STATUS -->
Epic: presentation-layer
Feature: Sprint 13
Task: S13-1 R-01 双焦点 spike 完成（10/10 PASS）——下一步 S13-2 hud 001 story-readiness
<!-- /STATUS -->

<!-- QA-PLAN：2026-09-08 | System：sprint-13 | Plan written：production/qa/qa-plan-sprint-13-2026-09-08.md -->
<!-- SPIKE：2026-09-08 | S13-1 R-01 | Report：production/spikes/r01-dual-focus-spike.md | OQ-02 已关闭 | R-01 已关闭 -->

## 当前任务

**S13-1 R-01 双焦点 spike 已完成**（2026-09-08，目标硬件 RTX 3050 / Godot 4.6.3 / Vulkan Forward+）：

- harness：`prototypes/r01-dual-focus-spike/`（spike.gd SceneTree 脚本 + probe_control.gd 探针 + results.json）
- **10/10 PASS**，三大结论：
  1. **双视觉策略成立**——`grab_focus()` 不影响鼠标 hover（V1）；焦点环与悬停边框并存（V2）——UX 规范无需修正
  2. **ADR-0004 路径注释修正**——焦点 Control 收到键盘 `_gui_input` 但不自动消耗，`_unhandled_input` 仍触发；须显式 `accept_event()`（V4/V6）——hud story 实现时遵循
  3. InputManager 设备掩码与双焦点正交（V5）
- 已更新：OQ-02 关闭（architecture.md）、R-01 关闭（risk register）、ADR-0004 引擎兼容性+风险节、sprint-status.yaml 13-1 done
- harness 局限记录：SceneTree 脚本环境 `parse_input_event` 不触发 GUI 命中测试（V3 降级手动派发）——hud 001 集成测试以真实场景覆盖

## Git 状态

- 工作树未提交：spike harness（prototypes/）+ spike 报告（production/spikes/）+ OQ-02/R-01/ADR-0004 更新 + sprint-status.yaml + active.md

## 下一步

- **S13-2 hud 001**：`/story-readiness production/epics/hud/story-001-hud-canvas-mount-and-visibility.md` → `/dev-story`
- 可并行应该项：S13-8 R-06 Ogg spike / S13-11 R-02 合批 009a / S13-12 R-03 D3D12 冒烟
- 依赖上报清单（story 实现时跟进——见 EPIC.md deck-editing-ui 依赖上报节）

## 全量测试基线（不变）

- Scripts: 143 / Tests: 2455 / Passing: 2454 / Pending: 1 / Failing: 0 / Asserts: 9195
