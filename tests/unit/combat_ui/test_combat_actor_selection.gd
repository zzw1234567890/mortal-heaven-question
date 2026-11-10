extends GutTest
## 「当前操作角色」显式状态（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]背景[/b]：施法者此前由阵位顺序临时裁定——多角色阵容里玩家点谁都没用，
## 出牌一律记在阵位首位。本文件锁定：自动筛出、显式切换、阵亡顺位、非法切换不生效。[br]
## [br]纯状态——零依赖，不触碰 Autoload / 节点。

const Selection := preload("res://src/ui/combat/shared/combat_actor_selection.gd")
const CasterRules := preload("res://src/ui/combat/shared/combat_caster_rules.gd")

## 阵位状态（镜像 DeploymentSystem.FieldState）。
const STANDBY: int = 1
const READY: int = 2
const DEAD: int = 4
const EMPTY: int = 0


func _slot(character_id: int, state: int, slot_index: int) -> Dictionary:
	return {"slot_index": slot_index, "character_id": character_id,
		"is_front": true, "state": state, "deploy_turn": 0}


func _empty(slot_index: int) -> Dictionary:
	return _slot(-1, EMPTY, slot_index)


var selection: RefCounted = null


func before_each() -> void:
	selection = Selection.new()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 自动筛出（刷新）
# ═══════════════════════════════════════════════════════════════════════════════

## 初始无当前角色；刷新后取阵位首个可行动角色。
func test_refresh_picks_first_eligible() -> void:
	# Arrange
	var field: Array = [_empty(0), _slot(102, READY, 1), _slot(103, READY, 2)]
	# Act
	var current: int = int(selection.call(&"refresh", field))
	# Assert
	assert_eq(current, 102, "跳过空位取首个可行动角色")
	assert_eq(selection.call(&"current_id"), 102, "状态已落定")


## 候选列表按 slot_index 升序，跳过阵亡与空位。
func test_candidates_are_ordered_and_filtered() -> void:
	var field: Array = [
		_slot(103, READY, 2), _slot(101, STANDBY, 0), _slot(102, DEAD, 1),
	]
	var candidates: Array = Selection.eligible_ids(field)
	assert_eq(candidates, [101, 103], "按阵位升序、跳过阵亡")


## 刷新不覆盖玩家的显式选择（当前角色仍合法时保留）。
func test_refresh_keeps_explicit_choice() -> void:
	# Arrange——玩家切到 103
	var field: Array = [_slot(101, READY, 0), _slot(103, READY, 1)]
	selection.call(&"refresh", field)
	assert_true(bool(selection.call(&"select", 103, field)), "前置：切换成功")
	# Act——再次刷新（同一阵位）
	var current: int = int(selection.call(&"refresh", field))
	# Assert
	assert_eq(current, 103, "刷新不把玩家选的改回阵位首位")


## 当前角色阵亡 → 刷新后顺位到下一个可行动角色。
func test_refresh_falls_through_when_current_died() -> void:
	# Arrange
	var field: Array = [_slot(101, READY, 0), _slot(102, READY, 1)]
	selection.call(&"refresh", field)
	# Act——101 阵亡
	field = [_slot(101, DEAD, 0), _slot(102, READY, 1)]
	var current: int = int(selection.call(&"refresh", field))
	# Assert
	assert_eq(current, 102, "阵亡自动顺位")


## 全阵亡 / 空阵位 → 无当前角色（-1 哨兵）。
func test_refresh_without_eligible_returns_sentinel() -> void:
	assert_eq(int(selection.call(&"refresh", [])), Selection.NO_ACTOR, "空阵位")
	assert_eq(int(selection.call(&"refresh", [_slot(101, DEAD, 0)])),
			Selection.NO_ACTOR, "全阵亡")
	assert_eq(int(selection.call(&"refresh", null)), Selection.NO_ACTOR, "快照不可用")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 显式切换
# ═══════════════════════════════════════════════════════════════════════════════

## 切到候选里的角色 → 成功且当前角色改变。
func test_select_switches_to_eligible_actor() -> void:
	var field: Array = [_slot(101, READY, 0), _slot(102, READY, 1)]
	selection.call(&"refresh", field)
	assert_true(bool(selection.call(&"select", 102, field)), "切换成功")
	assert_eq(selection.call(&"current_id"), 102, "当前角色已改变")


## 切到阵亡 / 未上场的角色 → 不生效，当前角色保持不变。
func test_select_rejects_ineligible_actor() -> void:
	var field: Array = [_slot(101, READY, 0), _slot(102, DEAD, 1)]
	selection.call(&"refresh", field)
	assert_false(bool(selection.call(&"select", 102, field)), "阵亡角色不可切换")
	assert_false(bool(selection.call(&"select", 999, field)), "未上场角色不可切换")
	assert_eq(selection.call(&"current_id"), 101, "当前角色保持不变")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 与兜底裁定同序
# ═══════════════════════════════════════════════════════════════════════════════

## 自动顺位的首位与 CombatCasterRules 的兜底裁定一致（两处各排各的会选出不同的人）。
func test_first_candidate_matches_caster_rules() -> void:
	var field: Array = [
		_slot(103, READY, 2), _slot(101, READY, 0), _slot(102, READY, 1),
	]
	assert_eq(Selection.eligible_ids(field)[0], CasterRules.resolve_caster(field),
			"自动顺位与兜底裁定同序")


## 清空后回到无当前角色。
func test_clear_resets_state() -> void:
	selection.call(&"refresh", [_slot(101, READY, 0)])
	selection.call(&"clear")
	assert_eq(selection.call(&"current_id"), Selection.NO_ACTOR, "清空后无角色")
	assert_eq(selection.call(&"candidates"), [], "候选一并清空")
