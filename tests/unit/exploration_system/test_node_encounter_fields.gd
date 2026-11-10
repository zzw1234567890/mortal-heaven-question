extends GutTest
## 探索节点遭遇字段补齐 —— 生成器产出 → 开战上下文直通。[br]
## [br][b]覆盖[/b]：[br]
##   - 生成器在战斗/精英节点写入 [code]encounter[/code] / [code]enemy_level[/code]
##     / [code]rewards[/code]（顶层与子字典同值）；[br]
##   - 生成器产出的节点详情能被 [code]CombatLaunchContext.build[/code] 直接接受，
##     且四份输入与节点定档一致（模板 ID / 等级 / 掉落）；[br]
##   - 掉落聚合走模板 [code]reward_config[/code]（灵石取区间中值）；[br]
##   - 名册缺失时字段仍可读，[code]validate[/code] 给出可读失败；[br]
##   - 缺省语义：无掉落 = [code]{}[/code]、未定等级 = 0，不用 null 混用；[br]
##   - 弹窗正文与开战上下文读同一份遭遇数据（数量/等级口径一致）。[br]
##
## 来源: exploration-system.md §3 步骤⑥（阵容在节点生成时确定）、
## ADR-0014 §决策 2/3、GDD ai-system.md §2 rewards。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
const Fields := preload("res://assets/enemies/encounter_fields.gd")
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
const EnemyTemplateScript := preload("res://assets/enemies/enemy_template.gd")
const RewardConfigScript := preload("res://assets/enemies/reward_config.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	ContextScript.clear()


func after_each() -> void:
	ContextScript.clear()
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 注入中难度配置（5 层，保证有中间层战斗节点）。
func _inject_config() -> void:
	var cfg: Dictionary = (es.get("DIFFICULTY_CONFIGS") as Array)[1]
	es.set("get_map_config_cb", Callable(func(_mid, _r): return cfg.duplicate(true)))


## 注入名册回调（预览字典形态——与 Explore 侧的 UI 预览同构）。
func _inject_roster(p_roster: Array) -> void:
	es.set("generate_enemy_roster_cb",
			Callable(func(_mid, _r, _is_elite): return p_roster.duplicate(true)))


## 注入最小可用的其它内容回调（事件/商店不影响本测试，但避免空实现噪声）。
func _inject_other_cbs() -> void:
	es.set("get_event_pool_cb", Callable(func(_mid, _r): return []))
	es.set("generate_shop_inventory_cb", Callable(func(_r): return {}))


## 造一个带 reward_config 的模板（掉落聚合的输入）。
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


## 生成一张图并返回第一个战斗类节点的详情（找不到返回空字典）。
func _first_combat_detail(p_result: Dictionary) -> Dictionary:
	var nodes: Dictionary = p_result.get("nodes", {})
	for node_id: int in nodes.keys():
		var ntype: int = int((nodes[node_id] as Dictionary).get("type", -1))
		if ntype == 1 or ntype == 2:  # COMBAT / ELITE
			return nodes[node_id]
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 生成器写入三字段（顶层 + encounter 子字典同值）
# ═══════════════════════════════════════════════════════════════════════════════

func test_generator_writes_encounter_level_and_rewards() -> void:
	# Arrange
	_inject_config()
	_inject_other_cbs()
	_inject_roster([
		{"template_id": "san_xiu", "name": "散修", "realm": 1},
		{"template_id": "san_xiu", "name": "散修", "realm": 1},
	])
	# Act
	var result: Dictionary = es.call("generate_map", &"enc_map", 2, 1)
	var detail: Dictionary = _first_combat_detail(result)
	# Assert——三字段齐备，且子字典/顶层同值
	assert_false(detail.is_empty(), "地图应至少产出一个战斗节点")
	assert_true(detail.has("encounter"), "节点详情应含 encounter 子字典")
	assert_eq(int(detail.get("enemy_level", -1)),
			int((detail["encounter"] as Dictionary).get("enemy_level", -2)),
			"顶层 enemy_level 与子字典同值")
	assert_eq((detail.get("rewards", {}) as Dictionary).keys(),
			(detail["encounter"] as Dictionary)["rewards"].keys(),
			"顶层 rewards 与子字典同值")
	assert_eq(detail["encounter"]["enemy_template_ids"], ["san_xiu"],
			"模板 ID 来自生成的名册")
	assert_eq(int(detail.get("enemy_level", -1)), 1,
			"名册自带境界优先（生成时的玩家境界只作兜底）")
	assert_eq(str(detail["encounter"]["display_name"]), "散修",
			"展示名取敌人名（不含数量——标题会再拼）")
	assert_eq(str(detail.get("label", "")), "散修 ×2", "节点标签带数量")
	assert_string_contains(str(detail["encounter"]["encounter_id"]), "enc_map_",
			"encounter_id 以地图 ID 为前缀（可追踪）")


func test_generator_falls_back_to_player_realm_when_roster_has_no_realm() -> void:
	# Arrange——名册条目不带境界（生成时只有模板 ID）
	_inject_config()
	_inject_other_cbs()
	_inject_roster([{"template_id": "san_xiu"}])
	# Act——玩家境界 3
	var detail: Dictionary = _first_combat_detail(
			es.call("generate_map", &"realm_fallback_map", 3, 1))
	# Assert——兜底到生成时的玩家境界（节点定档基准）
	assert_eq(int(detail.get("enemy_level", 0)), 3,
			"名册无境界时用生成时的玩家境界定档")


func test_generator_leaves_zero_rewards_as_empty_dictionary() -> void:
	# Arrange——名册条目没有 rewards，也没有模板查询 → 无掉落配置
	_inject_config()
	_inject_other_cbs()
	_inject_roster([{"template_id": "san_xiu", "realm": 1}])
	# Act
	var detail: Dictionary = _first_combat_detail(
			es.call("generate_map", &"no_reward_map", 1, 1))
	# Assert——缺省语义：{} 而不是 {lingshi: 0, ...}
	assert_eq(detail.get("rewards", null), {}, "未配置掉落应为空字典（非 0 掉落）")
	assert_eq((detail["encounter"] as Dictionary).get("rewards", null), {},
			"子字典同样为空字典")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 生成器产出 → 开战上下文直通
# ═══════════════════════════════════════════════════════════════════════════════

func test_generated_node_is_accepted_by_launch_context() -> void:
	# Arrange——模板带 reward_config（掉落聚合来源）
	_inject_config()
	_inject_other_cbs()
	_inject_roster([{"template_id": "san_xiu", "name": "散修", "realm": 1}])
	var template: Resource = _template("san_xiu", 1, 4, 8, 2)
	es.set("enemy_template_lookup_cb",
			Callable(func(tid: StringName) -> Variant:
				return template if tid == &"san_xiu" else null))
	var detail: Dictionary = _first_combat_detail(
			es.call("generate_map", &"launch_map", 1, 1))
	# Act——把生成器写出的节点直接喂给开战上下文
	var context: Dictionary = ContextScript.build(101, &"combat",
			detail.get("enemy_roster", []), [3, 5], detail)
	# Assert——四份输入都与节点定档一致
	assert_eq(ContextScript.validate(context), "", "生成器产出的节点应能直接开战")
	assert_eq(context[ContextScript.KEY_TEMPLATE_IDS], [&"san_xiu"],
			"模板 ID 直通")
	assert_eq(int(context[ContextScript.KEY_ENEMY_LEVEL]), 1, "等级取节点定档")
	assert_eq(int(context[ContextScript.KEY_REWARDS]["lingshi"]), 6,
			"灵石取 reward_config 区间中值 (4+8)/2")
	assert_eq(int(context[ContextScript.KEY_REWARDS]["cultivation"]), 2,
			"修为取模板配置")
	assert_eq(context[ContextScript.KEY_PLAYER_ROSTER], [3, 5], "玩家阵容透传")


func test_generated_encounter_id_and_title_are_stable() -> void:
	# Arrange
	_inject_config()
	_inject_other_cbs()
	_inject_roster([{"template_id": "mo_xiu", "name": "魔修", "realm": 1}])
	var detail: Dictionary = _first_combat_detail(
			es.call("generate_map", &"stable_map", 1, 1))
	# Act
	var first: Dictionary = ContextScript.build(101, &"combat", [], [1], detail)
	var second: Dictionary = ContextScript.build(101, &"combat", [], [1], detail)
	# Assert——同节点重复构建口径稳定（不掷骰）
	assert_eq(first[ContextScript.KEY_ENCOUNTER_ID],
			second[ContextScript.KEY_ENCOUNTER_ID], "同节点 encounter_id 稳定")
	assert_eq(str(first[ContextScript.KEY_DISPLAY_NAME]), "魔修", "标题取敌人名")
	assert_eq(first[ContextScript.KEY_REWARDS], second[ContextScript.KEY_REWARDS],
			"掉落口径稳定（不随重复进入变化）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 字段缺失 → 可读失败
# ═══════════════════════════════════════════════════════════════════════════════

func test_missing_roster_produces_readable_failure() -> void:
	# Arrange——名册回调缺失（打图阶段还没有 AI 系统）
	_inject_config()
	_inject_other_cbs()
	es.set("generate_enemy_roster_cb", Callable())
	var detail: Dictionary = _first_combat_detail(
			es.call("generate_map", &"no_roster_map", 1, 1))
	# Act
	var context: Dictionary = ContextScript.build(101, &"combat", [], [2], detail)
	var problem: String = ContextScript.validate(context)
	# Assert——不崩、不臆造敌人，失败文案指名缺什么
	assert_true((detail.get("enemy_roster") as Array).is_empty(), "无名册时为空数组")
	assert_false(problem.is_empty(), "缺敌方阵容应给出可读失败")
	assert_string_contains(problem, "敌方阵容", "失败文案点名敌方阵容")


func test_missing_player_roster_produces_readable_failure() -> void:
	# Arrange
	_inject_config()
	_inject_other_cbs()
	_inject_roster([{"template_id": "san_xiu", "realm": 1}])
	var detail: Dictionary = _first_combat_detail(
			es.call("generate_map", &"no_player_map", 1, 1))
	# Act
	var context: Dictionary = ContextScript.build(101, &"combat",
			detail.get("enemy_roster", []), [], detail)
	# Assert
	assert_string_contains(ContextScript.validate(context), "玩家出战阵容",
			"缺玩家阵容应给出可读失败")
	assert_eq(int(context[ContextScript.KEY_ENEMY_LEVEL]), 1,
			"玩家阵容缺失不影响敌方等级透传")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 字段契约：缺省语义与合并规则
# ═══════════════════════════════════════════════════════════════════════════════

func test_encounter_fields_of_detail_merges_top_level_over_child() -> void:
	# Arrange——手写详情：子字典有等级，顶层有掉落（两侧非缺省时各自生效）
	var detail: Dictionary = {
		"description": "竹林遭遇",
		"encounter": {"encounter_id": "bamboo", "enemy_template_ids": ["san_xiu"],
				"enemy_level": 2},
		"enemy_level": 3,
		"rewards": {"lingshi": 9},
	}
	# Act
	var encounter: Dictionary = Fields.of_detail(detail, 202)
	# Assert
	assert_eq(int(encounter["enemy_level"]), 3, "顶层等级非缺省时优先")
	assert_eq(int(encounter["rewards"]["lingshi"]), 9, "顶层掉落非缺省时优先")
	assert_eq(str(encounter["display_name"]), "竹林遭遇", "展示名回退节点描述")
	assert_eq(str(encounter["encounter_id"]), "bamboo", "子字典标识保留")


func test_encounter_fields_backfills_encounter_id_from_node() -> void:
	var encounter: Dictionary = Fields.of_detail({}, 305)
	assert_eq(str(encounter["encounter_id"]), "node_305", "空节点 ID 按节点兜底")
	assert_eq(int(encounter["enemy_level"]), Fields.LEVEL_UNSPECIFIED,
			"未定等级 = 0（不是 null/1）")
	assert_eq(encounter["rewards"], {}, "无掉落 = 空字典")


func test_encounter_fields_reads_legacy_ling_shi_key() -> void:
	# 探索经济域旧写法 ling_shi——读取兼容，写出统一 lingshi
	var rewards: Dictionary = Fields.sanitize_rewards({"ling_shi": 7, "cultivation": 1})
	assert_eq(int(rewards["lingshi"]), 7, "旧键 ling_shi 读取为 lingshi")
	assert_false(rewards.has("ling_shi"), "规范化后不保留旧键")


func test_encounter_fields_template_ids_keep_duplicates() -> void:
	# 显式列表保留重复（散修 ×2），派生名册按模板去重
	var explicit: Array = Fields.template_ids(
			{"enemy_template_ids": ["san_xiu", "san_xiu"]}, [])
	var derived: Array = Fields.template_ids({}, [
		{"template_id": "san_xiu"}, {"template_id": "san_xiu"}])
	assert_eq(explicit, [&"san_xiu", &"san_xiu"], "显式列表保留重复")
	assert_eq(derived, [&"san_xiu"], "名册派生去重")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 弹窗读同一份数据
# ═══════════════════════════════════════════════════════════════════════════════

func test_popup_lines_match_context_encounter() -> void:
	# Arrange——同一份节点详情分别喂给弹窗与开战上下文
	var detail: Dictionary = {
		"description": "山道巡守",
		"encounter": {
			"encounter_id": "shandao",
			"display_name": "山道巡守",
			"enemy_template_ids": ["san_xiu", "san_xiu"],
			"enemy_level": 2,
			"rewards": {"lingshi": 10},
		},
	}
	var encounter: Dictionary = Fields.of_detail(detail, 101)
	# Act
	var lines: Array = Rules.combat_lines_for_encounter(encounter, [], 3)
	var context: Dictionary = ContextScript.build(101, &"combat", [], [1], detail)
	# Assert——名册缺失时数量退化为模板数，等级与上下文一致
	assert_true(str(lines[0]).contains("山道巡守"), "正文名称取遭遇配置")
	assert_true(str(lines[0]).contains("×2"), "数量退化为模板 ID 数")
	assert_true(str(lines[1]).contains(Rules.realm_name(
			int(context[ContextScript.KEY_ENEMY_LEVEL]))), "境界行与开战等级同源")
	assert_eq(int(context[ContextScript.KEY_REWARDS]["lingshi"]), 10,
			"掉落同样来自该节点配置")


func test_popup_lines_strip_count_from_display_name() -> void:
	# 生成器的 label 带「×N」；正文另有数量，不得出现「散修 ×2 ×2」
	var lines: Array = Rules.combat_lines_for_encounter(
			{"display_name": "散修 ×2", "enemy_template_ids": ["san_xiu", "san_xiu"],
					"enemy_level": 1}, [], 3)
	assert_eq(str(lines[0]), "散修 ×2", "正文数量不重复拼接")
