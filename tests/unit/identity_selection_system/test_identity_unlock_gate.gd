extends GutTest
## identity-selection Story S16-1 单元测试：Logic 内核 + 读档跳过判定。
##
## 覆盖 QA 规格 AC-1/AC-2/AC-3：[br]
##   - AC-1: confirm_button_enabled（空 → false / 非空 → true / 返回重选选中保留）[br]
##   - AC-2: is_identity_unlocked 透传（6 条目 5 unlocked + 1 locked 阵道双杰）[br]
##   - AC-3: 读档跳过判定（is_identity_selected true/false → 请求导航 / 渲染 6 卡）[br]
##
## [b]纯函数直调[/b]：confirm_button_enabled / is_identity_unlocked 为 static，
## 直接以 [code]IS_SCRIPT.confirm_button_enabled(...)[/code] 调用
## （GUT 直调模式，不实例化场景）。[br]
## [b]读档跳过[/b]：场景实例化 + mock SceneManager（post_transition 信号驱动 +
## call_deferred 模式——godot-specialist 高风险修正：读档跳过导航不能直接放
## _ready，必须等 post_transition 后 defer）。[br]
## [b]mock 模式[/b]：参照 tests/integration/main_menu/test_menu_navigation.gd
## 的 MockSceneManager。
##
## 来源: story-004-identity-select-ui.md QA Test Cases AC-1/2/3、
## ADR-0031 §2、ADR-0022 §is_identity_selected。

const IS_SCENE: PackedScene = preload(
		"res://src/ui/identity_select/identity_select.tscn")
## IdentitySelect 脚本常量——static 纯函数经 preload 调用（class_name 在测试
## 动态加载下不可靠，先例 main_menu Logic 内核 preload 模式）。
const IS_SCRIPT := preload("res://src/ui/identity_select/identity_select.gd")
## SceneManager 脚本常量——断言引用同一枚举真理来源。
const SM := preload("res://src/foundation/scene_manager.gd")


## mock 场景管理器——记录 request_scene_change 调用；暴露 post_transition 信号
## 供读档跳过路径发射（godot-specialist 修正：断言在 post_transition 发射后）。
class MockSceneManager:
	extends Node
	signal post_transition(from: int, to: int)

	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return SM.SceneID.IDENTITY_SELECT

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true


## mock IdentitySelectionSystem——is_identity_selected 可配置；返回 6 条固定
## 条目（5 unlocked + 1 locked 阵道双杰）。
class MockIdentitySystem:
	extends Node

	var selected: bool = false

	func is_identity_selected() -> bool:
		return selected

	func get_available_identities() -> Array[Dictionary]:
		return _six_entries()

	func get_identity_preview(_identity_id: StringName) -> Dictionary:
		return {}

	func _six_entries() -> Array[Dictionary]:
		return [
			{"identity_id": &"azure_sword_disciple", "is_unlocked": true},
			{"identity_id": &"blood_sea_orphan", "is_unlocked": true},
			{"identity_id": &"star_isles_wanderer", "is_unlocked": true},
			{"identity_id": &"frost_palace_disciple", "is_unlocked": true},
			{"identity_id": &"crimson_valley_disciple", "is_unlocked": true},
			{"identity_id": &"formation_duo", "is_unlocked": false},
		]


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：confirm_button_enabled 纯函数
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_button_enabled_empty_selected_id_returns_false() -> void:
	## AC-1: 空选中 → false
	# Arrange
	var empty_id: StringName = &""
	# Act
	var result: bool = IS_SCRIPT.confirm_button_enabled(empty_id)
	# Assert
	assert_false(result, "空选中应返回 false")


func test_confirm_button_enabled_non_empty_selected_id_returns_true() -> void:
	## AC-1: 非空选中 → true
	# Arrange
	var selected: StringName = &"azure_sword_disciple"
	# Act
	var result: bool = IS_SCRIPT.confirm_button_enabled(selected)
	# Assert
	assert_true(result, "非空选中应返回 true")


func test_confirm_button_enabled_return_reselect_keeps_selection() -> void:
	## AC-1 Edge: 未选中 → 选中 → 返回重选（选中保留——selected_id 不重置）[br]
	## 场景层语义：返回重选只关闭弹窗、保留 selected_id。此断言验证纯函数
	## 在「返回重选后选中保留」状态下仍返回 true（选中态未清除）。
	# Arrange —— 模拟「选中 → 返回重选」后 selected_id 仍非空
	var selected_after_reselect: StringName = &"blood_sea_orphan"
	# Act
	var result: bool = IS_SCRIPT.confirm_button_enabled(selected_after_reselect)
	# Assert
	assert_true(result, "返回重选后选中保留——confirm_button_enabled 应仍为 true")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：is_identity_unlocked 透传
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_identity_unlocked_formation_duo_locked_returns_false() -> void:
	## AC-2: 阵道双杰（locked）→ false（透传 is_unlocked 字段，不自算）
	# Arrange
	var entry: Dictionary = {"identity_id": &"formation_duo", "is_unlocked": false}
	# Act
	var result: bool = IS_SCRIPT.is_identity_unlocked(entry)
	# Assert
	assert_false(result, "阵道双杰未解锁应返回 false")


func test_is_identity_unlocked_five_default_unlocked_return_true() -> void:
	## AC-2: 其余 5 条（unlocked）→ true
	# Arrange
	var unlocked_entries: Array[Dictionary] = [
		{"identity_id": &"azure_sword_disciple", "is_unlocked": true},
		{"identity_id": &"blood_sea_orphan", "is_unlocked": true},
		{"identity_id": &"star_isles_wanderer", "is_unlocked": true},
		{"identity_id": &"frost_palace_disciple", "is_unlocked": true},
		{"identity_id": &"crimson_valley_disciple", "is_unlocked": true},
	]
	# Act + Assert
	for entry: Dictionary in unlocked_entries:
		assert_true(IS_SCRIPT.is_identity_unlocked(entry),
				"身份 %s 已解锁应返回 true" % str(entry[&"identity_id"]))


func test_is_identity_unlocked_missing_field_defaults_false() -> void:
	## AC-2 Edge: 缺 is_unlocked 字段 → 安全默认 false（透传 .get 默认值）
	# Arrange
	var entry: Dictionary = {"identity_id": &"unknown"}
	# Act
	var result: bool = IS_SCRIPT.is_identity_unlocked(entry)
	# Assert
	assert_false(result, "缺 is_unlocked 字段应安全默认 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：读档跳过判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_skip_selected_true_requests_exploration_after_post_transition() -> void:
	## AC-3: is_identity_selected true → 读档跳过（post_transition 发射后请求导航）。[br]
	## godot-specialist 修正：_ready 期间 _transitioning 仍 true，直接导航会被
	## 并发守卫拒绝；必须等 post_transition 信号后 call_deferred 请求。
	# Arrange —— 已选中（mock selected=true）→ 场景 _ready 走跳过分支
	var mock_sm: MockSceneManager = MockSceneManager.new()
	var mock_isys: MockIdentitySystem = MockIdentitySystem.new()
	mock_isys.selected = true
	var screen: Control = IS_SCENE.instantiate()
	screen.animate = false
	screen.scene_manager = mock_sm
	screen.identity_system = mock_isys
	add_child(screen)
	# Assert —— _ready 同步阶段：转场未完成，不应已发出导航请求
	assert_eq(mock_sm.change_calls.size(), 0,
			"post_transition 前不应发出导航请求（并发守卫）")
	var grid_skip: GridContainer = screen.get_node("LayoutAnchor/GridContainer")
	assert_eq(grid_skip.get_child_count(), 0,
			"读档跳过不应渲染选择 UI（网格无卡片）")
	# Act —— 模拟 Phase 4 转场完成：发射 post_transition → 经 call_deferred
	mock_sm.post_transition.emit(0, SM.SceneID.IDENTITY_SELECT)
	await get_tree().process_frame
	# Assert —— post_transition 后导航请求发出，目标 EXPLORATION
	assert_eq(mock_sm.change_calls.size(), 1,
			"post_transition 后应发出 1 次导航请求")
	var call: Array = mock_sm.change_calls[0]
	assert_eq(call[1], SM.SceneID.EXPLORATION, "读档跳过目标应为 EXPLORATION")
	screen.free()
	mock_sm.free()
	mock_isys.free()


func test_skip_selected_false_renders_six_cards() -> void:
	## AC-3: is_identity_selected false → 渲染 6 卡网格（不请求导航）
	# Arrange —— 未选中（mock selected=false）
	var mock_sm: MockSceneManager = MockSceneManager.new()
	var mock_isys: MockIdentitySystem = MockIdentitySystem.new()
	mock_isys.selected = false
	var screen: Control = IS_SCENE.instantiate()
	screen.animate = false
	screen.scene_manager = mock_sm
	screen.identity_system = mock_isys
	add_child(screen)
	# Act + Assert —— 渲染 6 卡（GridContainer 直接子节点数 == 6）
	var grid: GridContainer = screen.get_node("LayoutAnchor/GridContainer")
	assert_eq(grid.get_child_count(), 6, "未选中应渲染 6 张身份卡片")
	assert_eq(mock_sm.change_calls.size(), 0, "未选中不应请求导航")
	screen.free()
	mock_sm.free()
	mock_isys.free()


func test_highlight_selected_preserves_locked_card_overlay() -> void:
	## 回归测试（code-review Required #1）: 选中解锁卡后，阵道双杰锁定卡
	## modulate.a 仍为 0.45（半透明遮罩不随选中态丢失——AC「阵道双杰未解锁时
	## 卡片显示半透明 🔒 遮罩」）。[br]
	## [b]驱动方式[/b]：直接调用 _highlight_selected（选中第 0 张已解锁卡），
	## 断言锁定卡（第 5 张 formation_duo）遮罩保持 0.45。
	# Arrange —— 未选中态渲染 6 卡（formation_duo 为第 5 张锁定卡）
	var mock_sm: MockSceneManager = MockSceneManager.new()
	var mock_isys: MockIdentitySystem = MockIdentitySystem.new()
	mock_isys.selected = false
	var screen: Control = IS_SCENE.instantiate()
	screen.animate = false
	screen.scene_manager = mock_sm
	screen.identity_system = mock_isys
	add_child(screen)
	var grid: GridContainer = screen.get_node("LayoutAnchor/GridContainer")
	# Act —— 选中第 0 张（azure_sword_disciple，已解锁）
	screen._highlight_selected(grid.get_child(0))
	# Assert —— 锁定卡（第 5 张）遮罩仍 0.45；选中卡 1.0
	var locked_card: Control = grid.get_child(5) as Control
	assert_almost_eq(locked_card.modulate.a, 0.45, 0.001,
			"选中解锁卡后锁定卡遮罩应保持 0.45 半透明")
	var selected_card: Control = grid.get_child(0) as Control
	assert_almost_eq(selected_card.modulate.a, 1.0, 0.001,
			"选中卡应完全不透明（1.0）")
	screen.free()
	mock_sm.free()
	mock_isys.free()


func test_play_intro_preserves_locked_card_overlay() -> void:
	## 回归测试（复审残留缺陷）: 入场动画路径（_play_intro）不得把锁定卡
	## 飞入到完全不透明——锁定卡飞入目标 alpha 应为 0.45。[br]
	## [b]驱动方式[/b]：直接调用 _play_intro 后，断言锁定卡（第 5 张）目标
	## tween 的最终值。Tween 目标值经 [code]tween_property[/code] 注册在
	## [code]final_val[/code] 字段——此处通过等待 tween 完成后再断言 modulate.a
	## （避免断言 tween 内部字段的脆弱性）。
	# Arrange —— 未选中态渲染 6 卡（animate=false 只关自动播放，不关手动调用）
	var mock_sm: MockSceneManager = MockSceneManager.new()
	var mock_isys: MockIdentitySystem = MockIdentitySystem.new()
	mock_isys.selected = false
	var screen: Control = IS_SCENE.instantiate()
	screen.animate = false
	screen.scene_manager = mock_sm
	screen.identity_system = mock_isys
	add_child(screen)
	var grid: GridContainer = screen.get_node("LayoutAnchor/GridContainer")
	# Act —— 手动触发入场动画
	screen._play_intro()
	# 推进 tween 到完成（0.6s 总时长 + 余量）
	await get_tree().create_timer(1.2).timeout
	# Assert —— 锁定卡 alpha 仍 0.45（飞入目标未冲掉遮罩）；解锁卡 1.0
	var locked_card: Control = grid.get_child(5) as Control
	assert_almost_eq(locked_card.modulate.a, 0.45, 0.001,
			"入场动画后锁定卡遮罩应保持 0.45（飞入目标非 1.0）")
	var first_card: Control = grid.get_child(0) as Control
	assert_almost_eq(first_card.modulate.a, 1.0, 0.001,
			"入场动画后解锁卡应完全不透明")
	screen.free()
	mock_sm.free()
	mock_isys.free()
