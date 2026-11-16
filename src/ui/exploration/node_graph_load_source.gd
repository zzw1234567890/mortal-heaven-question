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
## map_generated 处理回调（屏幕的 [method NodeGraphScreen._on_map_generated]）——
## 连接与退订都靠它，所以必须记下来（[method unbind] 无从凭空还原这个 Callable）。
var map_handler: Callable = Callable()
## node_moved 处理回调（屏幕的迷雾消散重算；可无效——调用方不需要时传空）。
var move_handler: Callable = Callable()
## stub 降级发射器实例（真实源可用时为 null）。
var stub_emitter: Node = null
## 当前是否为 stub 降级（屏幕经 [method NodeGraphScreen.is_using_stub_source] 暴露）。
var using_stub: bool = false
## 本次 [method load_map] 是否真的走了系统命令。[br]
## [br][b]为什么要这个标记[/b]：屏幕要判断「正在渲染的这份快照是不是系统给的」——
## 系统在场（Autoload 存在）不等于快照出自它：测试直调
## [code]_on_map_generated[/code] 传 stub 样本时系统照样在场，此时拿系统的判定去
## 翻六态会得到一张与快照无关的图（系统缓存里是别的 DAG）。本标记只在命令真的
## 下发过时为真，是「这份快照的出处」的唯一凭据。[br]
## [br][b]为什么可靠[/b]：[code]enter_map[/code] 同步广播 [code]map_generated[/code]，
## 屏幕的 [method NodeGraphScreen._on_map_generated] 在本调用返回之前就已执行完
## ——读到的一定是本次置的值。
var from_system: bool = false


## 绑定数据源——真实源只用不建；缺信号时建 stub 发射器并接回调。[br]
## [br][param p_system] 探索系统（注入或 Autoload，可空）。[br]
## [param p_host] stub 发射器的挂载宿主（一般是屏幕自身，随屏幕释放）。[br]
## [param p_handler] map_generated 处理回调（屏幕的 [method NodeGraphScreen._on_map_generated]）。[br]
## [param p_move_handler] node_moved 处理回调（屏幕的迷雾消散重算；可空）。[br]
## [br][b]真实源的信号连接也在这里[/b]：本模块是「数据源」这件事的唯一归属地——
## 连哪个信号、连给谁，跟「用真实源还是 stub」是同一个决定（此前屏幕另有一处
## 连接，两处各记一份，退订也就各自漏掉）。[br]
func resolve(p_system: Node, p_host: Node, p_handler: Callable,
		p_move_handler: Callable = Callable()) -> void:
	system = p_system
	map_handler = p_handler
	move_handler = p_move_handler
	using_stub = false
	stub_emitter = null
	if system != null and system.has_signal(&"map_generated"):
		bind_signals()
		return
	stub_emitter = MapGeneratedStubScript.new()
	p_host.add_child(stub_emitter)
	stub_emitter.map_generated.connect(p_handler)
	using_stub = true


## 连接真实系统的 map_generated / node_moved（幂等——重复调用不重复连）。[br]
## [br][b]为什么配对必须有 unbind[/b]：[method unbind] 见那里的说明（退出探索后
## 旧界面仍挂在信号上会收到不该收的广播）。
func bind_signals() -> void:
	if system == null:
		return
	if system.has_signal(&"map_generated") and not system.map_generated.is_connected(
			map_handler):
		system.map_generated.connect(map_handler)
	if move_handler.is_valid() and system.has_signal(&"node_moved") \
			and not system.node_moved.is_connected(move_handler):
		system.node_moved.connect(move_handler)


## 断开真实系统的信号——[b]界面离树时必须调用[/b]。[br]
## [br][b]为什么不能只等释放[/b]：退出探索走 [code]remove_child + queue_free[/code]，
## 而 [code]queue_free[/code] 到帧末才真正执行；这中间玩家（或测试）完全可能再次
## 进图，[code]enter_map[/code] 广播的 [code]map_generated[/code] 会打到这棵
## [b]已脱离场景树[/b]的旧界面上——它随即去查 Autoload（绝对路径）并重建
## Tween/Timer，全是「节点不在树里」的引擎报错（实测：重进地图时刷出一串
## [code]Can't use get_node() with absolute paths from outside the active scene tree[/code]）。
func unbind() -> void:
	if system == null:
		return
	if system.has_signal(&"map_generated") and system.map_generated.is_connected(map_handler):
		system.map_generated.disconnect(map_handler)
	if move_handler.is_valid() and system.has_signal(&"node_moved") \
			and system.node_moved.is_connected(move_handler):
		system.node_moved.disconnect(move_handler)


## 触发地图加载。[br]
## [br][param p_map_id] 目标地图 ID。[br]
## [param p_resume] [code]true[/code] = [b]读档续玩[/b]（见 [method resume_map]）。[br]
## [br][b]返回[/b]：是否受理（无系统且无 stub 时 false）。[br]
func load_map(p_map_id: StringName, p_resume: bool = false) -> bool:
	from_system = false
	if stub_emitter != null:
		stub_emitter.emit_map_generated(p_map_id)
		return true
	if p_resume:
		return resume_map(p_map_id)
	if system == null or not system.has_method(&"enter_map"):
		push_warning("NodeGraphLoadSource: 探索系统不支持 enter_map，节点图保持空白")
		return false
	# 境界与行动力上限来自系统侧（GSM / RealmSystem），不在 UI 里猜
	var realm: int = player_realm()
	# 标记先置——enter_map 同步广播 map_generated，屏幕的渲染回调在本行[b]返回之前[/b]
	# 就已执行，此时读到的必须已经是 true（否则「按快照出处决定判定来源」那一格会
	# 拿到上一轮的旧值，真实地图被当成 stub 渲染）。
	from_system = true
	system.call(&"enter_map", p_map_id, realm, max_action_points(realm))
	return true


## 读档续玩加载——[b]不重新生成地图[/b]，由系统从存档快照重建并广播。[br]
## [br][b]与 [method load_map] 的分工[/b]：那条走 [code]enter_map[/code]（新 seed、
## 已访问重置为入口、行动力回满）；本方法走 [code]resume_map[/code]（图 / 走过的路 /
## 剩余行动力全部取自存档）。读档后走前者，玩家会被悄悄送回起点。[br]
## [br][b]from_system 的置位时机同 [method load_map][/b]：系统同步广播
## [code]map_generated[/code]，屏幕的渲染回调在本行返回之前就会读到它。[br]
## [br][b]返回[/b]：是否受理。系统不支持 [code]resume_map[/code] 或该图无快照时
## false（[code]resume_map[/code] 自己会 push_warning）——屏幕据此保持空态，
## 由薄容器决定退回选图界面。
func resume_map(p_map_id: StringName) -> bool:
	if system == null or not system.has_method(&"resume_map"):
		push_warning("NodeGraphLoadSource: 探索系统不支持 resume_map，读档续玩中止")
		return false
	from_system = true
	return not (system.call(&"resume_map", p_map_id) as Dictionary).is_empty()


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
