
# Godot 显示服务 (DisplayServer) — 快速参考

最近验证：2026-10-05 | 引擎：Godot 4.6.3（R-04 spike 实测查证）

## 为什么单独建此文件

DisplayServer 分辨率/窗口 API 在引擎参考中长期零覆盖（2026-09-19 QL-STORY-READY 发现）。
LLM 训练数据对以下两个 API 存在**幻觉**，R-04 spike（2026-10-05）用反射
`ClassDB.class_get_method_list("DisplayServer")` 实测证实它们**不存在**。

## 自 ~4.3（LLM 知识截止）以来的变化

### 关键否定项（实测不存在——勿调用）

| 假 API | 实测结果 | 正确替代 |
|--------|---------|---------|
| `screen_get_resolutions()` | ❌ 不存在 | `get_screen_count()` + `screen_get_size(idx)` 手动组合 |
| `get_screen_size()` | ❌ 不存在 | `screen_get_size(idx)`（注意是 `screen_get_*` 不是 `get_screen_*`） |
| `window_set_fullscreen()` | ❌ 不存在 | `window_set_mode(WINDOW_MODE_FULLSCREEN / WINDOW_MODE_WINDOWED)` |
| `is_window_fullscreen()` | ❌ 不存在 | `window_get_mode() == WINDOW_MODE_FULLSCREEN` 判定 |

### 4.6 变化
- **`WINDOW_MODE_EXCLUSIVE_FULLSCREEN`（=4）新增**：独占全屏模式（LLM 知识截止后新增）

## 当前 API 模式

### 分辨率枚举（多显示器）—— R-04 实测
```gdscript
# 正确：运行时枚举各显示器分辨率（不硬编码列表）
func _enumerate_resolutions() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for i in DisplayServer.get_screen_count():
        result.append(DisplayServer.screen_get_size(i))
    return result  # 返回 Vector2i 列表（如 [(3840,2160), (1920,1080)]）
```

### 全屏/窗口切换—— R-04 实测
```gdscript
# 正确：走 window_set_mode（window_set_fullscreen 不存在）
DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)   # 全屏
DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)     # 窗口
DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)  # 独占全屏（4.6+）

# 查询当前模式
var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
```

### WindowMode 枚举（完整）
```
WINDOW_MODE_WINDOWED           = 0
WINDOW_MODE_MINIMIZED          = 1
WINDOW_MODE_MAXIMIZED          = 2
WINDOW_MODE_FULLSCREEN         = 3
WINDOW_MODE_EXCLUSIVE_FULLSCREEN = 4   # 4.6 新增
```

### 窗口尺寸
```gdscript
var size: Vector2i = DisplayServer.window_get_size()
DisplayServer.window_set_size(Vector2i(1280, 720))
```

### 帧率限制
```gdscript
Engine.max_fps = 60   # 30/60/120；0 = 不限帧
```

## 常见错误
- 调用 `screen_get_resolutions()` 枚举分辨率（不存在——LLM 幻觉，R-04 实测证实）
- 用 `window_set_fullscreen(true)` 切换全屏（不存在——须 `window_set_mode`）
- 用 `get_screen_size()` 取屏幕尺寸（正确名是 `screen_get_size`）
- 假设分辨率列表由单次 API 调用返回（须 `get_screen_count` + `screen_get_size` 循环）

## 关联
- R-04 spike 报告：`production/spikes/r04-displayserver-resolutions-spike.md`
- 探针：`prototypes/r04-displayserver-resolutions-spike/spike.gd`
- 消费方：main-menu 003（画面设置——分辨率枚举 + 全屏切换）
