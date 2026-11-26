extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## DEBT-CUI-010 集成用例：真实战斗场景里底部条「≡牌库:N / 弃:N」随牌堆变化。[br]
## [br][b]背景[/b]：计数组件自 Story 005 起只有 [code]set_deck_counts[/code] 一个入口，
## 而生产代码里[b]没有任何调用方[/b]——数字恒为 0。本文件走真实 [code]combat_scene.tscn[/code]
## （[code]FullBattleFixture[/code] 的既有装配），断言屏幕上的数字与
## [code]get_deck()[/code] / [code]get_discard_pile()[/code] 的实际大小一致。[br]
## [br][b]为什么必须走真实场景[/b]：断链的现场正在「组件建了、setter 有、没人调」这一段——
## 直接 new 一个 CombatBottombar 再自己调 setter 的用例永远绿（既有
## [code]test_cost_display.gd[/code] 就是那种口径），它证明不了订阅存在。[br]
## [br]Story 类型 Integration —— 此文件为 BLOCKING 证据。

## 计数组件上「未接线」的占位符（[code]deck_counter.gd[/code] 的 [member _has_data] 为假时）。
const PLACEHOLDER: String = "-"


func before_all() -> void:
	# CardSystem 的模板是异步加载的——等它读完（上限防挂死，同既有夹具口径）。
	for _i: int in range(300):
		if CardSystem.get_template(&"basic_attack") != null:
			break
		await get_tree().process_frame


func before_each() -> void:
	setup(false)
	confirm_deploy()


func after_each() -> void:
	await teardown()


## 底部条里的计数组件（真实场景节点）。
func counter() -> Variant:
	var bar: Variant = _root().get("combat_bottombar")
	assert_not_null(bar, "前置：底部条应存在")
	return bar.get("deck_counter")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 开战即接线：数字 == 实际牌堆大小
# ═══════════════════════════════════════════════════════════════════════════════

func test_counts_equal_real_piles_after_battle_start() -> void:
	# Then: 开战（含 init_deck + 开局发牌）之后数字与牌堆一致
	var deck_size: int = int(cs.call("get_deck").size())
	var discard_size: int = int(cs.call("get_discard_pile").size())
	assert_true(bool(counter().call("has_data")),
			"开战后应已收到过真实计数——占位符说明订阅没接上")
	assert_eq(counter().call("get_deck_count"), deck_size,
			"屏幕牌库数应等于 get_deck().size()")
	assert_eq(counter().call("get_discard_count"), discard_size,
			"屏幕弃牌数应等于 get_discard_pile().size()")
	assert_eq(counter().call("get_deck_text"), "≡牌库:%d" % deck_size,
			"牌库文本应与实际堆长一致")


func test_counter_text_is_not_stale_zero() -> void:
	# 本轮债的现场：牌堆有牌、屏幕写 0
	assert_gt(int(cs.call("get_deck").size()), 0, "前置：开局发牌后牌库应仍有牌")
	assert_ne(counter().call("get_deck_text"), "≡牌库:0",
			"牌库非空时屏幕不得显示 0（DEBT-CUI-010 的原现场）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 抽一张 → 牌库 -1
# ═══════════════════════════════════════════════════════════════════════════════

func test_draw_decrements_deck_count() -> void:
	# Arrange
	var before: int = int(cs.call("get_deck").size())
	assert_gt(before, 0, "前置：牌库应有牌可抽")
	# Act——走生产抽牌路径（combat_phase_manager 每回合调的就是它）
	cs.call("_draw_cards", 1)
	# Assert
	assert_eq(int(cs.call("get_deck").size()), before - 1, "牌库应少 1 张")
	assert_eq(counter().call("get_deck_count"), int(cs.call("get_deck").size()),
			"屏幕牌库数应跟随抽牌")
	assert_eq(counter().call("get_deck_text"), "≡牌库:%d" % (before - 1),
			"牌库文本应跟随抽牌")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 弃一张 → 弃牌堆 +1
# ═══════════════════════════════════════════════════════════════════════════════

func test_discard_increments_discard_count() -> void:
	# Arrange
	var hand: Array = cs.call("get_hand")
	assert_gt(hand.size(), 0, "前置：手牌应非空")
	var discard_before: int = int(cs.call("get_discard_pile").size())
	# Act——走生产弃牌路径（出牌结算与手牌超限弃置共用它）
	cs.call("discard_card", int(hand[0]))
	# Assert
	assert_eq(int(cs.call("get_discard_pile").size()), discard_before + 1,
			"弃牌堆应多 1 张")
	assert_eq(counter().call("get_discard_count"), discard_before + 1,
			"屏幕弃牌数应跟随弃牌")
	assert_eq(counter().call("get_discard_text"), "弃:%d" % (discard_before + 1),
			"弃牌文本应跟随弃牌")


## 弃手牌里不存在的 ID（虚构实例）——两堆都没动，屏幕数字不变。
func test_discard_unknown_card_keeps_counts_unchanged() -> void:
	# Arrange
	var deck_before: int = counter().call("get_deck_count")
	var discard_before: int = counter().call("get_discard_count")
	# Act
	cs.call("discard_card", 987654321)
	# Assert
	assert_eq(counter().call("get_deck_count"), deck_before,
			"弃牌失败时牌库数不应变")
	assert_eq(counter().call("get_discard_count"), discard_before,
			"弃牌失败时弃牌数不应变")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 洗回弃牌堆 → 两个数字同步变化
# ═══════════════════════════════════════════════════════════════════════════════

func test_shuffle_moves_discard_into_deck_and_syncs_both() -> void:
	# Arrange——先垫两张进弃牌堆
	var hand: Array = cs.call("get_hand")
	assert_gte(hand.size(), 2, "前置：手牌至少 2 张")
	cs.call("discard_card", int(hand[0]))
	cs.call("discard_card", int(hand[1]))
	var deck_before: int = int(cs.call("get_deck").size())
	var discard_before: int = int(cs.call("get_discard_pile").size())
	assert_gt(discard_before, 0, "前置：弃牌堆应有牌")
	# Act
	cs.call("shuffle_discard_into_deck")
	# Assert——两个数字同时变，且都等于各自的真实堆长
	assert_eq(int(cs.call("get_discard_pile").size()), 0, "洗回后弃牌堆应清空")
	assert_eq(int(cs.call("get_deck").size()), deck_before + discard_before,
			"洗回后牌库应接纳全部弃牌")
	assert_eq(counter().call("get_deck_count"), deck_before + discard_before,
			"屏幕牌库数应同步")
	assert_eq(counter().call("get_discard_count"), 0, "屏幕弃牌数应同步为 0")
	assert_eq(counter().call("get_discard_text"), "弃:0",
			"真值恰好是 0 时应显示 0（而不是占位符）")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 牌堆抽空：0 而不是负数
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_piles_show_zero_not_negative() -> void:
	# Arrange——真实空牌堆（开一场没有卡组的仗：init_deck([]) 是合法输入）
	cs.call("init_deck", [])
	# Then
	assert_eq(cs.call("get_deck").size(), 0, "前置：牌库应为空")
	assert_eq(counter().call("get_deck_count"), 0, "空牌库应显示 0")
	assert_eq(counter().call("get_discard_count"), 0, "空弃牌堆应显示 0")
	assert_eq(counter().call("get_deck_text"), "≡牌库:0", "空牌库文本应为 0")
	assert_true(bool(counter().call("has_data")), "空牌堆也是「有数据」——0 是真的 0")
	# Act——两堆皆空时抽牌（生产路径会走到这条分支）
	cs.call("_draw_cards", 2)
	# Assert——不报错、更不变负
	assert_eq(counter().call("get_deck_count"), 0, "抽空后仍应为 0 而不是负数")
	assert_false(counter().call("get_deck_text").contains("-"),
			"牌库文本不得出现负号：%s" % counter().call("get_deck_text"))


# ═══════════════════════════════════════════════════════════════════════════════
# 6. 退场成对退订：旧容器不再往已释放的组件推数
# ═══════════════════════════════════════════════════════════════════════════════

func test_exit_tree_unbinds_deck_wiring() -> void:
	# Arrange
	var wiring: Variant = scene.get("deck_wiring")
	assert_not_null(wiring, "前置：容器应持有计数订阅句柄")
	assert_not_null(wiring.get("_source"), "前置：订阅应已建立")
	# Act——走真实退场路径
	scene.free()
	scene = null
	# Assert
	assert_null(wiring.get("_source"), "退场应断开订阅（否则下一场战斗里旧容器仍在推数）")
	assert_eq(cs.get_signal_connection_list(&"pile_changed").size(), 0,
			"退场后 CombatSystem 上不应残留 pile_changed 订阅")
	# 退场后再动牌堆——不应报错（组件已随场景释放）
	cs.call("init_deck", [1, 2, 3])
