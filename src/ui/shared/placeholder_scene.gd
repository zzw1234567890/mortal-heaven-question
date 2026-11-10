class_name PlaceholderScene
extends Control
## PlaceholderScene —— SCENE_PATHS 占位场景共用实现（Sprint 18 场景补链）。
##
## [b]职责[/b]：闭合 [constant SceneManager.SCENE_PATHS] 中尚无对应 story 交付的
## 场景路径——深色底 + 场景标题 + 「尚未开放」状态 + 「返回探索」按钮。核心循环
## 转场（探索→商店/事件、战斗→结算/战败、HUD→卡组编辑/修为养成）不再落到
## [code]scene_transition.gd[/code] 的「目标场景缺失 → 回退 MAIN_MENU」失败路径。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不读不写任何游戏状态——只承载标题文案与
## 一次导航请求。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——按钮信号驱动。[br]
## [br][b]导航[/b]：唯一出口经 [code]SceneManager.request_scene_change[/code]
## （ADR-0005——禁止直调 [code]change_scene_to_file[/code]）；[code]from[/code] 取
## [code]get_current_scene_id()[/code]（同 MainMenu/PauseMenu 先例，不写魔数）。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——全部文案集中在本文件
## [constant TITLES] / [constant HINTS] / [constant TEXT_RETURN_BUTTON]，本地化
## epic 入库后替换为 key（同 S16/S17 TEXT_* 口径）。
##
## @experimental
## 来源: ADR-0005（场景切换唯一仲裁）、ADR-0031（表现层基线）、
## gate-check-presentation-layer-complete-2026-11-08 §B1（四占位场景）。

## SceneManager 脚本常量——SceneID / TransitionType 单一真理来源
## （preload 而非 Autoload 全局名——与 identity_select / node_popup_host 同源）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 底色（深墨基底——与 identity_select / loading 同源 BG-0 口径）。
const BG_COLOR: Color = Color(0.071, 0.071, 0.086)
## 标题字号（px——1920×1080 基准）。
const TITLE_FONT_SIZE: int = 32
## 提示正文字号（px）。
const HINT_FONT_SIZE: int = 16
## 内容块纵向间距（px）。
const CONTENT_SEPARATION: int = 16

## 固定 UI 词条（项目暂无本地化系统——S16/S17 TEXT_* 同源豁免注记）。
const TEXT_RETURN_BUTTON: String = "返回探索"
const TEXT_NOT_AVAILABLE: String = "该界面尚未开放"
const TEXT_FALLBACK_TITLE: String = "占位场景"

## SceneID → 标题（键为 SceneManager.SceneID 字面值——const Dictionary 不可引用
## 脚本常量，镜像口径同 hud.gd SCENE_VISIBILITY / state_transition_matrix.gd）。
const TITLES: Dictionary = {
	2: "卡组编辑",    # SceneID.DECK_EDITING
	6: "坊市",        # SceneID.SHOP
	7: "事件",        # SceneID.EVENT_PANEL
	8: "战斗结算",    # SceneID.RESULT_SCREEN
	9: "战败",        # SceneID.DEFEAT_SCREEN
	10: "修为养成",   # SceneID.CULTIVATION
}

## SceneID → 归属说明（玩家可见的下一跳提示——不含开发排期术语）。
const HINTS: Dictionary = {
	2: "卡组编辑功能正在打造中，当前对局使用初始卡组。",
	6: "坊市交易功能正在打造中，请先继续探索。",
	7: "此处的机缘尚未显现，请先继续探索。",
	8: "战斗结算详情正在打造中，奖励已计入修为与灵石。",
	9: "战败损失已结算，请重整旗鼓。",
	10: "修为养成功能正在打造中，请先继续探索。",
}

## 目标场景 ID（[code]SceneManager.SceneID[/code]——由 .tscn 逐个配置）。
@export var screen_id: int = 0

## [b]测试注入[/b]：可选——为 null 时按 /root/SceneManager 查找 Autoload。
var scene_manager: Node = null

## 返回按钮（测试与键盘焦点断言用）。
var return_button: Button = null
## 标题标签（测试断言用）。
var title_label: Label = null
## 状态标签（「尚未开放」——子类拿到真实数据后可覆写文案）。
var status_label: Label = null
## 提示标签（占位说明——子类可覆写为真实摘要）。
var hint_label: Label = null


func _ready() -> void:
	_build()


## 构建静态界面（一次——`_ready` 时调用；[member screen_id] 已由 .tscn 赋值）。
func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", CONTENT_SEPARATION)
	center.add_child(box)

	title_label = _make_label(TITLES.get(screen_id, TEXT_FALLBACK_TITLE),
			TITLE_FONT_SIZE, "Title")
	box.add_child(title_label)
	status_label = _make_label(TEXT_NOT_AVAILABLE, HINT_FONT_SIZE, "Status")
	box.add_child(status_label)
	hint_label = _make_label(str(HINTS.get(screen_id, "")), HINT_FONT_SIZE, "Hint")
	box.add_child(hint_label)

	return_button = Button.new()
	return_button.name = "ReturnButton"
	return_button.text = TEXT_RETURN_BUTTON
	return_button.custom_minimum_size = Vector2(160, 44)
	return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return_button.pressed.connect(_on_return_pressed)
	box.add_child(return_button)


## 返回探索——[b]唯一[/b]导航出口（ADR-0005 单一仲裁）。[br]
## [br][b]转场类型[/b]：COMBAT_TO_EXPLORE（音频矩阵唯一的「→探索」行，
## 1.0s 淡出淡入——结算/战败/商店/事件/养成共用）。[br]
## [br][b]from 动态取当前场景[/b]：不写魔数（PauseMenu M-2 先例）。
func _on_return_pressed() -> void:
	var sm: Node = _scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("PlaceholderScene: SceneManager 不可用——返回探索中止")
		return
	var from_id: int = screen_id
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	sm.call(&"request_scene_change", from_id,
			SceneManagerScript.SceneID.EXPLORATION,
			SceneManagerScript.TransitionType.COMBAT_TO_EXPLORE)


## SceneManager——注入优先，否则 /root/SceneManager（测试可替换为 mock）。
func _scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	return get_node_or_null("/root/SceneManager")


## 标签工厂（字号统一在此下发——不在各 .tscn 重复写主题覆盖）。
func _make_label(text: String, font_size: int, label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
