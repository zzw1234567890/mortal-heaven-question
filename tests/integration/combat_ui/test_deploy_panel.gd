extends GutTest
## combat-ui-layout Story 007 集成测试：备战面板装配与信号驱动渲染。
##
## 覆盖 AC-1（视觉框架：标题/角色卡网格/阵位预览/两个按钮）、AC-2（4 态渲染）、
## AC-5（提示与确认按钮态）、AC-6（阵位预览随选择实时更新——信号驱动）、
## AC-7（悬停协同信息）。
##
## Story 类型 UI（Logic 内核）——Logic 内核单测为 BLOCKING 证据（
## test_deploy_selection_state / test_formation_slot_layout），本文件提供面板装配与
## 渲染接线证据。

const PanelScript := preload("res://src/ui/combat/deploy/deploy_panel.gd")
const Rules := preload("res://src/ui/combat/shared/deploy_panel_rules.gd")

var panel: Control = null


func before_each() -> void:
	panel = PanelScript.new()
	add_child_autofree(panel)


## 构造测试名册（不依赖真实系统——面板只消费快照）。
func _make_roster(dead_ids: Array = []) -> Array:
	var roster: Array = []
	var names: Array = ["林渊", "苏剑鸣", "陆青", "白芷", "韩霜", "沈墨"]
	var tags: Array = [
		[&"qing_yun", &"sword"], [&"qing_yun"], [&"fire"],
		[&"fire", &"alchemy"], [&"sword"], [&"water"],
	]
	for i: int in range(6):
		var cid: int = 100 + i
		roster.append({
			"character_id": cid,
			"display_name": names[i],
			"hp": 8 + i,
			"attack": 3 + i % 3,
			"binding_count": 1 if i < 2 else 0,
			"faction_tags": tags[i],
			"is_dead": dead_ids.has(cid),
			"slot_index": i,
		})
	return roster


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：视觉框架骨架
# ═══════════════════════════════════════════════════════════════════════════════

func test_panel_builds_title_cards_preview_and_buttons() -> void:
	# Act
	panel.apply_roster(_make_roster(), 2, 1)
	# Assert: 四个框架要素齐备
	assert_not_null(panel.title_label, "应有战斗名称标题")
	assert_not_null(panel.get_node_or_null(NodePath("CharacterGrid")), "应有角色卡网格")
	assert_not_null(panel.preview, "应有阵位布局预览")
	assert_not_null(panel.confirm_button, "应有确认出战按钮")
	assert_not_null(panel.back_button, "应有返回探索按钮")
	assert_eq(panel.confirm_button.text, "确认出战", "确认按钮文案")
	assert_eq(panel.back_button.text, "返回探索", "返回按钮文案")


func test_panel_creates_one_card_per_roster_entry() -> void:
	# Act
	panel.apply_roster(_make_roster(), 2, 1)
	# Assert
	assert_eq(panel.get_cards().size(), 6, "名册 6 人应创建 6 张缩略卡")


func test_panel_title_set_battle_name() -> void:
	# Act
	panel.set_battle_title("⚔ 青云剑宗·山门 — 普通战斗")
	# Assert
	assert_eq(panel.title_label.text, "⚔ 青云剑宗·山门 — 普通战斗", "标题应可设置")


func test_card_shows_roster_stats() -> void:
	# Act
	panel.apply_roster(_make_roster(), 2, 1)
	var card: Control = panel.get_cards()[0]
	# Assert: 缩略卡含头像区/名称/HP/ATK/绑定概览数据
	assert_eq(card.get_display_name(), "林渊", "卡片显示名应来自名册")
	assert_eq(int(card.data.get("hp", 0)), 8, "卡片应含 HP")
	assert_eq(int(card.data.get("attack", 0)), 3, "卡片应含 ATK")
	assert_eq(int(card.data.get("binding_count", 0)), 1, "卡片应含绑定概览数量")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：4 态渲染
# ═══════════════════════════════════════════════════════════════════════════════

func test_cards_start_selectable_and_dead_start_unavailable() -> void:
	# Act
	panel.apply_roster(_make_roster([102]), 2, 1)
	# Assert: 未阵亡者可选中，阵亡者不可用
	assert_eq(panel.get_selection_state(100), Rules.STATE_SELECTABLE, "未选角色应为 selectable")
	assert_eq(panel.get_selection_state(102), Rules.STATE_UNAVAILABLE, "阵亡角色应为 unavailable")


func test_selected_card_becomes_selected_state() -> void:
	# Act
	panel.apply_roster(_make_roster(), 2, 1)
	assert_true(panel.toggle_selection(100), "首次点选应成功")
	# Assert
	assert_eq(panel.get_selection_state(100), Rules.STATE_SELECTED, "已选角色应为 selected")
	assert_eq(panel.get_selected_ids(), [100], "已选列表应包含该角色")


func test_dead_character_cannot_be_selected() -> void:
	# Act
	panel.apply_roster(_make_roster([101]), 2, 1)
	var changed: bool = panel.toggle_selection(101)
	# Assert
	assert_false(changed, "阵亡角色点选应被拒绝")
	assert_true(panel.get_selected_ids().is_empty(), "阵亡角色不应进入已选列表")


func test_full_selection_makes_others_replaceable() -> void:
	# Arrange: 炼气上限 2
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	panel.toggle_selection(101)
	# Assert: 名额满后其余未选角色为可替换
	assert_eq(panel.get_selection_state(102), Rules.STATE_REPLACEABLE,
			"名额满后未选角色应为 replaceable")


func test_deselect_returns_card_to_selectable() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	# Act: 再点一次取消
	var changed: bool = panel.toggle_selection(100)
	# Assert
	assert_true(changed, "取消选择应成功")
	assert_eq(panel.get_selection_state(100), Rules.STATE_SELECTABLE, "取消后应回到 selectable")
	assert_true(panel.get_selected_ids().is_empty(), "已选列表应为空")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：提示与确认按钮
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_button_disabled_with_zero_selection() -> void:
	# Act
	panel.apply_roster(_make_roster(), 2, 1)
	# Assert
	assert_true(panel.confirm_button.disabled, "0 已选时确认按钮应禁用")


func test_confirm_button_enabled_after_first_selection() -> void:
	# Act
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	# Assert
	assert_false(panel.confirm_button.disabled, "1 已选时确认按钮应启用")


func test_hint_updates_with_selection_count() -> void:
	# Act
	panel.apply_roster(_make_roster(), 3, 2)
	assert_eq(panel.hint_label.text, "还可以选择3人", "未选时应提示全部剩余")
	panel.toggle_selection(100)
	# Assert
	assert_eq(panel.hint_label.text, "还可以选择2人", "选 1 人后应提示剩余 2 人")


func test_hint_shows_full_state_when_max_reached() -> void:
	# Act
	panel.apply_roster(_make_roster(), 1, 1)
	panel.toggle_selection(100)
	# Assert
	assert_false(panel.hint_label.text.begins_with("还可以选择"), "满员后不再提示剩余人数")


func test_confirm_signal_emits_selected_ids() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	panel.toggle_selection(101)
	watch_signals(panel)
	# Act
	panel.confirm_button.pressed.emit()
	# Assert: 载荷为已选 ID 列表（上层据此调用 DeploymentSystem.setup_field）
	assert_signal_emitted(panel, "confirm_requested", "点击确认应发射 confirm_requested")
	var params: Array = get_signal_parameters(panel, "confirm_requested")
	assert_eq(params[0], [100, 101], "确认信号应携带已选角色 ID 列表")


func test_back_signal_emits_on_back_pressed() -> void:
	# Arrange
	watch_signals(panel)
	# Act
	panel.back_button.pressed.emit()
	# Assert
	assert_signal_emitted(panel, "back_requested", "点击返回应发射 back_requested")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：阵位预览随选择实时更新（信号驱动）
# ═══════════════════════════════════════════════════════════════════════════════

func test_preview_layout_follows_realm() -> void:
	# Act: 炼气 前2后1
	panel.apply_roster(_make_roster(), 2, 1)
	# Assert
	assert_eq(panel.preview.layout["front"], 2, "炼气预览前排 2")
	assert_eq(panel.preview.layout["back"], 1, "炼气预览后排 1")


func test_preview_updates_when_selection_changes() -> void:
	# Arrange: 化神 前3后3
	panel.apply_roster(_make_roster(), 6, 5)
	# Act: 选 4 人 → 前排 3 后排 1
	panel.toggle_selection(100)
	panel.toggle_selection(101)
	panel.toggle_selection(102)
	panel.toggle_selection(103)
	# Assert: 前排填满 3 人，后排 1 人
	assert_eq(panel.preview.get_row_names(0).size(), 3, "前排应填满 3 人")
	assert_eq(panel.preview.get_row_names(1), ["白芷"], "后排应按顺序填入第 4 人")


func test_preview_clears_when_deselecting_all() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	# Act
	panel.toggle_selection(100)
	# Assert
	assert_true(panel.preview.get_row_names(0).is_empty(), "取消全部选择后前排应为空")
	assert_true(panel.preview.get_row_names(1).is_empty(), "取消全部选择后后排应为空")


func test_preview_fills_front_before_back() -> void:
	# Arrange: 筑基 前2后2
	panel.apply_roster(_make_roster(), 3, 2)
	# Act: 选 2 人
	panel.toggle_selection(100)
	panel.toggle_selection(101)
	# Assert: 两人都在前排（前排优先填充）
	assert_eq(panel.preview.get_row_names(0), ["林渊", "苏剑鸣"], "应前排优先填充")
	assert_true(panel.preview.get_row_names(1).is_empty(), "后排应仍为空")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-7：悬停协同信息
# ═══════════════════════════════════════════════════════════════════════════════

func test_hover_shows_shared_faction_tags() -> void:
	# Arrange: 林渊 [qing_yun, sword] + 苏剑鸣 [qing_yun] 同时在场
	panel.apply_roster(_make_roster(), 3, 2)
	panel.toggle_selection(101)
	var card: Control = panel.get_cards()[0]
	# Act: 走真实信号路径（mouse_entered——锁定 AC-7「信号驱动」接线）
	card.mouse_entered.emit()
	# Assert: 显示共享阵营标签
	assert_true(panel.tooltip_label.visible, "悬停时应显示协同信息")
	assert_true(panel.tooltip_label.text.contains("qing_yun"), "应显示共享阵营标签")


func test_hover_without_synergy_shows_no_synergy_text() -> void:
	# Arrange: 韩霜 [sword] 已选，白芷 [fire, alchemy] 悬停——无交集
	panel.apply_roster(_make_roster(), 3, 2)
	panel.toggle_selection(104)
	var card: Control = panel.get_cards()[3]
	# Act
	card.mouse_entered.emit()
	# Assert
	assert_true(panel.tooltip_label.text.contains("暂无协同"), "无共享标签时应提示暂无协同")


func test_hover_exit_hides_tooltip() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 3, 2)
	var card: Control = panel.get_cards()[0]
	card.mouse_entered.emit()
	# Act: 真实 mouse_exited 信号
	card.mouse_exited.emit()
	# Assert
	assert_false(panel.tooltip_label.visible, "移出后应隐藏协同信息")


# ═══════════════════════════════════════════════════════════════════════════════
# 名册变化自洽性（阵亡后剔除已有选择）
# ═══════════════════════════════════════════════════════════════════════════════

func test_dead_confirmed_character_is_removed_from_selection() -> void:
	# Arrange: 先选 100，再刷新名册使其阵亡
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	# Act
	panel.apply_roster(_make_roster([100]), 2, 1)
	# Assert: 阵亡角色被剔除，不再计入已选
	assert_false(panel.get_selected_ids().has(100), "名册刷新后阵亡角色应被剔除")
	assert_eq(panel.get_selection_state(100), Rules.STATE_UNAVAILABLE, "阵亡角色应显示 unavailable")


func test_empty_roster_renders_skeleton_without_error() -> void:
	# Act: 依赖缺失/角色位为空
	panel.apply_roster([], 2, 1)
	# Assert: 骨架仍在，按钮禁用
	assert_eq(panel.get_cards().size(), 0, "空名册应无角色卡")
	assert_true(panel.confirm_button.disabled, "空名册确认按钮应禁用")


func test_unknown_character_state_is_empty_not_unavailable() -> void:
	# Act / Assert: 未知名册 ID 返回空串（审查 M11——与「已阵亡」语义分离）
	panel.apply_roster(_make_roster(), 2, 1)
	assert_eq(panel.get_selection_state(999), "", "未知角色 ID 应返回空串")


# ═══════════════════════════════════════════════════════════════════════════════
# 上限收缩与替换流程（审查 H3 / H5）
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_roster_shrinks_selection_when_limit_drops() -> void:
	# Arrange: 化神上限 6 → 选 5 人
	panel.apply_roster(_make_roster(), 6, 5)
	for i: int in range(5):
		panel.toggle_selection(100 + i)
	# Act: 境界回落到炼气（上限 2）
	panel.apply_roster(_make_roster(), 2, 1)
	# Assert: 保留先选者并收缩到 2 人（防「已选满 5/2」+ 预览丢名）
	assert_eq(panel.get_selected_ids(), [100, 101], "上限收缩应保留先选者")
	assert_false(panel.hint_label.text.begins_with("已选满 5"), "收缩后不应残留超限提示")


func test_replace_confirmed_swaps_specified_character() -> void:
	# Arrange: 炼气上限 2 已选满 100/101，请求 102 替换 101
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	panel.toggle_selection(101)
	panel.request_replace(102, 101)
	watch_signals(panel)
	# Act
	panel._on_replace_confirmed()
	# Assert: 指定位置被替换，载荷为 (新, 被替换)
	assert_eq(panel.get_selected_ids(), [100, 102], "应替换指定的已选角色而非固定首位")
	var params: Array = get_signal_parameters(panel, "replace_requested")
	assert_eq(params[0], 102, "替换信号应携带新角色 ID")
	assert_eq(params[1], 101, "替换信号应携带被替换角色 ID")


func test_replace_canceled_clears_pending() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 2, 1)
	panel.toggle_selection(100)
	panel.toggle_selection(101)
	panel.request_replace(102)
	var before: Array = panel.get_selected_ids()
	# Act
	panel._on_replace_canceled()
	# Assert: 取消不改变已选
	assert_eq(panel.get_selected_ids(), before, "取消替换不应改变已选阵容")
	assert_eq(panel.get_pending_replace_id(), -1, "取消后待确认替换应清空")
