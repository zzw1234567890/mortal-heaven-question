class_name CardArtResolver
extends RefCounted

## 卡面插画解析器：把一张卡的 card_id 映射到可用的贴图。[br]
## 查找顺序固定为「专属卡面 → 角色卡立绘 → 旧版角色卡插画」，都找不到返回 null，
## 由调用方画兜底样式（类型色块 + 类型图标）。[br]
## 已有资源优先：角色卡的立绘在 `assets/characters/portraits/` 里已经有了，
## 不再为它们单独生成卡面，直接复用。

## 专属卡面（`card_<card_id>.png`）。
const CARD_DIR: String = "res://assets/cards/illustrations/"
## 角色卡立绘（`char_<card_id>_portrait_full.png`），身份页也在用同一批。
const PORTRAIT_DIR: String = "res://assets/characters/portraits/"
## 旧版角色卡插画（`char_<card_id>_realm1.png`），只有林渊与苏剑鸣两张。
const LEGACY_DIR: String = "res://assets/cards/illustrations/character/"

## 负结果的缓存标记：避免每帧对一个没有图的 card_id 反复 stat 文件。
const MISSING: String = ""

static var _cache: Dictionary = {}


## 返回这张卡的卡面贴图；没有图时返回 null。[br]
## `p_card_id` 为空时同样返回 null，不抛错。
static func texture_for(p_card_id: StringName) -> Texture2D:
	var found := path_for(p_card_id)
	if found == MISSING:
		return null
	return load(found) as Texture2D


## 返回这张卡卡面的资源路径；没有图时返回空串。[br]
## 结果（含空串）会被缓存，适合在绘制里高频调用。
static func path_for(p_card_id: StringName) -> String:
	var key := String(p_card_id)
	if key.is_empty():
		return MISSING
	if _cache.has(key):
		return String(_cache[key])
	var resolved := _resolve(key)
	_cache[key] = resolved
	return resolved


## 清空缓存——测试与热重载用，生产代码不该调。
static func clear_cache() -> void:
	_cache.clear()


static func _resolve(p_key: String) -> String:
	var candidates: Array[String] = [
		CARD_DIR + "card_" + p_key + ".png",
		PORTRAIT_DIR + "char_" + p_key + "_portrait_full.png",
		LEGACY_DIR + "char_" + p_key + "_realm1.png",
	]
	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			return candidate
	return MISSING
