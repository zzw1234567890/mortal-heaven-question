extends GutTest
## combat-ui-layout Story 004 集成测试：阵法区（AC-4/AC-5）。
##
## 覆盖：默认 3 空槽位、apply_slot 部署/激活快照、阵营颜色回调解析、
## 越界守卫、阵名经 formation_info 回调解析、set_slot_active 熄灭光环保留阵名、
## apply_slot_states 全量重扫。
##
## Story 类型 UI（Integration）——此文件为 BLOCKING 证据（QA 缺口 #1 补齐）。
## 风格先例：tests/integration/combat_ui/test_phase_indicator_signal.gd。

const ZoneScript := preload("res://src/ui/combat/layout/formation_zone.gd")

var zone: FormationZone = null


func before_each() -> void:
	zone = ZoneScript.new()
	add_child_autofree(zone)


## 阵营颜色 mock 回调——tag_id → {name, color}。
func _tag_color(tag_id: StringName) -> Dictionary:
	if tag_id == &"zhengdao":
		return {"name": "正道", "color": Color(0.29, 0.62, 0.43)}
	if tag_id == &"modao":
		return {"name": "魔道", "color": Color(0.75, 0.22, 0.17)}
	return {}


## 阵法信息 mock 回调——template_id → {name, tag_id}。
func _formation_info(template_id: StringName) -> Dictionary:
	if template_id == &"cangxuan_formation":
		return {"name": "苍玄盟阵", "tag_id": &"zhengdao"}
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：阵法区（3 槽位 / 部署快照 / 空位虚线框）
# ═══════════════════════════════════════════════════════════════════════════════

func test_formation_zone_three_empty_slots_default() -> void:
	# Then: 默认 3 槽位且全空（template_id 空）
	var data: Array[Dictionary] = zone.get_slot_data()
	assert_eq(data.size(), 3, "阵法区应为 3 槽位")
	for i: int in range(3):
		assert_eq(data[i]["template_id"], &"", "槽位 %d 默认应为空" % i)
		assert_false(data[i]["is_active"], "槽位 %d 默认非激活" % i)


func test_formation_zone_apply_slot_deploys() -> void:
	# When: 部署到槽位 0
	zone.set_formation_info_callback(_formation_info)
	zone.set_tag_color_callback(_tag_color)
	zone.apply_slot(0, &"cangxuan_formation", false)
	# Then: 快照正确（阵名经回调解析为「苍玄盟阵」，阵营标签「正道」）
	var data: Array[Dictionary] = zone.get_slot_data()
	assert_eq(data[0]["template_id"], &"cangxuan_formation", "槽位 0 应部署该模板")
	assert_eq(data[0]["display_name"], "苍玄盟阵", "阵名应经 formation_info 回调解析")
	assert_eq(data[0]["tag_name"], "正道", "阵营标签应经 tag_color 回调解析")
	assert_false(data[0]["is_active"], "部署未激活（DEPLOYED_UNACTIVE）")


func test_formation_zone_apply_slot_activates_aura() -> void:
	# When: 激活槽位 0（光环开启——AC-5 颜色对应阵营）
	zone.set_formation_info_callback(_formation_info)
	zone.set_tag_color_callback(_tag_color)
	zone.apply_slot(0, &"cangxuan_formation", true)
	# Then: is_active=true + 光环色 = 阵营色（正道绿）
	var data: Array[Dictionary] = zone.get_slot_data()
	assert_true(data[0]["is_active"], "激活态 is_active 应为 true")
	assert_eq(data[0]["tag_color"], Color(0.29, 0.62, 0.43),
			"激活光环色应为阵营色（正道绿）")


func test_formation_zone_out_of_range_guard() -> void:
	# When: 越界 apply_slot（-1 与 3）——守卫安全返回（QA 缺口 #10）
	zone.apply_slot(-1, &"x", true)
	zone.apply_slot(3, &"x", true)
	# Then: 不崩溃，槽位不变
	var data: Array[Dictionary] = zone.get_slot_data()
	assert_eq(data[0]["template_id"], &"", "越界调用不应影响槽位 0")
	assert_eq(data[2]["template_id"], &"", "越界调用不应影响槽位 2")


func test_formation_zone_set_slot_active_keeps_name() -> void:
	# When: 部署激活后 deactivated（信号不携带 template_id——仅熄灭光环）
	zone.set_formation_info_callback(_formation_info)
	zone.set_tag_color_callback(_tag_color)
	zone.apply_slot(0, &"cangxuan_formation", true)
	zone.set_slot_active(0, false)
	# Then: 光环熄灭但阵名保留（与 FormationSystem DEPLOYED_UNACTIVE 语义一致）
	var data: Array[Dictionary] = zone.get_slot_data()
	assert_false(data[0]["is_active"], "deactivated 后光环熄灭")
	assert_eq(data[0]["template_id"], &"cangxuan_formation",
			"deactivated 后阵卡仍在位（不误清空为空格）")
	assert_eq(data[0]["display_name"], "苍玄盟阵", "阵名应保留")


func test_formation_zone_apply_slot_states_full_scan() -> void:
	# When: 全量重扫（get_slot_states 载荷——3 槽位 1 空 2 部署）
	zone.set_formation_info_callback(_formation_info)
	zone.set_tag_color_callback(_tag_color)
	zone.apply_slot_states([
		{"template_id": &"cangxuan_formation", "is_active": true},
		{"template_id": &"", "is_active": false},
		{"template_id": &"other_formation", "is_active": false},
	])
	# Then: 三槽位状态正确落定
	var data: Array[Dictionary] = zone.get_slot_data()
	assert_true(data[0]["is_active"], "槽位 0 激活")
	assert_eq(data[1]["template_id"], &"", "槽位 1 空")
	assert_eq(data[2]["display_name"], "other_formation",
			"槽位 2 未解析回调时阵名退化为 template_id 字面")


func test_formation_zone_missing_callback_fallback() -> void:
	# When: 无任何回调（独立可渲染——QA 缺口 #11 降级路径）
	zone.apply_slot(0, &"bare_formation", true)
	# Then: 阵名退化为 template_id 字面 + 光环退化为默认淡金
	var data: Array[Dictionary] = zone.get_slot_data()
	assert_eq(data[0]["display_name"], "bare_formation", "无回调时阵名退化为字面")
	assert_eq(data[0]["tag_color"], zone.DEFAULT_AURA_COLOR, "无回调时光环退化为默认色")
