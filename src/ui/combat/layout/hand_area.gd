class_name HandArea
extends Control
## HandArea —— 手牌区组装器（combat-ui-layout Story 006）。
##
## [b]职责[/b]：弧形排列 [HandCard] 缩略卡 + 敌方卡背区（[EnemyHandBack]）
## 组装，并完成信号驱动渲染：[br]
##   - [method apply_hand] 快照重建手牌（弧形定位 + Z 层序 + 三态视觉）[br]
##   - [method apply_phase] 阶段切换（阶段 2 内费用灰显 / 阶段 2 外灵能预览）[br]
##   - [method apply_hand_count] 敌方卡背数量 + 0 张提示[br]
##   - [method on_card_drawn] 抽牌入场动画（0.3s/张，飞入弧形位）[br]
##   - [method on_card_overflow] 满 10 抽牌溢出（提示 2s 淡出）[br]
##   - [method on_hand_changed] 手牌变更快照 + 重排动画（0.2s ease-out）[br]
##   - [method apply_selection] 选中态落定（抬起 + 加粗描边）[br]
##   - [method card_instance_id_at] 命中测试（交互层点击/拖拽取卡）[br]
## [br][b]拆分（DEBT-CUI-007-2）[/b]：弧形排位与动画归 [code]hand_area_layout.gd[/code]，
## 节点池与三态视觉（含命中测试）归 [code]hand_area_cards.gd[/code]；本文件只留
## 「组装 + 快照 + 信号回调」。[br]
## [br][b]快照契约[/b]：卡面快照经 [method apply_hand] 重建——生产由
## [code]CombatHandSnapshot[/code]（战斗手牌 → 快照，带卡面目标词）驱动；
## 可负担性经 [method apply_affordability] 批量刷新；选中态经
## [method apply_selection]（交互层驱动）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不访问卡牌系统，数据均为渲染快照；
## [member _selected_id] 是渲染快照，选中态真理来源是 [HandSelectionModel]。
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯信号驱动。
##
## @experimental
## 来源: ADR-0031、ADR-0008、design/gdd/combat-ui-system.md §2 手牌区/§边界情况、
## combat-ui-layout Story 006、combat-ui-interaction Story 001、DEBT-CUI-007-2。

## 排位与动画模块（弧形几何 / 重排 / 抽牌飞入——禁止内联）。
const LayoutScript := preload("res://src/ui/combat/layout/hand_area_layout.gd")
## 节点池与三态视觉模块（快照 → 卡节点 / 灰显 / 选中 / 命中）。
const CardsScript := preload("res://src/ui/combat/layout/hand_area_cards.gd")
## 选中态模型（只为取 [code]NO_CARD[/code] 哨兵——本区不持有模型实例）。
const SelectionModel := preload("res://src/ui/combat/shared/hand_selection_model.gd")

## 满牌溢出提示淡出时长（秒——GDD 2s）。
const OVERFLOW_HINT_FADE_SEC: float = 2.0
## 敌方卡背区顶部锚（敌方角色区上方小区域——屏幕高度比例）。
const ENEMY_BACK_TOP_RATIO: float = 0.12
const EMPTY_HINT_TEXT: String = "无手牌"
const OVERFLOW_HINT_TEXT: String = "手牌已满，卡牌进入弃牌堆"
const HINT_FONT_SIZE: int = 14
const HINT_COLOR: Color = Color(0.80, 0.80, 0.82)

## 手牌卡容器（弧形定位锚——中心对准本区底缘）。
var card_parent: Control = null
## 空手牌提示 Label。
var empty_hint: Label = null
## 满牌溢出提示 Label（2s 淡出）。
var overflow_hint: Label = null
## 敌方手牌背面区。
var enemy_hand_back: EnemyHandBack = null

## 当前手牌卡面快照（Array[Dictionary]——name/cost/rarity/type）。
var _cards: Array[Dictionary] = []
## 当前阶段（-1 = 未初始化）。
var _phase: int = -1
## 当前选中的卡实例 ID（渲染快照——真理来源是 [HandSelectionModel]）。
var _selected_id: int = SelectionModel.NO_CARD
## 减少动态（动画跳过直跳终态）。
var _reduce_motion: bool = false
## 溢出提示淡出 Tween 句柄（重入 kill）。
var _overflow_tween: Tween = null
## 排位与动画模块。
var _layout: RefCounted = null
## 节点池与三态视觉模块。
var _card_nodes: RefCounted = null


func _init() -> void:
	_build()
	_layout = LayoutScript.new(self)
	_card_nodes = CardsScript.new(card_parent)


## 构建子节点（卡片容器 + 提示 Label + 敌方卡背区）。
func _build() -> void:
	card_parent = Control.new()
	card_parent.name = "CardParent"
	card_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_parent)
	empty_hint = _make_hint("EmptyHint", EMPTY_HINT_TEXT)
	overflow_hint = _make_hint("OverflowHint", OVERFLOW_HINT_TEXT)
	overflow_hint.visible = false
	enemy_hand_back = EnemyHandBack.new()
	enemy_hand_back.name = "EnemyHandBack"
	# 卡背区锚定敌方角色区上方小区域（水平居中、纵向 0.12H 向下延伸）
	enemy_hand_back.anchor_left = 0.5
	enemy_hand_back.anchor_right = 0.5
	enemy_hand_back.anchor_top = ENEMY_BACK_TOP_RATIO
	enemy_hand_back.anchor_bottom = ENEMY_BACK_TOP_RATIO
	enemy_hand_back.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(enemy_hand_back)


## 提示 Label 工厂（统一字体/颜色/居中——避免重复代码）。
func _make_hint(label_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	label.add_theme_color_override("font_color", HINT_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## 绑定系统信号（依赖注入——测试注入 mock Node，生产传 CombatSystem）。[br]
## [b]重复调用防护[/b]：同源已绑定则跳过（is_connected——bottombar 先例）。
func bind_signals(combat_source: Node) -> void:
	if combat_source == null:
		return
	if combat_source.has_signal(&"phase_changed") \
			and not combat_source.phase_changed.is_connected(_on_phase_changed):
		combat_source.phase_changed.connect(_on_phase_changed)
	if combat_source.has_signal(&"card_drawn") \
			and not combat_source.card_drawn.is_connected(on_card_drawn):
		combat_source.card_drawn.connect(on_card_drawn)
	if combat_source.has_signal(&"card_overflow") \
			and not combat_source.card_overflow.is_connected(on_card_overflow):
		combat_source.card_overflow.connect(on_card_overflow)
	if combat_source.has_signal(&"hand_changed") \
			and not combat_source.hand_changed.is_connected(on_hand_changed):
		combat_source.hand_changed.connect(on_hand_changed)


## 设置减少动态（动画跳过直跳终态——UX 减少动态替代）。
func set_reduce_motion(reduce_motion: bool) -> void:
	_reduce_motion = reduce_motion
	if _layout != null:
		_layout.call(&"set_reduce_motion", reduce_motion)


## 应用手牌快照（战斗系统 hand_changed 载荷组装后传入）。[br]
## [param cards]: Array[Dictionary]——每项 [code]{name, cost, rarity, type}[/code]；
## 可负担性单独经 [method apply_affordability] 批量写入（费用系统驱动）。
func apply_hand(cards: Array) -> void:
	_cards = []
	for entry: Dictionary in cards:
		_cards.append(entry.duplicate(true))  # 深拷贝——不污染调用方原字典
	_card_nodes.call(&"sync", _cards, _phase, _selected_id)
	empty_hint.visible = _cards.is_empty()
	_relayout()


## 批量写入可负担性（费用系统 cost_changed 驱动——灰显判定）。[br]
## [param affordable_by_index]: Array[bool]——与手牌快照等长的费用充足标志。
func apply_affordability(affordable_by_index: Array) -> void:
	_card_nodes.call(&"apply_affordability", _cards, affordable_by_index)


## 应用阶段（phase_changed 载荷——阶段 2 外灵能预览 / 阶段 2 内费用灰显）。
func apply_phase(new_phase: int) -> void:
	_phase = new_phase
	_card_nodes.call(&"apply_phase", _cards, new_phase)


## 应用敌方手牌数量（敌方手牌数信号驱动——卡背）。
func apply_hand_count(count: int) -> void:
	enemy_hand_back.set_card_back_count(count)


## 应用选中态（combat-ui-interaction 001——选中卡抬起 + 加粗描边）。[br]
## [br][param p_selected_id] 选中的卡实例 ID（无选中传 NO_CARD）；快照需带
## [code]card_instance_id[/code] 才能匹配（缺失者按未选中渲染）。[br]
## [b]只重排、不重建[/b]：选中不该让卡牌重新入场（重建会重置 position 动画）。
func apply_selection(p_selected_id: int = SelectionModel.NO_CARD) -> void:
	_selected_id = p_selected_id
	if _cards.is_empty():
		return
	_card_nodes.call(&"apply_selection", _cards, p_selected_id)
	_relayout()


## 手牌里现存的卡实例 ID 列表（[code]HandSelectionModel.sync_hand[/code] 的入参）。
func get_card_instance_ids() -> Array:
	return _card_nodes.call(&"instance_ids", _cards)


## 命中测试——全局坐标落在哪张手牌上（交互层取卡用；无命中 -1）。[br]
## [br][b]逆序（视觉上层优先）[/b]：手牌 >7 张会叠放，命中必须与视觉一致
## （手牌区自身 [code]mouseFilter = IGNORE[/code]，卡面亦为 IGNORE——点击由交互层
## 统一接手并在这里做解析）。
func card_instance_id_at(p_global_pos: Vector2) -> int:
	return int(_card_nodes.call(&"card_id_at", _cards, p_global_pos))


## 获取手牌卡数量（测试断言用）。
func get_card_count() -> int:
	return _cards.size()


## 获取指定索引卡节点（测试断言用）。
func get_card(index: int) -> HandCard:
	if index < 0 or index >= _cards.size():
		return null
	return _cards[index].get("node", null)


## 空手牌提示可见性（测试断言用）。
func is_empty_hint_visible() -> bool:
	return empty_hint.visible


## 是否有进行中的重排动画（测试探针——委托排位模块）。
func has_rearrange_active() -> bool:
	return _layout != null and bool(_layout.call(&"has_rearrange_active"))


## 是否有进行中的溢出提示（测试探针）。
func has_overflow_hint_active() -> bool:
	return overflow_hint.visible


## === 信号回调 ================================================================

## phase_changed → 阶段状态落定（灵能预览 / 灰显切换）。
func _on_phase_changed(_old_phase: int, new_phase: int, _turn: int) -> void:
	apply_phase(new_phase)


## hand_changed → 快照重建 + 重排动画（载荷为卡面快照数组——生产契约）。
func on_hand_changed(hand: Array) -> void:
	apply_hand(hand)


## card_drawn → 抽牌入场动画（系统信号驱动；快照新增由 hand_changed 负责）。
func on_card_drawn(_card_id: int) -> void:
	if _layout != null:
		_layout.call(&"draw_in", _cards)


## card_overflow → 满 10 抽牌溢出（提示 2s 淡出；reduce_motion 直跳终态隐藏）。[br]
## 「牌库→弃牌堆」飞行动画实体归 feedback 层，本 story 只落提示文字。
func on_card_overflow(_card_id: int) -> void:
	_kill_overflow_tween()
	if _reduce_motion:
		overflow_hint.visible = false
		return
	overflow_hint.visible = true
	overflow_hint.modulate.a = 1.0
	_overflow_tween = create_tween()
	_overflow_tween.tween_property(overflow_hint, "modulate:a", 0.0,
			OVERFLOW_HINT_FADE_SEC)
	_overflow_tween.tween_callback(func() -> void: overflow_hint.visible = false)


## === 内部 ====================================================================

## 弧形重排（0.2s ease-out 动画；reduce_motion 直跳终态——委托排位模块）。
func _relayout() -> void:
	if _layout != null:
		_layout.call(&"relayout", _cards)


## 通知尺寸落定后重排（NOTIFICATION_RESIZED）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _kill_overflow_tween() -> void:
	if _overflow_tween != null and _overflow_tween.is_valid():
		_overflow_tween.kill()
	_overflow_tween = null
