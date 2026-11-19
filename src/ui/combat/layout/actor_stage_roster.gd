class_name ActorStageRoster
extends RefCounted
## ActorStageRoster —— 战场角色卡的节点表与建卡（DEBT-CUI-007-2 同类拆分）。
##
## [b]职责[/b]：持有「角色 ID → 角色卡节点」与左右两行数组——建卡（初始 HP/ATK
## 快照）、注册进反馈编排器、阵亡摘除、清场、命中测试。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_actor_stage.gd[/code] 加上「当前操作角色 /
## 手牌快照 / 出牌门面」后超过单文件 300 行软上限；节点表与建卡是独立的一摊事，
## 与信号订阅、施法者状态无关。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[member cards] 是 UI 节点表，不是游戏状态
## 副本；HP/ATK 建卡瞬间经取数入口现读一次。[br][b]零轮询[/b]：全部由装配台显式驱动。
##
## 来源: combat-ui-layout Story 002、ADR-0031、DEBT-CUI-007-2。

## 角色卡脚本（按需 new——同 CombatLayout 的组件装配先例）。
const CardScript: GDScript = preload("res://src/ui/combat/layout/character_status_card.gd")

## 角色 ID → 卡节点（UI 节点表）。
var cards: Dictionary = {}
## 敌方卡（按建卡顺序——命中测试的逆序依据）。
var enemy_cards: Array[Control] = []
## 我方卡（按建卡顺序）。
var ally_cards: Array[Control] = []

## 取数入口（HP/ATK/名册——装配台注入）。
var _reader: RefCounted = null
## 反馈编排器（可空——为空时只建卡不注册）。
var _coordinator: Control = null


## 构造——注入取数入口。
func _init(p_reader: RefCounted) -> void:
	_reader = p_reader


## 绑定反馈编排器（已建卡补注册）。
func bind_coordinator(p_coordinator: Control) -> void:
	_coordinator = p_coordinator
	for character_id: int in cards.keys():
		_register(character_id)


## 单侧建卡（entries 形状：[code][{character_id, is_front}][/code]）。
func build_side(p_entries: Variant, p_container: Control,
		p_bucket: Array[Control]) -> void:
	if not (p_entries is Array) or p_container == null:
		return
	for entry: Variant in p_entries:
		if not (entry is Dictionary):
			continue
		var character_id: int = int((entry as Dictionary).get("character_id", -1))
		if character_id < 0:
			continue
		var card: Control = _spawn(character_id,
				bool((entry as Dictionary).get("is_front", true)), p_container)
		if card != null:
			p_bucket.append(card)


## 清空全部卡（先注销再释放——防编排器持悬空引用）。
func clear() -> void:
	for character_id: int in cards.keys():
		if _coordinator != null and _coordinator.has_method(&"unregister_card"):
			_coordinator.call(&"unregister_card", character_id)
		var card: Control = cards[character_id] as Control
		if card != null and is_instance_valid(card):
			if card.get_parent() != null:
				card.get_parent().remove_child(card)
			card.queue_free()
	cards.clear()
	ally_cards.clear()
	enemy_cards.clear()


## 阵亡摘除——从节点表与两行数组里移除（卡节点本身由编排器做淡出）。[br]
## [b]返回[/b]: 该角色是否曾在本表里。
func forget(p_character_id: int) -> bool:
	if not cards.has(p_character_id):
		return false
	var card: Variant = cards[p_character_id]
	cards.erase(p_character_id)
	for bucket: Array in [ally_cards, enemy_cards]:
		for i: int in range(bucket.size() - 1, -1, -1):
			var entry: Variant = bucket[i]
			if entry == card or entry == null or not is_instance_valid(entry):
				bucket.remove_at(i)
	return true


## 查询角色卡（已释放返回 null——防调用方拿悬空引用）。
func get_card(p_character_id: int) -> Control:
	var card: Variant = cards.get(p_character_id)
	if card == null or not is_instance_valid(card):
		return null
	if not (card is Control):
		return null
	return card


## 已建卡数量（两侧合计）。
func count() -> int:
	return cards.size()


## 命中测试——全局坐标下的敌方角色 ID；无命中 -1。
func enemy_at(p_global_pos: Vector2) -> int:
	return _hit(enemy_cards, p_global_pos)


## 命中测试——全局坐标下的我方角色 ID；无命中 -1。
func ally_at(p_global_pos: Vector2) -> int:
	return _hit(ally_cards, p_global_pos)


# === 内部 =====================================================================

## 建一张卡：初始渲染快照（HP/ATK）+ 注册。
func _spawn(p_character_id: int, p_is_front: bool, p_container: Control) -> Control:
	var card: Control = CardScript.new()
	card.name = "ActorCard%d" % p_character_id
	p_container.add_child(card)
	# 非容器父节点不会自动撑开子节点——显式落到最小尺寸（120×168 基准），
	# 否则排布与飘字起点都会按 0×0 计算。
	card.size = card.custom_minimum_size
	cards[p_character_id] = card
	card.call(&"set_front_row", p_is_front)
	# 初始快照：HP 优先读战斗系统（开战已种子），读不到再回退模板/条目 max_hp，
	# 避免首帧「0/0 等刷新」的闪烁。
	var hp: Dictionary = _reader.call(&"hp", p_character_id)
	var current: int = int(hp.get("current", 0))
	var max_hp: int = int(hp.get("max", 0))
	if max_hp <= 0:
		max_hp = int(_reader.call(&"base_hp", p_character_id))
		current = maxi(current, max_hp)
	card.call(&"apply_atk", int(_reader.call(&"attack", p_character_id)))
	card.call(&"apply_hp", current, max_hp)
	# 显示名：敌方此前只有头像，玩家分不清同色敌人谁是谁——名与 HP 条绑在一张卡上，
	# 玩家才能读懂「这条血是谁的」。解析口径由取数入口转发（播报与卡面同源）；
	# 取数入口是旧版（无 display_name）时静默跳过——名牌留空，血量照常显示。
	if _reader.has_method(&"display_name"):
		card.call(&"apply_name", str(_reader.call(&"display_name", p_character_id)))
	_register(p_character_id)
	return card


## 注册到反馈编排器（编排器未注入时静默跳过——建卡仍可独立测试）。
func _register(p_character_id: int) -> void:
	if _coordinator == null or not _coordinator.has_method(&"register_card"):
		return
	_coordinator.call(&"register_card", p_character_id, cards.get(p_character_id))


## 逆序命中（视觉上层优先——重叠时玩家点到的是上面那张）。
func _hit(p_row: Array[Control], p_global_pos: Vector2) -> int:
	for i: int in range(p_row.size() - 1, -1, -1):
		var card: Control = p_row[i]
		if not is_instance_valid(card):
			continue
		if card.get_global_rect().has_point(p_global_pos):
			return _id_of(card)
	return -1


## 卡节点 → 角色 ID（查不到 -1）。
func _id_of(p_card: Control) -> int:
	for character_id: int in cards.keys():
		if cards[character_id] == p_card:
			return character_id
	return -1
