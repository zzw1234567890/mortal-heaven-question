extends GutTest
## Story 7-4 验收测试：ProgressionSystem endings + gallery + stats + meta 领域 API。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接实例化 ProgressionSystem
##   - 测试 endings/gallery/stats/meta 四个领域的 API
##
## 设计文档来源：ADR-0012 §关键接口（endings/gallery/stats/meta 领域）
## Story 来源：production/epics/progression-system/story-004-endings-gallery-stats-meta-api.md

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
# AC-001：unlock_ending("ascension_solo", path, identity, realm) → {success: true}
# ============================================================================

func test_unlock_ending_success() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var path: Dictionary = {"ch1": "reject_mo", "ch5": "ascend"}

	# Act
	var result: Dictionary = ps.unlock_ending("ascension_solo", path, "seven_peaks_disciple", "元婴")

	# Assert
	assert_true(result["success"], "解锁结局应返回 success: true")
	assert_true(ps._endings.has("ascension_solo"), "endings 应包含 ascension_solo")
	var ending: Dictionary = ps._endings["ascension_solo"]
	assert_true(bool(ending["unlocked"]), "应标记为 unlocked")
	assert_eq(int(ps._meta["total_completions"]), 1, "total_completions 应递增为 1")

	# Cleanup
	ps.free()


# ============================================================================
# AC-002：unlock_ending 重复解锁 → {success: false, reason: "already_unlocked"}
# ============================================================================

func test_unlock_ending_already_unlocked() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.unlock_ending("ascension_solo", {}, "id", "金丹")

	# Act
	var result: Dictionary = ps.unlock_ending("ascension_solo", {}, "id", "金丹")

	# Assert
	assert_false(result["success"], "重复解锁应返回 success: false")
	assert_eq(str(result["reason"]), "already_unlocked", "reason 应为 already_unlocked")
	assert_eq(int(ps._meta["total_completions"]), 1, "total_completions 不应二次递增")

	# Cleanup
	ps.free()


# ============================================================================
# AC-003：get_unlocked_endings() 返回已解锁 ending_id 数组
# ============================================================================

func test_get_unlocked_endings() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.unlock_ending("ascension_solo", {}, "id", "金丹")
	ps.unlock_ending("guardian_lone", {}, "id", "金丹")

	# Act
	var endings: Array = ps.get_unlocked_endings()

	# Assert
	assert_eq(endings.size(), 2, "应有 2 个已解锁结局")
	assert_true(endings.has("ascension_solo"), "应包含 ascension_solo")
	assert_true(endings.has("guardian_lone"), "应包含 guardian_lone")

	# Cleanup
	ps.free()


# ============================================================================
# AC-004：mark_card_discovered 首次标记 true，重复不发射信号
# ============================================================================

func test_mark_card_discovered_dedup() -> void:
	# Arrange
	var ps: Node = _make_ps()
	var received: Dictionary = {"count": 0}
	ps.card_discovered.connect(func(_card_id: String, _total: int): received["count"] = int(received["count"]) + 1)

	# Act——首次标记
	ps.mark_card_discovered("card_001")

	# Assert
	assert_true(bool(ps._card_gallery["card_001"]), "应标记为 true")
	assert_eq(int(received["count"]), 1, "首次应发射 card_discovered 信号")

	# Act——重复标记
	ps.mark_card_discovered("card_001")

	# Assert
	assert_eq(int(received["count"]), 1, "重复标记不应再发射信号")

	# Cleanup
	ps.free()


# ============================================================================
# AC-005：is_card_discovered("card_001") 返回 true
# ============================================================================

func test_is_card_discovered() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.mark_card_discovered("card_001")

	# Act + Assert
	assert_true(ps.is_card_discovered("card_001"), "已发现应返回 true")
	assert_false(ps.is_card_discovered("card_999"), "未发现应返回 false")

	# Cleanup
	ps.free()


# ============================================================================
# AC-006：get_card_gallery_stats() 返回 {total_discovered, total_cards=222, completion_pct}
# ============================================================================

func test_get_card_gallery_stats() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps.mark_card_discovered("card_001")
	ps.mark_card_discovered("card_002")

	# Act
	var stats: Dictionary = ps.get_card_gallery_stats()

	# Assert
	assert_eq(int(stats["total_discovered"]), 2, "发现 2 张")
	assert_eq(int(stats["total_cards"]), 222, "总卡牌应为 222")
	assert_true(float(stats["completion_pct"]) > 0.0, "completion_pct 应 > 0")

	# Cleanup
	ps.free()


# ============================================================================
# AC-007：increment_stat("total_battles", 1) 递增统计值
# ============================================================================

func test_increment_stat() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps._stats["total_battles"] = 5

	# Act
	ps.increment_stat("total_battles", 3)

	# Assert
	assert_eq(int(ps._stats["total_battles"]), 8, "应递增为 8")
	assert_true(ps.has_unsaved_changes(), "_dirty 应为 true")

	# Cleanup
	ps.free()


# ============================================================================
# AC-008：set_stat("highest_damage", 999) 仅在 > 当前值时写入
# ============================================================================

func test_set_stat_only_higher() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps._stats["highest_damage"] = 500

	# Act——更低值不写入
	ps.set_stat("highest_damage", 400)
	assert_eq(int(ps._stats["highest_damage"]), 500, "低于当前值不应写入")

	# Act——更高值写入
	ps.set_stat("highest_damage", 999)
	assert_eq(int(ps._stats["highest_damage"]), 999, "高于当前值应写入")

	# Cleanup
	ps.free()


# ============================================================================
# AC-009：get_meta("total_completions") 返回值
# ============================================================================

func test_get_meta() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps._meta["total_completions"] = 7

	# Act + Assert
	assert_eq(int(ps.get_meta_value("total_completions")), 7, "应返回 7")
	assert_eq(ps.get_meta_value("nonexistent_key"), null, "未知 key 应返回 null")

	# Cleanup
	ps.free()


# ============================================================================
# AC-010：set_meta("total_playtime_seconds", 3600) 写入受限 key
# ============================================================================

func test_set_meta_restricted_key() -> void:
	# Arrange
	var ps: Node = _make_ps()

	# Act——合法 key
	ps.set_meta_value("total_playtime_seconds", 3600)
	assert_eq(int(ps._meta["total_playtime_seconds"]), 3600, "应写入 total_playtime_seconds")

	# Act——非法 key（不应写入）
	ps.set_meta_value("invalid_key", 123)
	assert_false(ps._meta.has("invalid_key"), "非法 key 不应写入")

	# Cleanup
	ps.free()
