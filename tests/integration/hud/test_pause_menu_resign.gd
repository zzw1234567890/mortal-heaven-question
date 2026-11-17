extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 战斗中「返回主菜单」= 先投降结算（本轮补）。[br]
## [br][b]为什么需要[/b]：UX 规格明写战斗中放弃本场战斗的完整流程是
## [code]确认 → 触发 COMBAT_RESIGNED（视为战败）→ 显示战败结算画面（与正常战败
## 一致）→ 玩家点击「返回」→ 回到主菜单[/code]，而此前这条链只做到了第一
## 步——确认之后直接 [code]request_scene_change(MAIN_MENU)[/code]，战斗域没清、
## 战果没落库、撤退该扣的修为没扣。这是「点一下主菜单就白嫖一场输掉的仗」。[br]
## [br][b]本文件钉住四件事[/b]：[br]
##   1. 战斗中确认「不保存」→ 调 [code]confirm_retreat[/code]，且[b]不[/b]直发转场；[br]
##   2. 投降前已解除暂停并 pop MODAL 锁（顺序反了新场景停在冻结帧）；[br]
##   3. 非战斗场景仍是旧行为（先自动存档一次 → 转场主菜单），一字未改；[br]
##   4. 战斗不活跃 / 战斗系统缺失时降级回普通返回（不臆造第二场败仗）。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]（[code]MockCombat[/code] 在那边）。[br]
## [br]注：[code]SLS[/code] / [code]SM[/code] 等由夹具提供，此处不再声明——
## GDScript 里子类重复声明同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
##
## 来源: design/ux/pause-menu.md（§Events Fired 战斗中放弃的完整流程 第 340 行 /
## §Interaction Map 战斗中特殊规则 第 231 行 / §返回主菜单确认弹窗 第 270 行）、
## ADR-0005（导航唯一入口）、ADR-0008（战斗生命周期）。


## 进战斗场景（含一台活跃的战斗替身）。
func _enter_combat() -> MockCombat:
	sm.scene_id = SM.SceneID.COMBAT
	return attach_combat()


# ═══════════════════════════════════════════════════════════════════════════════
# 主链：战斗中返回主菜单 = 投降
# ═══════════════════════════════════════════════════════════════════════════════

func test_combat_return_triggers_retreat() -> void:
	## 核心断言：确认之后触发的是投降，不是转场。
	# Arrange —— 战斗中，替身战斗活跃
	var combat: MockCombat = _enter_combat()
	open_menu()
	# Act —— 走 UX 规格里的「不保存」键（战斗中的「返回主菜单」三键变体）
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(combat.retreat_calls, 1, "战斗中确认「返回主菜单」应触发一次投降")
	assert_eq(sm.change_calls.size(), 0,
			"不得直发转场——转场由战斗系统按结算结果自己请求（DEFEAT_SCREEN）")


func test_combat_return_does_not_auto_save_before_retreat() -> void:
	## 撤回结算会改写修为与资源——在它之前存一次底，存下的是「仗输了但还没结算」
	## 的中间态，反而把上一份干净存档盖掉。写盘时机归转场管线 Phase 2。
	# Arrange
	var combat: MockCombat = _enter_combat()
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(combat.retreat_calls, 1, "前置：投降已触发")
	assert_eq(sl.auto_save_calls, 0, "投降前不得顺手自动存档（会盖掉干净档）")
	assert_eq(sl.save_calls.size(), 0, "投降链不写盘")


func test_combat_return_releases_pause_and_lock_before_retreat() -> void:
	## 顺序不可反：冻结态下发起转场，新场景会停在冻结帧。
	## [br]替身在 [code]confirm_retreat[/code] 里记下「被调那一刻」的暂停与锁快照。
	# Arrange
	var combat: MockCombat = _enter_combat()
	open_menu()
	assert_true(get_tree().paused, "前置：菜单打开时处于暂停")
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	# 防御：替身可能没被调到——先断言调用发生，后面的快照才有意义
	assert_eq(combat.retreat_calls, 1, "前置：投降已触发")
	assert_false(combat.tree_paused_at_retreat,
			"触发投降那一刻不应仍处于暂停（否则结算画面停在冻结帧）")
	assert_false(combat.lock_held_at_retreat,
			"触发投降那一刻 MODAL 锁应已 pop")
	assert_false(menu.visible, "投降前应收起菜单")
	assert_eq(adapter.resume_calls, 1, "投降前应恢复音频")


func test_combat_return_with_confirm_save_writes_then_retreats() -> void:
	## 三键里的「确认保存」在战斗中同样以投降收尾——存档是玩家的显式要求，
	## 与「走哪条退出链」是两件事（同 [PauseMenuState.resolve_outcome] 的口径）。
	# Arrange
	var combat: MockCombat = _enter_combat()
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("ConfirmButton").pressed.emit()
	# Assert
	assert_eq(sl.save_calls.size(), 1, "「确认保存」应真实写盘一次")
	assert_eq(combat.retreat_calls, 1, "写盘成功后仍应走投降（不是转场主菜单）")
	assert_eq(sm.change_calls.size(), 0, "不得直发转场")


func test_tribulation_return_also_triggers_retreat() -> void:
	## 渡劫是战斗变体（hud GDD §状态与转换）——同一条规则，
	## 判定收在 [code]PauseMenuLayout.is_combat[/code] 一处。
	# Arrange
	sm.scene_id = SM.SceneID.TRIBULATION
	var combat: MockCombat = attach_combat()
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(combat.retreat_calls, 1, "渡劫中放弃本场战斗也走投降结算")


# ═══════════════════════════════════════════════════════════════════════════════
# 降级：不构成投降时回退旧行为
# ═══════════════════════════════════════════════════════════════════════════════

func test_non_combat_return_keeps_direct_navigation() -> void:
	## 非战斗场景一字未改：先顺手存一次底，再转场主菜单。
	# Arrange —— 缺省 EXPLORATION，不注入战斗系统
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(sl.auto_save_calls, 1, "探索中返回主菜单仍应先自动存档一次")
	assert_eq(sm.change_calls.size(), 1, "探索中应直发转场")
	assert_eq(int(sm.change_calls[0][1]), SM.SceneID.MAIN_MENU, "目标应为主菜单")


func test_combat_without_active_battle_navigates_directly() -> void:
	## 战斗场景在备战确认之前就已存在，此时点「返回主菜单」不该被判成投降
	## ——[code]battle_end[/code] 会凭空造出一场「战败」并给玩家记一次撤退。
	# Arrange
	var combat: MockCombat = _enter_combat()
	combat.active = false
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(combat.retreat_calls, 0, "无活跃战斗不得触发投降")
	assert_eq(sm.change_calls.size(), 1, "应回退到普通「返回主菜单」转场")


func test_combat_without_combat_system_navigates_directly() -> void:
	## 链路没接上（HUD 未注入）时退化成旧行为——比把玩家锁在一场关不掉的战斗里强。
	# Arrange —— 战斗场景但不注入 combat_system
	sm.scene_id = SM.SceneID.COMBAT
	open_menu()
	# Act
	menu._on_return_main_menu_pressed()
	confirm_button("LeaveButton").pressed.emit()
	# Assert
	assert_eq(sm.change_calls.size(), 1, "战斗系统缺失应回退普通返回（不静默卡死）")
	assert_false(get_tree().paused, "回退路径也应解除暂停")
	assert_false(menu.visible, "回退路径也应收起菜单")
