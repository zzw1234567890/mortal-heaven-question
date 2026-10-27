class_name MapCard
extends Panel
## MapCard —— 地图选择界面的单张地图卡片（exploration-ui Story S16-2）。
##
## [b]职责[/b]：纯视觉渲染 + 点击转发——持有一张地图的 stub 载荷条目
## [member entry]，按地图状态渲染三类卡片视觉（已通关可重入 / 未通关
## 境界达标 / 未解锁锁定），点击经 [signal card_activated] 上报主界面
## （主界面决定进入/重入/忽略——卡片自身零决策）。[br]
## [br][b]双焦点[/b]（ADR-0031 §3 + ADR-0004）：[member focus_mode] 显式设为
## [constant FOCUS_ALL]（纯 Control 默认 FOCUS_NONE，必须显式开启才能
## grab_focus——godot-specialist 高风险修正，S16-1 同源）；焦点环（松石青 2px）
## 与悬停（墨色边框加粗）双视觉由后续视觉 story 落实，本 story 只接焦点
## 机制 + 悬停 tooltip。锁定卡半透明遮罩（[code]modulate.a = 0.45[/code]）
## 为不变量——主界面入场动画不得将其冲到不透明（S16-1 同源缺陷预防）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[member entry] 是主界面每信号周期
## 刷新时重建传入的只读视图数据，卡片绝不缓存游戏状态、绝不写 GSM。
##
## 来源: ADR-0031、ADR-0014 §get_map_list 契约、control-manifest §Presentation、
## design/gdd/exploration-ui-system.md §1 地图选择界面、story-002-map-select-screen.md。

## 点击卡片信号——[param entry] 被点击卡片的完整地图载荷条目。
signal card_activated(entry: Dictionary)

## 难度⭐字符串映射——难度等级 1-4 → ⭐数量（GDD §1「1~4颗⭐」）。
const DIFFICULTY_STARS: Array[String] = ["⭐", "⭐⭐", "⭐⭐⭐", "⭐⭐⭐⭐"]

## 锁定卡半透明遮罩 alpha——锁定态灰显不变量（入场动画目标值同源）。
const LOCKED_ALPHA: float = 0.45

## 固定 UI 词条（项目暂无本地化系统——S16-1 TEXT_* 同源豁免注记）。
const TEXT_CLEARED: String = "已通关"
const TEXT_UNCLEARED: String = "未通关"
const TEXT_FIRST_CLEAR: String = "首次通关"
const TEXT_NO_REENTRY: String = "已通关·不可重入"
const TEXT_FREE_REENTRY: String = "免费重入"
const TEXT_REENTRY_SUFFIX: String = "灵石"
const TEXT_REALM_PREFIX: String = "需"
const TEXT_REALM_SUFFIX: String = "境界"

## 当前卡片的地图载荷条目（只读视图数据，主界面刷新时重建）。
var entry: Dictionary = {}

## 名称标签（动态追加 🔒/状态标记）。
var _name_label: Label
## 难度标签（⭐）。
var _difficulty_label: Label
## 状态标签（未通关/已通关/首次通关）。
var _status_label: Label
## 费用/不可重入标签。
var _cost_label: Label


## 初始化卡片视觉——[param map_entry] 为 [code]get_map_list()[/code] 载荷
## 单条目（契约字段见 story-002 stub 载荷契约）。[br]
## [br]卡片尺寸 ~360×420px（B7 裁决）；[code]size_flags_vertical[/code] 设为
## SHRINK_CENTER 防止被 HBox 纵向拉伸（code-review 建议——否则卡片实际高度
## 被 ScrollContainer 内容高度撑到 524 而非 420）。
func setup(map_entry: Dictionary) -> void:
	entry = map_entry
	custom_minimum_size = Vector2(360, 420)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 双焦点：纯 Control 默认 FOCUS_NONE，显式开启才能 grab_focus。
	focus_mode = Control.FOCUS_ALL
	_build()


## 卡片是否锁定（未解锁）——供主界面入场动画/初始焦点判定读取。[br]
## [b]契约关系[/b]：本方法与 MapSelectScreen.should_show_lock 语义互为取反
## （本方法 true=未锁定；should_show_lock true=应锁定）。两者不互相引用以避免
## preload 循环（map_select_screen → map_card），字段契约 [code]is_unlocked[/code]
## 为单一真理来源。
func is_unlocked_card() -> bool:
	return bool(entry.get(&"is_unlocked", true))


## 构建卡片内部结构——名称 + ⭐难度 + 状态 + 费用 + 悬停 tooltip。
func _build() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16.0
	box.offset_top = 14.0
	box.offset_right = -16.0
	box.offset_bottom = -14.0
	add_child(box)

	_name_label = Label.new()
	_name_label.text = str(entry.get(&"name", "—"))
	_name_label.add_theme_font_size_override(&"font_size", 26)
	box.add_child(_name_label)

	_difficulty_label = Label.new()
	_difficulty_label.text = _difficulty_text()
	box.add_child(_difficulty_label)

	_status_label = Label.new()
	_status_label.text = _status_text()
	box.add_child(_status_label)

	_cost_label = Label.new()
	_cost_label.text = _cost_text()
	box.add_child(_cost_label)

	# 视觉状态：锁定卡半透明遮罩 + 🔒 标记；tooltip 显示解锁条件/不可重入。
	if is_unlocked_card():
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, LOCKED_ALPHA)
		_name_label.text += " 🔒"
	tooltip_text = _tooltip_text()

	gui_input.connect(_on_gui_input)


## 难度⭐文本——难度等级 1-4 映射，越界安全回退「—」。
func _difficulty_text() -> String:
	var difficulty: int = int(entry.get(&"difficulty", 0))
	if difficulty >= 1 and difficulty <= DIFFICULTY_STARS.size():
		return DIFFICULTY_STARS[difficulty - 1]
	return "—"


## 状态文本——首次通关⭐ / 已通关 / 未通关。
func _status_text() -> String:
	if not bool(entry.get(&"is_cleared", false)):
		return TEXT_UNCLEARED
	if bool(entry.get(&"is_first_clear", false)):
		return TEXT_FIRST_CLEAR
	return TEXT_CLEARED


## 费用文本——已通关不可重入 / 永久免费 / 重入费用（总额字段，UI 不拆算）。
func _cost_text() -> String:
	if bool(entry.get(&"is_cleared", false)):
		if not bool(entry.get(&"reentry_allowed", false)):
			return TEXT_NO_REENTRY
		if bool(entry.get(&"is_permanent_free", false)):
			return TEXT_FREE_REENTRY
		return "重入%d%s" % [int(entry.get(&"reentry_total", 0)), TEXT_REENTRY_SUFFIX]
	return ""


## 悬停 tooltip 文本——未解锁显示「需X境界」；不可重入显示原因；其余空。
func _tooltip_text() -> String:
	if not is_unlocked_card():
		return "%s%d%s" % [TEXT_REALM_PREFIX,
				int(entry.get(&"realm_requirement", 0)), TEXT_REALM_SUFFIX]
	if bool(entry.get(&"is_cleared", false)) \
			and not bool(entry.get(&"reentry_allowed", false)):
		return TEXT_NO_REENTRY
	return ""


## 卡片点击转发——左键按下或键盘/手柄确认（[code]ui_accept[/code]）发
## [signal card_activated]（瞬态交互，不改变游戏状态——主界面据此分流，改变
## 状态的进入/重入才过 InputManager 锁栈）。[br]
## [b]键盘激活[/b]：卡片 focus_mode=FOCUS_ALL 聚焦后按 Enter/Space 触发
## [code]ui_accept[/code]——满足 ui-code 规则「所有交互元素同时支持键盘/鼠标
## 和手柄」（code-review HIGH 建议闭合）。
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_activated.emit(entry)
	elif event.is_action_pressed(&"ui_accept"):
		card_activated.emit(entry)
