extends RefCounted
## MainMenuBootstrap —— 主菜单作为「启动承载者」的三件首帧职责（从 main_menu.gd 拆出）。[br]
## [br][b]为什么由主菜单做这三件事[/b]：主菜单是 [code]run/main_scene[/code]
## （[code]project.godot[/code]），进程启动后的第一个场景——HUD 要在它这里挂进
## PersistentLayer 才能此后常驻，探索系统要在这里接上回调注入点，按键要在这里
## 从设置文件恢复。三件事的共同点是「[b]只发生一次、且必须发生在首个场景里[/b]」，
## 与「按钮怎么摆、点下去走哪条链」是两回事。[br]
## [br][b]HUD 挂载（gate-check 2026-11-08 §B1）[/b]：经 [method HudBootstrap.mount]
## 走 [code]SceneManager.register_persistent()[/code]；本件只负责「什么时候挂」，
## 装配细节归 [HudBootstrap]。[br]
## [br][b]为什么自动挂载要延后一帧 + 加 current_scene 守卫[/b]：场景切换时
## [code]current_scene[/code] 要到整个装载流程结束才落定，[code]_ready[/code] 内读取
## 可能还是旧值（故 [method Node.call_deferred]）；而集成测试把 MainMenu.tscn 当普通
## 节点 [code]add_child[/code]，此时 [code]current_scene[/code] 不是它——不挂，避免
## 测试进程里凭空多出一个常驻 HUD（它订阅全局 ESC 与转场信号）。生产路径
## （含读档/转场回到主菜单）守卫恒真。[br]
## [br][b]探索装配[/b]：把地图配置目录与敌人池接进 ExplorationSystem 的注入点
## ——与 HUD 同源，「数据实现」接到「系统接口」上，系统内部不硬编码地图表与敌人池
## （DEBT-EUI-006-3 / DEBT-EUI-006-5）。[b]不加 current_scene 守卫[/b]：本装配只改
## 回调字段、不挂节点，测试把主菜单当普通节点 add_child 时装配同样有意义（测试正是
## 要验真实回调路径）；重复执行幂等。[br]
## [br][b]按键加载[/b]：先快照当前 InputMap 为默认基准，再从设置文件加载并应用——
## 顺序不可逆（先加载再快照会把自定义键污染进默认基准，QL-STORY-READY 2026-09-20
## 裁决）。快照 store 写回宿主属性，因为设置面板装配时还要拿同一个实例
## （「恢复默认」要的是启动时那份基准）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本件不持任何状态——store 的归属是宿主，
## HUD 的归属是 PersistentLayer。[b]零轮询[/b]：无 [code]_process()[/code]。
##
## 来源: ADR-0031 §1/§1.2、gate-check-presentation-layer-complete-2026-11-08 §B1、
## hud Story 001、main-menu Story 004（键位持久化加载）。

## HUD 的生产挂载入口（[code]SceneManager.register_persistent()[/code] 的封装）。
const HudBootstrapScript := preload("res://src/ui/hud/hud_bootstrap.gd")
## 探索系统的生产装配入口（地图配置 + 敌人池）。
const ExplorationBootstrapScript := preload(
		"res://src/feature/exploration/exploration_bootstrap.gd")
## 按键绑定 store（键位持久化加载与设置面板共用同一份实现）。
const KeybindStoreScript := preload("res://src/ui/main_menu/keybind_store.gd")


## === HUD 挂载 ==================================================================

## 仅在「本节点就是运行中的主场景」时挂载全局 HUD。[br]
## [br][param p_host] 主菜单节点（延后一帧回调它的 [code]_mount_global_hud[/code]）。
static func mount_global_hud_if_boot_scene(p_host: Node) -> void:
	if p_host == null or not p_host.is_inside_tree():
		return
	p_host.call_deferred(&"_mount_global_hud")


## 守卫实现——[b]测试可直接调宿主的 [code]_mount_global_hud[/code]（守卫）/
## [code]_mount_hud[/code]（无守卫）[/b]。[br]
## [br][b]current_scene 为 null 时放行[/b]：场景切换的中间态（旧场景已释放、
## 新场景尚未登记）不该被误判成「不是主场景」而漏挂；此时本节点必然就是刚装载的
## 主菜单。[br]
## [br][param p_scene_manager] 已解析好的 SceneManager（注入优先，宿主负责解析）。
## [br][b]返回[/b]：是否真的走了挂载这一跳（守卫拦下时为 false）。
static func mount_global_hud(p_host: Node, p_scene_manager: Node) -> bool:
	if p_host == null or not p_host.is_inside_tree():
		return false
	var tree: SceneTree = p_host.get_tree()
	if tree == null:
		return false
	var current: Node = tree.current_scene
	if current != null and current != p_host:
		return false
	mount_hud(p_scene_manager)
	return true


## 挂载全局 HUD（幂等——重复进入主菜单复用同一实例）。[br]
## [br][param p_scene_manager] SceneManager（null 时 [HudBootstrap] 静默降级）。[br]
## [br][b]返回[/b]：已挂载的 HUD；SceneManager 不可用/不支持时 null。
static func mount_hud(p_scene_manager: Node) -> CanvasLayer:
	return HudBootstrapScript.mount(p_scene_manager)


## === 探索系统生产装配（地图配置 + 敌人池）====================================

## 把地图配置目录与敌人池接进 ExplorationSystem 的注入点。[br]
## [br][param p_host] 根节点查询的起点（[code]/root/ExplorationSystem[/code] 等）。[br]
## [br][b]返回[/b]：是否装配成功（探索系统缺失时为 false，静默降级）。
static func mount_exploration(p_host: Node) -> bool:
	if p_host == null:
		return false
	var es: Node = p_host.get_node_or_null(NodePath("/root/ExplorationSystem"))
	if es == null:
		return false
	return ExplorationBootstrapScript.mount(
			es, p_host.get_node_or_null(NodePath("/root/AISystem")))


## === 按键绑定启动加载（Story 004）==============================================

## 启动加载自定义按键（GDD 边界澄清「键位持久化加载」——重启不失效）。[br]
## [br][b]顺序[/b]：先快照后加载（顺序不可逆——见类文档）。文件无
## [code]keybinds[/code] 键（首次启动）→ 空绑定 → 跳过应用（InputMap 维持
## [code]project.godot[/code] 默认）。[br]
## [br][b]store 写回宿主[/b]：设置面板装配时要拿同一个实例（「恢复默认」用启动时
## 快照的基准）。[br]
## [br][param p_host] 宿主（读写它的 [code]keybind_store[/code] 属性）。[br]
## [br][b]返回[/b]：本次使用的 store（新建或宿主原有的那份）。
static func load_keybinds(p_host: Node) -> KeybindStore:
	if p_host == null:
		return null
	var store: KeybindStore = p_host.get(&"keybind_store") as KeybindStore
	if store == null:
		store = KeybindStoreScript.new()
		p_host.set(&"keybind_store", store)  # 留存共享——SettingsPanel 装配时注入（H-3）
	store.snapshot_defaults()
	var bindings: Dictionary = store.load_bindings()
	if not bindings.is_empty():
		KeybindStoreScript.apply_bindings(bindings)
	return store
