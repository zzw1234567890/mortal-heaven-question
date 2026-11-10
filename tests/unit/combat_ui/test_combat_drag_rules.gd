extends GutTest
## 拖拽启动阈值与按压状态机（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]验收点[/b]：GDD「鼠标移动 ≥8px 后启动拖拽」——7px 不启动、8px 启动、
## 9px 启动；释放时区分点击与拖拽。纯函数 / 纯状态，零依赖。

const Rules := preload("res://src/ui/combat/shared/combat_drag_rules.gd")
const Gesture := preload("res://src/ui/combat/interaction/combat_gesture_model.gd")

const ORIGIN: Vector2 = Vector2(100.0, 100.0)


## 阈值边界：7px 不启动，8px 启动，9px 启动（含边界）。
func test_threshold_boundary() -> void:
	assert_false(Rules.should_start(ORIGIN, ORIGIN + Vector2(7.0, 0.0)), "7px 不启动")
	assert_true(Rules.should_start(ORIGIN, ORIGIN + Vector2(8.0, 0.0)), "8px 启动（含边界）")
	assert_true(Rules.should_start(ORIGIN, ORIGIN + Vector2(9.0, 0.0)), "9px 启动")


## 对角线距离按欧氏距离判定（不是只看单轴）。
func test_threshold_uses_euclidean_distance() -> void:
	# (6,6) 的欧氏距离 ≈ 8.49 > 8 → 启动；(5,5) ≈ 7.07 → 不启动
	assert_false(Rules.should_start(ORIGIN, ORIGIN + Vector2(5.0, 5.0)), "5,5 不启动")
	assert_true(Rules.should_start(ORIGIN, ORIGIN + Vector2(6.0, 6.0)), "6,6 启动")


## 阈值可注入（测试与调参用）。
func test_threshold_injectable() -> void:
	assert_true(Rules.should_start(ORIGIN, ORIGIN + Vector2(4.0, 0.0), 4.0),
			"自定义阈值 4px 时 4px 启动")


## 点击判定：从未启动拖拽才算点击。
func test_click_predicate() -> void:
	assert_true(Rules.is_click(false), "未拖拽 → 点击")
	assert_false(Rules.is_click(true), "已拖拽 → 不是点击")


# ═══════════════════════════════════════════════════════════════════════════════
# 按压状态机
# ═══════════════════════════════════════════════════════════════════════════════

## 按下后小幅移动 → 释放是点击。
func test_press_move_small_releases_as_click() -> void:
	var gesture: RefCounted = Gesture.new()
	gesture.call(&"press", 7, ORIGIN)
	gesture.call(&"move", ORIGIN + Vector2(3.0, 0.0))
	var outcome: Dictionary = gesture.call(&"release")
	assert_eq(int(outcome["kind"]), Gesture.KIND_CLICK, "小幅移动 → 点击")
	assert_eq(int(outcome["card_id"]), 7, "卡 ID 保留")


## 按下后越过阈值 → 释放是拖拽；move 只在首次越过时返回 true。
func test_press_move_large_releases_as_drag() -> void:
	var gesture: RefCounted = Gesture.new()
	gesture.call(&"press", 7, ORIGIN)
	assert_true(bool(gesture.call(&"move", ORIGIN + Vector2(10.0, 0.0))), "首次越过报一次")
	assert_false(bool(gesture.call(&"move", ORIGIN + Vector2(20.0, 0.0))), "继续移动不重复报")
	var outcome: Dictionary = gesture.call(&"release")
	assert_eq(int(outcome["kind"]), Gesture.KIND_DRAG, "越过阈值 → 拖拽")


## 未按下就释放 → 无事件（不误触出牌）。
func test_release_without_press_is_none() -> void:
	var gesture: RefCounted = Gesture.new()
	var outcome: Dictionary = gesture.call(&"release")
	assert_eq(int(outcome["kind"]), Gesture.KIND_NONE, "无按压 → 无事件")
	assert_eq(int(outcome["card_id"]), -1, "无卡")


## 取消后释放不再产生事件（右键 / 弹窗中断）。
func test_cancel_discards_press() -> void:
	var gesture: RefCounted = Gesture.new()
	gesture.call(&"press", 7, ORIGIN)
	gesture.call(&"cancel")
	assert_false(bool(gesture.call(&"is_pressed")), "取消后不再按压")
	assert_eq(int(gesture.call(&"release")["kind"]), Gesture.KIND_NONE, "取消后释放无事件")


## 按在空白处（card_id = -1）也记录，释放时 kind 仍是点击（由调用方分流）。
func test_press_on_blank_tracks_card_sentinel() -> void:
	var gesture: RefCounted = Gesture.new()
	gesture.call(&"press", -1, ORIGIN)
	var outcome: Dictionary = gesture.call(&"release")
	assert_eq(int(outcome["kind"]), Gesture.KIND_CLICK, "空白按压也算一次点击")
	assert_eq(int(outcome["card_id"]), -1, "卡 ID 为 -1")
