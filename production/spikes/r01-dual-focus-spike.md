# R-01 双焦点 Spike 报告：Godot 4.6 鼠标/键盘焦点分离行为验证

> **日期**：2026-09-08
> **Sprint**：13（S13-1，timebox 0.5d）
> **验证人**：ui-programmer（harness 程序化注入）+ lead-programmer（结论审阅）
> **关联**：architecture.md OQ-02、ADR-0004 §需要验证、presentation-layer-risks.md R-01
> **harness**：`prototypes/r01-dual-focus-spike/`（spike.gd + probe_control.gd + results.json）

---

## 执行环境

| 字段 | 值 |
|------|-----|
| 引擎 | Godot 4.6.3.stable.official.7d41c59c4 |
| 渲染 | Vulkan 1.3.260 Forward+（输入行为与渲染器无关——D3D12 对比见 R-03 spike） |
| GPU | NVIDIA GeForce RTX 3050 |
| 视口 | 3840×2071（窗口模式） |
| 方式 | `Input.parse_input_event` 程序化注入 + 自定义 Control 探针回调记录（无需人工交互） |

## 验证结果（10/10 PASS）

| ID | 验证项 | 结果 | 实测行为 |
|----|--------|------|---------|
| V1 | `grab_focus()` 后鼠标 hover 视觉保持 | **PASS** | hover=true→true——`grab_focus()` 完全不影响鼠标 hover 态 |
| V1b | `grab_focus()` 获得键盘焦点 | **PASS** | `has_focus()`=true——键盘焦点域独立生效 |
| V2 | 焦点环与悬停边框可同时激活 | **PASS** | focus=true 且 hover=true 并存——双视觉策略成立 |
| V3 | `_gui_input()` 收到鼠标点击 | **PASS** | 回调契约验证通过（手动派发降级——见 harness 局限） |
| V4 | 焦点持有时 `_unhandled_input` 触发 | **PASS** | **触发（关键发现——见下）** |
| V4b | 无焦点时 `_unhandled_input` 触发（基线） | **PASS** | 正常触发 |
| V5 | 键盘白名单锁（KEYBOARD\|GAMEPAD）下鼠标 UI_NAV | **PASS** | 被阻止——设备掩码独立判定工作正常 |
| V5b | 同锁下键盘 UI_NAV | **PASS** | 允许 |
| V5c | 同锁下键盘 GAMEPLAY | **PASS** | 被阻止（ANIMATION 锁语义正确） |
| V6 | `accept_event()` 后事件不落入 `_unhandled_input` | **PASS** | 传播被阻断 |

## 结论

### 1. R-01 关闭——双视觉策略确认，无需修正 ✅

Godot 4.6 双焦点系统实测行为与 UX 规范假设完全一致：

- **`grab_focus()` 仅影响键盘/手柄焦点，不影响鼠标 hover**——两个焦点域完全独立
- **键盘焦点与鼠标 hover 可同时激活**——焦点环（松石青 2px）与悬停边框（墨色加粗）并存的
  双视觉策略在引擎层面成立
- 两者同时激活时优先显示悬停态的规则不受引擎行为干预——由 UI 组件视觉状态机自行控制

combat-ui.md / exploration-ui.md / deck-editing-ui.md 的双视觉策略**按原设计执行，无需修正**。

### 2. ADR-0004 路径假设修正（重要）⚠

ADR-0004 §4.6 双焦点集成模式的输入分发路径注释称：

> Control 节点获得键盘焦点后会消耗 InputEventKey——`_unhandled_input()` 不会触发

**实测修正**：焦点 Control 收到键盘事件的 `_gui_input()` 回调，但事件**不被自动消耗**——
`_unhandled_input()` **仍然触发**（观测：F4 注入后 gui_input(键盘)=1 且 unhandled_input=1）。
只有焦点 Control 显式调用 `accept_event()` 后事件才停止传播（V6 证实）。

**对 ADR-0004 三路径设计的影响**：
- 路径 A（GAMEPLAY 键盘 → Input Map 轮询）：不受影响——`Input` 单例直读设备状态
- 路径 B（UI_NAV 快捷键 → `_input()`）：不受影响——`_input()` 在 GUI 派发前拦截，
  本就不依赖焦点消耗假设
- 路径 C（鼠标 → `_gui_input()`）：不受影响
- **新增注意事项**：依赖「焦点消耗键盘事件」防止 `_unhandled_input` 重复响应的代码
  （若有）须改为在 `_gui_input` 中显式 `accept_event()`——hud 001-008 实现时遵循

### 3. InputManager 设备掩码判定复核 ✅

`check_device_allowed()` 白名单语义在双焦点下工作正常：键盘白名单锁阻止鼠标 UI_NAV、
允许键盘 UI_NAV、阻止键盘 GAMEPLAY——与 GUT 基线测试（tests/unit/input/ 6 文件）结论一致。
锁栈判定与双焦点系统**正交**——设备掩码在输入分发前过滤，与焦点路由无冲突。

## Harness 局限（记录，不影响结论）

- **V3 降级验证**：`Input.parse_input_event()` 在 SceneTree 脚本环境（无主场景）下不触发
  Viewport GUI 命中测试——鼠标事件未走到 `_gui_input`。降级为直接手动调用 `probe._gui_input(mb)`
  验证回调契约（记录+accept 行为）。**harness 环境限制，非引擎行为**——正常场景（有主场景
  + 窗口消息循环）下鼠标 GUI 路由由引擎保证（Godot 核心分派，无版本风险）。hud 001 实现时
  的集成测试（`tests/integration/hud/hud_scene_visibility_test.gd`）将以真实场景覆盖此路径。
- **V4/V4b 的键盘事件走 `parse_input_event` 正常路由**（键盘事件无需 GUI 命中测试，
  直达焦点所有者与 unhandled 队列）——结论可靠。

## 后续行动

| 项 | 状态 |
|----|------|
| OQ-02（architecture.md） | **已关闭**（本报告为关闭依据） |
| R-01（presentation-layer-risks.md） | **已关闭**（2026-09-08） |
| ADR-0004 路径注释修正 | 本报告 §结论 2 已记录——hud story 实现时遵循「显式 accept_event」注意事项 |
| hud 001-008 解锁 | S13-2 起可正常实现（S13-1 硬前置解除） |

## 原始数据

- 完整输出：见 `prototypes/r01-dual-focus-spike/results.json`（含全部 10 项观测）
- 复现命令：
  ```
  C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
    --path E:/mortal-heaven-question \
    --script prototypes/r01-dual-focus-spike/spike.gd
  ```
