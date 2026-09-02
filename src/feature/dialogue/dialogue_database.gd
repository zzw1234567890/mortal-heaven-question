class_name DialogueDatabase
extends RefCounted
## DialogueDatabase —— 对话树数据访问层（RefCounted 服务类，ADR-0027）。
##
## Feature 层 RefCounted（非 Autoload）。按需加载对话树 JSON 文件，[br]
## 内存缓存避免重复解析。由触发对话的系统按需实例化。[br]
## [br]来源: ADR-0027 §决策 2 + GDD dialogue-system.md §1。


## 对话树缓存——Dict[tree_id → Dictionary]。
var _tree_cache: Dictionary = {}

## 对话树注册表——tree_id → 文件路径映射。测试可直接注入。
var _tree_registry: Dictionary = {}


## 设置对话树注册表（tree_id → path 或 tree_data）。
func set_registry(registry: Dictionary) -> void:
	_tree_registry = registry

## 注册单个对话树（直接内联数据，供测试用）。
func register_tree(tree_id: String, tree_data: Dictionary) -> void:
	_tree_cache[tree_id] = tree_data.duplicate(true)
	_tree_registry[tree_id] = "inline"


## 检查对话树是否存在。
func has_tree(tree_id: String) -> bool:
	return _tree_registry.has(tree_id) or _tree_cache.has(tree_id)


## 获取对话树——优先从缓存读取，否则从注册表加载。
func get_tree(tree_id: String) -> Dictionary:
	# 缓存命中
	if _tree_cache.has(tree_id):
		return _tree_cache[tree_id]
	# 注册表中存在——检查是否为内联数据
	if _tree_registry.has(tree_id):
		var entry: Variant = _tree_registry[tree_id]
		if entry is Dictionary:
			_tree_cache[tree_id] = entry.duplicate(true)
			return _tree_cache[tree_id]
		if entry is String:
			# 文件路径——按需加载 JSON
			var path: String = entry
			var loaded: Dictionary = _load_json(path)
			if not loaded.is_empty():
				_tree_cache[tree_id] = loaded
				return loaded
	return {}


## 获取所有已注册的对话树 ID。
func get_all_tree_ids() -> Array:
	var ids: Array = []
	for key: String in _tree_registry:
		ids.append(key)
	for key: String in _tree_cache:
		if not ids.has(key):
			ids.append(key)
	return ids


## 从 JSON 文件加载对话树。
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueDatabase: 对话文件不存在: %s" % path)
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("DialogueDatabase: JSON 解析错误 %s: %s" % [path, json.get_error_message()])
		return {}
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("DialogueDatabase: %s 顶层不是 Dictionary" % path)
		return {}
	return data
