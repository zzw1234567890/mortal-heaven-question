class_name CombatBottombar
extends Control
## CombatBottombar —— 底部条三组件组装器（combat-ui-layout Story 005）。
##
## [b]职责[/b]：将费用栏（[CostBar]）+ 牌库/弃牌计数（[DeckCounter]）+
## 「结束出牌」按钮位（[EndTurnButton]）组装进 Story 001 的 BottomBar 容器，
## 并完成信号接线（phase_changed 驱动按钮显示/隐藏；cost_changed 驱动费用栏）。[br]
## [br][b]横向顺序[/b]（GDD §4）：费用栏（左）→ 牌库/弃牌计数（中）→
## 结束出牌按钮（右端）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本组装器只做信号路由 + 组件引用，
## 费用/计数/阶段数据均由各组件持渲染快照，经系统信号驱动。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯信号驱动。[br]
## [br][b]依赖注入[/b]：战斗源对象经 [method bind_signals] 注入（测试注入 mock）；
## 费用数据经 CostSystem [signal cost_changed] 订阅（生产）或测试直调
## [method apply_cost_state] 转发。
##
## @experimental
## 来源: ADR-0031、ADR-0008、ADR-0015、design/gdd/combat-ui-system.md §4/§569、
## combat-ui-layout Story 005。

## === 布局常量（1920×1080 基准 anchor 比例——非像素硬编码）====================

## 费用栏宽比例（160/1920）。
const COST_WIDTH_RATIO: float = 160.0 / 1920.0
## 牌库计数宽比例（130/1920）。
const DECK_WIDTH_RATIO: float = 130.0 / 1920.0
## 结束出牌按钮宽比例（120/1920）。
const END_BUTTON_WIDTH_RATIO: float = 120.0 / 1920.0
## 组件间距（12/1920）。
const GAP_RATIO: float = 12.0 / 1920.0

## === 子组件引用 ==============================================================

var cost_bar: CostBar = null
var deck_counter: DeckCounter = null
var end_turn_button: EndTurnButton = null


func _init() -> void:
	_build()


## 构建三组件（_init 构建——不依赖场景树时序）。
func _build() -> void:
	custom_minimum_size = Vector2(460, 48)
	cost_bar = CostBar.new()
	cost_bar.name = "CostBar"
	add_child(cost_bar)
	deck_counter = DeckCounter.new()
	deck_counter.name = "DeckCounter"
	add_child(deck_counter)
	end_turn_button = EndTurnButton.new()
	end_turn_button.name = "EndTurnButton"
	add_child(end_turn_button)


## 绑定系统信号（依赖注入——测试注入 mock Node，生产传 CombatSystem/CostSystem）。[br]
## [param combat_source]: CombatSystem 信号源（phase_changed）。[br]
## [param cost_source]: CostSystem 信号源（cost_changed）——费用数据驱动源。[br]
## [b]重复调用防护[/b]：同源已绑定则跳过（is_connected——hud.gd 先例）。
func bind_signals(combat_source: Node, cost_source: Node = null) -> void:
	if combat_source != null and combat_source.has_signal(&"phase_changed") \
			and not combat_source.phase_changed.is_connected(_on_phase_changed):
		combat_source.phase_changed.connect(_on_phase_changed)
	if cost_source != null and cost_source.has_signal(&"cost_changed") \
			and not cost_source.cost_changed.is_connected(_on_cost_changed):
		cost_source.cost_changed.connect(_on_cost_changed)


## 设置减少动态（转发费用栏）。
func set_reduce_motion(reduce_motion: bool) -> void:
	cost_bar.set_reduce_motion(reduce_motion)


## 应用费用状态（转发费用栏——测试直调或 CostSystem 信号转发）。
func apply_cost_state(available: int, base_max: int, temporary: int) -> void:
	cost_bar.apply_cost_state(available, base_max, temporary)


## 设置牌库/弃牌计数（转发计数组件——stub 先行）。
func set_deck_counts(deck_count: int, discard_count: int) -> void:
	deck_counter.set_deck_counts(deck_count, discard_count)


## === 信号回调 ================================================================

## phase_changed → 结束出牌按钮显示/隐藏（AC-7——仅阶段 2 可见）。
func _on_phase_changed(_old_phase: int, new_phase: int, _turn: int) -> void:
	end_turn_button.apply_phase(new_phase)


## cost_changed(current, max_show, total_max) → 费用栏刷新（AC-2 信号驱动）。[br]
## [b]载荷解包[/b]：CostSystem 第三参数为 total_max（基础上限+临时加成），
## 而费用栏需 temporary（临时加值）——换算 temporary = total_max - max_show。
func _on_cost_changed(current: int, max_show: int, total_max: int) -> void:
	cost_bar.apply_cost_state(current, max_show, total_max - max_show)


## === 布局 ====================================================================

## 三组件横向排布（_notification 尺寸落定后重排）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


## 横向排布：费用栏（左）→ 牌库计数（中）→ 结束出牌按钮（右端）。
func _relayout() -> void:
	if cost_bar == null or size.x <= 0.0:
		return
	var x: float = 0.0
	x = _place_ratio(cost_bar, x, COST_WIDTH_RATIO)
	x += GAP_RATIO * size.x
	x = _place_ratio(deck_counter, x, DECK_WIDTH_RATIO)
	# 结束出牌按钮锚定右端（不随 x 递增——固定右对齐）
	if end_turn_button != null:
		end_turn_button.anchor_left = 1.0 - END_BUTTON_WIDTH_RATIO
		end_turn_button.anchor_right = 1.0
		end_turn_button.anchor_top = 0.0
		end_turn_button.anchor_bottom = 1.0
		end_turn_button.offset_left = 0.0
		end_turn_button.offset_right = 0.0
		end_turn_button.offset_top = 4.0
		end_turn_button.offset_bottom = -4.0


## 子组件定位（anchor 比例换算——按容器实际宽 size.x 换算为 offset 像素，
## 非固定 1920 基准——保证任意宽度下三组件占比一致，响应式）。
func _place_ratio(node: Control, x: float, width_ratio: float) -> float:
	if node == null:
		return x
	node.anchor_left = 0.0
	node.anchor_right = 0.0
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = x
	node.offset_right = x + width_ratio * size.x
	node.offset_top = 0.0
	node.offset_bottom = size.y
	return node.offset_right
