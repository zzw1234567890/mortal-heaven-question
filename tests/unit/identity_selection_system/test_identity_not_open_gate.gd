extends GutTest
## 「该身份暂未开放」门禁验收：解锁之外的第二道拦截。
##
## [b]为什么需要[/b]：既有 S16-1 只拦「未解锁」。身份解锁了、卡组引用的卡牌模板
## 却没落盘时，[code]apply_identity[/code] 会中途校验失败——玩家点完确认什么也没发生
## （旧实现只有一句 [code]push_error[/code]，玩家看不见）。本文件锁住：
##   · 暂未开放的卡点击[b]不进选中态[/b]、确认按钮保持禁用；
##   · 提示文案是「该身份暂未开放」，且[b]不含[/b]「已为你选择其他身份」这类降级话术；
##   · 确认路径二次校验——即使选中态过期也已拦住；
##   · [code]apply_identity[/code] 仍失败时弹玩家可见的失败提示，而不是静默。
##
## 来源: design/gdd/identity-selection-system.md §边界情况、ADR-0031 §2、
## story-004-identity-select-ui.md。

const IS_SCENE: PackedScene = preload(
		"res://src/ui/identity_select/identity_select.tscn")
const Rules := preload("res://src/ui/identity_select/identity_select_rules.gd")

## 可开局的条目（含 is_ready）。
const READY_ENTRY: Dictionary = {
	"identity_id": &"azure_sword_disciple", "name": "青云剑宗·外门弟子",
	"style_tag": "续航", "initial_ling_shi": 15,
	"character_display_names": ["林渊", "苏剑鸣"],
	"is_unlocked": true, "is_ready": true, "block_reason": &"",
}
## 已解锁但卡组模板不全——「暂未开放」。
const NOT_OPEN_ENTRY: Dictionary = {
	"identity_id": &"star_isles_wanderer", "name": "碎星群岛散修",
	"style_tag": "灵活", "initial_ling_shi": 18,
	"character_display_names": ["汐音", "沐瑶"],
	"is_unlocked": true, "is_ready": false, "block_reason": &"templates_missing",
}
## 未解锁（轮回天赋未到手）。
const LOCKED_ENTRY: Dictionary = {
	"identity_id": &"formation_duo", "name": "阵道双杰",
	"style_tag": "运营", "initial_ling_shi": 25,
	"character_display_names": ["慕星河", "云素心"],
	"is_unlocked": false, "is_ready": false, "block_reason": &"locked",
}

## 每条用例的 mock 句柄——用例结束后显式释放（GUT 会报告未释放的 Node 为 orphan）。
var _mocks: Array[Node] = []


## mock IdentitySelectionSystem——一条可开局 + 一条暂未开放 + 一条未解锁。
class MockIdentitySystem:
	extends Node

	var entries: Array = []
	var applied: Array = []
	var apply_result: bool = true

	func is_identity_selected() -> bool:
		return false

	func get_available_identities() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for entry: Dictionary in entries:
			result.append(entry)
		return result

	func get_identity_preview(identity_id: StringName) -> Dictionary:
		if identity_id.is_empty():
			return {}
		return {
			"identity_id": identity_id, "name": str(identity_id),
			"flavor_text": "测试叙事文本。", "initial_deck_cards": [],
			"character_details": [], "talent": {}, "playstyle_hint": "",
		}

	func apply_identity(identity_id: StringName) -> bool:
		applied.append(identity_id)
		return apply_result


## MockSceneManager——带 post_transition（场景 _ready 会查它）。
class MockSceneManager:
	extends Node
	signal post_transition(from: int, to: int)

	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return 0

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true


func _entries() -> Array:
	return [READY_ENTRY, NOT_OPEN_ENTRY, LOCKED_ENTRY]


## 装一个场景 + 两个 mock——句柄记进 [member _mocks]，用例结束后统一释放。
func _mount() -> Control:
	var mock_isys: MockIdentitySystem = MockIdentitySystem.new()
	mock_isys.entries = _entries()
	var mock_sm: MockSceneManager = MockSceneManager.new()
	_mocks.append(mock_isys)
	_mocks.append(mock_sm)
	var screen: Control = IS_SCENE.instantiate()
	screen.animate = false
	screen.scene_manager = mock_sm
	screen.identity_system = mock_isys
	add_child_autofree(screen)
	return screen


func after_each() -> void:
	for mock: Node in _mocks:
		if is_instance_valid(mock):
			mock.free()
	_mocks.clear()


## 卡片点击统一经 [code]gui_input[/code] 信号驱动（headless 下 push_input 不投递，
## 项目既有先例 test_loot_delay_clickable.gd / test_node_move_interaction.gd）。
func _click(screen: Control, index: int) -> void:
	var card: Control = (screen.get_node("LayoutAnchor/GridContainer") as GridContainer) \
			.get_child(index) as Control
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card.gui_input.emit(click)


func _toast(screen: Control) -> AcceptDialog:
	return screen.get_node("LockedDialog") as AcceptDialog


# ═══════════════════════════════════════════════════════════════════════════════
# 纯函数：就绪判定与提示文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_identity_ready_requires_unlocked_and_ready() -> void:
	assert_true(Rules.is_identity_ready(READY_ENTRY), "两条都满足 → 就绪")
	assert_false(Rules.is_identity_ready(NOT_OPEN_ENTRY), "已解锁但模板不全 → 不就绪")
	assert_false(Rules.is_identity_ready(LOCKED_ENTRY), "未解锁 → 不就绪")
	assert_false(Rules.is_identity_ready({}), "空条目 → 不就绪")


func test_is_identity_ready_defaults_to_unlocked_when_field_absent() -> void:
	## 旧口径条目只带 is_unlocked——不能因为缺 is_ready 就把已解锁身份判死。
	assert_true(Rules.is_identity_ready({"is_unlocked": true}), "缺 is_ready 时回退 is_unlocked")
	assert_false(Rules.is_identity_ready({"is_unlocked": false}), "未解锁仍不就绪")


func test_start_block_reason_classifies_each_case() -> void:
	assert_eq(Rules.start_block_reason(READY_ENTRY), Rules.REASON_NONE, "就绪时无阻断")
	assert_eq(Rules.start_block_reason(NOT_OPEN_ENTRY), Rules.REASON_NOT_OPEN, "暂未开放")
	assert_eq(Rules.start_block_reason(LOCKED_ENTRY), Rules.REASON_LOCKED, "未解锁")
	assert_eq(Rules.start_block_reason({}), Rules.REASON_NOT_OPEN, "查无身份归入暂未开放")


func test_blocked_toast_text_matches_gdd_wording() -> void:
	assert_eq(Rules.blocked_toast_text(NOT_OPEN_ENTRY), "该身份暂未开放",
			"暂未开放的提示文案应为「该身份暂未开放」")
	assert_eq(Rules.blocked_toast_text(LOCKED_ENTRY), "该身份需要轮回天赋『苍玄行者』解锁",
			"未解锁仍提示轮回天赋")
	assert_eq(Rules.blocked_toast_text(READY_ENTRY), "", "就绪时不弹提示")


func test_confirm_enabled_for_requires_startable_selection() -> void:
	assert_true(Rules.confirm_enabled_for(&"azure_sword_disciple", READY_ENTRY),
			"选中可开局身份 → 确认可用")
	assert_false(Rules.confirm_enabled_for(&"star_isles_wanderer", NOT_OPEN_ENTRY),
			"选中暂未开放身份 → 确认应禁用")
	assert_false(Rules.confirm_enabled_for(&"", {}), "未选中 → 确认应禁用")


# ═══════════════════════════════════════════════════════════════════════════════
# 场景：暂未开放的卡点不动
# ═══════════════════════════════════════════════════════════════════════════════

func test_not_open_card_click_does_not_select_and_shows_toast() -> void:
	# Arrange
	var screen: Control = _mount()
	var confirm: Button = screen.get_node("LayoutAnchor/ConfirmButton") as Button
	assert_true(confirm.disabled, "初始态确认按钮应禁用")

	# Act —— 点第 1 张（star_isles_wanderer，is_ready=false）
	_click(screen, 1)

	# Assert
	assert_eq(screen.selected_id, &"", "暂未开放的身份不得进入选中态")
	assert_true(confirm.disabled, "确认按钮应保持禁用（不可据此开局）")
	assert_true(_toast(screen).visible, "应弹出提示")
	assert_eq(_toast(screen).dialog_text, "该身份暂未开放",
			"提示文案应为「该身份暂未开放」")


func test_not_open_toast_text_never_offers_silent_fallback() -> void:
	# Act
	var screen: Control = _mount()
	_click(screen, 1)

	# Assert —— 明确不静默降级到身份①
	var text: String = _toast(screen).dialog_text
	assert_false(text.contains("青云"), "提示不得暗示已改用身份①")
	assert_false(text.contains("其他身份"), "提示不得暗示已改用其他身份")


func test_locked_card_click_shows_talent_toast() -> void:
	# Act
	var screen: Control = _mount()
	_click(screen, 2)

	# Assert
	assert_eq(screen.selected_id, &"", "未解锁的身份不得进入选中态")
	assert_eq(_toast(screen).dialog_text, "该身份需要轮回天赋『苍玄行者』解锁",
			"未解锁应提示轮回天赋")
	assert_true((screen.get_node("LayoutAnchor/ConfirmButton") as Button).disabled,
			"确认按钮应保持禁用")


func test_ready_card_click_selects_and_enables_confirm() -> void:
	# Act
	var screen: Control = _mount()
	_click(screen, 0)

	# Assert
	assert_eq(screen.selected_id, &"azure_sword_disciple", "可开局身份应可选中")
	assert_false((screen.get_node("LayoutAnchor/ConfirmButton") as Button).disabled,
			"选中可开局身份后确认按钮应可用")
	assert_false(_toast(screen).visible, "正常选中不应弹提示")


func test_confirm_press_with_stale_not_open_selection_is_blocked() -> void:
	## 选中态过期（条目重读后不再可开局）——确认路径必须再拦一次。
	# Arrange —— 先正常选中，再把选中条目换成「暂未开放」
	var screen: Control = _mount()
	_click(screen, 0)
	screen.selected_entry = NOT_OPEN_ENTRY.duplicate()

	# Act
	screen._on_confirm_pressed()

	# Assert
	assert_false(screen.get_node("ConfirmDialog").visible, "不应弹出确认弹窗")
	assert_eq(_toast(screen).dialog_text, "该身份暂未开放", "应提示暂未开放")


func test_apply_identity_failure_shows_player_visible_toast() -> void:
	## 门禁全过但 apply 仍失败（资产在会话中途变了）——必须让玩家看见，不静默。
	# Arrange
	var screen: Control = _mount()
	var mock_isys: MockIdentitySystem = screen.identity_system
	mock_isys.apply_result = false
	_click(screen, 0)

	# Act
	screen._on_confirm_dialog_confirmed()

	# Assert
	assert_eq(mock_isys.applied, [&"azure_sword_disciple"], "应确实尝试过 apply")
	assert_true(_toast(screen).visible, "apply 失败应弹可见提示")
	assert_true(_toast(screen).dialog_text.contains("暂未开放"),
			"失败提示应说明原因，而不是只打日志")


func test_apply_identity_success_starts_narrative_and_requests_navigation() -> void:
	# Arrange
	var screen: Control = _mount()
	var mock_isys: MockIdentitySystem = screen.identity_system
	_click(screen, 0)

	# Act
	screen._on_confirm_dialog_confirmed()

	# Assert
	assert_eq(mock_isys.applied, [&"azure_sword_disciple"], "成功路径应调用 apply_identity")
	assert_true((screen.get_node("NarrativeOverlay") as Control).visible,
			"成功后应进入开局叙事")
	assert_false(_toast(screen).visible, "成功路径不应弹失败提示")
