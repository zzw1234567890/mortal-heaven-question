extends GutTest
## 战斗弹窗正文的「我方出战人数上限」——与真实境界配置同源。[br]
## [br][b]为什么单独一处[/b]：[code]test_node_interaction_rules.gd[/code] 已锁定
## 「敌人名称 + 数量 + 境界 + 推荐上场角色」四要素与正文行数契约；本文件只补本轮
## 新增的第 5 个信息——上限本身（[code]recommend_line[/code] 的后缀），并锁死
## 「上限与推荐数读同一个数」这条不变量（上限是推荐数的夹取上界）。[br]
## [br][b]覆盖[/b]：[br]
##   · 上限 >0 时正文带「（我方出战上限 N）」，N 就是传入的 max_deploy；[br]
##   · 上限 ≤0（RealmSystem 与快照都缺）时不臆造数字——退化为只报推荐数；[br]
##   · 推荐数恒 ≤ 上限（配置显式值同样被夹取）——上限与推荐数不得自相矛盾。[br]
## [br]来源: design/gdd/exploration-ui-system.md §4 线框（推荐战力：至少 N 人）/
## §5 Boss 战前确认、exploration-ui Story 006（AC-2）、B3 裁决（角色数版本）。

const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
const Preview := preload("res://src/ui/exploration/node_combat_preview_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 上限行（新增的第 5 个信息）
# ═══════════════════════════════════════════════════════════════════════════════

func test_recommend_line_reports_deploy_cap() -> void:
	var line: String = Rules.combat_lines([{"name": "散修", "realm": 1}], 3)[2]
	assert_true(line.contains("推荐上场角色"), "仍以推荐上场角色开头")
	assert_true(line.contains("我方出战上限 3"), "正文应报出我方出战上限（真实值）")


func test_recommend_line_omits_cap_when_unknown() -> void:
	# 上限未初始化（RealmSystem 缺 + 快照无 realm_id）→ 不臆造数字
	var line: String = Rules.combat_lines([{"name": "散修", "realm": 1}], 0)[2]
	assert_true(line.contains("推荐上场角色"), "推荐提示仍在")
	assert_false(line.contains("上限"), "上限未知时不得显示任何上限数字")


func test_cap_tracks_max_deploy_reading() -> void:
	# 上限是「读到的值」而不是常量——换境界换数字
	var low: String = Rules.combat_lines([{"name": "敌"}], 2)[1]
	var high: String = Rules.combat_lines([{"name": "敌"}], 6)[1]
	assert_true(low.contains("上限 2"), "炼气期上限应为查询到的 2")
	assert_true(high.contains("上限 6"), "化神期上限应为查询到的 6")


# ═══════════════════════════════════════════════════════════════════════════════
# 上限与推荐数的一致性（不得自相矛盾）
# ═══════════════════════════════════════════════════════════════════════════════

func test_recommended_never_exceeds_reported_cap() -> void:
	for max_deploy: int in [1, 2, 3, 4, 6]:
		for enemy_count: int in [0, 1, 3, 9]:
			var recommended: int = Rules.recommended_deploy(enemy_count, max_deploy)
			assert_true(recommended <= max_deploy,
					"敌人 %d / 上限 %d 时推荐数 %d 不得超过上限"
					% [enemy_count, max_deploy, recommended])


func test_override_is_clamped_by_reported_cap() -> void:
	# 地图配置给了 9，上限是 3 → 正文里既报上限 3，推荐数也必须是 3（不外泄矛盾值）
	# （带 realm 的名册让正文为三行：[敌人行, 境界行, 推荐行]）
	var line: String = Rules.combat_lines([{"name": "敌", "realm": 1}], 3, 9)[2]
	assert_true(line.contains("≥3"), "配置超限时应夹到上限（不显示 ≥9）")
	assert_true(line.contains("我方出战上限 3"), "上限如实报 3")


# ═══════════════════════════════════════════════════════════════════════════════
# 遭遇配置驱动（正文读的是节点遭遇，不是硬编码）
# ═══════════════════════════════════════════════════════════════════════════════

func test_lines_follow_encounter_level_and_template_count() -> void:
	# 名册为空时数量退化为遭遇里的模板数，境界取遭遇定档
	var encounter: Dictionary = {
		"display_name": "山道巡守", "enemy_template_ids": ["san_xiu", "san_xiu"],
		"enemy_level": 3,
	}
	var lines: Array = Rules.combat_lines_for_encounter(encounter, [], 4)
	assert_true(str(lines[0]).contains("×2"), "数量取遭遇的模板数")
	assert_true(str(lines[1]).contains("金丹期"), "境界取遭遇定档（3 = 金丹）")
	assert_true(str(lines[2]).contains("我方出战上限 4"), "上限取传入的上限")


func test_preview_line_does_not_duplicate_count_marker() -> void:
	# 展示名自带「×N」时正文不得出现「散修 ×2 ×2」
	var encounter: Dictionary = {"display_name": "散修 ×2", "enemy_template_ids": []}
	var lines: Array = Rules.combat_lines_for_encounter(encounter, [{"name": "散修"}], 2)
	assert_true(str(lines[0]).contains("×1"), "数量取名册长度")
	assert_false(str(lines[0]).contains("×2"), "展示名里的数量标记应被去掉")


func test_recommend_line_is_single_source_for_suffix() -> void:
	# 文案只在一处拼装——直接调 recommend_line 与经 lines_for_encounter 得同一串
	var direct: String = Preview.recommend_line(2, 5)
	var via_lines: String = Rules.combat_lines_for_encounter({}, [{"name": "a"}, {"name": "b"}], 5)[1]
	assert_eq(direct, via_lines, "推荐行文案应只有一处实现")
