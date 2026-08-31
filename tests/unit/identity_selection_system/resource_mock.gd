extends Node
## ResourceSystem mock——测试 IdentitySelectionSystem.apply_identity 时替换 ResourceSystem。[br]
## [br]模拟 add_resource 行为：灵石写入 GSM player.resources.ling_shi。[br]
## [br][b]可注入失败模式[/b]：设置 _fail_mode = true 时 add_resource 返回 false。[br]
## [br]来源: ADR-0022 §apply_identity ④ 设置初始灵石。

## 失败模式开关——测试回滚用。
var _fail_mode: bool = false


func add_resource(type: StringName, amount: int, quality: int = -1) -> bool:
	if _fail_mode:
		return false
	if type == &"ling_shi":
		var gsm: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
		if gsm != null:
			var old_val: int = int(gsm.player.resources.ling_shi)
			gsm.player.resources.ling_shi = old_val + amount
			gsm._buffer_change("player.resources.ling_shi", old_val, old_val + amount)
		return true
	return false