class_name HudBootstrap
extends RefCounted
## HudBootstrap —— HUD 的生产挂载入口（ADR-0031 §1 / §1.2）。[br]
## [br][b]为什么需要[/b]：`HUD.tscn` 经 [code]SceneManager.register_persistent()[/code]
## 挂入 PersistentLayer 才能跨场景常驻，但此前全库没有任何实例化点——
## HUD 只存在于测试与手动 debug 宿主中，生产运行永远看不到境界条/灵石条/
## 通知/暂停菜单（gate-check 2026-11-08 §B1；DEBT-EUI-005-6 的根因）。[br]
## [br][b]挂载点选择[/b]：[code]run/main_scene = MainMenu.tscn[/code] 是进程启动后
## 第一个场景（主菜单本体结构不动）——由主菜单 [code]_ready()[/code] 调用本类挂载，
## 之后每次转场（探索/战斗/商店…）HUD 都留在 PersistentLayer 中。[br]
## [br][b]幂等[/b]：PersistentLayer 下已有同名 `HUD` 节点时直接复用——
## 返回主菜单会重新实例化 MainMenu，但 HUD 只挂一次。[br]
## [br][b]失败语义（静默降级）[/b]：未注入 SceneManager / 缺少
## [code]register_persistent[/code]（测试 mock）/ 注册被拒——返回 null 且不抛错，
## 调用方（主菜单）继续正常工作，只是没有全局 HUD。[br]
## [br][b]零状态所有权[/b]：本类不持有任何节点引用（除返回值），节点生命期归
## PersistentLayer。[br]
## [br]来源: ADR-0031 §1/§1.2、ADR-0005（场景切换唯一仲裁）、
## gate-check-presentation-layer-complete-2026-11-08 §B1、hud Story 001。

## HUD 场景——[code]preload[/code] 常量：路径错误在解析期暴露
## （hud story 001 与 scene_manager 的同款约定）。
const HUD_SCENE: PackedScene = preload("res://src/ui/hud/HUD.tscn")

## HUD 根节点名（= HUD.tscn 根节点名；幂等判定用）。
const HUD_NODE_NAME: StringName = &"HUD"

## PersistentLayer 节点名（ADR-0031 §1.2 命名契约；幂等查询用）。
const PERSISTENT_LAYER_NAME: StringName = &"PersistentLayer"


## 挂载全局 HUD（幂等）。[br]
## [br][param scene_manager] SceneManager 实例（生产为 Autoload；测试可注入）。
## [br][b]返回[/b]：已挂载的 HUD CanvasLayer；无法挂载时 null。
static func mount(scene_manager: Node) -> CanvasLayer:
	if scene_manager == null or not scene_manager.has_method(&"register_persistent"):
		return null
	var existing: Node = mounted(scene_manager)
	if existing != null:
		return existing

	var hud: CanvasLayer = HUD_SCENE.instantiate()
	scene_manager.call(&"register_persistent", hud)
	if hud.get_parent() == null:
		# 注册被拒（已有父节点 / 层不可用）——不留在内存里
		hud.queue_free()
		push_warning("HudBootstrap: HUD 注册到 PersistentLayer 失败")
		return null
	if hud.has_method(&"setup"):
		hud.call(&"setup", scene_manager)
	return hud


## 查询当前是否已挂载（不触发挂载）。
static func is_mounted(scene_manager: Node) -> bool:
	return mounted(scene_manager) != null


## 取已挂载的 HUD（未挂载返回 null——不触发挂载）。[br]
## [br][b]为什么与 [method is_mounted] 并存[/b]：调用方除了「挂没挂」还要拿它调
## 接口（如 [method Hud.request_notification]）；每次 `get_node_or_null` 各写一遍
## 路径，路径一旦变化就会漏改（回探索提示 / 其他跨场景提示共用这一处）。
static func mounted(scene_manager: Node) -> Node:
	if scene_manager == null:
		return null
	var node: Node = scene_manager.get_node_or_null(
			NodePath("%s/%s" % [PERSISTENT_LAYER_NAME, HUD_NODE_NAME]))
	return node if node is CanvasLayer else null
