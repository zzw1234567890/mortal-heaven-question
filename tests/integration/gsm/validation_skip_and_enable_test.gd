extends GutTest
## Story 005 验收测试：GSM 校验跳过模式 + enable_validation 激活流程。
## 覆盖 AC-020~AC-023。

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

var gsm
var _card_db: Dictionary


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()
	_card_db = {
		"card_001": {"id": 1, "name": "火球术"},
		"card_002": {"id": 2, "name": "剑气斩"},
		"card_003": {"id": 3, "name": "护体罡气"},
	}


func after_each() -> void:
	gsm.free()
	gsm = null
	_card_db.clear()


# ═════════════════════════════════════════════════════════════════════════════
# AC-020：无效卡牌 ID 被拒绝（校验开启后）
# ═════════════════════════════════════════════════════════════════════════════

func test_ac020_invalid_card_id_rejected_after_validation() -> void:
	gsm.enable_validation(_card_db)
	assert_true(gsm.validation_enabled, "校验应已开启")

	var ok: bool = gsm.add_card_to_collection({"template_id": "invalid_card_999"})
	assert_false(ok, "无效 template_id 应被拒绝")
	assert_eq(gsm.collection.owned_cards.size(), 0, "卡牌不应被添加")
	assert_eq(gsm.collection.total_count, 0, "total_count 应不变")


func test_ac020_empty_template_id_rejected() -> void:
	gsm.enable_validation(_card_db)
	var ok: bool = gsm.add_card_to_collection({"template_id": ""})
	assert_false(ok, "空 template_id 应被拒绝")
	assert_eq(gsm.collection.owned_cards.size(), 0)


func test_ac020_valid_card_accepted_after_validation() -> void:
	gsm.enable_validation(_card_db)
	var ok: bool = gsm.add_card_to_collection({"template_id": "card_001", "id": 1})
	assert_true(ok, "有效 template_id 应被接受")
	assert_eq(gsm.collection.owned_cards.size(), 1)
	assert_eq(gsm.collection.total_count, 1)


# ═════════════════════════════════════════════════════════════════════════════
# AC-021：校验跳过模式下拒绝卡牌写入
# ═════════════════════════════════════════════════════════════════════════════

func test_ac021_validation_skip_mode_rejects_write() -> void:
	# GSM 启动时 validation_enabled 默认为 false
	assert_false(gsm.validation_enabled, "GSM 启动时应为校验跳过模式")

	var ok: bool = gsm.add_card_to_collection({"template_id": "card_001"})
	assert_false(ok, "校验跳过模式下应拒绝写入")
	assert_eq(gsm.collection.owned_cards.size(), 0, "卡牌不应被添加")


func test_ac021_multiple_calls_in_skip_mode_all_rejected() -> void:
	assert_false(gsm.validation_enabled)
	gsm.add_card_to_collection({"template_id": "card_001"})
	gsm.add_card_to_collection({"template_id": "card_002"})
	gsm.add_card_to_collection({"template_id": "card_003"})
	assert_eq(gsm.collection.owned_cards.size(), 0, "多次调用均应被拒绝")


# ═════════════════════════════════════════════════════════════════════════════
# AC-022：enable_validation 正常激活
# ═════════════════════════════════════════════════════════════════════════════

func test_ac022_enable_validation_sets_flag() -> void:
	gsm.enable_validation(_card_db)
	assert_true(gsm.validation_enabled, "校验应开启")


func test_ac022_card_validation_ready_emitted() -> void:
	var emitted := [false]  # 用数组包装——GDScript lambda 按值捕获基本类型
	gsm.card_validation_ready.connect(func() -> void:
		emitted[0] = true
	)
	gsm.enable_validation(_card_db)
	assert_true(emitted[0], "card_validation_ready 应发射")


func test_ac022_add_card_works_after_enable() -> void:
	gsm.enable_validation(_card_db)
	var ok: bool = gsm.add_card_to_collection({"template_id": "card_001", "id": 1})
	assert_true(ok, "激活校验后有效卡牌应被接受")
	assert_eq(gsm.collection.owned_cards.size(), 1)


func test_ac022_enable_with_empty_db_rejected() -> void:
	gsm.enable_validation({})
	assert_false(gsm.validation_enabled, "空模板数据库应被拒绝")


# ═════════════════════════════════════════════════════════════════════════════
# AC-023：重复调用 enable_validation 被拒绝
# ═════════════════════════════════════════════════════════════════════════════

func test_ac023_double_enable_validation_ignored() -> void:
	gsm.enable_validation(_card_db)
	assert_true(gsm.validation_enabled)

	# 第二个不同的数据库——应被忽略
	var second_db := {"card_004": {"id": 4}}
	gsm.enable_validation(second_db)

	# 数据库不应被覆盖
	assert_true(gsm._validate_card_ref("card_001"), "第一个数据库中的 card_001 仍应可校验")
	assert_false(gsm._validate_card_ref("card_004"), "第二个数据库中的 card_004 不应被加入")


func test_ac023_double_enable_with_empty_db_ignored() -> void:
	gsm.enable_validation(_card_db)
	gsm.enable_validation({})
	assert_true(gsm.validation_enabled, "校验仍应开启")
	assert_true(gsm._validate_card_ref("card_001"), "数据库不应被空字典覆盖")


# ═════════════════════════════════════════════════════════════════════════════
# 补充测试：回溯校验
# ═════════════════════════════════════════════════════════════════════════════

func test_retroactive_cleanup_on_enable() -> void:
	# 模拟在 enable_validation 前数据已被污染（通过直接写入 collection）
	gsm.collection.owned_cards.append({"template_id": "bad_card", "id": -1})
	gsm.collection.owned_cards.append({"template_id": "card_001", "id": 1})
	gsm.collection.total_count = 2

	gsm.enable_validation(_card_db)

	# 回溯校验应移除无效卡牌
	assert_eq(gsm.collection.owned_cards.size(), 1, "无效卡牌应被移除")
	assert_eq(gsm.collection.owned_cards[0].template_id, "card_001", "有效卡牌应保留")
	assert_eq(gsm.collection.total_count, 1, "total_count 应更新")


func test_add_card_signals_card_collection_changed() -> void:
	gsm.enable_validation(_card_db)

	var captured := [-1, &""]  # [card_id, action]
	gsm.card_collection_changed.connect(func(cid: int, action: StringName) -> void:
		captured[0] = cid
		captured[1] = action
	)

	gsm.add_card_to_collection({"template_id": "card_001", "id": 42})
	assert_eq(captured[0], 42)
	assert_eq(captured[1], &"added")


func test_add_card_duplicate_inst_dict_is_independent() -> void:
	gsm.enable_validation(_card_db)
	var inst := {"template_id": "card_001", "id": 1, "upgrade_level": 0}
	gsm.add_card_to_collection(inst)

	# 修改原始字典不应影响已存入 collection 的卡牌
	inst["upgrade_level"] = 5
	assert_eq(gsm.collection.owned_cards[0].upgrade_level, 0, "已存入的卡牌应与输入解耦")
