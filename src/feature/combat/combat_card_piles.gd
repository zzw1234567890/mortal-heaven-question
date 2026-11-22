extends RefCounted
## CombatCardPiles —— 战斗内三堆牌的行值操作（从 combat_system.gd 拆分）。[br]
## [br][b]职责边界[/b]：牌库 / 弃牌堆 / 手牌这三个数组的[b]增删与查询[/b]——
## 抽牌（含牌库抽空返还）、洗牌、弃牌、开局发牌、读档原样恢复、以及三处查询口。[br]
## [br][b]不持数组[/b]（ADR-0008 §状态单一所有者）：[code]_deck[/code] /
## [code]_discard_pile[/code] / [code]_hand[/code] / [code]_rng[/code] 仍归父节点，
## 本模块只经 [code]_parent.get[/code] 拿到数组引用就地增删——数组是引用类型，
## 就地改与「父节点自己改」等价，而「换一个新数组回去」会打断
## [code]combat_phase_manager._enforce_hand_limit[/code] 等处的既有别名假设。[br]
## [br][b]为什么不碰出牌结算[/b]：牌从手里进弃牌堆的「打出」语义归
## [code]combat_card_resolver.gd[/code]（它经父节点的 [method discard_card] 走同一条
## 落库路径）；本模块只管「数组怎么动」，不判「该不该动」。[br]
## [br][b]随机数口径[/b]：洗牌与牌库抽空返还共用父节点的 [code]_rng[/code]
## （[method CombatSystem.set_rng_seed] 之后确定性可复现）；本模块不自建 RNG。[br]
## [br]来源: ADR-0008 §出牌结算流程、GDD combat-system.md §2 抽牌规则 / AC-013、
## 先例 [code]combat_phase_manager.gd[/code] 的拆分注记。

## 回合经济规则（开局手牌张数 / 先手判定——纯函数，与阶段侧同一份口径）。
const TurnEconomy := preload("res://src/feature/combat/combat_turn_economy.gd")

## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 抽牌 ========================================================================

## 从牌库抽 n 张牌到手牌——牌库抽空时从弃牌堆随机返还 1 张到牌库底部。[br]
## [br]来源: GDD §2 抽牌规则 / AC-013。
func draw_cards(count: int) -> void:
	var deck: Array = _parent.get("_deck")
	var discard: Array = _parent.get("_discard_pile")
	var hand: Array = _parent.get("_hand")
	var rng: RandomNumberGenerator = _parent.get("_rng")
	for i in range(count):
		if deck.is_empty():
			# AC-013：牌库抽空 + 弃牌堆非空 → 随机返还 1 张到牌库底部
			if discard.is_empty():
				# 牌库和弃牌堆均空 → 跳过抽牌，不报错
				return
			var idx: int = rng.randi_range(0, discard.size() - 1)
			var card: Variant = discard[idx]
			discard.remove_at(idx)
			deck.append(card)
		if deck.is_empty():
			return
		var drawn: Variant = deck[0]
		deck.remove_at(0)
		hand.append(drawn)


## 发开局手牌——GDD §2「开局手牌：先手 4 张，后手 5 张」。<br>
## [br][b]为什么需要显式发牌[/b]：GDD 抽牌表里「先手第 1 回合不抽牌」的前提是
## 玩家手里[b]已经有[/b]开局手牌。此前该前提没有兑现——第 1 回合不抽牌就等于空手开局
## （无牌可出），所以旧实现用「恒抽 2 张」绕过。本方法把开局手牌补上，
## 抽牌表才能按 GDD 原样执行。<br>
## [br][b]与 [method init_deck] 的分工[/b]：init_deck 只负责「洗牌 + 清手牌」
## （既有 Story 001 契约，不改），发牌是它的下一步——单独成方法让
## 「牌堆就绪」与「发牌」可以分别测试，也让 [method CombatSystem.battle_start]
## 能在牌堆为空时安全跳过。<br>
## [br][b]牌堆不足时发多少算多少[/b]：不从弃牌堆返还（那会让开局凭空多出牌），
## 有多少发多少——不足是牌组配置问题，应由组牌侧暴露。<br>
## [br][b]返回[/b]: 实际发出的张数（牌堆为空时为 0）。
func deal_opening_hand() -> int:
	var count: int = TurnEconomy.opening_hand_size(is_first_player())
	# 沿用既有抽牌路径（含牌库抽空返还与手牌追加语义）——不另开一条发牌实现，
	# 否则「开局手牌」与「回合抽牌」的手牌顺序语义会分家。
	var hand: Array = _parent.get("_hand")
	var before: int = hand.size()
	draw_cards(count)
	return hand.size() - before


## 先手标志——开战 config 供数（回合经济规则的输入）。[br]
## [br][b]为什么留在这里[/b]：回合经济的三处消费（开局手牌、每回合抽牌、END 费用重置）
## 都要问同一个问题，口径取父节点定格的开战配置快照。
func is_first_player() -> bool:
	return TurnEconomy.is_first_player(_parent.get("_battle_config"))


# === 洗牌与弃牌 ==================================================================

## 初始化战斗牌库——接收卡组 ID 列表并洗牌。[br]
## [br][param card_ids] 卡组卡牌实例 ID 列表。[br]
## [br]洗牌使用父节点的 [code]_rng[/code]——[method CombatSystem.set_rng_seed]
## 之后确定性可复现。
func init_deck(card_ids: Array) -> void:
	var rng: RandomNumberGenerator = _parent.get("_rng")
	var deck: Array = card_ids.duplicate()
	_parent.get("_discard_pile").clear()
	_parent.get("_hand").clear()
	# Fisher-Yates 洗牌
	var n: int = deck.size()
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	_parent.set("_deck", deck)


## 洗牌——将弃牌堆全部洗回牌库，弃牌堆清空。
func shuffle_discard_into_deck() -> void:
	var deck: Array = _parent.get("_deck")
	var discard: Array = _parent.get("_discard_pile")
	var rng: RandomNumberGenerator = _parent.get("_rng")
	while not discard.is_empty():
		var idx: int = rng.randi_range(0, discard.size() - 1)
		var card: Variant = discard[idx]
		discard.remove_at(idx)
		deck.append(card)


## 弃牌——将手牌中的指定卡牌移到弃牌堆。[br]
## [br][param card_instance_id] 卡牌实例 ID。
func discard_card(card_instance_id: int) -> void:
	var hand: Array = _parent.get("_hand")
	for i in range(hand.size() - 1, -1, -1):
		var card: Variant = hand[i]
		var cid: Variant = null
		if card is Dictionary:
			cid = card.get("card_instance_id", card.get("instance_id", -1))
		elif card is int:
			cid = card
		elif card != null and card.has_method("get"):
			cid = card.get("card_instance_id", -1)
		if cid == card_instance_id:
			hand.remove_at(i)
			_parent.get("_discard_pile").append(card)
			return
	push_warning("CombatSystem: discard_card card_instance_id=%d not found in hand" % card_instance_id)


## 添加卡牌到牌库底部（绑定卡阵亡洗回——BindingManager 回调）。
func add_card_to_deck(card_instance_id: int) -> void:
	_parent.get("_deck").append(card_instance_id)


## 添加卡牌到弃牌堆（绑定卡覆盖进弃牌——BindingManager 回调）。
func add_card_to_discard(card_instance_id: int) -> void:
	_parent.get("_discard_pile").append(card_instance_id)


# === 整堆替换（注入与读档）======================================================

## 设置牌库 / 弃牌堆 / 手牌（[b]deprecated[/b]——测试注入用，生产代码使用 init_deck）。
func set_deck_state(deck: Array, discard: Array, hand: Array) -> void:
	_parent.set("_deck", deck.duplicate())
	_parent.set("_discard_pile", discard.duplicate())
	_parent.set("_hand", hand.duplicate())


## 按存档快照原样恢复三堆牌——读档续战专用（顺序与内容都取存档值）。[br]
## [br][b]与 [method init_deck] 的分工[/b]：[code]init_deck[/code] 是「开一场新仗」——
## 拿本局卡组洗一遍再清空手牌；本方法是「接着打」——牌面已经在存档里了，
## 洗牌会把它洗没（玩家攥着的那两张关键牌、已经垫进弃牌堆的那几张，全都会变）。[br]
## [br][b]不洗牌、不发牌[/b]：顺序就是抽牌顺序（[method draw_cards] 取
## [code]_deck[0][/code]），动了顺序等于换了一副牌；开局手牌也已经在 [code]hand[/code] 里，
## 再发一次等于凭空多几张。[br]
## [br][b]参数顺序与 [method set_deck_state] 不同[/b]（那里是牌库 / 弃牌堆 / 手牌）：
## 本方法的调用方（读档重建）按「手上 / 待抽 / 已弃」的自然顺序给，且带名字的类型
## 让写错的调用点在编译期就红。[br]
## [br][param p_hand] 存档里的手牌（实例 ID 列表，顺序即存档顺序）。[br]
## [param p_draw_pile] 存档里的抽牌堆。[br]
## [param p_discard_pile] 存档里的弃牌堆。
func restore_piles(p_hand: Array, p_draw_pile: Array, p_discard_pile: Array) -> void:
	_parent.set("_hand", p_hand.duplicate())
	_parent.set("_deck", p_draw_pile.duplicate())
	_parent.set("_discard_pile", p_discard_pile.duplicate())


# === 查询 ========================================================================

## 返回牌库（查询 API）。
func get_deck() -> Array:
	return _parent.get("_deck")


## 返回弃牌堆（查询 API）。
func get_discard_pile() -> Array:
	return _parent.get("_discard_pile")


## 返回手牌（查询 API）。
func get_hand() -> Array:
	return _parent.get("_hand")
