class_name HandAreaLayout
extends RefCounted
## HandAreaLayout —— 手牌区「弧形排位与动画」模块（DEBT-CUI-007-2 拆分）。
##
## [b]职责[/b]：把「卡牌该摆在哪、怎么飞过去」从 [HandArea] 里搬出来——
## 弧形终位计算（[code]HandArcRules[/code]）、z 层序、选中抬起偏移叠加、
## 重排 Tween（0.2s ease-out）与抽牌飞入 Tween（0.3s）；三个 Tween 句柄的
## 重入 kill 也归本模块。[br]
## [br][b]为什么单独成文件[/b]：[code]hand_area.gd[/code] 曾承担「排位 + 三态视觉 +
## 敌背区 + 抽牌动画 + 重排 + 选中态」六件事（401 行）。本模块只做其中一件；
## 快照与状态落定留在 [HandArea]，两者通过「卡快照数组」交接。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持有手牌数据，每次调用由宿主
## 传入快照；Tween 句柄是瞬态视觉状态（§2.1 豁免）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——全部由宿主显式驱动。
##
## 来源: ADR-0031、design/gdd/combat-ui-system.md §1/§2、
## combat-ui-layout Story 006、DEBT-CUI-007-2。

## 弧形几何纯函数（唯一落地处——禁止内联）。
const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")

## 抽牌入场动画时长（秒/张——GDD 0.3s）。
const DRAW_ANIM_SEC: float = 0.3
## 手牌重排动画时长（秒——GDD 0.2s ease-out）。
const REARRANGE_ANIM_SEC: float = 0.2
## 抽牌起始偏移（px——从牌库方向（右下方）飞入的偏移量）。
const DRAW_START_OFFSET: Vector2 = Vector2(140.0, 90.0)

## 宿主（取尺寸 + 创建 Tween 的节点）。
var _host: Control = null
## 减少动态（动画跳过直跳终态）。
var _reduce_motion: bool = false
## 重排 Tween 句柄（重入 kill）。
var _rearrange_tween: Tween = null
## 抽牌入场 Tween 句柄（重入 kill——避免与重排 Tween 并发写同一卡 position）。
var _draw_tween: Tween = null


## 构造——传入宿主（需在场景树内才能创建 Tween）。
func _init(p_host: Control) -> void:
	_host = p_host


## 设置减少动态（动画跳过直跳终态）。
func set_reduce_motion(p_reduce_motion: bool) -> void:
	_reduce_motion = p_reduce_motion


## 弧形重排（0.2s ease-out；reduce_motion 直跳终态）。[br]
## [param p_cards] 手牌快照数组（每项含 [code]node[/code]——非快照条目忽略）。
func relayout(p_cards: Array) -> void:
	_kill_rearrange_tween()
	if _host == null or not is_instance_valid(_host):
		return
	if _reduce_motion:
		apply_positions(p_cards)
		return
	var animatable: Array[Array] = []
	for i: int in range(p_cards.size()):
		var node: Control = _node_of(p_cards[i])
		if node != null:
			animatable.append([i, node])
	if animatable.is_empty():
		apply_positions(p_cards)
		return
	_rearrange_tween = _host.create_tween()
	_rearrange_tween.set_parallel(true)
	for entry: Array in animatable:
		var index: int = entry[0]
		var node: Control = entry[1]
		var target: Dictionary = _target_of(index, p_cards.size())
		# rotation / z_index 瞬态直设（仅 position 走 tween——旋转与层序无需动画）
		node.rotation = target["rotation"]
		node.z_index = Rules.hand_card_z_index(index, p_cards.size())
		_rearrange_tween.tween_property(node, "position",
				_lifted(_to_top_left(target, node), node),
				REARRANGE_ANIM_SEC).set_ease(Tween.EASE_OUT)


## 弧形终位直设（reduce_motion 路径 + 测试断言基准）。
func apply_positions(p_cards: Array) -> void:
	for i: int in range(p_cards.size()):
		var node: Control = _node_of(p_cards[i])
		if node == null:
			continue
		var target: Dictionary = _target_of(i, p_cards.size())
		node.position = _lifted(_to_top_left(target, node), node)
		node.rotation = target["rotation"]
		node.z_index = Rules.hand_card_z_index(i, p_cards.size())


## 末卡抽牌飞入（0.3s；reduce_motion 直跳终位）。[br]
## [br]快照新增由 [code]hand_changed[/code] 负责，本方法只对末卡做入场动画；
## kill 重排 Tween 避免两者并发写同一卡 position。
func draw_in(p_cards: Array) -> void:
	if p_cards.is_empty() or _host == null or not is_instance_valid(_host):
		return
	var node: Control = _node_of(p_cards[p_cards.size() - 1])
	if node == null:
		return
	var target: Dictionary = _target_of(p_cards.size() - 1, p_cards.size())
	var target_pos: Vector2 = _to_top_left(target, node)
	_kill_rearrange_tween()
	_kill_draw_tween()
	if _reduce_motion:
		node.position = target_pos
		return
	# 抽牌起始位（牌库方向右下方）→ 弧形终位飞入
	node.position = target_pos + DRAW_START_OFFSET
	node.rotation = target["rotation"]
	_draw_tween = _host.create_tween()
	_draw_tween.tween_property(node, "position", target_pos,
			DRAW_ANIM_SEC).set_ease(Tween.EASE_OUT)


## 是否有进行中的重排动画（测试探针）。
func has_rearrange_active() -> bool:
	return _rearrange_tween != null and _rearrange_tween.is_valid()


## 停止全部动画并清句柄（宿主退场 / 快照清空时调用）。
func stop() -> void:
	_kill_rearrange_tween()
	_kill_draw_tween()


# === 内部 =====================================================================

## 弧形终位（中心坐标 + 旋转——宿主尺寸为基准）。
func _target_of(p_index: int, p_total: int) -> Dictionary:
	var area: Vector2 = _host.size
	return Rules.hand_card_position(p_index, p_total, area.x, area.y)


## 快照条目 → 卡节点（缺失 / 已释放返回 null）。
func _node_of(p_entry: Variant) -> Control:
	if not (p_entry is Dictionary):
		return null
	var node: Variant = (p_entry as Dictionary).get("node")
	if node == null or not is_instance_valid(node):
		return null
	return node as Control


## 中心坐标 → 左上角锚定（卡牌 position 用左上角——收敛重复转换）。
func _to_top_left(pos: Dictionary, node: Control) -> Vector2:
	return Vector2(pos["x"] - node.size.x * 0.5, pos["y"])


## 叠加选中抬起偏移（偏移量由组件声明，位置所有权仍在本模块）。[br]
## [br][b]为什么叠加而非覆盖[/b]：弧形终位是「未选中的基准位」，抬起是相对它的
## 增量——取消选中时自然回到基准位，不需要另存一份原始坐标。
func _lifted(base_pos: Vector2, node: Control) -> Vector2:
	return base_pos - Vector2(0.0, float(node.call(&"get_lift_offset")))


func _kill_rearrange_tween() -> void:
	if _rearrange_tween != null and _rearrange_tween.is_valid():
		_rearrange_tween.kill()
	_rearrange_tween = null


func _kill_draw_tween() -> void:
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()
	_draw_tween = null
