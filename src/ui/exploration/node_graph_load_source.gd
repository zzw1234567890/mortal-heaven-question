extends RefCounted
## NodeGraphLoadSource —— 节点图的数据源选择与加载编排（从 NodeGraphScreen 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已贴近 300 行软上限，而「用哪个数据源、
## 怎么触发加载」与「收到快照后怎么画」是两件事——后者才是 UI 的职责。抽出来后
## 渲染路径不变，降级判定也只有一处。[br]
## [br][b]数据源判定[/b]：[b]看信号而不是看对象[/b]——探索系统存在但未声明
## [code]map_generated[/code] 时仍要降级（早期实情，B-1 回归）；只看 Autoload
## 是否存在会让 stub 永不建立、节点图空白。[br]
## [br][b]加载命令[/b]：真实源调 [code]ExplorationSystem.enter_map[/code]——地图
## 生成、GSM 写入、信号广播都在系统侧，本模块只传「进哪张图、什么境界、多少 AP」。[br]
## [br]来源: ADR-0014 §决策 3 信号表、ADR-0031 §2 零状态所有权、
## story-003-node-graph-data-states.md stub 裁决。

## stub 降级发射器脚本（无信号源时兜底渲染样本）。
const MapGeneratedStubScript := preload("res://src/ui/exploration/map_generated_stub.gd")

## 真实探索系统引用（可为 null——测试注入桩或 Autoload 缺失）。
var system: Node = null
## stub 降级发射器实例（真实源可用时为 null）。
var stub_emitter: Node = null
## 当前是否为 stub 降级（屏幕经 [method NodeGraphScreen.is_using_stub_source] 暴露）。
var using_stub: bool = false


## 绑定数据源——真实源只用不建；缺信号时建 stub 发射器并接回调。[br]
## [br][param p_system] 探索系统（注入或 Autoload，可空）。[br]
## [param p_host] stub 发射器的挂载宿主（一般是屏幕自身，随屏幕释放）。[br]
## [param p_handler] map_generated 处理回调（屏幕的 [method NodeGraphScreen._on_map_generated]）。[br]
func resolve(p_system: Node, p_host: Node, p_handler: Callable) -> void:
	system = p_system
	using_stub = false
	stub_emitter = null
	# 真实源的 map_generated 连接由屏幕统一处理（同一处连 node_moved 等）——
	# 本模块只在降级时额外接 stub 自己的信号。
	if system != null and system.has_signal(&"map_generated"):
		return
	stub_emitter = MapGeneratedStubScript.new()
	p_host.add_child(stub_emitter)
	stub_emitter.map_generated.connect(p_handler)
	using_stub = true


## 触发地图加载。[br]
## [br][param p_map_id] 目标地图 ID。[br]
## [br][b]返回[/b]：是否受理（无系统且无 stub 时 false）。[br]
func load_map(p_map_id: StringName) -> bool:
	if stub_emitter != null:
		stub_emitter.emit_map_generated(p_map_id)
		return true
	if system == null or not system.has_method(&"enter_map"):
		push_warning("NodeGraphLoadSource: 探索系统不支持 enter_map，节点图保持空白")
		return false
	# 境界与行动力上限来自系统侧（GSM / RealmSystem），不在 UI 里猜
	var realm: int = player_realm()
	system.call(&"enter_map", p_map_id, realm, max_action_points(realm))
	return true


## 玩家当前境界——GSM 只读；缺失时回退 1（新档炼气）。[br]
## [b]不臆造[/b]：境界只影响生成期配置兜底，节点强度仍由地图 [code]enemy_realm[/code]
## 定档——读不到就按最低境界进图，比传 UI 猜的数字安全。
func player_realm() -> int:
	var gsm: Node = _autoload(&"GameStateManager")
	if gsm == null:
		return 1
	return maxi(int(gsm.player.get("realm", 1)), 1)


## 行动力上限——[b]RealmSystem 是唯一权威[/b]（GDD action-point-system.md
## 「运行时通过 get_realm_property(L, "action_points") 查询当前上限」）。[br]
## RealmSystem 缺失（headless 单测/早期启动）时回退 10——只影响首次进入的 AP，
## 不写存档字段。
func max_action_points(p_realm: int) -> int:
	var rs: Node = _autoload(&"RealmSystem")
	if rs != null and rs.has_method(&"get_realm_property"):
		var value: Variant = rs.call(&"get_realm_property", p_realm, &"action_points")
		if value is int and int(value) > 0:
			return int(value)
	return 10


## Autoload 动态查找（测试环境缺 Autoload 时返回 null）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
