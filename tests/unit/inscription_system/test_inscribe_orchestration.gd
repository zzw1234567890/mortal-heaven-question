extends GutTest
## Story 6-9 验收测试：inscribe / apply_inscription 铭刻编排。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 注入 CardSystem mock（返回 artifact 类型模板）
##   - 注入 ResourceSystem mock（灵材扣减）
##   - 使用 artifact_instance_mock.gd 模拟法宝实例
##   - 验证铭刻编排流程 + 候选生成 + 数据写入
##
## 设计文档来源：GDD inscription-system.md §1/§4
## Story 来源：production/epics/inscription-system/story-002-inscribe-orchestration.md

const IS := preload("res://src/feature/inscription_system.gd")
const ARTIFACT_MOCK := preload("res://tests/unit/inscription_system/artifact_instance_mock.gd")

var gsm: Node = null
var _res_mock: Node = null
var _card_mock: Node = null


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	gsm.player.realm = 1
	gsm.player.resources.ling_cai = {"low": 0, "medium": 0, "high": 0, "top": 0}
	# ResourceSystem mock
	_res_mock = Node.new()
	_res_mock.set_script(load("res://tests/unit/inscription_system/resource_mock.gd"))
	# CardSystem mock
	_card_mock = Node.new()
	_card_mock.set_script(load("res://tests/unit/inscription_system/card_system_mock.gd"))
	# 注入 mock 覆盖
	IS._resource_system_override = _res_mock
	IS._card_system_override = _card_mock


func after_each() -> void:
	IS._resource_system_override = null
	IS._card_system_override = null
	if gsm != null:
		gsm.player.realm = 1
		gsm.player.resources.ling_cai = {"low": 0, "medium": 0, "high": 0, "top": 0}
	if _res_mock != null:
		_res_mock.free()
		_res_mock = null
	if _card_mock != null:
		_card_mock.free()
		_card_mock = null


## 创建模拟法宝实例
func _make_artifact_instance(inscriptions: Array, inscription_count: int, total_spent: int) -> RefCounted:
	var inst: RefCounted = ARTIFACT_MOCK.new()
	inst.template_id = "artifact_test"
	inst.inscriptions = inscriptions
	inst.inscription_count = inscription_count
	inst.total_materials_spent = total_spent
	return inst


## 设置灵材库存
func _setup_materials(medium: int) -> void:
	_res_mock._ling_cai = {1: 0, 2: medium, 3: 0, 4: 0}
	gsm.player.resources.ling_cai = {"low": 0, "medium": medium, "high": 0, "top": 0}


# ============================================================================
# AC-001：inscribe() 校验法宝类型——非法宝返回 NOT_ARTIFACT
# ============================================================================

func test_inscribe_non_artifact_returns_not_artifact() -> void:
	# Arrange——card_mock 返回非 artifact 类型
	_card_mock._template_type = "pill"
	var inst := _make_artifact_instance([], 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = IS.inscribe(inst, IS.Direction.NONE, rng)

	# Assert
	assert_eq(int(result["result"]), IS.InscribeResult.NOT_ARTIFACT, "非法宝类型应返回 NOT_ARTIFACT")


# ============================================================================
# AC-002：inscribe() 灵材不足返回 INSUFFICIENT_MATERIALS + cost 字段
# ============================================================================

func test_inscribe_insufficient_materials_returns_error_with_cost() -> void:
	# Arrange——card_mock 返回 artifact 类型
	_card_mock._template_type = "artifact"
	_setup_materials(0)  # 0 灵材
	var inst := _make_artifact_instance([], 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = IS.inscribe(inst, IS.Direction.NONE, rng)

	# Assert
	assert_eq(int(result["result"]), IS.InscribeResult.INSUFFICIENT_MATERIALS, "灵材不足应返回 INSUFFICIENT_MATERIALS")
	assert_true(result.has("cost"), "应包含 cost 字段")
	assert_eq(int(result["cost"]), 1, "首次铭刻 cost 应为 1")


# ============================================================================
# AC-003：inscribe() 成功返回 SUCCESS + candidates(3个) + cost + is_replace
# ============================================================================

func test_inscribe_success_returns_full_result() -> void:
	# Arrange
	_card_mock._template_type = "artifact"
	_setup_materials(10)
	var inst := _make_artifact_instance([], 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = IS.inscribe(inst, IS.Direction.NONE, rng)

	# Assert
	assert_eq(int(result["result"]), IS.InscribeResult.SUCCESS, "应返回 SUCCESS")
	assert_eq(int(result["cost"]), 1, "首次铭刻 cost 应为 1")
	assert_false(bool(result["is_replace"]), "新增模式 is_replace 应为 false")
	var candidates: Array = result["candidates"]
	assert_eq(candidates.size(), 3, "应返回 3 个候选")


# ============================================================================
# AC-004：inscribe() 确认即扣灵材——ResourceSystem.spend_resource 被调用
# ============================================================================

func test_inscribe_deducts_materials_on_confirm() -> void:
	# Arrange
	_card_mock._template_type = "artifact"
	_setup_materials(5)
	var inst := _make_artifact_instance([], 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	IS.inscribe(inst, IS.Direction.NONE, rng)

	# Assert——灵材应扣减 1（首次铭刻 cost=1）
	assert_eq(int(_res_mock._ling_cai[2]), 4, "中级灵材应扣减 1")


# ============================================================================
# AC-005：inscribe() 境界 L=1 时候选不含 T4
# ============================================================================

func test_inscribe_realm1_candidates_exclude_t4() -> void:
	# Arrange
	_card_mock._template_type = "artifact"
	_setup_materials(10)
	gsm.player.realm = 1
	var inst := _make_artifact_instance([], 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var t4_keys: Array = ["cost-1", "regen+1", "armor_break", "mana_extract"]

	# Act
	var result: Dictionary = IS.inscribe(inst, IS.Direction.NONE, rng)
	var candidates: Array = result["candidates"]

	# Assert
	for c: String in candidates:
		assert_false(t4_keys.has(c), "炼气期候选不应含 T4 属性: " + c)


# ============================================================================
# AC-006：inscribe() to_replace_idx=-1 时 is_replace=false
# ============================================================================

func test_inscribe_new_mode_is_replace_false() -> void:
	# Arrange
	_card_mock._template_type = "artifact"
	_setup_materials(10)
	var inst := _make_artifact_instance([], 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = IS.inscribe(inst, IS.Direction.NONE, rng, -1)

	# Assert
	assert_false(bool(result["is_replace"]), "to_replace_idx=-1 时 is_replace 应为 false")


# ============================================================================
# AC-007：inscribe() to_replace_idx>=0 时 is_replace=true
# ============================================================================

func test_inscribe_replace_mode_is_replace_true() -> void:
	# Arrange
	_card_mock._template_type = "artifact"
	_setup_materials(10)
	var inst := _make_artifact_instance([{"type": "atk+1"}, {"type": "def+1"}, {"type": "crit+3"}], 3, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = IS.inscribe(inst, IS.Direction.NONE, rng, 1)

	# Assert
	assert_true(bool(result["is_replace"]), "to_replace_idx>=0 时 is_replace 应为 true")
	assert_eq(int(result["to_replace_idx"]), 1, "to_replace_idx 应为 1")


# ============================================================================
# AC-008：apply_inscription() 新增模式——inscriptions 数组长度+1
# ============================================================================

func test_apply_inscription_new_mode_appends() -> void:
	# Arrange
	var inst := _make_artifact_instance([], 0, 0)

	# Act
	IS.apply_inscription(inst, "atk+1", -1, 1)

	# Assert
	assert_eq(inst.inscriptions.size(), 1, "新增后 inscriptions 长度应为 1")
	assert_eq(str(inst.inscriptions[0]["type"]), "atk+1", "首条属性 type 应为 atk+1")


# ============================================================================
# AC-009：apply_inscription() 替换模式——指定索引被替换，数组长度不变
# ============================================================================

func test_apply_inscription_replace_mode_swaps() -> void:
	# Arrange
	var inst := _make_artifact_instance(
		[{"type": "atk+1", "value": 1}, {"type": "def+1", "value": 1}, {"type": "crit+3", "value": 3}],
		3, 6
	)

	# Act——替换索引 1（def+1 → hp+2）
	IS.apply_inscription(inst, "hp+2", 1, 4)

	# Assert
	assert_eq(inst.inscriptions.size(), 3, "替换后数组长度应保持 3")
	assert_eq(str(inst.inscriptions[0]["type"]), "atk+1", "索引 0 不变")
	assert_eq(str(inst.inscriptions[1]["type"]), "hp+2", "索引 1 应被替换为 hp+2")
	assert_eq(str(inst.inscriptions[2]["type"]), "crit+3", "索引 2 不变")


# ============================================================================
# AC-010：apply_inscription() 后 inscription_count +1，total_materials_spent += cost
# ============================================================================

func test_apply_inscription_increments_count_and_spent() -> void:
	# Arrange
	var inst := _make_artifact_instance([{"type": "atk+1", "value": 1}], 1, 1)

	# Act
	IS.apply_inscription(inst, "def+1", -1, 2)

	# Assert
	assert_eq(inst.inscription_count, 2, "inscription_count 应 +1 为 2")
	assert_eq(inst.total_materials_spent, 3, "total_materials_spent 应 +=2 为 3")
