extends GutTest
## Sprint 18 单元测试：战斗结束判定内核（combat_end_check.gd）。
##
## 覆盖 GDD combat-system.md §9 的四种判定组合，以及「信息不足则不判」原则
## （ADR-0016 §is_game_over 必传 roster 的同源裁决）：[br]
##   - 敌方全灭 → VICTORY；敌方有活口 → 不判胜利[br]
##   - 己方阵位全空且本场曾有人 → DEFEAT[br]
##   - 阵位从未布置 / 名册为空 / 敌方阵容为空 → NONE（宁可打不完，不误判）[br]
##   - Dictionary 与 Object 两种条目形态的兼容读取
##
## Story 类型 Logic——本文件为阻塞证据。

const EndCheck := preload("res://src/feature/combat/combat_end_check.gd")


## 构造阵位条目（DeploymentSystem.get_field 的形状）。
func _slot(character_id: int) -> Dictionary:
	return {
		"slot_index": 0,
		"character_id": character_id,
		"is_front": true,
		"state": 2 if character_id != -1 else 0,
		"deploy_turn": 0,
	}


## 空阵位（6 格全空——DeploymentSystem 未布置时的形状）。
func _empty_field() -> Array:
	var field: Array = []
	for i: int in range(6):
		var entry: Dictionary = _slot(-1)
		entry["slot_index"] = i
		field.append(entry)
	return field


## 构造敌方条目（EnemyBattleState 的等效 Dictionary 桩）。
func _enemy(alive: bool) -> Dictionary:
	return {"is_alive": alive, "current_hp": 10 if alive else 0}


# ═══════════════════════════════════════════════════════════════════════════════
# 胜利判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_enemies_dead_returns_victory() -> void:
	# Arrange
	var enemy: Array = [_enemy(false), _enemy(false)]
	# Act
	var result: int = EndCheck.evaluate(enemy, _empty_field(), [101], false)
	# Assert
	assert_eq(result, EndCheck.RESULT_VICTORY, "敌方全灭应判胜利（即便我方阵位为空）")


func test_one_enemy_alive_does_not_return_victory() -> void:
	# Arrange
	var enemy: Array = [_enemy(false), _enemy(true)]
	# Act
	var result: int = EndCheck.evaluate(enemy, [_slot(101)], [101], true)
	# Assert
	assert_eq(result, EndCheck.RESULT_NONE, "尚有敌人存活不应判胜利")


func test_current_hp_zero_without_is_alive_key_counts_as_dead() -> void:
	# Arrange——旧存档/桩条目只有 HP，没有 is_alive 键
	var enemy: Array = [{"current_hp": 0}]
	# Act
	var result: int = EndCheck.evaluate(enemy, _empty_field(), [101], false)
	# Assert
	assert_eq(result, EndCheck.RESULT_VICTORY, "current_hp=0 应视作阵亡")


# ═══════════════════════════════════════════════════════════════════════════════
# 战败判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_field_empty_after_engaged_returns_defeat() -> void:
	# Arrange——本场曾有人，现在全空
	var enemy: Array = [_enemy(true)]
	# Act
	var result: int = EndCheck.evaluate(enemy, _empty_field(), [101], true)
	# Assert
	assert_eq(result, EndCheck.RESULT_DEFEAT, "阵位全空且本场曾有人应判战败")


func test_field_occupied_returns_none() -> void:
	# Arrange
	var field: Array = _empty_field()
	field[0] = _slot(101)
	# Act
	var result: int = EndCheck.evaluate([_enemy(true)], field, [101], true)
	# Assert
	assert_eq(result, EndCheck.RESULT_NONE, "我方仍有存活角色不应判战败")


# ═══════════════════════════════════════════════════════════════════════════════
# 信息不足则不判
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_enemy_roster_never_victory() -> void:
	# Arrange——敌方阵容为空 = 无信息（不是「全灭」）
	# Act
	var result: int = EndCheck.evaluate([], _empty_field(), [101], true)
	# Assert
	assert_eq(result, EndCheck.RESULT_DEFEAT, "空敌方阵容不应判胜利（阵位全空则按战败）")
	assert_ne(result, EndCheck.RESULT_VICTORY, "空敌方阵容绝不能判胜利")


func test_field_never_engaged_returns_none_even_if_empty() -> void:
	# Arrange——阵位从未被布置
	# Act
	var result: int = EndCheck.evaluate([_enemy(true)], _empty_field(), [101], false)
	# Assert
	assert_eq(result, EndCheck.RESULT_NONE, "从未布置阵位不应被读成己方全灭")


func test_empty_player_roster_returns_none() -> void:
	# Act
	var result: int = EndCheck.evaluate([_enemy(true)], _empty_field(), [], true)
	# Assert
	assert_eq(result, EndCheck.RESULT_NONE, "我方名册为空（无信息）不应判战败")


# ═══════════════════════════════════════════════════════════════════════════════
# 条目形态兼容
# ═══════════════════════════════════════════════════════════════════════════════

func test_object_entry_with_is_alive_property() -> void:
	# Arrange——对象形态（EnemyBattleState 真身）
	var alive := EnemyBattleState.new()
	alive.is_alive = false
	# Act + Assert
	assert_false(EndCheck.is_alive(alive), "对象 is_alive=false 应判为阵亡")
	alive.is_alive = true
	assert_true(EndCheck.is_alive(alive), "对象 is_alive=true 应判为存活")


func test_unknown_entry_treated_as_alive() -> void:
	# Arrange——读不到任何存活信息
	# Act + Assert
	assert_true(EndCheck.is_alive({"foo": 1}), "读不到存活信息时按存活处理（不误判胜利）")
	assert_false(EndCheck.is_alive(null), "null 条目按阵亡处理")


func test_is_occupied_uses_character_id_sentinel() -> void:
	# Act + Assert
	assert_true(EndCheck.is_occupied(_slot(101)), "character_id=101 应判有人")
	assert_false(EndCheck.is_occupied(_slot(-1)), "character_id=-1 应判空位")
	assert_false(EndCheck.is_occupied({"state": 2}), "缺 character_id 视为空位（安全默认）")
