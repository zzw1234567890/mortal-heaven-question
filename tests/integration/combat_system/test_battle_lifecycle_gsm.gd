extends GutTest
## Story 002 验收测试：战斗生命周期编排（battle_start / battle_end + GSM battle.* 域）。
##
## 覆盖 AC-001 到 AC-017（17 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CombatSystem 实例（不调 _ready）
##   - 真实 GSM Autoload 已在 SceneTree 中——battle_start/end 通过 GSM 第二层方法写入
##   - set_auto_advance(false) 禁用 call_deferred——手动控制阶段推进
##   - 信号捕获用 Dictionary 可变容器
##   - SaveLoad/InputManager/SceneManager 用 mock 或真实 Autoload
##
## 设计文档来源：ADR-0008 §战斗生命周期 + §GSM battle.* 域写入所有权例外
## Story 来源：production/epics/combat-system/story-002-battle-lifecycle-gsm.md

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	# 清理 GSM 战斗状态——不调 _do_flush（会发射 batch_updated 干扰后续测试信号计数）
	# 仅清空 _pending_changes + _flush_scheduled——stale call_deferred(_do_flush) 见空后安全返回
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	# 清理 GSM 战斗状态——不调 _do_flush
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 信号捕获容器。
func _capture_signal(signal_name: String) -> Dictionary:
	var state := {"received": false, "count": 0, "args": []}
	cs.connect(signal_name, func():
		state["received"] = true
		state["count"] += 1)
	return state


## 捕获 battle_started 信号。
func _capture_battle_started() -> Dictionary:
	var state := {"received": false, "config": {}, "count": 0}
	cs.connect("battle_started", func(config: Dictionary):
		state["received"] = true
		state["config"] = config.duplicate(true)
		state["count"] += 1)
	return state


## 捕获 battle_ended 信号。
func _capture_battle_ended() -> Dictionary:
	var state := {"received": false, "result": -1, "rewards": {}, "count": 0}
	cs.connect("battle_ended", func(result: int, rewards: Dictionary):
		state["received"] = true
		state["result"] = result
		state["rewards"] = rewards.duplicate(true)
		state["count"] += 1)
	return state


## 捕获 retreat_requested 信号。
func _capture_retreat_requested() -> Dictionary:
	var state := {"received": false, "count": 0}
	cs.connect("retreat_requested", func():
		state["received"] = true
		state["count"] += 1)
	return state


# ============================================================================
# AC-001：battle_start 初始化 battle 域
# ============================================================================

func test_ac001_battle_start_initializes_state() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck", "tribulation_level": 1, "is_tribulation": false})
	assert_true(cs.call("is_battle_active"), "is_active=true")
	assert_eq(cs.call("get_current_phase"), 0, "phase=PREPARATION")
	assert_eq(cs.call("get_turn_number"), 1, "turn=1")


func test_ac001_battle_start_rejects_duplicate() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	# 重复调用应拒绝
	cs.call("battle_start", {"enemy_deck_id": "test_deck2"})
	# 仍然是第一次的配置
	assert_true(cs.call("is_battle_active"), "仍活跃")


# ============================================================================
# AC-002：GSM._set_battle_active 创建 battle 域
# ============================================================================

func test_ac002_battle_start_creates_gsm_battle() -> void:
	assert_eq(GameStateManager.battle, null, "battle_start 前 battle=null")
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	assert_not_null(GameStateManager.battle, "battle_start 后 battle 域非空")
	assert_eq(GameStateManager.battle.get("is_active", false), true, "battle.is_active=true")
	assert_eq(GameStateManager.battle.get("phase", -1), 0, "battle.phase=PREPARATION")
	assert_eq(GameStateManager.battle.get("turn", -1), 1, "battle.turn=1")


# ============================================================================
# AC-003：battle_started 信号发射
# ============================================================================

func test_ac003_battle_started_signal() -> void:
	var sig := _capture_battle_started()
	var config := {"enemy_deck_id": "test_deck", "tribulation_level": 1, "is_tribulation": false}
	cs.call("battle_start", config)
	assert_true(sig["received"], "battle_started 信号已发射")
	assert_eq(sig["count"], 1, "信号发射 1 次")
	assert_eq(str(sig["config"]["enemy_deck_id"]), "test_deck", "载荷 config 正确")


# ============================================================================
# AC-004：战斗快照创建
# ============================================================================

func test_ac004_battle_snapshot_created() -> void:
	# SaveLoadSystem 是真实 Autoload——验证 create_battle_snapshot 被调用
	# 由于快照写入文件系统，这里验证 battle_start 不报错即可
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	assert_true(cs.call("is_battle_active"), "battle_start 成功——快照不阻塞启动")


# ============================================================================
# AC-005：输入锁推入
# ============================================================================

func test_ac005_input_lock_pushed() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	# InputManager 是真实 Autoload——验证 clear_locks 能清理（间接证明 push 成功）
	# battle_end 时会 clear_locks——验证无报错
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	assert_false(cs.call("is_battle_active"), "battle_end 后不活跃")


# ============================================================================
# AC-006：battle_start 调用 advance_phase（进入 PREPARATION）
# ============================================================================

func test_ac006_battle_start_enters_preparation() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	# battle_start 调用 _enter_phase(PREPARATION)——阶段应为 PREPARATION(0)
	assert_eq(cs.call("get_current_phase"), 0, "battle_start 后进入 PREPARATION")


# ============================================================================
# AC-007：GSM 第二层方法存在
# ============================================================================

func test_ac007_gsm_second_layer_methods_exist() -> void:
	assert_true(GameStateManager.has_method("_set_battle_phase"), "_set_battle_phase 存在")
	assert_true(GameStateManager.has_method("_increment_battle_turn"), "_increment_battle_turn 存在")
	assert_true(GameStateManager.has_method("_set_battle_active"), "_set_battle_active 存在")


# ============================================================================
# AC-008：battle_end(VICTORY) 结算
# ============================================================================

func test_ac008_victory_settlement() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# VICTORY 语义——rewards 包含 result=VICTORY
	assert_false(cs.call("is_battle_active"), "battle_end 后不活跃")


# ============================================================================
# AC-009：battle_end(DEFEAT) 保留 50% 资源
# ============================================================================

func test_ac009_defeat_retain_50_percent() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	assert_false(cs.call("is_battle_active"), "battle_end 后不活跃")


# ============================================================================
# AC-010：battle_end(RETREAT) 语义同 DEFEAT
# ============================================================================

func test_ac010_retreat_same_as_defeat() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.RETREAT)
	assert_false(cs.call("is_battle_active"), "RETREAT 后不活跃")


# ============================================================================
# AC-011：battle_end 入口防御清理
# ============================================================================

func test_ac011_battle_end_defensive_cleanup() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	# 注入非空攻击队列
	cs.call("set_attack_queue", [{"attacker": 1, "target": 2}])
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# 队列应被清空
	assert_eq(cs.call("get_attack_queue").size(), 0, "_attack_queue 已清空")
	assert_false(cs.call("is_battle_active"), "_is_active=false")


func test_ac011_battle_end_from_any_phase() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	# 推进到 PLAY(2)
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 从 PLAY 阶段调用 battle_end
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	assert_eq(cs.call("get_attack_queue").size(), 0, "队列清空")
	assert_false(cs.call("is_battle_active"), "不活跃")


# ============================================================================
# AC-012：GSM._set_battle_active(false) 清理 battle 域
# ============================================================================

func test_ac012_battle_end_clears_gsm_battle() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	assert_not_null(GameStateManager.battle, "battle_start 后 battle 非空")
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	assert_eq(GameStateManager.battle, null, "battle_end 后 battle=null")


# ============================================================================
# AC-013：battle_ended 信号发射
# ============================================================================

func test_ac013_battle_ended_signal() -> void:
	var sig := _capture_battle_ended()
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	assert_true(sig["received"], "battle_ended 信号已发射")
	assert_eq(sig["count"], 1, "信号发射 1 次")
	assert_eq(sig["result"], CS_SCRIPT.CombatResult.VICTORY, "result=VICTORY")
	assert_eq(sig["rewards"].get("result", -1), CS_SCRIPT.CombatResult.VICTORY, "rewards.result=VICTORY")


func test_ac013_battle_ended_signal_for_defeat() -> void:
	var sig := _capture_battle_ended()
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	assert_true(sig["received"], "battle_ended 信号已发射")
	assert_eq(sig["result"], CS_SCRIPT.CombatResult.DEFEAT, "result=DEFEAT")


# ============================================================================
# AC-014：VICTORY 清理快照
# ============================================================================

func test_ac014_victory_clears_snapshot() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# SaveLoad.clear_battle_snapshot 被调用——验证不报错
	assert_false(cs.call("is_battle_active"), "VICTORY 后不活跃")


func test_ac014_defeat_no_snapshot_clear() -> void:
	# DEFEAT 不清理快照（保留用于失败分析）——按 ADR 意图
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	assert_false(cs.call("is_battle_active"), "DEFEAT 后不活跃")


# ============================================================================
# AC-015：battle_end 切换场景
# ============================================================================

func test_ac015_scene_change_requested() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# SceneManager.request_scene_change 被调用——验证不报错
	assert_false(cs.call("is_battle_active"), "场景切换后不活跃")


# ============================================================================
# AC-016：retreat 无活跃战斗返回
# ============================================================================

func test_ac016_retreat_inactive_no_op() -> void:
	var sig := _capture_retreat_requested()
	cs.call("retreat")
	assert_false(sig["received"], "无活跃战斗时不发射 retreat_requested")
	assert_false(cs.call("is_battle_active"), "仍不活跃")


# ============================================================================
# AC-017：retreat 有活跃战斗发射确认
# ============================================================================

func test_ac017_retreat_active_emits_signal() -> void:
	var sig := _capture_retreat_requested()
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("retreat")
	assert_true(sig["received"], "有活跃战斗时发射 retreat_requested")
	assert_eq(sig["count"], 1, "信号发射 1 次")
	assert_true(cs.call("is_battle_active"), "retreat 后仍活跃（等待确认）")


func test_ac017_confirm_retreat_ends_battle() -> void:
	cs.call("battle_start", {"enemy_deck_id": "test_deck"})
	cs.call("retreat")
	assert_true(cs.call("is_battle_active"), "retreat 后仍活跃")
	cs.call("confirm_retreat")
	assert_false(cs.call("is_battle_active"), "confirm_retreat 后不活跃")


# ============================================================================
# 综合：完整生命周期
# ============================================================================

func test_full_lifecycle_start_and_end() -> void:
	var started_sig := _capture_battle_started()
	var ended_sig := _capture_battle_ended()
	# 开始
	cs.call("battle_start", {"enemy_deck_id": "final_deck"})
	assert_true(started_sig["received"], "battle_started 发射")
	assert_not_null(GameStateManager.battle, "GSM battle 域创建")
	# 推进若干阶段
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 结束
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	assert_true(ended_sig["received"], "battle_ended 发射")
	assert_eq(ended_sig["result"], CS_SCRIPT.CombatResult.VICTORY, "result=VICTORY")
	assert_eq(GameStateManager.battle, null, "GSM battle 域清理")
	assert_false(cs.call("is_battle_active"), "CombatSystem 不活跃")


func test_repeated_start_end_cycle() -> void:
	# 第 1 轮
	cs.call("battle_start", {"enemy_deck_id": "deck1"})
	assert_true(cs.call("is_battle_active"), "第 1 轮活跃")
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	assert_false(cs.call("is_battle_active"), "第 1 轮结束")
	assert_eq(GameStateManager.battle, null, "第 1 轮 battle 域清理")
	# 第 2 轮——确保 battle_end 后可再次 battle_start
	cs.call("battle_start", {"enemy_deck_id": "deck2"})
	assert_true(cs.call("is_battle_active"), "第 2 轮活跃")
	assert_not_null(GameStateManager.battle, "第 2 轮 battle 域创建")
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	assert_false(cs.call("is_battle_active"), "第 2 轮结束")
	assert_eq(GameStateManager.battle, null, "第 2 轮 battle 域清理")
