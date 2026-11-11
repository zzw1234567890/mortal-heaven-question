extends GutTest
## 战斗奖励掷骰内核——固定 RNG 下的确定性口径。[br]
## [br][b]锁定四件事[/b]：[br]
##   1. 灵石区间掷骰落在区间内，且同种子同结果（可复现）；[br]
##   2. 修为不掷骰，配置多少拿多少；[br]
##   3. 卡牌按 [code]chance[/code] 掷骰，命中与未命中两种情况都可见；[br]
##   4. 抽取顺序（区间先、卡牌后）与「确定性概率不消耗随机数」的口径。[br]
## [br][b]不碰 Autoload[/b]：本文件纯测 [code]combat_reward_roller.gd[/code]
## 的掷骰部分；发放（写资源/收藏）见
## [code]tests/integration/combat_system/test_battle_reward_grant.gd[/code]。
##
## 来源: DEBT-EUI-006-4（掉落是配置而非实得）、GDD combat-system.md §9。

const Roller := preload("res://src/feature/combat/combat_reward_roller.gd")


## 固定种子的 RNG（同种子 = 同序列——可复现的测试接缝）。
func _rng(p_seed: int = 42) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	return rng


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 灵石区间
# ═══════════════════════════════════════════════════════════════════════════════

func test_lingshi_roll_stays_within_range() -> void:
	var rng: RandomNumberGenerator = _rng()
	var config: Dictionary = {"lingshi_min": 4, "lingshi_max": 8}
	for _i: int in range(200):
		var rolled: Dictionary = Roller.roll(config, rng)
		var value: int = int(rolled["lingshi"])
		assert_true(value >= 4 and value <= 8,
				"灵石掷骰应落在 [4, 8]（实际 %d）" % value)
		assert_eq(int(rolled["lingshi_min"]), 4, "区间下限透传")
		assert_eq(int(rolled["lingshi_max"]), 8, "区间上限透传")
		assert_true(bool(rolled["lingshi_rolled"]), "区间配置应标记为已掷骰")


func test_lingshi_roll_is_deterministic_for_same_seed() -> void:
	var config: Dictionary = {"lingshi_min": 4, "lingshi_max": 8}
	var first: Dictionary = Roller.roll(config, _rng(42))
	var second: Dictionary = Roller.roll(config, _rng(42))
	assert_eq(int(first["lingshi"]), int(second["lingshi"]),
			"同种子应掷出同一灵石值（可复现）")


func test_lingshi_roll_fixed_range_is_exact() -> void:
	# 区间收成一点 = 定值：结果确定，且不标记为「掷骰」（没有随机性）
	var rolled: Dictionary = Roller.roll({"lingshi_min": 6, "lingshi_max": 6}, _rng())
	assert_eq(int(rolled["lingshi"]), 6, "min == max 时应取该值")
	assert_false(bool(rolled["lingshi_rolled"]), "无随机性时不标记为掷骰")


func test_lingshi_fixed_value_without_range() -> void:
	var rolled: Dictionary = Roller.roll({"lingshi": 12}, _rng())
	assert_eq(int(rolled["lingshi"]), 12, "定值配置原样返回")
	assert_eq(int(rolled["lingshi_min"]), 12, "定值时下限等于该值")
	assert_eq(int(rolled["lingshi_max"]), 12, "定值时上限等于该值")
	assert_false(bool(rolled["lingshi_rolled"]), "定值不标记为掷骰")


func test_lingshi_swapped_range_is_normalized() -> void:
	var rolled: Dictionary = Roller.roll({"lingshi_min": 9, "lingshi_max": 3}, _rng())
	assert_eq(int(rolled["lingshi_min"]), 3, "上下限颠倒时纠正为下限")
	assert_eq(int(rolled["lingshi_max"]), 9, "上下限颠倒时纠正为上限")
	assert_true(int(rolled["lingshi"]) >= 3 and int(rolled["lingshi"]) <= 9,
			"纠正后掷骰仍落在区间内")


func test_negative_lingshi_clamped_to_zero() -> void:
	var rolled: Dictionary = Roller.roll({"lingshi_min": -5, "lingshi_max": -1}, _rng())
	assert_eq(int(rolled["lingshi"]), 0, "负区间钳到 0（不掉玩家余额）")
	assert_false(bool(rolled["lingshi_rolled"]), "全零区间不掷骰")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 修为（不掷骰）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_passes_through_without_roll() -> void:
	var rolled: Dictionary = Roller.roll({"cultivation": 7}, _rng())
	assert_eq(int(rolled["cultivation"]), 7, "修为配置多少拿多少")


func test_negative_cultivation_clamped_to_zero() -> void:
	assert_eq(int(Roller.roll({"cultivation": -3}, _rng())["cultivation"]), 0,
			"负修为钳到 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 卡牌概率：命中 / 未命中
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_with_full_chance_always_hits() -> void:
	var config: Dictionary = {"cards": [{"card_id": "pei_yuan_dan", "chance": 1.0}]}
	for _i: int in range(20):
		var rolled: Dictionary = Roller.roll(config, _rng())
		assert_eq((rolled["cards"] as Array).size(), 1, "100% 概率应恒命中")
		assert_true((rolled["cards_missed"] as Array).is_empty(), "不应有未命中条目")


func test_card_with_zero_chance_always_misses() -> void:
	var config: Dictionary = {"cards": [{"card_id": "pei_yuan_dan", "chance": 0.0}]}
	var rolled: Dictionary = Roller.roll(config, _rng())
	assert_true((rolled["cards"] as Array).is_empty(), "0% 概率不应命中")
	assert_eq((rolled["cards_missed"] as Array).size(), 1, "未命中条目应被记录")


func test_card_missing_chance_defaults_to_guaranteed() -> void:
	# 旧配置的 cards 只是「卡牌清单」——没有概率即「列出来就给」
	var rolled: Dictionary = Roller.roll({"cards": [{"card_id": "pei_yuan_dan"}]}, _rng())
	assert_eq((rolled["cards"] as Array).size(), 1, "缺 chance 按恒命中")
	assert_almost_eq(float(rolled["cards"][0]["chance"]), 1.0, 0.001, "缺省概率 1.0")


func test_card_chance_hits_and_misses_are_both_observable() -> void:
	# 0.5 概率、固定种子、掷 200 次——两种结果都必须出现（口径可观测）
	var config: Dictionary = {"cards": [{"card_id": "pei_yuan_dan", "chance": 0.5}]}
	var rng: RandomNumberGenerator = _rng(7)
	var hits: int = 0
	var misses: int = 0
	for _i: int in range(200):
		var rolled: Dictionary = Roller.roll(config, rng)
		hits += (rolled["cards"] as Array).size()
		misses += (rolled["cards_missed"] as Array).size()
	assert_eq(hits + misses, 200, "每次掷骰恰好产出一个结果")
	assert_true(hits > 0, "50%% 概率应至少命中一次（实际 %d）" % hits)
	assert_true(misses > 0, "50%% 概率应至少未命中一次（实际 %d）" % misses)


func test_card_roll_is_deterministic_for_same_seed() -> void:
	var config: Dictionary = {"cards": [
		{"card_id": "a", "chance": 0.5}, {"card_id": "b", "chance": 0.5},
	]}
	var first: Dictionary = Roller.roll(config, _rng(99))
	var second: Dictionary = Roller.roll(config, _rng(99))
	assert_eq(first["cards"], second["cards"], "同种子命中集合一致")
	assert_eq(first["cards_missed"], second["cards_missed"], "同种子未命中集合一致")


func test_string_card_entries_treated_as_guaranteed() -> void:
	var rolled: Dictionary = Roller.roll({"cards": ["pei_yuan_dan"]}, _rng())
	assert_eq((rolled["cards"] as Array).size(), 1, "字符串条目按恒命中处理")
	assert_eq(str(rolled["cards"][0]["card_id"]), "pei_yuan_dan", "卡牌 ID 透传")


func test_card_without_card_id_is_dropped() -> void:
	var rolled: Dictionary = Roller.roll({"cards": [{"chance": 1.0}, 42]}, _rng())
	assert_true((rolled["cards"] as Array).is_empty(), "无 card_id 的条目被丢弃")
	assert_true((rolled["cards_missed"] as Array).is_empty(), "也不进未命中列表")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 抽取顺序与随机数消耗口径
# ═══════════════════════════════════════════════════════════════════════════════

func test_deterministic_entries_do_not_consume_random_numbers() -> void:
	# A：恒命中/恒未命中卡牌（不消耗随机数）；B：先掷一次灵石区间
	var deterministic: Dictionary = RenderProbe.run({"cards": [
		{"card_id": "a", "chance": 1.0}, {"card_id": "b", "chance": 0.0}]})
	var with_roll: Dictionary = RenderProbe.run({
		"lingshi_min": 1, "lingshi_max": 3,
		"cards": [{"card_id": "a", "chance": 1.0}, {"card_id": "b", "chance": 0.0}],
	})
	# 恒定概率路径不推进 RNG：下一次 randf() 与从未调用过时一致
	assert_eq(deterministic["next_randf"], RenderProbe.baseline_randf(),
			"确定性概率不应消耗随机数")
	assert_ne(with_roll["next_randf"], RenderProbe.baseline_randf(),
			"灵石区间掷骰应推进随机数")


func test_lingshi_is_rolled_before_cards() -> void:
	# 顺序口径：灵石 → 卡牌。用同一种子的两次调用对比验证「先区间后卡牌」，
	# 若顺序颠倒，命中集合会与「先卡牌后区间」的序列不同。
	var config: Dictionary = {
		"lingshi_min": 1, "lingshi_max": 100,
		"cards": [{"card_id": "a", "chance": 0.5}],
	}
	var first: Dictionary = Roller.roll(config, _rng(2024))
	var rng: RandomNumberGenerator = _rng(2024)
	var expected_lingshi: int = rng.randi_range(1, 100)
	var expected_hit: bool = rng.randf() < 0.5
	assert_eq(int(first["lingshi"]), expected_lingshi, "灵石取第一个随机数")
	assert_eq((first["cards"] as Array).size(), 1 if expected_hit else 0,
			"卡牌取第二个随机数（顺序口径）")


## 探针：手动按同一口径跑一遍，暴露「下一次 randf」值以判断随机数是否被消耗。
class RenderProbe:
	static func run(p_config: Dictionary) -> Dictionary:
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		Roller.roll(p_config, rng)
		return {"next_randf": rng.randf()}

	static func baseline_randf() -> float:
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		return rng.randf()
