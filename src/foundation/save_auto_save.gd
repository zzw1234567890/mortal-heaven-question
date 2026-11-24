extends RefCounted
## SaveAutoSave —— 自动存档的实现子模块（[SaveLoadSystem] 经 [method auto_save] 转发）。[br]
## [br][b]为什么必须有它[/b]：[code]SceneManager.request_scene_change[/code] 在 Phase 2
## 经 [code]has_method("auto_save")[/code] 守卫调用自动存档（AC-2），而
## [SaveLoadSystem] 此前根本没有这个方法——那条调用是[b]静默空操作[/b]。
## 后果不是「少存几次档」，而是「打完 Boss 直接退出的玩家什么都没留下」：
## 全库真正的写入点只有暂停菜单的「保存并退出」，玩家不点它就永远没有进度，
## 「继续游戏」也就无从谈起。[br]
## [br][b]为什么单独一处[/b]：自动存档的[b]决策[/b]（存不存、存什么元信息）与存档系统的
## 其余职责——原子写盘 / JSON 引擎 / 迁移链 / 容器 schema——是两件事，后者已按职责拆进
## [code]src/foundation/save_load/[/code] 的继承链各层。本模块保持独立子模块形态不变
## （链尾 [code]save_load_system.gd[/code] 经 [method auto_save] 转发），
## 因为它不碰落盘路径，只回答「什么时候该存」。[br]
## [br][b]什么时候不写[/b]：还没真正开局（[code]player.identity_id[/code] 为空）时不写。
## 主菜单 → 身份选择的转场正发生在这一状态上，此时 GSM 是一份全新空档；写下去会让
## 「继续游戏」在玩家还没选身份时就亮起，点进去是一局没有身份、没有卡组的空局。
## 这不是「存档失败」，是「还没有东西可存」。[br]
## [br][b]为什么不直接调 [code]save_game[/code] 而要经父节点[/b]：写盘、meta.json 更新、
## 信号广播全部在 [SaveLoadSystem] 内——本模块只决定「存不存、存什么元信息」，
## 不重实现一遍落盘路径。[br]
##
## 来源: ADR-0002 §存档容器、scene_manager.gd §Phase 2 自动存档（AC-2）、
## design/gdd/game-state-manager.md §存档。

## 槽位元信息里的回退境界名——与 [code]_build_save_container[/code] 的出厂默认
## 同源（RealmSystem 不可用时不让摘要行出现空境界）。
const FALLBACK_REALM_NAME: String = "炼气"


## 父节点引用——[SaveLoadSystem] 实例（取 GSM / 调 save_game）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 执行一次自动存档。[br]
## [br][b]返回[/b]：写入的 [enum SaveLoadSystem.SaveResult]；未开局 / 依赖不可用时
## 返回 [code]null[/code]（[b]没写也没出错[/b]——调用方据此与「写了一但失败」区分）。[br]
## [br][b]fire-and-forget[/b]：不阻塞转场管线，返回值只供测试与排障使用。
func run() -> Variant:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method(&"serialize"):
		push_warning("SaveLoadSystem.auto_save: GSM 不可用——本次自动存档跳过")
		return null
	if not has_started(gsm):
		return null
	if _parent == null or not _parent.has_method(&"save_game"):
		push_error("SaveLoadSystem.auto_save: 宿主缺少 save_game——本次自动存档跳过")
		return null
	return _parent.call(&"save_game",
			_parent.get(&"SaveSlotType").AUTOSAVE, 0, gsm.serialize(), build_meta(gsm))


## 是否已有可存的一局——判据是「身份已落地」。[br]
## [br][b]为什么不用场景判断[/b]：身份选择确认与探索进图分属两个场景，而「是否已开局」
## 这件事只由 GSM 回答（[code]apply_identity[/code] 是唯一写入点）。[br]
## [br][param p_gsm] GSM（非空——调用方已守卫）。
func has_started(p_gsm: Node) -> bool:
	return not str(p_gsm.player.get("identity_id", "")).is_empty()


## 自动存档的槽位元信息——境界显示名 + 场景落点 + 已游玩时长。[br]
## [br][b]为什么境界要查 RealmSystem[/b]：主菜单摘要行显示的是「上次：炼气期 · 游玩 …」，
## 而 GSM 里存的是境界[b]等级[/b]（1-5）。等级到显示名的映射只有
## [code]RealmSystem.realm_table[/code] 有——UI 不自己拼一份表（同一事实不出现两处）。[br]
## [br][b]为什么时长在这里也要写一遍[/b]：它有两个落点——[code].json[/code] 存档容器
## 顶层（由 [code]save_game[/code] 从 [code]session.playtime_seconds[/code] 取）与
## meta.json 的槽位条目（由 [code]_update_meta_json[/code] 从本字典取）。
## 两者读的是[b]同一个数[/b]（见 [method playtime_seconds]），只是落点不同；
## 只写一处的话，「继续游戏」摘要行与存档容器会各说各话。[br]
## [br][param p_gsm] GSM（非空——调用方已守卫）。
func build_meta(p_gsm: Node) -> Dictionary:
	return {
		"realm": realm_display_name(int(p_gsm.player.get("realm", 1))),
		"current_scene": str(session_of(p_gsm).get("current_scene", "main_menu")),
		"current_scene_id": int(session_of(p_gsm).get("scene_id", 0)),
		"playtime_seconds": playtime_seconds(p_gsm),
	}


## session 域（不可用 / 非字典时给空字典——缺失键一律走调用方的默认值）。[br]
## [br][b]为什么经 [method Object.get] 而不是 [code]p_gsm.session[/code][/b]：GSM 在用例里
## 常被换成只实现少数几个面的替身（[code]serialize[/code] / [code]player[/code]），
## 点属性会在替身上抛「Invalid get index」；本模块的其余取数（[code]player[/code] /
## [code]identity_id[/code]）同样走 [method Object.get]。替身没这一面即空字典，
## 三处消费者读到的都是同一个「没有时长」而不是崩溃。
func session_of(p_gsm: Node) -> Dictionary:
	var session: Variant = p_gsm.get(&"session")
	if session is Dictionary:
		return session
	return {}


## 已游玩时长（秒）——[b]全库唯一数据源[/b] [code]GSM.session.playtime_seconds[/code]
## 的读取面（由 [code]SessionClock[/code] 每帧累加）。[br]
## [br][b]为什么要有这个方法而不是各处直接读[/b]：三处消费者（本类的 [method build_meta]、
## 暂停菜单手动存档的 meta、[code]SaveLoadSystem._build_save_container] 的容器字段）
## 需要同一份「怎么取、缺失怎么办、负数怎么算」的口径——三份 [code].get(...)[/code]
## 迟早会在某一处写歪（例如忘了钳负数）。[br]
## [br][b]缺失给 0[/b]：老存档 / 手工改过的内存状态里可能没有这个键；不臆造时长。[br]
## [br][param p_gsm] GSM（非空——调用方已守卫）。
func playtime_seconds(p_gsm: Node) -> int:
	return maxi(int(session_of(p_gsm).get("playtime_seconds", 0)), 0)


## 境界等级 → 中文显示名（[code]RealmSystem.realm_table[/code] 的唯一读取面）。[br]
## [br][b]返回[/b]：RealmSystem 不可用或该等级不在表中时回落 [constant FALLBACK_REALM_NAME]。
func realm_display_name(p_level: int) -> String:
	var rs: Node = _get_realm_system()
	if rs != null and rs.has_method(&"get_realm_property"):
		var value: Variant = rs.call(&"get_realm_property", p_level, &"name")
		if value is String and not str(value).is_empty():
			return str(value)
	return FALLBACK_REALM_NAME


## GSM——经 SceneTree Autoload 查找（同 [SaveLoadSystem] 内部口径）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## RealmSystem——缺失时 [method realm_display_name] 走回退名（前向兼容，
## 同 [code]SaveLoadSystem._get_deployment_system[/code] 的口径）。
func _get_realm_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/RealmSystem")
