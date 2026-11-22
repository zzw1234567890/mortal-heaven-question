extends RefCounted
## CombatSceneReaders —— 战斗容器的只读取数（Sprint 18 结算回流抽出）。[br]
## [br][b]职责[/b]：把「境界 / 上场人数上限 / 减少动态偏好」三件只读取数从
## [code]combat_scene.gd[/code] 移出——容器本体只做依赖注入与信号接线，
## 取数逻辑独立后可单测，也把容器压回 coding-standards 的单文件软上限内
## （同 [code]combat_result_bridge.gd[/code] / [code]combat_play_bridge.gd[/code] 先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：每次调用都现读，不缓存任何值。[br]
## [br][b]降级[/b]：Autoload 缺失（剥离单例的测试环境）时返回安全默认值——
## 境界 1（炼气）、上场上限 2、不动效偏好 false；不把「读不到」变成崩溃。[br]
## [br]来源: ADR-0031 §2、coding-standards 单文件软上限。

## SettingsStore 脚本常量——reduce_motion 偏好读取（S17 同源口径）。
const SettingsStoreScript := preload("res://src/ui/main_menu/settings_store.gd")

## 境界缺失时的安全默认（1 = 炼气）。
const DEFAULT_REALM: int = 1
## 上场人数上限缺失时的安全默认（炼气期 2 人）。
const DEFAULT_MAX_DEPLOY: int = 2

## Autoload 查找器——本模块内的查找已收拢到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")


## 当前境界 ID（[member GameStateManager.player].realm；缺失回退 [constant DEFAULT_REALM]）。
func realm_id() -> int:
	var gsm: Node = _autoload(&"GameStateManager")
	if gsm == null:
		return DEFAULT_REALM
	var player: Variant = gsm.get("player")
	if player is Dictionary:
		return int((player as Dictionary).get("realm", DEFAULT_REALM))
	return DEFAULT_REALM


## 当前境界上场人数上限（RealmSystem 只读查询；缺失回退 [constant DEFAULT_MAX_DEPLOY]）。
func max_deploy() -> int:
	var rs: Node = _autoload(&"RealmSystem")
	if rs == null or not rs.has_method(&"get_current_property"):
		return DEFAULT_MAX_DEPLOY
	return maxi(int(rs.call(&"get_current_property", &"max_deploy")), 1)


## 读取减少动态偏好——注入覆盖优先（[b]非 null 即生效[/b]），否则读 SettingsStore。[br]
## [br][param override] 测试注入值（[code]null[/code] = 走真实偏好）。
func reduce_motion(override: Variant = null) -> bool:
	if override != null:
		return bool(override)
	var store: RefCounted = SettingsStoreScript.new()
	var gfx: Dictionary = store.load_graphics_category()
	return bool(gfx.get(SettingsStoreScript.GFX_KEY_REDUCE_MOTION, false))


## Autoload 动态查找（避免测试环境缺 Autoload 时的 NameError——同 CombatSystem 先例）。
func _autoload(node_name: StringName) -> Node:
	return AutoloadAccess.find(node_name)
