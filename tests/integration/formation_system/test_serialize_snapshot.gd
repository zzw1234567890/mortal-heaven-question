extends GutTest
## Story 004 验收测试：serialize_all 快照导出 + deserialize_all 恢复 + GSM battle.formation_snapshot + clear_all_formations。
##
## 覆盖 AC-001 到 AC-005（5 条 AC）。
## 测试策略：
##   - FS_SCRIPT.new() + var fs: Node 持有
##   - before_each: 重置 + 注入 condition_check_cb + GSM battle_start 包裹
##   - after_each: GSM battle_end 清理 + free
##   - mock: condition_check_cb 控制条件满足/不满足 + character_exists_cb 控制验证通过/失败
##
## 设计文档来源：ADR-0024 §GSM 边界 §serialize_all §deserialize_all §验证标准
## Story 来源：production/epics/formation-system/story-004-serialize-snapshot.md

const FS_SCRIPT := preload("res://src/feature/formation_system.gd")

const REQ_3_ZHENGDAO: Dictionary = {"tag_id": &"zhengdao", "min_count": 3}
const FIXED_EFFECT: Dictionary = {"hp": 2.0, "def": 1.0}

var fs: Node = null
var _condition_result: bool = true
var _count_result: int = 0
var _character_exists: Dictionary = {}


func before_each() -> void:
	fs = FS_SCRIPT.new()
	_condition_result = true
	_count_result = 0
	_character_exists.clear()
	fs.set("condition_check_cb", Callable(self, "_on_check_condition"))
	fs.set("count_on_field_cb", Callable(self, "_on_count_on_field"))
	fs.set("character_exists_cb", Callable(self, "_on_character_exists"))
	GameStateManager.battle_start({})


func after_each() -> void:
	if fs != null:
		fs.free()
		fs = null
	GameStateManager.battle_end({})
	_character_exists.clear()


func _on_check_condition(_requirement: Dictionary) -> bool:
	return _condition_result


func _on_count_on_field(_tag_id: StringName) -> int:
	return _count_result


func _on_character_exists(character_id: int) -> bool:
	if _character_exists.is_empty():
		return true
	return _character_exists.has(character_id)


func _set_condition(result: bool) -> void:
	_condition_result = result


func _deploy_test_formations() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"cangxuan_zhengdao", 0, REQ_3_ZHENGDAO,
		FS_SCRIPT.AuraScope.AFFILIATED_CHARACTERS, FIXED_EFFECT, 0, 0.0)
	fs.call("set_character_affilation", 200, 1)
	fs.call("set_character_affilation", 201, 1)
	_set_condition(false)
	fs.call("deploy_formation", 101, &"xuanbing_huichun", 1, REQ_3_ZHENGDAO,
		FS_SCRIPT.AuraScope.SAME_FACTION, {}, 5, 1.0)


# ============================================================================
# AC-001：serialize_all 返回完整快照
# ============================================================================

func test_serialize_all_complete_snapshot() -> void:
	_deploy_test_formations()
	var data: Dictionary = fs.call("serialize_all")
	assert_true(data.has("slots"), "快照含 slots 键")
	assert_true(data.has("affiliations"), "快照含 affiliations 键")
	assert_true(data.has("next_formation_id"), "快照含 next_formation_id 键")
	var slots: Array = data["slots"]
	assert_eq(slots.size(), 3, "3 个阵法位")
	# slot 0——固定阵法，完整字段验证（qa-lead GAP-006）
	var slot0: Dictionary = slots[0]
	assert_eq(slot0["formation_id"], 1, "slot 0 formation_id=1")
	assert_eq(slot0["card_instance_id"], 100, "slot 0 card_instance_id")
	assert_eq(str(slot0["template_id"]), "cangxuan_zhengdao", "slot 0 template_id")
	assert_eq(slot0["state"], FS_SCRIPT.SlotState.ACTIVE, "slot 0 ACTIVE")
	assert_eq(slot0["deployed_turn"], 0, "slot 0 deployed_turn")
	assert_eq(slot0["aura_scope"], FS_SCRIPT.AuraScope.AFFILIATED_CHARACTERS, "slot 0 aura_scope")
	assert_eq(slot0["max_level"], 0, "slot 0 max_level=0（固定阵法）")
	assert_eq(slot0["base_value"], 0.0, "slot 0 base_value（固定阵法）")
	var req0: Dictionary = slot0["requirement"]
	assert_eq(str(req0["tag_id"]), "zhengdao", "slot 0 requirement.tag_id")
	assert_eq(int(req0["min_count"]), 3, "slot 0 requirement.min_count")
	var ec0: Dictionary = slot0["effect_config"]
	assert_eq(float(ec0["hp"]), 2.0, "slot 0 effect_config.hp")
	assert_eq(float(ec0["def"]), 1.0, "slot 0 effect_config.def")
	assert_eq((slot0["affiliated_chars"] as Array).size(), 2, "slot 0 affiliated_chars 2 角色")
	# slot 1——梯度阵法
	var slot1: Dictionary = slots[1]
	assert_eq(slot1["formation_id"], 2, "slot 1 formation_id=2")
	assert_eq(str(slot1["template_id"]), "xuanbing_huichun", "slot 1 template_id")
	assert_eq(slot1["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "slot 1 UNACTIVE")
	assert_eq(slot1["max_level"], 5, "slot 1 max_level=5（梯度阵法）")
	assert_eq(slot1["base_value"], 1.0, "slot 1 base_value（梯度阵法）")
	assert_eq(slot1["aura_scope"], FS_SCRIPT.AuraScope.SAME_FACTION, "slot 1 aura_scope")
	# slot 2——空阵位
	var slot2: Dictionary = slots[2]
	assert_eq(slot2["state"], FS_SCRIPT.SlotState.EMPTY, "slot 2 EMPTY")
	var aff: Dictionary = data["affiliations"]
	assert_eq(aff.size(), 2, "2 条归属关系")
	assert_eq(int(aff[200]), 1, "角色 200 归属 formation 1")
	assert_eq(int(aff[201]), 1, "角色 201 归属 formation 1")
	assert_eq(int(data["next_formation_id"]), 3, "next_formation_id=3")


func test_serialize_all_empty_formations() -> void:
	var data: Dictionary = fs.call("serialize_all")
	var slots: Array = data["slots"]
	assert_eq(slots.size(), 3, "空阵法区仍 3 个阵位")
	for slot in slots:
		assert_eq(slot["state"], FS_SCRIPT.SlotState.EMPTY, "全 EMPTY")
	assert_eq((data["affiliations"] as Dictionary).size(), 0, "无归属")
	assert_eq(int(data["next_formation_id"]), 1, "next_formation_id=1")


# ============================================================================
# AC-002：快照写入 GSM.battle.formation_snapshot
# ============================================================================

func test_write_snapshot_to_gsm_success() -> void:
	_deploy_test_formations()
	fs.call("write_snapshot_to_gsm")
	assert_not_null(GameStateManager.battle, "battle 应活跃")
	assert_true(GameStateManager.battle.has("formation_snapshot"), "battle.formation_snapshot 存在")
	var snapshot: Dictionary = GameStateManager.battle["formation_snapshot"]
	assert_eq((snapshot["slots"] as Array).size(), 3, "GSM 快照含 3 阵位")
	assert_eq((snapshot["affiliations"] as Dictionary).size(), 2, "GSM 快照含 2 归属")


func test_write_snapshot_to_gsm_empty() -> void:
	fs.call("write_snapshot_to_gsm")
	assert_not_null(GameStateManager.battle, "battle 应活跃")
	assert_true(GameStateManager.battle.has("formation_snapshot"), "空快照也应写入 formation_snapshot 键")
	var snapshot: Dictionary = GameStateManager.battle["formation_snapshot"]
	assert_eq((snapshot["slots"] as Array).size(), 3, "空快照 3 阵位")
	assert_eq((snapshot["affiliations"] as Dictionary).size(), 0, "空快照 0 归属")


func test_write_snapshot_to_gsm_dedup() -> void:
	_deploy_test_formations()
	fs.call("write_snapshot_to_gsm")
	fs.call("write_snapshot_to_gsm")
	var snapshot: Dictionary = GameStateManager.battle["formation_snapshot"]
	assert_eq((snapshot["affiliations"] as Dictionary).size(), 2, "去重后快照仍 2 归属")


# ============================================================================
# AC-003：serialize/deserialize 往返完整性
# ============================================================================

func test_serialize_deserialize_roundtrip() -> void:
	_deploy_test_formations()
	var data: Dictionary = fs.call("serialize_all")
	fs.call("clear_all_formations")
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.EMPTY, "清空后 slot 0 EMPTY")
	fs.call("deserialize_all", data)
	var slots: Array = fs.call("get_slot_states")
	assert_eq(slots[0]["state"], FS_SCRIPT.SlotState.ACTIVE, "slot 0 恢复 ACTIVE")
	assert_eq(slots[0]["formation_id"], 1, "slot 0 formation_id 恢复")
	assert_eq(slots[0]["affiliated_count"], 2, "slot 0 affiliated_count 恢复")
	assert_eq(slots[1]["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "slot 1 恢复 UNACTIVE")
	assert_eq(slots[2]["state"], FS_SCRIPT.SlotState.EMPTY, "slot 2 恢复 EMPTY")
	assert_eq(int(fs.call("get_character_affilation", 200)), 1, "角色 200 归属恢复")
	assert_eq(int(fs.call("get_character_affilation", 201)), 1, "角色 201 归属恢复")
	assert_eq(int(fs.call("serialize_all")["next_formation_id"]), 3, "next_formation_id 恢复")


# ============================================================================
# AC-004：deserialize 归属悬空跳过
# ============================================================================

func test_deserialize_skips_missing_character() -> void:
	_deploy_test_formations()
	var data: Dictionary = fs.call("serialize_all")
	fs.call("clear_all_formations")
	_character_exists = {200: true}
	fs.call("deserialize_all", data)
	assert_eq(int(fs.call("get_character_affilation", 200)), 1, "角色 200 恢复")
	assert_eq(int(fs.call("get_character_affilation", 201)), -1, "角色 201 不存在 → 跳过")
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.ACTIVE, "阵法状态正常恢复")
	# lead-programmer C1 / qa-lead GAP-001：悬空角色不计入 affiliated_count
	assert_eq(fs.call("get_slot_states")[0]["affiliated_count"], 1, "悬空角色跳过后 affiliated_count 应为 1")


func test_deserialize_empty_snapshot() -> void:
	fs.call("deserialize_all", {"slots": [], "affiliations": {}, "next_formation_id": 1})
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.EMPTY, "空快照 → 阵位 EMPTY")
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "空快照 → 无归属")
	# qa-lead GAP-007：next_formation_id 默认值验证
	assert_eq(int(fs.call("serialize_all")["next_formation_id"]), 1, "空快照 → next_formation_id 默认 1")


func test_deserialize_missing_keys() -> void:
	fs.call("deserialize_all", {})
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.EMPTY, "缺键 → 默认 EMPTY")
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "缺键 → 无归属")
	# qa-lead GAP-007：next_formation_id 默认值验证
	assert_eq(int(fs.call("serialize_all")["next_formation_id"]), 1, "缺键 → next_formation_id 默认 1")


# ============================================================================
# AC-005：clear_all_formations 清理
# ============================================================================

func test_clear_all_formations_resets_slots() -> void:
	_deploy_test_formations()
	fs.call("clear_all_formations")
	var slots: Array = fs.call("get_slot_states")
	for slot in slots:
		assert_eq(slot["state"], FS_SCRIPT.SlotState.EMPTY, "全 EMPTY")
		assert_eq(int(slot["formation_id"]), -1, "formation_id 重置 -1")


func test_clear_all_formations_clears_affiliations() -> void:
	_deploy_test_formations()
	fs.call("clear_all_formations")
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "归属 200 清除")
	assert_eq(int(fs.call("get_character_affilation", 201)), -1, "归属 201 清除")


func test_clear_all_formations_preserves_next_formation_id() -> void:
	_deploy_test_formations()
	var next_id_before: int = int(fs.call("serialize_all")["next_formation_id"])
	assert_eq(next_id_before, 3, "清理前 next_formation_id=3")
	fs.call("clear_all_formations")
	var next_id_after: int = int(fs.call("serialize_all")["next_formation_id"])
	assert_eq(next_id_after, 3, "清理后 next_formation_id 保留=3（不重置）")


# ============================================================================
# JSON round-trip 安全（StringName→String→StringName）
# ============================================================================

func test_serialize_deserialize_json_roundtrip() -> void:
	_deploy_test_formations()
	var data: Dictionary = fs.call("serialize_all")
	var json_str: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary, "JSON 解析为 Dictionary")
	fs.call("clear_all_formations")
	fs.call("deserialize_all", parsed)
	# qa-lead GAP-002：深度验证 JSON round-trip 全字段
	var slots: Array = fs.call("get_slot_states")
	assert_eq(slots[0]["state"], FS_SCRIPT.SlotState.ACTIVE, "JSON round-trip 后 slot 0 ACTIVE")
	assert_eq(slots[1]["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "JSON round-trip 后 slot 1 UNACTIVE")
	assert_eq(slots[2]["state"], FS_SCRIPT.SlotState.EMPTY, "JSON round-trip 后 slot 2 EMPTY")
	assert_eq(int(slots[0]["formation_id"]), 1, "JSON round-trip 后 formation_id 恢复")
	assert_eq(slots[0]["affiliated_count"], 2, "JSON round-trip 后 affiliated_count 恢复")
	assert_eq(int(fs.call("get_character_affilation", 201)), 1, "JSON round-trip 后角色 201 归属恢复")
	assert_eq(int(fs.call("serialize_all")["next_formation_id"]), 3, "JSON round-trip 后 next_formation_id 恢复")
	var state: Dictionary = fs.call("get_formation_state", 1)
	assert_eq(str(state["template_id"]), "cangxuan_zhengdao", "template_id JSON round-trip 后恢复")
	assert_eq(int(fs.call("get_character_affilation", 200)), 1, "affiliations JSON round-trip 后恢复")
