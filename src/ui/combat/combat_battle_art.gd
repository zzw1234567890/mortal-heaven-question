extends TextureRect
## 战斗背景画——战斗发生在哪张图上，就铺那张图的舆图当底。[br]
## [br][b]为什么不是纯色[/b]：老板 2026-11-28 反馈「战斗页面要有背景图片，用地图场景
## 或者节点相关图片」。战斗是全屏界面，整片深色在没有 3D 场景的卡牌战斗里太寡淡。[br]
## [br][b]图从哪来[/b]：[code]MapTerrainArt.texture_of[/code] 与节点图共用同一套取值
## 顺序（先 [code]map_<地图 ID>.png[/code] 舆图，缺了退回地图选择页那张风景插画），
## 所以「同一条路线上节点图与战斗背景是同一幅画」，不会一边山水一边舆图。[br]
## [br][b]为什么在 [method Node._ready] 里读[/b]：走 Autoload 的
## [code]GameStateManager.exploration.current_map[/code]，[method Node._init] 阶段
## 场景树还没挂好（Autoload 取不到）。晚一帧上色对背景无感——它不是底色。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读 GSM 与资产，只写自己的
## [member TextureRect.texture]；取不到图就 [code]visible = false[/code]，让下层的
## [code]AppBackdrop[/code] 深色兜底，绝不自己造色。
##
## 来源: 老板 2026-11-28 反馈；design/art/art-bible.md §4.7.1（背景层级）。

const TerrainArtScript: GDScript = preload("res://src/ui/exploration/map_terrain_art.gd")

## GSM 里存当前地图 ID 的域与键（[code]gsm_exploration_writes.set_exploration_map[/code] 写的就是它）。
const GSM_SINGLETON: StringName = &"GameStateManager"
const EXPLORATION_DOMAIN: StringName = &"exploration"
const KEY_CURRENT_MAP: StringName = &"current_map"


func _ready() -> void:
	texture = TerrainArtScript.texture_of(current_map())

	# 取不到图（未进过探索 / 该图没有插画）时不占位——下层深色背板照常露出来。
	visible = texture != null
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 当前地图 ID；脱离项目树（探针、纯单元测试）时返回空串。
static func current_map() -> StringName:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return &""
	var gsm: Node = tree.root.get_node_or_null(NodePath(GSM_SINGLETON))
	if gsm == null:
		return &""
	var domain: Variant = gsm.get(String(EXPLORATION_DOMAIN))
	# GSM 的 exploration 域是 [b]Dictionary[/b]（[code]gsm_exploration_writes[/code] 走
	# [code]_gsm.exploration.current_map = …[/code] 点号取值）——不是 Resource，不能一律当 Object。
	# 注意：[code]as Dictionary[/code] 是空操作（内建类型不走 as 转换），必须赋给带类型的局部变量。
	if domain is Dictionary:
		var dict: Dictionary = domain
		var raw: Variant = dict.get(String(KEY_CURRENT_MAP))
		return &"" if raw == null else StringName(str(raw))
	if domain is Object:
		return StringName(str((domain as Object).get(String(KEY_CURRENT_MAP))))
	return &""
