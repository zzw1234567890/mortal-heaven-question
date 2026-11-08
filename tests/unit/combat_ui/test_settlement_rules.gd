extends GutTest
## combat-ui-layout Story 008 单元测试：结算/撤退 Logic 内核（AC-1~AC-10 判定层）。
##
## QA 规格（story QA Test Cases AC-1）：0.5s 延迟可点判定（内 disabled / 后
## enabled）；未选中时确认按钮灰；卡组满时卡牌选项 disabled；恰 0.5s 边界固化。
## 另覆盖三选一均匀等宽网格、结果→面板种类映射、战败 50% 摘要、撤退 50%/80%
## 双变体、渡劫战前警示文案。
##
## Story 类型 UI（Logic 内核）——此文件为 Logic 内核证据；面板装配与信号驱动的
## BLOCKING 证据见 tests/integration/combat_ui/test_loot_delay_clickable.gd。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const Retreat := preload("res://src/ui/combat/shared/retreat_rules.gd")
## 结果枚举取真源（不在测试内复制 1/2/3——生产枚举改动时本测试会跟着失败）。
const CombatSystemScript := preload("res://src/feature/combat_system.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：0.5s 延迟可点
# ═══════════════════════════════════════════════════════════════════════════════

func test_loot_clickable_false_immediately_after_show() -> void:
	assert_false(Rules.loot_clickable(0.0), "展示瞬间战利品应不可点")


func test_loot_clickable_false_just_before_delay() -> void:
	assert_false(Rules.loot_clickable(0.49), "0.5s 之前战利品应不可点")


func test_loot_clickable_true_exactly_at_delay_boundary() -> void:
	# 边界固化：恰好 0.5s 即视为可点（QDD「展示后 0.5s 延迟才变为可点击」）
	assert_true(Rules.loot_clickable(0.5), "恰好 0.5s 应视为可点（边界固化）")


func test_loot_clickable_true_after_delay() -> void:
	assert_true(Rules.loot_clickable(1.2), "0.5s 之后战利品应可点")


func test_loot_clickable_negative_elapsed_treated_as_zero() -> void:
	assert_false(Rules.loot_clickable(-1.0), "负经过时间应钳制为 0（不可点）")


func test_loot_hint_text_switches_with_clickable() -> void:
	assert_eq(Rules.loot_hint_text(false), Rules.TEXT_LOOT_WAITING, "等待期提示文案")
	assert_eq(Rules.loot_hint_text(true), Rules.TEXT_LOOT_READY, "就绪期提示文案")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：确认按钮启用判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_button_disabled_without_selection() -> void:
	assert_false(Rules.confirm_button_enabled(-1, true),
			"未选中任何项时确认按钮应灰（即使已过延迟）")


func test_confirm_button_disabled_before_delay_even_with_selection() -> void:
	assert_false(Rules.confirm_button_enabled(0, false),
			"未过延迟窗口时确认按钮应灰（即使已选中）")


func test_confirm_button_enabled_with_selection_after_delay() -> void:
	assert_true(Rules.confirm_button_enabled(0, true),
			"已选中且已过延迟时确认按钮应可点")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：三选一均匀等宽网格（GDD §边界情况）
# ═══════════════════════════════════════════════════════════════════════════════

func test_loot_grid_layout_three_equal_columns() -> void:
	# Arrange: 内容宽 656、间隔 16、3 列
	var layout: Dictionary = Rules.loot_grid_layout(656.0, 16.0, 3)
	# Assert: (656 - 16×2) / 3 = 208
	assert_eq(int(layout["columns"]), 3, "列数应为 3")
	assert_almost_eq(float(layout["cell_width"]), 208.0, 0.001, "每格等宽 208")
	assert_almost_eq(float(layout["used_width"]), 656.0, 0.001,
			"格宽×列数 + 间隔应等于内容宽（无溢出）")


func test_loot_grid_layout_cells_are_identical_width() -> void:
	# 等宽语义的直接断言：总占用 = 内容宽，且三格宽度一致（cell_width 单一值）
	var layout: Dictionary = Rules.loot_grid_layout(500.0, 10.0, 3)
	var cell: float = float(layout["cell_width"])
	assert_almost_eq(cell, (500.0 - 20.0) / 3.0, 0.001, "三格等宽 = (W - 2×gap)/3")
	assert_almost_eq(cell * 3.0 + 20.0, 500.0, 0.001, "三格 + 两间隔铺满内容宽")


func test_loot_grid_layout_narrow_panel_clamps_to_zero() -> void:
	# 内容宽不足以容纳间隔——不产负宽（Godot 负尺寸会告警）
	var layout: Dictionary = Rules.loot_grid_layout(20.0, 16.0, 3)
	assert_eq(float(layout["cell_width"]), 0.0, "窄面板格宽应钳制为 0（非负）")


func test_loot_grid_layout_columns_zero_treated_as_one() -> void:
	var layout: Dictionary = Rules.loot_grid_layout(300.0, 16.0, 0)
	assert_eq(int(layout["columns"]), 1, "列数 ≤0 应按 1 处理")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：卡组满灰显
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_deck_full_true_at_limit() -> void:
	assert_true(Rules.is_deck_full(20, 20), "张数达上限应判满")


func test_is_deck_full_false_below_limit() -> void:
	assert_false(Rules.is_deck_full(19, 20), "张数未达上限应判未满")


func test_is_deck_full_false_when_limit_uninitialized() -> void:
	assert_false(Rules.is_deck_full(5, 0), "上限未初始化（0）不应误判为满")


func test_card_option_greys_out_when_deck_full() -> void:
	var option: Dictionary = {"kind": Rules.OPTION_KIND_CARD, "name": "青云剑诀"}
	assert_eq(Rules.loot_option_state(option, 20, 20), Rules.OPTION_DECK_FULL,
			"卡组满时卡牌选项应灰显为 deck_full")


func test_lingshi_option_remains_available_when_deck_full() -> void:
	var option: Dictionary = {"kind": Rules.OPTION_KIND_LINGSHI, "amount": 25}
	assert_eq(Rules.loot_option_state(option, 20, 20), Rules.OPTION_AVAILABLE,
			"卡组满时灵石选项仍可选（不占卡位）")


func test_consumable_option_remains_available_when_deck_full() -> void:
	var option: Dictionary = {"kind": Rules.OPTION_KIND_CONSUMABLE, "name": "回血丹"}
	assert_eq(Rules.loot_option_state(option, 30, 20), Rules.OPTION_AVAILABLE,
			"卡组满时消耗品选项仍可选")


func test_deck_full_option_is_not_clickable() -> void:
	assert_false(Rules.option_clickable(Rules.OPTION_DECK_FULL),
			"deck_full 选项不可点")
	assert_true(Rules.option_clickable(Rules.OPTION_AVAILABLE), "可选态可点")
	assert_true(Rules.option_clickable(Rules.OPTION_SELECTED), "已选态可点")


func test_deck_full_option_note_matches_gdd_wording() -> void:
	assert_eq(Rules.loot_option_note(Rules.OPTION_DECK_FULL), "卡组已满",
			"灰显标注文案须为 GDD 原文「卡组已满」")
	assert_eq(Rules.loot_option_note(Rules.OPTION_SELECTED), "已选中", "选中角标")
	assert_eq(Rules.loot_option_note(Rules.OPTION_AVAILABLE), "", "可选态无角标")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：战利品选项文案（GDD §9 线框）
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_option_label_shows_name_rarity_and_school() -> void:
	var label: Dictionary = Rules.loot_option_label({
		"kind": Rules.OPTION_KIND_CARD, "name": "青云剑诀",
		"rarity": "蓝", "school": "功法",
	})
	assert_eq(str(label["title"]), "青云剑诀", "卡牌标题为卡名")
	assert_eq(str(label["subtitle"]), "（蓝·功法）", "副标题为（稀有度·类型）")


func test_lingshi_option_label_shows_amount() -> void:
	var label: Dictionary = Rules.loot_option_label({
		"kind": Rules.OPTION_KIND_LINGSHI, "amount": 25,
	})
	assert_eq(str(label["title"]), "灵石", "灵石标题")
	assert_eq(str(label["subtitle"]), "×25", "灵石数值（GDD 线框「×25」）")


func test_consumable_option_label_shows_consumable_tag() -> void:
	var label: Dictionary = Rules.loot_option_label({
		"kind": Rules.OPTION_KIND_CONSUMABLE, "name": "回血丹",
	})
	assert_eq(str(label["title"]), "回血丹", "消耗品标题")
	assert_eq(str(label["subtitle"]), "（消耗品）", "消耗品副标题")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：战斗结果 → 面板种类
# ═══════════════════════════════════════════════════════════════════════════════

func test_panel_kind_victory() -> void:
	assert_eq(Rules.panel_kind_for(CombatSystemScript.CombatResult.VICTORY),
			Rules.KIND_VICTORY, "VICTORY → 战利品面板")


func test_panel_kind_defeat() -> void:
	assert_eq(Rules.panel_kind_for(CombatSystemScript.CombatResult.DEFEAT),
			Rules.KIND_DEFEAT, "DEFEAT → 战败摘要面板")


func test_panel_kind_retreat() -> void:
	assert_eq(Rules.panel_kind_for(CombatSystemScript.CombatResult.RETREAT),
			Rules.KIND_RETREAT, "RETREAT → 撤退流程（不另开结算面板）")


func test_panel_kind_unknown_returns_none() -> void:
	assert_eq(Rules.panel_kind_for(999), Rules.KIND_NONE,
			"未知结果应返回 KIND_NONE（不静默默认成胜利）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：战败摘要（50% 修为 + 阵亡角色 + 绑定卡）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_loss_percent_normal_is_fifty() -> void:
	assert_eq(Rules.cultivation_loss_percent(false), 50, "普通战败修为损失 50%")


func test_cultivation_loss_percent_tribulation_is_eighty() -> void:
	assert_eq(Rules.cultivation_loss_percent(true), 80, "渡劫修为损失 80%")


func test_defeat_lines_state_fifty_percent_lost() -> void:
	var lines: Array = Rules.defeat_lines({
		"cultivation_lost": 12, "dead_names": ["林渊"], "binding_card_count": 2,
	})
	assert_true(str(lines[0]).contains("50%"), "首行应为 50% 修为损失")
	assert_true(str(lines[0]).contains("-12"), "有具体数值时应附带扣减量")
	assert_true(str(lines[1]).contains("林渊"), "次行应列出阵亡角色名")
	assert_true(str(lines[1]).contains("不可用"), "阵亡角色应标注不可用")
	assert_true(str(lines[2]).contains("2"), "第三行应说明绑定卡张数")


func test_defeat_lines_without_dead_names_says_none() -> void:
	var lines: Array = Rules.defeat_lines({})
	assert_true(str(lines[1]).contains("无"), "无阵亡角色时显示「无」")
	assert_eq(lines.size(), 2, "无绑定卡时不追加绑定行")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6/AC-7：撤退双变体（普通 50% / 渡劫 80%）
# ═══════════════════════════════════════════════════════════════════════════════

func test_retreat_loss_ratio_normal_is_half() -> void:
	assert_almost_eq(Retreat.retreat_cultivation_loss_ratio(false), 0.5, 0.0001,
			"普通撤退修为损失 50%")


func test_retreat_loss_ratio_tribulation_is_eighty_percent() -> void:
	assert_almost_eq(Retreat.retreat_cultivation_loss_ratio(true), 0.8, 0.0001,
			"渡劫撤退修为损失 80%（GDD §10 2026-07-24 修订）")


func test_retreat_loss_percent_integers() -> void:
	assert_eq(Retreat.retreat_cultivation_loss_percent(false), 50, "普通 50")
	assert_eq(Retreat.retreat_cultivation_loss_percent(true), 80, "渡劫 80")


func test_retreat_title_differs_between_variants() -> void:
	assert_eq(Retreat.retreat_title(false), "⚠ 确认撤退？", "普通撤退标题")
	assert_true(Retreat.retreat_title(true).contains("渡劫"),
			"渡劫变体标题应含「渡劫」以便区分")


func test_tribulation_retreat_warning_is_cinnabar_only_for_tribulation() -> void:
	var trib: Array = Retreat.retreat_warning_lines(true)
	assert_eq(trib.size(), 1, "渡劫变体应有一行专属警示")
	assert_eq(str(trib[0]), "畏劫而退，修为散尽", "渡劫警示文案（GDD 原文）")
	assert_eq(Retreat.retreat_warning_lines(false).size(), 0,
			"普通变体不得出现渡劫警示（不与 50% 混用）")


func test_tribulation_retreat_border_is_cinnabar() -> void:
	assert_eq(Retreat.retreat_border_color(true), Rules.COLOR_DANGER,
			"渡劫变体边框应为朱砂红 #B3424A")
	assert_eq(Rules.COLOR_DANGER.to_html(false), "b3424a", "朱砂红色值须为 #B3424A")
	assert_eq(Retreat.retreat_border_color(false), Rules.COLOR_PANEL_BORDER,
			"普通变体边框为淡墨")


func test_tribulation_retreat_lines_mention_eighty_percent_and_lost_chance() -> void:
	var lines: Array = Retreat.retreat_lines(true, 0)
	var joined: String = "\n".join(PackedStringArray(lines))
	assert_true(joined.contains("80%"), "渡劫撤退正文应写明 80% 修为损失")
	assert_true(joined.contains("渡劫机会"), "渡劫撤退正文应写明失去渡劫机会")
	assert_true(joined.contains("绑定卡"), "渡劫撤退也应保留绑定卡失去说明")


func test_normal_retreat_lines_keep_non_binding_items() -> void:
	var lines: Array = Retreat.retreat_lines(false, 3)
	var joined: String = "\n".join(PackedStringArray(lines))
	assert_true(joined.contains("非绑定物品"), "普通撤退保留非绑定物品")
	assert_false(joined.contains("80%"), "普通撤退不得出现 80%（Boss 50% 口径）")
	assert_true(joined.contains("3 张"), "有阵亡绑定卡时应补具体张数")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8：渡劫战前警示
# ═══════════════════════════════════════════════════════════════════════════════

func test_pre_battle_body_matches_gdd_wording() -> void:
	assert_eq(Retreat.pre_battle_body(), "天劫在前，退路将断。确认进战？",
			"战前警示正文须为 GDD 原文")


func test_pre_battle_buttons_match_gdd() -> void:
	var texts: Dictionary = Retreat.pre_battle_button_texts()
	assert_eq(str(texts["confirm"]), "确认进战", "确认按钮文案")
	assert_eq(str(texts["cancel"]), "返回", "返回按钮文案")


func test_pre_battle_warning_only_for_unconfirmed_tribulation() -> void:
	assert_true(Retreat.should_show_pre_battle_warning(true, false),
			"渡劫战未确认过时应弹警示")
	assert_false(Retreat.should_show_pre_battle_warning(true, true),
			"已确认过时同场不再重复弹")
	assert_false(Retreat.should_show_pre_battle_warning(false, false),
			"非渡劫战不弹警示")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-9：撤退按钮渲染态常驻可点
# ═══════════════════════════════════════════════════════════════════════════════

func test_retreat_button_always_enabled() -> void:
	assert_true(Retreat.retreat_button_always_enabled(),
			"撤退按钮渲染态应始终可点（GDD §10）")
	assert_eq(Retreat.retreat_button_text(), "撤退", "撤退按钮文案")


func test_victory_hint_falls_back_when_no_loot() -> void:
	assert_eq(Rules.victory_hint_text(false, 0), "本次无战利品",
			"空战利品应给出兜底文案（不显示「点击选中」）")
	assert_eq(Rules.victory_hint_text(true, 0), "本次无战利品",
			"延迟到点后空战利品仍显示兜底文案")
	assert_eq(Rules.victory_hint_text(false, 3), Rules.TEXT_LOOT_WAITING,
			"有战利品时等待期文案不变")
	assert_eq(Rules.victory_hint_text(true, 3), Rules.TEXT_LOOT_READY,
			"有战利品时到点文案不变")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：战利品卡内容块垂直居中（口径进内核——可断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_loot_card_content_top_centers_block_vertically() -> void:
	# Arrange: 卡格 210 + 内容块 70 → 上下各留 70
	# Act
	var top: float = Rules.loot_card_content_top(Rules.LOOT_CELL_HEIGHT)
	# Assert：上下留白相等（垂直居中的可断言定义）
	var bottom_gap: float = Rules.LOOT_CELL_HEIGHT \
			- top - Rules.CARD_CONTENT_BLOCK_HEIGHT
	assert_almost_eq(top, bottom_gap, 0.01, "内容块应垂直居中（上下留白相等）")
	assert_almost_eq(top, 70.0, 0.01, "(210-70)/2 = 70")


func test_loot_card_content_top_clamps_for_short_cell() -> void:
	# Arrange: 卡格比内容块还矮（退化布局）
	# Act
	var top: float = Rules.loot_card_content_top(40.0)
	# Assert：不产生负基线
	assert_eq(top, 0.0, "卡格矮于内容块时顶边钳制为 0（不产负基线）")
