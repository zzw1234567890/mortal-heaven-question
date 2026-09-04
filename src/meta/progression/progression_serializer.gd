extends RefCounted
## ProgressionSerializer —— 跨局元进度序列化/初始化子模块（从 progression_system.gd 拆分）。
##
## 持有对 ProgressionSystem 父节点的引用，通过它访问 6 个域存储
## （_achievements / _talents / _card_gallery / _endings / _stats / _meta）
## 以及 _dirty / _save_load_override / _get_save_load_system 等。
##
## [br]来源: ADR-0012 §关键接口 initialize / serialize / deserialize。
## [br]Sprint 9 Story 6：从 progression_system.gd 拆分。

## 父节点引用——ProgressionSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 初始化 6 个空领域存储。
func init_empty_stores() -> void:
	_parent.set("_achievements", {})
	_parent.set("_talents", {
		"points_available": 0,
		"total_earned": 0,
		"unlocked": [],
		"equipped": [],
		"total_reincarnations": 0,
		"victories": 0,
	})
	_parent.set("_card_gallery", {})
	_parent.set("_endings", {})
	_parent.set("_stats", {})
	_parent.set("_meta", {
		"highest_realm_ever": "",
		"total_playtime_seconds": 0,
		"total_completions": 0,
	})


## 从 SaveLoadSystem 加载 progression 数据。[br]
## 测试可通过 _save_load_override 注入 mock。
func load_progression_data() -> Dictionary:
	var override: Node = _parent.get("_save_load_override")
	if override != null:
		return override.load_progression()
	if Engine.has_singleton("SaveLoadSystem") or true:
		var sl: Node = _parent.call("_get_save_load_system")
		if sl != null and sl.has_method("load_progression"):
			return sl.load_progression()
	return {}


## 从 progression.dat 的已解析 JSON 填充全部 6 个域。[br]
## 缺失字段 → 默认值填充（向前兼容）。
func initialize(data: Dictionary) -> void:
	_parent.set("_achievements", _safe_dict(data, "achievements", {}))
	_parent.set("_talents", _safe_dict(data, "talents", {
		"points_available": 0,
		"total_earned": 0,
		"unlocked": [],
		"equipped": [],
		"total_reincarnations": 0,
		"victories": 0,
	}))
	_parent.set("_card_gallery", _safe_dict(data, "card_gallery", _safe_dict(data, "unlocked_cards", {})))
	_parent.set("_endings", _safe_dict(data, "endings", {}))
	_parent.set("_stats", _safe_dict(data, "statistics", {}))
	_parent.set("_meta", _safe_dict(data, "meta", {
		"highest_realm_ever": _safe_str(data, "highest_realm", ""),
		"total_playtime_seconds": _safe_int(data, "total_playtime_seconds", 0),
		"total_completions": 0,
	}))
	_parent.set("_dirty", false)


## 返回全量 progression 数据的 JSON 兼容 Dictionary。[br]
## 不包含 _dirty / _batch_depth / _initialized_and_loaded 内部标志。
func serialize() -> Dictionary:
	return {
		"achievements": (_parent.get("_achievements") as Dictionary).duplicate(true),
		"talents": (_parent.get("_talents") as Dictionary).duplicate(true),
		"card_gallery": (_parent.get("_card_gallery") as Dictionary).duplicate(true),
		"endings": (_parent.get("_endings") as Dictionary).duplicate(true),
		"statistics": (_parent.get("_stats") as Dictionary).duplicate(true),
		"meta": (_parent.get("_meta") as Dictionary).duplicate(true),
	}


## 从 progression.dat 的已解析 JSON 填充全部 6 个域。[br]
## 缺失字段 → 默认值填充（向前兼容）。[br]
## [b]返回[/b]: true 表示反序列化成功。
func deserialize(data: Dictionary) -> bool:
	initialize(data)
	return true


# === 静态安全辅助 ==============================================================

## 安全读取字典中的 Dictionary 字段——缺失时返回默认值。
static func _safe_dict(data: Dictionary, key: String, default_val: Dictionary) -> Dictionary:
	if data.has(key):
		var val: Variant = data[key]
		if val is Dictionary:
			return val
	return default_val


## 安全读取字典中的 String 字段——缺失时返回默认值。
static func _safe_str(data: Dictionary, key: String, default_val: String) -> String:
	if data.has(key):
		var val: Variant = data[key]
		if val is String:
			return val
	return default_val


## 安全读取字典中的 int 字段——缺失时返回默认值。
static func _safe_int(data: Dictionary, key: String, default_val: int) -> int:
	if data.has(key):
		var val: Variant = data[key]
		if val is int or val is float:
			return int(val)
	return default_val
