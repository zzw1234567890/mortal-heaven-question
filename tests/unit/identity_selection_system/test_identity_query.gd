extends GutTest
## Story 003 验收测试：is_identity_selected / get_current_identity。
##
## 覆盖 AC-001 到 AC-004（4 条 AC）。
## 测试策略：
##   - 实例化 IdentitySelectionSystem + GSM Autoload
##   - 验证未选择/已选择状态查询 + 读档跳过场景
##
## 设计文档来源：GDD identity-selection-system.md §6 身份重选/读档
## Story 来源：production/epics/identity-selection-system/story-003-identity-query.md

const IS_SCRIPT := preload("res://src/feature/identity_selection_system.gd")

var isys: Node = null
var gsm: Node = null


func before_each() -> void:
	isys = IS_SCRIPT.new()
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	gsm.player.identity_id = ""


func after_each() -> void:
	if gsm != null:
		gsm.player.identity_id = ""
	if isys != null:
		isys.free()
		isys = null


# ============================================================================
# AC-001：is_identity_selected() 未选择时返回 false
# ============================================================================

func test_is_identity_selected_returns_false_when_not_selected() -> void:
	# Arrange——identity_id 为空
	gsm.player.identity_id = ""

	# Act
	var result: bool = isys.is_identity_selected()

	# Assert
	assert_false(result, "未选择身份时应返回 false")


# ============================================================================
# AC-002：is_identity_selected() 已选择时返回 true
# ============================================================================

func test_is_identity_selected_returns_true_when_selected() -> void:
	# Arrange——identity_id 已写入
	gsm.player.identity_id = "azure_sword_disciple"

	# Act
	var result: bool = isys.is_identity_selected()

	# Assert
	assert_true(result, "已选择身份时应返回 true")


# ============================================================================
# AC-003：get_current_identity() 返回当前身份 ID
# ============================================================================

func test_get_current_identity_returns_selected_id() -> void:
	# Arrange
	gsm.player.identity_id = "blood_sea_orphan"

	# Act
	var identity: StringName = isys.get_current_identity()

	# Assert
	assert_eq(identity, &"blood_sea_orphan",
		"应返回当前身份 ID")


# ============================================================================
# AC-004：读档后（identity_id 非空）is_identity_selected() 返回 true——跳过身份选择
# ============================================================================

func test_is_identity_selected_returns_true_after_save_load() -> void:
	# Arrange——模拟读档后恢复 identity_id
	gsm.player.identity_id = "frost_palace_disciple"

	# Act
	var result: bool = isys.is_identity_selected()

	# Assert
	assert_true(result, "读档后 identity_id 非空时应返回 true——跳过身份选择")
