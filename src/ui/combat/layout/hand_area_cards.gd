class_name HandAreaCards
extends RefCounted
## HandAreaCards —— 手牌卡节点池与三态视觉落定（DEBT-CUI-007-2 拆分）。
##
## [b]职责[/b]：把「快照 → HandCard 节点」这一段收在一处——节点复用与回收、
## 卡面数据写入（名称/费用/稀有度/类型）、可负担性灰显、灵能预览、选中描边，
## 外加命中测试（重叠时按视觉上层取卡）。[br]
## [br][b]为什么单独成文件[/b]：[code]hand_area.gd[/code] 拆出「排位与动画」后仍
## 贴着 300 行软上限，而节点池与三态视觉是另一件事（与几何/动画互不相干）。
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持有手牌快照——每次由宿主传入；
## 本模块只操作宿主容器下的子节点。[br][b]零轮询[/b]：全部由宿主显式驱动。
##
## 来源: ADR-0031、design/gdd/combat-ui-system.md §2 手牌区状态、
## combat-ui-layout Story 006、combat-ui-interaction Story 001、DEBT-CUI-007-2。

## 缩略卡脚本（唯一节点类型）。
const CardScript: GDScript = preload("res://src/ui/combat/layout/hand_card.gd")
## 选中态模型（只为取 [code]NO_CARD[/code] 哨兵）。
const SelectionModel := preload("res://src/ui/combat/shared/hand_selection_model.gd")
## 阶段常量（阶段 2 外统一灵能预览）。
const PLAY_PHASE: int = 2

## 卡节点容器（宿主创建并注入）。
var _parent: Control = null


## 构造——传入卡节点容器。
func _init(p_parent: Control) -> void:
	_parent = p_parent


## 快照 → 节点同步（复用既有节点避免闪烁；多余节点回收）。[br]
## [param p_cards] 宿主的手牌快照数组（本方法会把 [code]node[/code] 写回条目）。
## [param p_phase] 当前阶段（决定灵能预览）。
## [param p_selected_id] 选中卡（重建后重放选中——防幽灵选中）。
func sync(p_cards: Array, p_phase: int, p_selected_id: int) -> void:
	if _parent == null:
		return
	while _parent.get_child_count() > p_cards.size():
		var extra: Node = _parent.get_child(_parent.get_child_count() - 1)
		_parent.remove_child(extra)
		extra.queue_free()
	for i: int in range(p_cards.size()):
		if not (p_cards[i] is Dictionary):
			continue
		var data: Dictionary = p_cards[i]
		var node: HandCard = data.get("node", null)
		if not is_instance_valid(node):
			node = CardScript.new()
			node.name = "Card%d" % i
			_parent.add_child(node)
			data["node"] = node
		node.set_card_data(int(data.get("card_instance_id", -1)),
				str(data.get("name", "")), int(data.get("cost", 0)),
				int(data.get("rarity", 1)), int(data.get("type", 0)))
		node.set_affordable(bool(data.get("affordable", true)))
		node.set_psychic(p_phase != PLAY_PHASE)
	apply_selection(p_cards, p_selected_id)


## 批量写入可负担性（费用系统 cost_changed 驱动）。[br]
## [param p_flags] 与快照等长的费用充足标志（多余项忽略）。
func apply_affordability(p_cards: Array, p_flags: Array) -> void:
	for i: int in range(mini(p_cards.size(), p_flags.size())):
		var node: HandCard = _node_of(p_cards[i])
		if node != null:
			node.set_affordable(bool(p_flags[i]))


## 灵能预览切换（阶段 2 外全部锁标记）。[param p_phase] 新阶段。
func apply_phase(p_cards: Array, p_phase: int) -> void:
	var psychic: bool = p_phase != PLAY_PHASE
	for entry: Variant in p_cards:
		var node: HandCard = _node_of(entry)
		if node != null:
			node.set_psychic(psychic)


## 选中态落到各卡（不重排——位置归排位模块）。[br]
## [param p_selected_id] 选中卡实例 ID（[code]NO_CARD[/code] = 全部取消）。
func apply_selection(p_cards: Array, p_selected_id: int) -> void:
	for entry: Variant in p_cards:
		var node: HandCard = _node_of(entry)
		if node == null:
			continue
		node.set_selected(p_selected_id >= 0
				and int((entry as Dictionary).get("card_instance_id", -1)) == p_selected_id)


## 手牌里现存的卡实例 ID 列表（[code]HandSelectionModel.sync_hand[/code] 的入参）；
## 缺 [code]card_instance_id[/code] 的条目跳过——无 ID 无从与选中比对。
func instance_ids(p_cards: Array) -> Array:
	var ids: Array = []
	for entry: Variant in p_cards:
		if not (entry is Dictionary):
			continue
		var card_id: int = int((entry as Dictionary).get("card_instance_id", -1))
		if card_id >= 0:
			ids.append(card_id)
	return ids


## 命中测试——全局坐标落在哪张手牌上（交互层取卡用）。[br]
## [br][b]逆序（视觉上层优先）[/b]：手牌 >7 张会叠放，玩家看到的是上层那张，
## 命中必须与视觉一致。无命中返回 -1。
func card_id_at(p_cards: Array, p_global_pos: Vector2) -> int:
	for i: int in range(p_cards.size() - 1, -1, -1):
		var node: HandCard = _node_of(p_cards[i])
		if node != null and node.get_global_rect().has_point(p_global_pos):
			return int((p_cards[i] as Dictionary).get("card_instance_id", -1))
	return -1


## 手牌里的卡节点（弧形顺序——焦点链据此串环）。[br]
## [br][b]为什么要节点而不是卡实例 ID[/b]：焦点链设的是 [member Control.focus_next]
## （节点属性），拿不到节点的条目无处可设。
func nodes_of(p_cards: Array) -> Array:
	var nodes: Array = []
	for entry: Variant in p_cards:
		var node: HandCard = _node_of(entry)
		if node != null:
			nodes.append(node)
	return nodes


## 快照条目 → 卡节点（缺失 / 已释放返回 null）。
func _node_of(p_entry: Variant) -> HandCard:
	if not (p_entry is Dictionary):
		return null
	var node: Variant = (p_entry as Dictionary).get("node")
	if node == null or not is_instance_valid(node):
		return null
	return node as HandCard
