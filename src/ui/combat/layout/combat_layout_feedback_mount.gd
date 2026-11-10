extends RefCounted
## CombatLayoutFeedbackMount —— 反馈编排器的装配（combat_layout 拆分模块·反馈组）。
##
## [b]职责[/b]：实例化 [code]CombatFeedbackCoordinator[/code]（伤害飘字 / HP 条合并刷新 /
## 阵亡淡出的生产装配点），并把信号源与 HP 终值读取 Callable 接进去。[br]
## [b]层级[/b]：全屏透明层，须挂在手牌区之上、备战 / 结算覆盖层之下——飘字盖住角色卡
## 但不遮面板；顺序由主类的构建次序保证，本模块只负责「建 + 接」。
##
## [b]为什么单独成文件[/b]：[code]combat_layout.gd[/code] 是场景挂载侧唯一持有的节点，
## 四组接线此前挤在同一个类里（465 行）。本模块只负责「反馈这一组」。
##
## 来源: combat-ui-layout Story 003、DEBT-CUI-007-2（combat_layout 拆分）。

## 反馈编排器脚本（生产实例化点）。
const CoordinatorScript: GDScript = preload(
		"res://src/ui/combat/feedback/combat_feedback_coordinator.gd")
## 敌方行动逐条播报（combat-ui-interaction 002）。
const BroadcastScript: GDScript = preload(
		"res://src/ui/combat/feedback/enemy_action_broadcast.gd")
## 播报命名工具（生成名称解析闭包）。
const TextScript: GDScript = preload(
		"res://src/ui/combat/feedback/enemy_action_text.gd")

## 宿主布局根（编排器挂在这里）。
var _layout: Control = null
## 编排器实例（[method build] 创建）。
var coordinator: Variant = null
## 敌方行动播报实例（[method build] 创建——在编排器之上）。
var broadcast: Variant = null


## 构造——传入宿主布局根。
func _init(p_layout: Control) -> void:
	_layout = p_layout


## 构建编排器（全屏透明层，不拦截鼠标——飘字池挂在其下）。
func build() -> void:
	coordinator = CoordinatorScript.new()
	coordinator.name = "CombatFeedback"
	coordinator.call(&"set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
	coordinator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(coordinator)
	# 播报背板挂在编排器之下、排在飘字池之后 = 绘制在飘字之上；
	# 不新增战斗根的子节点（根节点顺序是既有绘制层级契约，见 test_layout_mount_facade）。
	broadcast = BroadcastScript.new()
	broadcast.name = "EnemyActionBroadcast"
	coordinator.add_child(broadcast)


## 接线——把信号源与 HP 终值读取 Callable 注入编排器，并接通敌方行动播报。[br]
## [br][param p_sources] 信号源数组（CombatSystem + DeploymentSystem，可空项自动跳过）。[br]
## [param p_hp_reader] HP 终值读取 Callable——[code]func(character_id) -> {current, max}[/code]。[br]
## [param p_reduce_motion] 减少动态（进场时读到的设置值——飘字 / 阵亡动画的静态替代开关）。[br]
## [param p_card_system] 卡牌系统（战报里我方角色名的模板来源，可空）。[br]
## [param p_log_sink] 战报追加闭包（战斗日志 [code]append_entry[/code]，可空）。[br]
## [br][b]编排器缺失时[/b]告警并返回（不把缺依赖变成崩溃）。
func setup(p_sources: Array, p_hp_reader: Callable, p_reduce_motion: bool = false,
		p_card_system: Node = null, p_log_sink: Callable = Callable()) -> void:
	if coordinator == null:
		push_warning("CombatLayout.setup_feedback: 反馈编排器未装配")
		return
	coordinator.call(&"setup", p_sources, null, p_hp_reader, p_reduce_motion)
	_setup_broadcast(p_sources, p_card_system, p_log_sink)


## 接线敌方行动播报——信号源与名称解析都从同一组注入依赖派生。[br]
## [b]降级[/b]：播报未装配时静默跳过（同反馈编排器的可空依赖口径）。
func _setup_broadcast(p_sources: Array, p_card_system: Node,
		p_log_sink: Callable) -> void:
	if broadcast == null:
		return
	var resolver: Callable = TextScript.make_name_resolver(
			_first_source(p_sources), p_card_system)
	broadcast.call(&"setup", p_sources, BroadcastScript.DEFAULT_INTERVAL_MS,
			resolver, p_log_sink)


## 信号源数组里的第一个非空节点（CombatSystem 位）。
func _first_source(p_sources: Array) -> Node:
	for source: Variant in p_sources:
		if source is Node and source != null:
			return source
	return null
