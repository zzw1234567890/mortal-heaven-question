extends GutTest
## Debuff 集成测试——debuff 施加、回合递减、数值修正。[br]
## [br]测试覆盖：[br]
## - roster 直接施加 debuff[br]
## - 降攻 debuff 使 get_atk 返回修正后的攻击力[br]
## - 降防 debuff 使 get_defense 返回修正后的防御力[br]
## - 回合结束时 debuff 持续回合数递减[br]
## - 归零后移除，数值恢复[br]
## - 重复施加按层数叠加，5 层封顶[br]
## [br][b]接口约定[/b]：CombatRosterState.apply_debuff(target_id, type, duration,
## amount, source_id)，duration 在前、每层数值在后；角色必须先经 seed 种入阵位，
## 否则 get_atk/get_defense 读不到该 ID。

const DebuffManagerScript := preload("res://src/feature/combat/combat_debuff_manager.gd")
const RosterScript := preload("res://src/feature/combat/combat_roster_state.gd")

const TARGET_ID: int = 101
const SOURCE_ID: int = 100

var roster: RefCounted = null


func before_each() -> void:
	roster = RosterScript.new()


func after_each() -> void:
	if roster != null:
		roster.call(&"clear")
		roster = null


## 种入一个 101 号我方角色，[param extra] 覆盖数值（atk / defense 等）。
func _seed_target(extra: Dictionary = {}) -> void:
	var stats: Dictionary = {"current_hp": 10, "max_hp": 10}
	for key: Variant in extra.keys():
		stats[key] = extra[key]
	roster.call(&"seed", [{"character_id": TARGET_ID}], {TARGET_ID: stats}, [])


func test_atk_debuff_reduces_attack_value() -> void:
	# Arrange——种子一个 ATK=5 的角色
	_seed_target({"atk": 5})
	assert_eq(int(roster.call(&"get_atk", TARGET_ID)), 5, "前置：裸 ATK 为 5")
	# Act——施加降攻 debuff（每层降 2，持续 1 回合）
	assert_true(roster.call(&"apply_debuff", TARGET_ID, DebuffManagerScript.TYPE_ATK,
			1, 2, SOURCE_ID))
	# Assert——get_atk 应返回修正后的 3
	assert_eq(int(roster.call(&"get_atk", TARGET_ID)), 3, "降攻 debuff 应降低攻击力")


func test_def_debuff_reduces_defense_value() -> void:
	# Arrange——种子一个 DEF=4 的角色
	_seed_target({"defense": 4})
	assert_eq(int(roster.call(&"get_defense", TARGET_ID)), 4, "前置：裸 DEF 为 4")
	# Act——施加降防 debuff（每层降 2，持续 1 回合）
	assert_true(roster.call(&"apply_debuff", TARGET_ID, DebuffManagerScript.TYPE_DEF,
			1, 2, SOURCE_ID))
	# Assert——get_defense 应返回修正后的 2
	assert_eq(int(roster.call(&"get_defense", TARGET_ID)), 2, "降防 debuff 应降低防御力")


func test_turn_end_decrements_duration() -> void:
	# Arrange——施加 debuff（持续 3 回合）
	_seed_target({"atk": 5})
	assert_true(roster.call(&"apply_debuff", TARGET_ID, DebuffManagerScript.TYPE_ATK,
			3, 1, SOURCE_ID))
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_duration", TARGET_ID, DebuffManagerScript.TYPE_ATK), 3)
	# Act——回合结束递减
	roster.call(&"on_turn_end_debuff")
	# Assert——持续回合数 -1
	assert_eq(debuff_mgr.call(&"get_duration", TARGET_ID, DebuffManagerScript.TYPE_ATK), 2)
	roster.call(&"on_turn_end_debuff")
	assert_eq(debuff_mgr.call(&"get_duration", TARGET_ID, DebuffManagerScript.TYPE_ATK), 1)
	roster.call(&"on_turn_end_debuff")
	assert_eq(debuff_mgr.call(&"get_duration", TARGET_ID, DebuffManagerScript.TYPE_ATK), 0)
	# 归零后再过一次回合结束才真正移除条目
	roster.call(&"on_turn_end_debuff")
	assert_eq(debuff_mgr.call(&"get_stacks", TARGET_ID, DebuffManagerScript.TYPE_ATK), 0)
	assert_eq(int(roster.call(&"get_atk", TARGET_ID)), 5, "debuff 移除后 ATK 应恢复")


func test_stacking_with_limit() -> void:
	# Arrange——尝试叠加 6 层（上限 5）
	_seed_target({"atk": 10})
	var success_count: int = 0
	for _i: int in range(6):
		if roster.call(&"apply_debuff", TARGET_ID, DebuffManagerScript.TYPE_ATK,
				2, 1, SOURCE_ID):
			success_count += 1
	# Assert——前 5 次成功，第 6 次失败
	assert_eq(success_count, 5, "debuff 应封顶于 5 层")
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_stacks", TARGET_ID, DebuffManagerScript.TYPE_ATK), 5)
	# 5 层 × 每层降 1 → ATK 10 → 5
	assert_eq(int(roster.call(&"get_atk", TARGET_ID)), 5, "5 层降攻应累计生效")


func test_debuff_removed_at_zero_duration() -> void:
	# Arrange——duration 0（本回合结束后生效，所以立即递减并移除）
	_seed_target()
	assert_true(roster.call(&"apply_debuff", TARGET_ID, DebuffManagerScript.TYPE_ATK,
			0, 1, SOURCE_ID))
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	# Act——回合结束递减
	roster.call(&"on_turn_end_debuff")
	# Assert——duration 0 的 debuff 应立即移除
	assert_eq(debuff_mgr.call(&"get_stacks", TARGET_ID, DebuffManagerScript.TYPE_ATK), 0)
