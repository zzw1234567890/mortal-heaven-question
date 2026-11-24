extends "res://src/foundation/save_load/migration.gd"
## SaveLoadSystem 槽位层 —— [b]meta.json 与槽位查询[/b]。[br]
## [br][b]本层职责[/b]：「玩家看到的那张槽位列表」从哪来——meta.json 的读写
## （[method _load_meta_json] / [method _write_meta_json] / [method _update_meta_json] /
## [method _mark_slot_empty]）、槽位键的拼法（[method _slot_key]），以及三个面向 UI 的
## 查询（[method list_slots] / [method get_slot_meta] / [method delete_save]）。[br]
## [br][b]为什么单独一层[/b]：meta.json 是[b]展示用的旁路数据[/b]——它只记「哪个槽位
## 存在、名字/境界/时长是多少」，不参与读档正确性（读档读的是存档文件本身），
## 且写入刻意不走原子管线（丢了就丢了，重存一次即恢复）。这与「存档内容本身」
## 是两种可靠性要求，混在一层会让读者误以为 meta.json 也是关键数据。[br]
## [br][b]成员名逐字保留[/b]：Story 004 的验收（AC-005 ~ AC-007、AC-016）与主菜单侧的
## [code]MainMenuLogic._slot_key[/code]（同口径单测锁定同源）都直接引用这些名字。[br]
## [br]来源: design/gdd/game-state-manager.md §存档、ADR-0002 §元数据旁路。

## 由槽位类型和编号生成唯一键——用于 meta.json 中 slots 字典的键。
##
## [b]格式[/b]: [code]"autosave_0"[/code] / [code]"manual_1"[/code] / [code]"snapshot_0"[/code]。[br]
## 注意：MANUAL 使用 slot_id 区分 3 个槽位（1/2/3）。
func _slot_key(slot_type: SaveSlotType, slot_id: int) -> String:
	match slot_type:
		SaveSlotType.AUTOSAVE:
			return "autosave_0"
		SaveSlotType.MANUAL:
			return "manual_%d" % slot_id
		SaveSlotType.SNAPSHOT:
			return "snapshot_0"
		_:
			return "unknown"


## 加载 meta.json——文件不存在或解析失败时返回带空 slots 字典的默认值。
func _load_meta_json() -> Dictionary:
	var meta_path := _get_save_root() + "meta.json"
	var result := _parse_json_file(meta_path)
	if result["result"] != LoadResult.SUCCESS:
		return {"slots": {}}
	return result["data"]


## 写入 meta.json——直接覆盖（非关键数据，不使用原子写入管线）。
## [br]失败时调用 [method push_error] 记录。
func _write_meta_json(data: Dictionary) -> void:
	var meta_path := _get_save_root() + "meta.json"
	_ensure_dir(meta_path)
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveLoadSystem: 无法写入 meta.json")
		return
	var json_str := _serialize_to_json(data)
	f.store_string(json_str)
	f.close()


## 更新 meta.json 中指定槽位的元信息——加载 → 修改 → 写回。
func _update_meta_json(slot_type: SaveSlotType, slot_id: int, meta: Dictionary) -> void:
	var meta_data := _load_meta_json()
	if not meta_data.has("slots"):
		meta_data["slots"] = {}
	var key := _slot_key(slot_type, slot_id)
	meta_data["slots"][key] = {
		"name": meta.get("player_name", ""),
		"timestamp": Time.get_datetime_string_from_system(true),
		"realm": meta.get("realm", ""),
		"playtime": meta.get("playtime_seconds", 0),
		"exists": true,
	}
	_write_meta_json(meta_data)


## 标记槽位为空——删除存档后更新 meta.json 对应条目。
func _mark_slot_empty(slot_type: SaveSlotType, slot_id: int) -> void:
	var meta_data := _load_meta_json()
	if not meta_data.has("slots"):
		meta_data["slots"] = {}
	var key := _slot_key(slot_type, slot_id)
	meta_data["slots"][key] = {"exists": false}
	_write_meta_json(meta_data)


## [b]删除存档[/b]——删除指定槽位的存档文件并更新 meta.json。
##
## [b]返回[/b]: [code]true[/code]——文件不存在也返回 true（幂等：视同"已删除"）。[br]
## [br][b]⚠️ AC-005[/b]: 文件不存在 → 返回 true（不视为错误）；文件存在但删除失败 → 返回 false。
func delete_save(slot_type: SaveSlotType, slot_id: int = 0) -> bool:
	var path := _save_path(slot_type, slot_id)
	if not FileAccess.file_exists(path):
		_mark_slot_empty(slot_type, slot_id)
		return true

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_error("SaveLoadSystem: 删除存档失败: %s (err=%d)" % [path, err])
		return false

	_mark_slot_empty(slot_type, slot_id)
	return true


## [b]获取槽位元信息[/b]——仅读取存档容器的 meta 子字典，不读取 game_state。
##
## [b]参数[/b]: [param slot_type] 槽位类型；[param slot_id] 槽位编号。[br]
## [b]返回[/b]: 短格式 Dictionary——[code]{"exists": true/false, "name": "...",
##          "timestamp": "...", "realm": "...", "playtime": ...}[/code]。[br]
## 文件不存在时返回 [code]{"exists": false}[/code]。[br]
## [br][b]⚠️ AC-006[/b]: 不读取 game_state——仅解析存档容器的 meta 和顶层元数据。
func get_slot_meta(slot_type: SaveSlotType, slot_id: int = 0) -> Dictionary:
	var path := _save_path(slot_type, slot_id)
	var read_result := _atomic_read(path)
	if read_result["result"] != LoadResult.SUCCESS:
		return {"exists": false}

	var data: Dictionary = read_result["data"]
	var meta: Dictionary = data.get("meta", {})
	return {
		"exists": true,
		"name": meta.get("player_name", ""),
		"timestamp": data.get("timestamp", ""),
		"realm": meta.get("realm", ""),
		"playtime": data.get("playtime_seconds", 0),
	}


## [b]列出所有槽位[/b]——从 meta.json 读取全部槽位状态。
##
## [b]返回[/b]: [code]Array[Dictionary][/code]，每项含 [code]slot_type[/code] / [code]slot_id[/code] /
##          [code]exists[/code] / [code]name[/code] / [code]timestamp[/code] /
##          [code]realm[/code] / [code]playtime[/code]。[br]
## [br][b]⚠️ AC-007[/b]: 从 meta.json 而非扫描文件系统读取——仅返回已知槽位。
func list_slots() -> Array[Dictionary]:
	var meta_data := _load_meta_json()
	var slots: Dictionary = meta_data.get("slots", {})
	var result: Array[Dictionary] = []

	# 遍历所有已知槽位：autosave_0, manual_1-3, snapshot_0
	var known_keys := ["autosave_0", "manual_1", "manual_2", "manual_3", "snapshot_0"]
	for key in known_keys:
		var slot_info: Dictionary = slots.get(key, {"exists": false})
		var slot_type: int = SaveSlotType.AUTOSAVE
		var slot_id: int = 0
		if key.begins_with("manual_"):
			slot_type = SaveSlotType.MANUAL
			slot_id = int(key.trim_prefix("manual_"))
		elif key == "snapshot_0":
			slot_type = SaveSlotType.SNAPSHOT

		result.append({
			"slot_type": slot_type,
			"slot_id": slot_id,
			"exists": slot_info.get("exists", false),
			"name": slot_info.get("name", ""),
			"timestamp": slot_info.get("timestamp", ""),
			"realm": slot_info.get("realm", ""),
			"playtime": slot_info.get("playtime", 0),
		})

	return result
