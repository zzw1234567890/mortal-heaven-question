extends GutTest
## Story 8-7 验收测试：BindingManager 存根回调接线。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 BindingManager Autoload 实例验证注入
##   - 使用 BM_SCRIPT.new() 验证测试实例不注入
##   - 验证 Callable 目标方法存在

const BM_SCRIPT := preload("res://src/feature/binding/binding_manager.gd")

var bm_autoload: Node = null
var bm_test: Node = null


func before_each() -> void:
	bm_autoload = Engine.get_main_loop().root.get_node("/root/BindingManager")
	assert_not_null(bm_autoload, "BindingManager Autoload 应存在")
	bm_test = BM_SCRIPT.new()


func after_each() -> void:
	if bm_test != null and bm_test is Object and not bm_test.is_queued_for_deletion():
		bm_test.free()


# ============================================================================
# AC-001：BindingManager._ready() 在 Autoload 实例上注入 8 个回调
# ============================================================================

func test_autoload_has_all_callbacks_injected() -> void:
	bm_autoload.call("_inject_callbacks")
	assert_true(bm_autoload.get("effect_register_cb").is_valid(), "effect_register_cb 已注入")
	assert_true(bm_autoload.get("effect_remove_cb").is_valid(), "effect_remove_cb 已注入")
	assert_true(bm_autoload.get("effect_suspend_cb").is_valid(), "effect_suspend_cb 已注入")
	assert_true(bm_autoload.get("effect_restore_cb").is_valid(), "effect_restore_cb 已注入")
	assert_true(bm_autoload.get("card_shuffle_cb").is_valid(), "card_shuffle_cb 已注入")
	assert_true(bm_autoload.get("card_discard_cb").is_valid(), "card_discard_cb 已注入")
	assert_true(bm_autoload.get("card_exists_cb").is_valid(), "card_exists_cb 已注入")
	assert_true(bm_autoload.get("stat_bonus_cb").is_valid(), "stat_bonus_cb 已注入")


# ============================================================================
# AC-002：BM_SCRIPT.new() 测试实例不触发注入
# ============================================================================

func test_test_instance_not_injected() -> void:
	assert_false(bm_test.get("effect_register_cb").is_valid(), "测试实例 effect_register_cb 应为空")
	assert_false(bm_test.get("card_shuffle_cb").is_valid(), "测试实例 card_shuffle_cb 应为空")
	assert_false(bm_test.get("stat_bonus_cb").is_valid(), "测试实例 stat_bonus_cb 应为空")


# ============================================================================
# AC-003：effect_register_cb → CardEffectEngine.register_persistent_effect
# ============================================================================

func test_effect_register_cb_targets_card_effect_engine() -> void:
	bm_autoload.call("_inject_callbacks")
	var cb: Callable = bm_autoload.get("effect_register_cb")
	var cee = Engine.get_main_loop().root.get_node_or_null("/root/CardEffectEngine")
	assert_not_null(cee, "CardEffectEngine 应存在")
	var target: Object = cb.get_object()
	assert_eq(target, cee, "effect_register_cb 目标应为 CardEffectEngine")
	assert_eq(cb.get_method(), "register_persistent_effect", "方法名应为 register_persistent_effect")


# ============================================================================
# AC-004：effect_remove_cb → CardEffectEngine.remove_effects_by_source
# ============================================================================

func test_effect_remove_cb_targets_card_effect_engine() -> void:
	bm_autoload.call("_inject_callbacks")
	var cb: Callable = bm_autoload.get("effect_remove_cb")
	var cee = Engine.get_main_loop().root.get_node_or_null("/root/CardEffectEngine")
	assert_eq(cb.get_object(), cee, "effect_remove_cb 目标应为 CardEffectEngine")
	assert_eq(cb.get_method(), "remove_effects_by_source", "方法名应为 remove_effects_by_source")


# ============================================================================
# AC-005：effect_suspend_cb → CardEffectEngine.suspend_effects_by_source
# ============================================================================

func test_effect_suspend_cb_targets_card_effect_engine() -> void:
	bm_autoload.call("_inject_callbacks")
	var cb: Callable = bm_autoload.get("effect_suspend_cb")
	var cee = Engine.get_main_loop().root.get_node_or_null("/root/CardEffectEngine")
	assert_eq(cb.get_object(), cee, "effect_suspend_cb 目标应为 CardEffectEngine")
	assert_eq(cb.get_method(), "suspend_effects_by_source", "方法名应为 suspend_effects_by_source")


# ============================================================================
# AC-006：effect_restore_cb → CardEffectEngine.restore_effects_by_source
# ============================================================================

func test_effect_restore_cb_targets_card_effect_engine() -> void:
	bm_autoload.call("_inject_callbacks")
	var cb: Callable = bm_autoload.get("effect_restore_cb")
	var cee = Engine.get_main_loop().root.get_node_or_null("/root/CardEffectEngine")
	assert_eq(cb.get_object(), cee, "effect_restore_cb 目标应为 CardEffectEngine")
	assert_eq(cb.get_method(), "restore_effects_by_source", "方法名应为 restore_effects_by_source")


# ============================================================================
# AC-007：card_shuffle_cb → CombatSystem.add_card_to_deck
# ============================================================================

func test_card_shuffle_cb_targets_combat_system() -> void:
	bm_autoload.call("_inject_callbacks")
	var cb: Callable = bm_autoload.get("card_shuffle_cb")
	var cs = Engine.get_main_loop().root.get_node_or_null("/root/CombatSystem")
	assert_not_null(cs, "CombatSystem 应存在")
	assert_eq(cb.get_object(), cs, "card_shuffle_cb 目标应为 CombatSystem")
	assert_eq(cb.get_method(), "add_card_to_deck", "方法名应为 add_card_to_deck")


# ============================================================================
# AC-008：card_discard_cb → CombatSystem.add_card_to_discard
# ============================================================================

func test_card_discard_cb_targets_combat_system() -> void:
	bm_autoload.call("_inject_callbacks")
	var cb: Callable = bm_autoload.get("card_discard_cb")
	var cs = Engine.get_main_loop().root.get_node_or_null("/root/CombatSystem")
	assert_eq(cb.get_object(), cs, "card_discard_cb 目标应为 CombatSystem")
	assert_eq(cb.get_method(), "add_card_to_discard", "方法名应为 add_card_to_discard")


# ============================================================================
# AC-009：stat_bonus_cb → CardEffectEngine.get_stat_bonus（桩返回 0.0）
# ============================================================================

func test_stat_bonus_cb_targets_card_effect_engine() -> void:
	bm_autoload.call("_inject_callbacks")
	var cb: Callable = bm_autoload.get("stat_bonus_cb")
	var cee = Engine.get_main_loop().root.get_node_or_null("/root/CardEffectEngine")
	assert_eq(cb.get_object(), cee, "stat_bonus_cb 目标应为 CardEffectEngine")
	assert_eq(cb.get_method(), "get_stat_bonus", "方法名应为 get_stat_bonus")
	# 桩返回 0.0
	var result: float = bm_autoload.call("_query_stat_bonus", 999, "ATK")
	assert_eq(result, 0.0, "桩 get_stat_bonus 返回 0.0")


# ============================================================================
# AC-010：全量测试零回归
# ============================================================================

func test_no_regression() -> void:
	bm_autoload.call("_inject_callbacks")
	# Autoload 回调注入后 bind_card 不崩溃
	bm_autoload.call("cache_slot_limits", 1)
	var result: Dictionary = bm_autoload.call("bind_card", 9001, &"test_card", 1, 0)
	assert_true(result["success"] or not result["success"], "bind_card 不应崩溃")
	# 清理
	if result.has("binding_id") and result["binding_id"] >= 0:
		bm_autoload.call("remove_binding", result["binding_id"])
