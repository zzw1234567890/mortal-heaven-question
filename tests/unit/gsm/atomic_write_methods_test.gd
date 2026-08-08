extends GutTest
## Story 002 验收测试：GSM 第二层原子写入方法。
##
## 覆盖 AC-003 到 AC-012 的验收标准以及信号发射验证。
## [br]
## [b]注意:[/b] Story 003 引入了帧末延迟发射——数据立即写入，信号通过 call_deferred 延迟。
## 信号测试需在写入后 await 一帧才能验证。

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

var gsm
var _caught_changes: Dictionary
var _caught_resource_type: StringName
var _caught_resource_delta: int
var _caught_resource_balance: int
var _caught_battle_config: Dictionary
var _caught_battle_result: Dictionary
var _caught_batch_count: int


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()
	_caught_changes = {}
	_caught_resource_type = &""
	_caught_resource_delta = 0
	_caught_resource_balance = 0
	_caught_battle_config = {}
	_caught_battle_result = {}
	_caught_batch_count = 0


func after_each() -> void:
	gsm.free()
	gsm = null


# ── 信号捕获回调 ──────────────────────────────────────────────────────

func _on_batch_updated(changes: Dictionary) -> void:
	_caught_changes = changes
	_caught_batch_count += 1


func _on_resource_changed(type_val: StringName, delta: int, balance: int) -> void:
	_caught_resource_type = type_val
	_caught_resource_delta = delta
	_caught_resource_balance = balance


func _on_battle_started(config: Dictionary) -> void:
	_caught_battle_config = config


func _on_battle_ended(result: Dictionary) -> void:
	_caught_battle_result = result


# =========================================================================
# AC-003～AC-012：数据正确性测试（信号延迟不影响——数据立即写入）
# =========================================================================

func test_ac003_add_cultivation_increases_value() -> void:
	gsm.player.cultivation = 500
	gsm.player.max_cultivation = 1000
	gsm.add_cultivation(100, "test")
	assert_eq(gsm.player.cultivation, 600, "修为应从 500 增加到 600")


func test_ac003_add_cultivation_zero_positive_only() -> void:
	var before: int = gsm.player.cultivation
	gsm.add_cultivation(0, "test")
	assert_eq(gsm.player.cultivation, before, "amount=0 不应改变修为")
	gsm.add_cultivation(-5, "test")
	assert_eq(gsm.player.cultivation, before, "负 amount 不应改变修为")


func test_ac004_spend_resource_success() -> void:
	# Story 001 迁移：GSM 第二层方法 _set_resource_ling_shi 直接测试（不依赖 ResourceSystem）
	gsm.player.resources["ling_shi"] = 100
	gsm._set_resource_ling_shi(70)
	assert_eq(gsm.player.resources["ling_shi"], 70, "灵石应从 100 写入到 70")


func test_ac004_spend_resource_exact_balance() -> void:
	# Story 001 迁移：_set_resource_ling_cai 写入指定品质
	gsm._set_resource_ling_cai(1, 50)
	assert_eq(gsm.player.resources["ling_cai"]["low"], 50, "low 品质应写入 50")
	gsm._set_resource_ling_cai(1, 0)
	assert_eq(gsm.player.resources["ling_cai"]["low"], 0, "low 品质应扣至 0")


func test_ac004_set_resource_non_negative_guard() -> void:
	# Story 001 迁移：GSM 第二层方法不校验 amount，但有非负守卫
	gsm.player.resources["ling_shi"] = 100
	gsm._set_resource_ling_shi(-10)
	assert_eq(gsm.player.resources["ling_shi"], 0, "负值应被非负守卫钳为 0")


func test_ac005_set_resource_insufficient_funds_no_concept() -> void:
	# Story 001 迁移：GSM 第二层方法无余额校验概念——直接写入新值
	gsm.player.resources["ling_shi"] = 20
	gsm._set_resource_ling_shi(0)
	assert_eq(gsm.player.resources["ling_shi"], 0, "_set_resource_ling_shi 直接写入新值")


func test_ac006_nonexistent_resource_type_add_rejected() -> void:
	assert_false(gsm.add_resource(&"nonexistent_type", 100), "不存在的资源类型应返回 false")


func test_ac006_nonexistent_resource_type_spend_rejected() -> void:
	assert_false(gsm.spend_resource(&"nonexistent_type", 10), "不存在的资源类型应返回 false")


func test_ac006_add_resource_positive_only() -> void:
	assert_false(gsm.add_resource(&"ling_shi", 0), "amount=0 应返回 false")
	assert_false(gsm.add_resource(&"ling_shi", -5), "负 amount 应返回 false")


func test_ac007_battle_start_initializes_domain() -> void:
	gsm.battle = null
	gsm.battle_start({"enemy_id": "boss_01", "seed": 12345})
	assert_not_null(gsm.battle, "战斗开始后 battle 域应非 null")


func test_ac007_battle_start_contains_snapshot_realm() -> void:
	gsm.battle = null
	var original_realm: int = gsm.player.realm
	gsm.battle_start({"enemy_id": "boss_01"})
	assert_eq(gsm.battle.snapshot_realm, original_realm, "战斗快照应锁定当前境界")
	assert_true(gsm.battle.has("config"), "battle 应包含 config")


func test_ac007_battle_start_duplicate_is_safe() -> void:
	gsm.battle = null
	gsm.battle_start({"enemy_id": "first"})
	var first_battle: Dictionary = gsm.battle
	gsm.battle_start({"enemy_id": "second"})
	assert_eq(gsm.battle, first_battle, "重复调用不应覆盖已有战斗")


func test_ac008_battle_end_clears_domain() -> void:
	gsm.battle = null
	gsm.battle_start({"enemy_id": "test"})
	gsm.battle_end({"result": "victory", "rewards": {"ling_shi": 50}})
	assert_null(gsm.battle, "战斗结束后 battle 域应为 null")


func test_ac008_battle_end_without_battle_warns() -> void:
	gsm.battle = null
	gsm.battle_end({"result": "victory"})
	assert_null(gsm.battle, "无战斗时调用应仍然是 null")


func test_ac009_cultivation_overflow_stored() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	gsm.player.overflow_pool = 0
	gsm.player.cultivation_full = false
	gsm.add_cultivation(100)
	assert_eq(gsm.player.cultivation, 1000, "修为应到上限")
	assert_eq(gsm.player.overflow_pool, 50, "超出部分应入溢出池")
	assert_true(gsm.player.cultivation_full, "溢出时 cultivation_full 应置为 true")


func test_ac009_overflow_accumulates() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	gsm.player.overflow_pool = 50
	gsm.add_cultivation(100)
	assert_eq(gsm.player.cultivation, 1000)
	assert_eq(gsm.player.overflow_pool, 100, "溢出池应累积 50+50=100")


func test_ac010_overflow_absorbed_after_breakthrough() -> void:
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 1500
	gsm.player.overflow_pool = 200
	gsm.add_cultivation(300)
	assert_eq(gsm.player.cultivation, 300, "修为应增加 300")


func test_ac011_reincarnation_resets_player_state() -> void:
	gsm.player.cultivation = 800
	gsm.player.realm = GSM_SCRIPT.RealmLevel.FOUNDATION
	gsm.player.resources["ling_shi"] = 500
	gsm.player.resources["ling_cai"] = 30
	gsm.player.overflow_pool = 100
	gsm.player.max_cultivation = 1500
	gsm.collection.owned_cards = ["card_001", "card_002"]

	gsm.reincarnation_reset()

	assert_eq(gsm.player.cultivation, 0, "修为应归零")
	assert_eq(gsm.player.realm, GSM_SCRIPT.RealmLevel.QI_REFINING, "境界应重置为炼气")
	assert_eq(gsm.player.resources["ling_shi"], 0, "灵石应归零")
	assert_eq(gsm.player.resources["ling_cai"], 0, "灵材应归零")
	assert_eq(gsm.player.overflow_pool, 0, "溢出池应归零")
	assert_false(gsm.player.cultivation_full, "cultivation_full 应重置为 false")
	assert_eq(gsm.player.max_cultivation, gsm.BASE_MAX, "max_cultivation 应重置为 BASE_MAX")
	assert_eq(gsm.collection.owned_cards.size(), 2, "拥有的卡牌应保留")
	assert_eq(gsm.collection.owned_cards[0], "card_001")
	assert_eq(gsm.collection.owned_cards[1], "card_002")


func test_ac011_reincarnation_is_idempotent() -> void:
	gsm.player.cultivation = 500
	gsm.reincarnation_reset()
	assert_eq(gsm.player.cultivation, 0)
	gsm.reincarnation_reset()
	assert_eq(gsm.player.cultivation, 0, "重复调用应保持为零")
	assert_eq(gsm.player.realm, GSM_SCRIPT.RealmLevel.QI_REFINING)


func test_ac012_set_identity_stores_id() -> void:
	gsm.set_identity(&"identity_03")
	assert_eq(gsm.player.identity_id, "identity_03", "身份 ID 应被正确设置")


func test_ac012_set_identity_empty_rejected() -> void:
	var original: String = gsm.player.identity_id
	gsm.set_identity(&"")
	assert_eq(gsm.player.identity_id, original, "空 StringName 应被拒绝")
	gsm.set_identity(&"   ")
	assert_eq(gsm.player.identity_id, original, "空白 StringName 应被拒绝")


func test_ac012_set_identity_overwrite() -> void:
	gsm.set_identity(&"identity_first")
	assert_eq(gsm.player.identity_id, "identity_first")
	gsm.set_identity(&"identity_second")
	assert_eq(gsm.player.identity_id, "identity_second", "身份应可被覆盖")


func test_add_resource_to_existing_type() -> void:
	gsm.player.resources["dan_yao_sui_pian"] = 10
	assert_true(gsm.add_resource(&"dan_yao_sui_pian", 30), "add_resource 应返回 true")
	assert_eq(gsm.player.resources["dan_yao_sui_pian"], 40, "丹药碎片应从 10 增加到 40")


# =========================================================================
# 信号验证（Story 003 延迟发射——需 await 一帧）
# =========================================================================

func test_batch_updated_signal_emitted_on_add_cultivation() -> void:
	gsm.player.cultivation = 500
	gsm.player.max_cultivation = 1000
	gsm.batch_updated.connect(_on_batch_updated)

	gsm.add_cultivation(100)
	await get_tree().process_frame

	assert_true(_caught_changes.has("player.cultivation"), "batch_updated 应包含 player.cultivation")
	assert_eq(_caught_changes["player.cultivation"]["old"], 500, "old 应为 500")
	assert_eq(_caught_changes["player.cultivation"]["new"], 600, "new 应为 600")


func test_batch_updated_signal_emitted_on_spend_resource() -> void:
	gsm.player.resources["ling_shi"] = 100
	gsm.batch_updated.connect(_on_batch_updated)

	gsm.spend_resource(&"ling_shi", 30)
	await get_tree().process_frame

	assert_true(_caught_changes.has("player.resources.ling_shi"), "batch_updated 应包含资源路径")
	assert_eq(_caught_changes["player.resources.ling_shi"]["old"], 100)
	assert_eq(_caught_changes["player.resources.ling_shi"]["new"], 70)


func test_resource_changed_signal_emitted_on_add() -> void:
	gsm.player.resources["ling_shi"] = 50
	gsm.resource_changed.connect(_on_resource_changed)

	gsm.add_resource(&"ling_shi", 25)
	await get_tree().process_frame

	assert_eq(_caught_resource_type, &"ling_shi", "type 应为 ling_shi")
	assert_eq(_caught_resource_delta, 25, "delta 应为 +25")
	assert_eq(_caught_resource_balance, 75, "balance 应为 75")


func test_resource_changed_signal_emitted_on_spend() -> void:
	gsm.player.resources["ling_cai"] = 80
	gsm.resource_changed.connect(_on_resource_changed)

	gsm.spend_resource(&"ling_cai", 30)
	await get_tree().process_frame

	assert_eq(_caught_resource_delta, -30, "消耗时 delta 应为 -30")
	assert_eq(_caught_resource_balance, 50, "balance 应为 50")


func test_battle_started_signal_emitted() -> void:
	## Cat 2a 生命周期信号——仍然立即发射，不需要 await
	gsm.battle = null
	gsm.battle_started.connect(_on_battle_started)

	gsm.battle_start({"enemy_id": "boss_01", "seed": 42})

	assert_eq(_caught_battle_config.get("enemy_id"), "boss_01", "battle_started 应携带 config")
	assert_eq(_caught_battle_config.get("seed"), 42)


func test_battle_ended_signal_emitted() -> void:
	## Cat 2a 生命周期信号——仍然立即发射
	gsm.battle = null
	gsm.battle_start({"enemy_id": "test"})
	gsm.battle_ended.connect(_on_battle_ended)

	gsm.battle_end({"result": "victory", "rewards": {"ling_shi": 100}})

	assert_eq(_caught_battle_result.get("result"), "victory", "battle_ended 应携带 result")
	assert_eq(_caught_battle_result["rewards"]["ling_shi"], 100)


func test_reincarnation_emits_batch_updated() -> void:
	gsm.player.cultivation = 800
	gsm.player.realm = GSM_SCRIPT.RealmLevel.FOUNDATION
	gsm.player.resources["ling_shi"] = 500
	gsm.player.overflow_pool = 100
	gsm.player.max_cultivation = 1500
	gsm.player.cultivation_full = true
	gsm.batch_updated.connect(_on_batch_updated)

	gsm.reincarnation_reset()
	await get_tree().process_frame

	assert_true(_caught_changes.has("player.cultivation"), "应包含 cultivation")
	assert_true(_caught_changes.has("player.realm"), "应包含 realm")
	assert_true(_caught_changes.has("player.overflow_pool"), "应包含 overflow_pool")
	assert_true(_caught_changes.has("player.max_cultivation"), "应包含 max_cultivation")
	assert_eq(_caught_changes["player.cultivation"]["old"], 800)
	assert_eq(_caught_changes["player.cultivation"]["new"], 0)


func test_set_identity_duplicate_emits_only_once() -> void:
	## Story 003 适配：信号延迟发射——同值调用两次，帧末仅发射一次
	gsm.batch_updated.connect(_on_batch_updated)

	gsm.set_identity(&"duplicate_test")
	gsm.set_identity(&"duplicate_test")  # 同值→去重，不进入缓冲区
	await get_tree().process_frame

	assert_eq(_caught_batch_count, 1, "同值第二次不应再次发射信号")


func test_batch_updated_on_overflow() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	gsm.player.overflow_pool = 0
	gsm.player.cultivation_full = false
	gsm.batch_updated.connect(_on_batch_updated)

	gsm.add_cultivation(100)
	await get_tree().process_frame

	assert_true(_caught_changes.has("player.cultivation_full"), "溢出时应包含 cultivation_full")
	assert_true(_caught_changes.has("player.overflow_pool"), "溢出时应包含 overflow_pool")
	assert_eq(_caught_changes["player.overflow_pool"]["old"], 0)
	assert_eq(_caught_changes["player.overflow_pool"]["new"], 50)
