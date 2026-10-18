extends Node
## MockCombatSignals —— combat-ui Story 003 信号接线测试专用 mock（TD 先例）。[br]
## [br][b]契约对齐[/b]：[code]src/feature/combat_system.gd[/code] 的
## [code]attack_resolved / character_died / battle_ended[/code] +
## [code]src/feature/deployment_system.gd[/code] 的
## [code]standby_cleared / character_deployed[/code] 五信号（Story 003
## Coordinator 订阅集）。参照 [code]tests/integration/hud/mocks/hud_mock_gsm.gd[/code]
## 先例——自建 stub Node 带原生 signal 声明，不需要完整 GSM/Autoload。

## 单次攻击结算完毕（Cat 2b）——载荷 {attacker_id, target_id, damage, is_kill}。
signal attack_resolved(attack_data: Dictionary)
## 角色 HP ≤ 0——载荷 (character_id, side, binding_card_ids)。
signal character_died(character_id: int, side: int, binding_card_ids: Array)
## 战斗结束——载荷 (result: int, rewards: Dictionary)。
signal battle_ended(result: int, rewards: Dictionary)
## 回合结束待命清除——载荷 (character_ids: Array[int])。
signal standby_cleared(character_ids: Array)
## 角色上场——载荷 (character_id, slot_index, is_front, deploy_turn)。
signal character_deployed(character_id: int, slot_index: int,
	is_front: bool, deploy_turn: int)

## HP 数据域——hp_reader Callable 每结算帧从这里读取（零状态所有权：
## UI 不缓存，mock 同步提供最新值；测试通过 set_hp 模拟源系统状态）。
var _hp_store: Dictionary = {}


## 模拟源系统 HP 写入（测试 Arrange 用——mock 即源系统替身）。
func set_hp(character_id: int, current: int, max_val: int) -> void:
	_hp_store[character_id] = {"current": current, "max": max_val}


## hp_reader_cb 契约实现——func(character_id) -> {current, max}。
func read_hp(character_id: int) -> Dictionary:
	return _hp_store.get(character_id, {"current": 0, "max": 0})


## 发射一次攻击结算（测试便捷入口——payload 同 combat_system 契约）。
func emit_attack(target_id: int, damage: int, is_kill: bool = false,
		attacker_id: int = 1) -> void:
	attack_resolved.emit({
		"attacker_id": attacker_id,
		"target_id": target_id,
		"damage": damage,
		"is_kill": is_kill,
	})
