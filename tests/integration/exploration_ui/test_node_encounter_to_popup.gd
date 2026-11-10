extends GutTest
## 探索节点遭遇 → 弹窗正文 → 开战上下文：同一条数据链。[br]
## [br][b]本文件补的断链[/b]：此前弹窗只读到达名册、开战上下文只读节点
## [code]encounter[/code] 子字典——两边各推一套等级/数量，名册为空时弹窗显示
## 「×0」而上下文用的是模板数。本文件用 [b]生成器真实产出[/b] 的节点详情
## 驱动弹窗，断言正文与上下文读的是同一份遭遇数据。[br]
## [br][b]覆盖[/b]：[br]
##   1. 生成器写出的节点 → 弹窗正文（名称/数量/境界）；[br]
##   2. 点确认 → 跨场景上下文（模板 ID/等级/掉落）与节点定档一致；[br]
##   3. 名册缺失时正文数量退化为模板数（不显示 ×0）。[br]
##
## 来源: exploration-system.md §3 步骤⑥、GDD exploration-ui-system.md §4、
## 本轮「探索侧节点遭遇数据来源补齐」任务。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const HostScript := preload("res://src/ui/exploration/node_interaction_popup_host.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
const Fields := preload("res://assets/enemies/encounter_fields.gd")
const EnemyTemplateScript := preload("res://assets/enemies/enemy_template.gd")
const RewardConfigScript := preload("res://assets/enemies/reward_config.gd")

## 玩家出战阵容（测试注入——避开 GSM 角色位）。
const PLAYER_ROSTER: Array = [3, 5]

var es: Node = null
var host: Control = null
var viewport: Control = null
var renderer: Control = null
var _combat_entries: Array = []


func before_each() -> void:
	ContextScript.clear()
	_combat_entries.clear()
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	es.set("get_map_config_cb", Callable(func(_mid, _r):
		return (es.get("DIFFICULTY_CONFIGS") as Array)[1].duplicate(true)))
	es.set("get_event_pool_cb", Callable(func(_mid, _r): return []))
	es.set("generate_shop_inventory_cb", Callable(func(_r): return {}))
	_build_host()


func after_each() -> void:
	ContextScript.clear()
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 生成器节点 → 弹窗正文
# ═══════════════════════════════════════════════════════════════════════════════

func test_generated_encounter_drives_popup_body() -> void:
	# Arrange——生成器产出战斗节点（名册两名散修、境界 2）
	var detail: Dictionary = _generate_combat_detail([
		{"template_id": "san_xiu", "name": "散修", "realm": 2},
		{"template_id": "san_xiu", "name": "散修", "realm": 2},
	], 2)
	var node_id: int = _node_id_of(detail)
	_inject_snapshot(node_id, detail)
	# Act
	host.call(&"on_combat_arrival", detail.get("enemy_roster", []), &"combat")
	var body: String = _body_text()
	# Assert
	assert_true(body.contains("散修"), "正文名称取节点遭遇")
	assert_true(body.contains("×2"), "正文数量取节点名册")
	assert_true(body.contains("筑基期"), "正文境界取节点定档（2 = 筑基）")
	assert_true(body.contains("推荐上场角色"), "正文仍带推荐上场提示")


func test_popup_count_falls_back_to_templates_when_roster_empty() -> void:
	# Arrange——节点声明了两个模板，但到达信号的名册丢了（空数组）
	var detail: Dictionary = {
		"type": 1,
		"description": "山道巡守",
		"enemy_roster": [],
		"enemy_level": 1,
		"rewards": {},
		"encounter": {
			"encounter_id": "shandao",
			"display_name": "山道巡守",
			"enemy_template_ids": ["san_xiu", "san_xiu"],
			"enemy_level": 1,
			"rewards": {},
		},
	}
	_inject_snapshot(101, detail)
	# Act——到达信号带空名册
	host.call(&"on_combat_arrival", [], &"combat")
	var body: String = _body_text()
	# Assert——数量退化为模板数（不是 ×0）
	assert_true(body.contains("×2"), "名册为空时数量取模板数")
	assert_false(body.contains("×0"), "不得显示 ×0")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 弹窗确认 → 开战上下文与节点定档一致
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_publishes_context_matching_node_encounter() -> void:
	# Arrange——模板带 reward_config（掉落聚合输入）
	var template: Resource = _template("san_xiu", 1, 4, 8, 2)
	es.set("enemy_template_lookup_cb", Callable(func(tid: StringName) -> Variant:
		return template if tid == &"san_xiu" else null))
	var detail: Dictionary = _generate_combat_detail(
			[{"template_id": "san_xiu", "name": "散修", "realm": 1}], 1)
	var node_id: int = _node_id_of(detail)
	_inject_snapshot(node_id, detail)
	host.call(&"on_combat_arrival", detail.get("enemy_roster", []), &"combat")
	# Act——真实按钮路径确认
	_confirm_button().pressed.emit()
	var context: Dictionary = ContextScript.peek()
	# Assert——上下文四份输入与节点详情逐项一致
	assert_eq(context.get(ContextScript.KEY_TEMPLATE_IDS),
			[&"san_xiu"], "模板 ID 取节点遭遇")
	assert_eq(int(context.get(ContextScript.KEY_ENEMY_LEVEL, 0)),
			int(detail.get("enemy_level", -1)), "等级取节点顶层字段")
	assert_eq(int((context.get(ContextScript.KEY_REWARDS, {}) as Dictionary)
			.get("lingshi", 0)), 6, "掉落取节点聚合值（区间中值）")
	assert_eq(context.get(ContextScript.KEY_PLAYER_ROSTER), PLAYER_ROSTER,
			"玩家阵容来自注入提供者")
	assert_eq(ContextScript.validate(context), "", "上下文应可直接开战")
	assert_eq(_combat_entries.size(), 1, "应发一次战斗进入意图")


func test_handwritten_node_derives_level_and_rewards_from_templates() -> void:
	# Arrange——手写节点：无 encounter 子字典、名册只给模板 ID
	# （真实 AISystem 已加载 san_xiu.tres——等级与掉落走模板派生）
	var detail: Dictionary = {"type": 1, "description": "旧数据节点",
			"enemy_roster": [{"template_id": "san_xiu", "name": "散修"}]}
	_inject_snapshot(301, detail)
	host.call(&"on_combat_arrival", detail["enemy_roster"], &"combat")
	# Act
	_confirm_button().pressed.emit()
	var context: Dictionary = ContextScript.peek()
	var rewards: Dictionary = context.get(ContextScript.KEY_REWARDS, {})
	# Assert——手写节点无 encounter 子字典：等级由模板 realm 派生、掉落由
	# reward_config 聚合（不再恒为空）
	assert_eq(int(context.get(ContextScript.KEY_ENEMY_LEVEL, 0)), 1,
			"等级由模板 realm 派生")
	assert_true(int(rewards.get("lingshi", 0)) > 0,
			"掉落由模板 reward_config 聚合（san_xiu 已配最小掉落）")
	assert_eq(str(context.get(ContextScript.KEY_DISPLAY_NAME, "")), "旧数据节点",
			"展示名回退节点描述")


func test_shipped_templates_have_usable_reward_configs() -> void:
	# 任务要求：两个出厂模板都要有最小可用掉落，聚合不得恒为空
	for path: String in ["res://assets/enemies/san_xiu.tres",
			"res://assets/enemies/mo_xiu.tres"]:
		var template: Resource = load(path)
		assert_not_null(template, "%s 应可加载" % path)
		var config: Variant = template.get("reward_config")
		assert_not_null(config, "%s 应配置 reward_config" % path)
		assert_true(int(config.get("ling_shi_max")) >= int(config.get("ling_shi_min")),
				"%s 灵石区间应自洽" % path)
		assert_true(int(config.get("ling_shi_max")) > 0,
				"%s 灵石上限应大于 0（否则聚合恒空）" % path)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 用注入的名册生成地图，返回第一个战斗节点详情（附带节点 ID）。
func _generate_combat_detail(p_roster: Array, p_player_realm: int) -> Dictionary:
	es.set("generate_enemy_roster_cb",
			Callable(func(_mid, _r, _is_elite): return p_roster.duplicate(true)))
	var result: Dictionary = es.call("generate_map", &"popup_chain_map",
			p_player_realm, 1)
	var nodes: Dictionary = result.get("nodes", {})
	for node_id: int in nodes.keys():
		var ntype: int = int((nodes[node_id] as Dictionary).get("type", -1))
		if ntype == 1 or ntype == 2:
			var detail: Dictionary = (nodes[node_id] as Dictionary).duplicate(true)
			detail["_test_node_id"] = node_id
			return detail
	return {}


## 详情里携带的节点 ID（测试辅助键，不参与生产读取）。
func _node_id_of(p_detail: Dictionary) -> int:
	return int(p_detail.get("_test_node_id", 101))


## 注入渲染快照（屏幕层 map_generated 的同构载荷）。
func _inject_snapshot(p_node_id: int, p_detail: Dictionary) -> void:
	host.call(&"apply_snapshot", {
		"nodes": {p_node_id: p_detail},
		"current_node": p_node_id,
		"realm_id": 1,
	})


## 宿主 + 视口/渲染器桩（与 test_node_interaction_popups 同构的依赖面）。
func _build_host() -> void:
	viewport = Control.new()
	viewport.name = "ViewportStub"
	viewport.set_script(_stub_script("""
extends Control
var input_frozen: bool = false
var zoom: float = 1.0
var offset: Vector2 = Vector2.ZERO
"""))
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport.size = Vector2(1920, 1080)
	add_child_autofree(viewport)
	renderer = Control.new()
	renderer.name = "RendererStub"
	renderer.mouse_filter = Control.MOUSE_FILTER_STOP
	renderer.set_script(_stub_script("""
extends Control
func get_node_position(node_id: int) -> Vector2:
	return Vector2(100.0 + float(node_id % 100) * 60.0, 120.0 + float(node_id / 100) * 70.0)
"""))
	viewport.add_child(renderer)
	host = HostScript.new()
	host.name = "NodeInteractionPopupHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(host)
	host.size = Vector2(1920, 1080)
	host.call(&"setup", renderer, viewport, es)
	host.set("player_roster_provider",
			Callable(func() -> Array: return PLAYER_ROSTER.duplicate()))
	host.set(&"reduce_motion", true)
	host.connect(&"combat_entry_requested",
			func(ctype: StringName) -> void: _combat_entries.append(ctype))


func _stub_script(p_source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = p_source
	script.reload()
	return script


func _body_text() -> String:
	var body: Label = host.get_node_or_null(
			NodePath("NodeInteractionPopup/Body")) as Label
	return body.text if body != null else ""


func _confirm_button() -> Button:
	return host.get_node_or_null(
			NodePath("NodeInteractionPopup/ConfirmButton")) as Button


## 造一个带 reward_config 的模板（掉落聚合输入）。
func _template(p_id: String, p_realm: int, p_lo: int, p_hi: int,
		p_cultivation: int) -> Resource:
	var template: Resource = EnemyTemplateScript.new()
	template.template_id = StringName(p_id)
	template.display_name = p_id
	template.realm = p_realm
	var reward: Resource = RewardConfigScript.new()
	reward.ling_shi_min = p_lo
	reward.ling_shi_max = p_hi
	reward.cultivation_reward = p_cultivation
	template.reward_config = reward
	return template
