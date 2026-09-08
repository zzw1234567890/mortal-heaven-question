# R-01 双焦点 spike：Godot 4.6 鼠标/键盘焦点分离行为验证

> **状态**：已结束（2026-09-08——10/10 PASS，结论见 production/spikes/r01-dual-focus-spike.md）
> **假设**：Godot 4.6 双焦点系统中，`grab_focus()` 仅影响键盘/手柄焦点，不影响鼠标 hover 焦点；键盘焦点与鼠标 hover 可同时激活且视觉可区分（双视觉策略成立）
> **来源**：architecture.md OQ-02、ADR-0004 §需要验证、presentation-layer-risks.md R-01
> **Timebox**：0.5d（实际约 0.5d，含 harness 搭建与多轮注入路径调试）

## 如何运行

目标硬件、窗口模式（非 headless——事件注入需真实视口分派）：

```
C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --script prototypes/r01-dual-focus-spike/spike.gd
```

全程序化事件注入（`Input.parse_input_event`），无需人工交互。
结果输出到 stdout + `results.json`。

## 测试的假设（6 项验证）

| ID | 验证内容 | 依据 |
|----|---------|------|
| V1 | `grab_focus()` 后鼠标 hover 视觉保持 | UX 双视觉策略前提 |
| V1b | `grab_focus()` 获得键盘焦点（has_focus） | 基线确认 |
| V2 | 焦点环与悬停边框可同时激活 | 双视觉并存 |
| V3 | `_gui_input()` 收到注入的鼠标点击 | 标准鼠标路径 |
| V4 | probe 持有键盘焦点时 `_unhandled_input` 是否触发 | **关键**——ADR-0004 路径 B 设计假设 |
| V4b | 无焦点时 `_unhandled_input` 触发（基线对照） | 分派顺序确认 |
| V5 | InputManager 键盘白名单锁下鼠标 UI_NAV 被阻止 | `check_device_allowed` 双焦点判定 |
| V6 | `accept_event()` 后鼠标事件不落入 `_unhandled_input` | 传播阻断语义 |

## 文件清单

| 文件 | 用途 |
|------|------|
| `spike.gd` | 主脚本（SceneTree 脚本）——搭建场景、注入事件、记录结果 |
| `probe_control.gd` | 自定义 Control 测试探针——记录全部输入回调 |
| `results.json` | 运行结果（脚本写入） |
| `REPORT.md` | 结论报告（运行后更新——OQ-02 关闭依据） |

## 当前状态

**已结束**——2026-09-08 目标硬件运行，10/10 PASS。

## 发现

1. **双视觉策略成立**：`grab_focus()` 不影响鼠标 hover（V1）；焦点环与悬停边框可并存（V2）——UX 规范无需修正
2. **ADR-0004 路径注释需修正**：焦点 Control 收到键盘 `_gui_input` 但**不自动消耗**事件——`_unhandled_input` 仍触发（V4）。须显式 `accept_event()` 才阻断传播（V6 证实）
3. **InputManager 设备掩码与双焦点正交**（V5）——白名单判定工作正常
4. **Harness 局限**：SceneTree 脚本环境下 `parse_input_event` 不触发 GUI 命中测试（V3 降级手动派发）——正常场景由引擎保证，hud 001 集成测试覆盖
5. **GDScript 陷阱**：`var diff := 0` / `var pass := 0` 解析错误——`diff`/`pass` 在 GDScript 中不可作变量名（harness 调试发现）

完整结论：`production/spikes/r01-dual-focus-spike.md`（OQ-02 关闭依据）
