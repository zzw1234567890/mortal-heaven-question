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
## [br][b]快照契约[/b]：卡面快照（name/cost/rarity/type）经 [method apply_hand]
## 重建——生产由 [signal hand_changed] 载荷驱动（[method on_hand_changed] 消费）；
## 可负担性经 [method apply_affordability] 批量刷新（费用系统驱动）。
## [method on_card_drawn] 只做末卡入场动画，不新增快照（新增由 hand_changed 负责）。
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不访问卡牌系统，数据均为渲染快照。
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯信号驱动。
##
## @experimental
## 来源: ADR-0031、ADR-0008、design/gdd/combat-ui-system.md §2 手牌区/§边界情况、
## combat-ui-layout Story 006。

## 共享纯函数（弧形几何 Logic 内核——禁止内联）。
const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")

## === 动画常量（UX Transitions——瞬态视觉 §2.1 豁免）===========================

## 抽牌入场动画时长（秒/张——GDD 0.3s）。
const DRAW_ANIM_SEC: float = 0.3
## 手牌重排动画时长（秒——GDD 0.2s ease-out）。
const REARRANGE_ANIM_SEC: float = 0.2
## 满牌溢出提示淡出时长（秒——GDD 2s）。
const OVERFLOW_HINT_FADE_SEC: float = 2.0
## 抽牌起始偏移（px——从牌库方向（右下方）飞入的偏移量）。
const DRAW_START_OFFSET: Vector2 = Vector2(140.0, 90.0)

## === 布局常量 ================================================================

## 敌方卡背区顶部锚（敌方角色区上方小区域——屏幕高度比例）。
const ENEMY_BACK_TOP_RATIO: float = 0.12

## === 视觉常量（集中定义）=====================================================

const EMPTY_HINT_TEXT: String = "无手牌"
const OVERFLOW_HINT_TEXT: String = "手牌已满，卡牌进入弃牌堆"
const HINT_FONT_SIZE: int = 14
const HINT_COLOR: Color = Color(0.80, 0.80, 0.82)

## === 阶段常量（ADR-0008 CombatPhase.PLAY——同 end_turn_button 先例）===========

const PLAY_PHASE: int = 2

## === 子节点引用 ==============================================================

## 手牌卡容器（弧形定位锚——中心对准本区底缘）。
var card_parent: Control = null
## 空手牌提示 Label。
var empty_hint: Label = null
## 满牌溢出提示 Label（2s 淡出）。
var overflow_hint: Label = null
## 敌方手牌背面区。
var enemy_hand_back: EnemyHandBack = null

## === 运行态（渲染快照）=======================================================

## 当前手牌卡面快照（Array[Dictionary]——name/cost/rarity/type/affordable/node）。
var _cards: Array[Dictionary] = []
## 当前阶段（-1 = 未初始化）。
var _phase: int = -1
## 减少动态（动画跳过直跳终态）。
var _reduce_motion: bool = false
## 重排 Tween 句柄（重入 kill）。
var _rearrange_tween: Tween = null
## 抽牌入场 Tween 句柄（重入 kill——避免与重排 Tween 并发写同一卡 position）。
var _draw_tween: Tween = null
## 溢出提示淡出 Tween 句柄（重入 kill）。
var _overflow_tween: Tween = null


func _init() -> void:
	_build()


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


## 应用手牌快照（战斗系统 hand_changed 载荷组装后传入）。[br]
## [param cards]: Array[Dictionary]——每项 [code]{name, cost, rarity, type}[/code]；
## 可负担性单独经 [method apply_affordability] 批量写入（费用系统驱动）。
func apply_hand(cards: Array) -> void:
	_cards = []
	for entry: Dictionary in cards:
		_cards.append(entry.duplicate(true))  # 深拷贝——不污染调用方原字典
	_rebuild_cards()
	empty_hint.visible = _cards.is_empty()
	_relayout()


## 批量写入可负担性（费用系统 cost_changed 驱动——灰显判定）。[br]
## [param affordable_by_index]: Array[bool]——与手牌快照等长的费用充足标志。
func apply_affordability(affordable_by_index: Array) -> void:
	for i: int in range(mini(_cards.size(), affordable_by_index.size())):
		var node: HandCard = _cards[i].get("node", null)
		if is_instance_valid(node):
			node.set_affordable(bool(affordable_by_index[i]))


## 应用阶段（phase_changed 载荷——阶段 2 外灵能预览 / 阶段 2 内费用灰显）。
func apply_phase(new_phase: int) -> void:
	_phase = new_phase
	var psychic: bool = _phase != PLAY_PHASE
	for card_data: Dictionary in _cards:
		var node: HandCard = card_data.get("node", null)
		if is_instance_valid(node):
			node.set_psychic(psychic)


## 应用敌方手牌数量（敌方手牌数信号驱动——卡背）。
func apply_hand_count(count: int) -> void:
	enemy_hand_back.set_card_back_count(count)


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


## 是否有进行中的重排动画（测试探针）。
func has_rearrange_active() -> bool:
	return _rearrange_tween != null and _rearrange_tween.is_valid()


## 是否有进行中的溢出提示（测试探针）。
func has_overflow_hint_active() -> bool:
	return overflow_hint.visible


## === 信号回调 ================================================================

## phase_changed → 阶段状态落定（灵能预览 / 灰显切换）。
func _on_phase_changed(_old_phase: int, new_phase: int, _turn: int) -> void:
	apply_phase(new_phase)


## hand_changed → 快照重建 + 重排动画（载荷为卡面快照数组——生产契约）。
func on_hand_changed(hand: Array) -> void:
	if hand.is_empty():
		apply_hand([])
		return
	apply_hand(hand)


## card_drawn → 抽牌入场动画（0.3s/张飞入弧形位——系统信号驱动）。[br]
## 快照新增由 hand_changed 负责，本回调只对末卡做飞入动画；kill 重排 Tween
## 避免两者并发写同一卡 position。
func on_card_drawn(_card_id: int) -> void:
	if _cards.is_empty():
		return
	var last_node: HandCard = _cards[_cards.size() - 1].get("node", null)
	if not is_instance_valid(last_node):
		return
	var target: Dictionary = Rules.hand_card_position(_cards.size() - 1,
			_cards.size(), size.x, size.y)
	var target_pos: Vector2 = _to_top_left(target, last_node)
	_kill_rearrange_tween()
	_kill_draw_tween()
	if _reduce_motion:
		last_node.position = target_pos
		return
	# 抽牌起始位（牌库方向右下方）→ 弧形终位飞入
	last_node.position = target_pos + DRAW_START_OFFSET
	last_node.rotation = target["rotation"]
	_draw_tween = create_tween()
	_draw_tween.tween_property(last_node, "position", target_pos,
			DRAW_ANIM_SEC).set_ease(Tween.EASE_OUT)


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

## 中心坐标 → 左上角锚定（卡牌 position 用左上角——辅助方法收敛重复转换）。
func _to_top_left(pos: Dictionary, node: Control) -> Vector2:
	return Vector2(pos["x"] - node.size.x * 0.5, pos["y"])


## 重建卡片节点（与 _cards 快照同步——复用既有节点避免闪烁）。
func _rebuild_cards() -> void:
	while card_parent.get_child_count() > _cards.size():
		var extra: Node = card_parent.get_child(card_parent.get_child_count() - 1)
		card_parent.remove_child(extra)
		extra.queue_free()
	for i: int in range(_cards.size()):
		var data: Dictionary = _cards[i]
		var node: HandCard = data.get("node", null)
		if not is_instance_valid(node):
			node = HandCard.new()
			node.name = "Card%d" % i
			card_parent.add_child(node)
			data["node"] = node
		node.set_card_data(str(data.get("name", "")), int(data.get("cost", 0)),
				int(data.get("rarity", 1)), int(data.get("type", 0)))
		node.set_affordable(bool(data.get("affordable", true)))
		node.set_psychic(_phase != PLAY_PHASE)


## 弧形重排（0.2s ease-out 动画；reduce_motion 直跳终态）。
func _relayout() -> void:
	_kill_rearrange_tween()
	if _reduce_motion:
		_apply_positions()
		return
	# 收集可动画节点——空手牌不创建 Tween（避免「started with no Tweeners」报错）
	var animatable: Array[Array] = []
	for i: int in range(_cards.size()):
		var node: HandCard = _cards[i].get("node", null)
		if is_instance_valid(node):
			animatable.append([i, node])
	if animatable.is_empty():
		_apply_positions()
		return
	_rearrange_tween = create_tween()
	_rearrange_tween.set_parallel(true)
	for entry: Array in animatable:
		var i: int = entry[0]
		var node: HandCard = entry[1]
		var target: Dictionary = Rules.hand_card_position(i, _cards.size(),
				size.x, size.y)
		# rotation / z_index 瞬态直设（仅 position 走 tween——旋转与层序无需动画）
		node.rotation = target["rotation"]
		node.z_index = Rules.hand_card_z_index(i, _cards.size())
		_rearrange_tween.tween_property(node, "position",
				_to_top_left(target, node), REARRANGE_ANIM_SEC).set_ease(Tween.EASE_OUT)


## 弧形终位直设（reduce_motion 路径 + 测试断言基准）。
func _apply_positions() -> void:
	for i: int in range(_cards.size()):
		var node: HandCard = _cards[i].get("node", null)
		if not is_instance_valid(node):
			continue
		var pos: Dictionary = Rules.hand_card_position(i, _cards.size(),
				size.x, size.y)
		node.position = _to_top_left(pos, node)
		node.rotation = pos["rotation"]
		node.z_index = Rules.hand_card_z_index(i, _cards.size())


## 通知尺寸落定后重排（NOTIFICATION_RESIZED）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _kill_rearrange_tween() -> void:
	if _rearrange_tween != null and _rearrange_tween.is_valid():
		_rearrange_tween.kill()
	_rearrange_tween = null


func _kill_draw_tween() -> void:
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()
	_draw_tween = null


func _kill_overflow_tween() -> void:
	if _overflow_tween != null and _overflow_tween.is_valid():
		_overflow_tween.kill()
	_overflow_tween = null
