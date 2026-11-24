extends "res://src/foundation/save_load/slots.gd"
## SaveLoadSystem 快照层 —— [b]跨局元进度 + 战斗前快照[/b]。[br]
## [br][b]本层职责[/b]：两类「不是常规槽位」的存档——[method load_progression]
## （跨存档的元进度 progression.dat，文件不存在/损坏都回落默认值）与战斗快照三件套
## （[method create_battle_snapshot] / [method restore_battle_snapshot] /
## [method clear_battle_snapshot]，进战斗前存、结算后清）。[br]
## [br][b]为什么单独一层[/b]：两者的失败语义与常规槽位相反——常规槽位读不到是
## 「这个槽位是空的」（玩家要看到的事实），而这两类读不到是「没有进度/没有快照」
## （玩家不该看到任何提示，静默回落即可）。把它们与槽位查询混在一层，容易被后来者
## 按常规槽位那套错误码去套。[br]
## [br][b]成员名逐字保留[/b]：Story 004 的验收（AC-008 ~ AC-013）直接写在
## [method load_progression] / [method create_battle_snapshot] /
## [method restore_battle_snapshot] / [method clear_battle_snapshot] 上。[br]
## [br]来源: design/gdd/game-state-manager.md §存档、ADR-0002 §战斗快照、本轮
## 「战斗中存档 → 读档回到战斗」。


## [b]加载跨局元进度[/b]——读取 progression.dat 获取跨存档的持久进度数据。
##
## [b]返回[/b]: 进度 Dictionary。[br]
## 文件不存在时返回默认值字典（全部域从零初始化）——不报错。[br]
## [br][b]⚠️ AC-008[/b]: 首次启动 progression.dat 不存在 → 返回默认值。
## [br][b]⚠️ AC-009[/b]: progression.dat 损坏（非法 JSON）→ [method push_error] + 返回默认值 +
## 发射 [signal progression_saved](false) 信号。
func load_progression() -> Dictionary:
	const DEFAULTS := {
		"highest_realm": "",
		"total_playtime_seconds": 0,
		"unlocked_cards": [],
		"unlocked_talents": [],
		"achievements": {},
		"statistics": {
			"total_battles": 0,
			"total_victories": 0,
			"total_deaths": 0,
			"highest_damage": 0,
		},
	}

	var path := _get_save_root() + "progression.dat"
	var read_result := _parse_json_file(path)
	if read_result["result"] == LoadResult.FILE_NOT_FOUND:
		return DEFAULTS.duplicate(true)

	if read_result["result"] != LoadResult.SUCCESS:
		# AC-009：损坏 JSON → push_error + 默认值 + 信号
		push_error("SaveLoadSystem: progression.dat 损坏——重置为默认值")
		progression_saved.emit(false)
		return DEFAULTS.duplicate(true)

	return read_result["data"]


## [b]创建战斗快照[/b]——在进入战斗前保存当前游戏状态。
##
## [b]参数[/b]: [param data] 已序列化的 GSM 数据（由调用方调用 [method GameStateManager.serialize] 获得）。[br]
## [b]返回[/b]: [code]true[/code] 表示快照保存成功。[br]
## [br][b]⚠️ AC-010[/b]: 内部调用 [method _build_save_container] + [method _atomic_write]。
func create_battle_snapshot(data: Dictionary) -> bool:
	var path := _save_path(SaveSlotType.SNAPSHOT)
	var container := _build_save_container(data, {})
	var result := _atomic_write(path, container)
	return result == SaveResult.SUCCESS


## [b]恢复战斗快照[/b]——读入战斗前保存的状态并立即清除快照文件。
##
## [b]返回[/b]: [code]{"result": LoadResult, "data": Dictionary}[/code]。[br]
## 文件存在且校验通过 → 返回 SUCCESS + 调用 [method clear_battle_snapshot] 删除文件。[br]
## [br][b]⚠️ AC-011[/b]: 成功后自动清除快照文件（防止重复恢复）。
## [br][b]⚠️ AC-012[/b]: 文件不存在 → 返回 [code]{"result": FILE_NOT_FOUND}[/code]。
func restore_battle_snapshot() -> Dictionary:
	var path := _save_path(SaveSlotType.SNAPSHOT)
	var read_result := _atomic_read(path)
	if read_result["result"] != LoadResult.SUCCESS:
		return read_result

	clear_battle_snapshot()
	return read_result


## [b]清除战斗快照[/b]——删除 snapshot/pre_battle.json 文件。
##
## [b]⚠️ AC-013[/b]: 静默执行——文件不存在时不报错，不发射信号。
func clear_battle_snapshot() -> void:
	var path := _save_path(SaveSlotType.SNAPSHOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
