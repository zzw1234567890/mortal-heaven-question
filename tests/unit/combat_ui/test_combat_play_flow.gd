extends GutTest
## 出牌手势语义（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 点卡 = 选中；再点同一张 = 确认（不误出）；[br]
##   2. 单体卡点目标 = 立即确认；再点另一个目标[b]替换[/b]（不累加）；[br]
##   3. 多选卡点目标 = 累加，点卡才确认；[br]
##   4. 拖拽释放到目标 = 必定确认；释放到空白 = 取消、不出牌。[br]
## [br]全部使用注入桩（真实控制器 + 桩桥 + 桩数据供给）——不触碰 Autoload。

const Flow := preload("res://src/ui/combat/shared/combat_play_flow.gd")
const Controller := preload("res://src/ui/combat/shared/combat_play_controller.gd")
const Selection := preload("res://src/ui/combat/shared/hand_selection_model.gd")
const PlayResult := preload("res://src/feature/combat/combat_play_result.gd")
const Policy := preload("res://src/ui/combat/shared/combat_target_policy.gd")

const CARD_SINGLE: int = 31
const CARD_MULTI: int = 32
const CARD_SELF: int = 33
const ENEMY_A: int = 9001
const ENEMY_B: int = 9002


## 桩出牌桥——记录调用并返回成功。
class BridgeStub extends RefCounted:
	var calls: Array = []
	var result: Dictionary = {}

	func play_card_detailed(card_instance_id: int, targets: Array) -> Dictionary:
		calls.append({"card_instance_id": card_instance_id,
			"targets": targets.duplicate()})
		return result if not result.is_empty() else PlayResult.ok()

	func resolve_targets(explicit: Array) -> Dictionary:
		return {"targets": explicit.duplicate(), "source": 2,
			"reason": &"explicit_verified"}


## 桩数据供给——卡面目标词 / 可负担 / 敌方判定。
class ProviderStub extends RefCounted:
	var types: Dictionary = {}
	var affordable: bool = true
	var psychic: bool = false
	var enemies: Array = [ENEMY_A, ENEMY_B]

	func target_type_of(card_instance_id: int) -> StringName:
		return types.get(card_instance_id, &"")

	func can_afford(_card_instance_id: int) -> bool:
		return affordable

	func is_psychic() -> bool:
		return psychic

	func is_enemy_target(character_id: int) -> bool:
		return enemies.has(character_id)

	func all_enemy_ids() -> Array:
		return enemies.duplicate()


var bridge: BridgeStub = null
var provider: ProviderStub = null
var controller: RefCounted = null
var flow: RefCounted = null


func before_each() -> void:
	bridge = BridgeStub.new()
	provider = ProviderStub.new()
	provider.types = {
		CARD_SINGLE: &"single_enemy", CARD_MULTI: &"multi_enemy", CARD_SELF: &"self",
	}
	controller = Controller.new()
	controller.call(&"setup", bridge, Selection.new())
	flow = Flow.new()
	flow.call(&"setup", controller, provider)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 点卡：选中 / 再点确认
# ═══════════════════════════════════════════════════════════════════════════════

## 点卡 → 选中，不发请求。
func test_click_card_selects_without_playing() -> void:
	# Act
	var out: Dictionary = flow.call(&"click_card", CARD_SINGLE)
	# Assert
	assert_eq(out["status"], Flow.STATUS_SELECTED, "选中")
	assert_eq(int(controller.call(&"get_selected_card_id")), CARD_SINGLE, "控制器持有选中")
	assert_eq(bridge.calls.size(), 0, "未出牌")


## 再点同一张卡 → 确认出牌（点两下是明确的出牌意图）。
func test_second_click_on_same_card_plays() -> void:
	# Arrange
	flow.call(&"click_card", CARD_SINGLE)
	# Act
	var out: Dictionary = flow.call(&"click_card", CARD_SINGLE)
	# Assert
	assert_eq(out["status"], Flow.STATUS_PLAYED, "出牌成功")
	assert_eq(bridge.calls.size(), 1, "请求到达桥")
	assert_eq(int(bridge.calls[0]["card_instance_id"]), CARD_SINGLE, "卡 ID 正确")


## 点另一张卡 → 切换选中，不误出上一张。
func test_click_other_card_switches_selection() -> void:
	flow.call(&"click_card", CARD_SINGLE)
	var out: Dictionary = flow.call(&"click_card", CARD_MULTI)
	assert_eq(out["status"], Flow.STATUS_SELECTED, "切换选中")
	assert_eq(int(controller.call(&"get_selected_card_id")), CARD_MULTI, "选中换卡")
	assert_eq(bridge.calls.size(), 0, "未出牌")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 单体：点目标即确认；第二个目标替换
# ═══════════════════════════════════════════════════════════════════════════════

## 单体卡点目标 → 立即出牌，目标为该敌人。
func test_single_card_click_target_plays_immediately() -> void:
	# Arrange
	flow.call(&"click_card", CARD_SINGLE)
	# Act
	var out: Dictionary = flow.call(&"click_target", ENEMY_B)
	# Assert
	assert_eq(out["status"], Flow.STATUS_PLAYED, "点目标即出牌")
	assert_eq(bridge.calls[0]["targets"], [ENEMY_B], "打的是点的那个")


## [b]单目标卡拒绝多选[/b]：先点 A 再点 B → 目标是 B（替换，不是 [A,B]）。[br]
## [br][b]为什么锁这条[/b]：单目标卡选两个目标会让「打谁」含糊，系统侧会结算两次。
func test_single_card_rejects_multiple_targets() -> void:
	# Arrange——用不立即确认的路径（拖拽）观察目标列表
	flow.call(&"click_card", CARD_SINGLE)
	flow.call(&"click_target", ENEMY_A)
	# 第一次点击已确认出牌并清选中；重新选卡再点第二个目标
	flow.call(&"click_card", CARD_SINGLE)
	flow.call(&"click_target", ENEMY_B)
	# Assert
	assert_eq(bridge.calls.size(), 2, "两次独立出牌")
	assert_eq(bridge.calls[0]["targets"], [ENEMY_A], "第一次打 A")
	assert_eq(bridge.calls[1]["targets"], [ENEMY_B], "第二次只打 B（未累加 A）")


## 单体卡的拖拽释放也只有一个目标（多目标卡才累加）。
func test_single_card_drop_holds_single_target() -> void:
	var out: Dictionary = flow.call(&"drop", CARD_SINGLE, ENEMY_A)
	assert_eq(out["status"], Flow.STATUS_PLAYED, "拖拽即出牌")
	assert_eq(bridge.calls[0]["targets"], [ENEMY_A], "单目标")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 多选：累加，点卡确认
# ═══════════════════════════════════════════════════════════════════════════════

## 多选卡点两个目标 → 未出牌；再点卡 → 两个目标一起出。
func test_multi_card_accumulates_then_confirms() -> void:
	# Arrange
	flow.call(&"click_card", CARD_MULTI)
	# Act
	var first: Dictionary = flow.call(&"click_target", ENEMY_A)
	var second: Dictionary = flow.call(&"click_target", ENEMY_B)
	var picked_before: Array = flow.call(&"picked_targets")
	var played: Dictionary = flow.call(&"click_card", CARD_MULTI)
	# Assert
	assert_eq(first["status"], Flow.STATUS_TARGET_PICKED, "首个目标只记录")
	assert_eq(second["status"], Flow.STATUS_TARGET_PICKED, "第二个目标只记录")
	assert_eq(picked_before, [ENEMY_A, ENEMY_B], "两个目标都持有（确认前）")
	assert_eq(played["status"], Flow.STATUS_PLAYED, "点卡确认出牌")
	assert_eq(bridge.calls[0]["targets"], [ENEMY_A, ENEMY_B], "多目标一起交给桥")


## 多选卡再点同一目标 → 取消该目标。
func test_multi_card_second_click_removes_target() -> void:
	flow.call(&"click_card", CARD_MULTI)
	flow.call(&"click_target", ENEMY_A)
	flow.call(&"click_target", ENEMY_B)
	flow.call(&"click_target", ENEMY_A)
	assert_eq(flow.call(&"picked_targets"), [ENEMY_B], "A 被取消")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 自身 / 拖拽空白 / 非法目标
# ═══════════════════════════════════════════════════════════════════════════════

## 自身卡：点选后不接收目标，点卡确认时目标为空（治疗落施法者）。
func test_self_card_plays_without_targets() -> void:
	flow.call(&"click_card", CARD_SELF)
	var ignored: Dictionary = flow.call(&"click_target", ENEMY_A)
	assert_eq(ignored["status"], Flow.STATUS_IGNORED, "自身卡忽略目标点选")
	flow.call(&"click_card", CARD_SELF)
	assert_eq(bridge.calls.size(), 1, "确认时出牌")
	assert_eq(bridge.calls[0]["targets"], [], "目标为空")


## 拖拽释放到空白 → 取消选中，不出牌。
func test_drop_on_blank_cancels() -> void:
	flow.call(&"click_card", CARD_SINGLE)
	var out: Dictionary = flow.call(&"drop", CARD_SINGLE, -1)
	assert_eq(out["status"], Flow.STATUS_IGNORED, "空白释放忽略")
	assert_eq(bridge.calls.size(), 0, "不出牌")
	assert_eq(int(controller.call(&"get_selected_card_id")), Selection.NO_CARD,
			"选中被取消")


## 未选卡点敌方目标 → 忽略（玩家可能只是点到了空处）。
func test_click_target_without_selection_is_ignored() -> void:
	var out: Dictionary = flow.call(&"click_target", ENEMY_A)
	assert_eq(out["status"], Flow.STATUS_IGNORED, "未选卡忽略目标点选")


## 点非敌方目标（例如己方）→ 忽略，不进入目标列表。
func test_click_non_enemy_target_is_ignored() -> void:
	flow.call(&"click_card", CARD_MULTI)
	var out: Dictionary = flow.call(&"click_target", 555)
	assert_eq(out["status"], Flow.STATUS_IGNORED, "非敌方目标忽略")
	assert_eq(flow.call(&"picked_targets"), [], "目标列表未变")


## 费用不足：选中仍成立，确认时给出可显示的拒绝（保留选中可重试）。
func test_unaffordable_card_rejects_with_message() -> void:
	# Arrange
	provider.affordable = false
	flow.call(&"click_card", CARD_SINGLE)
	# Act
	var out: Dictionary = flow.call(&"click_target", ENEMY_A)
	# Assert
	assert_eq(out["status"], Flow.STATUS_REJECTED, "被拒")
	assert_eq((out["result"] as Dictionary)["reason"], PlayResult.REASON_COST_NOT_ENOUGH,
			"原因：费用不足")
	assert_false(String((out["result"] as Dictionary)["message"]).is_empty(), "有提示文本")
	assert_eq(bridge.calls.size(), 0, "本地拒绝不发请求")


## 无控制器（门面未装配）→ 拒绝且带提示，不崩。
func test_without_controller_degrades() -> void:
	var bare: RefCounted = Flow.new()
	bare.call(&"setup", null, provider)
	var out: Dictionary = bare.call(&"click_card", CARD_SINGLE)
	assert_eq(out["status"], Flow.STATUS_REJECTED, "无控制器 → 拒绝")
	assert_eq((out["result"] as Dictionary)["reason"], PlayResult.REASON_NO_COMBAT,
			"原因指向缺战斗系统")


## 卡离开手牌 → 选中自清（防幽灵选中）。
func test_sync_hand_clears_when_card_left() -> void:
	flow.call(&"click_card", CARD_MULTI)
	flow.call(&"click_target", ENEMY_A)
	flow.call(&"sync_hand", [CARD_SELF])
	assert_eq(int(controller.call(&"get_selected_card_id")), Selection.NO_CARD,
			"选中自清")
	assert_eq(flow.call(&"current_mode"), Policy.MODE_ANY, "模式一并复位")
