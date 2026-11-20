extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 战斗界面 Esc「退一层」的真实用例（design/ux/hud.md 层级退出）。[br]
## [br][b]背景[/b]：Esc 此前在战斗里只有两种结局——被暂停菜单接走，或者什么都不发生。
## 而 [code]CombatPlayFlow.cancel[/code] 的文档一直写着「点空白 / 右键 / ESC：取消选中」，
## ESC 这一条从未接线；撤退确认弹窗开着时按 Esc 也关不掉。[br]
## [br][b]不改既有暂停语义[/b]：没有可退的层时路由必须[b]放行[/b]——本文件最后一条
## 用例正是钉住这一点（事件未被消费，[code]InputManager[/code] 照常发 pause_requested）。[br]
## [br][b]为什么走真实按键[/b]：Esc 的层级判定依赖「谁先收到事件」，
## 直调路由方法测不出这个顺序。

## 真实输入驱动（真实视口事件投递）。
const RealInputDriverScript := preload(
		"res://tests/integration/combat_ui/real_input_click_driver.gd")

var driver: RefCounted = null
## 本用例里 InputManager 发出的暂停请求次数（验证「没有可退的层时放行」）。
var _pauses: Array = []


func before_all() -> void:
	for _i: int in range(300):
		if CardSystem.get_template(&"basic_attack") != null \
				and CardSystem.get_template(&"lin_yuan") != null:
			break
		await get_tree().process_frame
	AISystem.load_templates()


func before_each() -> void:
	setup(false)
	confirm_deploy()
	assert_true(drive_to_play(), "前置：应能推进到出牌阶段")
	driver = RealInputDriverScript.new()
	driver.call(&"setup", Callable(self, "_root"))
	_pauses = []
	InputManager.pause_requested.connect(_on_pause_requested)


func after_each() -> void:
	if InputManager.pause_requested.is_connected(_on_pause_requested):
		InputManager.pause_requested.disconnect(_on_pause_requested)
	driver = null
	await teardown()


## 已选中一张手牌时按 Esc：取消选中，且事件不再向下传播。[br]
## [br][b]这是「回到上一层」在战斗里最常用的一层[/b]——玩家点了张卡又不想出了。
func test_escape_cancels_selected_card() -> void:
	# Arrange——鼠标点一下选中（与玩家真实操作同源）
	var card: Control = _hand_cards()[0]
	var card_id: int = int(card.get("card_instance_id"))
	driver.call(&"click_control", card)
	var controller: Variant = _root().call("interaction").call("play_controller")
	assert_eq(int(controller.call("get_selected_card_id")), card_id,
			"前置：点一下应选中该卡")
	# Act
	_push_key(KEY_ESCAPE)
	# Assert
	assert_eq(int(controller.call("get_selected_card_id")), -1, "Esc 应取消选中")
	assert_eq(_pauses.size(), 0, "Esc 退掉了一层时不该同时触发暂停菜单")


## 没有任何可退的层时按 Esc：事件放行给暂停菜单（既有语义不变）。[br]
## [br][b]这是本次改动最该守住的一条[/b]：接线时若把 Esc 无条件消费掉，
## 玩家在战斗里就再也打不开暂停菜单了。
func test_escape_without_layer_falls_through_to_pause() -> void:
	# Arrange
	var controller: Variant = _root().call("interaction").call("play_controller")
	assert_eq(int(controller.call("get_selected_card_id")), -1, "前置：无选中")
	# Act
	_push_key(KEY_ESCAPE)
	# Assert
	assert_eq(_pauses.size(), 1, "没有可退的层时 Esc 应照常触发暂停菜单")


## 撤退确认弹窗开着时按 Esc：关掉弹窗（等价于点「继续战斗」），不撤退。[br]
## [br][b]为什么必须走按钮的 pressed[/b]：直调 [code]close_dialog[/code] 只关面板
## 不发信号，上层收不到「玩家放弃撤退」——同一件事留两条路径迟早只走通一条。
func test_escape_closes_retreat_dialog_without_retreating() -> void:
	# Arrange——点右上角撤退按钮打开确认弹窗（生产路径）
	var retreats: Array = []
	_root().get("settlement_host").connect(&"retreat_confirmed",
			func() -> void: retreats.append(1))
	driver.call(&"click", driver.call(&"retreat_button_pos"))
	var dialog: Variant = _root().get("settlement_host").get("retreat_dialog")
	assert_true(bool(dialog.call("is_showing")), "前置：撤退确认弹窗应已打开")
	# Act
	_push_key(KEY_ESCAPE)
	# Assert
	assert_false(bool(dialog.call("is_showing")), "Esc 应关掉撤退确认弹窗")
	assert_eq(retreats, [], "Esc 关弹窗不等于撤退")
	assert_eq(_pauses.size(), 0, "Esc 退掉了一层时不该同时触发暂停菜单")


## 弹窗关掉后，再按一次 Esc 才轮到暂停菜单（一层一层退，不是一次退到底）。[br]
## [br][b]为什么这条要有[/b]：一次按键连退多层是「退层级」最常见的实现错误，
## 玩家按一下 Esc 会直接掉出战斗。
func test_escape_retreats_one_layer_at_a_time() -> void:
	# Arrange
	driver.call(&"click", driver.call(&"retreat_button_pos"))
	var dialog: Variant = _root().get("settlement_host").get("retreat_dialog")
	assert_true(bool(dialog.call("is_showing")), "前置：弹窗应已打开")
	# Act——第一次退弹窗，第二次才该轮到暂停
	_push_key(KEY_ESCAPE)
	assert_false(bool(dialog.call("is_showing")), "第一次 Esc 关弹窗")
	assert_eq(_pauses.size(), 0, "第一次 Esc 不该触发暂停")
	_push_key(KEY_ESCAPE)
	# Assert
	assert_eq(_pauses.size(), 1, "第二次 Esc 才轮到暂停菜单")


# ═══════════════════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════════════════

## 投递一条真实按键（按下 + 抬起成对）。
func _push_key(p_code: Key) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var down := InputEventKey.new()
	down.keycode = p_code
	down.physical_keycode = p_code
	down.pressed = true
	tree.root.push_input(down, true)
	var up := InputEventKey.new()
	up.keycode = p_code
	up.physical_keycode = p_code
	up.pressed = false
	tree.root.push_input(up, true)


func _on_pause_requested() -> void:
	_pauses.append(1)


func _hand_cards() -> Array:
	var hand: Variant = _root().get("hand_area")
	return hand.call("card_nodes") as Array
