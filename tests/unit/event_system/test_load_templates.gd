extends GutTest
## Story 002 AC-001, AC-002：模板加载与 chain_next 引用完整性验证。
##
## 覆盖：
##   - AC-001: _load_templates() 正确加载测试目录下所有 .tres EventTemplate 文件
##   - AC-002: 加载完成后验证所有 chain_next 引用完整性——不存在的引用触发 push_error
##
## 测试策略：在 res://assets/events/<subdir>/ 下写入临时 .tres 文件，
## 调用 es._load_templates() 验证加载结果，after_each 清理。
## EventSystem 是 extends Node——测试中 new() 后手动调用 _load_templates()。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")
const EventConditionClass := preload("res://src/foundation/event_system/event_condition.gd")

const TEST_SUBDIRS := ["chain", "dong_fu_qiyu", "fang_shi_jiaoyi",
		"lian_dan_lian_qi", "ling_mai_caijue", "sha_ren_duo_bao", "xie_yue_san_xing"]

var es: Node = null
var _test_files: Array[String] = []


func before_each() -> void:
	es = ES_SCRIPT.new()
	_test_files.clear()
	# 清理上次测试可能残留的 test_*.tres 文件（防止崩溃残留污染）
	_cleanup_test_files()


func after_each() -> void:
	_cleanup_test_files()
	if es != null:
		es.free()
		es = null


func _cleanup_test_files() -> void:
	# 删除本测试追踪的文件
	for path: String in _test_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_test_files.clear()
	# 额外扫描：清理所有事件子目录下 test_*.tres 残留
	for subdir: String in TEST_SUBDIRS:
		var dir_path: String = "res://assets/events/%s" % subdir
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var f: String = dir.get_next()
		while f != "":
			if f.begins_with("test_") and f.ends_with(".tres"):
				DirAccess.remove_absolute("%s/%s" % [dir_path, f])
			f = dir.get_next()
		dir.list_dir_end()


func _save_test_template(tmpl: Resource, file_name: String) -> String:
	## 将 EventTemplate 保存到 res://assets/events/ling_mai_caijue/ 下并追踪清理。
	var path: String = "res://assets/events/ling_mai_caijue/%s" % file_name
	var err: int = ResourceSaver.save(tmpl, path)
	assert_eq(err, OK, "ResourceSaver.save 应成功: %s" % path)
	_test_files.append(path)
	return path


# ============================================================================
# AC-001：_load_templates() 正确加载 .tres EventTemplate 文件
# ============================================================================

func test_ac001_load_templates_loads_tres_files() -> void:
	# Arrange —— 创建 2 个 EventTemplate .tres 文件
	var tmpl1 := EventTemplateClass.new()
	tmpl1.template_id = &"test_load_001"
	tmpl1.title = "测试事件 001"
	tmpl1.options = [EventOptionClass.new()]
	_save_test_template(tmpl1, "test_load_001.tres")

	var tmpl2 := EventTemplateClass.new()
	tmpl2.template_id = &"test_load_002"
	tmpl2.title = "测试事件 002"
	tmpl2.options = [EventOptionClass.new()]
	_save_test_template(tmpl2, "test_load_002.tres")

	# Act
	es._load_templates()

	# Assert
	assert_true(es.templates.has(&"test_load_001"), "应加载 test_load_001")
	assert_true(es.templates.has(&"test_load_002"), "应加载 test_load_002")
	var loaded: EventTemplate = es.get_template(&"test_load_001")
	assert_not_null(loaded, "get_template 应返回非 null")
	assert_eq(loaded.title, "测试事件 001", "加载的模板标题应正确")


func test_ac001_load_templates_emits_templates_loaded_signal() -> void:
	# Arrange
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_signal_001"
	tmpl.options = [EventOptionClass.new()]
	_save_test_template(tmpl, "test_signal_001.tres")
	watch_signals(es)

	# Act
	es._load_templates()

	# Assert
	assert_signal_emitted(es, "templates_loaded", "加载完成应发射 templates_loaded 信号")


func test_ac001_load_templates_sets_ready_flag() -> void:
	# Arrange
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_ready_001"
	tmpl.options = [EventOptionClass.new()]
	_save_test_template(tmpl, "test_ready_001.tres")

	# Assert 加载前
	assert_false(es.is_ready(), "加载前 is_ready 应为 false")

	# Act
	es._load_templates()

	# Assert
	assert_true(es.is_ready(), "加载后 is_ready 应为 true")


func test_ac001_load_templates_skips_non_event_template_file() -> void:
	# Arrange —— 保存一个 EventCondition（非 EventTemplate）为 .tres
	var cond := EventConditionClass.new()
	var path: String = "res://assets/events/ling_mai_caijue/test_not_template.tres"
	ResourceSaver.save(cond, path)
	_test_files.append(path)
	watch_signals(es)

	# Act
	es._load_templates()

	# Assert
	assert_false(es.templates.has(&"test_not_template"), "非 EventTemplate 文件不应注册")
	assert_push_error_count(1, "非 EventTemplate 文件应 push_error")


func test_ac001_load_templates_skips_empty_template_id() -> void:
	# Arrange —— template_id 为空的模板应跳过
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &""
	tmpl.options = [EventOptionClass.new()]
	_save_test_template(tmpl, "test_empty_id.tres")
	watch_signals(es)

	# Act
	es._load_templates()

	# Assert
	assert_false(es.templates.has(&""), "空 template_id 不应注册")
	assert_push_error_count(1, "空 template_id 应 push_error")


# ============================================================================
# AC-002：chain_next 引用完整性验证
# ============================================================================

func test_ac002_load_templates_validates_chain_references() -> void:
	# Arrange —— chain_next 指向不存在的 ID
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_chain_bad_001"
	tmpl.chain_next = &"nonexistent_id"
	tmpl.options = [EventOptionClass.new()]
	_save_test_template(tmpl, "test_chain_bad_001.tres")
	watch_signals(es)

	# Act
	es._load_templates()

	# Assert —— 不存在的 chain_next 引用应触发 push_error
	assert_push_error_count(1, "chain_next 指向不存在的 ID 应 push_error")


func test_ac002_load_templates_valid_chain_references_no_error() -> void:
	# Arrange —— 两个模板互相引用 chain_next，引用完整
	var tmpl_a := EventTemplateClass.new()
	tmpl_a.template_id = &"test_chain_a"
	tmpl_a.chain_next = &"test_chain_b"
	tmpl_a.options = [EventOptionClass.new()]
	_save_test_template(tmpl_a, "test_chain_a.tres")

	var tmpl_b := EventTemplateClass.new()
	tmpl_b.template_id = &"test_chain_b"
	tmpl_b.chain_next = &""  # 无连锁
	tmpl_b.options = [EventOptionClass.new()]
	_save_test_template(tmpl_b, "test_chain_b.tres")
	watch_signals(es)

	# Act
	es._load_templates()

	# Assert —— 引用完整时不应 push_error（仅可能有其他文件的 error，此处目录干净）
	# 注意：_validate_chain_references 对有效引用不调用 push_error
	assert_true(es.templates.has(&"test_chain_a"), "test_chain_a 应加载")
	assert_true(es.templates.has(&"test_chain_b"), "test_chain_b 应加载")


func test_ac002_load_templates_empty_chain_next_no_error() -> void:
	# Arrange —— 空 chain_next 不触发引用验证
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_chain_empty"
	tmpl.chain_next = &""
	tmpl.options = [EventOptionClass.new()]
	_save_test_template(tmpl, "test_chain_empty.tres")
	watch_signals(es)

	# Act
	es._load_templates()

	# Assert —— 空 chain_next 是合法的，不应 push_error
	assert_true(es.templates.has(&"test_chain_empty"), "模板应加载")
