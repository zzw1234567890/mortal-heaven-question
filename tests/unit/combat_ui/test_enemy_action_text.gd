extends GutTest
## 敌方战报行文 / 命名回退 / 批内去重键（纯函数单元测试）。

const TextScript := preload("res://src/ui/combat/feedback/enemy_action_text.gd")


## 桩名称闭包——ID → 固定名字（跳过真实名册/模板）。
func _names() -> Callable:
	return func(character_id: int) -> String:
		if character_id == 100000:
			return "妖狼"
		if character_id == 8301:
			return "青岚"
		return ""


func _payload(overrides: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {
		"enemy_id": 100000,
		"action": &"skill",
		"target_id": 8301,
		"damage": 4,
		"is_kill": false,
		"known": true,
		"hp_after": 6,
	}
	payload.merge(overrides, true)
	return payload


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 行文
# ═══════════════════════════════════════════════════════════════════════════════

func test_skill_line_names_actor_target_and_damage() -> void:
	assert_eq(TextScript.format_line(_payload(), _names()),
			"「妖狼」对「青岚」造成 4 点伤害", "战报含谁对谁做了什么、多少伤害")


func test_kill_line_marks_target_fallen() -> void:
	var line: String = TextScript.format_line(
			_payload({"is_kill": true, "hp_after": 0}), _names())
	assert_string_contains(line, "将其击倒", "击杀要显式写出（不重复目标名）")


func test_retreat_line_has_no_target_or_damage() -> void:
	var line: String = TextScript.format_line(
			_payload({"action": &"retreat", "target_id": -1, "damage": 0}), _names())
	assert_eq(line, "「妖狼」撤退了", "撤退是一句独立战报")


func test_none_action_line_reports_no_target() -> void:
	var line: String = TextScript.format_line(
			_payload({"action": &"none", "target_id": -1, "damage": 0}), _names())
	assert_eq(line, "「妖狼」没有可攻击的目标", "无目标行动也要有可读记录")


func test_unknown_target_state_does_not_show_damage() -> void:
	var line: String = TextScript.format_line(
			_payload({"known": false}), _names())
	assert_eq(line, "「妖狼」攻击「青岚」（目标状态未知）",
			"未知 HP 时不展示伤害数字（不臆造）")


func test_fallen_target_line_hides_target_name() -> void:
	var line: String = TextScript.format_line(_payload(), _names(), true)
	assert_eq(line, "「妖狼」的行动落空（目标已阵亡）",
			"阵亡角色不再作为受击方出场")


func test_name_resolver_falls_back_to_readable_id() -> void:
	var line: String = TextScript.format_line(_payload(), Callable())
	assert_string_contains(line, "敌人 #100000", "敌方名兜底按 ID 段")
	assert_string_contains(line, "角色 #8301", "我方名兜底按 ID 段")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 批内去重键
# ═══════════════════════════════════════════════════════════════════════════════

func test_duplicate_key_is_stable_for_identical_payload() -> void:
	assert_eq(TextScript.duplicate_key(_payload()),
			TextScript.duplicate_key(_payload().duplicate(true)),
			"字段完全相同的载荷键相同")


func test_duplicate_key_changes_with_any_field() -> void:
	var base_key: String = TextScript.duplicate_key(_payload())
	assert_ne(base_key, TextScript.duplicate_key(_payload({"enemy_id": 100001})),
			"行动者不同 → 不同键")
	assert_ne(base_key, TextScript.duplicate_key(_payload({"target_id": 8302})),
			"目标不同 → 不同键")
	assert_ne(base_key, TextScript.duplicate_key(_payload({"damage": 5})),
			"伤害不同 → 不同键")
	assert_ne(base_key, TextScript.duplicate_key(_payload({"hp_after": 5})),
			"结算后 HP 不同 → 不同键")
