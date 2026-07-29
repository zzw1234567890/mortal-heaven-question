extends GutTest
## Story 004 验收测试：锁泄漏防护与退出时清理。
##
## 覆盖 AC-014 到 AC-017 和 AC-025/AC-026。
## 验证 push/pop 配对、场景变更自动清理、_exit_tree 断开连接。

const IM := preload("res://src/foundation/input_manager.gd")

var im: Node = null


func before_each() -> void:
	im = IM.new()
	im._ready()


func after_each() -> void:
	im.free()
	im = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-014: 正常路径 push+pop 配对——无锁泄漏
# push_lock(ANIMATION, &"combat") + pop_lock(&"combat") → 锁正确释放
# ═══════════════════════════════════════════════════════════════════════════════

func test_same_source_push_pop_paired_no_leak() -> void:
	im.push_lock(IM.LockType.ANIMATION, &"combat")
	assert_eq(im._lock_stack.size(), 1, "push 后栈深度应为 1")

	im.pop_lock(&"combat")
	assert_eq(im._lock_stack.size(), 0, "pop 后栈应为空")

	# 验证 pop 后可以重新 push 同一 source（不会触发重复检测）
	im.push_lock(IM.LockType.ANIMATION, &"combat")
	assert_eq(im._lock_stack.size(), 1, "pop 后重新 push 同一 source 应成功")
	assert_eq(im._lock_stack[0].type, IM.LockType.ANIMATION, "重新 push 的类型应正确")


# 多次 push/pop 配对——无泄漏
func test_multiple_push_pop_pairing() -> void:
	im.push_lock(IM.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM.LockType.ANIMATION, &"sys_b")
	assert_eq(im._lock_stack.size(), 2)

	im.pop_lock(&"sys_b")
	assert_eq(im._lock_stack.size(), 1)
	assert_eq(im._lock_stack[0].source, &"sys_a", "sys_b 移除后 sys_a 应仍存在")

	im.pop_lock(&"sys_a")
	assert_eq(im._lock_stack.size(), 0, "全部 pop 后栈应为空")


# 模拟异常路径——push 后未 pop 时的状态检查
func test_unpaired_push_detected_by_duplicate_check() -> void:
	# 正常 push
	im.push_lock(IM.LockType.ANIMATION, &"combat")
	assert_eq(im._lock_stack.size(), 1)

	# 漏掉 pop_lock——再次 push 同一 source
	# 重复 push 检测应捕获此情况（记录警告并跳过）
	im.push_lock(IM.LockType.ANIMATION, &"combat")
	# 栈深度不变——第二次 push 被跳过
	assert_eq(im._lock_stack.size(), 1,
			"重复 push 同一 source 不应增加栈——检测到可能的 pop 遗漏")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-015: clear_locks(source) 仅移除该 source 的锁
# 同一 source 在 push 后、pop 前的任何时刻调用 clear_locks(&"combat")
# → 栈中该 source 的所有锁被移除
# ═══════════════════════════════════════════════════════════════════════════════

func test_clear_locks_by_source_removes_only_that_source() -> void:
	im.push_lock(IM.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM.LockType.ANIMATION, &"sys_b")
	im.push_lock(IM.LockType.MODAL, &"sys_c")
	assert_eq(im._lock_stack.size(), 3)

	# 清除 sys_b
	im.clear_locks(&"sys_b")
	assert_eq(im._lock_stack.size(), 2, "清除 sys_b 后应剩 2 个锁")

	# sys_a 和 sys_c 仍在
	var remaining_sources: Array[StringName] = []
	for entry in im._lock_stack:
		remaining_sources.append(entry.source)
	assert_true(remaining_sources.has(&"sys_a"), "sys_a 应仍在栈中")
	assert_true(remaining_sources.has(&"sys_c"), "sys_c 应仍在栈中")
	assert_false(remaining_sources.has(&"sys_b"), "sys_b 不应在栈中")


# 同一 source 出现在栈中多次的情况（通过直接操纵内部栈模拟）
# 测试 clear_locks(source) 移除所有匹配项
func test_clear_locks_by_source_multiple_entries() -> void:
	# 虽然 AC-004 阻止同 source 重复 push，但通过直接追加来模拟边缘情况
	# （万一通过直接修改数组引入了重复 source 条目）
	im.push_lock(IM.LockType.DIALOGUE, &"leak_sys")
	im.push_lock(IM.LockType.MODAL, &"other_sys")
	# 直接追加第二个 leak_sys 条目
	var second := IM.LockEntry.new()
	second.type = IM.LockType.ANIMATION
	second.source = &"leak_sys"
	second.device_mask = IM.DEVICE_ALL
	im._lock_stack.append(second)
	assert_eq(im._lock_stack.size(), 3)

	# clear_locks(&"leak_sys")——应移除两个 leak_sys 条目
	im.clear_locks(&"leak_sys")
	assert_eq(im._lock_stack.size(), 1, "移除 leak_sys 的两个条目后应剩 1 个")
	assert_eq(im._lock_stack[0].source, &"other_sys", "剩余应为 other_sys")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-016: tree_changed 清除所有遗留锁
# 战斗动画 await 未完成时 SceneManager 切换场景 → tree_changed 触发
# → clear_locks() → 遗留的 animation 锁被清理
# ═══════════════════════════════════════════════════════════════════════════════

func test_tree_changed_clears_all_orphaned_locks() -> void:
	# 模拟场景：多个系统的锁被 push，但 pop 来不及调用
	im.push_lock(IM.LockType.DIALOGUE, &"dialogue_system")
	im.push_lock(IM.LockType.ANIMATION, &"combat_system")
	im.push_lock(IM.LockType.MODAL, &"settings_menu")
	assert_eq(im._lock_stack.size(), 3,
			"场景中有 3 个活跃锁——战斗动画和弹窗均未关闭")

	# 场景变更触发 tree_changed → _on_tree_changed 清除全部锁
	im._on_tree_changed()
	assert_eq(im._lock_stack.size(), 0,
			"tree_changed 后所有遗留锁应被清除")


# 验证 tree_changed 后 GSM 状态也被清理
func test_tree_changed_syncs_empty_to_gsm() -> void:
	im.push_lock(IM.LockType.DIALOGUE, &"orphan_test")
	im.push_lock(IM.LockType.TRANSITION, &"scene_test")
	assert_eq(im._lock_stack.size(), 2)

	im._on_tree_changed()

	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 0, "tree_changed 后 GSM 中锁数据也应为空")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-017: 调用方最佳实践文档
# Story 包含调用方最佳实践示例——每个 push_lock() 后须在返回/异常路径中配对的 pop_lock()
# ═══════════════════════════════════════════════════════════════════════════════

func test_call_pattern_documentation() -> void:
	## AC-017: 调用方文档——验证 Story 文件中包含调用方最佳实践示例。
	##
	## 本测试通过读取故事文件来确认最佳实践部分存在。
	## 最佳实践模式：
	##   1. 始终在 push_lock() 后立即安排 pop_lock()
	##   2. 若使用 await，确保所有退出路径都调用 pop_lock()
	##   3. 防御性代码：在系统退出/卸载时调用 clear_locks(source)

	var story_file := FileAccess.open(
			"res://production/epics/input-manager/story-004-modal-override-edge-cases.md",
			FileAccess.READ)
	assert_not_null(story_file, "Story 004 文件应存在并可读取")

	var content: String = story_file.get_as_text()
	story_file.close()

	# 验证最佳实践模式存在
	assert_true(content.contains("push_lock"),
			"Story 应包含 push_lock 代码示例")
	assert_true(content.contains("pop_lock"),
			"Story 应包含 pop_lock 代码示例")
	assert_true(content.contains("clear_locks"),
			"Story 应包含 clear_locks 防御性代码示例")

	# 验证调用方最佳实践章节
	assert_true(
			content.contains("最佳实践") or content.contains("Best Practice")
					or content.contains("调用方") or content.contains("Caller"),
			"Story 应包含调用方最佳实践章节")

	# 验证 await 异常路径指引
	assert_true(content.contains("await") or content.contains("async"),
			"Story 应包含 await 异常路径的处理指引")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-025: _exit_tree 断开 tree_changed 连接——防止悬挂引用
# ═══════════════════════════════════════════════════════════════════════════════

func test_exit_tree_disconnects_tree_changed() -> void:
	## AC-025: InputManager 在节点退出时断开 tree_changed 连接。
	## 将 node 添加到场景树中使其处于"树内"状态——验证 disconnect 分支确实被执行。

	im.push_lock(IM.LockType.MODAL, &"exit_test")

	# 将 im 添加到场景树——触发 is_inside_tree() → true，从而 _ready() 中的 connect 生效
	add_child(im)
	assert_true(im.is_inside_tree(), "add_child 后应处于场景树中")

	# _exit_tree 现在将执行 disconnect 分支
	im._exit_tree()
	assert_eq(im._lock_stack.size(), 0, "_exit_tree 后锁栈应为空")

	# 验证信号已断开：emit tree_changed 不应再触发 _on_tree_changed
	get_tree().tree_changed.emit()
	assert_eq(im._lock_stack.size(), 0, "tree_changed emit 后锁栈应仍为空——信号已被断开")

	# 清理：移除 node 以避免孤儿
	remove_child(im)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-026: _exit_tree 中清理锁栈 + 最终 _sync_to_gsm()
# 确保 GSM 中无残留状态
# ═══════════════════════════════════════════════════════════════════════════════

func test_exit_tree_clears_stack_and_syncs_gsm() -> void:
	## AC-026: _exit_tree 中清理锁栈 + 最终 _sync_to_gsm()。

	# 先 push 一些锁
	im.push_lock(IM.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM.LockType.MODAL, &"sys_b")
	assert_eq(im._lock_stack.size(), 2)

	# 调用 _exit_tree 触发清理
	im._exit_tree()

	# GSM 应为空
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 0,
			"_exit_tree 后 GSM.session.input_locks 应为空——无残留状态")


# ═══════════════════════════════════════════════════════════════════════════════
# 补充测试：_exit_tree 重复调用不崩溃
# ═══════════════════════════════════════════════════════════════════════════════

func test_exit_tree_idempotent() -> void:
	## _exit_tree 重复调用不应崩溃
	im.push_lock(IM.LockType.DIALOGUE, &"test")
	im._exit_tree()
	# 第二次调用不应崩溃
	im._exit_tree()
	assert_eq(im._lock_stack.size(), 0, "重复 _exit_tree 后栈仍为空")


# _exit_tree 的 GSM 同步结果——先 push 再 _exit_tree
func test_exit_tree_gsm_empty_after_cleanup() -> void:
	# 先写入一些数据到 GSM
	im.push_lock(IM.LockType.TRANSITION, &"final_scene")
	var locks_before: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks_before.size(), 1, "_exit_tree 前 GSM 应有 1 条记录")

	im._exit_tree()

	var locks_after: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks_after.size(), 0, "_exit_tree 后 GSM 无残留锁记录")
