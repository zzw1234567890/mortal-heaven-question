class_name BarkManager
extends RefCounted
## BarkManager —— bark（短对话气泡）播放管理器（RefCounted 服务类，ADR-0027）。
##
## Feature 层 RefCounted（非 Autoload）。管理角色 bark 池——[br]
## 每个角色一个 bark 池，触发时随机抽取，同一局不重复，[br]
## 池耗尽后重置并选择与上一句不同的 bark。[br]
## [br]来源: ADR-0027 §决策 5 + GDD dialogue-system.md §7 bark 池机制。


## bark 播放信号。
signal bark_played(character_id: String, text: String)

## bark 池——Dict[character_id → Array[String]]。
var _bark_pools: Dictionary = {}
## 剩余可用 bark——Dict[character_id → Array[String]]（抽取后移除）。
var _remaining: Dictionary = {}
## 上一条 bark 文本——用于重置后避免立即重复。
var _last_bark: Dictionary = {}  # character_id → String
## 播放历史记录。
var _bark_history: Array = []  # [{character_id, text, index}]


## 注册角色 bark 池。
func register_bark_pool(character_id: String, barks: Array) -> void:
	var pool: Array = []
	for bark: String in barks:
		pool.append(bark)
	_bark_pools[character_id] = pool
	_remaining[character_id] = pool.duplicate()
	_last_bark.erase(character_id)


## 播放 bark——从池中随机抽取一条文本。[br]
## 池耗尽时重置池并选择与上一句不同的 bark。[br]
## [b]返回[/b]: bark 文本（未注册角色或空池返回空字符串）。
func play_bark(character_id: String) -> String:
	# 未注册角色
	if not _bark_pools.has(character_id):
		return ""
	var full_pool: Array = _bark_pools[character_id]
	# 空池
	if full_pool.is_empty():
		return ""
	# 剩余池耗尽——重置
	var remaining: Array = _remaining[character_id]
	if remaining.is_empty():
		_remaining[character_id] = full_pool.duplicate()
		remaining = _remaining[character_id]
		# 如果重置后池只有 1 条且与上一条相同，无法避免重复，直接返回
		if remaining.size() == 1 and _last_bark.has(character_id) and remaining[0] == _last_bark[character_id]:
			var text0: String = remaining[0]
			_bark_history.append({"character_id": character_id, "text": text0, "index": _bark_history.size()})
			bark_played.emit(character_id, text0)
			return text0
	# 随机抽取——如果重置后，避免与上一条相同
	var candidates: Array = remaining.duplicate()
	if _last_bark.has(character_id) and candidates.size() > 1:
		var last_text: String = _last_bark[character_id]
		var filtered: Array = []
		for t: String in candidates:
			if t != last_text:
				filtered.append(t)
		candidates = filtered if not filtered.is_empty() else candidates
	# 随机抽取
	var pick_index: int = randi() % candidates.size()
	var text: String = candidates[pick_index]
	# 从 remaining 中移除
	var remove_index: int = remaining.find(text)
	if remove_index >= 0:
		remaining.remove_at(remove_index)
	_last_bark[character_id] = text
	_bark_history.append({"character_id": character_id, "text": text, "index": _bark_history.size()})
	bark_played.emit(character_id, text)
	return text


## 获取 bark 播放历史。[br]
## [b]返回[/b]: Array[{character_id, text, index}]。
func get_bark_history() -> Array:
	return _bark_history.duplicate(true)


## 获取角色剩余可用 bark 数量。
func get_remaining_count(character_id: String) -> int:
	if not _remaining.has(character_id):
		return 0
	return (_remaining[character_id] as Array).size()


## 重置角色 bark 池（清空历史+重置剩余池）。
func reset_pool(character_id: String) -> void:
	if _bark_pools.has(character_id):
		_remaining[character_id] = (_bark_pools[character_id] as Array).duplicate()
		_last_bark.erase(character_id)
