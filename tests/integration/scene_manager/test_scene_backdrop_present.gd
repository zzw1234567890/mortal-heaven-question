extends GutTest
## 战斗 / 渡劫薄容器的深色背板回归。
##
## [b]背景[/b]（一周目界面走查 2026-11-22）：这两个容器此前没有任何背景绘制节点，
## 玩家看到的整屏底色是 [b]Godot 默认清屏色[/b] [code]Color(0.3, 0.3, 0.3)[/code]
## （实测战斗屏 93.3% 像素 = RGB(76,76,76)）——四屏里唯一没有项目深色基底的界面。
## 其余三屏（主菜单 / 地图选择 / 节点图）都在 tscn 里自带 [code]ColorRect[/code]
## 背板，用的是同一支项目基准色 [code]Color(0.071, 0.071, 0.086)[/code]
## （见 [code]MainMenu.tscn[/code]、[code]map_select_screen.tscn[/code]）。[br]
## [br][b]为什么加在容器上而不是 [code]CombatRoot.tscn[/code][/b]：后者有子节点
## 顺序硬契约（[code]test_layout_mount_facade.gd[/code] 逐项比较整个子节点数组），
## 插任何节点都会打破它；容器的既有测试按名取件，与子节点数量无关。[br]
## [br][b]为什么不挂进场景树[/b]：本文件只验结构（节点在场 / 类型 / 锚点 / 颜色 /
## 绘制次序），[code]instantiate()[/code] 不进树即可拿到完整节点结构，
## 且不会触发 [code]_ready[/code] 的开战与转场接线——确定性最好。

## 项目深色基底（与 MainMenu.tscn / map_select_screen.tscn 的 Background 同值）。
const BG_COLOR: Color = Color(0.071, 0.071, 0.086, 1)

const CombatScenePath: String = "res://src/feature/combat/combat_scene.tscn"
const TribulationScenePath: String = "res://src/feature/tribulation/tribulation_scene.tscn"

var _roots: Array[Node] = []


func after_each() -> void:
	for root: Node in _roots:
		if is_instance_valid(root):
			root.free()
	_roots.clear()


## 加载并实例化（不进树），登记以便 after_each 释放。
func _spawn(p_path: String) -> Node:
	var packed: PackedScene = load(p_path) as PackedScene
	assert_not_null(packed, "%s 应能加载" % p_path)
	var root: Node = packed.instantiate()
	_roots.append(root)
	return root


## 背板节点：名为 Background 的 ColorRect，全屏锚点，项目基准色，且排在首位（在最底层）。
func _assert_backdrop(p_path: String) -> void:
	var root: Node = _spawn(p_path)
	var bg: Node = root.get_node_or_null(NodePath("Background"))
	assert_not_null(bg, "%s 应挂有 Background 背板" % p_path)
	if bg == null:
		return
	assert_true(bg is ColorRect, "Background 应为 ColorRect（纯色填充，无纹理依赖）")
	if not (bg is ColorRect):
		return
	assert_eq(root.get_child(0).name, StringName("Background"),
			"Background 必须是第一个子节点——否则会盖在战斗区之上")
	assert_almost_eq((bg as ColorRect).anchor_right, 1.0, 0.001, "背板应右锚到满屏")
	assert_almost_eq((bg as ColorRect).anchor_bottom, 1.0, 0.001, "背板应下锚到满屏")
	assert_eq((bg as ColorRect).color, BG_COLOR,
			"背板应为项目深色基底，而不是 Godot 默认清屏色 Color(0.3, 0.3, 0.3)")
	assert_eq((bg as ColorRect).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"背板不得拦截鼠标（点选要落到战场控件上）")


func test_combat_scene_has_dark_backdrop() -> void:
	_assert_backdrop(CombatScenePath)


func test_tribulation_scene_has_dark_backdrop() -> void:
	_assert_backdrop(TribulationScenePath)


func test_backdrop_color_is_not_godot_default_clear_color() -> void:
	# 反向断言：默认清屏色正是本轮要消灭的那块灰，任何界面都不该拿它当基底。
	assert_ne(BG_COLOR, Color(0.3, 0.3, 0.3), "基准色不应等于 Godot 默认清屏色")
	assert_lt(BG_COLOR.get_luminance(), 0.1, "基底亮度应落在暗调区间")
