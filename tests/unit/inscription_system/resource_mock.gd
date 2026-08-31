extends Node
## ResourceSystem mock——测试 InscriptionSystem 铭刻编排时替换 ResourceSystem。[br]
## [br]模拟 can_spend/spend_resource 行为：灵材写入 GSM player.resources.ling_cai。[br]
## [br]来源: ADR-0030 §inscribe ③ 灵材校验+扣减。

## 灵材库存——测试设置。
var _ling_cai: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}


func can_spend(type: StringName, amount: int, quality: int = -1) -> bool:
	if type == &"ling_cai":
		if quality < 1 or quality > 4:
			return false
		return int(_ling_cai.get(quality, 0)) >= amount
	return false


func spend_resource(type: StringName, amount: int, quality: int = -1) -> bool:
	if type == &"ling_cai":
		if quality < 1 or quality > 4:
			return false
		if int(_ling_cai.get(quality, 0)) < amount:
			return false
		_ling_cai[quality] = int(_ling_cai.get(quality, 0)) - amount
		var gsm: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
		if gsm != null:
			var key: String = ["low", "medium", "high", "top"][quality - 1]
			var old_val: int = int(gsm.player.resources.ling_cai[key])
			gsm.player.resources.ling_cai[key] = old_val - amount
			gsm._buffer_change("player.resources.ling_cai.%s" % key, old_val, old_val - amount)
		return true
	return false
