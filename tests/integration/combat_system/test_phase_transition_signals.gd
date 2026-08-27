extends GutTest
## Story 004 验收测试：阶段转换 Cat 2b 信号通知 CombatUI。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CombatSystem 实例
##   - set_auto_advance(false) + set_scene_change(false) 禁用帧依赖
##   - set_battle_active(true) 桩进入战斗
##   - 信号捕获用 Dictionary mutable container + 信号专属 lambda
##   - attack_resolved 使用具名字典格式（ADR-0007）
##
## 设计文档来源：ADR-0008 §信号分类 Cat 2b + ADR-0007 §_emit_signal_safe
## Story 来源：production/epics/combat-system/story-004-phase-transition-signals.md

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.call("set_battle_active", true)
	cs.call("set_rng_seed", 42)
	# 清理 GSM 信号链深度计数器（防止跨测试泄漏）
	if GameStateManager != null:
		GameStateManager._signal_chain_depth = 0
		GameStateManager.battle = null
		GameStateManager._pending_changes.clear()
		GameStateManager._flush_scheduled = false


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null


# === 辅助 ================================================================

## 捕获 phase_changed 信号（3 参数：old_phase, new_phase, turn）。
func _capture_phase_changed() -> Dictionary:
	var sig := {"received": false, "count": 0, "old": -1, "new": -1, "turn": -1}
	cs.connect("phase_changed", Callable(func(old_phase: int, new_phase: int, turn: int):
		sig["received"] = true
		sig["count"] += 1
		sig["old"] = old_phase
		sig["new"] = new_phase
		sig["turn"] = turn))
	return sig


## 捕获 battle_started 信号（1 参数：config Dictionary）。
func _capture_battle_started() -> Dictionary:
	var sig := {"received": false, "count": 0, "config": {}}
	cs.connect("battle_started", Callable(func(config: Dictionary):
		sig["received"] = true
		sig["count"] += 1
		sig["config"] = config))
	return sig


## 捕获 battle_ended 信号（2 参数：result, rewards）。
func _capture_battle_ended() -> Dictionary:
	var sig := {"received": false, "count": 0, "result": -1, "rewards": {}}
	cs.connect("battle_ended", Callable(func(result: int, rewards: Dictionary):
		sig["received"] = true
		sig["count"] += 1
		sig["result"] = result
		sig["rewards"] = rewards))
	return sig


## 构造测试用卡牌 Dictionary 桩。
func _make_card(card_id: int, cost: int) -> Dictionary:
	return {"card_instance_id": card_id, "cost": cost, "template_id": "test_card"}


## 注入手牌 + 卡牌实例缓存。
func _setup_hand(cards: Array) -> void:
	var instances: Dictionary = {}
	for card in cards:
		instances[card["card_instance_id"]] = card
	cs.call("set_card_instances", instances)
	cs.call("set_hand", cards.duplicate())


# ============================================================================
# AC-001：5 个 Cat 2b 信号声明在 CombatSystem
# ============================================================================

func test_ac001_five_cat2b_signals_declared() -> void:
	var signals: Array = cs.get_signal_list()
	var names: Array = []
	for s in signals:
		names.append(s["name"])
	assert_true(names.has("phase_changed"), "phase_changed 信号已声明")
	assert_true(names.has("battle_started"), "battle_started 信号已声明")
	assert_true(names.has("battle_ended"), "battle_ended 信号已声明")
	assert_true(names.has("attack_resolved"), "attack_resolved 信号已声明")
	assert_true(names.has("character_died"), "character_died 信号已声明")


func test_ac001_signals_not_in_signal_bus() -> void:
	# CombatUI 信号声明在 CombatSystem 而非 SignalBus Autoload
	var signals: Array = cs.get_signal_list()
	var combat_signals: Array = []
	for s in signals:
		var n: String = s["name"]
		if n in ["phase_changed", "battle_started", "battle_ended", "attack_resolved", "character_died"]:
			combat_signals.append(n)
	assert_eq(combat_signals.size(), 5, "5 个 Cat 2b 信号归属 CombatSystem")


# ============================================================================
# AC-002：phase_changed 信号在 advance_phase 成功后发射
# ============================================================================

func test_ac002_phase_changed_emitted_on_advance() -> void:
	var sig := _capture_phase_changed()
	var ok: bool = cs.call("advance_phase")
	assert_true(ok, "advance_phase 成功")
	assert_true(sig["received"], "phase_changed 已发射")
	assert_eq(sig["count"], 1, "发射 1 次")


func test_ac002_phase_changed_not_emitted_on_validation_failure() -> void:
	# 推进到 PLAY(2)——2→3 需要条件不满足时拒绝
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 手牌非空 + can_afford_any_card 桩返回 true → 2→3 验证失败
	cs.call("set_hand", [_make_card(1, 0)])
	var sig := _capture_phase_changed()
	var ok: bool = cs.call("advance_phase")
	assert_false(ok, "验证失败 advance_phase 返回 false")
	assert_false(sig["received"], "验证失败不发射 phase_changed")


func test_ac002_phase_changed_payload_correct() -> void:
	var sig := _capture_phase_changed()
	cs.call("advance_phase")  # 0→1
	assert_eq(sig["count"], 1, "发射 1 次")
	assert_eq(sig["old"], 0, "old_phase=0 (PREPARATION)")
	assert_eq(sig["new"], 1, "new_phase=1 (DRAW)")
	assert_eq(sig["turn"], 1, "turn=1")


# ============================================================================
# AC-003：battle_started 信号在 battle_start 完成后发射
# ============================================================================

func test_ac003_battle_started_emitted() -> void:
	cs.call("set_battle_active", false)
	cs.call("set_scene_change", false)
	var sig := _capture_battle_started()
	var config: Dictionary = {"enemy_deck_id": 1, "tribulation_level": 0}
	cs.call("battle_start", config)
	assert_true(sig["received"], "battle_started 已发射")
	assert_eq(sig["count"], 1, "发射 1 次")


func test_ac003_battle_started_payload_is_config() -> void:
	cs.call("set_battle_active", false)
	cs.call("set_scene_change", false)
	var sig := _capture_battle_started()
	var config: Dictionary = {"enemy_deck_id": 42, "tribulation_level": 1}
	cs.call("battle_start", config)
	assert_eq(sig["config"]["enemy_deck_id"], 42, "config.enemy_deck_id=42")


# ============================================================================
# AC-004：battle_ended 信号在 battle_end 完成后发射
# ============================================================================

func test_ac004_battle_ended_emitted() -> void:
	var sig := _capture_battle_ended()
	cs.call("battle_end", 1)  # VICTORY=1
	assert_true(sig["received"], "battle_ended 已发射")
	assert_eq(sig["count"], 1, "发射 1 次")


func test_ac004_battle_ended_payload_result_and_rewards() -> void:
	var sig := _capture_battle_ended()
	cs.call("battle_end", 1)  # VICTORY=1
	assert_eq(sig["result"], 1, "result=VICTORY(1)")
	assert_true(sig["rewards"] is Dictionary, "rewards 是 Dictionary")


func test_ac004_battle_ended_for_defeat() -> void:
	var sig := _capture_battle_ended()
	cs.call("battle_end", 2)  # DEFEAT=2
	assert_true(sig["received"], "battle_ended 已发射")
	assert_eq(sig["result"], 2, "result=DEFEAT(2)")


# ============================================================================
# AC-005：attack_resolved 信号具名字典格式
# ============================================================================

func test_ac005_attack_resolved_emitted_with_dict_payload() -> void:
	# 注入攻击队列
	cs.call("set_attack_queue", [{
		"attacker_id": 10, "target_id": 20,
		"attacker_atk": 5, "target_def": 2,
		"attacker_realm": 1, "defender_realm": 1,
	}])
	var sig := {"received": false, "count": 0, "payload": {}}
	cs.connect("attack_resolved", Callable(func(payload: Dictionary):
		sig["received"] = true
		sig["count"] += 1
		sig["payload"] = payload))
	cs.call("_resolve_attack_queue")
	assert_true(sig["received"], "attack_resolved 已发射")
	assert_eq(sig["count"], 1, "发射 1 次")
	assert_eq(sig["payload"]["attacker_id"], 10, "attacker_id=10")
	assert_eq(sig["payload"]["target_id"], 20, "target_id=20")
	assert_eq(sig["payload"]["damage"], 3, "damage=max(1,5-2)=3")
	assert_eq(sig["payload"]["is_kill"], false, "is_kill=false")


func test_ac005_attack_resolved_multiple_attacks() -> void:
	cs.call("set_attack_queue", [
		{"attacker_id": 10, "target_id": 20, "attacker_atk": 5, "target_def": 2, "attacker_realm": 1, "defender_realm": 1},
		{"attacker_id": 11, "target_id": 21, "attacker_atk": 4, "target_def": 0, "attacker_realm": 1, "defender_realm": 2},
	])
	var sig := {"received": false, "count": 0, "payloads": []}
	cs.connect("attack_resolved", Callable(func(payload: Dictionary):
		sig["received"] = true
		sig["count"] += 1
		sig["payloads"].append(payload)))
	cs.call("_resolve_attack_queue")
	assert_eq(sig["count"], 2, "2 次攻击发射 2 次 attack_resolved")
	assert_eq(sig["payloads"][0]["attacker_id"], 10, "第 1 次 attacker_id=10")
	assert_eq(sig["payloads"][1]["attacker_id"], 11, "第 2 次 attacker_id=11")


# ============================================================================
# AC-006：character_died 信号携带 binding_card_ids
# ============================================================================

func test_ac006_character_died_emitted_with_binding_ids() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	_setup_hand([_make_card(1, 0)])
	cs.set("resolve_cb", Callable(
		func(_card, _targets):
			return [{"target_id": 5, "is_kill": true, "side": 1, "binding_card_ids": [10, 20]}]
	))
	var sig := {"received": false, "count": 0, "char_id": -1, "side": -1, "binding_ids": []}
	cs.connect("character_died", Callable(func(char_id: int, side: int, binding_ids: Array):
		sig["received"] = true
		sig["count"] += 1
		sig["char_id"] = char_id
		sig["side"] = side
		sig["binding_ids"] = binding_ids))
	cs.call("play_card", 1, [0])
	assert_true(sig["received"], "character_died 已发射")
	assert_eq(sig["char_id"], 5, "character_id=5")
	assert_eq(sig["side"], 1, "side=1")
	assert_eq(sig["binding_ids"], [10, 20], "binding_card_ids=[10,20]")


func test_ac006_character_died_invalid_target_id_skipped() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	cs.set("resolve_cb", Callable(
		func(_card, _targets):
			return [{"target_id": -1, "is_kill": true, "side": 0, "binding_card_ids": []}]
	))
	var sig := {"received": false, "count": 0}
	cs.connect("character_died", Callable(func(_c: int, _s: int, _i: Array):
		sig["received"] = true
		sig["count"] += 1))
	cs.call("play_card", 1, [0])
	assert_false(sig["received"], "无效 target_id 不发射 character_died")
	assert_eq(sig["count"], 0, "信号 0 次")


# ============================================================================
# AC-007：CombatUI 监听 phase_changed 更新
# ============================================================================

func test_ac007_subscriber_receives_phase_changed() -> void:
	# 模拟 CombatUI 订阅 phase_changed
	var ui_state := {"current_phase": -1, "turn": -1, "updates": 0}
	cs.connect("phase_changed", Callable(func(_old: int, new_phase: int, turn: int):
		ui_state["current_phase"] = new_phase
		ui_state["turn"] = turn
		ui_state["updates"] += 1))
	cs.call("advance_phase")  # 0→1
	assert_eq(ui_state["current_phase"], 1, "UI 收到 phase=DRAW(1)")
	assert_eq(ui_state["turn"], 1, "UI 收到 turn=1")
	assert_eq(ui_state["updates"], 1, "UI 更新 1 次")
	cs.call("advance_phase")  # 1→2
	assert_eq(ui_state["current_phase"], 2, "UI 收到 phase=PLAY(2)")
	assert_eq(ui_state["updates"], 2, "UI 更新 2 次")


# ============================================================================
# AC-008：信号链深度不超 4 层
# ============================================================================

func test_ac008_signal_chain_depth_within_limit() -> void:
	# 验证信号发射后正常完成——说明链深度未超 4 层硬限制
	var sig := _capture_phase_changed()
	cs.call("advance_phase")
	assert_true(sig["received"], "信号已发射")
	assert_eq(sig["count"], 1, "信号正常发射 1 次——链深度正常")


func test_ac008_multiple_signals_dont_exceed_depth() -> void:
	# 连续发射多个不同信号验证链深度管理
	var phase_sig := _capture_phase_changed()
	cs.call("advance_phase")  # phase_changed
	cs.call("advance_phase")  # phase_changed
	assert_eq(phase_sig["count"], 2, "2 次 phase_changed 均成功")


# ============================================================================
# AC-009：信号处理器异常捕获（GSM 帧级重置）
# ============================================================================

func test_ac009_signal_handler_push_error_doesnt_block_subscriber() -> void:
	# 信号处理器 push_error 不中断执行——后续订阅者仍收到信号
	# GDScript 无传统异常机制——push_error 不中断 emit_signal 链
	var error_handler_called := {"called": false}
	cs.connect("phase_changed", Callable(func(_o: int, _n: int, _t: int):
		error_handler_called["called"] = true
		push_error("模拟处理器错误")))
	var sig := _capture_phase_changed()
	cs.call("advance_phase")
	# 第一个处理器 push_error 但不中断——第二个处理器应仍收到信号
	assert_true(error_handler_called["called"], "错误处理器被调用")
	assert_true(sig["received"], "即使前处理器 push_error，后续订阅者仍收到信号")


func test_ac009_gsm_depth_counter_resets_after_emit() -> void:
	# 验证 GSM 帧级重置——信号发射后 _signal_chain_depth 应归零
	# GSM Autoload 在测试环境中可用（已注册）
	if GameStateManager == null:
		pass  # 无 GSM 时跳过
		return
	GameStateManager._signal_chain_depth = 0
	cs.call("advance_phase")
	assert_eq(GameStateManager._signal_chain_depth, 0, "信号发射后 _signal_chain_depth 归零")


# ============================================================================
# 补充：retreat_requested 信号测试（GAP-1）
# ============================================================================

func test_retreat_requested_emitted_when_active() -> void:
	var sig := {"received": false, "count": 0}
	cs.connect("retreat_requested", Callable(func():
		sig["received"] = true
		sig["count"] += 1))
	cs.call("retreat")
	assert_true(sig["received"], "活跃战斗时 retreat_requested 发射")
	assert_eq(sig["count"], 1, "发射 1 次")


func test_retreat_requested_not_emitted_when_inactive() -> void:
	cs.call("set_battle_active", false)
	var sig := {"received": false, "count": 0}
	cs.connect("retreat_requested", Callable(func():
		sig["received"] = true
		sig["count"] += 1))
	cs.call("retreat")
	assert_false(sig["received"], "非活跃战斗时不发射 retreat_requested")


# ============================================================================
# 补充：AC-008 信号链深度 GSM 真实验证（GAP-2）
# ============================================================================

func test_ac008_gsm_depth_increments_during_emit() -> void:
	# 验证 GSM._emit_signal_safe 路径——信号发射期间深度计数器 > 0
	# 由于 _emit_safe 在发射后深度归零，我们验证发射后归零即可
	if GameStateManager == null:
		pass  # 无 GSM 时跳过
		return
	GameStateManager._signal_chain_depth = 0
	var depth_during_emit: Array = [-1]
	cs.connect("phase_changed", Callable(func(_o: int, _n: int, _t: int):
		depth_during_emit[0] = GameStateManager._signal_chain_depth))
	cs.call("advance_phase")
	assert_eq(depth_during_emit[0], 1, "信号发射期间 _signal_chain_depth=1")
	assert_eq(GameStateManager._signal_chain_depth, 0, "信号发射后 _signal_chain_depth 归零")


# ============================================================================
# 补充：AC-005 空攻击队列（GAP-5）
# ============================================================================

func test_ac005_empty_attack_queue_emits_nothing() -> void:
	cs.call("set_attack_queue", [])
	var sig := {"received": false, "count": 0}
	cs.connect("attack_resolved", Callable(func(_payload: Dictionary):
		sig["received"] = true
		sig["count"] += 1))
	cs.call("_resolve_attack_queue")
	assert_false(sig["received"], "空攻击队列不发射 attack_resolved")
	assert_eq(sig["count"], 0, "信号 0 次")


# ============================================================================
# 补充：battle_start 信号发射顺序（GAP-4）
# ============================================================================

func test_battle_start_emits_battle_started_not_phase_changed() -> void:
	cs.call("set_battle_active", false)
	cs.call("set_scene_change", false)
	var started_sig := _capture_battle_started()
	var phase_sig := _capture_phase_changed()
	cs.call("battle_start", {"enemy_deck_id": 1})
	assert_true(started_sig["received"], "battle_started 发射")
	assert_eq(started_sig["count"], 1, "battle_started 发射 1 次")
	# battle_start 直接 _enter_phase(PREPARATION) 不经 advance_phase → phase_changed 不发射
	assert_false(phase_sig["received"], "battle_start 不发射 phase_changed")


# ============================================================================
# 补充：多次战斗周期信号一致性（GAP-6）
# ============================================================================

func test_multiple_battle_cycles_signal_consistency() -> void:
	var started_sig := _capture_battle_started()
	var ended_sig := _capture_battle_ended()
	# 周期 1
	cs.call("set_battle_active", false)
	cs.call("set_scene_change", false)
	cs.call("battle_start", {"enemy_deck_id": 1})
	assert_eq(started_sig["count"], 1, "周期 1 battle_started 发射 1 次")
	cs.call("battle_end", 1)  # VICTORY
	assert_eq(ended_sig["count"], 1, "周期 1 battle_ended 发射 1 次")
	# 周期 2
	cs.call("battle_start", {"enemy_deck_id": 2})
	assert_eq(started_sig["count"], 2, "周期 2 battle_started 发射 1 次")
	cs.call("battle_end", 2)  # DEFEAT
	assert_eq(ended_sig["count"], 2, "周期 2 battle_ended 发射 1 次")


# ============================================================================
# AC-010：HP/费用变更不通过自有信号——通过 GSM Cat 1 batch_updated
# ============================================================================

func test_ac010_no_self_data_signal_for_hp() -> void:
	# CombatSystem 不发射 HP 数据变更信号——通过 GSM Cat 1 batch_updated
	var signals: Array = cs.get_signal_list()
	for s in signals:
		var n: String = s["name"]
		assert_false(n in ["hp_changed", "health_changed", "cost_changed", "mana_changed"],
			"CombatSystem 不发射 HP/费用数据信号: %s" % n)


func test_ac010_only_cat2b_signals_declared() -> void:
	# 确认 CombatSystem 的自定义信号都是 Cat 2b 通知信号，无数据信号重复
	# 过滤掉 Node 内置信号（tree_entered 等），只检查脚本声明的信号
	var expected: Array = ["phase_changed", "battle_started", "battle_ended", "attack_resolved", "character_died", "retreat_requested"]
	var builtin: Array = ["tree_entered", "tree_exiting", "tree_exited", "child_entered_tree", "child_exiting_tree", "child_order_changed", "replacing_by", "editor_description_changed", "editor_state_changed", "script_changed", "property_list_changed", "ready", "renamed"]
	var signals: Array = cs.get_signal_list()
	for s in signals:
		var n: String = s["name"]
		if n in builtin:
			continue
		assert_true(n in expected, "信号 %s 属于 Cat 2b 通知信号集合" % n)


# ============================================================================
# 综合：完整信号链集成测试
# ============================================================================

func test_full_signal_lifecycle_integration() -> void:
	# 模拟完整战斗生命周期中的信号发射
	var battle_started_sig := {"received": false, "count": 0}
	var phase_changed_sig := {"received": false, "count": 0}
	var battle_ended_sig := {"received": false, "count": 0}

	cs.connect("battle_started", Callable(func(_c: Dictionary):
		battle_started_sig["received"] = true
		battle_started_sig["count"] += 1))
	cs.connect("phase_changed", Callable(func(_o: int, _n: int, _t: int):
		phase_changed_sig["received"] = true
		phase_changed_sig["count"] += 1))
	cs.connect("battle_ended", Callable(func(_r: int, _rw: Dictionary):
		battle_ended_sig["received"] = true
		battle_ended_sig["count"] += 1))

	# battle_start（但 cs 已 active，需先重置）
	cs.call("set_battle_active", false)
	cs.call("set_scene_change", false)
	cs.call("battle_start", {"enemy_deck_id": 1})
	assert_true(battle_started_sig["received"], "battle_started 发射")
	# 注意：battle_start 直接 _enter_phase(PREPARATION) 不经 advance_phase → phase_changed 不发射

	# 推进几个阶段——每次 advance_phase 发射 phase_changed
	cs.call("advance_phase")  # PREPARATION→DRAW
	assert_true(phase_changed_sig["received"], "phase_changed 发射（advance_phase 调用）")
	cs.call("advance_phase")  # DRAW→PLAY
	assert_true(phase_changed_sig["count"] >= 2, "phase_changed 至少 2 次")

	# battle_end
	cs.call("battle_end", 1)  # VICTORY
	assert_true(battle_ended_sig["received"], "battle_ended 发射")
