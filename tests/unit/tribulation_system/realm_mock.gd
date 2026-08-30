extends Node
## RealmSystem mock——测试 TribulationSystem 成功结算时替换 RealmSystem。[br]
## [br]模拟 realm_up() 行为：记录调用参数 + 将 GSM.player.realm +1。[br]
## [br]来源: ADR-0021 §_handle_tribulation_success 测试桩。

var _realm_up_calls: Array = []

func realm_up(current_level: int) -> void:
	_realm_up_calls.append(current_level)
	var gsm: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm != null:
		gsm.change_realm(current_level + 1)