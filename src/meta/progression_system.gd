extends Node
## ProgressionSystem (Autoload #12) —— 跨局元进度系统。
##
## 拥有所有跨局元进度运行时数据（achievements / talents / card_gallery /
## endings / statistics / meta），使用直写缓存模型（API → 内部存储 →
## progression_updated 信号 → SaveLoadSystem 被动持久化）。
##
## 取代 GSM 的 progression.* 域所有权（ADR-0012）。
##
## [b]Story 7-1 范围[/b]：域存储 + initialize + serialize/deserialize + 脏标志。
##
## 来源: ADR-0012 §决策（架构图 + 关键接口 + 初始化策略 + 域存储声明）。


# === 信号 ====================================================================

## ProgressionSystem 初始化完成信号——_ready() 中数据填充后发射。[br]
## 特征系统在此信号后可安全查询 ProgressionSystem。
signal progression_initialized()

## 跨局数据变更信号——任何写入后发射。[br]
## SaveLoadSystem 监听此信号 → 被动持久化到 progression.dat。[br]
## [param domain] 变更的领域（achievements/talents/gallery/endings/stats/meta）。
signal progression_updated(domain: String)


# === 域存储（运行时，内存中）=================================================

## 成就域——Dict[String → Dictionary]。
var _achievements: Dictionary = {}
## 天赋域——Dict[String → Dictionary]。
var _talents: Dictionary = {}
## 卡牌图鉴域——Dict[String → bool]。
var _card_gallery: Dictionary = {}
## 结局域——Dict[String → Dictionary]。
var _endings: Dictionary = {}
## 统计域——Dict[String → int]。
var _stats: Dictionary = {}
## 元信息域——Dict[String → Variant]。
var _meta: Dictionary = {}


# === 内部标志 =================================================================

## 自上次保存后是否有变更。
var _dirty: bool = false
## 批量更新嵌套计数器——>0 时暂缓 progression_updated 信号。
var _batch_depth: int = 0
## 批量更新期间累积的变更域集合——batch_update_end 时一次性发射。
var _batch_pending_domains: Dictionary = {}
## 初始化完成标志——特征系统查询前检查此标志。
var _initialized_and_loaded: bool = false


# === 生命周期 =================================================================

## Autoload #12 _ready()——利用 Godot 顺序 _ready() 保证。[br]
## SaveLoadSystem (#4) 已完成 _ready()，直接调用 load_progression()。
func _ready() -> void:
	_init_empty_stores()
	var data: Dictionary = _load_progression_data()
	initialize(data)
	_initialized_and_loaded = true
	progression_initialized.emit()


## 初始化 6 个空领域存储。
func _init_empty_stores() -> void:
	_achievements = {}
	_talents = {
		"points_available": 0,
		"total_earned": 0,
		"unlocked": [],
		"equipped": [],
		"total_reincarnations": 0,
		"victories": 0,
	}
	_card_gallery = {}
	_endings = {}
	_stats = {}
	_meta = {
		"highest_realm_ever": "",
		"total_playtime_seconds": 0,
		"total_completions": 0,
	}


## 从 SaveLoadSystem 加载 progression 数据。[br]
## 测试可通过 _save_load_override 注入 mock。
func _load_progression_data() -> Dictionary:
	if _save_load_override != null:
		return _save_load_override.load_progression()
	if Engine.has_singleton("SaveLoadSystem") or true:
		var sl: Node = _get_save_load_system()
		if sl != null and sl.has_method("load_progression"):
			return sl.load_progression()
	return {}


## 从 progression.dat 的已解析 JSON 填充全部 6 个域。[br]
## 缺失字段 → 默认值填充（向前兼容）。
func initialize(data: Dictionary) -> void:
	_achievements = _safe_dict(data, "achievements", {})
	_talents = _safe_dict(data, "talents", {
		"points_available": 0,
		"total_earned": 0,
		"unlocked": [],
		"equipped": [],
		"total_reincarnations": 0,
		"victories": 0,
	})
	_card_gallery = _safe_dict(data, "card_gallery", _safe_dict(data, "unlocked_cards", {}))
	_endings = _safe_dict(data, "endings", {})
	_stats = _safe_dict(data, "statistics", {})
	_meta = _safe_dict(data, "meta", {
		"highest_realm_ever": _safe_str(data, "highest_realm", ""),
		"total_playtime_seconds": _safe_int(data, "total_playtime_seconds", 0),
		"total_completions": 0,
	})
	_dirty = false


# === 序列化（供 SaveLoadSystem 使用）==========================================

## 返回全量 progression 数据的 JSON 兼容 Dictionary。[br]
## 不包含 _dirty / _batch_depth / _initialized_and_loaded 内部标志。
func serialize() -> Dictionary:
	return {
		"achievements": _achievements.duplicate(true),
		"talents": _talents.duplicate(true),
		"card_gallery": _card_gallery.duplicate(true),
		"endings": _endings.duplicate(true),
		"statistics": _stats.duplicate(true),
		"meta": _meta.duplicate(true),
	}


## 从 progression.dat 的已解析 JSON 填充全部 6 个域。[br]
## 缺失字段 → 默认值填充（向前兼容）。[br]
## [b]返回[/b]: true 表示反序列化成功。
func deserialize(data: Dictionary) -> bool:
	initialize(data)
	return true


## 成就定义注册表——由 AchievementSystem 在运行时注册。
var _achievement_defs: Dictionary = {}


# === 脏标志 ===================================================================

## 返回 _dirty 标志——SaveLoadSystem 用于确定是否需要写入。
func has_unsaved_changes() -> bool:
	return _dirty


## SaveLoadSystem 在成功写入后调用——设置 _dirty = false。
func mark_saved() -> void:
	_dirty = false


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

## 天赋定义注册表——由 ReincarnationTalentSystem 初始化时调用。
var _talent_defs: Dictionary = {}

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


# === endings 领域 API =========================================================

## 结局解锁信号——GalleryUI 监听。
signal ending_unlocked_signal(ending_id: String, total: int)

## 解锁结局——原子写入 + 递增 total_completions + 发射信号。
func unlock_ending(ending_id: String, chapter_path: Dictionary, identity_id: String, realm: String) -> Dictionary:
	if _endings.has(ending_id) and bool(_endings[ending_id].get("unlocked", false)):
		return {"success": false, "reason": "already_unlocked"}
	_endings[ending_id] = {
		"id": ending_id,
		"unlocked": true,
		"unlocked_at": Time.get_datetime_string_from_system(false, true),
		"chapter_path": chapter_path.duplicate(true),
		"identity": identity_id,
		"realm": realm,
	}
	# 内置递增 total_completions
	_meta["total_completions"] = int(_meta.get("total_completions", 0)) + 1
	_mark_dirty_and_emit("endings")
	_mark_dirty_and_emit("meta")
	ending_unlocked_signal.emit(ending_id, int(_meta["total_completions"]))
	return {"success": true, "reason": ""}

## 返回已解锁 ending_id 的数组。
func get_unlocked_endings() -> Array:
	var result: Array = []
	for ending_id: String in _endings:
		if bool(_endings[ending_id].get("unlocked", false)):
			result.append(ending_id)
	return result

## 检查结局是否已解锁。
func has_ending(ending_id: String) -> bool:
	return _endings.has(ending_id) and bool(_endings[ending_id].get("unlocked", false))

## 获取结局详情。
func get_ending_detail(ending_id: String) -> Dictionary:
	if not _endings.has(ending_id):
		return {"id": ending_id, "unlocked": false, "unlocked_at": ""}
	return _endings[ending_id].duplicate(true)


# === gallery 领域 API ========================================================

## 卡牌发现信号——GalleryUI 监听。
signal card_discovered(card_id: String, total: int)

## 标记卡牌已发现——去重，已发现不发射信号。
func mark_card_discovered(card_id: String) -> void:
	if _card_gallery.has(card_id) and bool(_card_gallery[card_id]):
		return
	_card_gallery[card_id] = true
	_mark_dirty_and_emit("gallery")
	card_discovered.emit(card_id, _card_gallery.size())

## 检查卡牌是否已发现。
func is_card_discovered(card_id: String) -> bool:
	return _card_gallery.has(card_id) and bool(_card_gallery[card_id])

## 获取卡牌图鉴统计。
func get_card_gallery_stats() -> Dictionary:
	var discovered: int = _card_gallery.size()
	var total: int = 222
	var pct: float = float(discovered) / float(total) * 100.0 if total > 0 else 0.0
	return {
		"total_discovered": discovered,
		"total_cards": total,
		"completion_pct": pct,
	}


# === stats 领域 API ==========================================================

## 递增统计值（跨局累计）。
func increment_stat(key: String, amount: int = 1) -> void:
	_stats[key] = int(_stats.get(key, 0)) + amount
	_mark_dirty_and_emit("stats")

## 设置绝对值统计——仅在 > 当前值时写入。
func set_stat(key: String, value: int) -> void:
	var current: int = int(_stats.get(key, 0))
	if value > current:
		_stats[key] = value
		_mark_dirty_and_emit("stats")

## 获取统计值。
func get_stat(key: String) -> int:
	return int(_stats.get(key, 0))


# === meta 领域 API ===========================================================

## 可写入的 meta key 白名单。
const _META_KEYS: Array = [
	"highest_realm_ever",
	"total_reincarnations",
	"total_playtime_seconds",
	"total_completions",
]

## 获取 meta 值。
func get_meta_value(key: String) -> Variant:
	return _meta.get(key, null)

## 设置 meta 值——仅受限 key 可写入。
func set_meta_value(key: String, value: Variant) -> void:
	if key in _META_KEYS:
		_meta[key] = value
		_mark_dirty_and_emit("meta")


# === 内部辅助 =================================================================

## 标记数据为脏 + 发射 progression_updated 信号（受批量更新控制）。
func _mark_dirty_and_emit(domain: String) -> void:
	_dirty = true
	if _batch_depth > 0:
		_batch_pending_domains[domain] = true
	else:
		progression_updated.emit(domain)


## SaveLoadSystem 引用——测试注入优先。
var _save_load_override: Node = null


## 获取 SaveLoadSystem 引用——注入优先，否则 Autoload #4。
func _get_save_load_system() -> Node:
	if _save_load_override != null:
		return _save_load_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	for i: int in range(root.get_child_count()):
		var child: Node = root.get_child(i)
		if child != null and child.name == &"SaveLoadSystem":
			return child
	return null


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
