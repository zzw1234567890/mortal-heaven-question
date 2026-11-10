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
	cs.call("set_card_instances", {})


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
	# Arrange——[b]第 2 回合[/b]：GDD §2 抽牌表里第 1 回合按先后手分岔
	# （先手不抽牌），基础 2 张从第 2 回合起生效。本用例验证的是「抽牌动作本身
	# 会把牌从牌堆移进手牌」，故直接摆出第 2 回合的上下文。
	cs.call("init_deck", [1, 2, 3, 4, 5])

	# Act
	cs.call("set_deck_state", [1, 2, 3, 4, 5], [], [])
	cs.call("set_hand", [])
	cs.call("set_battle_active", true, 2)  # 第 2 回合
	cs.advance_phase()  # PREPARATION → DRAW

	# Assert
	assert_eq(cs.call("get_hand").size(), 2, "手牌应有 2 张（第 2 回合基础抽牌数）")
	assert_eq(cs.call("get_deck").size(), 3, "牌库应剩 3 张")


## 第 1 回合抽牌按先后手分岔（GDD §2 抽牌表——先手 0 / 后手 3）。
func test_draw_count_turn1_splits_by_first_player() -> void:
	# Arrange + Act——先手第 1 回合：不抽牌（使用开局手牌）
	cs.call("set_deck_state", [1, 2, 3, 4, 5], [], [])
	cs.call("set_hand", [])
	cs.set("_battle_config", {"is_first_player": true})
	cs.call("set_battle_active", true, 1)
	cs.advance_phase()  # PREPARATION → DRAW

	# Assert
	assert_eq(cs.call("get_hand").size(), 0, "先手第 1 回合不抽牌")

	# Arrange + Act——后手第 1 回合：抽 3 张（补偿）
	cs.call("set_deck_state", [1, 2, 3, 4, 5], [], [])
	cs.call("set_hand", [])
	cs.set("_battle_config", {"is_first_player": false})
	cs.call("set_battle_active", true, 1)
	cs.advance_phase()  # PREPARATION → DRAW

	# Assert
	assert_eq(cs.call("get_hand").size(), 3, "后手第 1 回合抽 3 张（补偿）")
	assert_eq(cs.call("get_deck").size(), 2, "牌库相应减少 3 张")
	cs.set("_battle_config", {})


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


## 打出的卡也进弃牌堆（GDD card-system §牌库与弃牌堆：已消耗的牌）。
## [br]回归点：此前 play_card 只把卡从手牌删除、不落弃牌堆——初始 7 张卡组
## 打空后长局再也抽不到牌。
func test_played_card_moves_to_discard() -> void:
	# Arrange——独立实例：Autoload 的 get_card_instance_cb 已注入 CardSystem，
	# 会绕过 set_card_instances 测试缓存（见 combat_card_resolver._get_card_instance）。
	var local: Node = load("res://src/feature/combat_system.gd").new()
	local.call("set_auto_advance", false)
	local.call("set_scene_change", false)
	local.call("set_card_instances", {77: {"card_instance_id": 77, "cost": 0}})
	local.call("set_deck_state", [], [88], [77])
	local.call("set_battle_active", true)
	local.call("advance_phase")  # PREPARATION → DRAW
	local.call("advance_phase")  # DRAW → PLAY
	# Act
	var result: Dictionary = local.call("play_card_detailed", 77, [])
	# Assert
	assert_true(bool(result.get("ok", false)), "0 费卡应能打出")
	assert_eq(local.call("get_hand").size(), 0, "打出的卡应离开手牌")
	assert_eq(local.call("get_discard_pile").size(), 2, "弃牌堆应增加该卡（原有 1 + 打出 1）")
	assert_eq(int(local.call("get_discard_pile")[1]), 77, "弃牌堆记录的是打出的卡实例")
	local.free()


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
