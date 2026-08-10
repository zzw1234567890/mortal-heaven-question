extends GutTest
## Story 002 验收测试：FactionSystem 场上阵营统计 + 阵法条件判定 + 阵营关系判定。
##
## 覆盖 AC-001 到 AC-020（20 条 AC）。
##
## 测试策略：
##   - FS_SCRIPT.new() 构造 FactionSystem 实例（纯查询无副作用）
##   - 操作真实 CardSystem Autoload（/root/CardSystem）注入测试模板 + field_characters
##   - 用 CardSystem.create_instance 创建实例，append 到 field_characters 模拟上场
##   - 阵亡场景：从 field_characters 移除实例模拟阵亡（DeploymentSystem 未来职责）
##   - before_each/after_each 清理 CardSystem + GSM 全局状态
##
## [b]跨 Epic 依赖[/b]：CardSystem.get_field_characters + get_template_by_instance_id（本 Story 补实现）。

const FS_SCRIPT: GDScript = preload("res://src/core/faction_system.gd")
const CS_SCRIPT: GDScript = preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")

var fs: Node = null
var cs: Node = null


func before_each() -> void:
	fs = FS_SCRIPT.new()
	# project.godot 尚未注册 CardSystem Autoload——手动创建实例（不加入场景树，[br]
	# 避免 _ready() 触发模板目录加载清空测试夹具）。通过 fs._test_card_system 注入。
	cs = CS_SCRIPT.new()
	cs.set_process(false)  # 阻止 _process 触发异步加载轮询
	fs._test_card_system = cs
	# 清空状态——避免残留
	cs.templates.clear()
	cs.field_characters.clear()
	_reset_gsm_state()
	# 注入测试用模板
	_inject_template(&"char_zhengdao_a", [&"zhengdao", &"qixuanmen"])
	_inject_template(&"char_zhengdao_b", [&"zhengdao", &"dangxia_valley"])
	_inject_template(&"char_zhengdao_c", [&"zhengdao", &"xuanbing_palace"])
	_inject_template(&"char_modao_a", [&"modao", &"xuehai_temple"])
	_inject_template(&"char_cross_a", [&"suixing_islands"])


func after_each() -> void:
	if fs != null:
		fs._test_card_system = null
		fs.free()
		fs = null
	if cs != null:
		cs.templates.clear()
		cs.field_characters.clear()
		cs.free()
		cs = null
	_reset_gsm_state()


# ============================================================================
# 辅助方法
# ============================================================================

## 获取真实 CardSystem Autoload 节点——若未注册则创建并挂到场景树。[br]
## project.godot 未注册 CardSystem Autoload（Sprint 2 进行中）——测试手动注入。[br]
## 返回已挂在 [code]/root/CardSystem[/code] 的 Node。
func _get_real_card_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var existing: Node = tree.root.get_node_or_null("/root/CardSystem")
	if existing != null:
		return existing
	var node: Node = CS_SCRIPT.new()
	tree.root.add_child(node)
	node.name = "CardSystem"
	node.set_process(false)  # 阻止 _process 触发异步加载轮询
	return node


## 清理 GSM 全局状态——Autoload 单例跨测试持续存在。
func _reset_gsm_state() -> void:
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.collection.owned_cards.clear()
	GameStateManager.collection.total_count = 0
	GameStateManager._next_card_instance_id = 1


## 注入测试模板到真实 CardSystem.templates。
func _inject_template(card_id: StringName, faction_tags: Array) -> CardTemplateClass:
	var tmpl := CardTemplateClass.new()
	tmpl.card_id = card_id
	tmpl.type = 0  # CHARACTER
	# faction_tags 是 Array[StringName]——必须构建类型化数组赋值，否则报 Invalid assignment
	var typed_tags: Array[StringName] = []
	for tag in faction_tags:
		typed_tags.append(tag as StringName)
	tmpl.faction_tags = typed_tags
	cs.templates[card_id] = tmpl
	return tmpl


## 创建实例并上场——append 到 CardSystem.field_characters 模拟 DeploymentSystem 上场。
func _create_and_deploy(template_id: StringName) -> int:
	# 调试：确认模板已注入
	assert_true(cs.templates.has(template_id), "模板 %s 应已注入（当前 templates.size=%d）" % [template_id, cs.templates.size()])
	var inst = cs.create_instance(template_id)
	assert_not_null(inst, "create_instance 应返回非 null 实例")
	cs.field_characters.append(inst)
	return inst.card_instance_id


# ============================================================================
# AC-001：count_on_field 方法签名
# ============================================================================

func test_ac001_count_on_field_returns_int() -> void:
	var c: int = fs.count_on_field(&"zhengdao")
	assert_eq(typeof(c), TYPE_INT, "count_on_field 应返回 int")


# ============================================================================
# AC-002：场上 3 正道 + 1 魔道 → count_on_field(&"zhengdao")=3
# ============================================================================

func test_ac002_count_zhengdao_returns_three() -> void:
	_create_and_deploy(&"char_zhengdao_a")
	_create_and_deploy(&"char_zhengdao_b")
	_create_and_deploy(&"char_zhengdao_c")
	_create_and_deploy(&"char_modao_a")
	assert_eq(fs.count_on_field(&"zhengdao"), 3, "3 正道角色应计数为 3")


# ============================================================================
# AC-003：青云剑宗角色自动计入正道（门派推导）
# ============================================================================

func test_ac003_sect_counts_as_major_alignment() -> void:
	# char_zhengdao_a 含 [zhengdao, qixuanmen]——查询 qixuanmen 应计数
	_create_and_deploy(&"char_zhengdao_a")
	# 查询大阵营 zhengdao——门派角色推导后计入
	assert_eq(fs.count_on_field(&"zhengdao"), 1, "青云剑宗角色应推导为正道计入")


# ============================================================================
# AC-004：同一角色只计一次（多门派标签）
# ============================================================================

func test_ac004_same_character_counted_once() -> void:
	# char_zhengdao_a 含 [zhengdao, qixuanmen]——2 个正道相关标签，但仍只计 1 次
	_create_and_deploy(&"char_zhengdao_a")
	assert_eq(fs.count_on_field(&"zhengdao"), 1, "多门派标签的角色只计一次")


# ============================================================================
# AC-005：get_field_faction_distribution 返回场上分布快照
# ============================================================================

func test_ac005_field_faction_distribution() -> void:
	_create_and_deploy(&"char_zhengdao_a")
	_create_and_deploy(&"char_modao_a")
	var dist: Dictionary = fs.get_field_faction_distribution()
	assert_true(dist.has(&"zhengdao"), "分布应含 zhengdao")
	assert_eq(dist[&"zhengdao"], 1, "zhengdao 计数应为 1")
	assert_true(dist.has(&"modao"), "分布应含 modao")
	assert_eq(dist[&"modao"], 1, "modao 计数应为 1")
	assert_true(dist.has(&"qixuanmen"), "分布应含门派 qixuanmen")
	assert_true(dist.has(&"xuehai_temple"), "分布应含门派 xuehai_temple")
	# 0 计数标签不应出现
	assert_false(dist.has(&"dangxia_valley"), "0 计数标签不应在分布中")


# ============================================================================
# AC-006：check_condition 方法签名
# ============================================================================

func test_ac006_check_condition_returns_bool() -> void:
	var ok: bool = fs.check_condition({tag_id = &"zhengdao", min_count = 1})
	assert_eq(typeof(ok), TYPE_BOOL, "check_condition 应返回 bool")


# ============================================================================
# AC-007：场上正道=3，check_condition(≥3) → true
# ============================================================================

func test_ac007_check_condition_meets_threshold() -> void:
	_create_and_deploy(&"char_zhengdao_a")
	_create_and_deploy(&"char_zhengdao_b")
	_create_and_deploy(&"char_zhengdao_c")
	assert_true(fs.check_condition({tag_id = &"zhengdao", min_count = 3}),
		"3 正道 ≥3 应满足阵法激活条件")


# ============================================================================
# AC-008：场上正道=2，check_condition(≥3) → false
# ============================================================================

func test_ac008_check_condition_below_threshold() -> void:
	_create_and_deploy(&"char_zhengdao_a")
	_create_and_deploy(&"char_zhengdao_b")
	assert_false(fs.check_condition({tag_id = &"zhengdao", min_count = 3}),
		"2 正道 <3 不应满足阵法激活条件")


# ============================================================================
# AC-009：check_condition({}) 空 requirement → false
# ============================================================================

func test_ac009_check_condition_empty_requirement() -> void:
	_create_and_deploy(&"char_zhengdao_a")
	assert_false(fs.check_condition({}), "空 requirement 应返回 false")
	assert_false(fs.check_condition({min_count = 1}), "缺失 tag_id 应返回 false")


# ============================================================================
# AC-010：is_hostile_to 方法签名
# ============================================================================

func test_ac010_is_hostile_to_returns_bool() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_modao_a")
	var ok: bool = fs.is_hostile_to(a_id, b_id)
	assert_eq(typeof(ok), TYPE_BOOL, "is_hostile_to 应返回 bool")


# ============================================================================
# AC-011：正道 A + 魔道 B → is_hostile_to=true
# ============================================================================

func test_ac011_zhengdao_vs_modao_is_hostile() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_modao_a")
	assert_true(fs.is_hostile_to(a_id, b_id), "正道 vs 魔道应敌对")


# ============================================================================
# AC-012：正道 A + 正道 B → is_hostile_to=false（同阵营）
# ============================================================================

func test_ac012_same_alignment_not_hostile() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_zhengdao_b")
	assert_false(fs.is_hostile_to(a_id, b_id), "同阵营不应敌对")


# ============================================================================
# AC-013：正道 A + 碎星群岛 B → is_hostile_to=false（中立）
# ============================================================================

func test_ac013_zhengdao_vs_cross_faction_not_hostile() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_cross_a")
	assert_false(fs.is_hostile_to(a_id, b_id), "正道 vs 跨阵营应中立不敌对")


# ============================================================================
# AC-014：get_alignment_relation 返回枚举值
# ============================================================================

func test_ac014_get_alignment_relation_returns_int() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_modao_a")
	var r: int = fs.get_alignment_relation(a_id, b_id)
	assert_eq(typeof(r), TYPE_INT, "get_alignment_relation 应返回 int")
	assert_true(r in [0, 1, 2], "返回值应在 {0, 1, 2} 范围内")


# ============================================================================
# AC-015：正道 vs 魔道 → HOSTILE(1)
# ============================================================================

func test_ac015_zhengdao_vs_modao_returns_hostile() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_modao_a")
	assert_eq(fs.get_alignment_relation(a_id, b_id), fs.FactionRelation.HOSTILE,
		"正道 vs 魔道应返回 HOSTILE(1)")


# ============================================================================
# AC-016：正道 vs 正道 → SAME(0)
# ============================================================================

func test_ac016_same_alignment_returns_same() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_zhengdao_b")
	assert_eq(fs.get_alignment_relation(a_id, b_id), fs.FactionRelation.SAME,
		"正道 vs 正道应返回 SAME(0)")


# ============================================================================
# AC-017：正道 vs 碎星群岛 → NEUTRAL(2)
# ============================================================================

func test_ac017_zhengdao_vs_cross_returns_neutral() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	var b_id: int = _create_and_deploy(&"char_cross_a")
	assert_eq(fs.get_alignment_relation(a_id, b_id), fs.FactionRelation.NEUTRAL,
		"正道 vs 跨阵营应返回 NEUTRAL(2)")


# ============================================================================
# AC-018：阵亡角色不计入（从 field_characters 移除模拟阵亡）
# ============================================================================

func test_ac018_dead_character_not_counted() -> void:
	var a_id: int = _create_and_deploy(&"char_zhengdao_a")
	_create_and_deploy(&"char_zhengdao_b")
	_create_and_deploy(&"char_zhengdao_c")
	# 初始 3 正道
	assert_eq(fs.count_on_field(&"zhengdao"), 3, "初始应有 3 正道")
	# 模拟 a 阵亡——从 field_characters 移除（DeploymentSystem 未来职责）
	var idx: int = -1
	for i in range(cs.field_characters.size()):
		var inst = cs.field_characters[i]
		if inst != null and inst.card_instance_id == a_id:
			idx = i
			break
	assert_ne(idx, -1, "应找到阵亡角色实例")
	cs.field_characters.remove_at(idx)
	# 阵亡后剩 2 正道
	assert_eq(fs.count_on_field(&"zhengdao"), 2, "阵亡角色不应计入")


# ============================================================================
# AC-019：CardSystem 不可用或场上为空时 count_on_field 返回 0
# ============================================================================

func test_ac019_empty_field_returns_zero() -> void:
	# 场上无角色——等价于 CardSystem 不可用（_get_field_characters 返回空数组）
	assert_eq(fs.count_on_field(&"zhengdao"), 0, "空场上应返回 0")


# ============================================================================
# AC-020：FactionSystem 仍不发射信号（Story 002 未新增 signal 声明）
# ============================================================================

func test_ac020_no_signals_declared() -> void:
	# get_script_signal_list() 只返回脚本自身声明的信号，不含 Node 基类内置信号
	var script_signals: Array = FS_SCRIPT.get_script_signal_list()
	assert_eq(script_signals.size(), 0, "FactionSystem 不应声明任何自有信号")


# ============================================================================
# 边缘情况补强
# ============================================================================

func test_cross_faction_vs_cross_faction_returns_neutral() -> void:
	var a_id: int = _create_and_deploy(&"char_cross_a")
	# 碎星群岛 vs 碎星群岛（同为跨阵营）——无大阵营归属，应返回 NEUTRAL
	assert_eq(fs.get_alignment_relation(a_id, a_id), fs.FactionRelation.NEUTRAL,
		"跨阵营 vs 跨阵营应返回 NEUTRAL")


func test_modao_vs_modao_returns_same() -> void:
	# 需要两个魔道角色——注入第二个魔道模板
	_inject_template(&"char_modao_b", [&"modao", &"meiying_pavilion"])
	var a_id: int = _create_and_deploy(&"char_modao_a")
	var b_id: int = _create_and_deploy(&"char_modao_b")
	assert_eq(fs.get_alignment_relation(a_id, b_id), fs.FactionRelation.SAME,
		"魔道 vs 魔道应返回 SAME")


func test_count_on_field_for_sect_tag() -> void:
	# 直接查询门派标签 qixuanmen——只有含该标签的角色计入
	_create_and_deploy(&"char_zhengdao_a")  # 含 qixuanmen
	_create_and_deploy(&"char_zhengdao_b")  # 含 dangxia_valley，不含 qixuanmen
	assert_eq(fs.count_on_field(&"qixuanmen"), 1, "只有 1 个青云剑宗角色")


func test_check_condition_min_count_zero() -> void:
	# min_count=0——只要 tag_id 非空即满足（即使场上无该标签角色）
	_create_and_deploy(&"char_zhengdao_a")
	assert_true(fs.check_condition({tag_id = &"zhengdao", min_count = 0}),
		"min_count=0 且 tag_id 非空应返回 true")
	assert_true(fs.check_condition({tag_id = &"modao", min_count = 0}),
		"min_count=0 即使场上无该标签也应返回 true（0 >= 0）")


func test_get_alignment_relation_invalid_id_returns_neutral() -> void:
	# 无效 instance_id——get_tags_of_character 返回空，无大阵营归属 → NEUTRAL
	assert_eq(fs.get_alignment_relation(99999, 99998), fs.FactionRelation.NEUTRAL,
		"无效 instance_id 应返回 NEUTRAL")


func test_is_hostile_to_invalid_ids_not_hostile() -> void:
	# 无效 instance_id 之间——NEUTRAL，非敌对
	assert_false(fs.is_hostile_to(99999, 99998),
		"无效 instance_id 之间不应敌对")