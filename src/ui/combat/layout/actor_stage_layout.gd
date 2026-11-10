class_name ActorStageLayout
extends RefCounted
## ActorStageLayout —— 战场角色卡排布（DEBT-CUI-007-2 同类拆分 / 单文件 300 行软上限）。
##
## [b]职责[/b]：把 [code]CombatActorStage[/code] 的「卡摆在哪」搬出来——前排贴中线、
## 后排靠外沿、各自水平居中；容器 [signal Control.resized] 驱动重排（窗口缩放不丢排列）。[br]
## [br][b]为什么单独成文件[/b]：装配台加上「当前操作角色 / 命中测试 / 手牌快照」后
## 顶穿 300 行；排布是纯几何，与建卡/信号无关，适合整体搬走。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持有卡表，每次调用由装配台传入；
## 只读容器尺寸。[br][b]零轮询[/b]：由 [code]resized[/code] 与显式调用驱动。
##
## 来源: combat-ui-layout Story 002、ADR-0031、DEBT-CUI-007-2。

## 卡间距（UX 角色区布局细节：16px）。
const CARD_GAP: float = 16.0
## 行内边距（容器上下留白）。
const ROW_MARGIN: float = 8.0
## 容器尺寸不可用时的回退（UX 基准 1920×340——纯 headless 环境兜底）。
const FALLBACK_AREA_SIZE: Vector2 = Vector2(1920.0, 340.0)

## 宿主装配台（取重排回调 + 连接 resized）。
var _owner: Node = null


## 构造——传入装配台（需提供 [code]_relayout()[/code]）。
func _init(p_owner: Node) -> void:
	_owner = p_owner


## 绑定左右容器——尺寸变化即重排（已连接则跳过）。
func attach(p_ally: Control, p_enemy: Control) -> void:
	for container: Control in [p_ally, p_enemy]:
		if container == null:
			continue
		var callback: Callable = Callable(_owner, &"_relayout")
		if not container.resized.is_connected(callback):
			container.resized.connect(callback)


## 重排两侧全部卡：前排贴中线、后排靠外沿，各自水平居中。
func relayout(p_ally_cards: Array[Control], p_enemy_cards: Array[Control],
		p_ally: Control, p_enemy: Control) -> void:
	_layout_side(p_ally_cards, p_ally, true)
	_layout_side(p_enemy_cards, p_enemy, false)


## 单侧排布。[param p_front_at_top] 我方前排在上（贴中线），敌方前排在下。[br]
## 前排卡 100% / 后排卡 85%（[method CharacterStatusCard.set_front_row] 已设 scale），
## 行内按各自实际宽度累加——不做固定网格（前后排卡宽不同）。
func _layout_side(p_cards: Array[Control], p_container: Control,
		p_front_at_top: bool) -> void:
	if p_container == null:
		return
	var area: Vector2 = p_container.size
	if area.x <= 0.0 or area.y <= 0.0:
		area = FALLBACK_AREA_SIZE
	var front: Array[Control] = []
	var back: Array[Control] = []
	for card: Control in p_cards:
		if not is_instance_valid(card):
			continue
		if bool(card.get(&"is_front_row")):
			front.append(card)
		else:
			back.append(card)
	var front_h: float = _card_height(front)
	var back_h: float = _card_height(back)
	var front_y: float = ROW_MARGIN
	var back_y: float = area.y - ROW_MARGIN - back_h
	if not p_front_at_top:
		front_y = area.y - ROW_MARGIN - front_h
		back_y = ROW_MARGIN
	_place_row(front, area.x, front_y)
	_place_row(back, area.x, back_y)


## 行内水平居中摆放。
func _place_row(p_row: Array[Control], p_area_width: float, p_y: float) -> void:
	if p_row.is_empty():
		return
	var total: float = CARD_GAP * float(p_row.size() - 1)
	for card: Control in p_row:
		total += card.size.x * card.scale.x
	var x: float = (p_area_width - total) * 0.5
	for card: Control in p_row:
		card.position = Vector2(x, p_y)
		x += card.size.x * card.scale.x + CARD_GAP


## 行高——取该行最高卡的实际视觉高度（无卡时 0）。
func _card_height(p_row: Array[Control]) -> float:
	var height: float = 0.0
	for card: Control in p_row:
		height = maxf(height, card.size.y * card.scale.y)
	return height
