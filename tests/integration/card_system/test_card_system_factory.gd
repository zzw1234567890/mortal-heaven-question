extends GutTest
## Story 004 验收测试：CardSystem 实例工厂 + GSM 集成。
##
## 覆盖 AC-001 到 AC-011（11 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CardSystem 实例（不调 _ready，不走异步加载）
##   - 直接注入 fixture 模板到 cs.templates（绕过 load_threaded_request）
##   - 真实 GSM Autoload 单例——before_each/after_each 清理状态
##   - 动态分派：var cs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）

const CS_SCRIPT := preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")
const CardInstanceClass := preload("res://src/core/card_system/card_instance.gd")

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()
	_reset_gsm_state()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	_reset_gsm_state()


## 清理 GSM 全局状态——Autoload 单例跨测试持续存在（参考 test_apply_outcomes.gd 模式）。
func _reset_gsm_state() -> void:
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.collection.owned_cards.clear()
	GameStateManager.collection.total_count = 0
	GameStateManager.narrative.current_chapter = ""
	GameStateManager.narrative.completed_chapters.clear()
	GameStateManager.narrative.story_flags.clear()
	GameStateManager.validation_enabled = false
	GameStateManager._card_template_database = {}
	GameStateManager._next_card_instance_id = 1


## 注入一个测试模板到 cs.templates。
func _inject_template(card_id: StringName, type: int = 0) -> CardTemplateClass:
	var tmpl := CardTemplateClass.new()
	tmpl.card_id = card_id
	tmpl.type = type
	cs.templates[card_id] = tmpl
	return tmpl


# ============================================================================
# AC-001：create_instance 方法签名 + 返回 CardInstance
# ============================================================================

func test_ac001_create_instance_returns_card_instance() -> void:
	_inject_template(&"card_test")
	var inst: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst, "create_instance 应返回非 null 实例")
	if inst != null:
		assert_true(inst is CardInstanceClass, "返回值应为 CardInstance 类型")


# ============================================================================
# AC-002：create_instance 调用 GSM.allocate_card_id() 分配全局唯一 ID
# ============================================================================

func test_ac002_create_instance_allocates_unique_id() -> void:
	_inject_template(&"card_test")
	var inst1: CardInstanceClass = cs.create_instance(&"card_test")
	var inst2: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst1, "inst1 应非 null")
	assert_not_null(inst2, "inst2 应非 null")
	if inst1 != null and inst2 != null:
		assert_true(inst1.card_instance_id != 0, "inst1.card_instance_id 应非零（已分配）")
		assert_true(inst2.card_instance_id != 0, "inst2.card_instance_id 应非零（已分配）")
		assert_true(inst1.card_instance_id != inst2.card_instance_id, "两个实例 ID 应唯一")
		assert_true(inst2.card_instance_id > inst1.card_instance_id, "ID 应单调递增")


# ============================================================================
# AC-003：create_instance 设置 template_id + acquired_chapter（方案 A 章节映射）
# ============================================================================

func test_ac003_create_instance_sets_template_id_and_chapter() -> void:
	_inject_template(&"card_test")
	# 设置当前章节为 chapter_3 → 应解析为 int 3
	GameStateManager.narrative.current_chapter = "chapter_3"
	var inst: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst, "inst 应非 null")
	if inst != null:
		assert_eq(inst.template_id, &"card_test", "template_id 应正确设置")
		assert_eq(inst.acquired_chapter, 3, "acquired_chapter 应为 3（chapter_3 解析）")


func test_ac003_create_instance_empty_chapter_resolves_to_zero() -> void:
	_inject_template(&"card_test")
	# 默认 current_chapter 为空字符串 → acquired_chapter == 0
	var inst: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst, "inst 应非 null")
	if inst != null:
		assert_eq(inst.acquired_chapter, 0, "空章节应解析为 0")


func test_ac003_create_instance_unknown_chapter_resolves_to_zero() -> void:
	_inject_template(&"card_test")
	GameStateManager.narrative.current_chapter = "chapter_99"
	var inst: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst, "inst 应非 null")
	if inst != null:
		assert_eq(inst.acquired_chapter, 0, "未知章节应解析为 0")


# ============================================================================
# AC-004：create_instance 对未知 template_id → push_error + return null
# ============================================================================

func test_ac004_create_instance_unknown_id_push_error_and_null() -> void:
	# templates 中不含 &"card_unknown"
	var inst: CardInstanceClass = cs.create_instance(&"card_unknown")
	assert_null(inst, "未知 template_id 应返回 null")
	assert_push_error_count(1, "未知 template_id 应 push_error 1 次")


func test_ac004_create_instance_empty_id_push_error_and_null() -> void:
	var inst: CardInstanceClass = cs.create_instance(&"")
	assert_null(inst, "空 template_id 应返回 null")
	assert_push_error_count(1, "空 template_id 应 push_error 1 次")


# ============================================================================
# AC-005：enable_validation 调用前，GSM.add_card_to_collection 拒绝写入
# ============================================================================

func test_ac005_add_card_rejected_before_validation() -> void:
	var inst_dict: Dictionary = {
		"card_instance_id": 1,
		"template_id": &"card_test",
	}
	var ok: bool = GameStateManager.add_card_to_collection(inst_dict)
	assert_false(ok, "校验未开启应拒绝写入")
	assert_false(GameStateManager.validation_enabled, "validation_enabled 应为 false")
	assert_eq(GameStateManager.collection.owned_cards.size(), 0, "collection 不应增加")


# ============================================================================
# AC-006：模板加载完成后，CardSystem 主动调用 GSM.enable_validation
# ============================================================================

func test_ac006_on_all_templates_loaded_enables_validation() -> void:
	_inject_template(&"card_test")
	assert_false(GameStateManager.validation_enabled, "调用前 validation_enabled 应为 false")
	cs._on_all_templates_loaded()
	assert_true(GameStateManager.validation_enabled, "调用后 validation_enabled 应为 true")


func test_ac006_on_all_templates_loaded_emits_signal() -> void:
	_inject_template(&"card_a")
	_inject_template(&"card_b")
	var received: Array = []
	cs.templates_loaded.connect(func(c: int) -> void:
		received.append(c)
	)
	cs._on_all_templates_loaded()
	assert_eq(received.size(), 1, "应发射 1 次 templates_loaded")
	if not received.is_empty():
		assert_eq(received[0], 2, "count 应为 2（入库模板数）")


func test_ac006_empty_templates_does_not_enable_validation() -> void:
	# 空 templates → GSM.enable_validation 会 push_error 不启用
	cs._on_all_templates_loaded()
	assert_false(GameStateManager.validation_enabled, "空 templates 不应启用校验")


func test_ac006_on_all_templates_loaded_idempotent_validation() -> void:
	# S-M1: 幂等性——重复调 _on_all_templates_loaded，validation_enabled 应保持 true（GSM 幂等保护）
	_inject_template(&"card_test")
	cs._on_all_templates_loaded()
	assert_true(GameStateManager.validation_enabled, "首次调用后应启用")
	cs._on_all_templates_loaded()
	assert_true(GameStateManager.validation_enabled, "重复调用后应保持启用")


func test_ac006_on_all_templates_loaded_emits_signal_each_call() -> void:
	# S-M1: 信号每次调用都发射——_on_all_templates_loaded 不缓存信号发射状态
	_inject_template(&"card_test")
	var received: Array = []
	cs.templates_loaded.connect(func(c: int) -> void:
		received.append(c)
	)
	cs._on_all_templates_loaded()
	cs._on_all_templates_loaded()
	assert_eq(received.size(), 2, "两次调用应发射 2 次信号")


# ============================================================================
# AC-007：enable_validation 后，add_card_to_collection 对有效 template_id 成功
# ============================================================================

func test_ac007_add_card_succeeds_after_validation() -> void:
	_inject_template(&"card_test")
	cs._on_all_templates_loaded()
	# 手工构造 inst_dict（Story 005 的 serialize_instance 未实现）
	var inst_dict: Dictionary = {
		"card_instance_id": 1,
		"template_id": &"card_test",
		"level": 1,
	}
	var ok: bool = GameStateManager.add_card_to_collection(inst_dict)
	assert_true(ok, "有效 template_id 应成功写入")
	assert_eq(GameStateManager.collection.owned_cards.size(), 1, "collection 应有 1 张卡")
	assert_eq(GameStateManager.collection.total_count, 1, "total_count 应为 1")


# ============================================================================
# AC-008：enable_validation 后，add_card_to_collection 对无效 template_id 拒绝 + push_error
# ============================================================================

func test_ac008_add_card_rejected_for_invalid_template_id() -> void:
	_inject_template(&"card_test")
	cs._on_all_templates_loaded()
	var inst_dict: Dictionary = {
		"card_instance_id": 1,
		"template_id": &"card_invalid",
	}
	var ok: bool = GameStateManager.add_card_to_collection(inst_dict)
	assert_false(ok, "无效 template_id 应拒绝写入")
	assert_push_error_count(1, "无效 template_id 应 push_error 1 次")
	assert_eq(GameStateManager.collection.owned_cards.size(), 0, "collection 不应增加")


func test_ac008_add_card_rejected_for_empty_template_id() -> void:
	_inject_template(&"card_test")
	cs._on_all_templates_loaded()
	var inst_dict: Dictionary = {
		"card_instance_id": 1,
		"template_id": &"",
	}
	var ok: bool = GameStateManager.add_card_to_collection(inst_dict)
	assert_false(ok, "空 template_id 应拒绝写入")


# ============================================================================
# AC-009：CardSystem._ready() 断言 GSM != null（Autoload 顺序保证——间接验证）
# ============================================================================

func test_ac009_gsm_available_for_card_system() -> void:
	# 间接验证：cs 能调用 GSM.allocate_card_id() 返回非零值，证明 GSM 可用
	_inject_template(&"card_test")
	var inst: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst, "inst 应非 null")
	if inst != null:
		assert_true(inst.card_instance_id != 0, "GSM.allocate_card_id 应返回非零值——证明 GSM 可用")


# ============================================================================
# AC-010：GSM 已实现四个方法（回归守护——本 Story 仅调用）
# ============================================================================

func test_ac010_gsm_has_required_methods() -> void:
	assert_true(GameStateManager.has_method("allocate_card_id"), "GSM 应有 allocate_card_id 方法")
	assert_true(GameStateManager.has_method("add_card_to_collection"), "GSM 应有 add_card_to_collection 方法")
	assert_true(GameStateManager.has_method("remove_card_from_collection"), "GSM 应有 remove_card_from_collection 方法")
	assert_true(GameStateManager.has_method("enable_validation"), "GSM 应有 enable_validation 方法")


# ============================================================================
# AC-011：enable_validation 前 create_instance 允许创建实例（不入库）
# ============================================================================

func test_ac011_create_instance_works_before_validation() -> void:
	_inject_template(&"card_test")
	# 未调用 _on_all_templates_loaded——validation_enabled 仍为 false
	var inst: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst, "校验未开启也应能创建实例")
	if inst != null:
		assert_true(inst is CardInstanceClass, "返回值应为 CardInstance")
		assert_true(inst.card_instance_id != 0, "ID 应已分配（非零）")
		# 验证实例未入库——AC-011 明确创建与入库解耦
		assert_eq(GameStateManager.collection.owned_cards.size(), 0, "实例不应自动入库")


func test_ac011_create_instance_does_not_auto_collection_after_validation() -> void:
	# S-M2: 确证 create_instance 不自动入库——enable_validation 后调用，collection 仍为空
	# （区分"未调用 add_card_to_collection" vs "调用了但被拒绝"）
	_inject_template(&"card_test")
	cs._on_all_templates_loaded()
	assert_true(GameStateManager.validation_enabled, "前置：校验已启用")
	var inst: CardInstanceClass = cs.create_instance(&"card_test")
	assert_not_null(inst, "inst 应非 null")
	assert_eq(GameStateManager.collection.owned_cards.size(), 0,
		"create_instance 不应自动入库——入库由调用方显式调 add_card_to_collection")


# ============================================================================
# AC-003 补充：章节映射边界值测试
# ============================================================================

func test_ac003_chapter_boundary_values() -> void:
	# S-L1: CHAPTER_NUMBER_MAP 边界值——chapter_1（最小）和 chapter_5（最大）
	_inject_template(&"card_test")
	for chapter_str: String in ["chapter_1", "chapter_2", "chapter_3", "chapter_4", "chapter_5"]:
		GameStateManager.narrative.current_chapter = chapter_str
		var inst: CardInstanceClass = cs.create_instance(&"card_test")
		assert_not_null(inst, "inst 应非 null（%s）" % chapter_str)
		if inst != null:
			var expected: int = int(chapter_str.substr(8))
			assert_eq(inst.acquired_chapter, expected,
				"%s 应解析为 %d" % [chapter_str, expected])
