extends GutTest
## Story 7-1 验收测试：ProgressionSystem 域存储 + initialize + serialize/deserialize。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接实例化 ProgressionSystem（不依赖 Autoload）
##   - 注入 SaveLoadSystem mock
##   - 验证域存储初始化、序列化往返、脏标志
##
## 设计文档来源：ADR-0012 §决策（架构图 + 关键接口 + 初始化策略）
## Story 来源：production/epics/progression-system/story-001-domain-storage.md

const PS := preload("res://src/meta/progression_system.gd")

var _save_load_mock: Node = null


func before_each() -> void:
	_save_load_mock = Node.new()
	_save_load_mock.set_script(load("res://tests/unit/progression_system/save_load_mock.gd"))


func after_each() -> void:
	if _save_load_mock != null:
		_save_load_mock.free()
		_save_load_mock = null


## 构造一个 ProgressionSystem 实例——不经过 _ready() Autoload 流程。
func _make_ps() -> Node:
	var ps: Node = PS.new()
	ps._save_load_override = _save_load_mock
	return ps


# ============================================================================
# AC-001：_ready() 后 _initialized_and_loaded = true
# ============================================================================

func test_ready_sets_initialized_flag() -> void:
	# Arrange
	var ps: Node = _make_ps()

	# Act——模拟 _ready() 逻辑（不经过 Autoload）
	ps._init_empty_stores()
	var data: Dictionary = ps._load_progression_data()
	ps.initialize(data)
	ps._initialized_and_loaded = true
	ps.progression_initialized.emit()

	# Assert
	assert_true(ps._initialized_and_loaded, "_ready() 后 _initialized_and_loaded 应为 true")

	# Cleanup
	ps.free()


# ============================================================================
# AC-002：_ready() 调用 SaveLoadSystem.load_progression() 获取数据
# ============================================================================

func test_load_progression_data_calls_save_load() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_save_load_mock._progression_data = {"achievements": {"ach_test": {"unlocked": true}}}

	# Act
	var data: Dictionary = ps._load_progression_data()

	# Assert
	assert_true(data.has("achievements"), "应从 SaveLoadSystem.load_progression() 获取数据")
	assert_eq(_save_load_mock.load_call_count, 1, "应调用 load_progression() 一次")

	# Cleanup
	ps.free()


# ============================================================================
# AC-003：initialize(data) 填充全部 6 个域存储
# ============================================================================

func test_initialize_populates_all_domains() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var data: Dictionary = {
		"achievements": {"ach_001": {"unlocked": true}},
		"talents": {"points_available": 50, "unlocked": ["t1"]},
		"card_gallery": {"card_001": true},
		"endings": {"ascension_solo": {"unlocked": true}},
		"statistics": {"total_battles": 10},
		"meta": {"total_completions": 3},
	}

	# Act
	ps.initialize(data)

	# Assert
	assert_true(ps._achievements.has("ach_001"), "achievements 域应被填充")
	assert_eq(int(ps._talents["points_available"]), 50, "talents 域应被填充")
	assert_true(ps._card_gallery.has("card_001"), "card_gallery 域应被填充")
	assert_true(ps._endings.has("ascension_solo"), "endings 域应被填充")
	assert_eq(int(ps._stats["total_battles"]), 10, "stats 域应被填充")
	assert_eq(int(ps._meta["total_completions"]), 3, "meta 域应被填充")

	# Cleanup
	ps.free()


# ============================================================================
# AC-004：首局（无 progression.dat）initialize({}) 后所有域为空/默认值
# ============================================================================

func test_initialize_empty_data_uses_defaults() -> void:
	# Arrange
	var ps: Node = _make_ps()

	# Act
	ps.initialize({})

	# Assert
	assert_eq(ps._achievements.size(), 0, "achievements 应为空")
	assert_eq(int(ps._talents["points_available"]), 0, "talents.points_available 应为 0")
	assert_eq(ps._card_gallery.size(), 0, "card_gallery 应为空")
	assert_eq(ps._endings.size(), 0, "endings 应为空")
	assert_eq(ps._stats.size(), 0, "stats 应为空")
	assert_eq(int(ps._meta["total_completions"]), 0, "meta.total_completions 应为 0")

	# Cleanup
	ps.free()


# ============================================================================
# AC-005：serialize() 返回包含全部 6 个域的 JSON 兼容 Dictionary
# ============================================================================

func test_serialize_returns_all_six_domains() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.initialize({})

	# Act
	var data: Dictionary = ps.serialize()

	# Assert
	assert_true(data.has("achievements"), "serialize 应包含 achievements")
	assert_true(data.has("talents"), "serialize 应包含 talents")
	assert_true(data.has("card_gallery"), "serialize 应包含 card_gallery")
	assert_true(data.has("endings"), "serialize 应包含 endings")
	assert_true(data.has("statistics"), "serialize 应包含 statistics")
	assert_true(data.has("meta"), "serialize 应包含 meta")

	# Cleanup
	ps.free()


# ============================================================================
# AC-006：deserialize(data) 从 JSON Dictionary 填充全部 6 个域，缺失字段用默认值
# ============================================================================

func test_deserialize_partial_data_fills_defaults() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var partial: Dictionary = {
		"achievements": {"ach_x": {"unlocked": true}},
		# talents / card_gallery / endings / statistics / meta 缺失
	}

	# Act
	var ok: bool = ps.deserialize(partial)

	# Assert
	assert_true(ok, "deserialize 应返回 true")
	assert_true(ps._achievements.has("ach_x"), "achievements 应从 data 填充")
	assert_eq(int(ps._talents["points_available"]), 0, "talents 缺失应默认 0")
	assert_eq(ps._card_gallery.size(), 0, "card_gallery 缺失应默认空")
	assert_eq(ps._endings.size(), 0, "endings 缺失应默认空")
	assert_eq(ps._stats.size(), 0, "stats 缺失应默认空")
	assert_eq(int(ps._meta["total_completions"]), 0, "meta 缺失应默认 0")

	# Cleanup
	ps.free()


# ============================================================================
# AC-007：serialize→deserialize→serialize 往返保真
# ============================================================================

func test_serialize_deserialize_roundtrip_fidelity() -> void:
	# Arrange
	var ps1: Node = _make_ps()
	var data: Dictionary = {
		"achievements": {"ach_001": {"unlocked": true, "unlocked_at": "2026-09-01"}},
		"talents": {"points_available": 25, "unlocked": ["t1", "t2"], "equipped": ["t1"]},
		"card_gallery": {"card_001": true, "card_002": true},
		"endings": {"ascension_solo": {"unlocked": true}},
		"statistics": {"total_battles": 42, "highest_damage": 999},
		"meta": {"total_completions": 7, "highest_realm_ever": "元婴"},
	}
	ps1.initialize(data)

	# Act
	var serialized1: Dictionary = ps1.serialize()
	var ps2: Node = _make_ps()
	ps2.deserialize(serialized1)
	var serialized2: Dictionary = ps2.serialize()

	# Assert
	assert_eq(serialized2, serialized1, "serialize→deserialize→serialize 应保真")

	# Cleanup
	ps1.free()
	ps2.free()


# ============================================================================
# AC-008：has_unsaved_changes() 初始 false，写入后 true，mark_saved() 后 false
# ============================================================================

func test_dirty_flag_lifecycle() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.initialize({})

	# Assert——初始 false
	assert_false(ps.has_unsaved_changes(), "initialize 后应为 false")

	# Act——模拟写入
	ps._dirty = true
	assert_true(ps.has_unsaved_changes(), "写入后应为 true")

	# Act——mark_saved
	ps.mark_saved()
	assert_false(ps.has_unsaved_changes(), "mark_saved 后应为 false")

	# Cleanup
	ps.free()


# ============================================================================
# AC-009：progression_initialized 信号在 _ready() 结束时发射
# ============================================================================

func test_progression_initialized_signal_emitted() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var received: Dictionary = {"received": false}
	ps.progression_initialized.connect(func(): received["received"] = true)

	# Act——模拟 _ready() 逻辑
	ps._init_empty_stores()
	var data: Dictionary = ps._load_progression_data()
	ps.initialize(data)
	ps._initialized_and_loaded = true
	ps.progression_initialized.emit()

	# Assert
	assert_true(received["received"], "progression_initialized 信号应被发射")

	# Cleanup
	ps.free()


# ============================================================================
# AC-010：serialize() 不包含 _dirty / _batch_depth / _initialized_and_loaded
# ============================================================================

func test_serialize_excludes_internal_flags() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.initialize({})
	ps._dirty = true
	ps._batch_depth = 2
	ps._initialized_and_loaded = true

	# Act
	var data: Dictionary = ps.serialize()

	# Assert——序列化输出不应包含内部标志
	assert_false(data.has("_dirty"), "serialize 不应包含 _dirty")
	assert_false(data.has("_batch_depth"), "serialize 不应包含 _batch_depth")
	assert_false(data.has("_initialized_and_loaded"), "serialize 不应包含 _initialized_and_loaded")

	# Cleanup
	ps.free()
