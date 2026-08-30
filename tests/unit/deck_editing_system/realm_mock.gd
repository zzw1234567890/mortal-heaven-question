extends Node
## RealmSystem mock——测试 DeckEditingSystem 时替换 RealmSystem。[br]
## [br]模拟 get_current_property() 行为：根据 GSM.player.realm 返回 deck_limit。[br]
## [br]来源: ADR-0023 §公共 API 测试桩。

var _deck_limits: Dictionary = {1: 20, 2: 25, 3: 30, 4: 35, 5: 40}

func get_current_property(key: StringName) -> Variant:
	if key != &"deck_limit":
		return null
	var gsm: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		return 20
	var realm: int = int(gsm.player.realm)
	return _deck_limits.get(realm, 20)