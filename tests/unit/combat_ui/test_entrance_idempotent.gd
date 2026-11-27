extends GutTest
## 进场过渡的幂等性（2026-11-27 regression）。
##
## 背景：底条进场曾用 `bottombar.position.y += SLIDE_OFFSET_PX` 做起始态，只在 Tween
## 结束时减回来。中途被 [method kill]（重复进场 / 部署面板打断）或走 reduce_motion
## 分支时位置不复位，底条就永久停在基准下方 60px——「结束回合」按钮因此落到 1080
## 视口之外，看着在屏幕上、点下去没有任何反应。
##
## 这里只测纯对象行为（不依赖 combat_scene），断言三件事：
## 1) 重复进场不累加位移；
## 2) kill 打断把位置拉回基准；
## 3) reduce_motion 路径也回到基准且 alpha 归 1。

const EntranceScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_layout_entrance_mount.gd")
const BASE_Y: float = 100.0
const BAR_BASE_Y: float = 900.0

var _root: Control = null
var _topbar: Control = null
var _enemy: Control = null
var _ally: Control = null
var _bar: Control = null
var _mount: RefCounted = null


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_root)
	_topbar = _zone("TopBar", BASE_Y)
	_enemy = _zone("EnemyArea", 200.0)
	_ally = _zone("AllyArea", 560.0)
	_bar = _zone("BottomBar", BAR_BASE_Y)
	_mount = EntranceScript.new(_root)


func _zone(p_name: String, p_y: float) -> Control:
	var node := Control.new()
	node.name = p_name
	node.position = Vector2(0.0, p_y)
	node.size = Vector2(1920.0, 100.0)
	_root.add_child(node)
	return node


func _play(p_reduce_motion: bool = false) -> void:
	_mount.play(_topbar, _enemy, _ally, _bar, p_reduce_motion)


# ── 1. 重复进场不累加 ────────────────────────────────────────────────────────


## 起始位移永远相对基准算：连开三轮，每轮的起始位都是「基准 ± 60」而不是越叠越远。
## （不靠等 Tween 跑完——headless 下帧时间极短，等帧数不等于等时间。）
func test_each_play_starts_from_the_base_offset_not_the_previous_one() -> void:
	for i: int in range(3):
		_play()
		assert_almost_eq(_bar.position.y, BAR_BASE_Y + EntranceScript.SLIDE_OFFSET_PX,
				0.5, "第 %d 轮起始位应是基准 +60（不累加）" % (i + 1))
		assert_almost_eq(_topbar.position.y, BASE_Y - EntranceScript.SLIDE_OFFSET_PX,
				0.5, "第 %d 轮顶条起始位应是基准 -60（不累加）" % (i + 1))
		_mount.kill()
		assert_almost_eq(_bar.position.y, BAR_BASE_Y, 0.5,
				"第 %d 轮打断后底条回到基准" % (i + 1))


# ── 2. kill 打断必须复位 ────────────────────────────────────────────────────


func test_kill_during_delay_restores_bottom_bar() -> void:
	_play()
	# 底条有 0.3s 延迟：此刻它还停在「基准 + 60」上，正是被打断会出事的窗口
	assert_almost_eq(_bar.position.y, BAR_BASE_Y + EntranceScript.SLIDE_OFFSET_PX,
			0.5, "延迟窗口内底条应处于下滑起始位")
	_mount.kill()
	assert_almost_eq(_bar.position.y, BAR_BASE_Y, 0.5,
			"kill 后底条必须复位到基准，否则按钮会落到视口外")


func test_kill_during_delay_restores_top_bar() -> void:
	_play()
	assert_almost_eq(_topbar.position.y, BASE_Y - EntranceScript.SLIDE_OFFSET_PX,
			0.5, "顶条起始位在基准上方")
	_mount.kill()
	assert_almost_eq(_topbar.position.y, BASE_Y, 0.5, "kill 后顶条复位")


func test_repeated_interrupt_never_accumulates() -> void:
	for i: int in range(5):
		_play()
		_mount.kill()
		assert_almost_eq(_bar.position.y, BAR_BASE_Y, 0.5,
				"第 %d 次打断后仍应在基准" % (i + 1))


# ── 3. reduce_motion 路径 ──────────────────────────────────────────────────


func test_reduce_motion_settles_at_base_and_full_alpha() -> void:
	_play(true)
	assert_almost_eq(_bar.position.y, BAR_BASE_Y, 0.5, "减少动态时底条直接就位")
	assert_almost_eq(_topbar.position.y, BASE_Y, 0.5, "减少动态时顶条直接就位")
	for node: Control in [_topbar, _enemy, _ally, _bar]:
		assert_almost_eq(node.modulate.a, 1.0, 0.01, "%s alpha 应为 1" % node.name)
	assert_null(_mount.tween, "减少动态路径不建 Tween")


func test_reduce_motion_after_interrupted_play_restores_position() -> void:
	_play()
	_mount.kill()
	_play(true)
	assert_almost_eq(_bar.position.y, BAR_BASE_Y, 0.5,
			"被打断后再走减少动态分支，仍要落在基准")
