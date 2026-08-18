extends GutTest
## Story 004 验收测试：clear_standby_state + mark_unavailable + revive_character + is_game_over。
##
## 覆盖 AC-001 到 AC-014（14 条 AC）。
## 测试策略：
##   - DS_SCRIPT.new() 构造 DeploymentSystem 实例（不调 _ready）
##   - 真实 RealmSystem/GSM Autoload——before_each 设置 player.realm 控制 max_deploy
##   - 信号时序：standby_cleared/character_unavailable/character_revived 均为 Cat 2b 即时发射
##   - 动态分派：var ds: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）
##
## 设计文档来源：ADR-0016 §待命状态清除 §不可用角色生命周期 §验证标准
## Story 来源：production/epics/deployment-system/story-004-clear-standby-revive.md

const DS_SCRIPT := preload("res://src/feature/deployment_system.gd")

var ds: Node = null
var _signal_callables: Array = []


func before_each() -> void:
	ds = DS_SCRIPT.new()
	_signal_callables.clear()


func after_each() -> void:
	_reset_realm()
	if ds != null:
		for callable: Callable in _signal_callables:
			for sig in [&"standby_cleared", &"character_unavailable", &"character_revived"]:
				if ds.is_connected(sig, callable):
					ds.disconnect(sig, callable)
		_signal_callables.clear()
		ds.free()
		ds = null


func _set_realm(level: int) -> void:
	GameStateManager.player.realm = level


func _reset_realm() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING


func _track_signal(signal_name: StringName, callable: Callable) -> void:
	ds.connect(signal_name, callable)
	_signal_callables.append(callable)


# ============================================================================
# AC-001：clear_standby_state STANDBY→READY
# ============================================================================

func test_ac001_clear_standby_standby_to_ready() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102], {})  # 全部 STANDBY
	ds._field[1]["state"] = DS_SCRIPT.FieldState.READY  # 102 手动 READY
	ds.clear_standby_state()
	assert_eq(ds._field[0]["state"], DS_SCRIPT.FieldState.READY, "101 STANDBY → READY")
	assert_eq(ds._field[1]["state"], DS_SCRIPT.FieldState.READY, "102 保持 READY")


# ============================================================================
# AC-002：clear_standby_state ACTED→READY
# ============================================================================

func test_ac002_clear_standby_acted_to_ready() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101], {})
	ds._field[0]["state"] = DS_SCRIPT.FieldState.ACTED  # 手动 ACTED
	ds.clear_standby_state()
	assert_eq(ds._field[0]["state"], DS_SCRIPT.FieldState.READY, "ACTED → READY（回合循环）")


# ============================================================================
# AC-003：clear_standby_state READY/DEAD/空位不变
# ============================================================================

func test_ac003_clear_standby_ready_dead_empty_unchanged() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102], {})  # slot 0/1
	ds._field[0]["state"] = DS_SCRIPT.FieldState.READY
	ds._field[1]["state"] = DS_SCRIPT.FieldState.DEAD
	ds.clear_standby_state()
	assert_eq(ds._field[0]["state"], DS_SCRIPT.FieldState.READY, "READY 不变")
	assert_eq(ds._field[1]["state"], DS_SCRIPT.FieldState.DEAD, "DEAD 不变")
	assert_eq(ds._field[2]["character_id"], -1, "空位跳过（slot 2 保持 EMPTY）")


# ============================================================================
# AC-004：standby_cleared 信号仅含待命角色（不含 ACTED→READY）
# ============================================================================

func test_ac004_standby_cleared_only_standby() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103], {})  # 全部 STANDBY
	ds._field[1]["state"] = DS_SCRIPT.FieldState.ACTED  # 102 ACTED
	var captured: Array = [null]
	var handler := func(ids: Array) -> void:
		captured[0] = ids
	_track_signal(&"standby_cleared", handler)

	ds.clear_standby_state()
	assert_not_null(captured[0], "standby_cleared 应发射")
	assert_eq(captured[0].size(), 2, "仅含待命角色（101/103），不含 ACTED 102")
	assert_true(captured[0].has(101), "含 101")
	assert_true(captured[0].has(103), "含 103")
	assert_false(captured[0].has(102), "不含 102（ACTED→READY 非待命清除）")


# ============================================================================
# AC-005：无 STANDBY 不发射 standby_cleared
# ============================================================================

func test_ac005_no_standby_no_signal() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102], {})
	ds._field[0]["state"] = DS_SCRIPT.FieldState.READY
	ds._field[1]["state"] = DS_SCRIPT.FieldState.ACTED
	var emitted: Array = [0]
	_track_signal(&"standby_cleared", func(_ids: Array) -> void: emitted[0] += 1)

	ds.clear_standby_state()
	assert_eq(emitted[0], 0, "无 STANDBY 不发射 standby_cleared")


func test_ac005_clear_standby_empty_field_no_crash() -> void:
	# 全空场调用不崩溃、不发射（GAP-4 补齐）
	var emitted: Array = [0]
	_track_signal(&"standby_cleared", func(_ids: Array) -> void: emitted[0] += 1)
	ds.clear_standby_state()  # 6 个空位全 EMPTY
	assert_eq(emitted[0], 0, "全空场不发射 standby_cleared")
	assert_eq(ds.get_field().size(), 6, "阵位结构不变")


func test_mark_unavailable_repeated_overwrites_context() -> void:
	# 重复标记同一角色：覆盖旧 context（GAP-3 语义锁定）
	ds.mark_unavailable(101, {"death_turn": 1, "death_battle_id": "b1"})
	ds.mark_unavailable(101, {"death_turn": 9, "death_battle_id": "b2"})
	var entry: Dictionary = ds._unavailable_characters[101]
	assert_eq(entry["death_turn"], 9, "覆盖为最新 death_turn")
	assert_eq(entry["death_battle_id"], "b2", "覆盖为最新 death_battle_id")


# ============================================================================
# AC-006：mark_unavailable 标记 + character_unavailable 信号
# ============================================================================

func test_ac006_mark_unavailable_sets_and_signals() -> void:
	var captured: Array = [null]
	var handler := func(cid: int) -> void:
		captured[0] = cid
	_track_signal(&"character_unavailable", handler)

	ds.mark_unavailable(101, {"death_turn": 3, "death_battle_id": "battle_001"})
	assert_true(ds._unavailable_characters.has(101), "_unavailable_characters 含 101")
	assert_not_null(captured[0], "character_unavailable 应发射")
	assert_eq(captured[0], 101, "载荷 character_id=101")


# ============================================================================
# AC-007：death_context 存储
# ============================================================================

func test_ac007_death_context_stored() -> void:
	ds.mark_unavailable(101, {"death_turn": 3, "death_battle_id": "battle_001"})
	var entry: Dictionary = ds._unavailable_characters[101]
	assert_eq(entry["death_turn"], 3, "death_turn==3")
	assert_eq(entry["death_battle_id"], "battle_001", "death_battle_id 正确")
	assert_eq(entry["revival_methods"], [], "revival_methods 默认空数组")


func test_ac007_death_context_missing_fields_default() -> void:
	ds.mark_unavailable(101, {})  # 空 death_context
	var entry: Dictionary = ds._unavailable_characters[101]
	assert_eq(entry["death_turn"], 0, "缺 death_turn → 0")
	assert_eq(entry["death_battle_id"], "", "缺 death_battle_id → 空串")


func test_ac007_death_context_revival_methods_stored() -> void:
	# revival_methods 非空值透传（GAP-2 补齐）
	ds.mark_unavailable(101, {"death_turn": 1, "death_battle_id": "b1", "revival_methods": ["item_5"]})
	var entry: Dictionary = ds._unavailable_characters[101]
	assert_eq(entry["revival_methods"], ["item_5"], "revival_methods 非空值透传")


# ============================================================================
# AC-008：get_unavailable_characters 列表
# ============================================================================

func test_ac008_get_unavailable_characters() -> void:
	ds.mark_unavailable(101, {"death_turn": 1, "death_battle_id": "b1"})
	ds.mark_unavailable(102, {"death_turn": 2, "death_battle_id": "b2"})
	var ids: Array = ds.get_unavailable_characters()
	assert_eq(ids.size(), 2, "返回 2 个不可用角色")
	assert_true(ids.has(101), "含 101")
	assert_true(ids.has(102), "含 102")


func test_ac008_get_unavailable_empty() -> void:
	assert_eq(ds.get_unavailable_characters().size(), 0, "无可标记角色时返回空列表")


# ============================================================================
# AC-009：revive_character 复活 + character_revived 信号
# ============================================================================

func test_ac009_revive_removes_and_signals() -> void:
	ds.mark_unavailable(101, {"death_turn": 3, "death_battle_id": "b1"})
	var captured: Array = [null]
	var handler := func(cid: int) -> void:
		captured[0] = cid
	_track_signal(&"character_revived", handler)

	var ok: bool = ds.revive_character(101)
	assert_true(ok, "复活成功返回 true")
	assert_false(ds._unavailable_characters.has(101), "_unavailable_characters 不含 101")
	assert_not_null(captured[0], "character_revived 应发射")
	assert_eq(captured[0], 101, "载荷 character_id=101")


func test_ac009_revive_restores_deployability() -> void:
	# 复活闭环：从不可用列表移除后，重新上场不再被拒绝（GAP-1 补齐）
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.mark_unavailable(101, {"death_turn": 3, "death_battle_id": "b1"})
	assert_false(ds.setup_field([101], {}), "复活前 setup_field 拒绝")
	var ok: bool = ds.revive_character(101)
	assert_true(ok, "复活成功")
	assert_true(ds.setup_field([101], {}), "复活后 setup_field 允许重新上场")


# ============================================================================
# AC-010：revive 非不可用角色 → false + 不发射
# ============================================================================

func test_ac010_revive_non_unavailable_rejected() -> void:
	var emitted: Array = [0]
	_track_signal(&"character_revived", func(_cid: int) -> void: emitted[0] += 1)

	var ok: bool = ds.revive_character(999)
	assert_false(ok, "非不可用角色返回 false")
	assert_eq(emitted[0], 0, "不发射 character_revived")


# ============================================================================
# AC-011：is_game_over 全灭判定
# ============================================================================

func test_ac011_is_game_over_all_unavailable() -> void:
	ds.mark_unavailable(101, {"death_turn": 1, "death_battle_id": "b1"})
	ds.mark_unavailable(102, {"death_turn": 2, "death_battle_id": "b1"})
	assert_true(ds.is_game_over([101, 102]), "全部角色位不可用 → true")


# ============================================================================
# AC-012：is_game_over 有可用角色
# ============================================================================

func test_ac012_is_game_over_has_available() -> void:
	ds.mark_unavailable(101, {"death_turn": 1, "death_battle_id": "b1"})
	assert_false(ds.is_game_over([101, 102]), "102 可用 → false")


func test_ac012_is_game_over_empty_roster() -> void:
	ds.mark_unavailable(101, {"death_turn": 1, "death_battle_id": "b1"})
	assert_false(ds.is_game_over([]), "空 roster → false（不误判失败）")


# ============================================================================
# AC-013：不可用角色拒绝上场（setup_field / deploy）
# ============================================================================

func test_ac013_setup_field_rejects_unavailable() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.mark_unavailable(101, {"death_turn": 1, "death_battle_id": "b1"})
	var ok: bool = ds.setup_field([101], {})
	assert_false(ok, "setup_field 拒绝不可用角色")


func test_ac013_deploy_rejects_unavailable() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101], {})
	ds.mark_unavailable(102, {"death_turn": 1, "death_battle_id": "b1"})
	var result: Dictionary = ds.deploy(200, 102, -1)
	assert_false(result["success"], "deploy 拒绝不可用角色")
	assert_eq(result["reason"], "character_unavailable", "reason=character_unavailable")


# ============================================================================
# AC-014：待命清除调用点契约（本 story 仅验证契约，实际调用属战斗 Epic）
# ============================================================================

func test_ac014_standby_clear_contract() -> void:
	# 契约验证：clear_standby_state 为公开方法，且待命清除发生在攻击声明前
	# （Phase 6 END → 新回合 Phase 3）——本 story 仅验证方法可调用 + 状态正确转换，
	# 实际 Phase 6 调用点属 CombatSystem（ADR-0008）。
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101], {})  # 第 1 回合 STANDBY
	assert_true(ds.is_standby(101), "上场角色初始待命（第 1 回合不可攻击）")
	ds.clear_standby_state()  # Phase 6 调用后
	assert_false(ds.is_standby(101), "待命清除后下回合可攻击")
