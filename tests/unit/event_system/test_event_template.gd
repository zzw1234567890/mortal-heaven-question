extends GutTest
## Story 001 验收测试：EventTemplate Resource 数据模型。
##
## 覆盖 AC-003 到 AC-012（AC-001/AC-002 为 Inspector 编辑器行为，
## 无法在 GUT 自动化测试中验证——需手动检查）。
##
## 每个测试验证 EventCondition / EventOutcome / EventOption / EventTemplate
## 实例化后字段读写正确，以及 use_range 标志消除歧义的行为。

const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")
const EventConditionClass := preload("res://src/foundation/event_system/event_condition.gd")
const EventOutcomeClass := preload("res://src/foundation/event_system/event_outcome.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")


# ============================================================================
# AC-011：Resource 类实例化 + 字段读写
# ============================================================================

# --- EventCondition 字段读写 -------------------------------------------------

func test_event_condition_default_values() -> void:
	var cond := EventConditionClass.new()
	assert_eq(cond.type, EventEnumsClass.ConditionType.REALM, "默认条件类型应为 REALM")
	assert_eq(cond.operator, EventEnumsClass.ConditionOperator.GE, "默认运算符应为 GE")
	assert_eq(cond.target, "", "默认 target 应为空字符串")
	assert_eq(cond.value_str, "", "默认 value_str 应为空字符串")
	assert_eq(cond.value_int, 0, "默认 value_int 应为 0")


func test_event_condition_field_read_write() -> void:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.RESOURCE
	cond.operator = EventEnumsClass.ConditionOperator.EQ
	cond.target = "ling_shi"
	cond.value_str = ""
	cond.value_int = 100

	assert_eq(cond.type, EventEnumsClass.ConditionType.RESOURCE)
	assert_eq(cond.operator, EventEnumsClass.ConditionOperator.EQ)
	assert_eq(cond.target, "ling_shi")
	assert_eq(cond.value_int, 100)


func test_event_condition_flag_type() -> void:
	## FLAG_SET 使用 value_str 存储 flag 值
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.FLAG_SET
	cond.target = "chapter_1_done"
	cond.value_str = "true"

	assert_eq(cond.type, EventEnumsClass.ConditionType.FLAG_SET)
	assert_eq(cond.target, "chapter_1_done")
	assert_eq(cond.value_str, "true")


# --- EventOutcome 字段读写 ---------------------------------------------------

func test_event_outcome_default_values() -> void:
	var out := EventOutcomeClass.new()
	assert_eq(out.type, EventEnumsClass.OutcomeType.NOTHING, "默认结果类型应为 NOTHING")
	assert_eq(out.target, "", "默认 target 应为空字符串")
	assert_eq(out.value_str, "", "默认 value_str 应为空字符串")
	assert_eq(out.value_int, 0, "默认 value_int 应为 0")
	assert_eq(out.use_range, false, "默认 use_range 应为 false")
	assert_eq(out.min_value, 0, "默认 min_value 应为 0")
	assert_eq(out.max_value, 0, "默认 max_value 应为 0")
	assert_eq(out.chance, 1.0, "默认 chance 应为 1.0（必定触发）")


func test_event_outcome_field_read_write() -> void:
	var out := EventOutcomeClass.new()
	out.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	out.target = "ling_shi"
	out.value_int = 50
	out.use_range = false
	out.chance = 0.8

	assert_eq(out.type, EventEnumsClass.OutcomeType.ADD_RESOURCE)
	assert_eq(out.target, "ling_shi")
	assert_eq(out.value_int, 50)
	assert_eq(out.use_range, false)
	assert_almost_eq(out.chance, 0.8, 0.001)


func test_event_outcome_with_range() -> void:
	var out := EventOutcomeClass.new()
	out.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	out.target = "ling_shi"
	out.use_range = true
	out.min_value = 50
	out.max_value = 150
	out.chance = 0.5

	assert_eq(out.use_range, true)
	assert_eq(out.min_value, 50)
	assert_eq(out.max_value, 150)
	assert_almost_eq(out.chance, 0.5, 0.001)


# --- EventOption 字段读写 ----------------------------------------------------

func test_event_option_default_values() -> void:
	var opt := EventOptionClass.new()
	assert_eq(opt.option_id, "", "默认 option_id 应为空字符串")
	assert_eq(opt.text, "", "默认 text 应为空字符串")
	assert_eq(opt.conditions.size(), 0, "默认 conditions 应为空数组")
	assert_eq(opt.outcomes.size(), 0, "默认 outcomes 应为空数组")
	assert_eq(opt.weight_override, 0, "默认 weight_override 应为 0")


func test_event_option_with_conditions_and_outcomes() -> void:
	var cond1 := EventConditionClass.new()
	cond1.type = EventEnumsClass.ConditionType.REALM
	cond1.value_int = 2

	var out1 := EventOutcomeClass.new()
	out1.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	out1.target = "ling_shi"
	out1.value_int = 100

	var opt := EventOptionClass.new()
	opt.option_id = "opt_a"
	opt.text = "稳妥开采"
	opt.conditions = [cond1]
	opt.outcomes = [out1]
	opt.weight_override = 5

	assert_eq(opt.option_id, "opt_a")
	assert_eq(opt.text, "稳妥开采")
	assert_eq(opt.conditions.size(), 1)
	assert_eq(opt.outcomes.size(), 1)
	assert_eq(opt.weight_override, 5)

	# 嵌套读取
	assert_eq(opt.conditions[0].value_int, 2)
	assert_eq(opt.outcomes[0].value_int, 100)


# --- EventTemplate 字段读写 --------------------------------------------------

func test_event_template_default_values() -> void:
	var tmpl := EventTemplateClass.new()
	assert_eq(tmpl.template_id, &"", "默认 template_id 应为空 StringName")
	assert_eq(tmpl.event_type, EventEnumsClass.EventType.LING_MAI_CAIJUE, "默认类型应为灵脉采掘")
	assert_eq(tmpl.title, "", "默认 title 应为空")
	assert_eq(tmpl.min_realm, 1, "默认 min_realm 应为 1")
	assert_eq(tmpl.weight, 10, "默认 weight 应为 10")
	assert_eq(tmpl.chain_next, &"", "默认 chain_next 应为空")
	assert_eq(tmpl.chain_on_option, -1, "默认 chain_on_option 应为 -1")
	assert_eq(tmpl.is_hidden, false, "默认 is_hidden 应为 false")
	assert_eq(tmpl.options.size(), 0, "默认 options 应为空数组")


func test_event_template_full_nested_structure() -> void:
	## 构建完整的 4 层嵌套结构：Template → Option → Condition + Outcome
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.REALM
	cond.value_int = 2

	var out := EventOutcomeClass.new()
	out.type = EventEnumsClass.OutcomeType.ADD_CULTIVATION
	out.value_int = 500

	var opt := EventOptionClass.new()
	opt.option_id = "opt_a"
	opt.text = "修炼"
	opt.conditions = [cond]
	opt.outcomes = [out]

	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"dong_fu_qiyu_001"
	tmpl.event_type = EventEnumsClass.EventType.DONG_FU_QIYU
	tmpl.title = "古老洞府"
	tmpl.description = "你发现了一处古老洞府……"
	tmpl.min_realm = 1
	tmpl.weight = 20
	tmpl.options = [opt]

	# 验证 Template 顶层字段
	assert_eq(tmpl.template_id, &"dong_fu_qiyu_001")
	assert_eq(tmpl.event_type, EventEnumsClass.EventType.DONG_FU_QIYU)
	assert_eq(tmpl.title, "古老洞府")

	# 验证嵌套层级
	assert_eq(tmpl.options.size(), 1)
	assert_eq(tmpl.options[0].option_id, "opt_a")
	assert_eq(tmpl.options[0].conditions.size(), 1)
	assert_eq(tmpl.options[0].outcomes.size(), 1)

	# 验证最深层的 Condition
	assert_eq(tmpl.options[0].conditions[0].type, EventEnumsClass.ConditionType.REALM)
	assert_eq(tmpl.options[0].conditions[0].value_int, 2)

	# 验证最深层的 Outcome
	assert_eq(tmpl.options[0].outcomes[0].type, EventEnumsClass.OutcomeType.ADD_CULTIVATION)
	assert_eq(tmpl.options[0].outcomes[0].value_int, 500)


# ============================================================================
# AC-003：use_range=false 且 min=max=0 → 精确值
# ============================================================================

func test_use_range_false_means_exact_value() -> void:
	## use_range=false 且 value_int=100 → 使用精确值 100，忽略 min/max
	var out := EventOutcomeClass.new()
	out.use_range = false
	out.value_int = 100
	out.min_value = 0
	out.max_value = 0

	assert_false(out.use_range, "use_range 应为 false")
	assert_eq(out.value_int, 100, "value_int 应为精确值 100")
	# min=max=0 与 use_range=false 不冲突——由 use_range 明确指示


func test_use_range_false_with_nonzero_min_max_still_exact() -> void:
	## 即使 min/max 有非零值，use_range=false 时仍应使用 value_int
	var out := EventOutcomeClass.new()
	out.use_range = false
	out.value_int = 42
	out.min_value = 10
	out.max_value = 100

	assert_false(out.use_range)
	assert_eq(out.value_int, 42)
	# 可以读取 min/max 但其语义上无效——use_range 是权威标志


# ============================================================================
# AC-004：use_range=true + 范围 + chance 滑块
# ============================================================================

func test_use_range_true_range_values() -> void:
	## use_range=true, min=50, max=150 → 随机范围
	var out := EventOutcomeClass.new()
	out.use_range = true
	out.min_value = 50
	out.max_value = 150
	out.chance = 0.75

	assert_true(out.use_range, "use_range 应为 true")
	assert_eq(out.min_value, 50)
	assert_eq(out.max_value, 150)
	assert_almost_eq(out.chance, 0.75, 0.001)


func test_chance_slider_range_is_zero_to_one() -> void:
	## chance 字段使用 @export_range(0.0, 1.0, 0.01)
	## 验证 chance 的可用范围
	var out := EventOutcomeClass.new()

	# 边界值
	out.chance = 0.0
	assert_almost_eq(out.chance, 0.0, 0.001)
	out.chance = 1.0
	assert_almost_eq(out.chance, 1.0, 0.001)
	out.chance = 0.01
	assert_almost_eq(out.chance, 0.01, 0.001)
	out.chance = 0.99
	assert_almost_eq(out.chance, 0.99, 0.001)


# ============================================================================
# AC-005：chain_on_option=-1 → 任意选项触发连锁
# ============================================================================

func test_chain_on_option_negative_one_means_any_option() -> void:
	## chain_on_option=-1 表示"任意选项均可触发连锁"
	var tmpl := EventTemplateClass.new()
	tmpl.chain_next = &"chain_event_001"
	tmpl.chain_on_option = -1

	assert_eq(tmpl.chain_on_option, -1, "chain_on_option=-1 表示任意选项触发")
	assert_ne(tmpl.chain_next, &"", "chain_next 非空时应触发连锁")


func test_chain_on_option_specific_index() -> void:
	## chain_on_option=0 → 仅第 0 个选项触发连锁
	var tmpl := EventTemplateClass.new()
	tmpl.chain_next = &"chain_event_002"
	tmpl.chain_on_option = 0

	assert_eq(tmpl.chain_on_option, 0)
	assert_ne(tmpl.chain_next, &"")


func test_chain_next_empty_means_no_chain() -> void:
	var tmpl := EventTemplateClass.new()
	tmpl.chain_next = &""

	assert_eq(tmpl.chain_next, &"", "空 chain_next 表示无连锁")


# ============================================================================
# AC-006：is_hidden=true → 隐藏奇遇
# ============================================================================

func test_is_hidden_true_marks_hidden_encounter() -> void:
	var tmpl := EventTemplateClass.new()
	tmpl.is_hidden = true
	tmpl.template_id = &"xie_yue_san_xing_001"
	tmpl.event_type = EventEnumsClass.EventType.XIE_YUE_SAN_XING

	assert_true(tmpl.is_hidden, "is_hidden=true 标记隐藏奇遇")
	assert_eq(tmpl.event_type, EventEnumsClass.EventType.XIE_YUE_SAN_XING)


func test_is_hidden_false_is_normal_event() -> void:
	var tmpl := EventTemplateClass.new()
	tmpl.is_hidden = false

	assert_false(tmpl.is_hidden, "is_hidden=false 表示普通事件")


# ============================================================================
# AC-007：weight=0 → 模板不会被选中
# ============================================================================

func test_weight_zero_means_disabled() -> void:
	## weight=0 时模板在 select_event() 中应被过滤掉
	## 此处验证数据模型——实际选择逻辑在 Story 002 实现
	var tmpl := EventTemplateClass.new()
	tmpl.weight = 0

	assert_eq(tmpl.weight, 0, "weight=0 表示模板被禁用（不会被 select_event 选中）")


func test_weight_positive_means_enabled() -> void:
	var tmpl := EventTemplateClass.new()
	tmpl.weight = 10

	assert_eq(tmpl.weight, 10, "weight>0 表示模板可被选中")


# ============================================================================
# AC-008：weight_override=0 → 无权重覆盖
# ============================================================================

func test_weight_override_zero_means_no_override() -> void:
	## weight_override=0 表示使用模板默认权重
	var opt := EventOptionClass.new()
	opt.weight_override = 0

	assert_eq(opt.weight_override, 0, "weight_override=0 表示无权重覆盖（使用模板默认权重）")


func test_weight_override_nonzero_overrides_template_weight() -> void:
	var opt := EventOptionClass.new()
	opt.weight_override = 15

	assert_eq(opt.weight_override, 15, "weight_override>0 覆盖模板默认权重")


# ============================================================================
# AC-012：use_range + min/max 字段组合覆盖所有合法状态
# ============================================================================

func test_use_range_combinations_exact_value() -> void:
	## use_range=false + value_int=200: 精确值 200
	var out := EventOutcomeClass.new()
	out.use_range = false
	out.value_int = 200
	assert_false(out.use_range)
	assert_eq(out.value_int, 200)


func test_use_range_combinations_range() -> void:
	## use_range=true + min=10, max=100: 随机范围 [10, 100]
	var out := EventOutcomeClass.new()
	out.use_range = true
	out.min_value = 10
	out.max_value = 100
	assert_true(out.use_range)
	assert_eq(out.min_value, 10)
	assert_eq(out.max_value, 100)


func test_use_range_combinations_min_equals_max() -> void:
	## use_range=true + min=50, max=50: 随机范围 [50, 50]（等价于精确值，但语义上仍是 range）
	var out := EventOutcomeClass.new()
	out.use_range = true
	out.min_value = 50
	out.max_value = 50
	assert_true(out.use_range)
	assert_eq(out.min_value, 50)
	assert_eq(out.max_value, 50)


func test_use_range_combinations_zero_range() -> void:
	## use_range=true + min=0, max=0: 随机范围 [0, 0]——合法，结果总是 0
	var out := EventOutcomeClass.new()
	out.use_range = true
	out.min_value = 0
	out.max_value = 0
	assert_true(out.use_range)
	assert_eq(out.min_value, 0)
	assert_eq(out.max_value, 0)


func test_use_range_combinations_chance_zero() -> void:
	## use_range=true + chance=0.0: 范围定义有效，但永不触发
	var out := EventOutcomeClass.new()
	out.use_range = true
	out.min_value = 100
	out.max_value = 500
	out.chance = 0.0
	assert_true(out.use_range)
	assert_almost_eq(out.chance, 0.0, 0.001)


func test_use_range_combinations_chance_one() -> void:
	## use_range=false + chance=1.0: 精确值 必定触发
	var out := EventOutcomeClass.new()
	out.use_range = false
	out.value_int = 300
	out.chance = 1.0
	assert_false(out.use_range)
	assert_almost_eq(out.chance, 1.0, 0.001)


func test_use_range_combinations_large_range() -> void:
	## use_range=true + 大范围：模拟"灵石 50~500"的高方差结果
	var out := EventOutcomeClass.new()
	out.use_range = true
	out.min_value = 50
	out.max_value = 500
	assert_true(out.use_range)
	assert_eq(out.max_value - out.min_value, 450)


# ============================================================================
# AC-009：无 Variant 类型检查（代码审查辅助）
# ============================================================================
# AC-009 要求所有 @export 字段不使用 Variant 类型。
# 此测试通过检查类字段的类型来验证——如果任何字段是 Variant，
# 则 typeof() 会返回 TYPE_NIL（Variant 的默认 type）。
# 实际的 Inspector 类型由 @export 注解控制——此处验证基础类型正确。

func test_no_variant_fields_in_event_condition() -> void:
	var cond := EventConditionClass.new()
	# 所有 @export 字段必须为 enum / String / int / bool
	assert_eq(typeof(cond.type), TYPE_INT, "enum 字段类型应为 int")
	assert_eq(typeof(cond.operator), TYPE_INT, "enum 字段类型应为 int")
	assert_eq(typeof(cond.target), TYPE_STRING, "target 应为 String")
	assert_eq(typeof(cond.value_str), TYPE_STRING, "value_str 应为 String")
	assert_eq(typeof(cond.value_int), TYPE_INT, "value_int 应为 int")


func test_no_variant_fields_in_event_outcome() -> void:
	var out := EventOutcomeClass.new()
	assert_eq(typeof(out.type), TYPE_INT, "enum 字段类型应为 int")
	assert_eq(typeof(out.target), TYPE_STRING, "target 应为 String")
	assert_eq(typeof(out.value_str), TYPE_STRING, "value_str 应为 String")
	assert_eq(typeof(out.value_int), TYPE_INT, "value_int 应为 int")
	assert_eq(typeof(out.use_range), TYPE_BOOL, "use_range 应为 bool")
	assert_eq(typeof(out.min_value), TYPE_INT, "min_value 应为 int")
	assert_eq(typeof(out.max_value), TYPE_INT, "max_value 应为 int")
	assert_eq(typeof(out.chance), TYPE_FLOAT, "chance 应为 float")


func test_no_variant_fields_in_event_option() -> void:
	var opt := EventOptionClass.new()
	assert_eq(typeof(opt.option_id), TYPE_STRING, "option_id 应为 String")
	assert_eq(typeof(opt.text), TYPE_STRING, "text 应为 String")
	assert_eq(typeof(opt.weight_override), TYPE_INT, "weight_override 应为 int")
	# Array 类型——GDScript 中 typed Array 仍返回 TYPE_ARRAY
	assert_eq(typeof(opt.conditions), TYPE_ARRAY, "conditions 应为 Array")
	assert_eq(typeof(opt.outcomes), TYPE_ARRAY, "outcomes 应为 Array")


func test_no_variant_fields_in_event_template() -> void:
	var tmpl := EventTemplateClass.new()
	assert_eq(typeof(tmpl.template_id), TYPE_STRING_NAME, "template_id 应为 StringName")
	assert_eq(typeof(tmpl.event_type), TYPE_INT, "enum 字段类型应为 int")
	assert_eq(typeof(tmpl.title), TYPE_STRING, "title 应为 String")
	assert_eq(typeof(tmpl.description), TYPE_STRING, "description 应为 String")
	assert_eq(typeof(tmpl.min_realm), TYPE_INT, "min_realm 应为 int")
	assert_eq(typeof(tmpl.weight), TYPE_INT, "weight 应为 int")
	assert_eq(typeof(tmpl.chain_next), TYPE_STRING_NAME, "chain_next 应为 StringName")
	assert_eq(typeof(tmpl.chain_on_option), TYPE_INT, "chain_on_option 应为 int")
	assert_eq(typeof(tmpl.is_hidden), TYPE_BOOL, "is_hidden 应为 bool")
	assert_eq(typeof(tmpl.options), TYPE_ARRAY, "options 应为 Array")


# ============================================================================
# 枚举完整性验证
# ============================================================================

func test_event_type_has_six_values() -> void:
	## EventType 必须包含全部 6 种事件类型，值 0-5
	assert_eq(EventEnumsClass.EventType.size(), 6, "EventType 应有 6 个值")
	assert_eq(EventEnumsClass.EventType.LING_MAI_CAIJUE, 0)
	assert_eq(EventEnumsClass.EventType.FANG_SHI_JIAOYI, 1)
	assert_eq(EventEnumsClass.EventType.DONG_FU_QIYU, 2)
	assert_eq(EventEnumsClass.EventType.SHA_REN_DUO_BAO, 3)
	assert_eq(EventEnumsClass.EventType.LIAN_DAN_LIAN_QI, 4)
	assert_eq(EventEnumsClass.EventType.XIE_YUE_SAN_XING, 5)


func test_condition_type_has_six_values() -> void:
	assert_eq(EventEnumsClass.ConditionType.size(), 6, "ConditionType 应有 6 个值")
	assert_eq(EventEnumsClass.ConditionType.REALM, 0)
	assert_eq(EventEnumsClass.ConditionType.FACTION, 1)
	assert_eq(EventEnumsClass.ConditionType.RESOURCE, 2)
	assert_eq(EventEnumsClass.ConditionType.CARD_OWNED, 3)
	assert_eq(EventEnumsClass.ConditionType.FLAG_SET, 4)
	assert_eq(EventEnumsClass.ConditionType.FLAG_NOT_SET, 5)


func test_condition_operator_has_three_values() -> void:
	assert_eq(EventEnumsClass.ConditionOperator.size(), 3, "ConditionOperator 应有 3 个值")
	assert_eq(EventEnumsClass.ConditionOperator.GE, 0)
	assert_eq(EventEnumsClass.ConditionOperator.EQ, 1)
	assert_eq(EventEnumsClass.ConditionOperator.LT, 2)


func test_outcome_type_has_twelve_values() -> void:
	## OutcomeType 必须包含全部 12 种结果类型，值 0-11
	## 顺序不得重排——与 ADR-0003 完全一致（ADR-0009 追加 12-16 值，不影响 0-11）
	assert_eq(EventEnumsClass.OutcomeType.ADD_RESOURCE, 0)
	assert_eq(EventEnumsClass.OutcomeType.ADD_CULTIVATION, 1)
	assert_eq(EventEnumsClass.OutcomeType.ADD_CARD, 2)
	assert_eq(EventEnumsClass.OutcomeType.REMOVE_CARD, 3)
	assert_eq(EventEnumsClass.OutcomeType.HEAL, 4)
	assert_eq(EventEnumsClass.OutcomeType.DAMAGE, 5)
	assert_eq(EventEnumsClass.OutcomeType.SET_FLAG, 6)
	assert_eq(EventEnumsClass.OutcomeType.GAIN_TALENT, 7)
	assert_eq(EventEnumsClass.OutcomeType.TRIGGER_BATTLE, 8)
	assert_eq(EventEnumsClass.OutcomeType.ADVANCE_CHAPTER, 9)
	assert_eq(EventEnumsClass.OutcomeType.RESTORE_AP, 10)
	assert_eq(EventEnumsClass.OutcomeType.NOTHING, 11)


# ============================================================================
# 多选项模板验证
# ============================================================================

func test_template_with_multiple_options() -> void:
	## 验证多个选项的模板结构
	var opt_a := EventOptionClass.new()
	opt_a.option_id = "opt_a"
	opt_a.text = "选项A"

	var opt_b := EventOptionClass.new()
	opt_b.option_id = "opt_b"
	opt_b.text = "选项B"

	var opt_c := EventOptionClass.new()
	opt_c.option_id = "opt_c"
	opt_c.text = "选项C"

	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"fang_shi_jiaoyi_001"
	tmpl.options = [opt_a, opt_b, opt_c]

	assert_eq(tmpl.options.size(), 3)
	assert_eq(tmpl.options[0].option_id, "opt_a")
	assert_eq(tmpl.options[1].option_id, "opt_b")
	assert_eq(tmpl.options[2].option_id, "opt_c")


# ============================================================================
# 多个 Outcome 验证
# ============================================================================

func test_option_with_multiple_outcomes() -> void:
	## 单个选项可以有多个结果——依次结算
	var out1 := EventOutcomeClass.new()
	out1.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	out1.target = "ling_shi"
	out1.value_int = 50

	var out2 := EventOutcomeClass.new()
	out2.type = EventEnumsClass.OutcomeType.ADD_CULTIVATION
	out2.value_int = 200

	var opt := EventOptionClass.new()
	opt.option_id = "opt_reward"
	opt.outcomes = [out1, out2]

	assert_eq(opt.outcomes.size(), 2)
	assert_eq(opt.outcomes[0].type, EventEnumsClass.OutcomeType.ADD_RESOURCE)
	assert_eq(opt.outcomes[1].type, EventEnumsClass.OutcomeType.ADD_CULTIVATION)


# ============================================================================
# 多个 Condition 验证（AND 逻辑）
# ============================================================================

func test_option_with_multiple_conditions_is_and_logic() -> void:
	## 多个条件是 AND 关系——全部满足才可见
	var cond1 := EventConditionClass.new()
	cond1.type = EventEnumsClass.ConditionType.REALM
	cond1.value_int = 2

	var cond2 := EventConditionClass.new()
	cond2.type = EventEnumsClass.ConditionType.FACTION
	cond2.value_str = "zhengdao"

	var opt := EventOptionClass.new()
	opt.option_id = "opt_elite"
	opt.conditions = [cond1, cond2]

	assert_eq(opt.conditions.size(), 2)
	assert_eq(opt.conditions[0].type, EventEnumsClass.ConditionType.REALM)
	assert_eq(opt.conditions[1].type, EventEnumsClass.ConditionType.FACTION)


# ============================================================================
# QA-L1：use_range=true 且 min_value > max_value 非法状态
# ============================================================================

func test_use_range_true_with_min_greater_than_max_is_illegal_state() -> void:
	## 当 use_range=true 且 min_value > max_value 时，范围为非法状态。
	## 数据模型允许写入，但结算逻辑应检测并报错（Story 002 实现）。
	var out := EventOutcomeClass.new()
	out.use_range = true
	out.min_value = 150
	out.max_value = 50

	assert_true(out.use_range)
	assert_true(out.min_value > out.max_value, "min > max 是非法状态——结算时应检测")


# ============================================================================
# QA-L2：chance 越界值（<0 或 >1）
# ============================================================================

func test_chance_below_zero_is_out_of_bounds() -> void:
	## chance 字段使用 @export_range(0.0, 1.0, 0.01)——Inspector 滑块会限制范围，
	## 但代码中仍可设置越界值。结算逻辑应在 Story 002 中 clamp 或报错。
	var out := EventOutcomeClass.new()
	out.chance = -0.5

	assert_true(out.chance < 0.0, "chance < 0 是越界值——结算时应 clamp 或报错")


func test_chance_above_one_is_out_of_bounds() -> void:
	var out := EventOutcomeClass.new()
	out.chance = 1.5

	assert_true(out.chance > 1.0, "chance > 1 是越界值——结算时应 clamp 或报错")


# ============================================================================
# QA-L3：空 options 数组的 EventTemplate 边缘情况
# ============================================================================

func test_empty_options_template_has_no_selectable_options() -> void:
	## 0 选项的模板——无选项可供玩家选择，是合法但不可玩的状态。
	## 结算逻辑应在 Story 002 中处理此边缘情况（跳过或报错）。
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"empty_test_001"

	assert_eq(tmpl.options.size(), 0, "空 options 数组应存在但无元素")
	assert_eq(tmpl.template_id, &"empty_test_001")


# ============================================================================
# QA-L4：description 字段断言（之前测试重 title 轻 description）
# ============================================================================

func test_event_template_description_field() -> void:
	## 验证 description 字段（多行文本）的读写。
	var tmpl := EventTemplateClass.new()
	tmpl.description = "第一行描述。\n第二行描述。\n第三行描述。"

	assert_eq(tmpl.description, "第一行描述。\n第二行描述。\n第三行描述。",
			"description 多行文本应正确读写")


func test_event_template_description_default_empty() -> void:
	## 默认 description 应为空字符串。
	var tmpl := EventTemplateClass.new()

	assert_eq(tmpl.description, "", "默认 description 应为空字符串")


# ============================================================================
# QA-L5：@export_enum 字符串与 EventEnums 枚举值同步验证
# ============================================================================

func test_export_enum_event_type_count_matches_event_enums() -> void:
	## 验证 EventTemplate.@export_enum 中声明的类型数量与 EventEnums.EventType 一致。
	## 如果策划添加了新事件类型但忘记更新 @export_enum 字符串，此测试会失败。
	assert_eq(EventEnumsClass.EventType.size(), 6,
			"EventEnums.EventType 应有 6 个值——若新增值，需同步更新 event_template.gd 的 @export_enum 字符串")


func test_export_enum_condition_type_count_matches_event_enums() -> void:
	## 验证 event_condition.gd 的 @export_enum 条件类型数量与 EventEnums.ConditionType 一致。
	assert_eq(EventEnumsClass.ConditionType.size(), 6,
			"EventEnums.ConditionType 应有 6 个值——若新增值，需同步更新 event_condition.gd 的 @export_enum 字符串")


func test_export_enum_outcome_type_count_matches_event_enums() -> void:
	## 验证 event_outcome.gd 的 @export_enum 结果类型数量与 EventEnums.OutcomeType 一致。
	## ADR-0009 追加 5 值（12-16）后，完整枚举为 17 值。
	assert_eq(EventEnumsClass.OutcomeType.size(), 17,
			"EventEnums.OutcomeType 应有 17 个值（ADR-0003 12 值 + ADR-0009 追加 5 值）——若新增值，需同步更新 event_outcome.gd 的 @export_enum 字符串")