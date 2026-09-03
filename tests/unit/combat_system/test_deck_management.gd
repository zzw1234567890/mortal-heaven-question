extends GutTest
## Story 8-1 验收测试：CombatSystem 牌库管理内建。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 CombatSystem Autoload 实例（非 new()——Autoload 全局单例）
##   - 固定 RNG seed 确保确定性
##   - 验证 init_deck / discard_card / shuffle_discard_into_deck

## CombatSystem Autoload 全局单例——不 new()。
var cs: Node = null


func before_each() -> void:
	cs = Engine.get_main_loop().root.get_node("/root/CombatSystem")
	assert_not_null(cs, "CombatSystem Autoload 应存在")
	cs.set_auto_advance(false)
	cs.set_scene_change(false)
	cs.set_rng_seed(42)


func after_each() -> void:
	# 清理战斗状态
	cs.set_battle_active(false)
	cs.call("set_deck_state", [], [], [])


# ============================================================================
# AC-001：init_deck 接收卡组 ID 列表并洗牌初始化 _deck
# ============================================================================

func test_init_deck_initializes() -> void:
	# Arrange
	var card_ids: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

	# Act
	cs.call("init_deck", card_ids)

	# Assert
	var deck: Array = cs.call("get_deck")
	assert_eq(deck.size(), 10, "牌库应有 10 张卡")


# ============================================================================
# AC-002：init_deck 后 _deck.size() == card_ids.size()，_hand 和 _discard_pile 为空
# ============================================================================

func test_init_deck_clears_hand_and_discard() -> void:
	# Arrange
	cs.call("set_deck_state", [1, 2], [3, 4], [5, 6])

	# Act
	cs.call("init_deck", [10, 20, 30])

	# Assert
	assert_eq(cs.call("get_deck").size(), 3, "牌库应有 3 张")
	assert_eq(cs.call("get_hand").size(), 0, "手牌应清空")
	assert_eq(cs.call("get_discard_pile").size(), 0, "弃牌堆应清空")


# ============================================================================
# AC-003：_draw_cards 抽牌后手牌增加，牌库减少对应数量
# ============================================================================

func test_draw_cards_moves_to_hand() -> void:
	# Arrange
	cs.call("init_deck", [1, 2, 3, 4, 5])

	# Act——_draw_cards 是内部方法，通过 set_battle_active + advance 到 DRAW 阶段触发
	# 或直接测试抽牌逻辑
	cs.call("set_deck_state", [1, 2, 3, 4, 5], [], [])
	cs.call("set_hand", [])
	# 触发 DRAW 阶段
	cs.set_battle_active(true)
	cs.advance_phase()  # PREPARATION → DRAW

	# Assert
	assert_eq(cs.call("get_hand").size(), 2, "手牌应有 2 张（基础抽牌数）")
	assert_eq(cs.call("get_deck").size(), 3, "牌库应剩 3 张")


# ============================================================================
# AC-004：discard_card 将手牌中的卡牌移到弃牌堆
# ============================================================================

func test_discard_card_moves_to_discard() -> void:
	# Arrange
	cs.call("set_deck_state", [], [], [1, 2, 3])

	# Act
	cs.call("discard_card", 2)

	# Assert
	assert_eq(cs.call("get_hand").size(), 2, "手牌应剩 2 张")
	assert_eq(cs.call("get_discard_pile").size(), 1, "弃牌堆应有 1 张")


# ============================================================================
# AC-005：shuffle_discard_into_deck 将弃牌堆全部洗回牌库
# ============================================================================

func test_shuffle_discard_into_deck() -> void:
	# Arrange
	cs.call("set_deck_state", [1], [2, 3, 4], [])

	# Act
	cs.call("shuffle_discard_into_deck")

	# Assert
	assert_eq(cs.call("get_deck").size(), 4, "牌库应有 4 张")
	assert_eq(cs.call("get_discard_pile").size(), 0, "弃牌堆应清空")


# ============================================================================
# AC-006：牌库+弃牌堆均空时 _draw_cards 不崩溃
# ============================================================================

func test_draw_cards_empty_no_crash() -> void:
	# Arrange
	cs.call("set_deck_state", [], [], [])
	cs.call("set_hand", [])

	# Act——触发抽牌
	cs.set_battle_active(true)
	cs.advance_phase()  # PREPARATION → DRAW

	# Assert——不崩溃，手牌仍为空
	assert_eq(cs.call("get_hand").size(), 0, "牌库+弃牌堆空时手牌应为空")


# ============================================================================
# AC-007：set_deck_state 保留为测试注入用（标记 deprecated）
# ============================================================================

func test_set_deck_state_still_works() -> void:
	# Act
	cs.call("set_deck_state", [1, 2], [3], [4, 5])

	# Assert
	assert_eq(cs.call("get_deck").size(), 2, "牌库 2 张")
	assert_eq(cs.call("get_discard_pile").size(), 1, "弃牌堆 1 张")
	assert_eq(cs.call("get_hand").size(), 2, "手牌 2 张")


# ============================================================================
# AC-008：get_deck / get_discard_pile / get_hand 保留为查询 API
# ============================================================================

func test_query_apis_return_arrays() -> void:
	# Arrange
	cs.call("set_deck_state", [1], [2], [3])

	# Act + Assert
	assert_eq(typeof(cs.call("get_deck")), TYPE_ARRAY, "get_deck 应返回 Array")
	assert_eq(typeof(cs.call("get_discard_pile")), TYPE_ARRAY, "get_discard_pile 应返回 Array")
	assert_eq(typeof(cs.call("get_hand")), TYPE_ARRAY, "get_hand 应返回 Array")


# ============================================================================
# AC-009：init_deck 使用 _rng 洗牌，set_rng_seed 后确定性可复现
# ============================================================================

func test_init_deck_deterministic_with_seed() -> void:
	# Arrange + Act——第一次
	cs.set_rng_seed(123)
	cs.call("init_deck", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	var deck1: Array = cs.call("get_deck").duplicate()

	# 第二次——相同 seed 应得到相同结果
	cs.set_rng_seed(123)
	cs.call("init_deck", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	var deck2: Array = cs.call("get_deck").duplicate()

	# Assert
	assert_eq(deck1, deck2, "相同 seed 应得到相同洗牌结果")


# ============================================================================
# AC-010：全量测试零回归
# ============================================================================

func test_no_regression() -> void:
	# 此 AC 在 Sprint QA 阶段通过全量测试验证
	# 此处验证 CombatSystem 基础功能未破坏
	cs.set_battle_active(true)
	assert_true(cs.is_battle_active(), "战斗应可激活")
	cs.set_battle_active(false)
	assert_false(cs.is_battle_active(), "战斗应可关闭")
