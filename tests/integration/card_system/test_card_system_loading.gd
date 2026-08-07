extends GutTest
## Story 003 验收测试：CardSystem 模板注册表 + 异步加载。
##
## 覆盖 AC-001 到 AC-012（12 条 AC）。
## 测试策略：动态创建 fixture .tres 文件到 res://tests/fixtures/card_system/templates/，
## 通过 _load_templates_from(fixture_path) 注入加载路径，循环 _process 推进异步加载。
## CardSystem extends Node 不声明 class_name——测试用 var cs: Node 动态分派（控制清单规则）。

const CS_SCRIPT := preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")

const FIXTURE_DIR := "res://tests/fixtures/card_system/templates/"

var cs: Node = null
var _test_files: Array[String] = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	_test_files.clear()
	_cleanup_test_files()
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)


func after_each() -> void:
	_cleanup_test_files()
	if cs != null:
		cs.free()
		cs = null


func _cleanup_test_files() -> void:
	for path: String in _test_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		# Godot 4.x 为每个 .tres 生成 .tres.uid sidecar——一并清理（R1: 防止 fixture 目录污染）
		var uid_path: String = path + ".uid"
		if FileAccess.file_exists(uid_path):
			DirAccess.remove_absolute(uid_path)
	_test_files.clear()
	# 额外扫描：清理 fixture 目录下所有残留 .tres + .tres.uid 文件
	var dir := DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return
	dir.include_hidden = false
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			DirAccess.remove_absolute(FIXTURE_DIR + f)
			DirAccess.remove_absolute(FIXTURE_DIR + f + ".uid")
		f = dir.get_next()
	dir.list_dir_end()


func _save_fixture(tmpl: Resource, file_name: String) -> String:
	var path: String = FIXTURE_DIR + file_name
	var err: int = ResourceSaver.save(tmpl, path)
	assert_eq(err, OK, "ResourceSaver.save 应成功: %s" % path)
	_test_files.append(path)
	return path


## 推进异步加载至完成——循环 _process 最多 60 帧（GAP-5 确定性方案）。
## NOTE: 不依赖 is_processing()——测试实例未加入 SceneTree，set_process(true) 是 no-op，
## is_processing() 永远返回 false。改为检查 _pending_paths 是否清空。
## NOTE: load_threaded_request 的后台线程需要 CPU 时间片——紧凑同步循环中主线程不让出，
## 状态会卡在 IN_PROGRESS。每帧用 OS.delay_msec 让出主线程，驱动后台加载器推进。
func _drive_loading_to_completion(target: Node) -> void:
	for frame: int in range(60):
		target._process(0.016)
		if target._pending_paths.is_empty():
			break
		OS.delay_msec(2)
	# R2: 显式超时断言——区分"实现 bug"与"CI 机器慢导致超时"
	assert_true(target._pending_paths.is_empty(),
		"加载应在 60 帧内完成（若失败可能是 flaky 或实现 bug）")


# ============================================================================
# AC-001：CardSystem extends Node，不声明 class_name
# ============================================================================

func test_ac001_card_system_extends_node_no_class_name() -> void:
	var script: GDScript = load("res://src/core/card_system/card_system.gd")
	assert_eq(script.get_instance_base_type(), "Node", "CardSystem 应继承 Node")
	# 源码中无顶层 class_name 声明（注释中的 # class_name 不算）
	var source: String = FileAccess.get_file_as_string("res://src/core/card_system/card_system.gd")
	var regex := RegEx.new()
	regex.compile("(?m)^class_name\\s+\\w+")
	assert_eq(regex.search(source), null, "源码不应有顶层 class_name 声明")
	# 确认使用动态分派模式
	assert_eq(cs.get_class(), "Node", "实例应为 Node 类型")


# ============================================================================
# AC-002：templates Dictionary 注册表，初始为空
# ============================================================================

func test_ac002_templates_initially_empty() -> void:
	assert_eq(typeof(cs.templates), TYPE_DICTIONARY, "templates 应为 Dictionary")
	assert_true(cs.templates.is_empty(), "templates 初始应为空")


# ============================================================================
# AC-003：_load_templates_from 枚举 .tres 文件，待加载队列长度正确
# ============================================================================

func test_ac003_load_templates_from_enqueues_pending() -> void:
	var tmpl1 := CardTemplateClass.new()
	tmpl1.card_id = &"card_a"
	_save_fixture(tmpl1, "card_a.tres")
	var tmpl2 := CardTemplateClass.new()
	tmpl2.card_id = &"card_b"
	_save_fixture(tmpl2, "card_b.tres")

	cs._load_templates_from(StringName(FIXTURE_DIR))

	var pending: Array = cs._pending_paths
	assert_eq(pending.size(), 2, "待加载队列长度应为 2")


# ============================================================================
# AC-004：load_threaded_request 已提交，状态为 IN_PROGRESS 或 LOADED
# ============================================================================

func test_ac004_load_threaded_request_submitted() -> void:
	var tmpl1 := CardTemplateClass.new()
	tmpl1.card_id = &"card_status_a"
	var path1: String = _save_fixture(tmpl1, "card_status_a.tres")
	var tmpl2 := CardTemplateClass.new()
	tmpl2.card_id = &"card_status_b"
	var path2: String = _save_fixture(tmpl2, "card_status_b.tres")

	cs._load_templates_from(StringName(FIXTURE_DIR))

	var status1: int = ResourceLoader.load_threaded_get_status(path1)
	var status2: int = ResourceLoader.load_threaded_get_status(path2)
	var valid: Array[int] = [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]
	assert_true(valid.has(status1), "path1 状态应为 IN_PROGRESS 或 LOADED（实际: %d）" % status1)
	assert_true(valid.has(status2), "path2 状态应为 IN_PROGRESS 或 LOADED（实际: %d）" % status2)


# ============================================================================
# AC-005：_process 每帧最多查询 10 个 load_threaded_get_status
# ============================================================================

func test_ac005_frame_throttle_max_ten() -> void:
	for i: int in range(15):
		var tmpl := CardTemplateClass.new()
		tmpl.card_id = StringName("card_throttle_%02d" % i)
		_save_fixture(tmpl, "card_throttle_%02d.tres" % i)
	cs._load_templates_from(StringName(FIXTURE_DIR))

	cs._process(0.016)

	var count: int = cs._frame_processed_count
	assert_true(count <= 10, "本帧处理计数应 <= 10（实际: %d）" % count)


# ============================================================================
# AC-006：全部加载完成后发射 templates_loaded 信号 + 空目录仍发射 count=0
# ============================================================================

func test_ac006_loading_completes_emits_signal() -> void:
	var tmpl1 := CardTemplateClass.new()
	tmpl1.card_id = &"card_complete_a"
	_save_fixture(tmpl1, "card_complete_a.tres")
	var tmpl2 := CardTemplateClass.new()
	tmpl2.card_id = &"card_complete_b"
	_save_fixture(tmpl2, "card_complete_b.tres")

	var received: Array = []
	cs.templates_loaded.connect(func(c: int) -> void:
		received.append(c)
	)

	cs._load_templates_from(StringName(FIXTURE_DIR))
	_drive_loading_to_completion(cs)

	assert_true(not received.is_empty(), "templates_loaded 信号应在 60 帧内发射")
	assert_eq(received[0] if not received.is_empty() else -1, 2, "发射的 count 应为 2")
	assert_true(cs._pending_paths.is_empty(), "加载完成后 pending 应清空")
	assert_eq(cs.templates.size(), 2, "templates 应有 2 个模板")


func test_ac006_empty_directory_emits_zero() -> void:
	_cleanup_test_files()
	var received: Array = []
	cs.templates_loaded.connect(func(c: int) -> void:
		received.append(c)
	)

	cs._load_templates_from(StringName(FIXTURE_DIR))

	assert_true(not received.is_empty(), "空目录应直接发射 templates_loaded")
	assert_eq(received[0] if not received.is_empty() else -1, 0, "空目录的 count 应为 0")


# ============================================================================
# AC-007：get_template O(1) 查询，不存在返回 null
# ============================================================================

func test_ac007_get_template_returns_template_or_null() -> void:
	var tmpl1 := CardTemplateClass.new()
	tmpl1.card_id = &"card_get_a"
	_save_fixture(tmpl1, "card_get_a.tres")
	var tmpl2 := CardTemplateClass.new()
	tmpl2.card_id = &"card_get_b"
	_save_fixture(tmpl2, "card_get_b.tres")
	cs._load_templates_from(StringName(FIXTURE_DIR))
	_drive_loading_to_completion(cs)

	var tpl: CardTemplateClass = cs.get_template(&"card_get_a")
	assert_not_null(tpl, "get_template 应返回非 null")
	assert_true(tpl is CardTemplateClass, "返回值应为 CardTemplate")
	assert_eq(tpl.card_id, &"card_get_a", "card_id 应正确")

	var missing: CardTemplateClass = cs.get_template(&"nonexistent")
	assert_null(missing, "不存在的 id 应返回 null")


# ============================================================================
# AC-008：get_templates_by_type O(n) 筛选，无匹配返回空数组
# ============================================================================

func test_ac008_get_templates_by_type_filters() -> void:
	var tmpl1 := CardTemplateClass.new()
	tmpl1.card_id = &"card_type_char1"
	tmpl1.type = CardTemplateClass.CardType.CHARACTER
	_save_fixture(tmpl1, "card_type_char1.tres")
	var tmpl2 := CardTemplateClass.new()
	tmpl2.card_id = &"card_type_char2"
	tmpl2.type = CardTemplateClass.CardType.CHARACTER
	_save_fixture(tmpl2, "card_type_char2.tres")
	var tmpl3 := CardTemplateClass.new()
	tmpl3.card_id = &"card_type_tech1"
	tmpl3.type = CardTemplateClass.CardType.TECHNIQUE
	_save_fixture(tmpl3, "card_type_tech1.tres")
	cs._load_templates_from(StringName(FIXTURE_DIR))
	_drive_loading_to_completion(cs)

	var arr: Array = cs.get_templates_by_type(CardTemplateClass.CardType.CHARACTER)
	assert_eq(arr.size(), 2, "应筛选出 2 个 CHARACTER 模板")
	for t in arr:
		assert_true(t is CardTemplateClass, "元素应为 CardTemplate")
		assert_eq(t.type, CardTemplateClass.CardType.CHARACTER, "类型应为 CHARACTER")

	var empty_arr: Array = cs.get_templates_by_type(CardTemplateClass.CardType.PILL)
	assert_eq(empty_arr.size(), 0, "无匹配类型应返回空数组")


# ============================================================================
# AC-009：重复 card_id——push_error 并跳过（第一个胜出，不断言哪个文件）
# ============================================================================

func test_ac009_duplicate_card_id_push_error_and_skip() -> void:
	# S1: 两个 fixture 的 type 不同——验证"第一个胜出"语义（而非仅 size==1）
	var tmpl1 := CardTemplateClass.new()
	tmpl1.card_id = &"card_dup"
	tmpl1.type = CardTemplateClass.CardType.CHARACTER
	_save_fixture(tmpl1, "card_dup_a.tres")
	var tmpl2 := CardTemplateClass.new()
	tmpl2.card_id = &"card_dup"
	tmpl2.type = CardTemplateClass.CardType.TECHNIQUE
	_save_fixture(tmpl2, "card_dup_b.tres")

	cs._load_templates_from(StringName(FIXTURE_DIR))
	_drive_loading_to_completion(cs)

	assert_eq(cs.templates.size(), 1, "重复 card_id 应只入库 1 个")
	assert_true(cs.templates.has(&"card_dup"), "应有 card_dup")
	# 验证"第一个胜出"——入库模板的 type 应为 tmpl1 的 CHARACTER，而非 tmpl2 的 TECHNIQUE
	var winner: CardTemplateClass = cs.get_template(&"card_dup")
	assert_eq(winner.type, CardTemplateClass.CardType.CHARACTER,
		"重复 card_id 应保留先加载的模板（第一个胜出）")
	assert_push_error_count(1, "重复 card_id 应 push_error 1 次")


# ============================================================================
# AC-010：非 CardTemplate + 缺 card_id——push_error 并跳过
# 注：THREAD_LOAD_FAILED 在实现中已处理（_process 中 FAILED 分支 +
# _validate_template null 检查），但难以在 GUT 中确定性模拟，此处只覆盖
# 可确定性模拟的情况（非 CardTemplate + 空 card_id）。
# ============================================================================

func test_ac010_invalid_files_push_error_and_skip() -> void:
	# 1. 有效 CardTemplate
	var tmpl_valid := CardTemplateClass.new()
	tmpl_valid.card_id = &"card_valid"
	_save_fixture(tmpl_valid, "card_valid.tres")
	# 2. 非 CardTemplate（普通 Resource）
	var plain_res := Resource.new()
	var path2: String = FIXTURE_DIR + "not_card_template.tres"
	ResourceSaver.save(plain_res, path2)
	_test_files.append(path2)
	# 3. card_id 为空的 CardTemplate
	var tmpl_empty := CardTemplateClass.new()
	tmpl_empty.card_id = &""
	_save_fixture(tmpl_empty, "empty_id.tres")

	cs._load_templates_from(StringName(FIXTURE_DIR))
	_drive_loading_to_completion(cs)

	assert_eq(cs.templates.size(), 1, "仅有效项入库")
	assert_true(cs.templates.has(&"card_valid"), "应有 card_valid")
	assert_push_error_count(2, "非 CardTemplate + 空 card_id 应 push_error 2 次")


# ============================================================================
# AC-011：templates_loaded 信号签名（1 个 int 参数）
# ============================================================================

func test_ac011_templates_loaded_signal_signature() -> void:
	var signals: Array = cs.get_signal_list()
	var found: bool = false
	for sig: Dictionary in signals:
		if sig["name"] == "templates_loaded":
			found = true
			var args: Array = sig["args"]
			assert_eq(args.size(), 1, "templates_loaded 应有 1 个参数")
			assert_eq(args[0]["type"], TYPE_INT, "参数类型应为 int")
	assert_true(found, "应存在 templates_loaded 信号")


# ============================================================================
# AC-012：DirAccess 打开失败——push_error + 发射 templates_loaded(0)
# ============================================================================

func test_ac012_dir_access_failure_emits_zero() -> void:
	var received: Array = []
	cs.templates_loaded.connect(func(c: int) -> void:
		received.append(c)
	)

	cs._load_templates_from(&"res://tests/fixtures/nonexistent/")

	assert_push_error_count(1, "DirAccess 失败应 push_error 1 次")
	assert_true(not received.is_empty(), "DirAccess 失败仍应发射 templates_loaded")
	assert_eq(received[0] if not received.is_empty() else -1, 0, "count 应为 0")
	assert_eq(cs.templates.size(), 0, "templates 应为空")
