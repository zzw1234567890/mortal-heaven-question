extends "res://src/meta/progression_system_growth.gd"
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
## [b]本层职责[/b]（链尾——记录面）：[b]结局 / 图鉴 / 统计 / 元信息[/b]四张「玩家战绩」域。
## [method unlock_ending]（原子写入 + 递增 [code]total_completions[/code] + 发信号）/
## [method get_unlocked_endings] / [method has_ending] / [method get_ending_detail]、
## [method mark_card_discovered]（去重幂等）/ [method is_card_discovered] /
## [method get_card_gallery_stats]（总数 222 固定口径）、[method increment_stat] /
## [method set_stat]（只升不降）/ [method get_stat]、[method get_meta_value] /
## [method set_meta_value]（受 [constant _META_KEYS] 白名单限制）。
## [signal ending_unlocked_signal] / [signal card_discovered] 两条记录域信号由本段方法发射、
## 在链首段声明（基段声明可在派生段 [code]emit[/code]）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  progression_system_contract.gd  [/code] ← 声明面：6 信号 / 14 字段 / 1 常量表 / 0 方法[br]
## [code]  progression_system_lifecycle.gd [/code] ← 信号与生命周期面：_ready / 序列化 / 脏标志 / 内部辅助[br]
## [code]  progression_system_growth.gd    [/code] ← 成长面：achievements / talents / 批量更新[br]
## [code]  progression_system.gd           [/code] ← 本层：记录面（endings / gallery / stats / meta）[br]
##
## [b]链序不是自由选择[/b]：GDScript 解析期要求被调方在[b]本段或祖先段[/b]——祖先段用裸
## 标识符引用后代段成员会直接报 [code]Function "xxx()" not found in base self[/code]。
## 故 [method _mark_dirty_and_emit]（每个域写入都要调）落在第 2 段；[method _ready]（要调
## 惰性获取器与全部域初始化）也必须在靠前的段，不能落链尾之后的任何位置。[br]
## [b]路径即契约[/b]：[code]project.godot[/code] 的 [code][autoload][/code] 把
## [code]ProgressionSystem[/code] 绑在 [code]res://src/meta/progression_system.gd[/code]
## 这一串字符上，另有 5 个单元测试文件按同一路径 [code]preload[/code] 取类，故本文件名逐字不动
## （本类[b]不声明[/b] [code]class_name[/code]）。[br]
## 守卫用例：[code]tests/unit/meta/test_progression_public_face_lock.gd[/code]。
##
## 来源: ADR-0012 §决策（架构图 + 关键接口 + 初始化策略 + 域存储声明）。

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

## 获取 meta 值。
func get_meta_value(key: String) -> Variant:
	return _meta.get(key, null)

## 设置 meta 值——仅受限 key 可写入。
func set_meta_value(key: String, value: Variant) -> void:
	if key in _META_KEYS:
		_meta[key] = value
		_mark_dirty_and_emit("meta")
