extends GutTest
## Story 7-5 验收测试：progression_updated 信号去重 + batch_update + SaveLoad 集成。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接实例化 ProgressionSystem
##   - 监听 progression_updated 信号验证去重和批量合并
##   - 模拟 SaveLoadSystem 被动持久化集成
##
## 设计文档来源：ADR-0012 §批量更新 API + §progression_updated 信号设计
## Story 来源：production/epics/progression-system/story-005-batch-update-integration.md

const PS := preload("res://src/meta/progression_system.gd")

var _save_load_mock: Node = null


func before_each() -> void:
	_save_load_mock = Node.new()
	_save_load_mock.set_script(load("res://tests/unit/progression_system/save_load_mock.gd"))


func after_each() -> void:
	if _save_load_mock != null:
		_save_load_mock.free()
		_save_load_mock = null


func _make_ps() -> Node:
	var ps: Node = PS.new()
	ps._save_load_override = _save_load_mock
	ps.initialize({})
	return ps


# ============================================================================
# AC-001：batch_update_begin() 后 _batch_depth = 1
# ============================================================================

func test_batch_update_begin_increments_depth() -> void:
	# Arrange
	var ps: Node = _make_ps()
	assert_eq(ps._batch_depth, 0, "初始 _batch_depth 应为 0")

	# Act
	ps.batch_update_begin()

	# Assert
	assert_eq(ps._batch_depth, 1, "begin 后 _batch_depth 应为 1")

	# Cleanup
	ps.free()


# ============================================================================
# AC-002：批量期间多次 increment_stat 只在 batch_update_end 时发射一次信号
# ============================================================================

func test_batch_update_dedup_emits_once() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var emit_count: Dictionary = {"count": 0}
	ps.progression_updated.connect(func(_domain: String): emit_count["count"] = int(emit_count["count"]) + 1)

	# Act
	ps.batch_update_begin()
	ps.increment_stat("total_battles", 1)
	ps.increment_stat("total_battles", 1)
	ps.increment_stat("total_victories", 1)
	ps.batch_update_end()

	# Assert——stats 域只发射一次
	assert_eq(int(emit_count["count"]), 1, "批量期间 3 次 increment_stat 应只发射 1 次 progression_updated")

	# Cleanup
	ps.free()


# ============================================================================
# AC-003：batch_update 嵌套 2 层，仅最外层 end 时发射信号
# ============================================================================

func test_batch_update_nested_only_outermost_emits() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var emit_count: Dictionary = {"count": 0}
	ps.progression_updated.connect(func(_domain: String): emit_count["count"] = int(emit_count["count"]) + 1)

	# Act
	ps.batch_update_begin()  # depth=1
	ps.increment_stat("total_battles", 1)
	ps.batch_update_begin()  # depth=2
	ps.increment_stat("total_victories", 1)
	ps.batch_update_end()     # depth=1——不应发射
	assert_eq(int(emit_count["count"]), 0, "内层 end 不应发射信号")
	ps.batch_update_end()     # depth=0——应发射

	# Assert
	assert_eq(int(emit_count["count"]), 1, "仅最外层 end 应发射 1 次")

	# Cleanup
	ps.free()


# ============================================================================
# AC-004：非批量模式下 increment_stat 每次都发射 progression_updated
# ============================================================================

func test_non_batch_mode_emits_every_time() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var emit_count: Dictionary = {"count": 0}
	ps.progression_updated.connect(func(_domain: String): emit_count["count"] = int(emit_count["count"]) + 1)

	# Act
	ps.increment_stat("total_battles", 1)
	ps.increment_stat("total_victories", 1)

	# Assert
	assert_eq(int(emit_count["count"]), 2, "非批量模式应每次发射")

	# Cleanup
	ps.free()


# ============================================================================
# AC-005：batch_update_end 后 _batch_depth = 0
# ============================================================================

func test_batch_update_end_resets_depth() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.batch_update_begin()
	ps.batch_update_begin()
	ps.batch_update_end()
	ps.batch_update_end()

	# Assert
	assert_eq(ps._batch_depth, 0, "全部 end 后 _batch_depth 应为 0")

	# Cleanup
	ps.free()


# ============================================================================
# AC-006：progression_updated 信号携带 domain 参数
# ============================================================================

func test_progression_updated_carries_domain() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var received_domain: Dictionary = {"domain": ""}
	ps.progression_updated.connect(func(domain: String): received_domain["domain"] = domain)

	# Act
	ps.increment_stat("total_battles", 1)

	# Assert
	assert_eq(str(received_domain["domain"]), "stats", "信号应携带 domain 参数")

	# Cleanup
	ps.free()


# ============================================================================
# AC-007：SaveLoad 监听 progression_updated → has_unsaved_changes 返回 true
# ============================================================================

func test_save_load_integration_dirty_check() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var sl: Node = _save_load_mock
	sl._save_called = false
	# 模拟 SaveLoadSystem 监听 ProgressionSystem.progression_updated
	ps.progression_updated.connect(func(_domain: String):
		sl._save_called = ps.has_unsaved_changes()
	)

	# Act
	ps.increment_stat("total_battles", 1)

	# Assert
	assert_true(sl._save_called, "SaveLoad 监听后应检测到 has_unsaved_changes = true")

	# Cleanup
	ps.free()


# ============================================================================
# AC-008：SaveLoad 调用 serialize() 获取完整数据后 mark_saved()
# ============================================================================

func test_save_load_serialize_and_mark_saved() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.increment_stat("total_battles", 5)
	assert_true(ps.has_unsaved_changes(), "写入后应有未保存变更")

	# Act——模拟 SaveLoadSystem 持久化流程
	var data: Dictionary = ps.serialize()
	assert_true(data.has("statistics"), "serialize 应返回完整数据")
	assert_eq(int(data["statistics"]["total_battles"]), 5, "数据应包含 total_battles=5")
	ps.mark_saved()

	# Assert
	assert_false(ps.has_unsaved_changes(), "mark_saved 后应无未保存变更")

	# Cleanup
	ps.free()


# ============================================================================
# AC-009：mark_saved 后 has_unsaved_changes 返回 false
# ============================================================================

func test_mark_saved_clears_dirty() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.increment_stat("total_battles", 1)
	assert_true(ps.has_unsaved_changes(), "写入后应有变更")

	# Act
	ps.mark_saved()

	# Assert
	assert_false(ps.has_unsaved_changes(), "mark_saved 后应无变更")

	# Cleanup
	ps.free()


# ============================================================================
# AC-010：批量期间不同域的变更在 end 时合并发射各自 domain 信号
# ============================================================================

func test_batch_different_domains_merged() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var received_domains: Dictionary = {}
	ps.progression_updated.connect(func(domain: String): received_domains[domain] = true)

	# Act
	ps.batch_update_begin()
	ps.increment_stat("total_battles", 1)  # stats 域
	ps.unlock_achievement("ach_test")       # achievements 域——需先注册
	ps.register_achievement("ach_test", {"name": "test", "category": "combat", "tier": "bronze", "target": 0})
	ps.unlock_achievement("ach_test")
	ps.batch_update_end()

	# Assert——两个不同域应各自发射一次
	assert_true(received_domains.has("stats"), "应发射 stats 域信号")
	assert_true(received_domains.has("achievements"), "应发射 achievements 域信号")

	# Cleanup
	ps.free()
