extends Node
## ProgressionSystem mock——测试 AchievementSystem 时替换 ProgressionSystem。

## 已注册的成就定义——测试验证。
var _registered_achievements: Dictionary = {}

## 已解锁成就集合——测试设置。
var _unlocked_achievements: Dictionary = {}

## unlock_achievement 调用记录。
var _unlock_calls: Array = []

## update_achievement_progress 调用记录。
var _progress_calls: Array = []


func register_achievement(ach_id: String, definition: Dictionary) -> void:
	_registered_achievements[ach_id] = definition
	if not _unlocked_achievements.has(ach_id):
		var target: int = int(definition.get("target", 0))
		_unlocked_achievements[ach_id] = {
			"unlocked": false,
			"progress": {"current": 0, "target": target} if target > 0 else null,
		}


func unlock_achievement(ach_id: String) -> Dictionary:
	_unlock_calls.append(ach_id)
	if not _unlocked_achievements.has(ach_id):
		return {"success": false, "reason": "unknown_id"}
	if bool(_unlocked_achievements[ach_id].get("unlocked", false)):
		return {"success": false, "reason": "already_unlocked"}
	_unlocked_achievements[ach_id]["unlocked"] = true
	return {"success": true, "reason": ""}


func update_achievement_progress(ach_id: String, increment: int) -> void:
	_progress_calls.append({"id": ach_id, "increment": increment})
	if not _unlocked_achievements.has(ach_id):
		return
	var ach: Dictionary = _unlocked_achievements[ach_id]
	var progress: Variant = ach.get("progress", null)
	if progress == null:
		# 无进度条成就——直接标记为解锁（达到 threshold=1 即解锁）
		ach["unlocked"] = true
		return
	var p: Dictionary = progress
	p["current"] = int(p.get("current", 0)) + increment
	ach["progress"] = p
	# 达到 target 自动标记
	if int(p["current"]) >= int(p["target"]) and not bool(ach.get("unlocked", false)):
		ach["unlocked"] = true


func get_achievement(ach_id: String) -> Dictionary:
	if not _unlocked_achievements.has(ach_id):
		return {"id": ach_id, "unlocked": false, "progress": null}
	var ach: Dictionary = _unlocked_achievements[ach_id].duplicate(true)
	ach["id"] = ach_id
	return ach


func get_achievements(category: String = "") -> Array:
	var result: Array = []
	for ach_id: String in _registered_achievements:
		var def: Dictionary = _registered_achievements[ach_id]
		if category != "" and str(def.get("category", "")) != category:
			continue
		var state: Dictionary = get_achievement(ach_id)
		state["id"] = ach_id
		result.append(state)
	# 已解锁在前，按 unlocked_at DESC
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_u: bool = bool(a.get("unlocked", false))
		var b_u: bool = bool(b.get("unlocked", false))
		if a_u and not b_u:
			return true
		if not a_u and b_u:
			return false
		if a_u and b_u:
			return str(a.get("unlocked_at", "")) > str(b.get("unlocked_at", ""))
		return false
	)
	return result
