extends GutTest
## 采集点结算 —— 材料入库、重复采集拒绝、背包上限夹紧。[br]
## [br][b]覆盖[/b]：[br]
##   · 可采列表来自节点载荷（生成期写入的 [code]materials[/code]），含
##     背包剩余容量与已采标记；[br]
##   · 采集后材料[b]真的进背包[/b]（经 [code]ResourceSystem.add_resource[/code]
##     → GSM [code]_set_resource_ling_cai[/code]，与既有背包同一本账）；[br]
##   · 同节点同槽位重复采集返回失败 + 中文提示，且不再改背包；[br]
##   · 槽位越界 / 空载荷 / 背包已满的拒绝路径都不改任何状态；[br]
##   · 已采状态记在 [code]map_states[map_id][/code]——持久化形态可直接断言。[br]
## [br][b]装置[/b]：真实 GSM + 真实 ResourceSystem（Autoload），用例前后快照还原
## [code]player[/code] 与探索域（同 [code]test_shop_and_rest_node_flow[/code] 口径）。
##
## 来源: design/gdd/resource-system.md §资源表（灵材）/ §边界（AC-19）、
## design/gdd/exploration-system.md §节点类型一览、ADR-0019 §关键接口。

const HarvestScript := preload("res://src/feature/exploration/exploration_harvest.gd")
const TableScript := preload("res://src/feature/exploration/exploration_harvest_table.gd")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

## 采集点节点 ID（layer 2, idx 3——任意非入口值即可）。
const HARVEST_NODE: int = 203
## 用例地图 ID（与 GSM 当前地图一致，已采状态才写得进去）。
const MAP_ID: StringName = &"qing_yun_jian_zong"

var es: Node = null
var harvest: RefCounted = null
var _player_before: Dictionary = {}
var _exploration_before: Dictionary = {}


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	es = ES_SCRIPT.new()
	es.set("_dag_ready", true)
	es.set("_node_details", {HARVEST_NODE: {
		"type": 10,  # NodeType.HARVEST
		"layer": 2,
		"idx": 3,
		"label": "采集点",
		"materials": TableScript.payload_for(MAP_ID, 1),
	}})
	harvest = HarvestScript.new(es)
	GameStateManager.player.resources.ling_cai = {
		"low": 0, "medium": 0, "high": 0, "top": 0}
	GameStateManager.exploration.current_map = MAP_ID
	GameStateManager.exploration.map_states = {}


func after_each() -> void:
	GameStateManager.player = _player_before
	GameStateManager.exploration = _exploration_before
	if es != null:
		es.free()
		es = null
	harvest = null


# ═══════════════════════════════════════════════════════════════════════════════
# 可采列表（载荷 → 面板的唯一数据源）
# ═══════════════════════════════════════════════════════════════════════════════

func test_entries_read_from_node_payload_with_room_and_flags() -> void:
	# Act
	var entries: Array = harvest.call(&"entries_at", HARVEST_NODE)
	# Assert——载荷两条（灵草 + 矿脉），字段齐备且初始未采
	assert_eq(entries.size(), TableScript.payload_for(MAP_ID, 1).size(),
			"可采条数应与节点载荷一致")
	var first: Dictionary = entries[0]
	assert_eq(str(first.get("kind_name")), "灵草", "首条应为灵草（载荷顺序）")
	assert_false(bool(first.get("harvested")), "尚未采集")
	assert_eq(int(first.get("room")), HarvestScript.LING_CAI_CAP,
			"空背包时剩余容量为上限")
	assert_eq(str(first.get("quality_name")), "下品", "炼气期载荷为下品材料")


func test_entries_empty_when_node_has_no_materials() -> void:
	var entries: Array = harvest.call(&"entries_at", 999)
	assert_eq(entries.size(), 0, "无载荷节点不臆造可采条目")


# ═══════════════════════════════════════════════════════════════════════════════
# 采集入库（真的写进背包）
# ═══════════════════════════════════════════════════════════════════════════════

func test_harvest_writes_material_into_bag() -> void:
	# Arrange
	var entries: Array = harvest.call(&"entries_at", HARVEST_NODE)
	var slot: int = int(entries[0]["slot"])
	var amount: int = int(entries[0]["amount"])
	var before: int = ResourceSystem.get_resource(&"ling_cai", 1)
	# Act
	var result: Dictionary = harvest.call(&"harvest_at_node", HARVEST_NODE, slot)
	# Assert——背包真的多了这么多，且是走 ResourceSystem 的路径
	assert_true(bool(result["success"]), "首次采集应成功")
	assert_eq(int(result["gained"]), amount, "入库量应等于载荷数量")
	assert_eq(ResourceSystem.get_resource(&"ling_cai", 1), before + amount,
			"材料应真的写进背包（ling_cai 下品）")
	assert_true(str(result["message"]).begins_with("采集：获得"),
			"提示应为中文采集成功文案")


func test_harvest_second_time_fails_and_keeps_bag_unchanged() -> void:
	# Arrange——先采一次
	var entries: Array = harvest.call(&"entries_at", HARVEST_NODE)
	var slot: int = int(entries[0]["slot"])
	harvest.call(&"harvest_at_node", HARVEST_NODE, slot)
	var after_first: int = ResourceSystem.get_resource(&"ling_cai", 1)
	# Act——同槽位再采
	var second: Dictionary = harvest.call(&"harvest_at_node", HARVEST_NODE, slot)
	# Assert
	assert_false(bool(second["success"]), "同节点同槽位只能采一次")
	assert_eq(str(second["reason"]), "already", "拒绝原因应为 already")
	assert_eq(str(second["message"]), HarvestScript.TEXT_ALREADY,
			"提示应为「此处已采集过」")
	assert_eq(ResourceSystem.get_resource(&"ling_cai", 1), after_first,
			"重复采集不得再改背包")


func test_harvest_second_slot_still_available_after_first() -> void:
	var entries: Array = harvest.call(&"entries_at", HARVEST_NODE)
	harvest.call(&"harvest_at_node", HARVEST_NODE, int(entries[0]["slot"]))
	# Act——另一个槽位（矿脉）仍可采
	var second: Dictionary = harvest.call(&"harvest_at_node", HARVEST_NODE,
			int(entries[1]["slot"]))
	assert_true(bool(second["success"]), "同节点的其它材料不受影响")


func test_harvest_rejects_out_of_range_slot() -> void:
	var bag_before: int = ResourceSystem.get_resource(&"ling_cai")
	var result: Dictionary = harvest.call(&"harvest_at_node", HARVEST_NODE, 99)
	assert_false(bool(result["success"]), "越界槽位应被拒")
	assert_eq(str(result["reason"]), "no_slot", "拒绝原因应为 no_slot")
	assert_eq(ResourceSystem.get_resource(&"ling_cai"), bag_before,
			"拒绝路径不得改背包")


# ═══════════════════════════════════════════════════════════════════════════════
# 背包上限夹紧
# ═══════════════════════════════════════════════════════════════════════════════

func test_room_for_clamps_to_remaining_capacity() -> void:
	assert_eq(HarvestScript.room_for(0, 5), 5, "空背包全额入库")
	assert_eq(HarvestScript.room_for(97, 5), 2, "只剩 2 格时只入 2")
	assert_eq(HarvestScript.room_for(99, 5), 0, "已满时不再入库")
	assert_eq(HarvestScript.room_for(200, 5), 0, "越界存档值按已满处理")
	assert_eq(HarvestScript.room_for(0, -3), 0, "负数量归零")


func test_harvest_partially_fills_bag_at_capacity_edge() -> void:
	# Arrange——下品已有 97，槽位载荷 2 条中的灵草数量可能是 1 或 2
	var entries: Array = harvest.call(&"entries_at", HARVEST_NODE)
	var slot: int = int(entries[0]["slot"])
	var wanted: int = int(entries[0]["amount"])
	GameStateManager.player.resources.ling_cai.low = \
			HarvestScript.LING_CAI_CAP - 1
	# Act
	var result: Dictionary = harvest.call(&"harvest_at_node", HARVEST_NODE, slot)
	# Assert——只入 1（余量），且提示里的数量是真实到手量
	assert_true(bool(result["success"]), "还有余量时采集应成功")
	assert_eq(int(result["gained"]), 1, "只入背包剩余容量")
	assert_eq(ResourceSystem.get_resource(&"ling_cai", 1), HarvestScript.LING_CAI_CAP,
			"入库后恰好到上限，不越界")
	assert_true(wanted >= 1, "载荷数量应 ≥1（否则本用例无意义）")


func test_harvest_full_bag_is_rejected_without_state_change() -> void:
	# Arrange——下品已满
	GameStateManager.player.resources.ling_cai.low = HarvestScript.LING_CAI_CAP
	var entries: Array = harvest.call(&"entries_at", HARVEST_NODE)
	var slot: int = int(entries[0]["slot"])
	# Act
	var result: Dictionary = harvest.call(&"harvest_at_node", HARVEST_NODE, slot)
	# Assert——拒绝且不标记已采（背包腾空后还能再来采）
	assert_false(bool(result["success"]), "背包已满时不得入库")
	assert_eq(str(result["reason"]), "bag_full", "拒绝原因应为 bag_full")
	assert_eq(str(result["message"]), HarvestScript.TEXT_FULL, "提示应为「背包已满」")
	var entries_after: Array = harvest.call(&"entries_at", HARVEST_NODE)
	assert_false(bool(entries_after[0]["harvested"]),
			"被拒的采集不得记为已采（满包不应白扣一次机会）")


# ═══════════════════════════════════════════════════════════════════════════════
# 已采状态持久化
# ═══════════════════════════════════════════════════════════════════════════════

func test_harvested_slot_persists_into_map_state() -> void:
	var entries: Array = harvest.call(&"entries_at", HARVEST_NODE)
	var slot: int = int(entries[0]["slot"])
	harvest.call(&"harvest_at_node", HARVEST_NODE, slot)
	# Assert——写进 map_states[map_id]["harvested"]，随探索域持久化
	var state: Dictionary = GameStateManager.exploration.map_states.get(MAP_ID, {})
	var saved: Dictionary = state.get(HarvestScript.KEY_HARVESTED, {})
	assert_true(saved.has(HARVEST_NODE), "已采记录应写进 map_states")
	assert_true((saved[HARVEST_NODE] as Array).has(slot), "记录的是被采的槽位")
	assert_true(HarvestScript.is_harvested(
			GameStateManager.exploration.map_states[MAP_ID], HARVEST_NODE, slot),
			"读回时该槽位应判定为已采")


func test_is_harvested_is_false_for_unrecorded_node() -> void:
	assert_false(HarvestScript.is_harvested({}, 0, 0), "空状态不得误判为已采")
	assert_eq(HarvestScript.harvested_slots({}, 0).size(), 0, "无记录时槽位表为空")


func test_payload_is_deterministic_for_same_map_and_realm() -> void:
	# 确定性——同图同境界恒同批（存档里的「已采 slot」才有意义）
	var a: Array = TableScript.payload_for(&"qing_yun_jian_zong", 1)
	var b: Array = TableScript.payload_for(&"qing_yun_jian_zong", 1)
	assert_eq(a, b, "同地图同境界的载荷应完全一致")
	assert_eq(a.size(), 2, "每档载荷含灵草与矿脉各一")
