extends RefCounted
## MapTerrainArt —— 探索节点图的[b]地形底图来源[/b]：舆图优先，风景插画兜底。[br]
##
## [b]为什么与 [MapCardArt] 分开[/b]：两者要的是两种东西。[br]
## · 地图选择页的卡片要的是[b]风景插画[/b]（有透视的山门、城池，用来「勾人」）；[br]
## · 探索节点图的背景要的是[b]舆图[/b]——正俯视的地形图，玩家在上面看路线与地名，
##   一张有近大远小的风景画当背景，节点像浮在照片上（反馈原话：「背景要完整地图，
##   而不是地图选择页面的场景图」）。[br]
## 两套图同目录、不同文件名（舆图统一 [code]map_<地图 ID>.png[/code]），因此这里只
## 做「按约定拼路径 + 存在就取，不存在退回风景插画」，不复制那份 17 张对照表。[br]
##
## [br][b]缺图不留黑[/b]：舆图缺失时退回 [MapCardArt] 的风景插画；两者都缺才返回
## [code]null[/code]，此时调用方仍会先铺底色，不会出现纯黑区块。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读资源，不读 GSM、不写任何玩法状态。[br]
##
## 来源: design/gdd/exploration-ui-system.md §2 节点图（需要一张能读路线的底图）、
## design/assets/specs/map-card-illustrations-assets.md（风景插画规格）、
## ADR-0031 §2。

## 舆图目录（与风景插画同目录）。
const TERRAIN_DIR: String = "res://assets/environments/maps/"
## 舆图文件名前缀：`map_<地图 ID>.png`。
const TERRAIN_PREFIX: String = "map_"
## 风景插画来源（舆图缺失时兜底）。
const MapCardArtScript := preload("res://src/ui/exploration/map_card_art.gd")

## 已解析过的纹理（同一张图会被地形层反复取，加载一次即可）。
static var _cache: Dictionary = {}


## 舆图路径；不存在时退回风景插画路径（可能为空串）。
static func path_of(p_map_id: StringName) -> String:
	var terrain_path: String = TERRAIN_DIR + TERRAIN_PREFIX + String(p_map_id) + ".png"
	if ResourceLoader.exists(terrain_path):
		return terrain_path
	return MapCardArtScript.path_of(p_map_id)


## 舆图纹理；都缺失时返回 null（调用方需容忍）。
static func texture_of(p_map_id: StringName) -> Texture2D:
	if _cache.has(p_map_id):
		return _cache[p_map_id] as Texture2D
	var path: String = path_of(p_map_id)
	var texture: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[p_map_id] = texture
	return texture


## 清空缓存（测试用：换资源后免得起新进程）。
static func clear_cache() -> void:
	_cache.clear()
