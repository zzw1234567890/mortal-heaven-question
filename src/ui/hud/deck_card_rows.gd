extends RefCounted
## DeckCardRows —— 卡组查看面板的[b]卡面行构建[/b]（纯构建，不读模型、不写状态）。[br]
## [br][b]为什么单独一处[/b]：面板要守 300 行软上限（.claude/docs/coding-standards.md），
## 而「一串卡面数据 → 一批行控件」与「什么时候刷新、按键意味着什么」是两件事
## （同 [code]inventory_panel_layout.gd[/code] 对 [method InventoryPanelLayout.add_rows]
## 的拆因）。[br]
## [br][b]为什么不用 [code]InventoryPanelLayout.add_rows[/code][/b]：那个入口按
## 「这一行有没有载荷」在 [Button] 与 [Label] 之间二选一，做出来的是单行文本按钮；
## 卡组要的是[b]卡面[/b]（三行 + 稀有度色条）。两处「一串行 → 一批控件」的分叉点
## 不同（一边是可否确认、一边是不是卡面），硬塞进同一个函数会让它长出第二个可选参数
## 并开始猜调用方想要哪种行。[br]
## [br][b]载荷键与读数口径与背包共用[/b]：[code]META_PAYLOAD[/code] /
## [code]row_text(row)[/code] 都取 [code]InventoryPanelLayout[/code] 那一份——
## 「这一行写了什么字」在四个面板里必须是同一个答案。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只 new 节点，引用交回面板
## （[method add_rows] 返回行数）。[br]
##
## 来源: design/ux/deck-editing-ui.md（§卡组浏览「复用手牌布局的卡片视觉」）、
## .claude/rules/ui-code.md（双输入 + 焦点可见 + 文字即标记）、ADR-0031 §2、
## 先例 [code]inventory_panel_layout.gd[/code] / [code]hand_card.gd[/code]。

## 卡面行控件（自绘卡底 + 引擎画字）。
const CardRowScript := preload("res://src/ui/hud/deck_card_row.gd")
## 载荷元数据键与行文本读取的单一来源（与背包 / 商店同一口径）。
const PanelLayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")
## 卡组行数据的键（与 [code]DeckViewRows[/code] 同源——不裸写字符串）。
const RowsScript := preload("res://src/ui/hud/deck_view_rows.gd")


## 逐行构建卡面行并接线。[br]
## [br][param p_rows] [code]DeckViewRows.build[/code] 产出的
## [code]Array[{text, payload}][/code]——载荷里带 [code]face[/code] 的走卡面行。[br]
## [param p_on_pressed] 确认回调 [code]func(index: int) -> void[/code]（键盘游标与鼠标
## 点击两条路径共用同一个出口——只接一边等于给另一种输入设备的玩家一个点了没反应的
## 按钮）。[br]
## [br][b]没有 [code]face[/code] 的行退回纯文本行[/b]：卡面字段是模板读出来的，
## 万一带载荷的行缺了这一项（半截数据），画一张白板卡面比画一行字更糟。[br]
## [br][b]返回[/b]：实际写入的行数（面板据此更新行计数，不必再数一遍子节点）。
static func add_rows(p_item_box: VBoxContainer, p_rows: Array,
		p_prefix: String = "Card", p_on_pressed: Callable = Callable()) -> int:
	var count: int = 0
	for raw: Variant in p_rows:
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		var payload: Dictionary = row.get("payload", {})
		var name: String = "%s%d" % [p_prefix, count]
		var face: Variant = payload.get(RowsScript.KEY_FACE)
		if face is Dictionary and not (face as Dictionary).is_empty():
			_add_card_row(p_item_box, name, face, payload, p_on_pressed)
		else:
			PanelLayoutScript.add_text_row(p_item_box, str(row.get("text", "")), name)
		count += 1
	return count


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建一个卡面行并接线（下标在接线时绑定——与 [method InventoryPanelLayout.add_selectable_row]
## 同一口径，回调方拿到的是「第几行」）。[br]
## [br][b]标注写进卡面文本[/b]：「已抽出 / 仍在牌库」由
## [code]CardFaceRules.face_text[/code] 拼进第二行——文字标记，色盲可读
## （.claude/rules/ui-code.md），也让屏幕阅读器读得出。
static func _add_card_row(p_item_box: VBoxContainer, p_name: String,
		p_face: Dictionary, p_payload: Dictionary, p_on_pressed: Callable) -> void:
	var row: Button = CardRowScript.new()
	row.name = p_name
	row.call(&"apply_face", p_face, str(p_payload.get(RowsScript.KEY_MARKER, "")))
	row.set_meta(PanelLayoutScript.META_PAYLOAD, p_payload)
	p_item_box.add_child(row)
	if p_on_pressed.is_valid():
		row.pressed.connect(p_on_pressed.bind(p_item_box.get_child_count() - 1))
