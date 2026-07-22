
# Godot UI — 快速参考

最近验证：2026-02-12 | 引擎：Godot 4.6

## 自 ~4.3（LLM 知识截止）以来的变化

### 4.6 变化
- **双焦点系统 (Dual-focus system)**：鼠标/触摸焦点现在与键盘/手柄焦点分离
  - 视觉反馈因输入方式而异
  - 自定义焦点实现可能需要更新
- **TabContainer**：标签页属性可直接在 Inspector 中编辑
- **TileMapLayer 场景瓦片旋转**：场景瓦片可像图集瓦片一样旋转

### 4.5 变化
- **FoldableContainer**：新的手风琴式 UI 节点，用于可折叠分区
- **递归 Control 行为**：通过单一属性即可禁用整个节点层级的鼠标/焦点
- **屏幕阅读器支持**：Control 节点可与 AccessKit 协作
- **实时翻译预览**：在编辑器中测试不同语言区域
- **`RichTextLabel.push_meta`**：新增可选的 `tooltip` 参数（源自 4.4）

### 4.4 变化
- **`GraphEdit.connect_node`**：新增可选的 `keep_alive` 参数

## 当前 API 模式

### 主题与样式（4.6）
```gdscript
# Editor uses new "Modern" theme by default
# For game UI, use custom themes as before:
var theme := Theme.new()
theme.set_color(&"font_color", &"Label", Color.WHITE)
theme.set_font_size(&"font_size", &"Label", 24)
```

### 焦点管理（4.6 — 变更）
```gdscript
# Keyboard/gamepad focus (grab_focus still works)
func _ready() -> void:
    %StartButton.grab_focus()

# IMPORTANT: In 4.6, mouse hover is separate from keyboard focus
# Both can be active simultaneously on different controls
# Test your UI with BOTH mouse and keyboard/gamepad

# Focus neighbors (unchanged)
%Button1.focus_neighbor_bottom = %Button2.get_path()
%Button1.focus_neighbor_right = %Button3.get_path()
```

### FoldableContainer（4.5 — 新增）
```gdscript
# Accordion-style collapsible container
# Add as parent of content you want to make collapsible
# Children show/hide when header is clicked
# Configure via editor properties or code
```

### 递归禁用（4.5 — 新增）
```gdscript
# Disable all mouse/focus interactions for a hierarchy
# Useful for disabling entire menu sections
%SettingsPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
# In 4.5+, this can propagate recursively to children
```

### 本地化就绪 UI（最佳实践）
```gdscript
# Use tr() for all visible strings
label.text = tr("MENU_START_GAME")

# Use auto-wrap for labels (text length varies by language)
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# Test with live translation preview in editor (4.5+)
```

## 常见错误
- 假设 `grab_focus()` 会影响鼠标焦点（在 4.6 中仅影响键盘/手柄）
- 升级到 4.6 后未同时使用鼠标和手柄测试 UI
- 硬编码字符串而非使用 `tr()` 进行本地化
- 未使用 `FoldableContainer` 实现可折叠 UI（4.5 新增，比自定义方案更简洁）
