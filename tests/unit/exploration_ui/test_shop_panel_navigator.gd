extends "res://tests/unit/exploration_ui/shop_navigator_fixture.gd"
## 商店面板键盘/手柄游标的核心行为（复位 / 移动 / 确认）。[br]
## [br][b]Story 类型[/b]：Logic（纯游标逻辑——行数组 + 三个动作出口注入，无场景依赖）。
## 输入事件翻译与焦点信号见 [code]test_shop_panel_navigator_events.gd[/code]；
## 面板级的完整链路（真实输入事件 → 购买/关闭）见
## [code]test_shop_panel_navigation.gd[/code]。[br]
## [br]装置（真实 Button 行、注入出口、计数器）见
## [code]shop_navigator_fixture.gd[/code]。[br]
##
## 来源: .claude/rules/ui-code.md（双输入）、ADR-0031 §2/§4（零状态所有权 + 双焦点）、
## GDD exploration-ui-system.md §4c、shop_panel_navigator.gd。


# ═══════════════════════════════════════════════════════════════════════════════
# 复位
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_lands_on_first_selectable_row() -> void:
	# Arrange——首行售罄
	_rows_of("oxx")
	# Act
	nav.call(&"reset")
	# Assert——跳过禁用行落到首个可选行
	assert_eq(int(nav.call(&"focus_index")), 1, "复位应落到首个可选行而不是禁用行")


func test_reset_on_empty_shelf_leaves_no_cursor() -> void:
	# Arrange——空货架
	_rows = []
	# Act
	nav.call(&"reset")
	# Assert
	assert_eq(int(nav.call(&"focus_index")), -1, "空货架不应有游标（如实报告而非臆造 0）")


func test_reset_on_all_disabled_shelf_leaves_no_cursor() -> void:
	# Arrange——全部买不起
	_rows_of("ooo")
	# Act
	nav.call(&"reset")
	# Assert
	assert_eq(int(nav.call(&"focus_index")), -1, "全列禁用时不应停在禁用行上")


func test_reset_after_rows_replaced_relands_on_first_selectable() -> void:
	# Arrange——先落到第 3 行
	_rows_of("xxx")
	nav.call(&"reset")
	nav.call(&"move", 1)
	nav.call(&"move", 1)
	assert_eq(int(nav.call(&"focus_index")), 2, "前置条件：游标已到第 3 行")
	# Act——货架重建（重上架换了一批控件）
	_rows_of("xx")
	nav.call(&"reset")
	# Assert——复位到新一批的首个可选行（不下标错位）
	assert_eq(int(nav.call(&"focus_index")), 0, "重建后应复位到新货架首行")


# ═══════════════════════════════════════════════════════════════════════════════
# 移动
# ═══════════════════════════════════════════════════════════════════════════════

func test_move_down_selects_next_row() -> void:
	# Arrange
	_rows_of("xxx")
	nav.call(&"reset")
	# Act
	var moved: int = int(nav.call(&"move", 1))
	# Assert
	assert_eq(moved, 1, "↓ 应下移一行")
	assert_eq(int(nav.call(&"focus_index")), 1, "游标应停在第 2 行")


func test_move_up_selects_previous_row() -> void:
	# Arrange
	_rows_of("xxx")
	nav.call(&"reset")
	nav.call(&"move", 1)
	# Act
	nav.call(&"move", -1)
	# Assert
	assert_eq(int(nav.call(&"focus_index")), 0, "↑ 应上移一行")


func test_move_down_skips_disabled_rows() -> void:
	# Arrange——第 2、3 行售罄
	_rows_of("xoox")
	nav.call(&"reset")
	# Act
	nav.call(&"move", 1)
	# Assert——落到第 4 行（跳过两个禁用行）
	assert_eq(int(nav.call(&"focus_index")), 3, "↓ 应跳过售罄行")


func test_move_up_skips_disabled_rows() -> void:
	# Arrange——第 2、3 行售罄，游标在第 4 行
	_rows_of("xoox")
	nav.call(&"reset")
	nav.call(&"move", 1)
	# Act
	nav.call(&"move", -1)
	# Assert
	assert_eq(int(nav.call(&"focus_index")), 0, "↑ 应跳过售罄行")


func test_move_down_at_last_row_does_not_wrap() -> void:
	# Arrange——游标已在末行
	_rows_of("xx")
	nav.call(&"reset")
	nav.call(&"move", 1)
	# Act
	nav.call(&"move", 1)
	# Assert——不环绕（「已到底」应可观测）
	assert_eq(int(nav.call(&"focus_index")), 1, "末行再按 ↓ 应停在原地，不回到首行")


func test_move_up_at_first_row_does_not_wrap() -> void:
	# Arrange
	_rows_of("xx")
	nav.call(&"reset")
	# Act
	nav.call(&"move", -1)
	# Assert
	assert_eq(int(nav.call(&"focus_index")), 0, "首行再按 ↑ 应停在原地")


func test_move_with_no_rows_keeps_cursor_absent() -> void:
	# Arrange
	_rows = []
	# Act
	var moved: int = int(nav.call(&"move", 1))
	# Assert
	assert_eq(moved, -1, "无行可移时应返回无游标")


func test_move_when_all_rows_disabled_keeps_cursor_absent() -> void:
	# Arrange——全部售罄
	_rows_of("oo")
	# Act
	nav.call(&"move", 1)
	# Assert——没有候选就保持无游标（不是硬停在禁用行）
	assert_eq(int(nav.call(&"focus_index")), -1, "无候选时不应把游标放到禁用行上")


# ═══════════════════════════════════════════════════════════════════════════════
# 确认
# ═══════════════════════════════════════════════════════════════════════════════

func test_activate_on_cursor_row_fires_purchase() -> void:
	# Arrange
	_rows_of("xxx")
	nav.call(&"reset")
	nav.call(&"move", 1)
	# Act
	var fired: bool = bool(nav.call(&"activate"))
	# Assert
	assert_true(fired, "游标在可选行时确认应发起购买")
	assert_eq(_activated, [1], "发起的是游标所在那行")


func test_activate_without_cursor_fires_nothing() -> void:
	# Arrange——空货架
	_rows = []
	# Act
	var fired: bool = bool(nav.call(&"activate"))
	# Assert
	assert_false(fired, "无游标时确认不应发起购买")
	assert_eq(_activated, [], "无游标时不得发意图")


func test_activate_on_disabled_row_fires_nothing() -> void:
	# Arrange——直接构造「游标落在禁用行」的交叉态（鼠标绕过面板的路径）
	_rows_of("xo")
	nav.call(&"reset")
	nav.call(&"move", 1)
	assert_eq(int(nav.call(&"focus_index")), 0, "前置条件：游标在可选行")
	(_rows[0] as Button).disabled = true  # 行在游标选中后才变成不可买
	# Act
	var fired: bool = bool(nav.call(&"activate"))
	# Assert——与鼠标点击同口径：禁用行不发意图
	assert_false(fired, "游标所在行禁用时确认应被拒")
	assert_eq(_activated, [], "禁用行不得发意图")
