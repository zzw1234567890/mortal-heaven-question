extends GutTest
## hud Story 004 Logic 内核单测：NotificationStack 通知队列。
##
## 覆盖 QA Test Cases 的 AC-1（自动消失）/ AC-2（容量上限与丢弃规则）/
## AC-3（重要通知优先级）/ AC-4（手动关闭）/ AC-6（类型映射全值表）
## 全部规格与 edge cases（story 2026-09-10 QL-STORY-READY G1-G8 裁决版）。
##
## 纯逻辑直调——无需场景树与 Autoload（时间注入模式：advance(delta) 推进时间，
## 先例 test_lingshi_formatter.gd）。风格：arrange/act/assert + 表驱动 + 中文失败消息。

const S: Script = preload("res://src/ui/hud/notification_stack.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

func _ids_in_stack(stack: RefCounted) -> Array:
	var ids: Array = []
	for entry: Dictionary in stack.get_active():
		ids.append(int(entry[&"id"]))
	return ids


func _has_id(stack: RefCounted, id: int) -> bool:
	return _ids_in_stack(stack).has(id)


func _texts_in_stack(stack: RefCounted) -> Array:
	var texts: Array = []
	for entry: Dictionary in stack.get_active():
		texts.append(str(entry[&"text"]))
	return texts


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：通知自动消失
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac001_item_notification_expires_after_3s() -> void:
	## AC-1 主体: push("item", "获得 回血丹 ×1") 且 advance(3.0) → 已移除
	# Arrange
	var stack: RefCounted = S.new()
	# Act
	stack.push("item", "获得 回血丹 ×1")
	var removed: Array = stack.advance(3.0)
	# Assert
	assert_eq(stack.get_active().size(), 0, "3s 后 item 通知应已移除")
	assert_eq(removed.size(), 1, "advance 应返回 1 条被移除条目")


func test_ac001_lingshi_notification_expires_after_2s() -> void:
	## AC-1 edge: 灵石通知 2s——advance(2.0) 后已移除；1.99s 时仍在
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("lingshi", "+25 灵石")
	# Act + Assert —— 不足 2s 仍在（advance(1.99) 后剩余 0.00999...——
	# IEEE754 2.0-1.99 二进制近似误差使剩余值 >0，边界语义已由 G8 专项用例锁定）
	stack.advance(1.99)
	assert_eq(stack.get_active().size(), 1, "1.99s 时灵石通知应仍在队列")
	# Act + Assert —— 补齐到 2.0s+ 已移除（对浮点误差留余量——用 0.02 越过边界）
	stack.advance(0.02)
	assert_eq(stack.get_active().size(), 0, "2.0s+ 后灵石通知应已移除")


func test_ac001_system_notification_expires_after_5s() -> void:
	## AC-1 edge: 系统提示 5s——4.99s 仍在；5.0s 已移除
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("system", "修为已达瓶颈")
	# Act + Assert
	stack.advance(4.99)
	assert_eq(stack.get_active().size(), 1, "4.99s 时系统提示应仍在队列")
	# 补齐越过 5s（浮点余量——G8 边界已由 item 3.0 恰达用例锁定）
	stack.advance(0.02)
	assert_eq(stack.get_active().size(), 0, "5.0s+ 后系统提示应已移除")


func test_ac001_advance_insufficient_keeps_notification() -> void:
	## AC-1 edge: 时间推进不足时仍在队列（item 3s——advance(2.9) 后仍在）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "获得 回血丹 ×1")
	# Act
	stack.advance(2.9)
	# Assert
	assert_eq(stack.get_active().size(), 1, "2.9s 时 item 通知应仍在队列")


func test_ac001_exact_duration_boundary_removed() -> void:
	## AC-1 edge（G8 裁决）: t=duration 恰好到达 → 已移除（≤0 即移除——含等号）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "获得 回血丹 ×1")
	# Act
	stack.advance(3.0)
	# Assert
	assert_eq(stack.get_active().size(), 0, "t=3.0 恰好到达时通知应已移除（G8 边界）")


func test_ac001_duration_minus_epsilon_still_active() -> void:
	## AC-1 edge（G8 裁决）: advance(duration - 0.01) → 仍在队列
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "获得 回血丹 ×1")
	# Act
	stack.advance(2.99)
	# Assert
	assert_eq(stack.get_active().size(), 1, "2.99s（duration-0.01）时通知应仍在队列（G8 边界）")


func test_ac001_partial_advance_accumulates() -> void:
	## AC-1 补充: 分段推进累计——1.0 + 1.0 + 1.0 = 3.0 后 item 通知移除
	## （advance 内部维护累计时间——G1 裁决）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "获得 回血丹 ×1")
	# Act
	stack.advance(1.0)
	stack.advance(1.0)
	stack.advance(1.0)
	# Assert
	assert_eq(stack.get_active().size(), 0, "三次 1.0s 分段推进累计 3.0s 后应移除")


func test_ac001_mixed_types_expire_independently() -> void:
	## AC-1 补充: 混合类型各自独立到期——2s 时灵石已移除、item 仍在
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("lingshi", "+25 灵石")
	stack.push("item", "获得 回血丹 ×1")
	# Act
	var removed: Array = stack.advance(2.0)
	# Assert
	assert_eq(removed.size(), 1, "2.0s 时仅灵石通知到期")
	assert_eq(str(removed[0][&"text"]), "+25 灵石", "被移除的应为灵石通知")
	assert_eq(stack.get_active().size(), 1, "item 通知应仍在队列")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：容量上限与丢弃规则
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac002_fourth_normal_push_evicts_earliest_normal() -> void:
	## AC-2 主体: 3 普通 + push 第 4 普通 → 最早的普通被移除（除本次 push 外），
	## 队列保持 3 条
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "第1条")
	stack.push("card", "第2条")
	stack.push("lingshi", "第3条")
	# Act
	var id4: int = stack.push("item", "第4条")
	# Assert
	assert_ne(id4, 0, "第 4 条普通通知应成功入队（挤出最早的而非拒绝本次）")
	assert_eq(stack.get_active().size(), 3, "队列应保持 3 条")
	assert_false(_has_id(stack, 1), "最早的普通通知（id=1）应被移除")
	assert_true(_has_id(stack, id4), "本次 push 的通知应在队列中")
	var texts: Array = _texts_in_stack(stack)
	assert_eq(texts, ["第2条", "第3条", "第4条"], "队列应保留第 2/3/4 条（FIFO 挤出最早）")


func test_ac002_important_not_evicted_when_mixed() -> void:
	## AC-2 edge: 3 条中含重要通知时重要通知不被丢弃
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "普通1")
	stack.push("system", "重要2")
	stack.push("item", "普通3")
	# Act
	stack.push("item", "普通4")
	# Assert
	assert_true(_has_id(stack, 2), "重要通知（system，id=2）不应被丢弃")
	assert_eq(stack.get_active().size(), 3, "队列应保持 3 条")
	assert_false(_has_id(stack, 1), "被挤出的是最早的非重要通知（id=1）")


func test_ac002_all_important_plus_important_allows_temp_overflow() -> void:
	## AC-2 edge（G2 裁决）: 3 全重要 + push 重要 → 队列临时 4 条，原 3 条均在
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("system", "重要1")
	stack.push("error", "重要2")
	stack.push("system", "重要3")
	# Act
	var id4: int = stack.push("error", "重要4")
	# Assert
	assert_ne(id4, 0, "重要通知 push 永不拒绝")
	assert_eq(stack.get_active().size(), 4, "队列应临时 4 条（重要永不丢弃）")
	for i: int in [1, 2, 3, 4]:
		assert_true(_has_id(stack, i), "原 3 条重要 + 本次重要均应在队列（id=%d）" % i)


func test_ac002_all_important_plus_normal_rejected() -> void:
	## AC-2 edge（G2 裁决）: 3 全重要 + push 普通 → push 被拒绝（返回 id=0），
	## 队列保持 3 条重要
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("system", "重要1")
	stack.push("error", "重要2")
	stack.push("system", "重要3")
	# Act
	var id4: int = stack.push("item", "普通4")
	# Assert
	assert_eq(id4, 0, "全重要队列 + 普通 push 应被拒绝（返回 0）")
	assert_eq(stack.get_active().size(), 3, "队列应保持 3 条")
	assert_false(_texts_in_stack(stack).has("普通4"), "被拒的普通通知不应出现在队列中")


func test_ac002_important_overflow_falls_back_on_next_normal() -> void:
	## AC-2 补充（G2 裁决「回落」语义）: 3 普通+1 重要（临时 4 条）后 push 普通
	## → 挤出 2 条最早普通回落到 3 条（3 普通-2 旧普通 + 1 重要 + 本次普通 = 3）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "普通1")
	stack.push("item", "普通2")
	stack.push("item", "普通3")
	stack.push("system", "重要4")
	assert_eq(stack.get_active().size(), 4, "前置：3 普通 + 1 重要 = 临时 4 条")
	# Act
	var id5: int = stack.push("item", "普通5")
	# Assert
	assert_ne(id5, 0, "回落路径的普通 push 应成功入队")
	assert_eq(stack.get_active().size(), 3, "应回落到 3 条（移除 2 条最早普通）")
	assert_false(_has_id(stack, 1), "普通1 应被挤出")
	assert_false(_has_id(stack, 2), "普通2 应被挤出")
	assert_true(_has_id(stack, 3), "普通3 应保留")
	assert_true(_has_id(stack, 4), "重要4 应保留")
	assert_true(_has_id(stack, id5), "本次 push 应保留")


func test_ac002_first_push_returns_id_one() -> void:
	## push 返回 id 递增语义——首次为 1（story 接口规格）
	# Arrange
	var stack: RefCounted = S.new()
	# Act + Assert
	assert_eq(stack.push("item", "a"), 1, "首次 push 应返回 id=1")
	assert_eq(stack.push("item", "b"), 2, "第二次 push 应返回 id=2")
	assert_eq(stack.push("item", "c"), 3, "第三次 push 应返回 id=3")


func test_ac002_rejected_push_does_not_consume_id() -> void:
	## QA G-1/G-4: 被拒 push 不消耗 id——3 重要 + 第 4 普通被拒（返回 0）后，
	## 下一次成功 push 返回 id=4（_next_id 未因拒绝路径递增，id 序号连续）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("system", "重要1")
	stack.push("system", "重要2")
	stack.push("system", "重要3")
	# Act —— 第 4 条普通被拒（全重要队列无可挤出项）
	var rejected_id: int = stack.push("item", "普通4")
	# Assert（G-4 内核侧——拒绝路径 _next_id 不递增的间接断言）
	assert_eq(rejected_id, 0, "全重要队列 + 普通 push 应被拒绝（返回 0）")
	# Act —— 下一次成功 push（再入一条重要）
	var next_id: int = stack.push("error", "重要4")
	# Assert（G-1——id 连续：被拒 push 未消耗 id=4）
	assert_eq(next_id, 4, "被拒 push 不消耗 id——下一个成功 push 应返回 id=4（连续）")


func test_ac002_important_overflow_falls_back_on_expiry() -> void:
	## QA G-2: 超时回落序列——3 普通 + 2 重要在队（临时 5 条），推进到 2 条普通
	## 到期 → 队列回落到 3 条内；继续推进到重要到期 → 逐条移除
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("lingshi", "普通1")     # 2s
	stack.push("lingshi", "普通2")     # 2s
	stack.push("lingshi", "普通3")     # 2s
	stack.push("system", "重要1")      # 5s
	stack.push("system", "重要2")      # 5s
	assert_eq(stack.get_active().size(), 5, "前置：3 普通 + 2 重要 = 临时 5 条")
	# Act —— 推进 2s：3 条普通到期（回落，重要仍在）
	var removed: Array = stack.advance(2.0)
	# Assert
	assert_eq(removed.size(), 3, "2s 时 3 条普通应全部到期")
	assert_eq(stack.get_active().size(), 2, "普通到期后队列回落到 2 条（重要仍在）")
	# Act —— 继续推进到 5s：2 条重要到期（逐条移除）
	removed = stack.advance(3.0)
	# Assert
	assert_eq(removed.size(), 2, "5s 时 2 条重要应全部到期")
	assert_eq(stack.get_active().size(), 0, "全部到期后队列应为空")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：重要通知优先级
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac003_error_push_enters_full_queue() -> void:
	## AC-3 主体: 3 普通满队 + push 错误提示（重要）→ 错误提示入队（临时 4 条）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "普通1")
	stack.push("item", "普通2")
	stack.push("item", "普通3")
	# Act
	var err_id: int = stack.push("error", "灵石不足")
	# Assert
	assert_ne(err_id, 0, "重要通知 push 应永不拒绝（G2 裁决）")
	assert_true(_has_id(stack, err_id), "错误提示应入队")
	assert_eq(stack.get_active().size(), 4, "满 3 普通时重要通知入队 → 临时 4 条")


func test_ac003_error_not_evicted_by_subsequent_normal() -> void:
	## AC-3 主体: 错误提示入队后不被后续普通通知挤出
	# Arrange —— 3 普通 + 1 错误（临时 4 条）
	var stack: RefCounted = S.new()
	stack.push("item", "普通1")
	stack.push("item", "普通2")
	stack.push("item", "普通3")
	var err_id: int = stack.push("error", "灵石不足")
	# Act —— push 2 条普通（每条触发回落挤出，目标均为普通1/2）
	stack.push("item", "普通4")
	stack.push("card", "普通5")
	# Assert
	assert_true(_has_id(stack, err_id), "错误提示不应被后续普通通知挤出")
	assert_eq(stack.get_active().size(), 3, "连续普通 push 后队列应回落到 3 条")
	assert_true(_texts_in_stack(stack).has("灵石不足"), "错误提示文本应仍在队列")


func test_ac003_consecutive_two_important() -> void:
	## AC-3 edge: 连续 2 条重要通知——均入队且均不被挤出
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "普通1")
	stack.push("item", "普通2")
	stack.push("item", "普通3")
	# Act
	var sys_id: int = stack.push("system", "系统提示A")
	var err_id: int = stack.push("error", "错误提示B")
	# Assert
	assert_ne(sys_id, 0, "第 1 条重要通知应入队")
	assert_ne(err_id, 0, "第 2 条重要通知应入队（重要永不挤出重要）")
	assert_eq(stack.get_active().size(), 5, "3 普通 + 2 重要 = 临时 5 条")
	assert_true(_has_id(stack, sys_id), "连续重要的第 1 条应在队列")
	assert_true(_has_id(stack, err_id), "连续重要的第 2 条应在队列")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：手动关闭
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac004_dismiss_removes_notification() -> void:
	## AC-4 主体: dismiss(id) 成功且 get_active() 不含该 id
	# Arrange
	var stack: RefCounted = S.new()
	var id: int = stack.push("item", "获得 回血丹 ×1")
	# Act
	var ok: bool = stack.dismiss(id)
	# Assert
	assert_true(ok, "dismiss 存在的 id 应返回 true")
	assert_false(_has_id(stack, id), "dismiss 后 get_active() 不应含该 id")
	assert_eq(stack.get_active().size(), 0, "队列应为空")


func test_ac004_dismiss_twice_returns_false() -> void:
	## AC-4 主体: 再次 dismiss 同 id 返回 false
	# Arrange
	var stack: RefCounted = S.new()
	var id: int = stack.push("item", "获得 回血丹 ×1")
	stack.dismiss(id)
	# Act + Assert
	assert_false(stack.dismiss(id), "重复 dismiss 同 id 应返回 false")


func test_ac004_dismiss_nonexistent_id_returns_false() -> void:
	## AC-4 补充: 不存在的 id dismiss 返回 false（不崩溃不报错）
	# Arrange
	var stack: RefCounted = S.new()
	# Act + Assert
	assert_false(stack.dismiss(999), "dismiss 不存在的 id 应返回 false")


func test_ac004_dismiss_earliest_keeps_rest() -> void:
	## AC-4 edge: 关闭最早一条后其余仍在（堆叠重排）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "第1条")
	stack.push("item", "第2条")
	stack.push("item", "第3条")
	# Act
	var ok: bool = stack.dismiss(1)
	# Assert
	assert_true(ok, "dismiss 最早一条应成功")
	assert_eq(_texts_in_stack(stack), ["第2条", "第3条"],
			"关闭最早一条后其余通知应保持（且维持入队序）")


func test_ac004_dismissed_notification_not_returned_by_advance() -> void:
	## AC-4 补充: 已手动关闭的通知不再被 advance 返回（无双重移除）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "第1条")
	stack.push("item", "第2条")
	stack.dismiss(1)
	# Act
	var removed: Array = stack.advance(3.0)
	# Assert
	assert_eq(removed.size(), 1, "已手动关闭的 id=1 不应再出现在 advance 移除列表")
	assert_eq(str(removed[0][&"text"]), "第2条", "advance 移除的应为仅存的第 2 条")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：类型映射全值表（G3 裁决 2026-09-10）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac006_type_meta_full_value_table() -> void:
	## AC-6 主体: 8 类型映射全值表逐条断言（duration/color/blink/important 四字段）
	# Arrange —— GDD §4 类型表 + story G3/G4/G6 裁决全值
	var expected: Array = [
		["item", 3.0, "green", false, false],
		["card", 3.0, "gold", false, false],
		["lingshi", 2.0, "gold", false, false],
		["cultivation", 2.0, "purple", false, false],
		["combat_event_offensive", 3.0, "red", false, false],
		["combat_event_defensive", 3.0, "blue", false, false],
		["system", 5.0, "white", false, true],
		["error", 5.0, "red", true, true],
	]
	for c: Array in expected:
		# Act
		var meta: Dictionary = S.get_type_meta(c[0])
		# Assert
		assert_eq(meta[&"duration"], c[1], "%s duration 应为 %s" % [c[0], c[1]])
		assert_eq(meta[&"color"], c[2], "%s color 应为 %s" % [c[0], c[2]])
		assert_eq(meta[&"blink"], c[3], "%s blink 应为 %s" % [c[0], c[3]])
		assert_eq(meta[&"important"], c[4], "%s important 应为 %s" % [c[0], c[4]])


func test_ac006_only_error_blinks() -> void:
	## AC-6 锁定: 仅 error 类型 blink=true（G3 裁决——blink 专属）
	# Arrange
	var types: Array = ["item", "card", "lingshi", "cultivation",
			"combat_event_offensive", "combat_event_defensive", "system"]
	for type: String in types:
		# Act
		var meta: Dictionary = S.get_type_meta(type)
		# Assert
		assert_false(meta[&"blink"], "%s 不应 blink（blink 为 error 专属）" % type)


func test_ac006_unknown_type_safe_default_as_system() -> void:
	## AC-6 edge（G3 裁决）: 未知类型 → 安全默认按系统提示处理（5s/白/重要/不闪）
	## + push_warning
	# Arrange + Act
	var meta: Dictionary = S.get_type_meta("totally_unknown_type")
	# Assert
	assert_eq(meta[&"duration"], 5.0, "未知类型 duration 应按系统提示 5s")
	assert_eq(meta[&"color"], "white", "未知类型 color 应按系统提示 white")
	assert_false(meta[&"blink"], "未知类型不应 blink（非 error）")
	assert_true(meta[&"important"], "未知类型应按系统提示判为重要")
	assert_push_warning_count(1, "未知类型查询应 push_warning 1 次")


func test_ac006_unknown_type_push_treated_as_important() -> void:
	## AC-6 edge 补充: 未知类型 push 走安全默认——全重要队列 + 未知类型 push
	## 不被拒绝（按 system 重要处理）且行为与 system 一致
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("system", "重要1")
	stack.push("system", "重要2")
	stack.push("system", "重要3")
	# Act
	var id: int = stack.push("unknown_type_x", "未知类型条目")
	# Assert
	assert_ne(id, 0, "未知类型按系统提示（重要）处理——push 不应被拒绝")
	var entry: Dictionary = stack.get_active().back()
	assert_eq(entry[&"color"], "white", "未知类型条目 color 应为 white（安全默认）")
	assert_true(entry[&"important"], "未知类型条目应判为重要（安全默认）")


func test_ac006_get_active_snapshot_is_readonly() -> void:
	## get_active 只读快照语义——调用方修改快照不影响内部队列
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "条目A")
	# Act —— 篡改快照
	var snapshot: Array = stack.get_active()
	snapshot[0][&"text"] = "被篡改"
	# Assert
	assert_eq(_texts_in_stack(stack), ["条目A"],
			"修改快照不应影响内部队列（duplicate 保护）")


func test_ac006_advance_negative_delta_clamped() -> void:
	## advance 负 delta 防御——钳 0 不倒流（时间不可倒退，通知不得因负增量复活）
	# Arrange
	var stack: RefCounted = S.new()
	stack.push("item", "条目A")
	stack.advance(1.5)
	# Act
	stack.advance(-1.0)
	# Assert
	assert_eq(float(stack.get_active()[0][&"remaining"]), 1.5,
			"负 delta 应被钳 0——剩余时长不变（不倒流）")
