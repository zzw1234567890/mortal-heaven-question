extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 暂停菜单场景变体落地验收：按钮可见性按场景 + 焦点起点跳过不可选按钮。[br]
## [br][b]为什么需要[/b]：UX 规格要求「战斗中隐藏『保存并退出』」，且焦点顺序
## 跳过此按钮（design/ux/pause-menu.md §Interaction Map「战斗中特殊规则」）。
## 纯判定已有单测（[code]test_pause_menu_variant.gd[/code]）——本文件测的是[b]落地[/b]：
## 判定算对了，控件上的 [code]visible[/code] 与真实的 [code]grab_focus[/code] 有没有跟上。
## 判错与「判对了但没生效」是两类不同的缺陷，故分两处各锁一遍。[br]
## [br][b]覆盖[/b]：[br]
##   1. 探索中全部 7 个按钮可见；[br]
##   2. 战斗中/渡劫中/商店中/事件中「保存并退出」不可见，其余按钮不动；[br]
##   3. 焦点起点落在「继续游戏」（战斗中隐藏的那一个不在焦点链上）；[br]
##   4. 焦点起点跳过置灰按钮（通用规则）；[br]
##   5. 拿不到场景 ID 时保持全显示（最宽松）；[br]
##   6. 重开菜单时可见性重新按当前场景算（场景变了不会留着上一次的隐藏态）。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]（[code]sm.scene_id[/code] 可配）。[br]
## [br]注：[code]SM[/code] 由夹具提供，此处不再声明——GDScript 里子类重复声明同名
## 成员是解析错误，整个文件会被 GUT 静默忽略。[br]
##
## 来源: design/ux/pause-menu.md（States & Variants / 键盘焦点顺序 /
## 战斗中特殊规则）、design/gdd/hud-system.md §8、ADR-0031 §2。

func _button(button_name: String) -> Button:
	return menu.get_node("Panel/VBox/" + button_name) as Button


func _save_exit() -> Button:
	return _button("SaveExitButton")


# ═══════════════════════════════════════════════════════════════════════════════
# 可见性按场景
# ═══════════════════════════════════════════════════════════════════════════════

func test_exploration_shows_all_buttons() -> void:
	## 探索支持随时存档——规格明写「全部 7 个按钮可用」。
	# Arrange —— sm.scene_id 缺省 EXPLORATION
	# Act
	open_menu()
	# Assert
	assert_true(_save_exit().visible, "探索中「保存并退出」应可见")
	for name: String in ["ContinueButton", "DeckViewButton", "SettingsButton",
			"SaveButton", "LoadButton", "ReturnButton"]:
		assert_true(_button(name).visible, "探索中 %s 应可见" % name)


func test_combat_hides_save_exit_only() -> void:
	## 战斗中只藏「保存并退出」——其余按钮的可用性不变（返回主菜单仍可放弃本场战斗）。
	# Arrange
	sm.scene_id = SM.SceneID.COMBAT
	# Act
	open_menu()
	# Assert
	assert_false(_save_exit().visible, "战斗中「保存并退出」应隐藏（不可存档）")
	for name: String in ["ContinueButton", "DeckViewButton", "SettingsButton",
			"SaveButton", "LoadButton", "ReturnButton"]:
		assert_true(_button(name).visible, "战斗中 %s 仍应可见" % name)


func test_tribulation_hides_save_exit() -> void:
	## 渡劫为战斗变体——同一条规则（hud GDD §状态与转换）。
	# Arrange
	sm.scene_id = SM.SceneID.TRIBULATION
	# Act
	open_menu()
	# Assert
	assert_false(_save_exit().visible, "渡劫中「保存并退出」应隐藏")


func test_shop_and_event_hide_save_exit() -> void:
	## 商店/事件为过渡场景，不独立存档——规格明写隐藏。
	# Arrange + Act + Assert —— 商店
	sm.scene_id = SM.SceneID.SHOP
	open_menu()
	assert_false(_save_exit().visible, "商店中「保存并退出」应隐藏")
	menu.request_close()
	# Arrange + Act + Assert —— 事件面板
	sm.scene_id = SM.SceneID.EVENT_PANEL
	open_menu()
	assert_false(_save_exit().visible, "事件面板中「保存并退出」应隐藏")


func test_unknown_scene_id_keeps_save_exit_visible() -> void:
	## 宿主拿不到当前场景 ID 时按最宽松处理——藏掉一个本该可用的按钮比多显示一个更糟。
	# Arrange —— 注入一个缺 get_current_scene_id 的替身
	menu.scene_manager = null
	# Act
	open_menu()
	# Assert
	assert_true(_save_exit().visible, "拿不到场景 ID 时应保持全显示（最宽松）")
	assert_eq(focus_owner(), _button("ContinueButton"), "焦点起点仍应落在继续游戏")


func test_variant_recomputed_on_each_open() -> void:
	## 可见性不缓存：先探索（显示）→ 关掉 → 切到战斗再打开（隐藏）。
	# Arrange
	open_menu()
	assert_true(_save_exit().visible, "前置：探索中显示")
	menu.request_close()
	# Act —— 场景切到战斗（战斗中 combat-ui 转发 ESC，同一份菜单组件）
	sm.scene_id = SM.SceneID.COMBAT
	open_menu()
	# Assert
	assert_false(_save_exit().visible, "重开时可见性应按当前场景重新算")


# ═══════════════════════════════════════════════════════════════════════════════
# 焦点起点
# ═══════════════════════════════════════════════════════════════════════════════

func test_focus_starts_on_continue_in_exploration() -> void:
	# Act
	open_menu()
	# Assert
	assert_eq(focus_owner(), _button("ContinueButton"),
			"探索中焦点起点应为「继续游戏」（规格的默认焦点）")


func test_focus_skips_hidden_save_exit_in_combat() -> void:
	## 战斗中隐藏的那一个不能在焦点链上——否则屏幕上没有焦点环，按 Enter 却真的
	## 触发了那个看不见的按钮。
	# Arrange
	sm.scene_id = SM.SceneID.COMBAT
	# Act
	open_menu()
	# Assert
	assert_false(_save_exit().visible, "前置：战斗中「保存并退出」已隐藏")
	assert_false(_save_exit().has_focus(),
			"焦点不得落在隐藏的「保存并退出」上")
	assert_eq(focus_owner(), _button("ContinueButton"),
			"焦点起点应落在首个可选按钮（继续游戏）")


func test_focus_start_skips_disabled_button() -> void:
	## 通用规则：置灰按钮引擎拒绝激活，停在上面等于焦点悬空。[br]
	## 用「继续游戏」置灰来构造——它在焦点顺序第一位。
	# Arrange
	_button("ContinueButton").disabled = true
	# Act
	open_menu()
	# Assert
	assert_eq(focus_owner(), _button("DeckViewButton"),
			"焦点起点应跳过置灰的按钮，落到下一个可选者上")


func test_focus_start_skips_hidden_leading_button() -> void:
	## 隐藏的若恰在顺序最前，焦点不能停在它身上（同一规则的边界）。
	# Arrange
	_button("ContinueButton").visible = false
	# Act
	open_menu()
	# Assert
	assert_eq(focus_owner(), _button("DeckViewButton"),
			"焦点起点应跳过隐藏的首个按钮")


func test_load_panel_back_refocuses_visible_button_in_combat() -> void:
	## 从读档面板返回时的回锚也走同一条「跳过隐藏」的判定——战斗中回锚不该抓
	## 那个看不见的「保存并退出」。
	# Arrange
	sm.scene_id = SM.SceneID.COMBAT
	open_menu()
	menu._on_load_pressed()
	# Act
	menu._on_load_panel_back()
	# Assert
	assert_eq(focus_owner(), _button("ContinueButton"),
			"战斗中从读档面板返回，焦点应回锚到「继续游戏」（而非隐藏按钮）")
