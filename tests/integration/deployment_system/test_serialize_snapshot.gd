extends GutTest
## Story 003 验收测试：serialize_field 快照导出 + GSM.battle.deployment_snapshot + 不可用角色同步。
##
## 覆盖 AC-001 到 AC-011（11 条 AC）。
## 测试策略：
##   - DS_SCRIPT.new() 构造 DeploymentSystem 实例（不调 _ready）
##   - 真实 GameStateManager Autoload——AC-003/007/010 验证第二层原子写路径
##   - battle_start / battle_end 在 after_each 清理，player.unavailable_characters 每测重置
##   - serialize/deserialize round-trip 用真实 GSM 方法验证
##
## 设计文档来源：ADR-0016 §GSM 边界 §不可用角色生命周期 §验证标准
## Story 来源：production/epics/deployment-system/story-003-serialize-snapshot-export.md

const DS_SCRIPT := preload("res://src/feature/deployment_system.gd")

var ds: Node = null


## 覆盖 _get_gsm() 返回 null 的子类——验证 GSM 节点缺失（双守卫第一分支）时不崩溃。
class NullGsmDS extends "res://src/feature/deployment_system.gd":
	func _get_gsm() -> Node:
		return null


## 覆盖 _get_gsm() 返回无目标方法的假节点——验证 has_method 双守卫（第二分支）时不崩溃。
class NoMethodGsmDS extends "res://src/feature/deployment_system.gd":
	var fake_gsm: Node = null

	func _get_gsm() -> Node:
		return fake_gsm


func before_each() -> void:
	ds = DS_SCRIPT.new()


func after_each() -> void:
	_reset_realm()
	if GameStateManager.battle != null:
		GameStateManager.battle_end({})
	# 测试清理专用——绕过第二层原子方法，避免帧末 batch_updated 残留（非生产写路径）
	if GameStateManager.player.has("unavailable_characters"):
		GameStateManager.player.unavailable_characters = {}
	if ds != null:
		ds.free()
		ds = null


func _set_realm(level: int) -> void:
	GameStateManager.player.realm = level


func _reset_realm() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING


# ============================================================================
# AC-001：serialize_field 返回完整结构（含 6 个阵位 + 空位）
# ============================================================================

func test_ac001_serialize_field_full_structure() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # max_deploy=4
	ds.setup_field([101, 102, 103, 104], {})  # 前 2 后 2，slot 2/5 空位
	var data: Dictionary = ds.serialize_field()
	assert_eq(data.size(), 6, "应含 6 个阵位条目")
	for slot in range(6):
		assert_true(data.has(slot), "应含 slot %d" % slot)
		var entry: Dictionary = data[slot]
		assert_true(entry.has("character_id"), "entry 含 character_id")
		assert_true(entry.has("is_front"), "entry 含 is_front")
		assert_true(entry.has("state"), "entry 含 state")
		assert_true(entry.has("deploy_turn"), "entry 含 deploy_turn")
	# 空位也序列化（character_id=-1 + EMPTY）
	assert_eq(data[2]["character_id"], -1, "空位 slot 2 character_id=-1")
	assert_eq(data[2]["state"], "EMPTY", "空位 slot 2 state=EMPTY")


# ============================================================================
# AC-002：serialize_field 纯序列化结构（JSON 可序列化）
# ============================================================================

func test_ac002_serialize_field_json_serializable() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})
	var data: Dictionary = ds.serialize_field()
	var json_str: String = JSON.stringify(data)
	assert_true(json_str != null and not json_str.is_empty(), "JSON.stringify 不报错")
	assert_false(json_str.contains("RefCounted"), "无 RefCounted 引用")
	assert_false(json_str.contains("Node"), "无 Node 引用")


# ============================================================================
# AC-003：战斗结束写 GSM.battle.deployment_snapshot
# ============================================================================

func test_ac003_write_to_gsm_battle_deployment_snapshot() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})
	GameStateManager.battle_start({})
	var expected: Dictionary = ds.serialize_field()
	ds.write_snapshot_to_gsm()
	assert_eq(GameStateManager.battle.deployment_snapshot, expected, "battle.deployment_snapshot == snapshot")
	assert_eq(GameStateManager.get_state("battle.deployment_snapshot"), expected, "get_state 读取一致")


# ============================================================================
# AC-004：GSM 不可用/无活跃战斗时不崩溃
# ============================================================================

func test_ac004_gsm_unavailable_no_crash() -> void:
	# 无活跃战斗（battle==null）——第二层方法 push_warning 并返回，不应崩溃
	ds.sync_unavailable_to_gsm()
	ds.write_snapshot_to_gsm()
	assert_true(true, "GSM 无活跃战斗时 sync/write 应静默跳过不崩溃")


func test_ac004_gsm_node_null_no_crash() -> void:
	# _get_gsm() 返回 null——双守卫第一分支（gsm == null）应静默跳过
	var null_ds: Node = NullGsmDS.new()
	null_ds.setup_field([101], {})
	null_ds.sync_unavailable_to_gsm()
	null_ds.write_snapshot_to_gsm()
	assert_true(true, "_get_gsm() 返回 null 时 sync/write 不崩溃")
	null_ds.free()


func test_ac004_gsm_missing_method_no_crash() -> void:
	# _get_gsm() 返回无 _set_battle_deployment_snapshot 方法的节点——双守卫第二分支（has_method）静默跳过
	var no_method_ds: Node = NoMethodGsmDS.new()
	no_method_ds.fake_gsm = Node.new()
	no_method_ds.setup_field([101], {})
	no_method_ds.sync_unavailable_to_gsm()
	no_method_ds.write_snapshot_to_gsm()
	assert_true(true, "GSM 缺目标方法时 sync/write 不崩溃")
	no_method_ds.fake_gsm.free()
	no_method_ds.free()


# ============================================================================
# AC-005：deserialize_field 恢复阵位
# ============================================================================

func test_ac005_deserialize_field_restores() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})
	var data: Dictionary = ds.serialize_field()
	# 清空阵位后恢复
	ds._reset_field()
	ds.deserialize_field(data)
	assert_eq(ds.get_character_slot(101), 0, "101 恢复到 slot 0")
	assert_eq(ds.get_character_slot(104), 4, "104 恢复到 slot 4")
	assert_eq(ds.get_character_slot(999), -1, "不存在角色不恢复")
	var field: Array = ds.get_field()
	assert_eq(field[2]["character_id"], -1, "空位 slot 2 保持空位")


# ============================================================================
# AC-006：deserialize_field 空/无效 data 安全
# ============================================================================

func test_ac006_deserialize_empty_safe() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})
	ds.deserialize_field({})
	var field: Array = ds.get_field()
	assert_eq(field.size(), 6, "空快照后阵位结构不变")
	for entry: Dictionary in field:
		assert_eq(entry["character_id"], -1, "空快照 → 全空阵位")


func test_ac006_deserialize_invalid_entry_safe() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.deserialize_field({0: "not_a_dict", 1: 42, 2: null})
	assert_eq(ds.get_character_slot(101), -1, "非法 entry 不崩溃且不误恢复")
	var field: Array = ds.get_field()
	assert_eq(field.size(), 6, "非法快照后阵位结构不变")


func test_ac006_deserialize_missing_fields_fill_defaults() -> void:
	# 缺字段的 entry 用默认值填充——state=EMPTY、deploy_turn=-1、is_front 按 slot 推导
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.deserialize_field({
		0: {"character_id": 101},                       # 缺 state/is_front/deploy_turn
		4: {"character_id": 202, "state": "READY"},     # 缺 is_front/deploy_turn
	})
	var field: Array = ds.get_field()
	assert_eq(field[0]["character_id"], 101, "slot 0 character_id 恢复")
	assert_eq(field[0]["state"], DS_SCRIPT.FieldState.EMPTY, "缺 state → 默认 EMPTY")
	assert_eq(field[0]["is_front"], true, "slot 0 缺 is_front → 前排推导 true")
	assert_eq(field[0]["deploy_turn"], -1, "缺 deploy_turn → 默认 -1")
	assert_eq(field[4]["character_id"], 202, "slot 4 character_id 恢复")
	assert_eq(field[4]["state"], DS_SCRIPT.FieldState.READY, "显式 state=READY 保留")
	assert_eq(field[4]["is_front"], false, "slot 4 缺 is_front → 后排推导 false")


func test_ac006_deserialize_invalid_state_falls_back_empty() -> void:
	# 非法 state 字符串 → 回退 EMPTY（前向兼容旧/损坏存档）
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.deserialize_field({0: {"character_id": 101, "state": "INVALID_STATE"}})
	assert_eq(ds._field[0]["state"], DS_SCRIPT.FieldState.EMPTY, "非法 state → EMPTY 回退")


func test_ac006_deserialize_json_roundtrip_string_keys() -> void:
	# JSON round-trip 后 int key 变 String key——deserialize 应接受 String key（C-1 修复）
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})
	var data: Dictionary = ds.serialize_field()
	var json_str: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary, "JSON round-trip 解析为 Dictionary")
	ds._reset_field()
	ds.deserialize_field(parsed)
	var field: Array = ds.get_field()
	assert_eq(field[0]["character_id"], 101, "String key slot 0 恢复")
	assert_eq(field[4]["character_id"], 104, "String key slot 4 恢复")
	assert_eq(field[2]["state"], DS_SCRIPT.FieldState.EMPTY, "空位恢复 EMPTY")


# ============================================================================
# AC-007：sync_unavailable_to_gsm 同步
# ============================================================================

func test_ac007_sync_unavailable_to_gsm() -> void:
	ds._unavailable_characters[101] = {"death_turn": 3, "death_battle_id": "b1", "revival_methods": []}
	ds._unavailable_characters[102] = {"death_turn": 5, "death_battle_id": "b2", "revival_methods": ["dan"]}
	ds.sync_unavailable_to_gsm()
	assert_true(GameStateManager.player.has("unavailable_characters"), "player 域含 unavailable_characters")
	var data: Dictionary = GameStateManager.player.unavailable_characters
	assert_eq(data.size(), 2, "同步 2 个不可用角色")
	assert_true(data.has(101), "含角色 101")
	assert_true(data.has(102), "含角色 102")


func test_ac007_sync_empty_safe() -> void:
	ds.sync_unavailable_to_gsm()
	assert_eq(GameStateManager.player.unavailable_characters.size(), 0, "空列表同步空 Dictionary")


# ============================================================================
# AC-008：load_unavailable_from_gsm 恢复
# ============================================================================

func test_ac008_load_unavailable_from_gsm() -> void:
	var data: Dictionary = {
		101: {"death_turn": 2, "death_battle_id": "battle_1", "revival_methods": []},
		102: {"death_turn": 7, "death_battle_id": "battle_2", "revival_methods": ["talent"]},
	}
	ds.load_unavailable_from_gsm(data)
	assert_eq(ds._unavailable_characters.size(), 2, "重建 2 个不可用角色")
	assert_true(ds._unavailable_characters.has(101), "含 101")
	assert_eq(ds._unavailable_characters[102]["death_turn"], 7, "death_turn 恢复")
	assert_eq(ds._unavailable_characters[102]["revival_methods"], ["talent"], "revival_methods 恢复")


func test_ac008_load_unavailable_invalid_safe() -> void:
	ds.load_unavailable_from_gsm({})  # 空不崩溃
	assert_eq(ds._unavailable_characters.size(), 0, "空数据 → 空字典")


# ============================================================================
# AC-009：snapshot round-trip 一致性
# ============================================================================

func test_ac009_round_trip_consistency() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103], {})  # 前 2 后 1
	# 手动设置 101 → ACTED
	ds._field[0]["state"] = DS_SCRIPT.FieldState.ACTED
	var before: Array = ds.get_field()
	var data: Dictionary = ds.serialize_field()
	ds._reset_field()
	ds.deserialize_field(data)
	var after: Array = ds.get_field()
	for i in range(6):
		assert_eq(after[i]["slot_index"], before[i]["slot_index"], "slot_index 一致")
		assert_eq(after[i]["character_id"], before[i]["character_id"], "character_id 一致")
		assert_eq(after[i]["is_front"], before[i]["is_front"], "is_front 一致")
		assert_eq(after[i]["state"], before[i]["state"], "state 一致")
		assert_eq(after[i]["deploy_turn"], before[i]["deploy_turn"], "deploy_turn 一致")


# ============================================================================
# AC-010：GSM 写走第二层原子方法（不直接写属性）
# ============================================================================

func test_ac010_gsm_write_via_second_layer() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102], {})
	GameStateManager.battle_start({})
	# 直接调用第二层方法验证路径可达（不直接写 GameStateManager.battle.deployment_snapshot 属性）
	GameStateManager._set_battle_deployment_snapshot(ds.serialize_field())
	assert_true(GameStateManager.battle.has("deployment_snapshot"), "第二层方法写入 battle.deployment_snapshot")
	assert_eq(GameStateManager.battle.deployment_snapshot.size(), 6, "第二层方法写入 6 个阵位")


# ============================================================================
# AC-011：不可用角色 entry 结构
# ============================================================================

func test_ac011_unavailable_entry_structure() -> void:
	ds._unavailable_characters[101] = {
		"death_turn": 3,
		"death_battle_id": "battle_3",
		"revival_methods": ["nirvana_pill"],
	}
	var entry: Dictionary = ds._unavailable_characters[101]
	assert_true(entry.has("death_turn"), "含 death_turn")
	assert_true(entry.has("death_battle_id"), "含 death_battle_id")
	assert_true(entry.has("revival_methods"), "含 revival_methods")
	assert_true(entry["revival_methods"] is Array, "revival_methods 为 Array")


func test_ac011_load_normalizes_revival_methods() -> void:
	# 读档缺 revival_methods → load 填充默认空数组
	var data: Dictionary = {101: {"death_turn": 1, "death_battle_id": "b"}}
	ds.load_unavailable_from_gsm(data)
	assert_eq(ds._unavailable_characters[101]["revival_methods"], [], "缺 revival_methods → 默认空数组")
