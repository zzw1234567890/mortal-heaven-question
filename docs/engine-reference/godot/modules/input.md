
# Godot 输入 (Input) — 快速参考

最近验证：2026-02-12 | 引擎：Godot 4.6

## 自 ~4.3（LLM 知识截止）以来的变化

### 4.6 变化
- **双焦点系统 (Dual-focus system)**：鼠标/触摸焦点现在与键盘/手柄焦点分离
  - 视觉反馈因输入方式而异
  - 自定义焦点实现可能需要更新
- **Select Mode 快捷键变更**："Select Mode" 现为 `v` 键；旧模式重命名为
  "Transform Mode"（`q` 键）

### 4.5 变化
- **SDL3 手柄驱动**：手柄处理委托给 SDL 库，以获得更好的跨平台支持
- **递归 Control 禁用**：单一属性即可禁用整个节点层级的鼠标/焦点

### 4.3 变化（已在训练数据中）
- **InputEventShortcut**：专用于菜单快捷键的事件类型（可选）

## 当前 API 模式

### 输入动作 (Input Actions)（不变）
```gdscript
func _physics_process(delta: float) -> void:
    var input_dir: Vector2 = Input.get_vector(
        &"move_left", &"move_right", &"move_forward", &"move_back"
    )
    if Input.is_action_just_pressed(&"jump"):
        jump()
```

### 输入事件 (Input Events)（不变）
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            handle_click(event.position)
    elif event is InputEventKey:
        if event.keycode == KEY_ESCAPE and event.pressed:
            toggle_pause()
```

### 焦点管理（4.6 — 变更）
```gdscript
# Mouse/touch and keyboard/gamepad focus are now SEPARATE
# Visual styles may differ depending on which input method is active
# If you have custom focus drawing, test with both input methods

# Standard approach still works:
func _ready() -> void:
    %StartButton.grab_focus()  # Keyboard/gamepad focus

# But be aware: mouse hover focus != keyboard focus in 4.6
```

### 手柄（4.5+ — SDL3 后端）
```gdscript
# API unchanged, but SDL3 provides:
# - Better device detection across platforms
# - Improved rumble support
# - More consistent button mapping

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton:
        if event.button_index == JOY_BUTTON_A and event.pressed:
            confirm_selection()
```

## 常见错误
- 未测试鼠标和键盘两条焦点路径（4.6 的双焦点）
- 假设 `grab_focus()` 会影响鼠标焦点（在 4.6 中它只影响键盘/手柄）
- 在热路径中使用字符串字面量而非 `StringName`（`&"action"`）作为动作名
