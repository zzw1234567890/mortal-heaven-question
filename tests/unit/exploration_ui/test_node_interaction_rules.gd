extends GutTest
## exploration-ui Story 006 单元测试：节点交互弹窗 Logic 内核（NodeInteractionRules）。
##
## [b]覆盖[/b]（BLOCKING——ADR-0031 §2 零状态纯函数）：[br]
##   - 分发表路由（GDD §4c 五类 + 事件/传送显式排除，AC-1/AC-9/AC-10）
##   - 确认动作三元组（kind → action）
##   - 战斗敌人摘要三要素（名称/数量/境界，AC-2）+ 双形态载荷兼容
##   - 推荐上场角色数（数据驱动 + ≥1/≤max_deploy 不变量）
##   - 渡劫 80% 警示（AC-6——渡劫专属，不得与 Boss 50% 混用）
##   - 回复量校验包装（灵泉满回复 / 回复点 floor 50%——GDD 公式 7）
##   - 弹窗定位（节点附近 + 视口内 clamp + 越界翻转）
##
## 来源: story-006-node-interaction-popups.md QA Test Cases AC-1、AC-4、AC-5、AC-6；
## design/gdd/exploration-ui-system.md §4/§4b/§4c、design/gdd/exploration-system.md 公式 7。

const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：分发表路由（GDD §4c）
# ═══════════════════════════════════════════════════════════════════════════════

func test_dispatch_routes_five_interaction_types() -> void:
	# Arrange / Act / Assert（GDD §4c 表逐行）
	assert_eq(Rules.popup_kind_for(&"shop"), Rules.KIND_SHOP, "shop → 商店弹窗")
	assert_eq(Rules.popup_kind_for(&"action_spring"), Rules.KIND_SPRING,
			"action_spring → 灵泉弹窗")
	assert_eq(Rules.popup_kind_for(&"rest"), Rules.KIND_REST, "rest → 回复点弹窗")
	assert_eq(Rules.popup_kind_for(&"tribulation"), Rules.KIND_TRIBULATION,
			"tribulation → 渡劫台弹窗")


func test_dispatch_routes_combat_and_elite_to_combat_popup() -> void:
	# combat 与 elite 共用战斗确认弹窗（GDD §4c「战斗/精英」同一行）
	assert_eq(Rules.popup_kind_for(&"combat"), Rules.KIND_COMBAT, "combat → 战斗弹窗")
	assert_eq(Rules.popup_kind_for(&"elite"), Rules.KIND_COMBAT, "elite → 战斗弹窗")


func test_dispatch_excludes_event_and_teleport_nodes() -> void:
	# AC-9/AC-10：事件（EventSystem 面板接管）与传送（B5 机制未闭合）均无弹窗
	assert_eq(Rules.popup_kind_for(&"event"), Rules.KIND_NONE,
			"事件节点不得进入探索 UI 分发表（防双面板）")
	assert_eq(Rules.popup_kind_for(&"teleport"), Rules.KIND_NONE,
			"传送节点无交互弹窗（B5 裁决）")
	assert_false(Rules.has_popup(&"event"), "事件节点 has_popup 应为 false")
	assert_false(Rules.has_popup(&"teleport"), "传送节点 has_popup 应为 false")


func test_dispatch_unknown_type_yields_no_popup() -> void:
	assert_eq(Rules.popup_kind_for(&"nonexistent"), Rules.KIND_NONE,
			"未知 interaction_type 不应弹出任何面板")
	assert_eq(Rules.popup_kind_for(&""), Rules.KIND_NONE, "空类型无弹窗")


func test_dispatch_table_covers_every_confirm_action() -> void:
	# 分发表每个 kind 都必须有确认动作（缺一项会让弹窗确认变成空操作）
	for interaction_type: StringName in Rules.DISPATCH_TABLE.keys():
		var kind: StringName = Rules.popup_kind_for(interaction_type)
		assert_ne(Rules.confirm_action_for(kind), Rules.ACTION_NONE,
				"kind '%s' 缺少确认动作" % kind)


# ═══════════════════════════════════════════════════════════════════════════════
# 确认动作三元组
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_actions_match_gdd_dispatch_table() -> void:
	assert_eq(Rules.confirm_action_for(Rules.KIND_COMBAT), Rules.ACTION_ENTER_COMBAT,
			"战斗 → 进入战斗")
	assert_eq(Rules.confirm_action_for(Rules.KIND_SHOP), Rules.ACTION_OPEN_SHOP,
			"商店 → 打开商店 overlay（B9 非场景切换）")
	assert_eq(Rules.confirm_action_for(Rules.KIND_SPRING), Rules.ACTION_USE_SPRING,
			"灵泉 → 使用灵泉")
	assert_eq(Rules.confirm_action_for(Rules.KIND_REST), Rules.ACTION_REST,
			"回复点 → 休息")
	assert_eq(Rules.confirm_action_for(Rules.KIND_TRIBULATION),
			Rules.ACTION_ENTER_TRIBULATION, "渡劫台 → 挑战渡劫")


func test_button_texts_follow_gdd_wireframes() -> void:
	# GDD §4/§4b 线框原文措辞
	assert_eq(Rules.button_texts(Rules.KIND_COMBAT)["confirm"], "进入战斗")
	assert_eq(Rules.button_texts(Rules.KIND_COMBAT)["cancel"], "先等等")
	assert_eq(Rules.button_texts(Rules.KIND_SPRING)["confirm"], "使用灵泉")
	assert_eq(Rules.button_texts(Rules.KIND_REST)["confirm"], "休息")
	assert_eq(Rules.button_texts(Rules.KIND_TRIBULATION)["confirm"], "挑战渡劫")
	assert_eq(Rules.button_texts(Rules.KIND_TRIBULATION)["cancel"], "再等等")


func test_title_for_every_kind_is_non_empty() -> void:
	for kind: StringName in Rules.CONFIRM_ACTIONS.keys():
		assert_false(Rules.title_for(kind).is_empty(), "kind '%s' 缺少标题" % kind)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：战斗弹窗内容（敌人名称 + 数量 + 境界 + 推荐战力）
# ═══════════════════════════════════════════════════════════════════════════════

func test_combat_summary_reads_name_count_and_realm_from_dicts() -> void:
	# Arrange: stub 形态（Dictionary 载荷）
	var roster: Array = [
		{"name": "青云剑宗外门弟子", "realm": 1},
		{"name": "青云剑宗外门弟子", "realm": 1},
	]
	# Act
	var summary: Dictionary = Rules.combat_enemy_summary(roster)
	# Assert
	assert_eq(int(summary["count"]), 2, "数量应为阵容长度")
	assert_eq(int(summary["realm"]), 1, "境界应取阵营最高境界")
	assert_eq((summary["names"] as Array)[0], "青云剑宗外门弟子", "名称取自载荷")


func test_combat_summary_tolerates_empty_roster() -> void:
	var summary: Dictionary = Rules.combat_enemy_summary([])
	assert_eq(int(summary["count"]), 0, "空阵容数量为 0")
	assert_eq(int(summary["realm"]), 0, "空阵容境界为 0（不臆造）")
	assert_eq((summary["names"] as Array).size(), 0, "空阵容无名称")


func test_combat_lines_include_name_count_and_realm() -> void:
	# Arrange
	var roster: Array = [{"name": "竹林剑客", "realm": 2}]
	# Act
	var lines: Array = Rules.combat_lines(roster, 3)
	# Assert
	assert_true(str(lines[0]).contains("竹林剑客"), "首行应含敌人名称")
	assert_true(str(lines[0]).contains("×1"), "首行应含数量")
	assert_true(str(lines[1]).contains("筑基期"), "次行应为境界名")
	assert_true(str(lines[2]).contains("推荐上场角色"), "末行应为推荐战力提示")


func test_combat_lines_without_realm_omits_realm_line() -> void:
	# 境界未知（0）时不臆造境界行
	var lines: Array = Rules.combat_lines([{"name": "无名", "realm": 0}], 2)
	assert_eq(lines.size(), 2, "无境界时仅敌人行 + 推荐行")
	assert_false(str(lines[0]).contains("期"), "不应出现空境界名")


func test_combat_lines_show_unknown_for_nameless_roster() -> void:
	var lines: Array = Rules.combat_lines([{}, {}], 2)
	assert_true(str(lines[0]).contains("未知"), "无名称时应显示未知而非空白")
	assert_true(str(lines[0]).contains("×2"), "无名称时数量仍应正确")


# ═══════════════════════════════════════════════════════════════════════════════
# 推荐上场角色数（B3 裁决：角色数版本，配置优先）
# ═══════════════════════════════════════════════════════════════════════════════

func test_recommended_deploy_prefers_config_override() -> void:
	assert_eq(Rules.recommended_deploy(1, 6, 4), 4, "配置值优先于推定")


func test_recommended_deploy_clamps_to_max_deploy() -> void:
	assert_eq(Rules.recommended_deploy(3, 2), 2, "推荐数不得超过上场上限")
	assert_eq(Rules.recommended_deploy(9, 2, 9), 2, "配置值同样受上限夹取")


func test_recommended_deploy_is_at_least_one() -> void:
	assert_eq(Rules.recommended_deploy(0, 6), 1, "无敌人也至少推荐 1 人")
	assert_eq(Rules.recommended_deploy(1, 0), 1, "上限未初始化时退化为 1（不出现 ≥0）")


func test_realm_name_maps_all_five_realms() -> void:
	assert_eq(Rules.realm_name(1), "炼气期")
	assert_eq(Rules.realm_name(5), "化神期")
	assert_eq(Rules.realm_name(9), "", "未知境界返回空串而非臆造")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：渡劫台 80% 警示（渡劫专属，不与 Boss 50% 混用）
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_warning_states_eighty_percent() -> void:
	var lines: Array = Rules.tribulation_warning_lines()
	assert_eq(lines.size(), 2, "警示行应为警示 + 对照注两行")
	assert_true(str(lines[0]).contains("80%"), "警示必须写明 80% 修为损失")
	assert_false(str(lines[0]).contains("50%"), "警示行不得混入 Boss 的 50%")


func test_tribulation_warning_is_cinnabar_red() -> void:
	# 朱砂红 #B3424A（lingshi_deck_bar.COLOR_OVERLIMIT 同源）
	assert_eq(Rules.COLOR_DANGER.to_html(false).to_upper(), "B3424A",
			"渡劫警示必须用朱砂红 #B3424A")


func test_tribulation_ready_defaults_true_when_field_absent() -> void:
	assert_true(Rules.tribulation_ready({}), "字段缺失时宽松视为圆满（不误拦）")
	assert_true(Rules.tribulation_ready({"tribulation_ready": true}), "显式 true → 可挑战")
	assert_false(Rules.tribulation_ready({"tribulation_ready": false}),
			"显式 false → 无弹窗（AC-7）")


func test_tribulation_body_mentions_full_cultivation() -> void:
	var body: Array = Rules.body_lines(Rules.KIND_TRIBULATION)
	assert_true(str(body[1]).contains("修为已满"), "渡劫弹窗应说明修为已满")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4/AC-5：回复量校验（UI 不自行应用——仅交叉校验系统返回值）
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_restore_all_equals_missing_points() -> void:
	assert_eq(Rules.spring_restore_all(0, 7), 7, "空行动力 → 回复全部 7 点")
	assert_eq(Rules.spring_restore_all(3, 7), 4, "3/7 → 回复 4 点")
	assert_eq(Rules.spring_restore_all(7, 7), 0, "已满 → 回复 0 点")
	assert_eq(Rules.spring_restore_all(9, 7), 0, "越界输入不产生负回复")


func test_rest_heal_amount_is_half_lost_hp_floored() -> void:
	# GDD 公式 7：floor(lost_hp_total × 0.5)
	assert_eq(Rules.rest_heal_amount(10), 5, "损失 10 → 回复 5")
	assert_eq(Rules.rest_heal_amount(9), 4, "损失 9 → floor(4.5) = 4")
	assert_eq(Rules.rest_heal_amount(1), 0, "损失 1 → floor(0.5) = 0")
	assert_eq(Rules.rest_heal_amount(0), 0, "无损失 → 0")
	assert_eq(Rules.rest_heal_amount(-5), 0, "负值输入不产生治疗")


func test_rest_body_matches_formula_wording() -> void:
	var body: Array = Rules.body_lines(Rules.KIND_REST)
	assert_eq(str(body[0]), "全队回复50%已损失HP", "文案必须与公式 7（B1 修正）一致")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-11（视觉通道的几何部分）：弹窗在节点附近、不覆盖全屏
# ═══════════════════════════════════════════════════════════════════════════════

func test_popup_position_offsets_from_node_center() -> void:
	var host := Vector2(1920, 1080)
	var pos: Vector2 = Rules.popup_position(Vector2(800, 500), Rules.POPUP_SIZE, host)
	assert_true(pos.x > 800.0, "弹窗应在节点右侧（不盖住节点）")
	assert_true(pos.y > 500.0, "弹窗应在节点下方")
	assert_true(pos.x + Rules.POPUP_SIZE.x <= host.x, "右边界不得越出视口")


func test_popup_position_flips_left_near_right_edge() -> void:
	var host := Vector2(1920, 1080)
	var anchor := Vector2(1880, 200)
	var pos: Vector2 = Rules.popup_position(anchor, Rules.POPUP_SIZE, host)
	assert_true(pos.x < anchor.x, "右边缘节点应把弹窗翻到左侧")
	assert_true(pos.x >= Rules.EDGE_MARGIN, "翻转后仍须留边距")


func test_popup_position_clamps_inside_small_host() -> void:
	# 弹窗比宿主大时不出现负坐标（夹到边距）
	var pos: Vector2 = Rules.popup_position(Vector2(10, 10), Vector2(2000, 2000),
			Vector2(800, 600))
	assert_eq(pos, Vector2(Rules.EDGE_MARGIN, Rules.EDGE_MARGIN),
			"超大弹窗应夹到左上边距")


func test_popup_is_smaller_than_viewport_baseline() -> void:
	# GDD §4「弹窗不会覆盖整个屏幕」——360×220 在 1920×1080 基准下为小型面板
	assert_true(Rules.POPUP_SIZE.x <= 1920.0 * 0.5, "弹窗宽度不超过半屏")
	assert_true(Rules.POPUP_SIZE.y <= 1080.0 * 0.5, "弹窗高度不超过半屏")
