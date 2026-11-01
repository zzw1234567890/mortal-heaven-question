extends Node
## MockTopbarSignals —— combat-ui-layout Story 004 顶部条信号接线测试 mock。
##
## [b]契约对齐[/b]：[code]src/feature/combat_system.gd[/code] 的
## [code]phase_changed / battle_ended[/code] + [code]src/feature/formation_system.gd[/code]
## 的 [code]formation_deployed / activated / deactivated / overwritten[/code]。
## 参照 [code]mock_combat_signals.gd[/code] 先例——自建 stub Node 带原生 signal
## 声明，不需要完整 Autoload。
signal phase_changed(old_phase: int, new_phase: int, turn: int)
signal battle_started(config: Dictionary)
signal battle_ended(result: int, rewards: Dictionary)
signal formation_deployed(formation_id: int, slot_index: int, template_id: StringName, deployed_turn: int)
signal formation_activated(formation_id: int, slot_index: int, template_id: StringName, trigger_reason: String)
signal formation_deactivated(formation_id: int, slot_index: int, reason: String)
signal formation_overwritten(old_formation_id: int, new_formation_id: int, slot_index: int)
