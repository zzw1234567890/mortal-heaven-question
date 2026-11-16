extends "res://tests/integration/save_load/save_round_trip_fixture.gd"
## 存档往返验收：近期新增的探索 / 战斗持久状态「存 → 读 → 状态等价」。[br]
## [br][b]本文件补的断链[/b]：这些状态在内存里都写得进、UI 也读得到，但整份存档
## 此前[b]根本存不下去[/b]——[code]GSM.serialize()[/code] 的载荷含 StringName 与
## int 字典键，被 [code]SaveLoadSystem._is_json_compatible[/code] 判为非法，
## [code]save_game[/code] 恒返回 [code]VALIDATION_ERROR[/code]。即使强行落盘，JSON
## 的「数字皆 float / 键皆 String」也会让读回来的 [code]has(int)[/code] 判定失效
## （已访问节点可重复进、已采槽位查不到、灵泉限次查不到）。[br]
## [br][b]覆盖清单[/b]（逐项对应任务书第 1 条的审计表）：[br]
##   1. 本图通关标记 [code]is_first_clear[/code] / [code]clear_count[/code]；[br]
##   2. 已访问节点 [code]visited_nodes[/code]（[code]has(int)[/code] 仍成立）；[br]
##   3. 采集已采 [code]harvested[/code]（int 键 + int 槽位，不可重复采）；[br]
##   4. 灵泉限次 [code]action_spring_uses[/code]（读档不重置）；[br]
##   5. 事件已弹 [code]events_shown[/code]；[br]
##   6. 自动地图解锁依赖的通关记录（[code]map_states[/code] 整体）；[br]
##   7. 阵亡标记 [code]player.unavailable_characters[/code]（int 键 + 落地到 DeploymentSystem）；[br]
##   8. 残血 [code]player.character_hp[/code]；[br]
##   9. 收藏与卡组（[code]owned_cards[/code] / [code]deck.slots[/code]）；[br]
##   10. 剧情标记 [code]narrative.story_flags[/code]（自动解锁的另一半条件）。[br]
## [br]来源: ADR-0002 §JSON + 迁移链、ADR-0014 §决策 1 状态分层模型、
## ADR-0016 §不可用角色生命周期、本轮任务书第 1/3 条。

# ═══════════════════════════════════════════════════════════════════════════════
# 1. 存 → 读 → 状态等价（本文件的主用例）
# ═══════════════════════════════════════════════════════════════════════════════

func test_exploration_progress_survives_save_and_load() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS, "刚存的档必须读得回来")
	# Assert——已通关的图仍显示已通，通关次数不归零
	var state: Dictionary = state_of_a()
	assert_true(bool(state.get("is_first_clear", false)), "读档后已通关的图仍为已通")
	assert_eq(int(state.get("clear_count", 0)), 3, "通关次数不归零")
	assert_eq(int(state.get("entry_count", 0)), 4, "进入次数保持")
	assert_eq(ClearScript.new().clear_count_of(MAP_A, gsm), 3, "通关记录的读侧入口同样成立")
	# 另一张图不串场——通关记录按地图 ID 分记
	assert_false(bool(gsm.exploration.map_states.get(MAP_B, {}).get("is_first_clear", true)),
			"未通关的图读档后仍为未通关（自动解锁的前置判定依据）")


func test_visited_nodes_stay_int_after_json_round_trip() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——元素必须是 int，否则 Array.has(int) 恒 false（可重复进同一节点）
	var visited: Array = gsm.exploration.visited_nodes
	assert_eq(visited, [0, 101, 203], "已访问集合逐元素等价")
	assert_eq(typeof(visited[1]), TYPE_INT, "元素类型还原为 int（JSON 会回来成 float）")
	assert_true(visited.has(101), "has(int) 判定成立——已访问节点不会被再算一次")


func test_harvested_slots_block_reharvest_after_load() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——int 键必须还原：JSON 会把 203 变成 "203"，查不到就等于已采记录丢光
	var state: Dictionary = state_of_a()
	assert_true(state.has("harvested"), "已采记录仍在")
	var harvested: Dictionary = state.get("harvested", {})
	assert_true(harvested.has(203), "节点键还原为 int")
	assert_false(harvested.has("203"), "不得同时留下 String 键（会被读侧判成另一个节点）")
	assert_eq(HarvestScript.harvested_slots(state, 203), [0, 2], "已采槽位逐元素等价")
	assert_true(HarvestScript.is_harvested(state, 203, 0), "已采节点读档后仍判为已采（不可重复采）")
	assert_false(HarvestScript.is_harvested(state, 203, 1), "未采槽位不受牵连")


func test_action_spring_uses_not_reset_by_load() -> void:
	# Arrange——本图灵泉限 2 次，已用掉 2 次
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——限次读回来仍是 2，且类型是 int（状态等价可直比）
	var state: Dictionary = state_of_a()
	assert_eq(SpringScript.uses_of(state), 2, "灵泉已用次数不重置")
	assert_eq(typeof(state.get(SpringScript.KEY_SPRING_USES)), TYPE_INT, "次数还原为 int")
	assert_true(SpringScript.is_exhausted(state, {SpringScript.KEY_SPRING_COUNT: 2}),
			"读档后本图限次已用尽——不会白送一次回复")


func test_event_shown_nodes_stay_recorded_after_load() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——v2 新增字段：不还原的话重进地图会再弹一次同样的奖励
	var state: Dictionary = state_of_a()
	assert_eq(ShownScript.shown_of(state), [101, 203], "已弹节点列表逐元素等价")
	assert_eq(typeof(ShownScript.shown_of(state)[0]), TYPE_INT, "元素还原为 int")
	assert_true(ShownScript.is_shown(state, 101), "已弹节点读档后仍判为已弹")
	assert_false(ShownScript.is_shown(state, 102), "未弹节点不受牵连")
	assert_true(ShownScript.is_shown_in_gsm(gsm, 203), "按当前地图一步判定的入口同样成立")


func test_cleared_map_records_nested_keys_survive() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——图结构与节点详情都按 int 键索引（邻接判定 / 节点详情查不到即判死）
	var state: Dictionary = state_of_a()
	var graph: Dictionary = state.get("graph", {})
	assert_true(graph.has(101), "邻接表键还原为 int")
	assert_eq(graph.get(101), [203], "邻接表元素还原为 int")
	var nodes: Dictionary = state.get("nodes", {})
	assert_true(nodes.has(101), "节点详情键还原为 int")
	assert_eq(str((nodes.get(101, {}) as Dictionary).get("type", "")), "battle", "节点详情内容保持")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 阵亡 / 残血 / 收藏卡组 / 剧情标记
# ═══════════════════════════════════════════════════════════════════════════════

func test_dead_characters_stay_dead_after_load() -> void:
	# Arrange
	seed_progress()
	assert_eq(save_slot(), SLS.SaveResult.SUCCESS)
	wipe_memory()
	# Act——本地阵亡表也清空：读档必须把它从存档里接回来
	DeploymentSystem._unavailable_characters.clear()
	assert_eq(load_slot(), SLS.LoadResult.SUCCESS)
	# Assert——GSM 侧
	var unavailable: Dictionary = gsm.player.unavailable_characters
	assert_true(unavailable.has(CHAR_DEAD), "阵亡名单键还原为 int")
	assert_eq(typeof(unavailable.keys()[0]), TYPE_INT, "键类型必须是 int（备战按角色 ID 判）")
	assert_eq(int((unavailable.get(CHAR_DEAD, {}) as Dictionary).get("death_turn", -1)), 3,
			"死亡上下文随档保留")
	# Assert——落地到 DeploymentSystem：不拉回来的话存档里的死人会重新上场
	var ids: Array = DeploymentSystem.get_unavailable_characters()
	assert_true(ids.has(CHAR_DEAD), "读档后 DeploymentSystem 仍视其为阵亡")
	assert_false(ids.has(CHAR_HURT), "残血未阵亡的角色不进阵亡表")


func test_wounded_hp_survives_save_and_load() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——残血跨场持久（「带伤进下一场」）
	var table: Dictionary = gsm.player.character_hp
	assert_eq(int((table.get(str(CHAR_HURT), {}) as Dictionary).get("current_hp", -1)), 5,
			"残血不归满")
	assert_eq(int((table.get(str(CHAR_HURT), {}) as Dictionary).get("max_hp", -1)), 9, "上限保持")
	assert_eq(int((table.get(str(CHAR_DEAD), {}) as Dictionary).get("current_hp", -1)), 0,
			"阵亡角色的 0 血照实保留（不夹到 1 冒充存活）")


func test_collection_and_deck_survive_save_and_load() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——收藏（逐字段：StringName↔String 的往返由读侧各自转换，不做整字典直比）
	var cards: Array = gsm.collection.owned_cards
	assert_eq(cards.size(), 2, "收藏条目数保持")
	assert_eq(int((cards[0] as Dictionary).get("card_instance_id", -1)), 11, "实例 ID 保持")
	assert_eq(str((cards[1] as Dictionary).get("template_id", "")), "card_water_002", "模板 ID 保持")
	assert_eq(int((cards[1] as Dictionary).get("level", -1)), 2, "等级保持 int")
	assert_eq(int(gsm.collection.total_count), 2, "总数保持")
	# Assert——卡组：当前卡组与阵位槽（槽位混有非数字占位串，不能被压成 0）
	assert_eq(gsm.deck.current_deck, [11, 12], "当前卡组逐元素等价")
	assert_eq(gsm.deck.slots[0], 11, "角色实例 ID 槽位还原为 int")
	assert_eq(gsm.deck.slots[1], "char_1", "非数字占位串原样保留（不得压成 0 号角色）")
	assert_eq(gsm.deck.slots[2], null, "空位保持 null")


func test_story_flags_survive_save_and_load() -> void:
	# Arrange
	seed_progress()
	# Act
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Assert——StringName 键落成 String 键，StringName 查得到（String/StringName 双向等价）
	var flags: Variant = gsm.get_state("narrative.story_flags")
	assert_true(flags is Dictionary, "剧情标记仍在")
	assert_true(bool((flags as Dictionary).get(&"met_master", false)), "已置位的标记读档后仍为真")
	assert_false((flags as Dictionary).has(&"never_set"), "没置过的标记不凭空长出来")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 二次存档：读进来再存一次，载荷仍可写、内容不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_reload_then_resave_keeps_payload_valid() -> void:
	## 读档后的内存必须仍是「可存档形态」——若读侧还原成了 JSON 装不下的类型，
	## 玩家读一次档就会从此存不了档。
	# Arrange
	seed_progress()
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS)
	# Act——不重新播种，直接再走一遍存-清-读
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS, "读档后立刻再存仍必须成功")
	# Assert——关键状态在二次往返后依旧等价
	var state: Dictionary = state_of_a()
	assert_eq(int(state.get("clear_count", 0)), 3, "二次往返后通关次数不变")
	assert_eq(HarvestScript.harvested_slots(state, 203), [0, 2], "二次往返后已采槽位不变")
	assert_eq(ShownScript.shown_of(state), [101, 203], "二次往返后已弹事件不变")
	assert_eq(SpringScript.uses_of(state), 2, "二次往返后灵泉次数不变")
