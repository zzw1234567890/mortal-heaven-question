extends GutTest
## Story 3-10 验收测试：GSM 第二层原子写入方法独立单测补齐。
##
## 覆盖此前零覆盖的 6 个第二层方法：
##   _set_battle_status_snapshot / set_session_scene / remove_card_from_collection /
##   restore_action_points / unlock_talent / advance_chapter。
##
## 测试通过 preload + .new() 创建独立 GSM 实例，手动 _ready() 初始化（同其余 GSM 测试先例）。

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

var gsm


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()


func after_each() -> void:
	gsm.free()
	gsm = null


# ═════════════════════════════════════════════════════════════════════════════
# _set_battle_status_snapshot —— 战斗状态快照写入（战斗结束导出）
# ═════════════════════════════════════════════════════════════════════════════

func test_set_battle_status_snapshot_writes_into_battle() -> void:
	gsm.battle_start({})
	var snapshot: Array = [{"id": 1, "stacks": 2}]
	gsm._set_battle_status_snapshot(snapshot)
	assert_eq(gsm.battle.status_snapshot, snapshot, "快照应写入 battle.status_snapshot")
	gsm.battle_end({"result": "test"})


func test_set_battle_status_snapshot_null_battle_rejected() -> void:
	gsm.battle = null
	gsm._set_battle_status_snapshot([{"id": 1}])
	assert_null(gsm.battle, "无活跃战斗时应拒绝写入，battle 仍为 null")


func test_set_battle_status_snapshot_same_value_dedup() -> void:
	gsm.battle_start({})
	gsm.battle.status_snapshot = [{"id": 1}]
	gsm._pending_changes.clear()
	gsm._set_battle_status_snapshot([{"id": 1}])
	assert_true(gsm._pending_changes.is_empty(), "同值快照应去重，不缓冲变更")
	gsm.battle_end({"result": "test"})


# ═════════════════════════════════════════════════════════════════════════════
# set_session_scene —— 当前场景写入
# ═════════════════════════════════════════════════════════════════════════════

func test_set_session_scene_writes_id_and_path() -> void:
	gsm.set_session_scene(7, "res://scenes/battle.tscn")
	assert_eq(gsm.session.scene_id, 7, "scene_id 应写入")
	assert_eq(gsm.session.current_scene, "res://scenes/battle.tscn", "current_scene 应写入")


func test_set_session_scene_buffers_both_paths() -> void:
	gsm.set_session_scene(3, "res://scenes/explore.tscn")
	assert_true(gsm._pending_changes.has("session.scene_id"), "应缓冲 session.scene_id")
	assert_true(gsm._pending_changes.has("session.current_scene"), "应缓冲 session.current_scene")


# ═════════════════════════════════════════════════════════════════════════════
# remove_card_from_collection —— 按 card_instance_id 移除卡牌
# ═════════════════════════════════════════════════════════════════════════════

func test_remove_card_from_collection_success() -> void:
	gsm.enable_validation({"card_001": {"id": 1}})
	gsm.add_card_to_collection({"template_id": "card_001", "card_instance_id": 42})
	gsm.add_card_to_collection({"template_id": "card_001", "card_instance_id": 43})
	assert_eq(gsm.collection.owned_cards.size(), 2)

	var ok: bool = gsm.remove_card_from_collection(42)
	assert_true(ok, "移除应成功")
	assert_eq(gsm.collection.owned_cards.size(), 1, "应移除 1 张")
	assert_eq(gsm.collection.owned_cards[0].card_instance_id, 43, "剩余卡牌应保留")
	assert_eq(gsm.collection.total_count, 1, "total_count 应更新")


func test_remove_card_from_collection_validation_skip_rejected() -> void:
	var ok: bool = gsm.remove_card_from_collection(42)
	assert_false(ok, "校验未开启应拒绝移除")


func test_remove_card_from_collection_not_found_rejected() -> void:
	gsm.enable_validation({"card_001": {"id": 1}})
	var ok: bool = gsm.remove_card_from_collection(999)
	assert_false(ok, "未找到实例应返回 false")


# ═════════════════════════════════════════════════════════════════════════════
# restore_action_points —— 恢复行动力
# ═════════════════════════════════════════════════════════════════════════════

func test_restore_action_points_increments() -> void:
	gsm.exploration.action_points = 1
	gsm.restore_action_points(2)
	assert_eq(gsm.exploration.action_points, 3, "行动力应从 1 恢复到 3")


func test_restore_action_points_non_positive_rejected() -> void:
	gsm.exploration.action_points = 5
	gsm.restore_action_points(0)
	gsm.restore_action_points(-3)
	assert_eq(gsm.exploration.action_points, 5, "非正恢复量不应改变行动力")


# ═════════════════════════════════════════════════════════════════════════════
# unlock_talent —— 解锁天赋（去重 append）
# ═════════════════════════════════════════════════════════════════════════════

func test_unlock_talent_appends() -> void:
	gsm.unlock_talent(&"talent_003")
	assert_eq(gsm.player.talents, [&"talent_003"], "天赋应追加到 talents 数组")


func test_unlock_talent_dedup_existing() -> void:
	gsm.player.talents = [&"talent_001", &"talent_002"]
	gsm.unlock_talent(&"talent_001")
	assert_eq(gsm.player.talents.size(), 2, "已有天赋不应重复追加")


# ═════════════════════════════════════════════════════════════════════════════
# advance_chapter —— 推进章节（旧章节进入 completed_chapters）
# ═════════════════════════════════════════════════════════════════════════════

func test_advance_chapter_first_chapter_sets_current() -> void:
	gsm.advance_chapter(&"chapter_1")
	assert_eq(gsm.narrative.current_chapter, "chapter_1", "current_chapter 应写入")
	assert_true(gsm.narrative.completed_chapters.is_empty(), "首章不应有已完成章节")


func test_advance_chapter_moves_old_to_completed() -> void:
	gsm.advance_chapter(&"chapter_1")
	gsm.advance_chapter(&"chapter_2")
	assert_eq(gsm.narrative.current_chapter, "chapter_2", "current_chapter 应更新")
	assert_eq(gsm.narrative.completed_chapters, ["chapter_1"], "旧章节应进入 completed_chapters")


func test_advance_chapter_same_chapter_dedup() -> void:
	gsm.advance_chapter(&"chapter_1")
	gsm.advance_chapter(&"chapter_1")
	assert_eq(gsm.narrative.current_chapter, "chapter_1")
	assert_true(gsm.narrative.completed_chapters.is_empty(), "相同章节不应重复推进")


func test_advance_chapter_empty_rejected() -> void:
	var original: String = gsm.narrative.current_chapter
	gsm.advance_chapter(&"")
	assert_eq(gsm.narrative.current_chapter, original, "空章节 ID 应被拒绝")
