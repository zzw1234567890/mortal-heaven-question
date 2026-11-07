extends GutTest
## combat-ui-layout Story 007 集成测试：备战面板在战斗场景中的宿主接线（AC-1）。
##
## 覆盖审查 H6：`CombatLayout` 对 `deploy_panel` 的实例化 / 锚点 / 默认隐藏 /
## show/hide 入口此前零断言——补宿主层回归，防止「双次全量重建」类缺陷复现。
##
## Story 类型 UI（Logic 内核）——Logic 内核 BLOCKING 证据见
## test_deploy_selection_state / test_formation_slot_layout；本文件为宿主接线证据。
##
## 访问方式：`CombatRoot.tscn.instantiate()` 的静态类型为 Control，脚本成员
## 经 [method Node.get_node] 取面板 + 按 `class_name DeployPanel` 静态类型化访问。

const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")
const Rules := preload("res://src/ui/combat/shared/deploy_panel_rules.gd")

var combat_root: Control = null
var panel: DeployPanel = null


func before_each() -> void:
	combat_root = CombatRootScene.instantiate()
	add_child_autofree(combat_root)
	panel = combat_root.get_node_or_null(NodePath("DeployPanel")) as DeployPanel


func _make_roster() -> Array:
	var roster: Array = []
	for i: int in range(4):
		roster.append({
			"character_id": 200 + i,
			"display_name": "角色%d" % (i + 1),
			"hp": 8 + i, "attack": 3, "binding_count": 0,
			"faction_tags": [], "is_dead": false, "slot_index": i,
		})
	return roster


func test_combat_root_has_hidden_deploy_panel() -> void:
	# Assert: 面板挂在战斗根上且默认隐藏（备战前不应遮挡战场）
	assert_not_null(panel, "战斗根应装配备战面板 DeployPanel")
	assert_false(panel.visible, "备战面板默认应隐藏")


func test_deploy_panel_is_fullscreen_overlay() -> void:
	# Assert: 全屏覆盖层（anchor 0-1），仅左/上留内边距
	assert_almost_eq(panel.anchor_left, 0.0, 0.0001, "面板应左对齐")
	assert_almost_eq(panel.anchor_right, 1.0, 0.0001, "面板应全宽")
	assert_almost_eq(panel.anchor_bottom, 1.0, 0.0001, "面板应全高")


func test_show_deploy_panel_makes_visible_with_roster() -> void:
	# Arrange: 注入桩名册（依赖未注入——走直接下发路径）
	panel.apply_roster(_make_roster(), 2, 1)
	# Act
	combat_root.call("show_deploy_panel", 2, 1, "⚔ 测试战斗")
	# Assert: 可见 + 标题生效 + 上限生效（炼气 2）
	assert_true(panel.visible, "show 后应可见")
	assert_true(panel.title_label.text.contains("测试战斗"), "标题应生效")
	assert_eq(panel.max_deploy, 2, "上限应为 2")


func test_show_deploy_panel_does_not_duplicate_cards() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 2, 1)
	var before: int = panel.get_cards().size()
	# Act: 连续两次 show（单次取数下发，不应双重建卡）
	combat_root.call("show_deploy_panel", 2, 1, "A")
	combat_root.call("show_deploy_panel", 2, 1, "B")
	# Assert: 依赖未注入 → load_roster 读到空名册（卡片清零，不泄漏不重复）
	assert_eq(panel.get_cards().size(), 0, "无依赖时 show 应下发空名册")
	assert_eq(before, 4, "前置条件：桩名册应有 4 张卡")


func test_hide_deploy_panel_hides() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 2, 1)
	combat_root.call("show_deploy_panel", 2, 1, "测试")
	assert_true(panel.visible, "前置条件：show 后应可见")
	# Act
	combat_root.call("hide_deploy_panel")
	# Assert
	assert_false(panel.visible, "hide 后应不可见")


func test_show_without_sources_warns_and_keeps_skeleton() -> void:
	# Act: 依赖未注入（gsm/card_system 为空）
	combat_root.call("show_deploy_panel", 2, 1, "空名册")
	# Assert: 显式告警（不静默空面板）+ 骨架仍在
	assert_push_warning_count(1, "未注入依赖时应 push_warning 1 次（审查 H1）")
	assert_not_null(panel.confirm_button, "空名册骨架应仍具备按钮")


func test_panel_selection_updates_preview_in_scene() -> void:
	# Arrange
	panel.apply_roster(_make_roster(), 2, 1)
	panel.visible = true
	# Act
	panel.toggle_selection(200)
	# Assert: 炼气预览前排第一个已填 + 已选态落在卡片上
	assert_eq(panel.preview.get_row_names(0), ["角色1"], "选中后预览前排应填入角色名")
	assert_eq(panel.get_selection_state(200), Rules.STATE_SELECTED, "已选角色应为 selected")
	assert_eq(panel.get_selection_state(201), Rules.STATE_SELECTABLE,
			"其余角色应保持可选中态")
