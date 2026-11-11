extends GutTest
## Debuff 管理器单元测试——降攻/降防 debuff。[br]
## [br]测试覆盖：[br]
## - 基础施加与读取[br]
## - 层数叠加与上限封顶[br]
## - 回合结束递减与移除[br]
## - 攻击力/防御力修正[br]
## - 快照与状态查询

const DebuffManagerScript := preload("res://src/feature/combat/combat_debuff_manager.gd")


func test_apply_single_debuff() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	assert_true(debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 1, 100))
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_ATK), 1)
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_ATK), 2)


func test_apply_multiple_stacks() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	# 叠加 3 层
	for i: int in range(3):
		assert_true(debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 1, 100))
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_ATK), 3)
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_ATK), 2)


func test_stack_limit_enforced() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	# 尝试叠加 6 层（上限 5）
	var success_count: int = 0
	for i: int in range(6):
		if debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 1, 100):
			success_count += 1
	assert_eq(success_count, 5)  # 前 5 次成功
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_ATK), 5)


func test_turn_end_decrements_duration() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 1, 100)
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_ATK), 2)
	# 回合结束
	debuff.call(&"on_turn_end")
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_ATK), 1)
	debuff.call(&"on_turn_end")
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_ATK), 0)
	debuff.call(&"on_turn_end")
	# 归零后移除
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_ATK), 0)
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_ATK), -1)


func test_multiple_debuff_types_independent() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 1, 100)  # 降攻
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_DEF, 3, 1, 50)   # 降防
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_ATK), 1)
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_DEF), 1)
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_ATK), 2)
	assert_eq(debuff.call(&"get_duration", 1, DebuffManagerScript.TYPE_DEF), 3)


func test_atk_with_debuff() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 2, 100)  # 降攻 2 (duration=2, amount=2)
	assert_eq(debuff.call(&"get_atk_with_debuff", 1, 10), 8)
	assert_eq(debuff.call(&"get_atk_with_debuff", 1, 5), 3)
	assert_eq(debuff.call(&"get_atk_with_debuff", 1, 1), 0)  # 不能低于 0


func test_def_with_debuff() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_DEF, 2, 3, 100)  # 降防 3 (duration=2, amount=3)
	assert_eq(debuff.call(&"get_def_with_debuff", 1, 10), 7)
	assert_eq(debuff.call(&"get_def_with_debuff", 1, 5), 2)
	assert_eq(debuff.call(&"get_def_with_debuff", 1, 1), 0)  # 不能低于 0


func test_multiple_targets_independent() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 2, 100)  # 目标1降攻2
	debuff.call(&"apply", 2, DebuffManagerScript.TYPE_ATK, 1, 3, 100)  # 目标2降攻3
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_ATK), 1)
	assert_eq(debuff.call(&"get_stacks", 2, DebuffManagerScript.TYPE_ATK), 1)
	assert_eq(debuff.call(&"get_atk_with_debuff", 1, 10), 8)
	assert_eq(debuff.call(&"get_atk_with_debuff", 2, 10), 7)


func test_snapshot_captures_state() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 1, 2)
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_DEF, 3, 1, 3)
	var snap: Dictionary = debuff.call(&"snapshot")
	assert_true(snap.has(1))
	var char_states: Dictionary = snap[1]
	assert_true(char_states.has("atk_down"))
	assert_true(char_states.has("def_down"))


func test_clear_resets_all() -> void:
	var debuff: RefCounted = DebuffManagerScript.new()
	debuff.call(&"apply", 1, DebuffManagerScript.TYPE_ATK, 2, 1, 2)
	debuff.call(&"apply", 2, DebuffManagerScript.TYPE_DEF, 3, 1, 3)
	debuff.call(&"clear")
	assert_eq(debuff.call(&"get_stacks", 1, DebuffManagerScript.TYPE_ATK), 0)
	assert_eq(debuff.call(&"get_stacks", 2, DebuffManagerScript.TYPE_DEF), 0)
