extends RefCounted
## MapSelectData —— 地图选择界面的数据读取面（从 MapSelectScreen 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已超 300 行软上限，而「数据从哪来」与
## 「拿到数据怎么渲染、点击怎么分流」是两件事（同 [code]map_select_animator.gd[/code]、
## [code]shop_panel_navigator.gd[/code] 拆分先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块[b]只读[/b]——地图列表与灵石
## 每次现取，不缓存、不写 GSM；屏幕上也没有它可写坏的状态。[br]
## [br][b]注入优先于 Autoload[/b]：宿主（屏幕）的 [code]exploration_system[/code] /
## [code]resource_system[/code] 字段是测试注入点，注入为空时才回退 Autoload
## （headless 单测没有这两个 Autoload，回退会拿到 null——按「无数据」如实降级，
## 不臆造地图与余额）。[br]
## [br][b]与 stub 的关系[/b]：此前 [code]get_map_list()[/code] 未实现时屏幕回退
## [code]map_data_stub.gd[/code] 的 8 条硬编码（地图清单/解锁门槛/费用全是写死的）。
## 探明表登记补齐、[code]ExplorationSystem.get_map_list()[/code] 落地后，stub 与
## 本模块的兜底分支一并删除——列表要么来自配置，要么为空。[br]
##
## 来源: ADR-0031 §2、ADR-0014 §get_map_list 契约、
## design/gdd/exploration-ui-system.md §1。

## InputManager 脚本常量——ActionType/DeviceType 枚举真理来源。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")

## 宿主屏幕（读取注入字段 + Autoload 兜底查找的锚点）。
var _host: Node = null


## 构造——传入宿主屏幕。
func _init(p_host: Node = null) -> void:
	_host = p_host


## 地图列表——[code]ExplorationSystem.get_map_list()[/code]（唯一数据源）。[br]
## [br][b]返回[/b]：条目数组；系统不可用或未实现该方法时返回空数组——屏幕按
## 空列表渲染（不空白崩溃，也不塞假地图）。[br]
func map_list() -> Array:
	var es: Node = exploration_system()
	if es != null and es.has_method(&"get_map_list"):
		var entries: Variant = es.call(&"get_map_list")
		return entries if entries is Array else []
	return []


## 灵石余额——只读消费 [code]ResourceSystem.get_resource(&"ling_shi")[/code]。[br]
## [br][b]返回[/b]：余额（资源系统不可用时 0——不臆造数值）。
func ling_shi() -> int:
	var rs: Node = resource_system()
	if rs != null and rs.has_method(&"get_resource"):
		return int(rs.call(&"get_resource", &"ling_shi"))
	return 0


## 输入锁栈判定——改变游戏状态的点击必须过 InputManager（ADR-0004）。[br]
## [br][b]返回[/b]：是否放行；InputManager 不可用时放行（headless 测试与早期
## 启动阶段无该 Autoload）。[br]
func input_allowed() -> bool:
	var im: Node = _autoload(&"InputManager")
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.call(&"is_input_allowed",
			InputManagerScript.ActionType.GAMEPLAY,
			InputManagerScript.DeviceType.MOUSE))


## 探索系统——注入对象优先，否则回退 Autoload。
func exploration_system() -> Node:
	var injected: Variant = _host.get(&"exploration_system") if _host != null else null
	if injected != null:
		return injected as Node
	return _autoload(&"ExplorationSystem")


## 资源系统——注入对象优先，否则回退 Autoload。
func resource_system() -> Node:
	var injected: Variant = _host.get(&"resource_system") if _host != null else null
	if injected != null:
		return injected as Node
	return _autoload(&"ResourceSystem")


## Autoload 查找——宿主未进树 / headless 测试时返回 null（调用方降级）。
func _autoload(p_name: StringName) -> Node:
	if _host != null and _host.is_inside_tree():
		return _host.get_node_or_null(NodePath("/root/" + String(p_name)))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("/root/" + String(p_name)))
