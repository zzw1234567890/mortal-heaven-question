extends GutTest
## 出牌交互闭环控制器（combat-ui-interaction 001）。[br]
## [br][b]背景[/b]：这是本 epic 第一块闭环的 Logic 内核——拖拽 / 数字键 / 手柄
## 只是它不同的触发方式，三条路径必须共用同一份「能不能出、出哪张、打谁、
## 被拒怎么说」的判定，否则三种输入会走出三种行为。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 未选卡 / 不可确认时 [b]不发请求[/b]，直接返回带提示的本地拒绝；[br]
##   2. 费用不足 → 拒绝结果带可显示的提示文本（[b]不静默失败[/b]）；[br]
##   3. 成功 → 清选中 + 广播 [code]card_played[/code]；失败 → [b]保留选中[/b]
##      + 广播 [code]play_rejected[/code]（玩家可改目标重试）；[br]
##   4. 目标经桥解析，全无效时挡住确认。[br]
## [br]全部使用注入桩——不触碰 Autoload / 文件系统。

const Controller := preload("res://src/ui/combat/shared/combat_play_controller.gd")
const Selection := preload("res://src/ui/combat/shared/hand_selection_model.gd")
const PlayResult := preload("res://src/feature/combat/combat_play_result.gd")
const TargetRules := preload("res://src/ui/combat/shared/combat_target_rules.gd")


## 桩出牌桥——记录调用并按预设结果返回。
class BridgeStub extends RefCounted:
	var calls: Array = []
	var result: Dictionary = {}
	var resolution: Dictionary = {}

	func play_card_detailed(card_instance_id: int, targets: Array) -> Dictionary:
		calls.append({"card_instance_id": card_instance_id,
			"targets": targets.duplicate()})
		return result if not result.is_empty() else PlayResult.ok()

	func resolve_targets(explicit: Array) -> Dictionary:
		if not resolution.is_empty():
			return resolution
		return {"targets": explicit.duplicate(), "source": 2, "reason": &"explicit_verified"}


var bridge: BridgeStub = null
var controller: RefCounted = null
var played: Array = []
var rejected: Array = []
var selections: Array = []


func before_each() -> void:
	bridge = BridgeStub.new()
	controller = Controller.new()
	controller.call(&"setup", bridge, Selection.new())
	played.clear()
	rejected.clear()
	selections.clear()
	controller.connect(&"card_played", func(result: Dictionary) -> void:
		played.append(result))
	controller.connect(&"play_rejected", func(result: Dictionary) -> void:
		rejected.append(result))
	controller.connect(&"selection_changed", func(card_id: int) -> void:
		selections.append(card_id))


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 前置拒绝：不发请求
# ═══════════════════════════════════════════════════════════════════════════════

## 没选卡就确认 → 本地拒绝，[b]不调用出牌桥[/b]。
func test_confirm_without_selection_rejects_locally() -> void:
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "无选中 → 拒绝")
	assert_eq(bridge.calls.size(), 0, "不发请求到桥")
	assert_eq(rejected.size(), 1, "广播 play_rejected")
	assert_eq(played.size(), 0, "未广播 card_played")


## 费用不足 → 拒绝且提示文本[b]非空[/b]（不静默失败），仍不发请求。
func test_unaffordable_confirm_rejects_with_message() -> void:
	# Arrange
	controller.call(&"select_card", 7, false, false)
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "费用不足 → 拒绝")
	assert_eq(out["reason"], PlayResult.REASON_COST_NOT_ENOUGH, "原因：费用不足")
	assert_false(String(out["message"]).is_empty(), "带可显示的提示文本")
	assert_eq(bridge.calls.size(), 0, "本地拒绝不发请求")


## 灵能预览态 → 拒绝（原因指向阶段）。
func test_psychic_confirm_rejects() -> void:
	# Arrange
	controller.call(&"select_card", 7, true, true)
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "灵能态不可出牌")
	assert_eq(out["reason"], PlayResult.REASON_WRONG_PHASE, "原因：阶段不对")


## 目标非法 → 拒绝（原因指向目标）。
func test_invalid_target_confirm_rejects() -> void:
	# Arrange——桥把显式目标判为全无效
	bridge.resolution = {"targets": [], "source": TargetRules.SOURCE_NONE,
		"reason": &"explicit_invalid"}
	controller.call(&"select_card", 7, true, false)
	controller.call(&"set_targets", [999])
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "目标非法 → 拒绝")
	assert_eq(out["reason"], PlayResult.REASON_BAD_TARGET, "原因：目标非法")
	assert_eq(bridge.calls.size(), 0, "本地拒绝不发请求")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 成功路径
# ═══════════════════════════════════════════════════════════════════════════════

## 可出牌 → 请求到达桥，成功后[b]清选中[/b]并广播 card_played。
func test_successful_play_clears_selection_and_broadcasts() -> void:
	# Arrange
	bridge.result = PlayResult.ok({"targets": [101], "cost": 2})
	controller.call(&"select_card", 7, true, false)
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_true(PlayResult.is_ok(out), "出牌成功")
	assert_eq(bridge.calls.size(), 1, "请求到达桥")
	assert_eq(int(bridge.calls[0]["card_instance_id"]), 7, "卡实例 ID 正确")
	assert_eq(played.size(), 1, "广播 card_played")
	assert_eq(rejected.size(), 0, "未广播拒绝")
	assert_eq(controller.call(&"get_selected_card_id"), Selection.NO_CARD,
			"出牌后清选中")


## 未显式指定目标 → 桥收到空目标（由桥走默认策略：首个存活敌人）。
func test_confirm_without_targets_sends_empty_list() -> void:
	# Arrange
	controller.call(&"select_card", 7, true, false)
	# Act
	controller.call(&"confirm")
	# Assert
	assert_eq(bridge.calls[0]["targets"], [], "空目标交桥解析（默认策略）")


## 显式指定目标 → 原样传给桥。
func test_explicit_targets_reach_bridge() -> void:
	# Arrange
	controller.call(&"select_card", 7, true, false)
	controller.call(&"set_targets", [103])
	# Act
	controller.call(&"confirm")
	# Assert
	assert_eq(bridge.calls[0]["targets"], [103], "显式目标传给桥")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 系统侧拒绝：保留选中
# ═══════════════════════════════════════════════════════════════════════════════

## 桥拒了（系统侧费用判定不过）→ [b]保留选中[/b]（玩家可等费用恢复后重试）。[br]
## [br][b]为什么不清选中[/b]：清掉会让玩家的手停在半空，且得重新找到那张卡；
## 保留选中意味着费用一恢复就能直接确认。
func test_bridge_rejection_keeps_selection() -> void:
	# Arrange
	bridge.result = PlayResult.fail(PlayResult.REASON_COST_NOT_ENOUGH,
			{"cost": 5, "current": 1})
	controller.call(&"select_card", 7, true, false)
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "桥拒绝")
	assert_eq(rejected.size(), 1, "广播 play_rejected")
	assert_eq(played.size(), 0, "未广播成功")
	assert_eq(controller.call(&"get_selected_card_id"), 7, "选中被保留")
	assert_false(String(out["message"]).is_empty(), "拒绝带提示文本")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 选中态信令与手牌同步
# ═══════════════════════════════════════════════════════════════════════════════

## 选中卡 → 广播 selection_changed（UI 据此落「抬起」视觉）。
func test_select_card_broadcasts_selection_change() -> void:
	# Act
	controller.call(&"select_card", 7, true, false)
	# Assert
	assert_eq(selections.size(), 1, "广播一次")
	assert_eq(int(selections[0]), 7, "载荷为选中的卡 ID")


## 取消选中 → 广播 NO_CARD；未选中时取消是[b]无操作[/b]（不白刷一帧）。
func test_cancel_broadcasts_and_is_idempotent() -> void:
	# Arrange
	controller.call(&"select_card", 7, true, false)
	# Act
	controller.call(&"cancel")
	controller.call(&"cancel")  # 幂等
	# Assert
	assert_eq(selections.size(), 2, "选中 + 取消各一次，第二次取消不发")
	assert_eq(int(selections[1]), Selection.NO_CARD, "取消载荷为无选中")


## 选中的卡离开手牌 → 自清并广播（防幽灵选中）。
func test_sync_hand_clears_and_broadcasts() -> void:
	# Arrange
	controller.call(&"select_card", 7, true, false)
	# Act
	var cleared: bool = bool(controller.call(&"sync_hand", [8]))
	# Assert
	assert_true(cleared, "自清发生")
	assert_eq(controller.call(&"get_selected_card_id"), Selection.NO_CARD, "选中清空")
	assert_eq(selections.size(), 2, "广播了自清后的状态")


## 桥未注入（门面在装配台缺失时的降级态）→ 确认给出「战斗系统未就绪」而非崩溃，
## 也[b]不谎报「找不到卡」[/b]（选中本身是成立的，缺的是出牌通道）。
func test_confirm_without_bridge_degrades_gracefully() -> void:
	# Arrange——控制器持有 null 桥
	var bare: RefCounted = Controller.new()
	bare.call(&"setup", null, Selection.new())
	bare.call(&"select_card", 7, true, false)
	assert_true(bare.call(&"can_confirm"), "选中本身仍成立")
	# Act——确认不应崩溃
	var out: Dictionary = bare.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "无桥 → 拒绝")
	assert_eq(out["reason"], PlayResult.REASON_NO_COMBAT, "原因指向缺战斗系统")
	assert_false(String(out["message"]).is_empty(), "带可显示的提示文本")


## can_confirm 与选中模型一致（UI 的确认手势先问这里）。
func test_can_confirm_mirrors_selection_state() -> void:
	# Assert——未选中
	assert_false(bool(controller.call(&"can_confirm")), "无选中不可确认")
	# Act——选中充足费用的卡
	controller.call(&"select_card", 7, true, false)
	# Assert
	assert_true(bool(controller.call(&"can_confirm")), "选中后可确认")
	# Act——费用被花掉
	controller.call(&"refresh_playability", false, false)
	assert_false(bool(controller.call(&"can_confirm")), "费用变化后不可确认")
