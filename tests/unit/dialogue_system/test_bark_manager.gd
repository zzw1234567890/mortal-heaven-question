extends GutTest
## Story 7-14 验收测试：BarkManager + play_bark + get_bark_history。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 内联 bark 池数据
##   - 使用固定 seed 确保随机确定性
##   - 验证不重复、池耗尽重置、信号发射、历史记录
##
## 设计文档来源：GDD dialogue-system.md §7 bark 池机制 + §5/§6 验收标准
## Story 来源：production/epics/dialogue-system/story-003-bark-manager.md

const BM := preload("res://src/feature/dialogue/bark_manager.gd")

## 测试用 bark 池。
const TEST_POOL := ["文本A", "文本B", "文本C"]


func before_each() -> void:
	# 固定随机种子确保确定性
	seed(42)


# ============================================================================
# AC-001：BarkManager 实例化后持有 bark 池字典
# ============================================================================

func test_instance_has_bark_pools() -> void:
	# Arrange + Act
	var bm: BM = BM.new()

	# Assert
	assert_eq(typeof(bm._bark_pools), TYPE_DICTIONARY, "应持有 _bark_pools 字典")
	assert_true(bm._bark_pools.is_empty(), "初始应为空字典")


# ============================================================================
# AC-002：register_bark_pool 注册角色 bark 池
# ============================================================================

func test_register_bark_pool() -> void:
	# Arrange
	var bm: BM = BM.new()

	# Act
	bm.register_bark_pool("lin_yuan", TEST_POOL)

	# Assert
	assert_true(bm._bark_pools.has("lin_yuan"), "应注册 lin_yuan")
	assert_eq((bm._bark_pools["lin_yuan"] as Array).size(), 3, "池大小应为 3")
	assert_eq((bm._remaining["lin_yuan"] as Array).size(), 3, "剩余池也应为 3")


# ============================================================================
# AC-003：play_bark 从池中随机抽取一条 bark 文本返回
# ============================================================================

func test_play_bark_returns_text() -> void:
	# Arrange
	var bm: BM = BM.new()
	bm.register_bark_pool("lin_yuan", TEST_POOL)

	# Act
	var text: String = bm.play_bark("lin_yuan")

	# Assert
	assert_true(TEST_POOL.has(text), "返回的文本应在池中")
	assert_false(text.is_empty(), "文本不应为空")


# ============================================================================
# AC-004：连续 play_bark 5 次（池大小=3），前 3 次各不相同
# ============================================================================

func test_play_bark_no_repeat_within_pool() -> void:
	# Arrange
	var bm: BM = BM.new()
	bm.register_bark_pool("lin_yuan", TEST_POOL)

	# Act——连续播放 3 次
	var results: Array = []
	for i in range(3):
		results.append(bm.play_bark("lin_yuan"))

	# Assert——前 3 次各不相同
	assert_eq(results.size(), 3, "应有 3 条结果")
	for i in range(3):
		for j in range(i + 1, 3):
			assert_ne(results[i], results[j], "第 %d 次和第 %d 次应不同" % [i + 1, j + 1])


# ============================================================================
# AC-005：池耗尽后第 4 次 play_bark 重置池并选择与上一句不同的 bark
# ============================================================================

func test_pool_reset_after_exhaustion() -> void:
	# Arrange
	var bm: BM = BM.new()
	bm.register_bark_pool("lin_yuan", TEST_POOL)

	# Act——前 3 次耗尽池
	var first_batch: Array = []
	for i in range(3):
		first_batch.append(bm.play_bark("lin_yuan"))
	# 第 4 次——重置池
	var fourth: String = bm.play_bark("lin_yuan")

	# Assert——第 4 次不应与第 3 次相同
	assert_ne(fourth, first_batch[2], "重置后第 4 次不应与上一句相同")
	assert_true(TEST_POOL.has(fourth), "第 4 次文本应在池中")
	assert_eq(bm.get_remaining_count("lin_yuan"), 2, "重置后已抽 1 条，剩余应为 2")


# ============================================================================
# AC-006：play_bark 后发射 bark_played(character_id, text) 信号
# ============================================================================

func test_play_bark_emits_signal() -> void:
	# Arrange
	var bm: BM = BM.new()
	bm.register_bark_pool("lin_yuan", TEST_POOL)
	var received: Dictionary = {"char_id": "", "text": "", "received": false}
	bm.bark_played.connect(func(cid: String, t: String): received["char_id"] = cid; received["text"] = t; received["received"] = true)

	# Act
	var text: String = bm.play_bark("lin_yuan")

	# Assert
	assert_true(received["received"], "应发射 bark_played 信号")
	assert_eq(str(received["char_id"]), "lin_yuan", "信号参数 character_id 应为 lin_yuan")
	assert_eq(str(received["text"]), text, "信号参数 text 应与返回值一致")


# ============================================================================
# AC-007：get_bark_history() 返回已播放记录列表
# ============================================================================

func test_get_bark_history() -> void:
	# Arrange
	var bm: BM = BM.new()
	bm.register_bark_pool("lin_yuan", TEST_POOL)

	# Act
	bm.play_bark("lin_yuan")
	bm.play_bark("lin_yuan")
	var history: Array = bm.get_bark_history()

	# Assert
	assert_eq(history.size(), 2, "应有 2 条历史")
	assert_eq(str(history[0]["character_id"]), "lin_yuan", "第 1 条 character_id 应为 lin_yuan")
	assert_eq(int(history[0]["index"]), 0, "第 1 条 index 应为 0")
	assert_eq(int(history[1]["index"]), 1, "第 2 条 index 应为 1")


# ============================================================================
# AC-008：play_bark 未注册角色返回空字符串，不崩溃
# ============================================================================

func test_play_bark_unregistered_character() -> void:
	# Arrange
	var bm: BM = BM.new()

	# Act
	var text: String = bm.play_bark("unknown_char")

	# Assert
	assert_eq(text, "", "未注册角色应返回空字符串")


# ============================================================================
# AC-009：空池角色 play_bark 返回空字符串，不崩溃
# ============================================================================

func test_play_bark_empty_pool() -> void:
	# Arrange
	var bm: BM = BM.new()
	bm.register_bark_pool("silent_char", [])

	# Act
	var text: String = bm.play_bark("silent_char")

	# Assert
	assert_eq(text, "", "空池角色应返回空字符串")


# ============================================================================
# AC-010：BarkManager 为 RefCounted，通过 new() 实例化
# ============================================================================

func test_bark_manager_is_refcounted() -> void:
	# Arrange + Act
	var bm: BM = BM.new()

	# Assert
#	assert_false(bm is Node, "BarkManager 不应为 Node")
	assert_true(bm is RefCounted, "BarkManager 应为 RefCounted")
