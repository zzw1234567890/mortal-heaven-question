extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 战斗内覆盖面板的焦点「从哪来回哪去」+ 链外控件收拢（真实场景真实按键）。[br]
## [br][b]背景[/b]：面板一开就把焦点抢走（面板自己的默认焦点），而关闭时[b]没有任何
## 东西记得它是从哪来的[/b]。当前兜底是「焦点为空就补默认焦点」，于是取消一次撤退
## 确认之后，焦点从撤退按钮跳到第一张手牌——每开一次面板丢一次位置。手柄玩家对此
## 最敏感：十字键按回原处得重走一遍整条链。[br]
## [br][b]三条路径[/b]：撤退确认弹窗、战利品选择面板、行囊面板（后者见
## [code]test_combat_bag_focus_restore.gd[/code]——那一路要真实收藏里有丹药）。[br]
## [br][b]走真实场景与真实按键[/b]：弹窗的开合经生产入口（按钮
## [code]pressed[/code] / 真实 Esc 事件），不是直调 [code]remember[/code] 之后
## 自说自话——否则「焦点到底有没有回到原处」这条根本没被测到。[br]
## [br][b]不改既有用例[/b]：本文件只新增；[code]test_combat_keyboard_focus_path.gd[/code]
## （12 例）与 [code]test_bottombar_and_retreat_real_input.gd[/code] 必须仍绿。

## 环境推进用到的阶段号（与 [code]CombatPhase[/code] 同源）。
const PHASE_PLAY: int = 2
## 战斗结果（与 [code]CombatSystem.CombatResult[/code] 同源）。
const VICTORY: int = 1
## 战败结果（同源）。
const DEFEAT: int = 2


func before_all() -> void:
	for _i: int in range(300):
		if CardSystem.get_template(&"basic_attack") != null \
				and CardSystem.get_template(&"lin_yuan") != null:
			break
		await get_tree().process_frame
	AISystem.load_templates()


func before_each() -> void:
	setup(false)
	confirm_deploy()
	assert_true(drive_to_play(), "前置：应能推进到出牌阶段")


func after_each() -> void:
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 链外控件被收拢（Tab 再也跳不出去）
# ═══════════════════════════════════════════════════════════════════════════════

## 出牌阶段战场里链外已无可见可聚焦控件。[br]
## [br][b]此前的事实[/b]：探针实测链外唯一一个是顶部条的[b]战斗日志折叠按钮[/b]
## ——玩家在底栏按一次 Tab 就跳到屏幕左上角，且那个按钮的 [code]pressed[/code]
## 全库无人接线（跳过去按回车什么也不会发生，比跳走更糟）。[br]
## [br][b]为什么要走真实场景断言[/b]：收拢的判据（可见 / 可聚焦 / 链外）依赖
## 真实节点树与真实 [code]focus_mode[/code]；拿假控件树测只能证明算法自洽。
func test_no_outside_focusable_control_in_play_phase() -> void:
	# Act
	var outside: Array = _chain().call("outside_focusables")
	# Assert
	assert_eq(outside.size(), 0,
			"出牌阶段链外不该还有可聚焦控件（实测漏网者：%s）" % _describe(outside))


## 战斗日志折叠按钮已进链：它是链上可聚焦的一站，不再靠几何自推被 Tab 撞上。[br]
## [br][b]本轮语义变更[/b]：上一轮它的 [code]pressed[/code] 全库无人接线，于是被
## [b]收出焦点[/b]（[code]FOCUS_NONE[/code]）——Tab 不再跳过去，但键盘 / 手柄玩家
## 也再也开不了日志。本轮按钮接上了开合（[code]CombatLog.toggle[/code]），
## 于是改判据：它进链（环首），可聚焦、按得动。[br]
## [br][b]本用例替换的旧断言[/b]：旧断言是「[code]focus_mode == FOCUS_NONE[/code]」，
## 钉的是「链外唯一漏网者已被收掉」这一前提；前提已被有意推翻，断言随新语义重写，
## 强度不降——从「它不能聚焦」变成「它可聚焦、在链上、且按下真的开合」。
func test_log_collapse_button_is_a_reachable_chain_stop() -> void:
	# Arrange
	var collapse: Control = _root().find_child("CollapseLabel", true, false) as Control
	assert_not_null(collapse, "前置：战斗日志折叠按钮应存在（顶栏结构变了就更新本用例）")
	# Act / Assert
	assert_eq(collapse.focus_mode, Control.FOCUS_ALL,
			"战斗日志折叠按钮应可聚焦（它是本轮的日志入口）")
	assert_true(_chain().call("focus_order").has(collapse.name),
			"折叠按钮应是焦点链上的一站（链序：%s）" % str(_chain().call("focus_order")))
	assert_false(_chain().call("outside_focusables").has(collapse),
			"折叠按钮已在链上，不该同时出现在链外清单里")


## 连按 10 次 Tab，焦点始终落在链上（手牌 / 行囊 / 结束出牌 / 撤退 / 日志入口）。[br]
## [br][b]为什么按次数而不是按某一站[/b]：链尾的自指一旦失效，引擎会退回几何自推
## ——症状是「第 4 次 Tab 之后才会飘」，只按三次永远测不到。[br]
## [br][b]链上为什么含日志入口[/b]：它本轮进了环（环首）——见上一条用例说明。
func test_tab_cycles_inside_the_chain_only() -> void:
	# Arrange——焦点落在第一张手牌（默认焦点），从这里开始绕环
	var chain: Array = _chain_nodes()
	assert_gt(chain.size(), 3, "前置：链上应至少有手牌 + 三个动作按钮")
	# Act + Assert
	for step: int in range(10):
		_push_key(KEY_TAB)
		var owner: Control = get_viewport().gui_get_focus_owner()
		assert_true(chain.has(owner),
				"第 %d 次 Tab 后焦点跑到链外了：%s" % [step + 1, _name_of(owner)])
		assert_eq(owner.focus_mode, Control.FOCUS_ALL,
				"第 %d 次 Tab 后焦点控件应仍可聚焦" % (step + 1))


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 撤退确认弹窗：关掉後焦点回原处
# ═══════════════════════════════════════════════════════════════════════════════

## 从手牌打开撤退确认、点「继续战斗」关闭 → 焦点回到打开前那张手牌。[br]
## [br][b]本文件的核心[/b]：不记焦点的话，关闭时兜底落「第一张手牌」——
## 从第三张按出去的玩家回来发现焦点跳到了第一张。
func test_retreat_dialog_cancel_returns_focus_to_origin() -> void:
	# Arrange——焦点放在[b]第二张[/b]手牌（不是默认的第一张，否则测不出「回原处」）
	var origin: Control = _origin_card()
	assert_eq(get_viewport().gui_get_focus_owner(), origin, "前置：焦点在原处手牌上")
	var dialog: Variant = _retreat_dialog()
	# Act——点右上角撤退按钮（生产入口）
	_retreat_button().emit_signal(&"pressed")
	assert_true(bool(dialog.call("is_showing")), "前置：撤退确认弹窗应已打开")
	assert_ne(get_viewport().gui_get_focus_owner(), origin,
			"前置：弹窗应已抢走焦点（否则本用例测不到「还回去」）")
	# Act——点「继续战斗」（生产关闭出口）
	var cancel: Button = dialog.get("cancel_button") as Button
	cancel.emit_signal(&"pressed")
	# Assert
	assert_false(bool(dialog.call("is_showing")), "「继续战斗」应关掉弹窗")
	assert_eq(get_viewport().gui_get_focus_owner(), origin,
			"关闭后焦点应回到打开弹窗前的那张手牌")


## 按 Esc 关掉撤退确认弹窗 → 焦点同样回到原处（不因为走的是键盘就丢位置）。[br]
## [br][b]为什么 Esc 要单列[/b]：Esc 走的是「按钮 pressed」这条生产出口没错，
## 但它是先被 [code]CombatEscapeRouter[/code] 拦下再转发的——多一层转发就多一个
## 可能漏掉还原的地方。
func test_retreat_dialog_escape_returns_focus_to_origin() -> void:
	# Arrange
	var origin: Control = _origin_card()
	var dialog: Variant = _retreat_dialog()
	_retreat_button().emit_signal(&"pressed")
	assert_true(bool(dialog.call("is_showing")), "前置：弹窗应已打开")
	# Act
	_push_key(KEY_ESCAPE)
	# Assert
	assert_false(bool(dialog.call("is_showing")), "Esc 应关掉撤退确认弹窗")
	assert_eq(get_viewport().gui_get_focus_owner(), origin,
			"Esc 关弹窗后焦点应回到原处")


## 焦点从[b]底栏按钮[/b]出发时也回得到原处（不是只认手牌那一类）。[br]
## [br][b]为什么用底栏按钮当第二个原点[/b]：默认兜底恰好是「第一张手牌」，
## 若只在手牌上测，还原失败会被兜底掩盖成通过——换个原点才能把两者分开。
func test_retreat_dialog_returns_focus_to_bottom_bar_button() -> void:
	# Arrange
	var origin: Button = _bag_button()
	origin.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), origin, "前置：焦点在行囊按钮上")
	var dialog: Variant = _retreat_dialog()
	# Act
	_retreat_button().emit_signal(&"pressed")
	assert_true(bool(dialog.call("is_showing")), "前置：弹窗应已打开")
	var cancel: Button = dialog.get("cancel_button") as Button
	cancel.emit_signal(&"pressed")
	# Assert
	assert_eq(get_viewport().gui_get_focus_owner(), origin,
			"关闭后焦点应回到行囊按钮（而非兜底的第一张手牌）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 战利品选择面板：关掉后焦点回原处
# ═══════════════════════════════════════════════════════════════════════════════

## 胜利面板打开时抢走焦点，点「跳过」关闭后焦点回到原处手牌。[br]
## [br][b]为什么战利品这条路最该有[/b]：它是唯一会自己抢焦点的面板
## （[code]grab_initial_focus[/code] 把焦点放到第一张战利品卡上），
## 也最容易让玩家的位置丢掉——选完卡之后手柄还得重走一遍整条链。
func test_loot_panel_skip_returns_focus_to_origin() -> void:
	# Arrange
	var origin: Control = _origin_card()
	var panel: Variant = _settlement_panel()
	assert_eq(get_viewport().gui_get_focus_owner(), origin, "前置：焦点在原处手牌上")
	# Act——走生产入口开面板（宿主是 battle_ended 的接收者）
	_open_victory_panel()
	assert_true(bool(panel.call("is_open")), "前置：胜利面板应已打开")
	assert_ne(get_viewport().gui_get_focus_owner(), origin,
			"前置：面板应已把焦点抢到战利品卡上")
	# Act——点「跳过」（生产关闭出口）
	var skip: Button = panel.get("skip_button") as Button
	skip.emit_signal(&"pressed")
	# Assert
	assert_false(bool(panel.call("is_open")), "「跳过」应关掉面板")
	assert_eq(get_viewport().gui_get_focus_owner(), origin,
			"关闭后焦点应回到打开面板前的那张手牌")


## 战败面板点「返回探索」关闭后，焦点同样回到原处。[br]
## [br][b]为什么战败也算一条[/b]：它不是胜利那条的分支——不同的打开方法
## （[code]show_defeat[/code] 而不是 [code]show_victory[/code]）、不同的关闭按钮，
## 但共用同一个 [code]closed[/code] 出口；任一方法漏发信号都该在这里显形。
func test_defeat_panel_returns_focus_to_origin() -> void:
	# Arrange
	var origin: Control = _origin_card()
	var panel: Variant = _settlement_panel()
	# Act
	_settlement_host().call(&"on_battle_ended", DEFEAT, {"retain_ratio": 0.5})
	assert_true(bool(panel.call("is_open")), "前置：战败面板应已打开")
	var confirm: Button = panel.get("confirm_button") as Button
	confirm.emit_signal(&"pressed")
	# Assert
	assert_false(bool(panel.call("is_open")), "「返回探索」应关掉面板")
	assert_eq(get_viewport().gui_get_focus_owner(), origin,
			"关闭后焦点应回到打开面板前的那张手牌")


## 从没记过焦点（面板打开时焦点本就空着）→ 关闭时不该凭空塞一个焦点。[br]
## [br][b]这是鼠标玩家的常态[/b]：点鼠标不改键盘焦点（实测），面板开之前焦点
## 常常就是空的。此时「关闭后落默认焦点」正是「关一次面板跳一次焦点」这个
## 症状本身——记与不记必须分得开。
func test_panel_close_stays_empty_when_nothing_was_focused() -> void:
	# Arrange——清空焦点，再打开面板
	get_viewport().gui_release_focus()
	assert_null(get_viewport().gui_get_focus_owner(), "前置：焦点为空")
	_open_victory_panel()
	var panel: Variant = _settlement_panel()
	assert_true(bool(panel.call("is_open")), "前置：面板应已打开")
	# Act
	var skip: Button = panel.get("skip_button") as Button
	skip.emit_signal(&"pressed")
	# Assert——面板自己的战利品卡被隐藏后焦点自动释放；不该再落到别处
	var owner: Control = get_viewport().gui_get_focus_owner()
	var chain: Array = _chain_nodes()
	assert_false(chain.has(owner),
			"没记过焦点时关闭面板不该把焦点落到链上（实际落到：%s）"
			% _name_of(owner))


# ═══════════════════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════════════════

## 投递一条真实按键（按下 + 抬起成对——引擎对合成事件同样做 UI 动作派发）。
func _push_key(p_code: Key) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var down := InputEventKey.new()
	down.keycode = p_code
	down.physical_keycode = p_code
	down.pressed = true
	tree.root.push_input(down, true)
	var up := InputEventKey.new()
	up.keycode = p_code
	up.physical_keycode = p_code
	up.pressed = false
	tree.root.push_input(up, true)


## 焦点「原处」——第二张手牌（避开默认兜底落的第一张，见用例说明）。[br]
## [br][b]先重取节点再抓焦点[/b]：每次刷新手牌会换一批卡节点，停在旧引用上
## 验的是已退场的节点。
func _origin_card() -> Control:
	var cards: Array = _hand_cards()
	assert_gt(cards.size(), 1, "前置：手牌至少两张（第一张是默认兜底，不能用）")
	var origin: Control = cards[1]
	origin.grab_focus()
	return origin


## 焦点链实例（场景接线持有——测试据此断言链的构成与收拢结果）。
func _chain() -> Variant:
	var wiring: Variant = scene.get("interaction_wiring")
	assert_not_null(wiring, "前置：场景应持有出牌交互接线")
	var chain: Variant = wiring.get("focus_chain")
	assert_not_null(chain, "前置：交互接线应已建焦点链")
	return chain


## 链上控件清单（Tab 只该在这些之间走）。[br]
## [br][b]含战斗日志入口[/b]：本轮它从「链外收拢」改成「进链」（环首）——
## 见 [method test_log_collapse_button_is_a_reachable_chain_stop] 的说明。
func _chain_nodes() -> Array:
	var nodes: Array = _hand_cards()
	nodes.append(_bag_button())
	nodes.append(_end_turn_button())
	nodes.append(_retreat_button())
	nodes.append(_log_collapse_button())
	return nodes


## 战斗日志折叠按钮（链首站）。
func _log_collapse_button() -> Control:
	return _root().find_child("CollapseLabel", true, false) as Control


## 走生产入口打开胜利面板（宿主是 [signal CombatSystem.battle_ended] 的接收者）。[br]
## [br][b]载荷带一张卡[/b]：候选为空时面板直接切汇总视图（不建三选一格子），
## 焦点也就不会落到战利品卡上——本用例要的正是「面板抢焦点」那一段。
func _open_victory_panel() -> void:
	_settlement_host().call(&"on_battle_ended", VICTORY, {
		"lingshi": 12, "cultivation": 6, "retention_ratio": 1.0,
		"cards": [{"name": "测试战利品", "rarity": "凡品"}],
	})


## 结算宿主（战场根上的生产节点）。
func _settlement_host() -> Variant:
	var host: Variant = _root().get("settlement_host")
	assert_not_null(host, "前置：战场根应持有结算宿主")
	return host


## 结算面板（宿主自建的子面板）。
func _settlement_panel() -> Variant:
	return _settlement_host().get("settlement_panel")


## 撤退确认弹窗（宿主自建的子面板）。
func _retreat_dialog() -> Variant:
	return _settlement_host().get("retreat_dialog")


func _hand_cards() -> Array:
	var hand: Variant = _root().get("hand_area")
	return hand.call("card_nodes") as Array


func _bag_button() -> Button:
	return _bar().get("bag_button").get("button") as Button


func _end_turn_button() -> Button:
	return _bar().get("end_turn_button").get("button") as Button


func _retreat_button() -> Button:
	return _root().get("retreat_button") as Button


func _bar() -> Variant:
	return _root().get("combat_bottombar")


## 控件名（断言消息用——null 与具名控件分开）。
func _name_of(p_control: Control) -> String:
	return "null" if p_control == null else "%s:%s" % [p_control.name, p_control.get_class()]


## 控件清单描摹（失败消息里一眼看清漏网的是谁）。
func _describe(p_nodes: Array) -> String:
	if p_nodes.is_empty():
		return "无"
	var names: Array = []
	for node: Variant in p_nodes:
		names.append(_name_of(node as Control))
	return ", ".join(names)
