extends GutTest
## 链外焦点收拢（CombatFocusSweeper）——Tab 走到链尾不再跳到链外控件。[br]
## [br][b]背景[/b]：焦点链只管「手牌 → 行囊 → 结束出牌 → 撤退」，但引擎在链走到头
## 时会退回几何自推，把焦点交给链外的控件。实测（探针
## [code]tools/probe_combat_focusable.gd[/code]）战斗里那一个是顶部条的
## [b]战斗日志折叠按钮[/b]——玩家在底栏按一次 Tab 就跳到屏幕左上角，且那个按钮的
## [code]pressed[/code] 全库无人接线（跳过去按回车什么也不会发生）。[br]
## [br][b]本文件锁定五条语义[/b]：[br]
##   1. 可见、可聚焦、非链上的控件全部被收（[code]focus_mode[/code] 置 NONE）；[br]
##   2. 链上控件一个都不动（收拢不许碰链的底盘）；[br]
##   3. 覆盖层子树整棵跳过（面板打开时它自管焦点）；[br]
##   4. 隐藏的控件不动（不可见本就不该落焦点，改它是越权）；[br]
##   5. 幂等 + 可还原（收两次不污染记账，还原后逐位回到原值）。[br]
## [br]全部用例使用自建控件树——不触碰 Autoload、不加载战斗场景。

const SweeperScript := preload("res://src/ui/combat/interaction/combat_focus_sweeper.gd")

var _host: Control = null
var _sweeper: RefCounted = null


func before_each() -> void:
	_host = Control.new()
	_host.name = "Host"
	_host.size = Vector2(800, 600)
	add_child_autofree(_host)
	_sweeper = SweeperScript.new()


func after_each() -> void:
	_sweeper = null
	await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 收掉链外的
# ═══════════════════════════════════════════════════════════════════════════════

## 链外的可见按钮被收（[code]focus_mode[/code] 从 ALL 变 NONE）。[br]
## [br][b]为什么这条是本文件的核心[/b]：Tab 从链尾跳到日志折叠按钮就是靠
## 「它还是可聚焦的」——收掉它，引擎无处可跳。
func test_sweep_takes_outside_button_out_of_focus() -> void:
	# Arrange
	var outside: Button = _add_button("Stray", _host)
	assert_eq(outside.focus_mode, Control.FOCUS_ALL, "前置：链外按钮本可聚焦")
	# Act
	var count: int = int(_sweeper.call(&"sweep", _host, []))
	# Assert
	assert_eq(count, 1, "应收掉 1 个链外控件")
	assert_eq(outside.focus_mode, Control.FOCUS_NONE, "链外按钮应退出焦点")


## 深层嵌套的链外控件同样被收（递归遍历，不是只看直接子节点）。
func test_sweep_reaches_nested_outside_control() -> void:
	# Arrange——两层容器包着
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	_host.add_child(box)
	var deep: Button = _add_button("Deep", box)
	# Act
	int(_sweeper.call(&"sweep", _host, []))
	# Assert
	assert_eq(deep.focus_mode, Control.FOCUS_NONE, "嵌套深处的链外控件也应被收")


## 查询接口与收拢口径一致：清单里的每一个收完都变 NONE，且清单外没有被动过。[br]
## [br][b]为什么单列这条[/b]：[method outside_nodes] 是测试与调试的观测入口，
## 它若与 [method sweep] 的判据漂移，断言就变成自说自话。
func test_outside_nodes_matches_what_sweep_changes() -> void:
	# Arrange
	var stray: Button = _add_button("Stray", _host)
	var keeper: Button = _add_button("Keeper", _host)
	var hidden: Button = _add_button("Hidden", _host)
	hidden.visible = false
	# Act
	var listed: Array = _sweeper.call(&"outside_nodes", _host, [keeper])
	int(_sweeper.call(&"sweep", _host, [keeper]))
	# Assert
	assert_true(listed.has(stray), "可见且非链上的控件应在清单里")
	assert_false(listed.has(keeper), "链上控件不该在清单里")
	assert_false(listed.has(hidden), "隐藏控件不该在清单里")
	assert_eq(stray.focus_mode, Control.FOCUS_NONE, "清单里的控件收后应为 NONE")
	assert_eq(keeper.focus_mode, Control.FOCUS_ALL, "链上控件不该被动")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 链上的一个都不碰
# ═══════════════════════════════════════════════════════════════════════════════

## [code]keep[/code] 名单里的控件（链上的手牌 / 底栏 / 撤退）原样保留。[br]
## [br][b]为什么必须有这条[/b]：收拢一旦碰链上的控件，玩家按 Tab 会在中途被清掉
## 焦点——「收链外」与「别碰链上」是一体两面。
func test_sweep_leaves_chain_controls_untouched() -> void:
	# Arrange
	var cards: Array = []
	for i: int in range(3):
		cards.append(_add_button("Card%d" % i, _host))
	var bag: Button = _add_button("BagButton", _host)
	var stray: Button = _add_button("Stray", _host)
	# Act
	var count: int = int(_sweeper.call(&"sweep", _host, cards + [bag]))
	# Assert
	assert_eq(count, 1, "只应收掉链外的那一个")
	for card: Button in cards:
		assert_eq(card.focus_mode, Control.FOCUS_ALL, "%s 是链上控件，不该被动" % card.name)
	assert_eq(bag.focus_mode, Control.FOCUS_ALL, "底栏按钮是链上控件，不该被动")
	assert_eq(stray.focus_mode, Control.FOCUS_NONE, "链外的照收")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 覆盖层整棵跳过
# ═══════════════════════════════════════════════════════════════════════════════

## 覆盖层子树（备战 / 结算 / 行囊）里的按钮一个都不碰。[br]
## [br][b]为什么按名字豁免[/b]：这三个面板自管焦点（各自的 wire_focus_chain /
## 默认焦点），收拢一旦伸进去，面板一开就被抹平——玩家在面板里连按钮都按不动。
func test_sweep_skips_overlay_subtrees() -> void:
	# Arrange
	var stray: Button = _add_button("Stray", _host)
	var overlay: Control = Control.new()
	overlay.name = "SettlementHost"
	_host.add_child(overlay)
	var inner: Button = _add_button("ConfirmButton", overlay)
	# Act
	var count: int = int(_sweeper.call(&"sweep", _host, []))
	# Assert
	assert_eq(count, 1, "只应收链外那一个——覆盖层整棵跳过")
	assert_eq(stray.focus_mode, Control.FOCUS_NONE, "链外的照收")
	assert_eq(inner.focus_mode, Control.FOCUS_ALL, "覆盖层里的按钮不该被动")
	assert_eq(overlay.focus_mode, Control.FOCUS_NONE, "覆盖层自身也不该被动（它本非可聚焦）")


## 三个覆盖层名字都被认（不只 [code]SettlementHost[/code] 一个）。
func test_sweep_skips_all_three_overlay_names() -> void:
	# Arrange
	var kept: Array = []
	for overlay_name: String in ["DeployPanel", "SettlementHost", "CombatBagScreen"]:
		var overlay: Control = Control.new()
		overlay.name = overlay_name
		_host.add_child(overlay)
		kept.append(_add_button("%sButton" % overlay_name, overlay))
	# Act
	var count: int = int(_sweeper.call(&"sweep", _host, []))
	# Assert
	assert_eq(count, 0, "三个覆盖层里的按钮都不该被收")
	for button: Button in kept:
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "%s 不该被动" % button.name)


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 隐藏的不动 / 读屏态的放过
# ═══════════════════════════════════════════════════════════════════════════════

## 隐藏的链外控件不动（不可见本就不该落焦点，改它是越权）。[br]
## [br][b]为什么这条重要[/b]：覆盖层面板关闭后是「隐藏但留树」，按钮的
## [code]focus_mode[/code] 得留着等它再开——收拢若按「非 NONE」一律改，
## 面板就再也开不起来了。
func test_sweep_ignores_hidden_controls() -> void:
	# Arrange
	var hidden: Button = _add_button("HiddenOverlayButton", _host)
	hidden.visible = false
	# Act
	var count: int = int(_sweeper.call(&"sweep", _host, []))
	# Assert
	assert_eq(count, 0, "隐藏控件不该被收")
	assert_eq(hidden.focus_mode, Control.FOCUS_ALL, "隐藏控件的 focus_mode 应原样保留")


## [constant Control.FOCUS_ACCESSIBILITY] 的控件放过（读屏未启用时引擎本就不给它
## 焦点，收掉等于改别人的可访问性配置）。
func test_sweep_leaves_accessibility_focus_alone() -> void:
	# Arrange
	var rich := RichTextLabel.new()
	rich.name = "LogRich"
	rich.focus_mode = Control.FOCUS_ACCESSIBILITY
	_host.add_child(rich)
	assert_eq(rich.focus_mode, Control.FOCUS_ACCESSIBILITY, "前置：读屏态控件")
	# Act
	var count: int = int(_sweeper.call(&"sweep", _host, []))
	# Assert
	assert_eq(count, 0, "读屏态控件不该被收")
	assert_eq(rich.focus_mode, Control.FOCUS_ACCESSIBILITY, "读屏态应原样保留")


## 禁用按钮照收（引擎对禁用 Button 的焦点导航不跳过）。[br]
## [br][b]与 [method CombatFocusRing.focusable] 的差别[/b]：那一条把禁用算作
## 「不可落焦点」（默认焦点不该放上去），而收拢面对的是「Tab 会不会走到」——
## 禁用按钮恰恰是最该收的那一类。
func test_sweep_takes_disabled_outside_button() -> void:
	# Arrange
	var disabled: Button = _add_button("DisabledStray", _host)
	disabled.disabled = true
	# Act
	var count: int = int(_sweeper.call(&"sweep", _host, []))
	# Assert
	assert_eq(count, 1, "禁用按钮也应被收（引擎不跳过它）")
	assert_eq(disabled.focus_mode, Control.FOCUS_NONE, "禁用按钮应退出焦点")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 幂等 + 可还原
# ═══════════════════════════════════════════════════════════════════════════════

## 收两次不污染记账：还原后仍回到最初的值。[br]
## [br][b]为什么必须幂等[/b]：链在每次阶段落定都会收一次（[code]apply_phase[/code]），
## 第二次若不认「这已经是我改的」，就会把 [constant Control.FOCUS_NONE] 记成
## 「改前值」——还原把控件永久锁死。
func test_sweep_is_idempotent_across_repeats() -> void:
	# Arrange
	var stray: Button = _add_button("Stray", _host)
	# Act——连收三次
	for _i: int in range(3):
		_sweeper.call(&"sweep", _host, [])
	assert_eq(_sweeper.call(&"tracked_count"), 1, "同一个控件只应记一笔")
	_sweeper.call(&"restore")
	# Assert
	assert_eq(stray.focus_mode, Control.FOCUS_ALL, "还原后应回到最初的可聚焦态")


## 还原把每个控件的 [code]focus_mode[/code] 逐位还回去、记账清空。
func test_restore_returns_every_control_to_previous_mode() -> void:
	# Arrange——三种初值各一个
	var all: Button = _add_button("All", _host)
	var click: Button = _add_button("Click", _host)
	click.focus_mode = Control.FOCUS_CLICK
	var none: Control = Control.new()
	none.name = "None"
	none.focus_mode = Control.FOCUS_NONE
	_host.add_child(none)
	int(_sweeper.call(&"sweep", _host, []))
	assert_eq(all.focus_mode, Control.FOCUS_NONE, "前置：已收")
	assert_eq(click.focus_mode, Control.FOCUS_NONE, "前置：已收")
	# Act
	_sweeper.call(&"restore")
	# Assert
	assert_eq(all.focus_mode, Control.FOCUS_ALL, "ALL 应回到 ALL")
	assert_eq(click.focus_mode, Control.FOCUS_CLICK, "CLICK 应回到 CLICK")
	assert_eq(none.focus_mode, Control.FOCUS_NONE, "本非可聚焦的仍为 NONE")
	assert_eq(_sweeper.call(&"tracked_count"), 0, "还原后记账应清空")


## 控件随场景销毁后还原不炸（跳过已释放的控件）。[br]
## [br][b]为什么这条要有[/b]：手牌重建会 [code]queue_free[/code] 旧卡节点；退场时
## 还原账里可能留着已释放的控件——不跳过就会往已释放对象上写属性。
func test_restore_survives_freed_controls() -> void:
	# Arrange
	var doomed: Button = _add_button("Doomed", _host)
	int(_sweeper.call(&"sweep", _host, []))
	doomed.free()
	# Act
	_sweeper.call(&"restore")
	# Assert
	assert_eq(_sweeper.call(&"tracked_count"), 0, "已释放的控件也应从记账里清掉")


## 树外的根静默返回 0（不抛错——退场路径上布局可能已失效）。
func test_sweep_returns_zero_for_null_or_freed_root() -> void:
	assert_eq(_sweeper.call(&"sweep", null, []), 0, "null 根应返回 0")
	var orphan := Control.new()
	var count: int = int(_sweeper.call(&"sweep", orphan, []))
	orphan.free()
	assert_eq(count, 0, "未入树的根应返回 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════════════════

## 建一个可聚焦按钮并挂到 [param p_parent] 下。
func _add_button(p_name: String, p_parent: Node) -> Button:
	var button := Button.new()
	button.name = p_name
	button.focus_mode = Control.FOCUS_ALL
	button.size = Vector2(80, 30)
	p_parent.add_child(button)
	return button
