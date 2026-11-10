extends RefCounted
## FullBattleClickDriver —— 完整战斗用例的鼠标点击驱动（2026-11-10 验收）。[br]
## [br][b]职责[/b]：把「按控件中心坐标模拟一次左键点击」收在一处——手牌卡、敌方
## 角色卡、结束出牌按钮的命中测试全部走真实 [code]CombatInputLayer._handle_button[/code]，
## 不直接调 [code]play_card[/code]。[br]
## [br][b]为什么独立成文件[/b]：点击/坐标是测试基础设施，与「一场战斗怎么推进」
## 分开后，夹具只保留回合编排（单文件 300 行软上限）。

## 桩 SceneManager——只记录转场请求（真实实现会加载场景并自动存档）。
class SceneManagerStub extends Node:
	var requests: Array = []

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


## 取战场门面（CombatLayout）的回调——由夹具注入。
var _root_provider: Callable = Callable()


## 注入门面取数回调（[code]func() -> Variant[/code]）。
func setup(p_root_provider: Callable) -> void:
	_root_provider = p_root_provider


## 模拟一次鼠标点击（按下 + 释放，同一位置——未越过 8px 拖拽阈值）。
func click(p_global_pos: Vector2) -> void:
	var input: Node = _input_layer()
	if input == null:
		return
	input.call(&"_handle_button", button_event(p_global_pos, true))
	input.call(&"_handle_button", button_event(p_global_pos, false))


## 手牌区第 [param p_index] 张卡的全局中心（真实命中测试的输入）。
func hand_card_pos(p_index: int) -> Vector2:
	var hand: Variant = _root().get("hand_area")
	var card: Control = hand.call("get_card", p_index)
	return card.get_global_rect().get_center() if card != null else Vector2(-1.0, -1.0)


## 敌方角色卡的全局中心。
func enemy_card_pos(p_character_id: int) -> Vector2:
	var stage: Variant = _root().get("actor_stage")
	var card: Control = stage.call("get_card", p_character_id)
	return card.get_global_rect().get_center() if card != null else Vector2(-1.0, -1.0)


## 构造一次鼠标按键事件。
func button_event(p_global_pos: Vector2, p_pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = p_pressed
	event.global_position = p_global_pos
	return event


func _root() -> Variant:
	return _root_provider.call() if _root_provider.is_valid() else null


func _input_layer() -> Node:
	var root: Variant = _root()
	if root == null:
		return null
	return root.call("interaction").call("get_input_layer")
