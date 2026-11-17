extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 战斗中「查看卡组」= 只读卡组查看面板（本轮补）。[br]
## [br][b]为什么需要[/b]：这个按钮此前只发 [signal PauseMenu.deck_view_requested]
## 信号、全库零消费者——玩家点下去什么都不发生（面板本体不在任何 story 的范围里，
## 于是成了一条断链）。规格要求它在战斗中打开[只读]查看：卡牌可看详情，不可编辑、
## 不可拖拽，关闭后回到暂停菜单。[br]
## [br][b]本文件钉住四件事[/b]：[br]
##   1. 点「查看卡组」真的弹出面板，且渲染出的行数等于卡组张数；[br]
##   2. 战斗中每行带「已抽出 / 仍在牌库」标注（手牌那一张标前一个）；[br]
##   3. 关闭（「返回」/ ESC）后焦点回到暂停菜单的按钮上；[br]
##   4. 只读——行确认只展开详情，没有任何写入口；菜单关闭时面板一并收起。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]（[code]MockDeck[/code] /
## [code]MockCards[/code] / [code]attach_deck[/code] 在那边）。[br]
## [br]注：[code]SLS[/code] / [code]SM[/code] 等由夹具提供，此处不再声明——
## GDScript 里子类重复声明同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
##
## 来源: design/ux/pause-menu.md（§Interaction Map 战斗中特殊规则 第 321 行 /
## §States & Variants 战斗中变体 第 231 行 / §Interaction Map 第 309 行）、
## design/ux/deck-editing-ui.md（§多入口到达）、ADR-0031 §1/§2、
## .claude/rules/ui-code.md（双输入 + 只读面板不拥有状态）。

## 三张牌的卡组（实例 ID 1/2/3）——行数断言与标注断言的共同夹具。
const DECK_IDS: Array[int] = [1, 2, 3]


## 装一副三张牌的卡组并进战斗场景（返回卡组替身）。
func _enter_combat_with_deck() -> MockDeck:
	sm.scene_id = SM.SceneID.COMBAT
	var deck: MockDeck = attach_deck({
		1: make_template("林远", 1, 1),
		2: make_template("御剑术", 2, 2, 1),
		3: make_template("聚灵丹", 3, 0, 4),
	})
	attach_combat()
	return deck


# ═══════════════════════════════════════════════════════════════════════════════
# 打开
# ═══════════════════════════════════════════════════════════════════════════════

func test_deck_button_opens_readonly_viewer() -> void:
	## 核心断言：按钮不再是个哑巴——点下去真的有面板出现。
	# Arrange
	_enter_combat_with_deck()
	open_menu()
	assert_null(deck_view(), "前置：未点之前不应有面板")
	# Act —— 走真实场景信号（不直调处理函数）
	menu_button("DeckViewButton").pressed.emit()
	# Assert
	var view: Control = deck_view()
	assert_not_null(view, "点「查看卡组」应创建面板")
	assert_true(bool(view.call(&"is_open")), "点「查看卡组」后面板应打开")
	assert_true(menu.visible, "打开卡组面板不应关闭暂停菜单（它是覆盖层）")


func test_deck_viewer_renders_every_deck_card() -> void:
	## 渲染实证：卡组三张 → 三行（不是「卡组为空」的降级文案）。
	# Arrange
	_enter_combat_with_deck()
	open_menu()
	# Act
	menu_button("DeckViewButton").pressed.emit()
	# Assert
	var view: Control = deck_view()
	assert_eq(int(view.call(&"entry_count")), DECK_IDS.size(),
			"三张牌的卡组应渲染三行")
	var texts: Array = view.call(&"entry_texts")
	assert_eq(texts.size(), DECK_IDS.size(), "行文本数量应与行数一致")
	assert_true(str(texts[0]).contains("林远"), "首行应是卡组里的第一张（名称来自模板）")
	assert_eq(str(view.call(&"summary_text")), "卡组 3 张", "摘要应报出卡组张数")


func test_deck_viewer_is_readonly_declared() -> void:
	## 只读要说出来（规格明写「所有编辑按钮禁用」）——玩家不必自己找按钮。
	# Arrange
	_enter_combat_with_deck()
	open_menu()
	# Act
	menu_button("DeckViewButton").pressed.emit()
	# Assert
	var message: String = str(deck_view().call(&"message_text"))
	assert_true(message.contains("只读"), "提示行应声明只读：" + message)
	assert_true(message.contains("不可编辑"), "提示行应说明不可编辑：" + message)


func test_deck_viewer_reuses_panel_and_refreshes_each_open() -> void:
	## 复用式单例 + 零状态所有权：第二次打开现读卡组（停留期间可能刚打出一张牌）。
	# Arrange
	var deck: MockDeck = _enter_combat_with_deck()
	open_menu()
	menu_button("DeckViewButton").pressed.emit()
	var first: Control = deck_view()
	deck_view().call(&"close")
	# Act —— 卡组少一张后再开
	deck.cards = [1, 2]
	menu_button("DeckViewButton").pressed.emit()
	# Assert
	assert_same(deck_view(), first, "面板应复用同一个实例（不叠第二个）")
	assert_eq(int(deck_view().call(&"entry_count")), 2, "再开应现读最新卡组（非缓存）")


# ═══════════════════════════════════════════════════════════════════════════════
# 战斗中标注：已抽出 / 仍在牌库
# ═══════════════════════════════════════════════════════════════════════════════

func test_rows_mark_hand_cards_in_combat() -> void:
	## 战斗中标注（deck-editing-ui §多入口到达明写的两个词）——文字标记，
	## 不靠颜色单独承载（色盲可读）。
	# Arrange —— 实例 1 已抽到手上
	_enter_combat_with_deck()
	(menu.combat_system as MockCombat).hand = [1]
	open_menu()
	# Act
	menu_button("DeckViewButton").pressed.emit()
	# Assert
	var texts: Array = deck_view().call(&"entry_texts")
	assert_true(str(texts[0]).contains("已抽出"), "手牌里的那张应标「已抽出」：" + str(texts[0]))
	assert_true(str(texts[1]).contains("仍在牌库"), "牌库里的那张应标「仍在牌库」：" + str(texts[1]))
	assert_true(str(texts[2]).contains("仍在牌库"), "第三张同样仍在牌库")


func test_rows_have_no_mark_when_battle_inactive() -> void:
	## 战斗未活跃时不标注：此时 [code]get_hand()[/code] 本就是空的，给每张都标
	## 「仍在牌库」等于凭空断言一件尚未发生的事（规格只要求在战斗中标注）。
	# Arrange
	_enter_combat_with_deck()
	(menu.combat_system as MockCombat).active = false
	(menu.combat_system as MockCombat).hand = [1]
	open_menu()
	# Act
	menu_button("DeckViewButton").pressed.emit()
	# Assert
	var texts: Array = deck_view().call(&"entry_texts")
	assert_false(str(texts[0]).contains("已抽出"), "非活跃战斗不应标注")
	assert_false(str(texts[0]).contains("仍在牌库"), "非活跃战斗不应标注")


# ═══════════════════════════════════════════════════════════════════════════════
# 关闭与焦点回锚
# ═══════════════════════════════════════════════════════════════════════════════

func test_back_button_closes_viewer_and_restores_menu_focus() -> void:
	## 规格：关闭后回到暂停菜单。焦点必须真的还回去——面板按钮一隐藏，键盘焦点
	## 就落在不可见的控件上，方向上键按不动、回车还会打到看不见的按钮。
	# Arrange
	_enter_combat_with_deck()
	open_menu()
	menu_button("DeckViewButton").pressed.emit()
	assert_true(bool(deck_view().call(&"is_open")), "前置：面板已打开")
	# Act
	deck_view().call(&"press_back")
	# Assert
	assert_false(bool(deck_view().call(&"is_open")), "「返回」应收起面板")
	assert_true(menu.visible, "「返回」不应关闭暂停菜单")
	assert_true(focus_owner() != null, "焦点应有归属（不悬空）")
	assert_true(menu.is_ancestor_of(focus_owner()),
			"焦点应回到暂停菜单内部：" + str(focus_owner()))


func test_esc_closes_viewer_before_menu() -> void:
	## ESC 分层：面板开着时第一下先收面板，菜单留着（共用一个键时必须一层层退）。
	# Arrange
	_enter_combat_with_deck()
	open_menu()
	menu_button("DeckViewButton").pressed.emit()
	# Act
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(bool(deck_view().call(&"is_open")), "第一下 ESC 应先收面板")
	assert_true(menu.visible, "第一下 ESC 不应关闭菜单")
	assert_true(get_tree().paused, "菜单仍在，暂停应保持")
	# Act —— 第二下才关菜单
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(menu.visible, "第二下 ESC 才关菜单")
	assert_false(get_tree().paused, "关菜单应解除暂停")


func test_closing_menu_also_closes_viewer() -> void:
	## 留一个「开着」的覆盖层在隐藏的菜单里，下次打开会看到上一次的残影。
	# Arrange
	_enter_combat_with_deck()
	open_menu()
	menu_button("DeckViewButton").pressed.emit()
	# Act —— 点「继续游戏」关菜单
	menu_button("ContinueButton").pressed.emit()
	# Assert
	assert_false(menu.visible, "前置：菜单已关")
	assert_false(bool(deck_view().call(&"is_open")), "菜单关闭时面板应一并收起")
	# Act —— 再次打开菜单：不应看到上一次的面板
	open_menu()
	# Assert
	assert_false(bool(deck_view().call(&"is_open")), "重开菜单不应带出上一次的面板")


# ═══════════════════════════════════════════════════════════════════════════════
# 只读：行确认只展开详情
# ═══════════════════════════════════════════════════════════════════════════════

func test_activating_row_only_expands_detail() -> void:
	## 「只读」的落地：行的确认动作只展开详情文本，不发任何系统调用。
	## [br][code]MockDeck[/code] 只实现了 [code]get_deck_cards[/code]——若面板试图
	## 走任何写入口（加牌 / 减牌 / 装备），这一行会以 [code]ERR_UNAVAILABLE[/code]
	## 失败，而断言面（卡组内容未变 + 详情已展开）会同时亮红。
	# Arrange
	var deck: MockDeck = _enter_combat_with_deck()
	var before: Array = deck.cards.duplicate()
	open_menu()
	menu_button("DeckViewButton").pressed.emit()
	var view: Control = deck_view()
	assert_eq((view.call(&"detail_texts") as Array).size(), 0, "前置：详情未展开")
	# Act
	view.call(&"press_row", 0)
	# Assert
	var detail: Array = view.call(&"detail_texts")
	assert_gt(detail.size(), 0, "确认一行应展开详情")
	assert_true(str(detail[0]).contains("林远"), "详情首行应是该牌的名称：" + str(detail[0]))
	assert_eq(deck.cards, before, "只读查看不得改动卡组内容")
	assert_true(bool(deck_view().call(&"is_open")), "展开详情不应收起面板")
