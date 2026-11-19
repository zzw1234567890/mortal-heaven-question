extends "res://tests/integration/exploration_ui/one_run_battle_fixture.gd"
## 一周目冒烟（存档段）—— 打到一半存盘，读回来接着走。[br]
## [br][b]为什么是这一段[/b]：链路前七步都在同一段内存里跑；玩家真正的处境是
## 「关掉游戏第二天再开」——那是 [code]serialize → JSON → 磁盘 → deserialize[/code]
## 这条路，内存里的对象一个都带不过去。[br]
## [br][b]覆盖[/b]（第 8 步）：中途存档 → 清空内存 → 读档 → 身份 / 境界 /
## [code]visited_nodes[/code] / [code]clear_count[/code] / 收藏 / 灵石逐一相同。[br]
## [br][b]走真实读盘写盘[/b]：真实 [code]SaveLoadSystem[/code]，只把存档根换到
## 测试专用目录（[code]one_run_base_fixture.gd[/code] 的 [class TestSLS]）。[br]
##
## 来源: design/gdd/save-load-system.md §9、design/gdd/exploration-system.md §6、
## ADR-0002（JSON + 迁移链）、ADR-0014 §决策 1 状态分层模型。

const SLS2 := preload("res://src/foundation/save_load_system.gd")


func test_mid_run_save_round_trip_preserves_progress() -> void:
	# Arrange——走完真实开局前三步，并真的往图里走一格（visited 有内容才验得出来）
	start_new_run()
	var map_id: StringName = first_map_id()
	var hop: int = first_non_exempt_hop()
	assert_true(hop > 0, "前置：入口应有可走的后继节点")
	click_node(hop)
	assert_true(visited().has(hop), "前置：这一跳应被受理")
	gsm.set(&"player", (gsm.player as Dictionary).duplicate(true))
	gsm.player["realm"] = int(gsm.player.get("realm", 1))

	# 记下读档后要逐项比对的那份事实
	var expected: Dictionary = _progress_fingerprint(map_id)
	assert_ne(str(expected["identity"]), "", "前置：身份应已落地")
	assert_gt(int(expected["visited"]), 1, "前置：visited 应不止入口（否则这一条验不出东西）")

	# Act——真实写盘 → 抹掉内存 → 真实读盘
	open_save_system()
	assert_eq(save_progress(), SLS2.SaveResult.SUCCESS, "存档应写得进盘")
	wipe_memory()
	# 抹干净了吗——不确认这一条，下面的「读回来后一致」可能只是内存压根没被清
	assert_eq(str(gsm.player.get("identity_id", "")), "", "前置：身份已从内存抹掉")
	assert_eq(visited().size(), 0, "前置：已访问节点已从内存抹掉")
	assert_eq(load_progress(), SLS2.LoadResult.SUCCESS, "存档应读得回来")

	# Assert——逐项与存档前一致
	var actual: Dictionary = _progress_fingerprint(map_id)
	assert_eq(str(actual["identity"]), str(expected["identity"]), "身份应一致")
	assert_eq(int(actual["realm"]), int(expected["realm"]), "境界应一致")
	assert_eq(int(actual["visited"]), int(expected["visited"]), "已访问节点数应一致")
	assert_eq(actual["visited_nodes"], expected["visited_nodes"], "已访问节点集合应一致")
	assert_eq(int(actual["clear_count"]), int(expected["clear_count"]), "通关次数应一致")
	assert_eq(int(actual["collection"]), int(expected["collection"]), "收藏张数应一致")
	assert_eq(int(actual["ling_shi"]), int(expected["ling_shi"]), "灵石应一致")
	assert_eq(str(actual["current_map"]), str(expected["current_map"]), "当前图应一致")


func test_save_round_trip_survives_a_cleared_map() -> void:
	# Arrange——造一份「已通关」的进度（通关结算的写入面也要能过 JSON）
	start_new_run()
	var map_id: StringName = first_map_id()
	gsm.update_exploration_map_state(map_id, {"is_first_clear": true, "clear_count": 2})
	assert_eq(int(_progress_fingerprint(map_id)["clear_count"]), 2, "前置：通关次数已写入")

	# Act
	open_save_system()
	assert_eq(save_progress(), SLS2.SaveResult.SUCCESS, "存档应写得进盘")
	var expected: Dictionary = _progress_fingerprint(map_id)
	wipe_memory()
	assert_eq(load_progress(), SLS2.LoadResult.SUCCESS, "存档应读得回来")

	# Assert——通关记录整条活着回来（不是只剩一个数）
	var actual: Dictionary = _progress_fingerprint(map_id)
	assert_eq(int(actual["clear_count"]), int(expected["clear_count"]), "通关次数应一致")
	assert_true(is_first_clear(map_id), "首通标记应一致")
	assert_eq(int(actual["visited"]), int(expected["visited"]), "已访问节点数应一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 读档后要逐项比对的那份事实（键即断言项——不散在用例里各读一次）。[br]
## [br][b]visited 同时给「个数」与「集合」[/b]：个数一致但集合不同（比如顺序错位
## 或换了节点）也是回归，只看个数会放过。
func _progress_fingerprint(p_map_id: StringName) -> Dictionary:
	var nodes: Array = visited()
	var sorted_nodes: Array = nodes.duplicate()
	sorted_nodes.sort()
	return {
		"identity": str(gsm.player.get("identity_id", "")),
		"realm": int(gsm.player.get("realm", 0)),
		"visited": nodes.size(),
		"visited_nodes": sorted_nodes,
		"clear_count": clear_count(p_map_id),
		"collection": int((gsm.collection as Dictionary).get("owned_cards", []).size()),
		"ling_shi": ling_shi(),
		"current_map": str(current_map()),
	}
