extends GutTest
## Story 004 AC-001, AC-002, AC-003, AC-007, AC-008, AC-011(c)：连锁事件深度限制 + 截断。
##
## 覆盖：
##   - AC-001: chain_depth=3 时 get_chain_event() 返回空 StringName（截断生效）
##   - AC-002: chain_depth=2 且模板有 chain_next 时返回下一个模板 ID（正常延续）
##   - AC-003: chain_depth=3 截断时 push_warning 被调用（GUT assert_push_warning_count 断言）
##   - AC-007: chain_next=&"" 时 get_chain_event() 返回空 StringName
##   - AC-008: 模板不存在时 get_chain_event() 安全返回空 StringName（不崩溃）
##   - AC-011(c): 深度截断时 _chain_visited_ids 被清空
##   - 补充: 深度边界 depth==3 截断、depth==2 不截断
##
## 测试策略：用内存 EventTemplate 构造夹具，手动填充 es.templates 字典，
## 不依赖磁盘文件。每个测试自主 arrange/act/assert，before_each 清理状态。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")
const EventInstanceClass := preload("res://src/foundation/event_system/event_instance.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	# 不调 _ready()——手动控制 templates 字典
	# _chain_visited_ids 在 new() 后默认为 []，但显式清空以保隔离性
	es._chain_visited_ids.clear()


func after_each() -> void:
	if es != null:
		es.free()
		es = null


func _make_chain_template(tmpl_id: StringName, chain_next: StringName,
		chain_on_option: int = -1) -> EventTemplate:
	## 构造一个带 chain_next 的模板，含 1 个空选项。
	var opt := EventOptionClass.new()
	opt.option_id = "opt_0"
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = tmpl_id
	tmpl.chain_next = chain_next
	tmpl.chain_on_option = chain_on_option
	tmpl.options = [opt]
	es.templates[tmpl_id] = tmpl
	return tmpl


func _make_instance(tmpl_id: StringName, chain_depth: int) -> EventInstance:
	## 构造一个指定 chain_depth 的 EventInstance。
	var inst := EventInstanceClass.new()
	inst.template_id = tmpl_id
	inst.chain_depth = chain_depth
	inst.available_option_indices = [0]
	return inst


# ============================================================================
# AC-001：chain_depth=3 时 get_chain_event() 返回空 StringName（截断生效）
# ============================================================================

func test_ac001_chain_depth_3_returns_empty_stringname() -> void:
	# Arrange —— 模板有 chain_next，但实例深度已达 MAX_CHAIN_DEPTH=3
	_make_chain_template(&"event_root", &"event_next")
	var inst := _make_instance(&"event_root", 3)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert
	assert_eq(next_id, &"", "chain_depth=3 应被截断，返回空 StringName")


# ============================================================================
# AC-002：chain_depth=2 且模板有 chain_next 时返回下一个模板 ID
# ============================================================================

func test_ac002_chain_depth_2_returns_next_template_id() -> void:
	# Arrange —— 深度 2（< MAX_CHAIN_DEPTH=3），模板指向 event_next
	_make_chain_template(&"event_root", &"event_next")
	_make_chain_template(&"event_next", &"")  # 链终点模板存在
	var inst := _make_instance(&"event_root", 2)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert
	assert_eq(next_id, &"event_next", "chain_depth=2 应返回 chain_next 指向的 ID")


func test_ac002_chain_depth_0_returns_next_template_id() -> void:
	# Arrange —— 根事件深度 0，正常连锁
	_make_chain_template(&"event_root", &"event_next")
	var inst := _make_instance(&"event_root", 0)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert
	assert_eq(next_id, &"event_next", "chain_depth=0 应返回 chain_next")


# ============================================================================
# AC-003：chain_depth=3 截断时 push_warning 被调用
# ============================================================================

func test_ac003_depth_truncation_calls_push_warning() -> void:
	# Arrange
	_make_chain_template(&"event_root", &"event_next")
	var inst := _make_instance(&"event_root", 3)

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— GUT assert_push_warning_count 断言 push_warning 被调用 1 次
	assert_push_warning_count(1, "深度截断应调用 push_warning 1 次")


func test_ac003_depth_truncation_warning_contains_template_id() -> void:
	# Arrange
	_make_chain_template(&"event_truncated", &"event_next")
	var inst := _make_instance(&"event_truncated", 3)

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— warning 文本包含模板 ID（可诊断性）
	assert_push_warning("event_truncated", "截断 warning 应包含模板 ID")


# ============================================================================
# AC-007：chain_next=&"" 时 get_chain_event() 返回空 StringName
# ============================================================================

func test_ac007_empty_chain_next_returns_empty() -> void:
	# Arrange —— chain_next 为空（无连锁）
	_make_chain_template(&"event_leaf", &"")
	var inst := _make_instance(&"event_leaf", 0)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert
	assert_eq(next_id, &"", "chain_next 为空时应返回空 StringName")


func test_ac007_empty_chain_next_does_not_push_warning() -> void:
	# Arrange —— chain_next 为空是正常链结束，不应 push_warning
	_make_chain_template(&"event_leaf", &"")
	var inst := _make_instance(&"event_leaf", 0)

	# Act
	es.get_chain_event(inst, 0)

	# Assert
	assert_push_warning_count(0, "正常链结束（无 chain_next）不应 push_warning")


# ============================================================================
# AC-008：模板不存在时 get_chain_event() 安全返回空 StringName
# ============================================================================

func test_ac008_missing_template_returns_empty_safely() -> void:
	# Arrange —— 不注册任何模板，实例指向不存在的 ID
	var inst := _make_instance(&"nonexistent_event", 0)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert —— 不崩溃，返回空
	assert_eq(next_id, &"", "模板不存在时应安全返回空 StringName")


func test_ac008_missing_template_does_not_push_warning() -> void:
	# Arrange
	var inst := _make_instance(&"nonexistent_event", 0)

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— 模板不存在视为链结束，不触发深度截断 warning
	assert_push_warning_count(0, "模板不存在不应 push_warning（视为正常链结束）")


# ============================================================================
# 补充：深度边界 depth==3 截断、depth==2 不截断
# ============================================================================

func test_chain_depth_exactly_3_boundary_truncates() -> void:
	# Arrange —— 边界值：depth == MAX_CHAIN_DEPTH（=3）应截断
	_make_chain_template(&"event_root", &"event_next")
	var inst := _make_instance(&"event_root", 3)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert
	assert_eq(next_id, &"", "depth == MAX_CHAIN_DEPTH 边界应截断")


func test_chain_depth_exactly_2_boundary_does_not_truncate() -> void:
	# Arrange —— 边界值：depth == MAX_CHAIN_DEPTH - 1（=2）不应截断
	_make_chain_template(&"event_root", &"event_next")
	var inst := _make_instance(&"event_root", 2)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert
	assert_eq(next_id, &"event_next", "depth == MAX_CHAIN_DEPTH - 1 不应截断")


func test_chain_depth_4_also_truncates() -> void:
	# Arrange —— 超出边界：depth=4 也应截断
	_make_chain_template(&"event_root", &"event_next")
	var inst := _make_instance(&"event_root", 4)

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert
	assert_eq(next_id, &"", "depth > MAX_CHAIN_DEPTH 应截断")


# ============================================================================
# AC-011(c)：深度截断时 _chain_visited_ids 被清空
# ============================================================================

func test_ac011c_depth_truncation_clears_visited_ids() -> void:
	# Arrange —— 预填充 visited_ids 模拟链中途状态，然后触发深度截断
	_make_chain_template(&"event_root", &"event_next")
	es._chain_visited_ids.append(&"event_a")
	es._chain_visited_ids.append(&"event_b")
	var inst := _make_instance(&"event_root", 3)

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— 深度截断清空 visited_ids，防止残留污染下一条链
	assert_eq(es._chain_visited_ids.size(), 0,
			"深度截断应清空 _chain_visited_ids")


func test_ac011b_no_chain_next_clears_visited_ids() -> void:
	# Arrange —— 预填充 visited_ids，然后触发无 chain_next 的链结束
	_make_chain_template(&"event_leaf", &"")
	es._chain_visited_ids.append(&"event_a")
	es._chain_visited_ids.append(&"event_b")
	var inst := _make_instance(&"event_leaf", 0)

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— 场景 (b) 正常结束也清空 visited_ids
	assert_eq(es._chain_visited_ids.size(), 0,
			"无 chain_next 链结束应清空 _chain_visited_ids")


# ============================================================================
# 补充：MAX_CHAIN_DEPTH 常量值验证
# ============================================================================

func test_max_chain_depth_constant_is_three() -> void:
	# 验证常量值符合 ADR-0003 决策 5
	assert_eq(es.MAX_CHAIN_DEPTH, 3, "MAX_CHAIN_DEPTH 应为 3（ADR-0003 决策 5）")
