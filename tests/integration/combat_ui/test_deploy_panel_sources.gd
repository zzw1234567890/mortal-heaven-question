extends GutTest
## combat-ui-layout Story 007 集成测试：备战面板的生产取数装配（AC-1）。
##
## 覆盖 QL-TEST-COVERAGE 缺口 2/3/6/7/8：
## - `setup()` 的 `character_unavailable` / `character_revived` 订阅与 `visible` 门控
## - `load_roster()` / `refresh_roster()` 的成功路径（此前全用 `apply_roster` 绕开）
## - 替换弹窗的「打开」环节、默认被替换者、非已选 ID 回落
## - `_on_replace_confirmed` 的守卫与回退分支
## - 悬停协同的自身排除与多人并集聚合
##
## 桩依赖见 `mocks/mock_deploy_sources.gd`（不发真实系统信号之外的行为）。

const PanelScript := preload("res://src/ui/combat/deploy/deploy_panel.gd")
const Rules := preload("res://src/ui/combat/shared/deploy_panel_rules.gd")
const MockSources := preload("res://tests/integration/combat_ui/mocks/mock_deploy_sources.gd")
const RosterReader := preload("res://src/ui/combat/deploy/deploy_roster_reader.gd")
const DeploymentSystemScript := preload("res://src/feature/deployment_system.gd")

var panel: Control = null
var sources: Node = null


func before_each() -> void:
	panel = PanelScript.new()
	add_child_autofree(panel)
	sources = MockSources.new()
	add_child_autofree(sources)


## 六角色模板（101 林渊 / 102 苏剑鸣 / 103 陆青 / 104 白芷 / 105 韩霜 / 106 沈墨）。
func _six_templates() -> Dictionary:
	return {
		101: {"name": "林渊", "base_hp": 8, "base_attack": 3,
				"faction_tags": [&"qing_yun", &"sword"]},
		102: {"name": "苏剑鸣", "base_hp": 9, "base_attack": 4,
				"faction_tags": [&"qing_yun"]},
		103: {"name": "陆青", "base_hp": 7, "base_attack": 5,
				"faction_tags": [&"fire"]},
		104: {"name": "白芷", "base_hp": 6, "base_attack": 2,
				"faction_tags": [&"fire", &"alchemy"]},
		105: {"name": "韩霜", "base_hp": 8, "base_attack": 4,
				"faction_tags": [&"sword"]},
		106: {"name": "沈墨", "base_hp": 9, "base_attack": 3,
				"faction_tags": [&"water"]},
	}


func _seed_six() -> void:
	sources.seed([101, 102, 103, 104, 105, 106], _six_templates())


# ═══════════════════════════════════════════════════════════════════════════════
# setup() 信号订阅（审查 M10 的修复此前「改了但没测」）
# ═══════════════════════════════════════════════════════════════════════════════

func test_setup_subscribes_and_republishes_roster_on_unavailable() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.visible = true
	var before_ids: Array = panel.get_cards().map(
			func(c: Control) -> int: return c.get_character_id())
	assert_eq(before_ids.size(), 6, "前置条件：6 张卡")
	# Act: 103 阵亡（发真实 character_unavailable 信号）
	sources.mark_unavailable_for_test(103)
	# Assert: 面板自行刷新名册，103 变不可用态
	assert_eq(panel.get_selection_state(103), Rules.STATE_UNAVAILABLE,
			"阵亡信号应触发面板自行刷新名册")


func test_setup_ignores_dirty_signal_when_hidden() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.visible = false
	# Act
	sources.mark_unavailable_for_test(103)
	# Assert: 隐藏时不刷新（避免无谓重建卡）
	assert_eq(panel.get_selection_state(103), Rules.STATE_SELECTABLE,
			"面板隐藏时阵亡信号不应触发刷新")


func test_setup_twice_connects_only_once() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.visible = true
	sources.template_query_count = 0
	var before_count: int = panel.get_cards().size()
	# Act: 一次信号只应刷新一次（若重复连接会读两遍名册）
	sources.mark_unavailable_for_test(103)
	# Assert: 6 个有效角色位 → 单次刷新恰好 6 次模板查询
	assert_eq(sources.template_query_count, 6,
			"重复 setup 不应造成重复订阅（单次刷新只取数一遍）")
	assert_eq(panel.get_cards().size(), before_count, "卡片数不变")


func test_revived_character_becomes_selectable_again() -> void:
	# Arrange: 103 先阵亡再复活
	_seed_six()
	sources.unavailable = [103]
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.visible = true
	assert_eq(panel.get_selection_state(103), Rules.STATE_UNAVAILABLE,
			"前置条件：103 应为不可用")
	# Act
	sources.revive_for_test(103)
	# Assert
	assert_eq(panel.get_selection_state(103), Rules.STATE_SELECTABLE,
			"复活信号应使角色恢复可选中")


# ═══════════════════════════════════════════════════════════════════════════════
# load_roster() / refresh_roster() 成功路径
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_roster_reads_production_chain_once() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	# Act
	var count: int = panel.load_roster(2, 1)
	# Assert: 6 个有效角色位 → 6 张卡，且每角色位只查一次模板
	assert_eq(count, 6, "读取到 6 个角色")
	assert_eq(panel.get_cards().size(), 6, "应创建 6 张卡")
	assert_eq(sources.template_query_count, 6,
			"单次取数：每个有效角色位恰好查询一次模板（审查 H2）")


func test_load_roster_names_and_stats_come_from_templates() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	# Act
	panel.load_roster(2, 1)
	var card: Control = panel.get_cards()[0]
	# Assert: 端到端字段链路（GSM → 模板 → 卡片）
	assert_eq(card.get_display_name(), "林渊", "显示名来自模板")
	assert_eq(int(card.data.get("hp", 0)), 8, "HP 来自 base_hp")
	assert_eq(int(card.data.get("attack", 0)), 3, "ATK 来自 base_attack")


func test_load_roster_marks_dead_from_deployment_system() -> void:
	# Arrange
	_seed_six()
	sources.unavailable = [102]
	panel.setup(sources, sources, sources, sources)
	# Act
	panel.load_roster(3, 2)
	# Assert
	assert_eq(panel.get_selection_state(102), Rules.STATE_UNAVAILABLE,
			"部署系统不可用列表中的角色应为不可用态")
	assert_eq(panel.get_selection_state(101), Rules.STATE_SELECTABLE,
			"其余角色应可选中")


func test_refresh_roster_keeps_current_limit_and_realm() -> void:
	# Arrange: 按化神（上限 6）装配
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(6, 5)
	# Act: 直接刷新（不传上限）
	var count: int = panel.refresh_roster()
	# Assert: 复用当前设定，不被重置为 0
	assert_eq(count, 6, "刷新应读到 6 人")
	assert_eq(panel.max_deploy, 6, "刷新不应改写上限")
	assert_eq(panel.realm_id, 5, "刷新不应改写境界")


func test_refresh_roster_without_sources_returns_zero_without_crash() -> void:
	# Arrange: 未注入依赖
	# Act
	var count: int = panel.refresh_roster()
	# Assert
	assert_eq(count, 0, "依赖缺失时刷新应返回 0 而不崩溃")
	assert_eq(panel.get_cards().size(), 0, "无依赖时应为空名册")


# ═══════════════════════════════════════════════════════════════════════════════
# 替换弹窗「打开」环节（H5 默认值与文案此前未被断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_full_selection_toggle_opens_replace_dialog_and_rejects_selection() -> void:
	# Arrange: 炼气上限 2，已选满 101/102
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.toggle_selection(101)
	panel.toggle_selection(102)
	# Act: 名额满后点第三个角色
	var changed: bool = panel.toggle_selection(103)
	# Assert: 不静默选中，转入替换流程
	assert_false(changed, "满员点选不应直接改变已选")
	assert_eq(panel.get_selected_ids(), [101, 102], "已选阵容应保持不变")
	assert_eq(panel.get_pending_replace_id(), 103, "应进入 103 的替换待确认")


func test_replace_dialog_text_uses_gdd_wording() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.toggle_selection(101)
	panel.toggle_selection(102)
	# Act
	panel.request_replace(104)
	# Assert（GDD §8 文案「用[角色名]替换[已选角色名]？」）
	assert_eq(panel.replace_dialog.dialog_text, "用白芷替换林渊？",
			"替换弹窗文案应按 GDD 措辞填充")


func test_request_replace_without_target_defaults_to_first_selected() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.toggle_selection(101)
	panel.toggle_selection(103)
	# Act
	panel.request_replace(105)
	# Assert: 省略被替换者 → 取首位已选（101 林渊）
	assert_eq(panel.replace_dialog.dialog_text, "用韩霜替换林渊？",
			"省略被替换者时应默认首位已选")


func test_request_replace_with_unknown_target_falls_back_to_first() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.toggle_selection(101)
	panel.toggle_selection(103)
	# Act: 传入不在已选中的 ID
	panel.request_replace(105, 999)
	# Assert
	assert_eq(panel.replace_dialog.dialog_text, "用韩霜替换林渊？",
			"非已选 ID 应回落到首位已选")


func test_replace_confirmed_without_pending_is_noop() -> void:
	# Arrange: 未发起替换
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.toggle_selection(101)
	var before: Array = panel.get_selected_ids()
	watch_signals(panel)
	# Act
	panel._on_replace_confirmed()
	# Assert: 无待确认时不应发信号、不应改阵容
	assert_signal_not_emitted(panel, "replace_requested",
			"无待确认替换时不应发射 replace_requested")
	assert_eq(panel.get_selected_ids(), before, "无待确认时阵容不应改变")


func test_replace_confirmed_reports_actual_replaced_id() -> void:
	# Arrange: 指定 102 替换，随后 102 阵亡并被自动剔除
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(2, 1)
	panel.toggle_selection(101)
	panel.toggle_selection(102)
	panel.request_replace(104, 102)
	sources.mark_unavailable_for_test(102)
	watch_signals(panel)
	# Act: 待替换目标已不在已选中 → 回落到首位
	panel._on_replace_confirmed()
	# Assert: 载荷第二参数应是真实被替换者（101）而非失效的 102
	var params: Array = get_signal_parameters(panel, "replace_requested")
	assert_eq(params[0], 104, "新角色 ID 应为 104")
	assert_eq(params[1], 101, "被替换者应为实际替换的 101（回退分支）")


# ═══════════════════════════════════════════════════════════════════════════════
# 悬停协同：自身排除与多人并集
# ═══════════════════════════════════════════════════════════════════════════════

func test_hover_on_selected_self_shows_no_synergy() -> void:
	# Arrange
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(3, 2)
	panel.toggle_selection(101)
	var card: Control = panel.get_cards()[0]
	# Act: 悬停自己（已选）
	card.mouse_entered.emit()
	# Assert: 自身不参与协同计算
	assert_true(panel.tooltip_label.text.contains("暂无协同"),
			"悬停已选角色自身时应显示暂无协同")


func test_hover_unions_shared_tags_across_multiple_selected() -> void:
	# Arrange: 已选 102(qing_yun) + 103(fire) + 105(sword)，悬停 101(qing_yun,sword)
	_seed_six()
	panel.setup(sources, sources, sources, sources)
	panel.load_roster(4, 2)
	panel.toggle_selection(102)
	panel.toggle_selection(103)
	panel.toggle_selection(105)
	var card: Control = panel.get_cards()[0]
	# Act
	card.mouse_entered.emit()
	# Assert: 与多人的并集标签都出现
	assert_true(panel.tooltip_label.visible, "应显示协同信息")
	assert_true(panel.tooltip_label.text.contains("qing_yun"), "应含来自 102 的共用标签")
	assert_true(panel.tooltip_label.text.contains("sword"), "应含来自 105 的共用标签")
	assert_false(panel.tooltip_label.text.contains("fire"), "103 的无交集标签不应出现")


# ═══════════════════════════════════════════════════════════════════════════════
# 跨系统 ID 域契约（QL-TEST-COVERAGE 缺口 4）
#
# 读取器把 deck.slots 里的 card_instance_id 同时用于 DeploymentSystem 的阵亡
# 查询键与 BindingManager 的绑定查询键。若两套 ID 域不一致，阵亡判定会静默
# 恒 false（不报错）。本节用**真实 DeploymentSystem** 做契约式验证——任何一侧
# 改 ID 域时此处立即变红。
# ═══════════════════════════════════════════════════════════════════════════════

func test_deployment_mark_unavailable_marks_reader_snapshot_dead() -> void:
	# Arrange: 真实部署系统 + 桩取数链
	var ds: Node = DeploymentSystemScript.new()
	add_child_autofree(ds)
	_seed_six()
	# Act: 用读取器输出的 ID 去标记阵亡，再重读名册
	var before: Array = RosterReader.read(sources, sources, ds, sources)
	assert_false(bool(before[0]["is_dead"]), "前置条件：101 初始存活")
	ds.mark_unavailable(101, {"death_turn": 1})
	var after: Array = RosterReader.read(sources, sources, ds, sources)
	# Assert: 同一数值 ID 在两套系统间语义一致
	assert_true(bool(after[0]["is_dead"]),
			"DeploymentSystem.mark_unavailable 的键应与 deck.slots 的 ID 同域")


func test_deployment_revive_clears_reader_dead_flag() -> void:
	# Arrange
	var ds: Node = DeploymentSystemScript.new()
	add_child_autofree(ds)
	_seed_six()
	ds.mark_unavailable(102, {"death_turn": 1})
	var mid: Array = RosterReader.read(sources, sources, ds, sources)
	assert_true(bool(mid[1]["is_dead"]), "前置条件：102 已标记阵亡")
	# Act
	ds.revive_character(102)
	var after: Array = RosterReader.read(sources, sources, ds, sources)
	# Assert: 复活后读取器不再判阵亡
	assert_false(bool(after[1]["is_dead"]), "复活后读取器应恢复 is_dead=false")
