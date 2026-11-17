extends GutTest
## PauseMenuLayout 纯函数单测：按场景调按钮可见性 + 焦点起点挑选。[br]
## [br][b]为什么需要[/b]：UX 规格要求「战斗中隐藏『保存并退出』」（战斗不支持中退
## 保存），而暂停菜单此前恒显示全部 7 个按钮——玩家在战斗里点得到「保存并退出」，
## 点下去却是一条不该存在的存档路。[br]
## [br][b]判定与落地分开测[/b]：本文件测纯判定（哪些场景该藏、焦点该落哪个按钮），
## 落地（控件 [code]visible[/code] 与真实 [code]grab_focus[/code]）在
## [code]test_pause_menu_variant_focus.gd[/code]——两处各自可测，判错与「判对了但没生效」
## 才是两类不同的缺陷。[br]
## [br]来源: design/ux/pause-menu.md（States & Variants / 键盘焦点顺序 /
## 战斗中特殊规则）、design/gdd/hud-system.md §8。

const Layout := preload("res://src/ui/hud/pause_menu_layout.gd")
const SM := preload("res://src/foundation/scene_manager.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：按场景决定「保存并退出」可见性
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_exit_visible_in_exploration() -> void:
	## 探索支持随时存档——规格明写「探索中全部 7 个按钮可用」。
	# Act + Assert
	assert_true(Layout.save_exit_visible(SM.SceneID.EXPLORATION),
			"探索中「保存并退出」应可见")


func test_save_exit_hidden_in_combat() -> void:
	## AC（UX 规格第 4 条验收）：战斗中暂停时「保存并退出」按钮隐藏——战斗中不可存档。
	# Act + Assert
	assert_false(Layout.save_exit_visible(SM.SceneID.COMBAT),
			"战斗中「保存并退出」应隐藏（战斗不支持中退保存）")


func test_save_exit_hidden_in_tribulation() -> void:
	## 渡劫是战斗变体（hud GDD §状态与转换）——同一条规则。
	# Act + Assert
	assert_false(Layout.save_exit_visible(SM.SceneID.TRIBULATION),
			"渡劫（战斗变体）中「保存并退出」应隐藏")


func test_save_exit_hidden_in_shop_and_event() -> void:
	## 商店/事件为过渡场景，不独立存档——规格明写隐藏。
	# Act + Assert
	assert_false(Layout.save_exit_visible(SM.SceneID.SHOP), "商店中应隐藏")
	assert_false(Layout.save_exit_visible(SM.SceneID.EVENT_PANEL), "事件面板中应隐藏")


func test_save_exit_hidden_in_settlement_screens() -> void:
	## 结算/战败屏同为过渡态——此时存档毫无意义（本场已结束）。
	# Act + Assert
	assert_false(Layout.save_exit_visible(SM.SceneID.RESULT_SCREEN), "结算屏中应隐藏")
	assert_false(Layout.save_exit_visible(SM.SceneID.DEFEAT_SCREEN), "战败屏中应隐藏")


func test_save_exit_visible_in_non_combat_game_scenes() -> void:
	## 卡组编辑 / 修炼室同为游戏内可停留场景——不进隐藏名单即显示。
	# Act + Assert
	assert_true(Layout.save_exit_visible(SM.SceneID.DECK_EDITING), "卡组编辑中应可见")
	assert_true(Layout.save_exit_visible(SM.SceneID.CULTIVATION), "修炼室中应可见")


func test_save_exit_visible_for_unknown_scene_id() -> void:
	## 拿不到场景 ID（宿主未注入 SceneManager）时按最宽松处理：藏掉一个本该可用的
	## 按钮，玩家会以为存档功能没了；多显示一个则由动作层的失败反馈兜底。
	# Act + Assert
	assert_true(Layout.save_exit_visible(-1), "未知场景 ID 应保持显示（最宽松）")
	assert_true(Layout.save_exit_visible(999), "未知场景 ID 应保持显示（最宽松）")


# ═══════════════════════════════════════════════════════════════════════════════
# 战斗变体判定（确认框的战斗提示 / 进度口径共用）
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_combat_only_true_for_combat_variants() -> void:
	# Act + Assert
	assert_true(Layout.is_combat(SM.SceneID.COMBAT), "战斗场景应为战斗中变体")
	assert_true(Layout.is_combat(SM.SceneID.TRIBULATION), "渡劫应算战斗中变体")
	assert_false(Layout.is_combat(SM.SceneID.EXPLORATION), "探索不应算战斗中")
	assert_false(Layout.is_combat(SM.SceneID.SHOP), "商店不应算战斗中")
	assert_false(Layout.is_combat(-1), "未知场景不应算战斗中")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：焦点起点跳过隐藏 / 置灰 / 不可聚焦的按钮
# ═══════════════════════════════════════════════════════════════════════════════

## 造一个按传入「可见 / 置灰」规格建按钮的竖列（挂进树——[method CanvasItem.is_visible_in_tree]
## 依赖树关系，游离控件恒为 false 会让断言失去意义）。
func _build_buttons(specs: Array) -> Array:
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var buttons: Array = []
	for index: int in range(specs.size()):
		var spec: Dictionary = specs[index]
		var button := Button.new()
		button.name = "B%d" % index
		button.text = "B%d" % index
		button.visible = bool(spec.get("visible", true))
		button.disabled = bool(spec.get("disabled", false))
		if bool(spec.get("no_focus", false)):
			button.focus_mode = Control.FOCUS_NONE
		box.add_child(button)
		buttons.append(button)
	return buttons


func test_first_focusable_returns_first_visible_enabled() -> void:
	# Arrange —— 首个可选的就在第 0 位
	var buttons: Array = _build_buttons([{}, {}, {}])
	# Act
	var target: Button = Layout.first_focusable(buttons)
	# Assert
	assert_eq(target, buttons[0], "应返回首个可见且可激活的按钮")


func test_first_focusable_skips_hidden_leading_button() -> void:
	## 战斗中的实际形状：第 0 位可见，「保存并退出」（第 5 位）隐藏。
	## 更狠的一种：隐藏的那个恰在最前——焦点不能停在看不见的按钮上。
	# Arrange
	var buttons: Array = _build_buttons([
		{"visible": false}, {"disabled": true}, {},
	])
	# Act
	var target: Button = Layout.first_focusable(buttons)
	# Assert
	assert_eq(target, buttons[2], "应跳过隐藏与置灰的按钮，落在首个可选者上")


func test_first_focusable_skips_focus_none_button() -> void:
	## [constant Control.FOCUS_NONE] 的按钮不可被键盘/手柄停在上面——同隐藏处理。
	# Arrange
	var buttons: Array = _build_buttons([{"no_focus": true}, {}])
	# Act
	var target: Button = Layout.first_focusable(buttons)
	# Assert
	assert_eq(target, buttons[1], "应跳过 FOCUS_NONE 的按钮")


func test_first_focusable_returns_null_when_all_unavailable() -> void:
	## 全部不可选时返回 null——调用方据此保持不变（不 grab 到空引用上）。
	# Arrange
	var buttons: Array = _build_buttons([{"visible": false}, {"disabled": true}])
	# Act + Assert
	assert_null(Layout.first_focusable(buttons), "全部不可选时应返回 null")


func test_first_focusable_returns_null_for_empty_input() -> void:
	# Act + Assert
	assert_null(Layout.first_focusable([]), "空数组应返回 null")


func test_first_focusable_ignores_non_button_entries() -> void:
	## 调用方直接把容器子节点丢进来（含 Label / HSeparator）——非 Button 一律跳过。
	# Arrange —— 混入一个 Label 顶在最前
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var label := Label.new()
	label.name = "NotAButton"
	box.add_child(label)
	var button := Button.new()
	button.name = "RealButton"
	box.add_child(button)
	# Act
	var target: Button = Layout.first_focusable(box.get_children())
	# Assert
	assert_eq(target, button, "非 Button 的子节点应被跳过（分隔线与标签不抢焦点）")
