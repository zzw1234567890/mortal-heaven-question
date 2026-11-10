extends GutTest
## 探索→战斗开战上下文单测（CombatLaunchContext / CombatSceneLaunch）。[br]
## [br][b]覆盖[/b]：[br]
##   - 节点详情显式配置优先（模板 ID / 等级 / 掉落 / 展示名）；[br]
##   - 无显式配置时从名册条目派生（模板 ID、境界、掉落聚合）；[br]
##   - 契约校验：缺上下文 / 缺敌方 / 缺玩家阵容各有可读失败；[br]
##   - 发布净化：StringName 转 String、运行时对象不进跨场景缓存；[br]
##   - 一次性消费 + 标题前缀 + 备战面板预选。
##
## 来源: exploration-system.md §3 步骤⑥、ADR-0014 §决策 3、本轮补链任务。

const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
const LaunchScript := preload("res://src/feature/combat/combat_scene_launch.gd")

## 备战面板桩——只实现预选用到的两个入口。
class DeployStub extends Node:
	var selected: Array = []
	var reject: Array = []

	func toggle_selection(character_id: int) -> bool:
		if reject.has(character_id) or selected.has(character_id):
			return false
		selected.append(character_id)
		return true

	func get_selected_ids() -> Array:
		return selected.duplicate()


func after_each() -> void:
	ContextScript.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# build：显式配置优先
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_prefers_node_encounter_config() -> void:
	# Arrange——节点详情自带 encounter（探索系统在节点生成时定档）
	var detail: Dictionary = {
		"description": "山道巡守",
		"encounter": {
			"encounter_id": "shandao",
			"display_name": "山道巡守",
			"enemy_template_ids": [&"san_xiu", &"san_xiu"],
			"enemy_level": 2,
			"rewards": {"lingshi": 10, "cultivation": 4, "cards": [{"card_id": "basic_attack"}]},
		},
	}
	# Act
	var context: Dictionary = ContextScript.build(101, &"combat", [], [3, 5],
			detail)
	# Assert
	assert_eq(int(context[ContextScript.KEY_NODE_ID]), 101, "节点 ID 透传")
	assert_eq(context[ContextScript.KEY_COMBAT_TYPE], &"combat", "战斗类型透传")
	assert_eq(context[ContextScript.KEY_TEMPLATE_IDS], [&"san_xiu", &"san_xiu"],
			"模板 ID 取显式配置")
	assert_eq(int(context[ContextScript.KEY_ENEMY_LEVEL]), 2, "敌方等级取显式配置")
	assert_eq(int(context[ContextScript.KEY_REWARDS]["lingshi"]), 10, "掉落取显式配置")
	assert_eq(int(context[ContextScript.KEY_REWARDS]["cultivation"]), 4, "修为掉落透传")
	assert_eq(context[ContextScript.KEY_PLAYER_ROSTER], [3, 5], "玩家阵容规范化（去重/去非正）")
	assert_eq(str(context[ContextScript.KEY_DISPLAY_NAME]), "山道巡守", "展示名取遭遇配置")


func test_build_derives_from_roster_entries_when_no_encounter() -> void:
	# Arrange——无 encounter 子字典，只有到达信号带来的预览名册
	var roster: Array = [
		{"template_id": "san_xiu", "realm": 2, "rewards": {"lingshi": 3}},
		{"template_id": "san_xiu", "realm": 3, "rewards": {"lingshi": 2, "cultivation": 1}},
	]
	# Act
	var context: Dictionary = ContextScript.build(202, &"elite", roster, [7], {})
	# Assert
	assert_eq(context[ContextScript.KEY_TEMPLATE_IDS], [&"san_xiu"], "模板 ID 从条目派生并去重")
	assert_eq(int(context[ContextScript.KEY_ENEMY_LEVEL]), 3, "等级取名册最高境界")
	assert_eq(int(context[ContextScript.KEY_REWARDS]["lingshi"]), 5, "灵石掉落按条目累加")
	assert_eq(int(context[ContextScript.KEY_REWARDS]["cultivation"]), 1, "修为掉落按条目累加")
	assert_eq(context[ContextScript.KEY_PLAYER_ROSTER], [7], "玩家阵容透传")


func test_build_falls_back_to_detail_description_for_title() -> void:
	var context: Dictionary = ContextScript.build(1, &"combat", [], [1],
			{"description": "竹林遭遇"})
	assert_eq(str(context[ContextScript.KEY_DISPLAY_NAME]), "竹林遭遇",
			"无遭遇配置时展示名回退节点描述")


# ═══════════════════════════════════════════════════════════════════════════════
# validate：可读失败
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_reports_missing_context() -> void:
	assert_string_contains(ContextScript.validate({}), "未收到探索侧开战上下文",
			"空上下文应给出明确原因")


func test_validate_reports_missing_enemy_and_player() -> void:
	var context: Dictionary = ContextScript.build(1, &"combat", [], [], {})
	var problem: String = ContextScript.validate(context)
	assert_string_contains(problem, "敌方阵容", "缺敌方阵容应报出")
	assert_string_contains(problem, "玩家出战阵容", "缺玩家阵容应报出")


func test_validate_passes_with_template_ids_and_player_roster() -> void:
	var context: Dictionary = ContextScript.build(1, &"combat", [], [9],
			{"encounter": {"enemy_template_ids": [&"san_xiu"]}})
	assert_eq(ContextScript.validate(context), "", "四份输入齐备时应通过")


# ═══════════════════════════════════════════════════════════════════════════════
# publish / take：净化与一次性消费
# ═══════════════════════════════════════════════════════════════════════════════

func test_publish_sanitizes_string_names_and_drops_objects() -> void:
	# Arrange——StringName 键值 + 运行时对象（都不能进 JSON 存档）
	var runtime_object: Node = Node.new()
	var context: Dictionary = {
		&"combat_type": &"elite",
		"enemy_roster": [runtime_object, {"template_id": &"san_xiu"}],
		"player_roster": [1, 2],
	}
	# Act
	ContextScript.publish(context)
	var taken: Dictionary = ContextScript.take()
	# Assert
	assert_true(taken.has("combat_type"), "StringName 键应转成 String 键")
	assert_eq(taken.get("combat_type"), &"elite", "StringName 值保留（模板 ID 契约同型）")
	assert_eq((taken.get("enemy_roster") as Array).size(), 1, "对象条目应被丢弃")
	assert_eq((taken.get("enemy_roster") as Array)[0].get("template_id"), &"san_xiu",
			"字典条目内的 StringName 保留")
	assert_eq(taken.get("player_roster"), [1, 2], "普通数组原样保留")
	runtime_object.free()


func test_take_is_one_shot() -> void:
	ContextScript.publish({"node_id": 1, "player_roster": [1]})
	assert_false(ContextScript.take().is_empty(), "首次取走应拿到上下文")
	assert_true(ContextScript.take().is_empty(), "二次取走应为空（一次性消费）")


# ═══════════════════════════════════════════════════════════════════════════════
# CombatSceneLaunch：读取面
# ═══════════════════════════════════════════════════════════════════════════════

func _launch(p_context: Dictionary) -> RefCounted:
	var launch: RefCounted = LaunchScript.new()
	launch.call(&"consume", p_context)
	return launch


func test_launch_consumes_override_and_exposes_fields() -> void:
	var launch: RefCounted = _launch({
		"display_name": "山道巡守",
		"enemy_template_ids": [&"san_xiu"],
		"enemy_level": 2,
		"rewards": {"lingshi": 8},
		"player_roster": [3, 4],
	})
	assert_true(bool(launch.call(&"is_valid")), "齐备的上下文应可用")
	assert_eq(str(launch.call(&"failure_text")), "", "无失败文案")
	assert_eq(str(launch.call(&"title", "⚔ 遭遇战")), "⚔ 山道巡守", "标题取遭遇展示名")
	assert_eq(launch.call(&"enemy_template_ids"), [&"san_xiu"], "模板 ID 透传")
	assert_eq(int(launch.call(&"enemy_level")), 2, "等级透传")
	assert_eq(int(launch.call(&"rewards")["lingshi"]), 8, "掉落透传")
	assert_eq(launch.call(&"player_roster"), [3, 4], "玩家阵容透传")


func test_launch_failure_text_is_readable() -> void:
	var launch: RefCounted = _launch({})
	assert_false(bool(launch.call(&"is_valid")), "空上下文不可开战")
	assert_string_contains(str(launch.call(&"failure_text")), "无法进入战斗：",
			"失败文案应带玩家可读前缀")
	assert_string_contains(str(launch.call(&"failure_text")), "未收到探索侧开战上下文",
			"失败文案应说明缺什么")


func test_launch_title_keeps_icon_and_falls_back() -> void:
	var titled: RefCounted = _launch({
		"display_name": "⚔ 已有图标", "enemy_template_ids": [&"san_xiu"],
		"player_roster": [1]})
	assert_eq(str(titled.call(&"title", "⚔ 遭遇战")), "⚔ 已有图标", "已带图标不重复加前缀")
	var empty: RefCounted = _launch({})
	assert_eq(str(empty.call(&"title", "⚔ 遭遇战")), "⚔ 遭遇战", "无名称时回退默认标题")


func test_launch_preselect_uses_public_panel_api() -> void:
	var deploy: DeployStub = DeployStub.new()
	add_child_autofree(deploy)
	deploy.reject = [4]
	var launch: RefCounted = _launch({
		"enemy_template_ids": [&"san_xiu"], "player_roster": [3, 4, 5]})
	# Act
	var picked: Array = launch.call(&"preselect", deploy)
	# Assert
	assert_eq(picked, [3, 5], "被面板拒绝的角色（阵亡/超上限）不计入")
	assert_eq(deploy.selected, [3, 5], "预选走 toggle_selection 公开入口")
