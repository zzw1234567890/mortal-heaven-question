extends GutTest
## main-menu Story 001 单元测试：MainMenuLogic.select_latest_save / build_save_summary。
##
## 覆盖 QA 规格 AC-2（最近存档选取）全部场景与 edge cases：[br]
##   - 时间戳不同 → 返回最新者[br]
##   - 时间戳相同 → 槽序号升序 tie-break[br]
##   - 单存档 → 该存档[br]
##   - 空/全不存在/null → 空字典[br]
##   - 摘要组装：正常 / 无存档空串 / 时长格式化[br]
##
## 纯函数直调——无需场景树与 Autoload。风格先例：
## tests/unit/hud/test_cultivation_bar_state.gd（arrange/act/assert）。

const LOGIC := preload("res://src/ui/main_menu/main_menu_logic.gd")

## 槽位元数据工厂（list_slots 返回契约镜像——测试数据在测试内定义）。
func _slot(slot_type: int, slot_id: int, exists: bool, timestamp: String,
		realm: String = "金丹期", playtime: int = 7200) -> Dictionary:
	return {
		"slot_type": slot_type,
		"slot_id": slot_id,
		"exists": exists,
		"name": "测试存档",
		"timestamp": timestamp,
		"realm": realm,
		"playtime": playtime,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：最近存档选取
# ═══════════════════════════════════════════════════════════════════════════════

func test_latest_save_distinct_timestamps_returns_newest() -> void:
	## AC-2: 时间戳不同 → 返回时间戳最新者
	# Arrange —— manual_2 较新
	var slots: Array = [
		_slot(0, 0, true, "2026-09-10T08:00:00"),
		_slot(1, 1, true, "2026-09-11T12:00:00"),
		_slot(1, 2, true, "2026-09-12T09:30:00"),
	]
	# Act
	var latest: Dictionary = LOGIC.select_latest_save(slots)
	# Assert
	assert_eq(int(latest.get("slot_type", -1)), 1, "应选中 manual 槽")
	assert_eq(int(latest.get("slot_id", -1)), 2, "应选中时间戳最新的 manual_2")


func test_latest_save_equal_timestamps_tiebreak_slot_order() -> void:
	## AC-2: 时间戳完全相同 → 槽序号升序 tie-break（autosave slot_id=0
	## 优先于 manual_1 slot_id=1——SLOT_ORDER 常量注释语义）。
	# Arrange —— 全部同时间戳；list_slots 遍历序即槽序升序
	var slots: Array = [
		_slot(0, 0, true, "2026-09-12T10:00:00"),
		_slot(1, 1, true, "2026-09-12T10:00:00"),
		_slot(1, 2, true, "2026-09-12T10:00:00"),
	]
	# Act
	var latest: Dictionary = LOGIC.select_latest_save(slots)
	# Assert
	assert_eq(int(latest.get("slot_type", -1)), 0,
			"同时间戳应取槽序号最小者（autosave slot_id=0）")
	assert_eq(int(latest.get("slot_id", -1)), 0, "tie-break 槽序号升序")


func test_latest_save_equal_timestamps_manual_tiebreak_lowest_id() -> void:
	## AC-2 补充: autosave 不存在时，同时间戳的 manual 槽间按 slot_id 升序
	## （manual_1 优先于 manual_2）。
	# Arrange
	var slots: Array = [
		_slot(1, 2, true, "2026-09-12T10:00:00"),
		_slot(1, 1, true, "2026-09-12T10:00:00"),
	]
	# Act
	var latest: Dictionary = LOGIC.select_latest_save(slots)
	# Assert
	assert_eq(int(latest.get("slot_id", -1)), 1, "manual 同时间戳应取 slot_id 最小者")


func test_latest_save_single_slot_returns_itself() -> void:
	## AC-2 edge: 单存档 → 该存档
	# Arrange
	var slots: Array = [_slot(2, 0, true, "2026-09-01T00:00:00")]
	# Act
	var latest: Dictionary = LOGIC.select_latest_save(slots)
	# Assert
	assert_eq(int(latest.get("slot_type", -1)), 2, "单存档应原样返回")
	assert_eq(int(latest.get("slot_id", -1)), 0, "单存档应原样返回")


func test_latest_save_empty_list_returns_empty_dict() -> void:
	## AC-2 空状态防御: 空列表 → 空字典
	# Arrange
	var slots: Array = []
	# Act
	var latest: Dictionary = LOGIC.select_latest_save(slots)
	# Assert
	assert_true(latest.is_empty(), "空列表应返回空字典（调用方守卫）")


func test_latest_save_null_list_returns_empty_dict() -> void:
	## AC-2 空状态防御: null → 空字典
	# Arrange + Act
	var latest: Dictionary = LOGIC.select_latest_save(null)
	# Assert
	assert_true(latest.is_empty(), "null 列表应返回空字典")


func test_latest_save_all_missing_returns_empty_dict() -> void:
	## AC-2 空状态防御: 全部不存在 → 空字典（exists 过滤）
	# Arrange
	var slots: Array = [
		_slot(0, 0, false, "2026-09-12T10:00:00"),
		_slot(1, 1, false, "2026-09-12T11:00:00"),
	]
	# Act
	var latest: Dictionary = LOGIC.select_latest_save(slots)
	# Assert
	assert_true(latest.is_empty(), "全部不存在应返回空字典")


func test_latest_save_missing_entries_skipped() -> void:
	## AC-2 防御: 不存在槽位不参与选取——最新者落在存在的槽位上。
	# Arrange —— manual_2 时间戳最新但不存在 → 应选 manual_1
	var slots: Array = [
		_slot(1, 1, true, "2026-09-11T00:00:00"),
		_slot(1, 2, false, "2026-09-12T00:00:00"),
	]
	# Act
	var latest: Dictionary = LOGIC.select_latest_save(slots)
	# Assert
	assert_eq(int(latest.get("slot_id", -1)), 1, "不存在的最新槽应被跳过")


# ═══════════════════════════════════════════════════════════════════════════════
# 存档摘要组装（story AC + GDD 边界澄清 2026-09-19）
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_summary_normal_meta_builds_text() -> void:
	## 摘要：realm + playtime 组装「上次：[境界] · 游玩 [时长]」
	# Arrange —— 7200s = 2小时0分
	var meta: Dictionary = _slot(0, 0, true, "2026-09-12T00:00:00",
			"元婴期", 7200)
	# Act
	var summary: String = LOGIC.build_save_summary(meta)
	# Assert
	assert_eq(summary, "上次：元婴期 · 游玩 2小时0分", "摘要应按模板组装")


func test_save_summary_missing_save_returns_empty() -> void:
	## 摘要：无存档（exists != true）→ 空串（UI 判空隐藏摘要行）
	# Arrange
	var meta: Dictionary = _slot(0, 0, false, "2026-09-12T00:00:00")
	# Act
	var summary: String = LOGIC.build_save_summary(meta)
	# Assert
	assert_eq(summary, "", "无存档应返回空串")


func test_save_summary_playtime_formats_hours_minutes() -> void:
	## 摘要时长格式化：7385s = 2小时3分（向下取整分钟）
	# Arrange
	var meta: Dictionary = _slot(0, 0, true, "2026-09-12T00:00:00",
			"炼气期", 7385)
	# Act
	var summary: String = LOGIC.build_save_summary(meta)
	# Assert
	assert_eq(summary, "上次：炼气期 · 游玩 2小时3分", "7385s 应格式化为 2小时3分")


func test_save_summary_zero_playtime_shows_zero() -> void:
	## 摘要时长边界：0s（首局刚存档）→「0小时0分」（语义正确不崩溃）
	# Arrange
	var meta: Dictionary = _slot(0, 0, true, "2026-09-12T00:00:00",
			"炼气期", 0)
	# Act
	var summary: String = LOGIC.build_save_summary(meta)
	# Assert
	assert_eq(summary, "上次：炼气期 · 游玩 0小时0分", "0 秒应显示 0小时0分")


func test_save_summary_negative_playtime_clamped() -> void:
	## 摘要防御：负 playtime（meta 损坏）→ 钳 0 不显示负数。
	# Arrange
	var meta: Dictionary = _slot(0, 0, true, "2026-09-12T00:00:00",
			"炼气期", -100)
	# Act
	var summary: String = LOGIC.build_save_summary(meta)
	# Assert
	assert_eq(summary, "上次：炼气期 · 游玩 0小时0分", "负值应钳为 0小时0分")
