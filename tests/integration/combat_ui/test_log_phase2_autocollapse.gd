extends GutTest
## combat-ui-layout Story 004 集成测试：日志行为（AC-2）。
##
## 覆盖：默认折叠、append_entry 滚底（scroll_vertical 位于最大值）、
## 阶段 2 进入自动收起、战斗结束清空、折叠态新条目仍追加。
##
## Story 类型 UI（Integration）——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/combat_ui/test_layout_skeleton.gd。

const LogScript := preload("res://src/ui/combat/layout/combat_log.gd")

var log: CombatLog = null


func before_each() -> void:
	log = LogScript.new()
	add_child_autofree(log)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：日志行为（默认折叠 / 滚底 / 阶段 2 收起 / 清空）
# ═══════════════════════════════════════════════════════════════════════════════

func test_log_default_collapsed_as_label() -> void:
	# Then: 默认折叠（展开面板不可见——GDD「默认折叠为小标签」）
	assert_false(log.is_expanded(), "默认应为折叠态")
	assert_false(log.expand_panel.visible, "展开面板默认应不可见")


func test_log_append_entry_scrolls_to_bottom() -> void:
	# Arrange —— 展开 + 追加多条
	log.expand()
	for i: int in range(20):
		log.append_entry("[2·攻击结算] 林渊 → 攻击 → 敌方前1 → %d伤害" % (i + 1))
	# 等待滚底落定（call_deferred 于帧末 deferred 阶段读新鲜 max_value——code-review 阻塞项修复）
	await get_tree().process_frame
	await get_tree().process_frame
	# Then: 20 条全部入列 + 滚动位于真实底部（AC-2 滚底条款）
	assert_eq(log.get_entries().size(), 20, "应有 20 条日志")
	var vbar: VScrollBar = log.scroll.get_v_scroll_bar()
	var max_value: int = int(vbar.max_value)
	assert_true(max_value > 0, "前置：内容高度应产生可滚动范围（排除真空通过）")
	# Godot 将 scroll_vertical 钳制到 [max_value - page]（真实底部）；
	# 设 max_value 即滚到底，故断言钳制后的真实底部值。
	assert_eq(log.get_scroll_vertical(), int(vbar.max_value - vbar.page),
			"滚动位置应位于真实底部（max_value - page）")
	# Then: 最新条目在正文末尾
	assert_true(log.log_rich.text.ends_with("20伤害"),
			"最新条目应位于正文末尾")


func test_log_expand_panel_half_screen_height() -> void:
	# AC-6 半屏覆盖（QA 缺口 #4）：展开面板高度 = 视口高度 × 50%
	log.expand()
	await get_tree().process_frame
	var viewport_h: float = log.get_viewport_rect().size.y
	var panel_h: float = log.expand_panel.offset_bottom - log.expand_panel.offset_top
	assert_almost_eq(panel_h, viewport_h * 0.5, 1.0,
			"展开面板高度应约等于屏高 50%%（屏 %s / 面板 %s）" % [viewport_h, panel_h])


func test_log_phase2_autocollapse() -> void:
	# Arrange —— 展开态
	log.expand()
	assert_true(log.is_expanded(), "前置：日志已展开")
	# When: phase_changed(2) 触发（AC-2 阶段 2 进入自动收起）
	log.apply_phase(2)
	# Then: 折叠态恢复
	assert_false(log.is_expanded(), "阶段 2 进入后日志应自动收起")
	assert_false(log.expand_panel.visible, "阶段 2 进入后展开面板应隐藏")


func test_log_clear_on_battle_end() -> void:
	# Arrange —— 追加若干条目
	log.append_entry("[1·抽牌] 林渊 → 抽牌 → 手牌 → 2张")
	log.append_entry("[2·攻击结算] 林渊 → 攻击 → 敌方前1 → 5伤害")
	assert_eq(log.get_entries().size(), 2, "前置：有 2 条日志")
	# When: 战斗结束清空（AC-2 战后清理条款）
	log.clear()
	# Then: 条目清空
	assert_eq(log.get_entries().size(), 0, "清空后应为 0 条")
	assert_eq(log.log_rich.text, "", "清空后正文应为空")


func test_log_append_while_collapsed_still_appends() -> void:
	# When: 折叠态下追加新条目（AC-2 edge——仍追加，展开后可见）
	log.append_entry("[1·抽牌] 林渊 → 抽牌 → 手牌 → 2张")
	# Then: 条目已追加（展开后可见）
	assert_eq(log.get_entries().size(), 1, "折叠态新条目仍应追加")
	assert_false(log.is_expanded(), "折叠态追加不改变展开状态")


func test_log_expand_keeps_state() -> void:
	# When: 展开 → 再展开（幂等）
	log.expand()
	log.expand()
	# Then: 仍展开（不重复副作用）
	assert_true(log.is_expanded(), "重复展开应保持展开态")
