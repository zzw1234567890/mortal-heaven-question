extends GutTest
## 出牌目标解析纯函数（combat-ui-interaction 001）。[br]
## [br][b]背景[/b]：`play_card()` 此前只认 `caster_id`，没有任何「打谁」的默认策略——
## 玩家不点目标时目标列表是空的，出牌效果无处落地。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 未指定目标 → 默认取候选池[b]首个存活敌人[/b]；[br]
##   2. 显式指定 → 以其为准，只保留候选池里存活的那些；[br]
##   3. 显式目标[b]全部无效[/b] → 拒绝（不悄悄改成另一个人）；[br]
##   4. 候选池[b]读不到[/b] → 显式目标原样透传（不越权否决）。[br]
## [br]纯函数——零依赖，不触碰 Autoload。

const TargetRules := preload("res://src/ui/combat/shared/combat_target_rules.gd")


## 候选条目工厂。
func _enemy(character_id: int, is_alive: bool = true) -> Dictionary:
	return {"character_id": character_id, "is_alive": is_alive,
		"current_hp": 20 if is_alive else 0, "max_hp": 20}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 默认策略：首个存活敌人
# ═══════════════════════════════════════════════════════════════════════════════

## 未指定目标 → 取候选池第一个（单敌场景就是那个敌人）。
func test_default_picks_first_candidate() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([], [_enemy(101)])
	# Assert
	assert_eq(out["targets"], [101], "默认打第一个敌人")
	assert_eq(int(out["source"]), TargetRules.SOURCE_DEFAULT, "来源标记为默认")


## 第一个已阵亡 → 跳过它取下一个存活者（默认策略的核心价值）。
func test_default_skips_dead_and_picks_next_alive() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([],
			[_enemy(101, false), _enemy(102), _enemy(103)])
	# Assert
	assert_eq(out["targets"], [102], "跳过阵亡的第一个，打下一个存活者")
	assert_eq(int(out["source"]), TargetRules.SOURCE_DEFAULT, "仍是默认来源")


## 候选池为空（名册读不到）→ 空目标 + UNRESOLVED，不报「非法」。[br]
## 空目标不等于「打所有人」，调用方按 source 区分。
func test_default_with_empty_pool_is_unresolved_not_invalid() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([], [])
	# Assert
	assert_eq(out["targets"], [], "无候选 → 空目标")
	assert_eq(int(out["source"]), TargetRules.SOURCE_UNRESOLVED, "标记未解析")
	assert_ne(int(out["source"]), TargetRules.SOURCE_NONE, "不等于「非法」")


## 候选池全阵亡 → 同样走 UNRESOLVED（无可选，但不否决）。
func test_default_with_all_dead_is_unresolved() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([], [_enemy(101, false)])
	# Assert
	assert_eq(out["targets"], [], "全阵亡 → 无可默认目标")
	assert_eq(int(out["source"]), TargetRules.SOURCE_UNRESOLVED, "未解析而非非法")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 显式覆盖
# ═══════════════════════════════════════════════════════════════════════════════

## 显式指定存活敌人 → 采纳该目标（不退回默认）。
func test_explicit_overrides_default() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([103], [_enemy(101), _enemy(103)])
	# Assert
	assert_eq(out["targets"], [103], "用玩家指定的目标，而非默认的第一个")
	assert_eq(int(out["source"]), TargetRules.SOURCE_EXPLICIT, "来源标记为显式")


## 显式指定多个存活敌人 → 全部保留且保序。
func test_explicit_keeps_multiple_targets_in_order() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([103, 101],
			[_enemy(101), _enemy(103)])
	# Assert
	assert_eq(out["targets"], [103, 101], "多个目标保序保留")


## 显式目标里混了阵亡者 → 只保留存活的那个（不是整批拒绝）。
func test_explicit_drops_dead_keeps_alive() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([101, 102],
			[_enemy(101, false), _enemy(102)])
	# Assert
	assert_eq(out["targets"], [102], "剔除阵亡目标，保留存活者")
	assert_eq(int(out["source"]), TargetRules.SOURCE_EXPLICIT, "仍是显式来源")


## 显式目标全部无效（阵亡 / 不存在）→ 拒绝，[b]不退回默认[/b]。[br]
## 这条是「不猜」的核心：玩家点了 A，系统不能因为 A 死了就打 B。
func test_explicit_all_invalid_rejects_instead_of_defaulting() -> void:
	# Act——101 阵亡、999 不在候选池
	var out: Dictionary = TargetRules.resolve([101, 999], [_enemy(101, false), _enemy(102)])
	# Assert
	assert_eq(out["targets"], [], "全无效 → 空目标")
	assert_eq(int(out["source"]), TargetRules.SOURCE_NONE, "标记为非法（调用方据此拒绝）")


## 重复目标去重——同一敌人被点两次不该结算两次。
func test_explicit_deduplicates_targets() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([102, 102], [_enemy(102)])
	# Assert
	assert_eq(out["targets"], [102], "重复目标去重")


## 负数 / 非法项跳过（宽松兼容 UI 传入的 Variant 数组）。
func test_explicit_skips_negative_entries() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([-1, 102], [_enemy(102)])
	# Assert
	assert_eq(out["targets"], [102], "负数哨兵跳过")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 候选池读不到：不越权否决
# ═══════════════════════════════════════════════════════════════════════════════

## 候选池为空（敌方名册未接线）时，显式目标原样透传。[br]
## [br][b]为什么不能拒绝[/b]：名册缺失是「UI 数据源没接好」，不是「玩家选错了」；
## 此时否决会让出牌在任何未接线场景下完全不可用。真正的合法性归系统侧
## `_validate_targets`。
func test_explicit_passes_through_when_pool_unavailable() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([100001], [])
	# Assert
	assert_eq(out["targets"], [100001], "读不到候选池 → 显式目标原样透传")
	assert_eq(int(out["source"]), TargetRules.SOURCE_EXPLICIT, "仍算显式来源")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. HP 派生存活（候选池只给得到 HP 时）
# ═══════════════════════════════════════════════════════════════════════════════

## 条目只带 HP（无 is_alive 键）→ 按 HP 派生存活判定。
func test_alive_derived_from_hp_when_no_flag() -> void:
	# Arrange——101 归零、102 尚存
	var pool: Array = [
		{"character_id": 101, "current_hp": 0, "max_hp": 20},
		{"character_id": 102, "current_hp": 5, "max_hp": 20},
	]
	# Act
	var out: Dictionary = TargetRules.resolve([], pool)
	# Assert
	assert_eq(out["targets"], [102], "无 is_alive 键时按 HP 判定存活")


## 未知 HP（current=0 且 max=0）→ [b]按存活处理[/b]，不把敌人从候选池里抹掉。
func test_unknown_hp_treated_as_alive() -> void:
	# Assert
	assert_true(TargetRules.is_alive_hp(0, 0), "读不到 HP ≠ 死了")
	assert_false(TargetRules.is_alive_hp(0, 20), "有上限却归零 → 阵亡")
	assert_true(TargetRules.is_alive_hp(5, 20), "有血 → 存活")


## is_alive 键优先于 HP——两条数据都在时以显式标志为准（与战斗状态表同源）。
func test_explicit_alive_flag_wins_over_hp() -> void:
	# Arrange——HP 归零但显式标注存活（落库侧尚未同步的瞬态）
	var pool: Array = [{"character_id": 101, "is_alive": true,
		"current_hp": 0, "max_hp": 20}]
	# Act
	var out: Dictionary = TargetRules.resolve([], pool)
	# Assert
	assert_eq(out["targets"], [101], "显式存活标志优先于 HP")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 脏输入不崩
# ═══════════════════════════════════════════════════════════════════════════════

## 非字典条目 / 缺 ID 的条目跳过——不崩、不误取。
func test_tolerates_malformed_candidates() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([], [42, null, {"character_id": -1},
		{"character_id": 105}])
	# Assert
	assert_eq(out["targets"], [105], "跳过非法条目，取合法者")


## 结果字典形状稳定（三个键恒在——调用方按固定契约读）。
func test_result_shape_is_stable() -> void:
	# Act
	var out: Dictionary = TargetRules.resolve([], [_enemy(101)])
	# Assert
	assert_true(out.has("targets") and out.has("source") and out.has("reason"),
			"结果恒带 targets / source / reason 三键")
