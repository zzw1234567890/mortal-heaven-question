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

## 宿主布局根（编排器挂在这里）。
var _layout: Control = null
## 编排器实例（[method build] 创建）。
var coordinator: Variant = null


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


## 接线——把信号源与 HP 终值读取 Callable 注入编排器。[br]
## [br][param p_sources] 信号源数组（CombatSystem + DeploymentSystem，可空项自动跳过）。[br]
## [param p_hp_reader] HP 终值读取 Callable——[code]func(character_id) -> {current, max}[/code]。[br]
## [param p_reduce_motion] 减少动态（进场时读到的设置值——飘字 / 阵亡动画的静态替代开关）。[br]
## [br][b]编排器缺失时[/b]告警并返回（不把缺依赖变成崩溃）。
func setup(p_sources: Array, p_hp_reader: Callable, p_reduce_motion: bool = false) -> void:
	if coordinator == null:
		push_warning("CombatLayout.setup_feedback: 反馈编排器未装配")
		return
	coordinator.call(&"setup", p_sources, null, p_hp_reader, p_reduce_motion)
