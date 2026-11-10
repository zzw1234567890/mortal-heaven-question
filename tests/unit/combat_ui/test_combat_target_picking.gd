extends GutTest
## 目标点选累加规则（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]本文件锁定的验收点[/b]：[b]单目标卡拒绝多选[/b]——点第二个目标必须
## 替换而不是累加；多选卡再点同一目标则取消。纯函数，零依赖。

const Picking := preload("res://src/ui/combat/shared/combat_target_picking.gd")
const Policy := preload("res://src/ui/combat/shared/combat_target_policy.gd")


## 单体：第二个目标替换第一个（绝不累加）。
func test_single_mode_replaces_previous_target() -> void:
	# Act
	var first: Array = Picking.apply([], 101, Policy.MODE_SINGLE)
	var second: Array = Picking.apply(first, 102, Policy.MODE_SINGLE)
	# Assert
	assert_eq(first, [101], "第一个目标被采纳")
	assert_eq(second, [102], "第二个目标替换（不是 [101, 102]）")


## 单体：再点同一个目标仍是它（幂等，不重复）。
func test_single_mode_same_target_is_idempotent() -> void:
	var out: Array = Picking.apply([101], 101, Policy.MODE_SINGLE)
	assert_eq(out, [101], "重复点同一目标不产生重复项")


## 多选：新目标追加，再点取消。
func test_multi_mode_toggles_targets() -> void:
	var a: Array = Picking.apply([], 101, Policy.MODE_MULTI)
	var b: Array = Picking.apply(a, 102, Policy.MODE_MULTI)
	var c: Array = Picking.apply(b, 101, Policy.MODE_MULTI)
	assert_eq(a, [101], "首个目标")
	assert_eq(b, [101, 102], "追加第二个")
	assert_eq(c, [102], "再点第一个 → 取消")


## 自身 / 全体：玩家的点选被忽略（目标由系统决定）。
func test_system_modes_ignore_player_picks() -> void:
	assert_eq(Picking.apply([], 101, Policy.MODE_SELF), [], "自身不接收目标")
	assert_eq(Picking.apply([], 101, Policy.MODE_AUTO_ALL), [], "全体不接收点选")


## 无效 ID（负数）不进入列表。
func test_negative_target_ignored() -> void:
	assert_eq(Picking.apply([101], -1, Policy.MODE_MULTI), [101], "负值忽略")


## 入参数组不被改写（纯函数）。
func test_does_not_mutate_input() -> void:
	var original: Array = [101]
	Picking.apply(original, 102, Policy.MODE_MULTI)
	assert_eq(original, [101], "调用方数组保持原样")


## 模式判定：单体不允许持多、只有单体点完即确认。
func test_mode_predicates() -> void:
	assert_false(Picking.allows_multiple(Policy.MODE_SINGLE), "单体不允许多目标")
	assert_true(Picking.allows_multiple(Policy.MODE_MULTI), "多选允许")
	assert_true(Picking.confirms_immediately(Policy.MODE_SINGLE), "单体点完即确认")
	assert_false(Picking.confirms_immediately(Policy.MODE_MULTI), "多选要玩家点卡确认")


## 完成判定：自身/全体恒完成；单体/多选需至少一个目标。
func test_completion_rules() -> void:
	assert_true(Picking.is_complete([], Policy.MODE_SELF), "自身无需目标")
	assert_true(Picking.is_complete([], Policy.MODE_AUTO_ALL), "全体由系统填")
	assert_false(Picking.is_complete([], Policy.MODE_SINGLE), "单体缺目标")
	assert_true(Picking.is_complete([101], Policy.MODE_SINGLE), "单体有目标")
