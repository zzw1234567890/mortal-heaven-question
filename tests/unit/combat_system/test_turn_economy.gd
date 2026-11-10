extends GutTest
## 回合经济规则单元测试（combat-ui-interaction 002 / 本轮）。[br]
## [br][b]覆盖[/b]：GDD §2 抽牌表（先手第 1 回合 0 / 后手第 1 回合 3 / 第 2 回合起 2）、
## 开局手牌（4 / 5）、手牌上限溢出、先手标志的缺省与脏数据兜底。[br]
## [br][b]为什么单测纯函数[/b]：这些数字是 GDD 明文规则，最容易被后续改动悄悄漂移
## （旧实现恒返 2 就是漂移的实例）。纯函数测试零依赖、改一处立刻变红。

const Economy := preload("res://src/feature/combat/combat_turn_economy.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 抽牌表（GDD §2）
# ═══════════════════════════════════════════════════════════════════════════════

func test_draw_first_player_turn1_is_zero() -> void:
	assert_eq(Economy.draw_count(true, 1), 0, "先手第 1 回合不抽牌（使用开局手牌）")


func test_draw_second_player_turn1_is_three() -> void:
	assert_eq(Economy.draw_count(false, 1), 3, "后手第 1 回合抽 3 张（补偿）")


func test_draw_base_from_turn2() -> void:
	assert_eq(Economy.draw_count(true, 2), 2, "先手第 2 回合基础 2 张")
	assert_eq(Economy.draw_count(false, 2), 2, "后手第 2 回合基础 2 张")
	assert_eq(Economy.draw_count(true, 9), 2, "第 9 回合仍为基础 2 张")


func test_draw_turn_below_one_treated_as_turn1() -> void:
	## 回合号未落定（桩环境）时按第 1 回合从严——比按基础值宽松更安全
	## （宽松会在真实的第 1 回合多抽 2 张）。
	assert_eq(Economy.draw_count(true, 0), 0, "turn=0 按第 1 回合处理（先手 0）")
	assert_eq(Economy.draw_count(false, 0), 3, "turn=0 按第 1 回合处理（后手 3）")
	assert_eq(Economy.draw_count(true, -5), 0, "负回合号同样按第 1 回合")


# ═══════════════════════════════════════════════════════════════════════════════
# 开局手牌（GDD §2）
# ═══════════════════════════════════════════════════════════════════════════════

func test_opening_hand_first_player() -> void:
	assert_eq(Economy.opening_hand_size(true), 4, "先手开局 4 张")


func test_opening_hand_second_player() -> void:
	assert_eq(Economy.opening_hand_size(false), 5, "后手开局 5 张（补偿）")


# ═══════════════════════════════════════════════════════════════════════════════
# 手牌上限
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_overflow_under_limit_is_zero() -> void:
	assert_eq(Economy.hand_overflow(7), 0, "未超限不弃牌")
	assert_eq(Economy.hand_overflow(10), 0, "恰好等于上限不弃牌")


func test_hand_overflow_over_limit() -> void:
	assert_eq(Economy.hand_overflow(12), 2, "12 张需弃 2 张")
	assert_eq(Economy.hand_overflow(11, 10), 1, "自定义上限同样生效")


# ═══════════════════════════════════════════════════════════════════════════════
# 先手标志读取（缺省与脏数据兜底）
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_first_player_defaults_true_when_absent() -> void:
	## 缺省先手 = 与改造前的硬编码口径一致（不产生行为漂移）
	assert_true(Economy.is_first_player({}), "空 config 缺省先手")


func test_is_first_player_reads_explicit_false() -> void:
	assert_false(Economy.is_first_player({"is_first_player": false}), "显式 false 生效")


func test_is_first_player_ignores_non_bool() -> void:
	## 读到字符串 / null 时不猜「谁是后手」——猜错会让一方白拿 +1 费与 3 张牌
	assert_true(Economy.is_first_player({"is_first_player": "no"}), "非布尔值按先手处理")
	assert_true(Economy.is_first_player({"is_first_player": null}), "null 按先手处理")
