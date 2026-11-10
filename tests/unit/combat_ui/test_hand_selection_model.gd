extends GutTest
## 手牌选中态模型（combat-ui-interaction 001）。[br]
## [br][b]背景[/b]：选中态此前只由 HandCard 的视觉暗示，没有任何代码持有
## 「选了哪张」——于是「非法时不可确认」无处可写、也无法测试。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 选中 / 取消 / 切换的转移规则（切卡清目标、重复选保留目标）；[br]
##   2. 不可出牌（费用不足 / 灵能态 / 目标非法）时 [b]can_confirm 为 false[/b]；[br]
##   3. 目标为空[b]不算非法[/b]——默认策略会打首个存活敌人；[br]
##   4. 卡离开手牌 → 自清（防「幽灵选中」）。[br]
## [br]纯状态——零依赖，不触碰 Autoload / 节点。

const Selection := preload("res://src/ui/combat/shared/hand_selection_model.gd")


var model: RefCounted = null


func before_each() -> void:
	model = Selection.new()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 状态转移
# ═══════════════════════════════════════════════════════════════════════════════

## 初始无选中——状态 CLEAR 且不可确认。
func test_initial_state_has_no_selection() -> void:
	# Assert
	assert_eq(model.get_state(), Selection.STATE_CLEAR, "初始无选中")
	assert_false(model.can_confirm(), "无选中不可确认")
	assert_eq(model.get_reason(), Selection.REASON_NO_CARD, "原因：没选卡")
	assert_eq(model.get_card_instance_id(), Selection.NO_CARD, "卡 ID 为哨兵")


## 选中充足费用的卡 → READY 且可确认。
func test_select_affordable_card_is_ready() -> void:
	# Act
	var confirmable: bool = bool(model.call(&"select_card", 7, true, false))
	# Assert
	assert_true(confirmable, "选中充足费用的卡即可确认")
	assert_eq(model.get_state(), Selection.STATE_READY, "状态 READY")
	assert_true(model.is_selected(7), "第 7 张为选中态")
	assert_false(model.is_selected(8), "其他卡未选中")


## 取消选中 → 回到 CLEAR（幂等，重复调用无副作用）。
func test_clear_returns_to_clear_state() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	model.call(&"confirm")
	# Assert
	assert_eq(model.get_state(), Selection.STATE_CLEAR, "出牌后回到无选中")
	assert_false(model.has_selection(), "无选中")
	model.call(&"clear")  # 幂等
	assert_eq(model.get_state(), Selection.STATE_CLEAR, "重复清空仍是无选中")


## 切换卡牌 → [b]清空已准备的目标[/b]（目标属于上一张卡）。
func test_switching_card_clears_targets() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	model.call(&"select_target", [101])
	# Act
	model.call(&"select_card", 8, true, false)
	# Assert
	assert_eq(model.get_target_indices(), [], "换卡后目标清空")
	assert_true(model.is_selected(8), "新卡处于选中态")


## 重复选中同一张卡 → [b]保留目标[/b]（玩家点第二下不该把选好的目标弄丢）。
func test_reselecting_same_card_keeps_targets() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	model.call(&"select_target", [101])
	# Act
	model.call(&"select_card", 7, true, false)
	# Assert
	assert_eq(model.get_target_indices(), [101], "重复选中同卡不清目标")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 非法时不可确认（本条是 epic 要求的核心）
# ═══════════════════════════════════════════════════════════════════════════════

## 费用不足 → 选中成功（可看详情）但[b]不可确认[/b]。
func test_unaffordable_card_cannot_confirm() -> void:
	# Act
	var confirmable: bool = bool(model.call(&"select_card", 7, false, false))
	# Assert
	assert_false(confirmable, "费用不足不可确认")
	assert_eq(model.get_state(), Selection.STATE_BLOCKED, "状态 BLOCKED")
	assert_eq(model.get_reason(), Selection.REASON_UNAFFORDABLE, "原因：费用不足")
	assert_true(model.has_selection(), "仍处于选中态（可查看，只是按不动）")


## 灵能预览态（阶段 2 外）→ 不可确认。
func test_psychic_card_cannot_confirm() -> void:
	# Act
	var confirmable: bool = bool(model.call(&"select_card", 7, true, true))
	# Assert
	assert_false(confirmable, "灵能态不可确认")
	assert_eq(model.get_reason(), Selection.REASON_PSYCHIC, "原因：灵能预览")


## 显式目标全部无效 → 不可确认（原因指向目标）。
func test_invalid_targets_block_confirm() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	# Act
	model.call(&"select_target", [101])
	model.call(&"mark_targets_invalid", true)
	# Assert
	assert_false(model.can_confirm(), "目标非法不可确认")
	assert_eq(model.get_state(), Selection.STATE_TARGET_INVALID, "状态 TARGET_INVALID")
	assert_eq(model.get_reason(), Selection.REASON_TARGET_INVALID, "原因：目标非法")


## 重新指定目标 → 清除上一次的「非法」标记（玩家改了目标就该能再试）。[br]
## 这条防的是「改对了目标却仍按不动确认」。
func test_reselecting_targets_clears_invalid_flag() -> void:
	# Arrange——先标成非法
	model.call(&"select_card", 7, true, false)
	model.call(&"select_target", [101])
	model.call(&"mark_targets_invalid", true)
	assert_false(model.can_confirm(), "前置：已被挡住")
	# Act——重新选一个目标
	model.call(&"select_target", [102])
	# Assert
	assert_true(model.can_confirm(), "重选目标后恢复可确认")


## 空目标时 [code]mark_targets_invalid[/code] [b]不生效[/b]——空走默认策略，不是非法。
func test_mark_invalid_ignored_without_explicit_targets() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	# Act
	model.call(&"mark_targets_invalid", true)
	# Assert
	assert_true(model.can_confirm(), "无显式目标 → 走默认策略，不判非法")
	assert_eq(model.get_state(), Selection.STATE_READY, "仍是可确认")


## 原因优先级：没选卡 > 灵能 > 费用 > 目标——UI 只显示第一条。
func test_reason_priority_order() -> void:
	# Arrange——同时费用不足且目标非法
	model.call(&"select_card", 7, false, false)
	model.call(&"select_target", [101])
	model.call(&"mark_targets_invalid", true)
	# Assert——费用原因优先于目标原因
	assert_eq(model.get_reason(), Selection.REASON_UNAFFORDABLE, "费用原因优先")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 可出牌性刷新（费用变化 / 阶段切换）
# ═══════════════════════════════════════════════════════════════════════════════

## 费用被别处花掉 → 刷新后不可确认，但[b]选中不被清[/b]（费用恢复后可直接确认）。
func test_refresh_playability_keeps_selection() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	assert_true(model.can_confirm(), "前置：可确认")
	# Act——费用被花掉
	model.call(&"refresh_playability", false, false)
	# Assert
	assert_false(model.can_confirm(), "费用变化后不可确认")
	assert_true(model.is_selected(7), "选中未被清空")
	# Act——费用恢复
	model.call(&"refresh_playability", true, false)
	assert_true(model.can_confirm(), "费用恢复后直接可确认（不必重选）")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 手牌同步：防幽灵选中
# ═══════════════════════════════════════════════════════════════════════════════

## 选中的卡被打出（离开手牌）→ 自清，[b]确认不可再点[/b]。[br]
## [br][b]为什么必须[/b]：模型若仍以为「选着第 7 张」，UI 上却什么都没有，
## 玩家点确认会打出一张不存在的手牌（或静默失败）。
func test_sync_hand_clears_selection_when_card_left_hand() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	# Act——手牌里只剩 8、9
	var cleared: bool = bool(model.call(&"sync_hand", [8, 9]))
	# Assert
	assert_true(cleared, "自清发生过")
	assert_false(model.has_selection(), "选中被清空")
	assert_false(model.can_confirm(), "幽灵选中不可确认")


## 选中的卡仍在手牌 → 不动（不清、不误报）。
func test_sync_hand_keeps_selection_when_card_present() -> void:
	# Arrange
	model.call(&"select_card", 7, true, false)
	model.call(&"select_target", [101])
	# Act
	var cleared: bool = bool(model.call(&"sync_hand", [7, 8]))
	# Assert
	assert_false(cleared, "卡还在手牌 → 不自清")
	assert_true(model.is_selected(7), "选中保持")
	assert_eq(model.get_target_indices(), [101], "目标保持")


## 无选中时 sync_hand 是无操作（返回值恒 false）。
func test_sync_hand_is_noop_without_selection() -> void:
	# Act / Assert
	assert_false(bool(model.call(&"sync_hand", [])), "无选中时不报自清")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 目标列表契约
# ═══════════════════════════════════════════════════════════════════════════════

## get_target_indices 返回副本——调用方改它不污染模型。
func test_get_targets_returns_copy() -> void:
	# Arrange
	model.call(&"select_target", [101, 102])
	# Act
	var targets: Array = model.get_target_indices()
	targets.append(999)
	# Assert
	assert_eq(model.get_target_indices(), [101, 102], "外部修改不回流到模型")


## 目标去重 + 负值跳过。
func test_select_target_deduplicates_and_skips_negative() -> void:
	# Act
	model.call(&"select_target", [-1, 101, 101, 102])
	# Assert
	assert_eq(model.get_target_indices(), [101, 102], "去重且跳过负值")
