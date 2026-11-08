extends GutTest
## combat-ui-layout Story 007 单元测试：角色选择 4 态判定（AC-2/AC-3）。
##
## QA 规格（story QA Test Cases AC-1）：阵亡 → 不可用（优先）；已选 → ✓；
## 未选+未满 → ☐；未选+已满+未阵亡 → ⊕。
## 边界：阵亡且名额未满（仍不可用）；selected_count == max 恰好边界；max=1。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。

const Rules := preload("res://src/ui/combat/shared/deploy_panel_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 4 态主分支
# ═══════════════════════════════════════════════════════════════════════════════

func test_deploy_selection_state_selected_returns_selected() -> void:
	# Act / Assert: 已选 → ✓（名额未满）
	assert_eq(Rules.deploy_selection_state(false, true, 1, 3), Rules.STATE_SELECTED,
			"已选角色应为 selected")


func test_deploy_selection_state_unselected_not_full_returns_selectable() -> void:
	# Act / Assert: 未选 + 名额未满 → ☐
	assert_eq(Rules.deploy_selection_state(false, false, 1, 3), Rules.STATE_SELECTABLE,
			"未选且未满应为 selectable")


func test_deploy_selection_state_unselected_full_returns_replaceable() -> void:
	# Act / Assert: 未选 + 名额已满 → ⊕
	assert_eq(Rules.deploy_selection_state(false, false, 3, 3), Rules.STATE_REPLACEABLE,
			"未选且已满应为 replaceable")


func test_deploy_selection_state_dead_returns_unavailable() -> void:
	# Act / Assert: 阵亡 → 💀
	assert_eq(Rules.deploy_selection_state(true, false, 0, 3), Rules.STATE_UNAVAILABLE,
			"阵亡角色应为 unavailable")


# ═══════════════════════════════════════════════════════════════════════════════
# 边缘：阵亡优先 / 边界值
# ═══════════════════════════════════════════════════════════════════════════════

func test_deploy_selection_state_dead_overrides_selected() -> void:
	# Arrange: 阵亡但仍在已选集合（名册变化后的残留态）
	# Act / Assert: 阵亡优先于已选
	assert_eq(Rules.deploy_selection_state(true, true, 1, 3), Rules.STATE_UNAVAILABLE,
			"阵亡应优先于已选（阵亡 → 不可用）")


func test_deploy_selection_state_dead_with_free_slots_still_unavailable() -> void:
	# Act / Assert: 阵亡且名额未满（0/3）仍为不可用
	assert_eq(Rules.deploy_selection_state(true, false, 0, 3), Rules.STATE_UNAVAILABLE,
			"阵亡且名额未满仍应为 unavailable")


func test_deploy_selection_state_dead_overrides_replaceable() -> void:
	# Act / Assert: 阵亡 + 名额已满 → 不可用（非可替换）
	assert_eq(Rules.deploy_selection_state(true, false, 3, 3), Rules.STATE_UNAVAILABLE,
			"阵亡应优先于可替换")


func test_deploy_selection_state_boundary_selected_equals_max() -> void:
	# Arrange: selected_count == max_deploy 恰好边界
	# Act / Assert: 未选角色 → 可替换
	assert_eq(Rules.deploy_selection_state(false, false, 2, 2), Rules.STATE_REPLACEABLE,
			"selected_count 恰等 max_deploy 应为 replaceable")


func test_deploy_selection_state_boundary_one_below_max() -> void:
	# Act / Assert: selected_count = max-1 → 仍可选
	assert_eq(Rules.deploy_selection_state(false, false, 1, 2), Rules.STATE_SELECTABLE,
			"selected_count = max-1 应为 selectable")


func test_deploy_selection_state_max_deploy_one_full_returns_replaceable() -> void:
	# Act / Assert: max=1 时选满 1 人 → 其余未选角色可替换
	assert_eq(Rules.deploy_selection_state(false, false, 1, 1), Rules.STATE_REPLACEABLE,
			"max_deploy=1 选满后应为 replaceable")


func test_deploy_selection_state_max_deploy_one_empty_returns_selectable() -> void:
	# Act / Assert: max=1 且未选 → 可选
	assert_eq(Rules.deploy_selection_state(false, false, 0, 1), Rules.STATE_SELECTABLE,
			"max_deploy=1 未选应为 selectable")


func test_deploy_selection_state_constants_are_distinct() -> void:
	# Assert: 4 态常量互异（防止常量复制粘贴错误导致状态不可区分）
	var values: Array = [Rules.STATE_SELECTED, Rules.STATE_SELECTABLE,
			Rules.STATE_REPLACEABLE, Rules.STATE_UNAVAILABLE]
	var unique: Dictionary = {}
	for v: String in values:
		unique[v] = true
	assert_eq(unique.size(), 4, "4 态常量应互不相同")


# ═══════════════════════════════════════════════════════════════════════════════
# 确认按钮启用判定（AC-5）
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_button_enabled_zero_selected_returns_false() -> void:
	# Act / Assert: 0 已选 → 不可点
	assert_false(Rules.confirm_button_enabled(0), "0 已选时确认按钮应禁用")


func test_confirm_button_enabled_one_selected_returns_true() -> void:
	# Act / Assert: 1 已选 → 可点
	assert_true(Rules.confirm_button_enabled(1), "1 已选时确认按钮应启用")


func test_confirm_button_enabled_full_selected_returns_true() -> void:
	# Act / Assert: 满员 → 可点
	assert_true(Rules.confirm_button_enabled(6), "满员时确认按钮应启用")


# ═══════════════════════════════════════════════════════════════════════════════
# 提示文案（AC-5「还可以选择X人」）
# ═══════════════════════════════════════════════════════════════════════════════

func test_remaining_hint_reports_remaining_count() -> void:
	# Act / Assert: 3 上限、选 1 人 → 还可以选择2人
	assert_eq(Rules.remaining_hint(1, 3), "还可以选择2人", "未满时应提示剩余人数")


func test_remaining_hint_all_remaining() -> void:
	# Act / Assert: 未选时提示全部可选
	assert_eq(Rules.remaining_hint(0, 2), "还可以选择2人", "未选时应提示全部剩余")


func test_remaining_hint_full_shows_full_state() -> void:
	# Act / Assert: 满员不再提示剩余人数
	var hint: String = Rules.remaining_hint(3, 3)
	assert_false(hint.begins_with("还可以选择"), "满员时不应再提示还可以选择")
	assert_true(hint.contains("3/3"), "满员提示应包含 3/3")


func test_remaining_hint_uninitialized_limit_is_neutral() -> void:
	# Act / Assert（审查 LOW14）：上限未初始化（0 或负值）时不冒充「还可以选择 0 人」
	assert_eq(Rules.remaining_hint(0, 0), "上场人数上限未初始化",
			"上限为 0 时应提示未初始化")
	assert_eq(Rules.remaining_hint(2, -1), "上场人数上限未初始化",
			"上限为负值时应提示未初始化")


# ═══════════════════════════════════════════════════════════════════════════════
# 协同信息共享标签（AC-7）
# ═══════════════════════════════════════════════════════════════════════════════

func test_shared_faction_tags_returns_intersection() -> void:
	# Arrange
	var hovered: Array = [&"qing_yun", &"sword"]
	var selected: Array = [&"sword", &"fire"]
	# Act
	var shared: Array = Rules.shared_faction_tags(hovered, selected)
	# Assert
	assert_eq(shared, [&"sword"], "应返回两者交集")


func test_shared_faction_tags_empty_when_no_overlap() -> void:
	# Act / Assert
	assert_true(Rules.shared_faction_tags([&"a"], [&"b"]).is_empty(),
			"无交集时应为空")


func test_shared_faction_tags_deduplicates() -> void:
	# Arrange: 悬停角色标签重复 + 已选标签重复
	var shared: Array = Rules.shared_faction_tags([&"a", &"a"], [&"a", &"a"])
	# Assert
	assert_eq(shared, [&"a"], "共享标签应去重")


func test_shared_faction_tags_preserves_hovered_order() -> void:
	# Arrange
	var shared: Array = Rules.shared_faction_tags([&"b", &"a"], [&"a", &"b"])
	# Assert
	assert_eq(shared, [&"b", &"a"], "共享标签应保持悬停角色标签顺序")


func test_shared_faction_tags_empty_inputs() -> void:
	# Act / Assert
	assert_true(Rules.shared_faction_tags([], [&"a"]).is_empty(), "悬停标签为空时应返回空")
	assert_true(Rules.shared_faction_tags([&"a"], []).is_empty(), "已选标签为空时应返回空")


# ═══════════════════════════════════════════════════════════════════════════════
# 文案纯函数（协同提示 / 替换确认——面板只消费不内联）
# ═══════════════════════════════════════════════════════════════════════════════

func test_synergy_text_with_shared_tags() -> void:
	# Act
	var text: String = Rules.synergy_text("林渊", [&"qing_yun", &"sword"])
	# Assert
	assert_true(text.begins_with("林渊"), "文案应以角色名开头")
	assert_true(text.contains("qing_yun"), "文案应包含共享标签")
	assert_true(text.contains("sword"), "文案应包含全部共享标签")


func test_synergy_text_without_shared_tags() -> void:
	# Act / Assert
	assert_eq(Rules.synergy_text("白芷", []), "白芷：暂无协同", "无共享标签时提示暂无协同")


func test_replace_prompt_matches_gdd_wording() -> void:
	# Act / Assert: GDD §8 明文「用[角色名]替换[已选角色名]？」
	assert_eq(Rules.replace_prompt("陆青", "林渊"), "用陆青替换林渊？",
			"替换确认文案应符合 GDD 句式")
