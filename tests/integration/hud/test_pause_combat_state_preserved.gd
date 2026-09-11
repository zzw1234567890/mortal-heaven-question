extends GutTest
## hud Story 005 集成测试：战斗状态保持（AC-2 / AC-hud-011）。
##
## Given: 战斗进行到第 3 回合，GSM battle 域状态已知[br]
## When: 暂停 → 恢复[br]
## Then: 回合数、battle 域关键状态全部不变[br]
##
## 测试策略（先例 test_battle_lifecycle_gsm.gd）：CS_SCRIPT.new() + set_auto_advance(false)
## 模式构造 CombatSystem 实例（不调 _ready），battle_start 驱动 GSM battle 域；
## HUD.tscn 实例化 + mock adapter（先例 test_notification_request_interface.gd）。
## 测试后清理：SceneTree.paused = false + InputManager 锁栈 + GSM battle 域。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const HUD_SCENE: PackedScene = preload("res://src/ui/hud/HUD.tscn")

var cs: Node = null
var hud: CanvasLayer = null
var pause_menu: Control = null


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	# 清理 GSM 战斗状态——先例 before_each 模式（不调 _do_flush）
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	pause_menu = hud.get_node_or_null("PauseOverlay/PauseMenu")
	pause_menu.animate = false


func after_each() -> void:
	# 清理暂停状态 + 锁栈 + GSM 战斗状态——防泄漏污染后续套件
	get_tree().paused = false
	InputManager.clear_locks()
	if hud != null and is_instance_valid(hud):
		hud.free()
	hud = null
	pause_menu = null
	if cs != null:
		cs.free()
		cs = null
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 推进战斗到指定回合（PREPARATION 回绕时 _turn 递增——phase_changed 信号路径）。
func _advance_to_turn(target_turn: int) -> void:
	while cs.call("get_turn_number") < target_turn:
		cs.call("advance_phase")  # 每回合 7 阶段——回绕 PREPARATION 时回合 +1


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：战斗状态保持（AC-hud-011 核心）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac002_turn_number_preserved_after_pause_resume() -> void:
	## AC-2 主体: 战斗第 3 回合暂停→恢复——回合数不变
	# Arrange —— 战斗推进到第 3 回合
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	_advance_to_turn(3)
	assert_eq(cs.call("get_turn_number"), 3, "前置：第 3 回合")
	# Act —— 暂停 → 恢复（combat_ui 转发路径——战斗中 ESC 的实际来源）
	hud.request_pause(&"combat_ui")
	assert_true(get_tree().paused, "前置：暂停中")
	pause_menu.request_close()
	# Assert
	assert_eq(cs.call("get_turn_number"), 3, "恢复后回合数应仍为 3（不变）")
	assert_true(cs.call("is_battle_active"), "战斗仍应活跃")

func test_ac002_gsm_battle_domain_preserved() -> void:
	## AC-2 主体: GSM battle 域关键状态（phase/turn/is_active）暂停前后不变
	# Arrange
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	var before: Dictionary = GameStateManager.battle.duplicate(true)
	# Act
	hud.request_pause(&"combat_ui")
	pause_menu.request_close()
	# Assert
	assert_eq(GameStateManager.battle.get("is_active"), before.get("is_active"),
			"battle.is_active 应不变")
	assert_eq(GameStateManager.battle.get("phase"), before.get("phase"),
			"battle.phase 应不变")
	assert_eq(GameStateManager.battle.get("turn"), before.get("turn"),
			"battle.turn 应不变")

func test_ac002_pause_while_combat_lock_active() -> void:
	## AC-2 edge: 战斗动画锁（ANIMATION）下 ESC 暂停——恢复后战斗锁仍在且状态不变
	## （battle_start 推入 ANIMATION 锁——MODAL 叠加其上，关闭后战斗锁恢复）
	# Arrange
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	assert_true(InputManager.has_lock(&"combat_system"),
			"前置：battle_start 推入战斗 ANIMATION 锁")
	var turn_before: int = cs.call("get_turn_number")
	# Act —— 战斗中 ESC（UI_NAV 在 ANIMATION 锁下允许——test_modal_integration 先例）
	hud.request_pause(&"esc")
	assert_true(get_tree().paused, "战斗锁下暂停菜单应可打开")
	pause_menu.request_close()
	# Assert —— 战斗锁恢复 + 回合不变
	assert_true(InputManager.has_lock(&"combat_system"),
			"关闭暂停后战斗 ANIMATION 锁应仍在（配对恢复）")
	assert_false(InputManager.has_lock(&"pause_menu"),
			"暂停 MODAL 锁应已释放")
	assert_eq(cs.call("get_turn_number"), turn_before, "回合数应不变")

func test_ac002_multi_pause_resume_cycles_in_combat() -> void:
	## AC-2 edge: 战斗中多轮暂停/恢复——状态稳定（无累积漂移）
	# Arrange
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	# Act —— 3 轮暂停/恢复
	for i: int in range(3):
		hud.request_pause(&"combat_ui")
		assert_true(get_tree().paused, "第 %d 轮暂停应生效" % (i + 1))
		pause_menu.request_close()
		assert_false(get_tree().paused, "第 %d 轮恢复应生效" % (i + 1))
	# Assert
	assert_true(cs.call("is_battle_active"), "3 轮后战斗仍活跃")
	assert_eq(cs.call("get_turn_number"), 1, "回合数应仍为 1（无推进）")
	assert_false(InputManager.has_lock(&"pause_menu"), "暂停锁应清空")
	assert_true(InputManager.has_lock(&"combat_system"), "战斗锁应保持")
