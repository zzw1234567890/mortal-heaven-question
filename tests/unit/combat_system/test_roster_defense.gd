extends GutTest
## CombatRosterState 防御字段建模 + 固定值减免规则（combat-ui-interaction 002 后续）。
##
## 锁定三件事：[br]
##   1. [code]defense[/code] 默认 0——没有数据时绝不臆造防御值；[br]
##   2. 注入的 [code]defense[/code] / [code]def[/code] 被如实种入并能经
##      [code]read_hp[/code] 读回（敌方条目同理）；[br]
##   3. [code]CombatDefenseRules.apply_flat[/code] 按 [code]max(0, 伤害 − DEF)[/code]
##      结算，负防御按 0、允许完全免伤。

const RosterState := preload("res://src/feature/combat/combat_roster_state.gd")
const DefenseRules := preload("res://src/feature/combat/combat_defense_rules.gd")

const CHAR_A: int = 8601
const CHAR_B: int = 8602


func _field(character_id: int) -> Array:
	return [{"character_id": character_id, "is_front": true}]


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 默认值 / 注入值
# ═══════════════════════════════════════════════════════════════════════════════

func test_player_defense_defaults_to_zero() -> void:
	# Arrange / Act——只给 HP，不给防御
	var roster: RefCounted = RosterState.new()
	roster.seed_player_field(_field(CHAR_A),
			{CHAR_A: {"current_hp": 10, "max_hp": 10}})
	# Assert——默认 0，不臆造
	assert_eq(int(roster.read_hp(CHAR_A)["defense"]), 0, "未注入防御时默认 0")
	assert_eq(int(roster.get_state(CHAR_A)["defense"]), 0, "状态表同样存 0")


func test_player_defense_injected_value_is_read_back() -> void:
	# Arrange / Act
	var roster: RefCounted = RosterState.new()
	roster.seed_player_field(_field(CHAR_A),
			{CHAR_A: {"current_hp": 10, "max_hp": 10, "defense": 4}})
	# Assert
	assert_eq(int(roster.read_hp(CHAR_A)["defense"]), 4, "注入的 defense 应可读回")
	assert_eq(int(roster.get_hp(CHAR_A)["current"]), 10, "HP 读取契约不受影响")


func test_player_defense_accepts_def_alias() -> void:
	# Arrange / Act——短字段名 def 与 attack/atk 的既有别名口径一致
	var roster: RefCounted = RosterState.new()
	roster.seed_player_field(_field(CHAR_B),
			{CHAR_B: {"current_hp": 8, "max_hp": 8, "def": 3}})
	# Assert
	assert_eq(int(roster.read_hp(CHAR_B)["defense"]), 3, "def 别名应被接受")


func test_unknown_character_defense_is_zero() -> void:
	# Arrange / Act
	var roster: RefCounted = RosterState.new()
	# Assert——未知角色不得编出防御值
	assert_eq(int(roster.read_hp(999999)["defense"]), 0, "未知角色防御读 0")
	assert_false(bool(roster.read_hp(999999)["known"]), "未知角色 known=false")


func test_enemy_entry_defense_is_seeded() -> void:
	# Arrange / Act
	var roster: RefCounted = RosterState.new()
	roster.seed_enemy_roster([{
		"character_id": 777, "current_hp": 5, "max_hp": 5,
		"attack": 2, "defense": 2, "is_alive": true,
	}])
	# Assert
	assert_eq(int(roster.read_hp(777)["defense"]), 2, "敌方条目的防御也应入表")


func test_negative_defense_is_clamped_to_zero() -> void:
	# Arrange / Act——负防御不得变成反向增伤
	var roster: RefCounted = RosterState.new()
	roster.seed_player_field(_field(CHAR_A),
			{CHAR_A: {"current_hp": 10, "max_hp": 10, "defense": -5}})
	# Assert
	assert_eq(int(roster.read_hp(CHAR_A)["defense"]), 0, "负防御夹到 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 固定值减免纯函数
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_flat_subtracts_defense() -> void:
	assert_eq(DefenseRules.apply_flat(10, 4), 6, "10 − 4 = 6")


func test_apply_flat_allows_zero_damage() -> void:
	assert_eq(DefenseRules.apply_flat(4, 4), 0, "防御 ≥ 伤害时完全免伤")
	assert_eq(DefenseRules.apply_flat(3, 9), 0, "不得出现负伤害")


func test_apply_flat_negative_defense_does_not_amplify() -> void:
	assert_eq(DefenseRules.apply_flat(10, -3), 10, "负防御按 0 处理")


func test_apply_flat_zero_defense_keeps_raw_damage() -> void:
	assert_eq(DefenseRules.apply_flat(7, 0), 7, "0 防御时伤害 = 原始伤害")
