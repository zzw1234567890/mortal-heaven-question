extends GutTest
## 两个界面顶栏的[b]分栏[/b] —— 「左上角与右上角元素重叠（图标与文字压在一起）」。[br]
## [br][b]本文件补的缺口[/b]：节点图顶栏的「退出探索」按钮、AP 行、走投无路提示
## 与地图选择顶栏的标题 / 灵石余额，此前各写各的偏移量（按钮距左 16px、AP 距右
## 16px、标题右缘 -420 对余额左缘 -400 只隔 20px）——没有一处是错的，但也没有
## 一处是同一套口径，窄分辨率下重叠是必然。[br]
## [br][b]覆盖[/b]：[br]
##   1. 两个界面里左右两组元素[b]互不相交[/b]（这是玩家看到的那件事本身）；[br]
##   2. 中间留出 ≥ [constant TopBarLayout.MIDDLE_GAP_MIN] 的空白给标题类文字；[br]
##   3. 右侧元素右缘距视口边 ≥ 12px（不贴边——贴边时按钮边框几乎压着屏幕缘）；[br]
##   4. 图标与其紧邻文字之间的间距 ≥ [constant MapCardArt.ICON_GAP]（
##      「图标与文字压在一起」的量化口径）。[br]
## [br][b]为什么实例化真实场景[/b]：这些偏移写在 [code].tscn[/code] 里，读文本断言
## 是绕过引擎的做法；挂起来量 [code]get_global_rect()[/code] 才是玩家看得见的结果。[br]
##
## 来源: 玩家反馈「左上角与右上角元素重叠（图标与文字压在一起）」、
## src/ui/shared/top_bar_layout.gd（分栏口径的唯一落点）、
## design/gdd/exploration-ui-system.md §1/§2、.claude/rules/ui-code.md。

const TopBarLayoutScript := preload("res://src/ui/shared/top_bar_layout.gd")
const ArtScript := preload("res://src/ui/exploration/map_card_art.gd")
const GraphScene: PackedScene = preload("res://src/ui/exploration/node_graph_screen.tscn")
const SelectScene: PackedScene = preload("res://src/ui/exploration/map_select_screen.tscn")
const MapCardScript := preload("res://src/ui/exploration/map_card.gd")

## 右侧元素右缘距视口边的下限（px）——低于此值即为「贴边」。[br]
## 比 [constant TopBarLayout.EDGE_MARGIN]（24）松一档：这条判据要抓的是
## 「贴着屏幕边」，而不是把设计值钉死（改设计值时不该连带改测试）。
const RIGHT_MARGIN_FLOOR: float = 12.0

var _node: Control = null


func after_each() -> void:
	if _node != null and is_instance_valid(_node):
		_node.free()
	_node = null


## 视口宽度（两个场景都按锚点铺满视口——用实际宽度量贴边，不写死 1280）。
func _viewport_width(p_node: Control) -> float:
	return p_node.get_viewport_rect().size.x


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 节点图顶栏：退出按钮 ↔ 走投无路提示 / AP 行
# ═══════════════════════════════════════════════════════════════════════════════

func _graph_topbar() -> Dictionary:
	_node = GraphScene.instantiate()
	_node.set("animate", false)
	add_child_autofree(_node)
	await get_tree().process_frame
	return {
		"bar": _node.get_node(^"TopBar") as Control,
		"exit": _node.get_node_or_null(^"TopBar/ExitButton") as Control,
		"ap": _node.get_node_or_null(^"TopBar/APLabel") as Control,
		"status": _node.get_node_or_null(^"TopBar/StatusLabel") as Control,
	}


func test_node_graph_exit_button_does_not_overlap_status_label() -> void:
	# Arrange
	var bar: Dictionary = await _graph_topbar()
	var exit_button: Control = bar["exit"]
	var status: Control = bar["status"]
	assert_not_null(exit_button, "顶栏应有退出按钮")
	assert_not_null(status, "顶栏应有走投无路提示位")
	if exit_button == null or status == null:
		return
	# Act——提示位平时隐藏，量位置要先让它参与布局
	status.visible = true
	await get_tree().process_frame
	# Assert——两块矩形不相交，且中间留白够
	assert_true(TopBarLayoutScript.is_clear_of(exit_button, status),
			"退出按钮 %s 与提示位 %s 不应相交"
			% [exit_button.get_global_rect(), status.get_global_rect()])
	assert_gte(TopBarLayoutScript.gap_between(exit_button, status),
			TopBarLayoutScript.MIDDLE_GAP_MIN,
			"退出按钮与提示位之间应留 ≥ %.0fpx 给标题类文字，实际 %.0fpx"
			% [TopBarLayoutScript.MIDDLE_GAP_MIN,
			TopBarLayoutScript.gap_between(exit_button, status)])


func test_node_graph_ap_label_stays_inside_viewport_with_margin() -> void:
	# Arrange
	var bar: Dictionary = await _graph_topbar()
	var ap: Control = bar["ap"]
	assert_not_null(ap, "顶栏应有 AP 行")
	if ap == null:
		return
	# Assert——右缘不越出视口，且留出边距
	var margin: float = TopBarLayoutScript.right_margin_of(ap, _viewport_width(_node))
	assert_gte(margin, RIGHT_MARGIN_FLOOR,
			"AP 行右缘距视口边应有 ≥ %.0fpx 边距，实际 %.0fpx" % [RIGHT_MARGIN_FLOOR, margin])
	assert_lte(ap.get_global_rect().end.x, _viewport_width(_node),
			"AP 行不应越出视口右缘")


func test_node_graph_status_label_does_not_overlap_ap_label() -> void:
	# Arrange
	var bar: Dictionary = await _graph_topbar()
	var status: Control = bar["status"]
	var ap: Control = bar["ap"]
	assert_not_null(status, "顶栏应有走投无路提示位")
	assert_not_null(ap, "顶栏应有 AP 行")
	if status == null or ap == null:
		return
	# Act
	status.visible = true
	await get_tree().process_frame
	# Assert——提示位与 AP 行在同一行（都靠右），排版约束下靠 anchor_right 的
	# 右侧偏移给出间距，这里量的是「真的没有像素重叠」
	assert_true(TopBarLayoutScript.is_clear_of(status, ap),
			"提示位 %s 与 AP 行 %s 不应相交"
			% [status.get_global_rect(), ap.get_global_rect()])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 地图选择顶栏：标题 ↔ 灵石余额
# ═══════════════════════════════════════════════════════════════════════════════

func _select_header() -> Dictionary:
	_node = SelectScene.instantiate()
	_node.set("animate", false)
	add_child_autofree(_node)
	await get_tree().process_frame
	return {
		"anchor": _node.get_node(^"LayoutAnchor") as Control,
		"title": _node.get_node(^"LayoutAnchor/TitleLabel") as Control,
		"balance": _node.get_node(^"LayoutAnchor/BalanceLabel") as Control,
	}


func test_map_select_title_does_not_overlap_balance() -> void:
	# Arrange
	var header: Dictionary = await _select_header()
	var title: Control = header["title"]
	var balance: Control = header["balance"]
	assert_not_null(title, "顶栏应有标题")
	assert_not_null(balance, "顶栏应有余额行")
	if title == null or balance == null:
		return
	# Assert
	assert_true(TopBarLayoutScript.is_clear_of(title, balance),
			"标题 %s 与余额 %s 不应相交"
			% [title.get_global_rect(), balance.get_global_rect()])


func test_map_select_header_keeps_middle_gap() -> void:
	# Arrange
	var header: Dictionary = await _select_header()
	var gap: float = TopBarLayoutScript.gap_between(header["title"], header["balance"])
	# Assert——中间留白够（标题再长也只是被自己的裁切收尾，不顶到余额）
	assert_gte(gap, TopBarLayoutScript.MIDDLE_GAP_MIN,
			"标题与余额之间应留 ≥ %.0fpx 空白，实际 %.0fpx"
			% [TopBarLayoutScript.MIDDLE_GAP_MIN, gap])


func test_map_select_balance_stays_inside_viewport_with_margin() -> void:
	# Arrange
	var header: Dictionary = await _select_header()
	var anchor: Control = header["anchor"]
	# Assert——余额右缘贴内容区右缘（内容区本身已有 96px 外边距，故这里量内容区）
	var margin: float = anchor.get_global_rect().end.x \
			- header["balance"].get_global_rect().end.x
	assert_gte(margin, 0.0, "余额行不应越出内容区右缘")
	assert_lte(header["balance"].get_global_rect().end.x, _viewport_width(_node),
			"余额行不应越出视口右缘")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 卡片上的图标行：图标与紧邻文字的间距
# ═══════════════════════════════════════════════════════════════════════════════

func _card_of(p_entry: Dictionary) -> Panel:
	var card: Panel = MapCardScript.new()
	card.call(&"setup", p_entry)
	add_child_autofree(card)
	_node = card
	return card


func _entry(p_overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {
		"map_id": &"qing_yun_jian_zong", "name": "青云剑宗", "difficulty": 1,
		"is_cleared": false, "clear_count": 0, "is_unlocked": true,
		"reentry_allowed": true, "reentry_total": 0, "is_permanent_free": true,
	}
	for key: Variant in p_overrides.keys():
		entry[key] = p_overrides[key]
	return entry


func test_difficulty_icon_row_keeps_gap_between_icon_and_text() -> void:
	# Arrange——难度行是「⭐ / 低」两节点
	var card: Panel = _card_of(_entry({"difficulty": 3}))
	await get_tree().process_frame
	var row: HBoxContainer = ArtScript.icon_row_of(card, &"DifficultyRow")
	assert_not_null(row, "卡面应有难度图标行")
	if row == null:
		return
	var icon: Control = row.get_node_or_null(NodePath(String(ArtScript.NODE_ICON))) as Control
	var text: Control = row.get_node_or_null(NodePath(String(ArtScript.NODE_ICON_TEXT))) as Control
	# Assert——两个节点都在，且间距不小
	assert_not_null(icon, "难度行应有图标节点")
	assert_not_null(text, "难度行应有文字节点")
	if icon == null or text == null:
		return
	assert_gte(TopBarLayoutScript.gap_between(icon, text), float(ArtScript.ICON_GAP),
			"难度行图标与文字间距应 ≥ %dpx，实际 %.0fpx"
			% [ArtScript.ICON_GAP, TopBarLayoutScript.gap_between(icon, text)])


func test_locked_card_shows_lock_icon_row_below_the_name() -> void:
	# Arrange——锁定卡：解锁小标是单独一行，不再拼进名称
	var card: Panel = _card_of(_entry({"is_unlocked": false,
			"locked_hint": "需筑基期", "name": "苍玄正道盟"}))
	await get_tree().process_frame
	# Act
	var row: HBoxContainer = ArtScript.icon_row_of(card, &"LockRow")
	var name_label: Label = null
	for raw: Variant in _labels_of(card):
		var label: Label = raw as Label
		if label.text == "苍玄正道盟":
			name_label = label
	# Assert——小标在场且可见，且压在名称行下方（不是拼在名字里）
	assert_not_null(row, "锁定卡应有解锁小标行")
	assert_not_null(name_label, "卡面应有名称行")
	if row == null or name_label == null:
		return
	assert_true(row.visible, "锁定卡的小标应可见")
	assert_gte(row.get_global_rect().position.y, name_label.get_global_rect().end.y - 0.5,
			"解锁小标（起于 %.0f）应在名称行（到 %.0f）之下——拼在名字后面就会压字"
			% [row.get_global_rect().position.y, name_label.get_global_rect().end.y])


func test_unlocked_card_hides_lock_icon_row() -> void:
	## 已解锁卡不该出现「未解锁」小标（占位不显示，也不该抢一行高度）。
	var card: Panel = _card_of(_entry())
	await get_tree().process_frame
	var row: HBoxContainer = ArtScript.icon_row_of(card, &"LockRow")
	assert_not_null(row, "解锁小标行常驻树上（只是不可见）——便于两态复用")
	if row == null:
		return
	assert_false(row.visible, "已解锁卡不该显示「未解锁」小标")


## 卡面所有标签（深度优先）。
func _labels_of(p_node: Node) -> Array:
	var out: Array = []
	for child: Node in p_node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_labels_of(child))
	return out
