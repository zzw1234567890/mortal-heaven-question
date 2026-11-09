class_name CombatActorStage
extends Node
## CombatActorStage —— 战场角色卡装配与排布（Sprint 18 / DEBT-CBT-018-1 残留闭环）。
##
## [b]职责[/b]：把「战斗系统持有的敌我名册」变成战场上的 [CharacterStatusCard]，
## 并把这些卡注册进 [CombatFeedbackCoordinator]——此后 HP 条 / 伤害飘字 /
## 阵亡淡出才有真实数据可消费。[br]
## [br][b]为什么独立成文件[/b]：此前全库没有任何生产代码创建角色卡，
## [code]CombatFeedbackCoordinator[/code] 的卡表永远是空的（HP 落库只停在数据层）。
## 装配逻辑塞进 [code]combat_scene.gd[/code]（260 行）会顶穿 300 行软上限，
## 也破坏「薄容器只接线」的职责边界。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：名册/HP/ATK 一律经
## [code]combat_actor_reader.gd[/code] 现读；建卡瞬间取一次快照做初始渲染
## （[member _cards] 是 UI 节点表，不是游戏状态副本）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——建卡由 [method build_roster]
## 显式驱动，排布由容器 [signal Control.resized] 驱动。[br]
##
## @experimental
## 来源: ADR-0031、ADR-0008 §Phase 1/Phase 6、design/ux/combat-ui.md §Layout Zones、
## combat-ui-layout Story 002/003、DEBT-CBT-018-1 残留项。

## 角色卡脚本（按需 new——同 CombatLayout 的组件装配先例）。
const CardScript := preload("res://src/ui/combat/layout/character_status_card.gd")
## 取数入口（名册 / HP / ATK——单一读取链路）。
const ReaderScript := preload("res://src/ui/combat/layout/combat_actor_reader.gd")
## UI 出牌桥（DEBT-CBT-018-10 第四阶段——出牌前裁定施法者再转交 CombatSystem）。
const PlayBridgeScript := preload("res://src/ui/combat/shared/combat_play_bridge.gd")

## 卡间距（UX 角色区布局细节：16px）。
const CARD_GAP: float = 16.0
## 行内边距（容器上下留白）。
const ROW_MARGIN: float = 8.0
## 容器尺寸不可用时的回退（UX 基准 1920×340——纯 headless 环境兜底）。
const FALLBACK_AREA_SIZE: Vector2 = Vector2(1920.0, 340.0)

## 取数入口实例（RefCounted）。
var _reader: RefCounted = ReaderScript.new()
## 反馈编排器（卡建好后注册——由挂载侧注入）。
var _coordinator: Control = null
## UI 出牌桥（出牌时裁定施法者——数据源与 [member _reader] 同一组注入）。
var _play_bridge: RefCounted = PlayBridgeScript.new()

## === 容器（CombatLayout 的区域）=============================================

var _ally_container: Control = null
var _enemy_container: Control = null

## === UI 节点表（非游戏状态——ADR-0031 §2 合规）==============================

## 敌方卡（按建卡顺序）。
var _enemy_cards: Array[Control] = []
## 我方卡（按建卡顺序）。
var _ally_cards: Array[Control] = []
## 角色 ID → 卡（[method get_card] 查询与清理用）。
var _cards: Dictionary = {}


## 注入数据源（全部可空——缺失时对应侧不建卡，不抛错）。
func setup(p_combat: Node, p_deployment: Node, p_card_system: Node = null,
		_p_binding_manager: Node = null) -> void:
	_reader.call(&"setup", p_combat, p_deployment, p_card_system)
	_play_bridge.call(&"setup", p_combat, p_deployment)
	_connect_death(p_combat)


## UI 出牌入口——裁定施法者后转交 [code]CombatSystem.play_card()[/code]。[br]
## [br][b]为什么从角色卡装配台暴露[/b]：本台已持有战斗系统与部署系统两份数据源
## （[method setup] 注入），出牌桥所需正好齐备，不必新增一层容器。[br]
## [br][b]层级关系[/b]：[code]CombatLayout[/code] 是场景挂载侧持有的那个节点
## （[code]combat_scene.gd[/code] 调的是它的 [code]setup_feedback[/code]），本台是它的
## 子组件；交互层应调 [code]CombatLayout.play_card()[/code]，本方法只作下层入口。[br]
## [br][b]施法者口径（临时）[/b]：我方阵位第一个存活角色（见
## [code]combat_caster_rules.gd[/code]）；interaction epic 落地「当前操作角色」后
## 应改为显式传入。[br]
## [br][param p_card_instance_id] 卡牌实例 ID。[param p_target_indices] 目标索引列表。[br]
## [b]返回[/b]: 出牌是否成功。
func play_card(p_card_instance_id: int, p_target_indices: Array) -> bool:
	return bool(_play_bridge.call(&"play_card", p_card_instance_id, p_target_indices))


## 当前裁定出的施法者 ID（测试与后续交互层查询用；判不出为 -1）。
func current_caster_id() -> int:
	return int(_play_bridge.call(&"current_caster_id"))


## 指定卡的落地容器（我方区 / 敌方区）。
func set_containers(p_ally: Control, p_enemy: Control) -> void:
	_ally_container = p_ally
	_enemy_container = p_enemy
	_connect_resized(_ally_container)
	_connect_resized(_enemy_container)


## 绑定反馈编排器——此后新建的卡自动注册（已建卡也补注册）。
func bind_coordinator(p_coordinator: Control) -> void:
	_coordinator = p_coordinator
	for character_id: int in _cards.keys():
		_register(character_id)


## 构建全部角色卡（开战时调用）。[br]
## [param p_player_ids] 开战配置里的角色 ID（空 → 回退读 DeploymentSystem 阵位）。[br]
## [br][b]先清后建[/b]：重复开战不会残留上一场的卡与注册关系。
func build_roster(p_player_ids: Array = []) -> void:
	clear_roster()
	_build_side(_reader.call(&"player_entries", p_player_ids), _ally_container, _ally_cards)
	_build_side(_reader.call(&"enemy_entries"), _enemy_container, _enemy_cards)
	_relayout()


## 清空全部角色卡（战斗结束 / 重开战）。[br]
## [b]顺序[/b]：先从反馈编排器注销（防其持有悬空卡引用），再释放节点。
## [b]立即摘父[/b]：只 queue_free 会让节点滞留到帧末，下一场的 card_count /
## 子节点数会读到「上一场的残影」——先 remove_child 再 queue_free。
func clear_roster() -> void:
	for character_id: int in _cards.keys():
		if _coordinator != null and _coordinator.has_method(&"unregister_card"):
			_coordinator.call(&"unregister_card", character_id)
		var card: Control = _cards[character_id] as Control
		if card != null and is_instance_valid(card):
			if card.get_parent() != null:
				card.get_parent().remove_child(card)
			card.queue_free()
	_cards.clear()
	_ally_cards.clear()
	_enemy_cards.clear()


## 查询角色卡（测试与后续交互层命中测试用）。[br]
## 卡被阵亡流程移除后对象已 freed——此时返回 null（防调用方拿到悬空引用；
## 对已释放实例做 `is Control` 判断会抛引擎错误，故先判有效性）。
func get_card(character_id: int) -> Control:
	var card: Variant = _cards.get(character_id)
	if card == null or not is_instance_valid(card):
		return null
	if not (card is Control):
		return null
	return card


## 已建卡数量（两侧合计——测试断言用）。
func card_count() -> int:
	return _cards.size()


## 订阅阵亡信号——卡被战斗侧判死后从节点表摘除（防「UI 仍以为卡在」）。[br]
## [br][b]与编排器的分工[/b]：动效（淡出→移除→空位框）归
## [code]CombatFeedbackCoordinator[/code]；本台只维护「谁还有卡」的索引，
## 两个消费者各自订阅同一条信号（ADR-0008 §架构原则 #2 信号不承载逻辑）。[br]
## [b]幂等[/b]：已连接则不重复（_connect_once 先例）。
func _connect_death(source: Node) -> void:
	if source == null or not source.has_signal(&"character_died"):
		return
	var handler: Callable = Callable(self, &"_on_character_died")
	if not source.is_connected(&"character_died", handler):
		source.connect(&"character_died", handler)


func _on_character_died(character_id: int, _side: int, _ids: Array) -> void:
	if not _cards.has(character_id):
		return
	var card: Variant = _cards[character_id]
	_cards.erase(character_id)
	_forget_from_rows(card)


## 从行内数组摘除已阵亡的卡（排布重算时不把已释放节点算进去）。
func _forget_from_rows(card: Variant) -> void:
	for bucket: Array in [_ally_cards, _enemy_cards]:
		for i: int in range(bucket.size() - 1, -1, -1):
			var entry: Variant = bucket[i]
			if entry == card or entry == null or not is_instance_valid(entry):
				bucket.remove_at(i)


# === 建卡 ====================================================================

## 单侧建卡（entries 形状：[code][{character_id, is_front}][/code]）。
func _build_side(entries: Variant, container: Control, bucket: Array[Control]) -> void:
	if not (entries is Array) or container == null:
		return
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var character_id: int = int((entry as Dictionary).get("character_id", -1))
		if character_id < 0:
			continue
		var card: Control = _spawn_card(character_id,
				bool((entry as Dictionary).get("is_front", true)), container)
		if card != null:
			bucket.append(card)


## 建一张卡：初始渲染快照（HP/ATK）+ 注册。
func _spawn_card(character_id: int, is_front: bool, container: Control) -> Control:
	var card: Control = CardScript.new()
	card.name = "ActorCard%d" % character_id
	container.add_child(card)
	# 非容器父节点不会自动撑开子节点——显式落到最小尺寸（120×168 基准），
	# 否则排布与飘字起点都会按 0×0 计算。
	card.size = card.custom_minimum_size
	_cards[character_id] = card
	card.call(&"set_front_row", is_front)
	# 初始快照：HP 优先读战斗系统（开战已种子），读不到再回退模板/条目 max_hp，
	# 避免首帧「0/0 等刷新」的闪烁。
	var hp: Dictionary = _reader.call(&"hp", character_id)
	var current: int = int(hp.get("current", 0))
	var max_hp: int = int(hp.get("max", 0))
	if max_hp <= 0:
		max_hp = int(_reader.call(&"base_hp", character_id))
		current = maxi(current, max_hp)
	card.call(&"apply_atk", int(_reader.call(&"attack", character_id)))
	card.call(&"apply_hp", current, max_hp)
	_register(character_id)
	return card


## 注册到反馈编排器（编排器未注入时静默跳过——建卡仍可独立测试）。
func _register(character_id: int) -> void:
	if _coordinator == null or not _coordinator.has_method(&"register_card"):
		return
	_coordinator.call(&"register_card", character_id, _cards.get(character_id))


# === 排布 ====================================================================

## 重排两侧全部卡：前排贴中线、后排靠外沿，各自水平居中。
func _relayout() -> void:
	_layout_side(_ally_cards, _ally_container, true)
	_layout_side(_enemy_cards, _enemy_container, false)


## 单侧排布。[param front_at_top] 我方前排在上（贴中线），敌方前排在下。[br]
## 前排卡 100% / 后排卡 85%（[method CharacterStatusCard.set_front_row] 已设 scale），
## 行内按各自实际宽度累加——不做固定网格（前后排卡宽不同）。
func _layout_side(cards: Array[Control], container: Control, front_at_top: bool) -> void:
	if container == null:
		return
	var area: Vector2 = container.size
	if area.x <= 0.0 or area.y <= 0.0:
		area = FALLBACK_AREA_SIZE
	var front: Array[Control] = []
	var back: Array[Control] = []
	for card: Control in cards:
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
	if not front_at_top:
		front_y = area.y - ROW_MARGIN - front_h
		back_y = ROW_MARGIN
	_place_row(front, area.x, front_y)
	_place_row(back, area.x, back_y)


## 行内水平居中摆放。
func _place_row(row: Array[Control], area_width: float, y: float) -> void:
	if row.is_empty():
		return
	var total: float = CARD_GAP * float(row.size() - 1)
	for card: Control in row:
		total += card.size.x * card.scale.x
	var x: float = (area_width - total) * 0.5
	for card: Control in row:
		card.position = Vector2(x, y)
		x += card.size.x * card.scale.x + CARD_GAP


## 行高——取该行最高卡的实际视觉高度（无卡时 0）。
func _card_height(row: Array[Control]) -> float:
	var height: float = 0.0
	for card: Control in row:
		height = maxf(height, card.size.y * card.scale.y)
	return height


## 容器尺寸变化 → 重排（锚点布局下窗口缩放不丢排列）。
func _connect_resized(container: Control) -> void:
	if container == null or container.resized.is_connected(_relayout):
		return
	container.resized.connect(_relayout)
