extends "res://src/meta/progression_system_lifecycle.gd"
## ProgressionSystem 成长面（继承链第 3 段）——[b]成就 + 天赋 + 批量更新[/b]。
##
## [b]本层职责[/b]：两条「玩家变强」的域——跨局累计的 [b]achievements[/b] 与轮回点消费的
## [b]talents[/b]，外加两条领域信号与批量事务。[br]
##   · [b]achievements[/b]——[method register_achievement]（外部系统注册定义 + 懒建运行时条目）、
##     [method unlock_achievement]（仅未解锁时成功）、[method update_achievement_progress]
##     （跨局累计，达标自动解锁）、[method get_achievement] / [method get_achievements]
##     （已解锁在前、按 [code]unlocked_at[/code] 降序）；[br]
##   · [b]talents[/b]——[method register_talent] / [method get_talent_points] /
##     [method add_talent_points]（轮回结算加点）/ [method purchase_talent]（扣点 + 前置校验）/
##     [method grant_talent]（不扣点、幂等）/ [method get_talent_tree_state] /
##     [method set_equipped_talents]（槽位校验）/ [method get_active_slot_count]
##     （[code]5 + floor(unlocked / 4)[/code]）；[br]
##   · [b]批量事务[/b]——[method batch_update_begin] / [method batch_update_end]：
##     嵌套计数归零时按域去重补发 [signal progression_updated]（结算链路一次事务只落一次盘）。[br]
## [b]两条成长域信号在第 3 段发射、在链首段声明[/b]（基段声明可在派生段 emit）：
## [signal achievement_unlocked] 由 [method unlock_achievement] 发，
## [signal talent_purchased] 由 [method purchase_talent] 发。
##
## 来源: ADR-0012 §关键接口（achievements / talents / 批量更新领域）、
## production/epics/progression-system/story-002-achievements-api.md、story-003-talents-api.md。

# === achievements 领域 API ====================================================

## 成就解锁信号——UI 监听此信号展示解锁通知。
signal achievement_unlocked(ach_id: String)

## 注册成就定义——由 AchievementSystem 初始化时调用。
func register_achievement(ach_id: String, definition: Dictionary) -> void:
	_achievement_defs[ach_id] = definition
	if not _achievements.has(ach_id):
		var target: int = int(definition.get("target", 0))
		_achievements[ach_id] = {
			"id": ach_id,
			"unlocked": false,
			"unlocked_at": "",
			"progress": {"current": 0, "target": target} if target > 0 else null,
		}


## 解锁成就——仅在未解锁时成功。写入 unlocked_at 时间戳 + 发射信号。
func unlock_achievement(ach_id: String) -> Dictionary:
	if not _achievement_defs.has(ach_id):
		return {"success": false, "reason": "unknown_id"}
	if not _achievements.has(ach_id):
		register_achievement(ach_id, _achievement_defs[ach_id])
	var ach: Dictionary = _achievements[ach_id]
	if bool(ach.get("unlocked", false)):
		return {"success": false, "reason": "already_unlocked"}
	ach["unlocked"] = true
	ach["unlocked_at"] = Time.get_datetime_string_from_system(false, true)
	_achievements[ach_id] = ach
	_mark_dirty_and_emit("achievements")
	achievement_unlocked.emit(ach_id)
	return {"success": true, "reason": ""}


## 获取单个成就状态。
func get_achievement(ach_id: String) -> Dictionary:
	if not _achievements.has(ach_id):
		return {"id": ach_id, "unlocked": false, "unlocked_at": "", "progress": null}
	return _achievements[ach_id].duplicate(true)


## 获取成就列表——按 category 过滤，已解锁按 unlocked_at DESC 排序。
func get_achievements(category: String = "") -> Array:
	var result: Array = []
	for ach_id: String in _achievement_defs:
		var ach: Dictionary = get_achievement(ach_id)
		if category != "" and str(_achievement_defs[ach_id].get("category", "")) != category:
			continue
		result.append(ach)
	# 排序——已解锁在前，按 unlocked_at DESC
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_unlocked: bool = bool(a.get("unlocked", false))
		var b_unlocked: bool = bool(b.get("unlocked", false))
		if a_unlocked and not b_unlocked:
			return true
		if not a_unlocked and b_unlocked:
			return false
		if a_unlocked and b_unlocked:
			return str(a.get("unlocked_at", "")) > str(b.get("unlocked_at", ""))
		return false
	)
	return result


## 递增成就进度（跨局累计）——达到 target 时自动解锁。
func update_achievement_progress(ach_id: String, increment: int) -> void:
	if not _achievement_defs.has(ach_id):
		return
	if not _achievements.has(ach_id):
		register_achievement(ach_id, _achievement_defs[ach_id])
	var ach: Dictionary = _achievements[ach_id]
	var progress: Variant = ach.get("progress", null)
	if progress == null:
		return
	var p: Dictionary = progress
	p["current"] = int(p.get("current", 0)) + increment
	ach["progress"] = p
	_achievements[ach_id] = ach
	_mark_dirty_and_emit("achievements")
	# 达到 target 自动解锁
	if int(p["current"]) >= int(p["target"]) and not bool(ach.get("unlocked", false)):
		unlock_achievement(ach_id)


# === talents 领域 API =========================================================

## 天赋购买信号——UI 监听此信号刷新天赋树。
signal talent_purchased(talent_id: String, points_remaining: int)

## 注册天赋定义。
func register_talent(talent_id: String, definition: Dictionary) -> void:
	_talent_defs[talent_id] = definition

## 获取当前可用轮回点。
func get_talent_points() -> int:
	return int(_talents.get("points_available", 0))

## 添加轮回点——轮回结算时调用。
func add_talent_points(amount: int) -> void:
	_talents["points_available"] = int(_talents.get("points_available", 0)) + amount
	_talents["total_earned"] = int(_talents.get("total_earned", 0)) + amount
	_mark_dirty_and_emit("talents")

## 购买天赋——扣除轮回点 + 解锁 + 发射信号。
func purchase_talent(talent_id: String) -> Dictionary:
	if not _talent_defs.has(talent_id):
		return {"success": false, "reason": "unknown_id"}
	var unlocked: Array = _talents.get("unlocked", [])
	if unlocked.has(talent_id):
		return {"success": false, "reason": "already_unlocked"}
	var cost: int = int(_talent_defs[talent_id].get("cost", 0))
	var points: int = int(_talents.get("points_available", 0))
	if points < cost:
		return {"success": false, "reason": "insufficient_points"}
	# 检查前置条件
	var prereq: String = str(_talent_defs[talent_id].get("prerequisite", ""))
	if not prereq.is_empty() and not unlocked.has(prereq):
		return {"success": false, "reason": "prerequisite_locked"}
	# 扣除点数 + 写入 unlocked
	_talents["points_available"] = points - cost
	unlocked.append(talent_id)
	_talents["unlocked"] = unlocked
	_mark_dirty_and_emit("talents")
	talent_purchased.emit(talent_id, int(_talents["points_available"]))
	return {"success": true, "reason": ""}

## 直接授予天赋——不扣点，幂等。用于 EventSystem GAIN_TALENT 和特殊奖励。
func grant_talent(talent_id: String) -> Dictionary:
	if not _talent_defs.has(talent_id):
		return {"success": false, "reason": "unknown_id"}
	var unlocked: Array = _talents.get("unlocked", [])
	if unlocked.has(talent_id):
		return {"success": true, "reason": "already_unlocked"}
	unlocked.append(talent_id)
	_talents["unlocked"] = unlocked
	_mark_dirty_and_emit("talents")
	return {"success": true, "reason": ""}

## 获取天赋树完整状态。
func get_talent_tree_state() -> Dictionary:
	return {
		"unlocked": (_talents.get("unlocked", []) as Array).duplicate(),
		"equipped": (_talents.get("equipped", []) as Array).duplicate(),
		"points": int(_talents.get("points_available", 0)),
		"slots": get_active_slot_count(),
	}

## 设置装备的天赋——校验槽位数。
func set_equipped_talents(ids: Array) -> Dictionary:
	var max_slots: int = get_active_slot_count()
	if ids.size() > max_slots:
		return {"success": false, "reason": "slot_exceeded"}
	# 校验所有 ID 已解锁
	var unlocked: Array = _talents.get("unlocked", [])
	for id: String in ids:
		if not unlocked.has(id):
			return {"success": false, "reason": "not_unlocked"}
	_talents["equipped"] = ids.duplicate()
	_mark_dirty_and_emit("talents")
	return {"success": true, "reason": ""}

## 获取当前可用槽位数——N = 5 + floor(unlocked_count / 4)。
func get_active_slot_count() -> int:
	var unlocked_count: int = (_talents.get("unlocked", []) as Array).size()
	return 5 + int(unlocked_count / 4)


# === 批量更新 API ===========================================================

## 暂缓 progression_updated 信号发射。嵌套调用增加计数器。
func batch_update_begin() -> void:
	_batch_depth += 1


## 计数器归零时一次性发射所有累积域的 progression_updated 信号。
func batch_update_end() -> void:
	if _batch_depth > 0:
		_batch_depth -= 1
	if _batch_depth == 0 and _batch_pending_domains.size() > 0:
		for domain: String in _batch_pending_domains:
			progression_updated.emit(domain)
		_batch_pending_domains.clear()
