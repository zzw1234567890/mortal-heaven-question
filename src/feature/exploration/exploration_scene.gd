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
## 地图 ID 转交给它）；[signal MapSelectScreen.reentry_requested] 连
## [method _mount_reentry_flow]（扣费与进图归 Feature 层，本容器只接线）。[br]
## [br][b]通关之后去哪[/b]：结算面板确认时刷新列表并高亮「下一张」
## （[method _on_map_clear_confirmed]）——没有这一步，17 张卡里最显眼的仍然是
## 刚通完那张，玩家的默认动作是原地重刷。[br]
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
## 战斗奖励到账提示（取走即清 + HUD 通知出口，见该类文档）。
const RewardNoticeScript := preload("res://src/feature/exploration/exploration_reward_notice.gd")
## 探索系统脚本——[code]EndReason[/code] 枚举的真理来源（preload 避免 headless 下
## 的全局名解析问题，同 [code]node_interaction_popup_host.gd[/code] 的 SceneManager 口径）。
const ExplorationSystemScript := preload("res://src/feature/exploration_system.gd")
## 地图通关结算面板的接线（Boss 胜利 → 本场景挂载时弹出结算 overlay）。
const MapClearPresenterScript := preload("res://src/ui/exploration/map_clear_presenter.gd")
## 结算面板的文案内核（「下一张去哪」的读取口——键名归它，这里不裸写）。
const MapClearRulesScript := preload("res://src/ui/exploration/map_clear_panel_rules.gd")
## 重入确认之后的落地接线（扣费 → 进图 / 拒绝提示，见该类文档）。
const ReentryFlowScript := preload("res://src/ui/exploration/map_select_reentry_flow.gd")
## 卡牌详情来源（按模板 ID 查 description / flavor_text——见该类文档）。
const CardDetailScript := preload("res://src/ui/exploration/map_clear_card_detail.gd")
## 跨场景进入意图的落地编排（新开局直落第一张图 / 读档续玩回上次那张图）。
const EntryFlowScript := preload("res://src/feature/exploration/exploration_entry_flow.gd")

## 地图选择界面实例（挂载子节点）。
var map_select_screen: Control = null
## 节点图主界面实例（进入地图后挂载）。
var node_graph_screen: Control = null
## 地图通关结算接线（未挂载为 null）。
var map_clear_presenter: RefCounted = null
## 重入确认之后的下游接线（未挂载为 null）。
var reentry_flow: RefCounted = null
## [b]测试注入[/b]：通知请求入口 [code]func(type: String, text: String) -> int[/code]。
## 为 null 时按 SceneManager → PersistentLayer/HUD 查找（生产路径）。
var notify_cb: Callable = Callable()


func _ready() -> void:
	map_select_screen = MapSelectScreenScene.instantiate()
	add_child(map_select_screen)
	# 节点图构建（story 003）：MapSelectScreen 进入意图 → 挂载 NodeGraphScreen
	# 并触发地图加载（真实源走 enter_map / 降级源发 stub 信号）
	map_select_screen.enter_map_requested.connect(_on_enter_map_requested)
	# 重入意图（S16-2 起就存在、此前全库无消费者）——扣费与进图归 Feature 层
	_mount_reentry_flow()
	# 战斗奖励回探索提示——一次性取走（取不到 = 本场无奖励/没打过战斗）
	_flush_battle_reward_notice()
	# 地图通关结算（Boss 胜利的那一局）——同一条「回到探索时检查一次」的时序
	_mount_map_clear_settlement()
	# 本次进入的意图（新开局直落第一张图 / 读档续玩回上次那张图）——取走即清
	_consume_entry_intent()


## 重入接线——[signal MapSelectScreen.reentry_requested] → 扣费放行 / 拒绝提示。[br]
## [br][b]本方法补的断链[/b]：该信号自 S16-2 起就摆在那里，而[b]全库无消费者[/b]
## ——玩家在重入确认弹窗上点「确认传送」，扣费与进图两件事都不会发生（弹窗关掉、
## 界面停在原地，点击看起来像失灵）。[br]
## [br][b]进图出口是 [method _enter_map] 的 [code]false[/code] 分支[/b]：重入要的是
## 新 seed、新 DAG、行动力回满（[code]enter_map[/code] 口径），不是读档续玩的快照重建
## ——参数在这里绑死，重入路径就不可能误走续玩分支。[br]
## [br][b]依赖与判定都在别处[/b]：费用公式归 [code]ExplorationEconomy[/code]、
## 资格与扣费归 [code]ExplorationReentry[/code]、文案出口归 [code]MapSelectNotice[/code]
## ——本容器只把三方接起来（见 [code]map_select_reentry_flow.gd[/code]）。[br]
## [br]来源: design/gdd/exploration-ui-system.md §1 重入确认弹窗、ADR-0014 §决策 4、
## ADR-0031 §2。
func _mount_reentry_flow() -> void:
	reentry_flow = ReentryFlowScript.new()
	reentry_flow.call(&"attach", self, map_select_screen,
			Callable(self, &"_enter_map").bind(false))
	reentry_flow.call(&"connect_screen")


## 消费「本次进探索要干什么」的意图（[ExplorationEntryIntent]——取走即清）。[br]
## [br][b]实现见 [ExplorationEntryFlow][/b]（新开局落点 / 读档续玩口径都在那边，
## 本容器只把进图出口交出去）。[br]
## [br][b]返回[/b]：实际消费到的模式（[enum ExplorationEntryIntent.EntryMode]；
## 测试断言用——无意图时为 NONE）。
func _consume_entry_intent() -> int:
	return EntryFlowScript.consume(Callable(self, &"_enter_map"))

## 战斗奖励到账提示——取走即清（取不到 = 本场无奖励/没打过战斗）。[br]
## [br][b]返回[/b]：实际展示的文案（空串 = 没有可提示的奖励——测试断言用）。[br]
## [br]实现见 [ExplorationRewardNotice]（HUD 未挂载 / 通知入口不可用时静默跳过，
## 不把缺 UI 变成崩溃）。
func _flush_battle_reward_notice() -> String:
	return RewardNoticeScript.flush(self)


## 地图通关结算面板——Boss 战胜利后本场景挂载时弹出（GDD exploration-ui-system.md §7）。[br]
## [br][b]时机同战斗奖励提示[/b]：结算与 [code]MapClearView[/code] 的发布都在转场
## [b]之前[/b]（[code]PlaceholderScene[/code] 里调 [code]end_exploration(BOSS_DEFEATED)[/code]），
## 而 Boss 胜利的转场目的地就是本场景——面板在此挂载，取走即清（反复进出不重放）。[br]
## [br][b]为什么挂在本容器而不是节点图[/b]：打完 Boss 回到的是[b]地图选择界面[/b]
## （节点图要玩家点卡片才挂），挂在节点图上的面板永远不会出现。[br]
## [br][b]「回到地图选择」出口[/b]：确认即收起 overlay，并刷新底下的地图列表与余额
## ——[b]不复用[/b] [code]back_to_map_select_requested[/code]（那条会再触发一次
## [code]end_exploration(PLAYER_QUIT)[/code]，多广播一次语义失真的结束事件）。[br]
## [br][b]详情来源注入[/b]：面板点开奖励卡牌时读卡牌模板的 [code]description[/code] /
## [code]flavor_text[/code]；CardSystem 缺失时提供者返回空字典，面板只用载荷字段
## （不臆造描述文本）。[br]
## [br]来源: GDD exploration-ui-system.md §7、ADR-0014 §决策 5、ADR-0031 §2。
func _mount_map_clear_settlement() -> void:
	map_clear_presenter = MapClearPresenterScript.new()
	map_clear_presenter.set(&"detail_provider", Callable(self, &"_card_detail_extra"))
	map_clear_presenter.call(&"attach", self, Callable(self, &"_on_map_clear_confirmed"))
	map_clear_presenter.call(&"show_pending")


## 通关结算已确认——刷新地图选择界面（列表 + 余额）并高亮「下一张去哪」。[br]
## [br][b]为什么要显式刷新[/b]：与 [method _unmount_node_graph] 同源理由——
## [method MapSelectScreen._refresh_map_list] / [method MapSelectScreen._refresh_balance]
## 只在 [code]_ready[/code] 与 [code]resource_changed[/code] 时跑，而 [code]_ready[/code]
## 早在本局开始前就跑过了；不刷新的话卡片上的「已通关」标记与余额停在进图那一刻。[br]
## [br][b]为什么要高亮[/b]：刷新之后 17 张卡里最显眼的仍是[b]刚通完那张[/b]（它亮着
## 「已通关」），玩家的默认动作是原地重刷；点亮推荐卡把「下一张在哪」摆到眼前。[br]
## [br][b]顺序：先刷新再点亮[/b]——刷新会重建全部卡片（推荐态由
## [code]MapSelectCards[/code] 持有并在重建时重放），反过来先点亮会被重建抹掉。[br]
## [br][b]推荐 ID 从面板载荷读[/b]：它由 Feature 层算出随 [code]MapClearView[/code]
## 发布（见 [code]ExplorationClearReport[/code]）；键名归
## [code]MapClearPanelRules.next_map_id[/code]，本容器不裸写字符串。[br]
## [br][b]不结算[/b]：BOSS_DEFEATED 的结算已经在转场前完成（本容器只负责收尾展示）。
func _on_map_clear_confirmed() -> void:
	if map_select_screen == null:
		return
	map_select_screen.call(&"_refresh_map_list")
	map_select_screen.call(&"_refresh_balance")
	_highlight_next_map()


## 点亮「下一张」卡片（[param p_view] 为面板本次展示的结算载荷）。[br]
## [br][b]返回[/b]：是否真的点亮了某一张（无结算载荷 / 全图通关 / 推荐图不在列表里
## 时为 false——此时不臆造一张「看起来像推荐」的卡）。[br]
## [br][b]卡片数组从屏幕现取[/b]：刷新之后卡片是新建的，缓存一份旧引用会点到一个
## 已 [code]queue_free[/code] 的节点上。
func _highlight_next_map(p_view: Dictionary = {}) -> bool:
	if map_select_screen == null:
		return false
	var view: Dictionary = p_view
	if view.is_empty() and map_clear_presenter != null:
		view = map_clear_presenter.call(&"view")
	return bool(map_select_screen.call(&"highlight_next_map",
			MapClearRulesScript.next_map_id(view)))


## 通关结算面板是否正开着（宿主查询/测试断言用）。
func map_clear_panel_open() -> bool:
	return map_clear_presenter != null and bool(
			map_clear_presenter.call(&"is_panel_open"))


## 卡牌详情补充字段——按模板 ID 查卡牌系统（面板点击奖励卡牌时调用）。[br]
## [br][b]返回[/b]：[code]{description, flavor_text}[/code]；查不到模板时为空字典
## （面板只用载荷里的名称/稀有度/类型，不编造描述）。[br]
## [br][b]只读查询[/b]：本方法不改任何状态（ADR-0031 §2——UI 零状态所有权）。[br]
## [br]实现见 [MapClearCardDetail]（CardSystem 未挂载 / 无该模板时如实返回空字典）。
func _card_detail_extra(p_entry: Variant) -> Dictionary:
	return CardDetailScript.extra_of(self, p_entry)


## 进入地图意图（[signal MapSelectScreen.enter_map_requested]）——挂载节点图主界面
## 并把玩家选中的地图 ID 转交给它。[br]
## [br][param p_map_id] 玩家在地图选择界面点中的地图（[b]不再丢弃[/b]——此前固定
## 进青云剑宗，导致无论点哪张图都看到同一张 DAG）。[br]
## [br][b]重复点击[/b]：节点图已挂载时忽略（进入动画期间双击不应重复生成地图）。[br]
## [br][b]新生成[/b]：本条路径走 [code]p_resume = false[/code]（重新生成地图）；读档续玩
## 走 [method _resume_last_map]，两条路都汇到 [method _enter_map]。
func _on_enter_map_requested(p_map_id: StringName) -> void:
	_enter_map(p_map_id, false)


## 进图实现——挂载 [code]NodeGraphScreen[/code] 并按 [param p_resume] 触发加载。[br]
## [br][param p_resume] [code]false[/code] = 新生成（[code]enter_map[/code]：新 seed、
## 已访问重置为入口、行动力回满）；[code]true[/code] = 读档续玩（[code]resume_map[/code]：
## 图 / 走过的路 / 剩余行动力全部取自存档，见 [code]NodeGraphLoadSource.resume_map[/code]）。[br]
## [br][b]为什么抽成一处[/b]：挂载与接线（含退出意图）对两条路径完全相同，差别只在
## 传给节点图的最后一个布尔——复制一份挂载序列会让「接线漏一条」只在一半路径上出现。[br]
## [br][b]返回[/b]：是否真的挂了节点图（已挂载时为 false——重复意图被忽略；
## 读档续玩拿不到快照时也返回 false——那种情况下这张空图已被拆掉）。
func _enter_map(p_map_id: StringName, p_resume: bool) -> bool:
	if node_graph_screen != null:
		return false
	node_graph_screen = NodeGraphScreenScene.instantiate()
	# 退出探索意图（GDD exploration-system.md §8「退出按钮在探索HUD中始终可用」）
	# ——本容器是唯一同时持有节点图与结算入口的地方。
	node_graph_screen.back_to_map_select_requested.connect(_on_exit_exploration_requested)
	add_child(node_graph_screen)
	node_graph_screen.trigger_map_load(p_map_id, p_resume)
	# 读档续玩拿不到快照（该图在存档里没有 graph/nodes）——加载如实失败，本屏幕
	# 是一块什么都没有的画板。拆掉它退回选图界面：留在里面玩家既看不到图、
	# 也点不动任何东西，只能靠退出按钮脱身。
	if p_resume and not bool(node_graph_screen.call(&"has_snapshot")):
		_unmount_node_graph()
		return false
	return true


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
