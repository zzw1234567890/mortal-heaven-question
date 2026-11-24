extends GutTest
## 节点图顶栏被 HUD 压住 ——「点了『退出探索』没反应」。[br]
## [br][b]本文件补的缺口[/b]：[code]test_top_bar_layout.gd[/code] 量的是顶栏[b]内部[/b]
## 的分栏（退出键 ↔ 提示位 / AP 行的矩形不相交），没有一条量到[b]顶栏与全局 HUD 的
## 关系[/b]。而 HUD 是 [code]CanvasLayer.layer = 90[/code] 的常驻层，探索场景里它可见
## （[code]hud.gd[/code] 的可见性矩阵 [code]3: true[/code]），它的「境界修为」区落在
## 左上角 [code](16,12)-(256,72)[/code]，正是节点图顶栏放「退出探索」的位置。[br]
## [br][b]为什么这是断链而不是观感问题[/b]：两块矩形重叠时，Godot 的控件拾取先按
## [code]CanvasLayer.layer[/code] 降序排（HUD 的 90 在场景层之上），落在按钮上的左键
## 于是被 [code]RealmBar[/code] 吃掉——它的根节点 [code]mouse_filter = STOP[/code]
## （[code]realm_bar.gd[/code] 的 G8 裁决，为 tooltip 悬停而设）。鼠标点不动
## 「退出探索」，探索结束这条主动退路就断了。[br]
## [br][b]为什么实例化真实场景 + 真实投递[/b]：偏移写在两个 [code].tscn[/code] 里，
## 读文本算坐标是绕过引擎的做法；只有把两个场景都挂进树、再经
## [code]Viewport.push_input[/code] 投一次真左键，量到的才是「玩家点得到点不到」本身。[br]
## [br][b]覆盖[/b]：[br]
##   1. [b]正对照[/b]：HUD 不可见时，同一坐标的左键必须落到「退出探索」按钮上
##      （否则本用例是空过的——它得先证明「这一下本来点得动」）；[br]
##   2. [b]断链[/b]：HUD 可见（探索场景的真实状态）时，同一坐标的左键仍必须落到按钮上；[br]
##   3. 顶栏左侧元素整体让开 HUD 左上角锚区（[constant TopBarLayout.HUD_LEFT_ANCHOR_EDGE]）。
##
## 来源: 第二轮真机试玩走查（[code]tools/playtest2_driver.gd[/code]，不提交）——
## 「退出探索→选图 ❌ | 退出键命中=RealmBar｜弹窗可见=null」、
## design/ux/exploration-ui.md §Layout Zones（顶部条归探索 UI）、
## design/ux/hud.md「元素 1 / 场景表」（境界修为区左上，探索可见）、
## src/ui/hud/hud.gd（可见性矩阵）、src/ui/shared/top_bar_layout.gd（分栏口径的唯一落点）。

const GraphScene: PackedScene = preload("res://src/ui/exploration/node_graph_screen.tscn")
const HudScene: PackedScene = preload("res://src/ui/hud/HUD.tscn")
const TopBarLayoutScript := preload("res://src/ui/shared/top_bar_layout.gd")

## 布局落定需要的帧数——场景挂载后要等一次 NOTIFICATION_SORT_CHILDREN。
const SETTLE_FRAMES: int = 3

var _graph: Control = null
var _hud: CanvasLayer = null


func after_each() -> void:
	_free(_hud)
	_free(_graph)


func _free(p_node: Node) -> void:
	if p_node != null and is_instance_valid(p_node):
		p_node.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 挂「节点图 + HUD 常驻层」——层级关系与探索场景一致（HUD 在 90 层，场景在默认层）。[br]
## [br][b]为什么不调 [code]HUD.setup(sm)[/code][/b]：[code]setup[/code] 的职责是订阅转场
## 信号与同步初始可见性；本用例要的只是「内容分支可见」这一个事实，直接置位比起搭一套
## SceneManager mock 更贴近被验证的东西。[br]
## [br][b]返回[/b]：挂好的节点图屏（HUD 存进成员变量供后续开关）。
## [br][b]为什么用 [code]add_child[/code] 而不是 [code]add_child_autofree[/code][/b]：
## [method after_each] 已经显式释放，两条路都挂会让「已释放的引用」在断言信息里
## 打转（先例：本仓库其余集成用例二选一，不并用）。
func _mount(p_hud_visible: bool) -> Control:
	_graph = GraphScene.instantiate()
	_graph.set(&"animate", false)
	add_child(_graph)
	_hud = HudScene.instantiate()
	add_child(_hud)
	await _settle()
	(_hud.get_node(^"ContentLayer") as Control).visible = p_hud_visible
	await _settle()
	return _graph


func _settle() -> void:
	for _i: int in range(SETTLE_FRAMES):
		await get_tree().process_frame


## 「退出探索」按钮（节点图顶栏的第一个按钮）。[br]
## [br][b]按文案找而不是按节点路径[/b]：玩家眼里只有「退出探索」四个字；按文案找
## 顺带验证了按钮上写的就是这四个字。
func _exit_button(p_graph: Control) -> Button:
	for node: Node in _walk(p_graph):
		if node is Button and (node as Button).text == "退出探索":
			return node as Button
	return null


## 在控件的中心投一次真左键（按下 + 抬起），返回投递坐标。[br]
## [br][b]为什么 [code]push_input[/code] 而不是直发 [code]pressed[/code][/b]：
## 被验证的正是「引擎把这一下派给了谁」——直发信号把拾取这一步整个跳过了。[br]
## [br][b]第二参数为 true[/b]：坐标已是视口坐标，不再经 [code]canvas_items[/code] 拉伸换算。[br]
## [br][b]不做候选点重试[/b]：与 [code]PlaytestQuery.click_control[/code] 不同——那边是
## 「想办法点到」，这边要量的是「玩家点在正中间那一下会怎样」，重试会把结论洗掉。
func _click(p_control: Control) -> Vector2:
	var point: Vector2 = p_control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = point
		ev.global_position = point
		get_viewport().push_input(ev, true)
	return point


## 「退出探索」被按下后应弹出的确认框（节点图屏自带）是否已可见。
func _exit_dialog_open(p_graph: Control) -> bool:
	var dialog: Window = p_graph.get_node_or_null(^"ExitDialog") as Window
	return dialog != null and dialog.visible


func _walk(p_node: Node) -> Array:
	var out: Array = []
	if p_node == null:
		return out
	for child: Node in p_node.get_children():
		out.append(child)
		out.append_array(_walk(child))
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 正对照：HUD 不可见时这一下本来点得动
# ═══════════════════════════════════════════════════════════════════════════════

func test_exit_button_click_works_without_hud_overlay() -> void:
	# Arrange
	var graph: Control = await _mount(false)
	var exit_button: Button = _exit_button(graph)
	assert_not_null(exit_button, "节点图顶栏应有『退出探索』按钮")
	if exit_button == null:
		return
	# Act
	_click(exit_button)
	await _settle()
	# Assert——正对照：没有 HUD 压着时，这一下必须落到按钮上
	assert_true(_exit_dialog_open(graph),
			"没有 HUD 覆盖时点『退出探索』应弹出确认框（正对照——其余用例靠它才不是空过）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 断链：探索场景的真实状态（HUD 可见）下，同一坐标的左键到不了按钮
# ═══════════════════════════════════════════════════════════════════════════════

func test_exit_button_click_survives_hud_overlay() -> void:
	# Arrange
	var graph: Control = await _mount(true)
	var exit_button: Button = _exit_button(graph)
	assert_not_null(exit_button, "节点图顶栏应有『退出探索』按钮")
	if exit_button == null:
		return
	# Act——同一个坐标，与正对照的唯一差别是 HUD 内容分支可见
	_click(exit_button)
	await _settle()
	# Assert
	assert_true(_exit_dialog_open(graph),
			"探索场景里 HUD 在 90 层且内容分支可见，但点在『退出探索』按钮上的左键仍应被按钮收到"
			+ "（被 HUD 的境界修为区吃掉 = 玩家鼠标点不动这一下）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 分栏口径：顶栏左侧元素整体让开 HUD 左上角锚区
# ═══════════════════════════════════════════════════════════════════════════════

func test_top_bar_left_group_clears_hud_left_anchor() -> void:
	# Arrange
	var graph: Control = await _mount(true)
	var exit_button: Button = _exit_button(graph)
	assert_not_null(exit_button, "节点图顶栏应有『退出探索』按钮")
	if exit_button == null:
		return
	var hud_bar: Control = _hud.get_node_or_null(^"ContentLayer/RealmBarArea/RealmBar") as Control
	assert_not_null(hud_bar, "HUD 应有左上角境界修为区")
	if hud_bar == null:
		return
	# Act——顶栏左侧元素与 HUD 左上角锚区是否真的分了家
	var bar_rect: Rect2 = exit_button.get_global_rect()
	var hud_rect: Rect2 = hud_bar.get_global_rect()
	var overlap: float = bar_rect.intersection(hud_rect).get_area()
	# Assert——不相交（相切算过：没有像素重叠就没有「压在一起」）
	assert_lte(overlap, 0.0,
			"顶栏『退出探索』%s 与 HUD 境界修为区 %s 不应有像素重叠，实际重叠 %.0f px²"
			% [bar_rect, hud_rect, overlap])
	assert_gte(bar_rect.position.x, TopBarLayoutScript.HUD_LEFT_ANCHOR_EDGE,
			"顶栏左侧元素应从 HUD 左上角锚区右缘（%.0fpx）之后起，实际 %.0fpx"
			% [TopBarLayoutScript.HUD_LEFT_ANCHOR_EDGE, bar_rect.position.x])
