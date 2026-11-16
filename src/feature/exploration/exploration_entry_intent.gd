extends RefCounted
## ExplorationEntryIntent —— 「这一次进探索要干什么」的跨场景意图（RefCounted 静态类）。[br]
## [br][b]为什么需要[/b]：探索场景是「新开局」「读档续玩」「从别处回来」三条路径的
## 共同终点，而它在挂载那一刻无从分辨自己是被谁叫来的——[br]
##   · [b]新开局[/b]（主菜单 → 身份选择 → 探索）要[b]直接落到第一张图[/b]；[br]
##   · [b]读档续玩[/b]（主菜单 → 探索）要[b]回到存档里那张图[/b]；[br]
##   · 其余（占位场景/暂停菜单回来）应[b]停在选图界面[/b]。[br]
## 中间的发起方（主菜单、身份选择）都不该在导航前抢着写探索状态（ADR-0031 §2 零状态
## 所有权——状态写入归 Feature 层），所以「想干什么」只能作为一份跨场景[b]意图[/b]
## 传递。项目内既有口径即 [code]static var[/code] 缓存（同
## [code]CombatLaunchContext[/code] / [code]MapClearView[/code] / [code]CombatResultView[/code]）。[br]
## [br][b]一次性[/b]：[method take_entry_mode] 取走即清——同一份意图不会让玩家进两次图，
## 也不会残留到「下一次从暂停菜单回到探索」时冒出来。[br]
## [br][b]只持一个枚举[/b]：地图 ID 与境界由探索场景在进图那刻按探明表 / GSM 现取
## （本模块连「第一张图是哪张」都不缓存，见 [method first_map_id]）。[br]
## [br][b]与 ADR-0005 的分工[/b]：转场请求仍必须经
## [code]SceneManager.request_scene_change[/code]；本模块只回答「到了之后做什么」，
## 不碰导航。[br]
##
## 来源: ADR-0031 §2 零状态所有权、ADR-0005（场景切换唯一仲裁）、
## design/gdd/exploration-system.md §1（探明表顺序 = 剧情顺序）、
## design/gdd/main-menu-system.md（新游戏 / 继续游戏 / 读档三条路径）。

## 地图配置目录——「第一张图」不在本模块硬编码，取探明表首项（表序即剧情序）。
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")


## 进入探索的意图类型——探索场景挂载时消费。
enum EntryMode {
	NONE = 0,       ## 无意图——停在选图界面（默认；从暂停菜单等路径回来）
	FIRST_MAP = 1,  ## 新开局——直接进第一张图并生成 DAG
	RESUME = 2,     ## 读档续玩——按存档里的导航状态回到上次那张图
}

## 待消费的意图（[constant EntryMode.NONE] = 没有）。
static var _mode: int = EntryMode.NONE


## 请求「新开局，直接进第一张图」——身份选择开局成功后调用。[br]
## [br][b]不在这里导航[/b]：导航仍由调用方经 SceneManager 发起（ADR-0005）。
static func request_new_run() -> void:
	_mode = EntryMode.FIRST_MAP


## 请求「读档续玩，回到存档里那张图」——主菜单读档成功后调用。
static func request_resume() -> void:
	_mode = EntryMode.RESUME


## 取走本次进入意图（取后清空——见文件头「一次性」）。[br]
## [br][b]返回[/b]：[enum EntryMode] 之一；没有意图时 [constant EntryMode.NONE]。
static func take_entry_mode() -> int:
	var mode: int = _mode
	_mode = EntryMode.NONE
	return mode


## 清空意图（不消费地丢弃——测试隔离与「中途放弃」路径用）。
static func clear() -> void:
	_mode = EntryMode.NONE


## 当前是否有待消费意图（只读查询，不消费）。
static func has_pending() -> bool:
	return _mode != EntryMode.NONE


## 第一张地图的 ID——探明表首项（表序即剧情顺序，见
## [constant ExplorationMapCatalog.MAPS]）。[br]
## [br][b]不硬编码地图 ID[/b]：新增 / 重排地图只改探明表，本模块自动跟随。[br]
## [br][b]返回[/b]：探明表为空时返回空 [StringName]（调用方据此退回选图界面）。
static func first_map_id() -> StringName:
	var ids: Array = CatalogScript.MAPS.keys()
	if ids.is_empty():
		return &""
	return StringName(str(ids[0]))
