extends Control
## ExplorationScene —— 探索阶段薄容器场景（exploration-ui Story S16-2）。[br]
## [br][b]角色[/b]：闭合 [constant SceneManager.SCENE_PATHS] 的 EXPLORATION 占位
## 路径（[code]res://src/feature/exploration/exploration_scene.tscn[/code]）——
## 身份选择→探索的第一跳可端到端演示（Sprint 16 冲刺目标「核心循环可演示
## 第一跳」）。[br]
## [br][b]结构[/b]：root Control 挂载 [code]MapSelectScreen[/code] 实例（story 002
## 交付）；[code]enter_map_requested[/code] 意图后挂载 [code]NodeGraphScreen[/code]
##（story 003 交付——节点图主界面）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本容器不持有游戏状态，仅负责子界面
## 挂载与意图转发。[method MapSelectScreen] 的 [signal MapSelectScreen.enter_map_requested]
## 已连 [method _on_enter_map_requested]（挂载 NodeGraphScreen 并把玩家选中的
## 地图 ID 转交给它）；[signal MapSelectScreen.reentry_requested] 意图仍无下游
## 消费者（重入实际编排归探索系统）。[br]
## [br][b]退出探索闭环[/b]：节点图的 [signal NodeGraphScreen.back_to_map_select_requested]
## 连到 [method _on_exit_exploration_requested]——走既有
## [code]ExplorationMapFlush.end_exploration(PLAYER_QUIT)[/code] 结算，再拆界面回到
## 地图选择（GDD exploration-system.md §8「退出按钮在探索HUD中始终可用」）。此前该
## 意图全库无消费者，玩家在行动力见底时无处可退。[br]
## [br][b]数据链[/b]：容器[b]不生成地图[/b]——[code]NodeGraphScreen.trigger_map_load[/code]
## 调 [code]ExplorationSystem.enter_map[/code]，地图生成 / GSM 写入 / 信号广播都在
## 系统侧；容器只传「玩家点了哪张图」。[br]
##
## 来源: ADR-0031 §1、ADR-0005（场景切换唯一仲裁）、ADR-0014 §决策 5、
## story-002/story-003。

## MapSelectScreen 场景常量——实例化地图选择界面（含静态节点树，须用
## PackedScene.instantiate() 而非脚本 new()——脚本 new 不加载 .tscn 节点）。
const MapSelectScreenScene := preload("res://src/ui/exploration/map_select_screen.tscn")
## NodeGraphScreen 场景常量——节点图主界面（story 003 主交付）。
const NodeGraphScreenScene := preload("res://src/ui/exploration/node_graph_screen.tscn")
## 结算对象（战斗奖励文案的跨场景缓存——回探索提示读它）。
const ResultViewScript := preload("res://src/feature/combat/combat_result_view.gd")
## HUD 通知入口（战斗奖励到账提示——HUD 未挂载时静默降级）。
const HudBootstrapScript := preload("res://src/ui/hud/hud_bootstrap.gd")
## 探索系统脚本——[code]EndReason[/code] 枚举的真理来源（preload 避免 headless 下
## 的全局名解析问题，同 [code]node_interaction_popup_host.gd[/code] 的 SceneManager 口径）。
const ExplorationSystemScript := preload("res://src/feature/exploration_system.gd")

## 地图选择界面实例（挂载子节点）。
var map_select_screen: Control = null
## 节点图主界面实例（进入地图后挂载）。
var node_graph_screen: Control = null
## [b]测试注入[/b]：通知请求入口 [code]func(type: String, text: String) -> int[/code]。
## 为 null 时按 SceneManager → PersistentLayer/HUD 查找（生产路径）。
var notify_cb: Callable = Callable()


func _ready() -> void:
	map_select_screen = MapSelectScreenScene.instantiate()
	add_child(map_select_screen)
	# 节点图构建（story 003）：MapSelectScreen 进入意图 → 挂载 NodeGraphScreen
	# 并触发地图加载（真实源走 enter_map / 降级源发 stub 信号）
	map_select_screen.enter_map_requested.connect(_on_enter_map_requested)
	# 战斗奖励回探索提示——一次性取走（取不到 = 本场无奖励/没打过战斗）
	_flush_battle_reward_notice()


## 战斗奖励到账提示。[br]
## [br][b]时机[/b]：本场景每次挂载（= 从战斗/结算/战败回到探索）检查一次；
## 文案由 [code]CombatResultView.publish[/code] 在战斗结束时备好，取走即清，
## 因此同一场不会重复弹、反复进出地图也不会重放旧奖励。[br]
## [br][b]为什么在探索侧弹[/b]：结算/战败场景是全屏占位界面且随即退场，玩家真正
## 继续游玩的位置是节点图；提示落在这里才与「已到账」的认知对齐。[br]
## [br][b]降级[/b]：HUD 未挂载 / 通知入口不可用时静默跳过（不把缺 UI 变成崩溃）。[br]
## [br][b]返回[/b]：实际展示的文案（空串 = 没有可提示的奖励——测试断言用）。
func _flush_battle_reward_notice() -> String:
	var notice: String = ResultViewScript.take_pending_notice()
	if notice.is_empty():
		return ""
	var sink: Callable = _notification_sink()
	if not sink.is_valid():
		return ""
	# 类型固定 item（「获得/正向」语义——见 CombatRewardLines.notification_type 口径）
	sink.call("item", notice)
	return notice


## 通知入口——注入优先，否则取常驻 HUD 的 [method Hud.request_notification]。
func _notification_sink() -> Callable:
	if notify_cb.is_valid():
		return notify_cb
	var sm: Node = get_node_or_null(NodePath("/root/SceneManager"))
	if sm == null:
		return Callable()
	var hud: Node = HudBootstrapScript.mounted(sm)
	if hud == null or not hud.has_method(&"request_notification"):
		return Callable()
	return Callable(hud, &"request_notification")


## 进入地图意图（[signal MapSelectScreen.enter_map_requested]）——挂载节点图主界面
## 并把玩家选中的地图 ID 转交给它。[br]
## [br][param p_map_id] 玩家在地图选择界面点中的地图（[b]不再丢弃[/b]——此前固定
## 进青云剑宗，导致无论点哪张图都看到同一张 DAG）。[br]
## [br][b]重复点击[/b]：节点图已挂载时忽略（进入动画期间双击不应重复生成地图）。
func _on_enter_map_requested(p_map_id: StringName) -> void:
	if node_graph_screen != null:
		return
	node_graph_screen = NodeGraphScreenScene.instantiate()
	# 退出探索意图（GDD exploration-system.md §8「退出按钮在探索HUD中始终可用」）
	# ——本容器是唯一同时持有节点图与结算入口的地方。
	node_graph_screen.back_to_map_select_requested.connect(_on_exit_exploration_requested)
	add_child(node_graph_screen)
	node_graph_screen.trigger_map_load(p_map_id)


## 主动退出探索意图（[signal NodeGraphScreen.back_to_map_select_requested]）——结算并
## 退回地图选择界面。[br]
## [br][b]顺序[/b]：先结算再拆节点图。结算走既有 [code]ExplorationMapFlush[/code]
## （[code]end_exploration[/code] + [code]EndReason.PLAYER_QUIT[/code]）——它负责把
## [code]collected_*[/code] 全额转入 [code]player.*[/code]、清导航状态、清 DAG 缓存；
## 先拆界面会让结算时读到的 [code]current_map[/code] 变成空（拆界面之前只有这一处
## 能读），玩家已收集的资源就留在了 [code]map_states[/code] 里永远转不出来。[br]
## [br][b]为什么是 PLAYER_QUIT[/b]：GDD §8 明说「主动退出 = 全额保留，与行动力归零
## 结束相同，区别仅在触发方式」——用 [code]AP_DEPLETED[/code] 描述一次主动操作会
## 让存档/统计里的事件语义失真。[br]
## [br][b]结算失败仍拆界面[/b]：无活跃地图时结算直接返回（GSM 里本就没有东西可转），
## 此时卡在节点图里比退出去更糟。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算、GDD exploration-system.md §5/§8。
func _on_exit_exploration_requested() -> void:
	_settle_active_exploration()
	_unmount_node_graph()


## 结算当前地图（[code]EndReason.PLAYER_QUIT[/code]）。[br]
## [br][b]返回[/b]：结算摘要（系统不可用时为只能标出原因的短字典）——测试断言用。
func _settle_active_exploration() -> Dictionary:
	var es: Node = get_node_or_null(NodePath("/root/ExplorationSystem"))
	if es == null or not es.has_method(&"end_exploration"):
		push_warning("ExplorationScene: 探索系统不可用，退出未结算")
		return {}
	return es.call(&"end_exploration", ExplorationSystemScript.EndReason.PLAYER_QUIT)


## 卸载节点图并刷新地图选择界面——回到「选择地图」这一步。[br]
## [br][b]为什么不重建地图选择界面[/b]：[method _on_enter_map_requested] 只把节点图
## [code]add_child[/code] 叠在上面，地图选择界面[b]从未被卸下[/b]——重建会多出一份
## 需要显式回收的实例，而旧实例在 [method Node.queue_free] 生效前仍连着 GSM 的
## [signal GameStateManager.resource_changed]（结算刚写的那笔灵石会打到一棵已脱树
## 的界面上）；刷新既有的那份没有这一类时序问题。[br]
## [br][b]为什么要显式刷新[/b]：[method MapSelectScreen._refresh_map_list] 只在
## [code]_ready[/code] 与 [code]resource_changed[/code] 时跑，而 [code]_ready[/code]
## 早在本局开始前就跑过了——不刷新的话卡片上的可重入状态与余额停在进图那一刻。[br]
## [br][b]解除引用[/b]：[member node_graph_screen] 必须置空——[method
## _on_enter_map_requested] 靠它判「是否已挂载」，留着会拒绝下一次进入。
func _unmount_node_graph() -> void:
	if node_graph_screen == null:
		return
	if node_graph_screen.back_to_map_select_requested.is_connected(
			_on_exit_exploration_requested):
		node_graph_screen.back_to_map_select_requested.disconnect(
				_on_exit_exploration_requested)
	remove_child(node_graph_screen)
	node_graph_screen.queue_free()
	node_graph_screen = null
	if map_select_screen != null:
		# 重读两侧数据（列表 + 余额）——[method MapSelectScreen._refresh_map_list] /
		# [method MapSelectScreen._refresh_balance] 是它自己的读取面，这里只是触发一次
		# 「现取」（跨模块调私有方法是本库既有做法：子模块走
		# [code]_parent.call("_get_map_config")[/code]；[code]MapSelectScreen[/code]
		# 已贴 300 行软上限，不为其新开一个仅转发的公开方法）。
		map_select_screen.call(&"_refresh_map_list")
		map_select_screen.call(&"_refresh_balance")
