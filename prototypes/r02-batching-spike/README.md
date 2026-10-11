# R-02 合批基准原型 + DC 测量 API spike

combat-ui-layout 009a 前置原型。两个目的：
1. **spike.gd** —— 查证 Godot 4.6 `RenderingServer.get_rendering_info` 是否存在（已确认存在）。
2. **benchmark.gd** —— 程序化构造 16 角色卡，采样 Draw Call（009b 复用此测量方法）。

## 测试假设

- 角色位按「头像 1 + 状态图标图集 1 + HP条 draw_rect 1 + 文字 1」合并后，每角色位 ≤4 DC，
  16 位合计 ≤64 DC，为整场景 <200 预算留余量。

## 运行方式（窗口模式——headless DC 不具代表性）

```bash
C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --script prototypes/r02-batching-spike/spike.gd

C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --script prototypes/r02-batching-spike/benchmark.gd
```

## 状态

已完成——spike 查证 `get_rendering_info` 存在；benchmark 窗口模式实测 16 卡 96 DC / 6.0 DC·位。

## 发现（2026-10-11）

- `RenderingServer.get_rendering_info()` **存在**；`RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME = 2`。
- 反射枚举出 `RENDERING_INFO_*` 共 11 项（0..10）。
- 结论已回写 `docs/engine-reference/godot/modules/rendering.md`。
- **benchmark 实测（16 角色卡）**：96 DC 整帧 / 6.0 DC·位——**超预想「≤4 DC·位」**。
  根因 = HP 条三个 draw_rect（fill×2 + outline×1）= 3 DC，非 1；文字 Label 非单次 draw call。
  整场景仍达标（96 << 200），但峰值场景重算 ≈201 DC 贴线——fallback 裁剪优先级升级为硬约束。
