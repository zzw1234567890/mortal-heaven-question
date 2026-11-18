extends GutTest
## 人数轴验收：敌方人数随「地图境界档 − 玩家境界」走的三档区间 + 三层夹取。[br]
## [br][b]本文件补的缺口[/b]：上一轮把敌方 [b]属性[/b] 接上了地图境界档，但人数仍写死
## 在每张地图配置的 [code]enemy_count_min/max[/code] 里——炼气玩家打归墟与打青云剑宗
## 不仅敌人一样强，连来几个都一样（玩家境界对人数零影响）。[br]
## [br][b]两个层次[/b]：[br]
##   1. [b]纯函数层[/b]：`DifficultyCurve.count_range_of` 的三档读数与三层夹取；[br]
##   2. [b]名册层[/b]：真实 [code]ExplorationEnemyPool.make_roster[/code] 掷出的人数
##      落在纯函数给的区间里（口径只有一处——测试不自己抄一份区间）。[br]
## [br][b]区间一律从 [code]DifficultyCurve[/code] 读[/b]（不硬编码人数）：调表即调断言
## 口径，不会出现「测试与实现各说各话」。唯一写死的是本轮验收目标本身
## （首图 1 人 / 追平 2~3 / 越级 3~4），那是需求不是实现细节。[br]
## [br][b]端到端层不在这里[/b]：真实战斗的场景与回合数在
## [code]tests/integration/combat_ui/test_l4_gui_xu_tong_dao_battle.gd[/code]。
##
## 来源: GDD ai-system.md §9 难度缩放、GDD exploration-system.md §7 回旧地图、DEBT-EQT-001。

const CurveScript := preload("res://assets/enemies/difficulty_curve.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const PoolScript := preload("res://src/feature/exploration/exploration_enemy_pool.gd")
const EnemyTemplateScript := preload("res://assets/enemies/enemy_template.gd")
const RealmScript := preload("res://src/core/realm_system.gd")

## 首图（唯一「炼气玩家一进游戏就能进」的地图）。
const FIRST_MAP: StringName = &"qing_yun_jian_zong"

## 名册层用的模板桩——散修口径（HP 16 / ATK 2）。
var _templates: Dictionary = {}


func before_each() -> void:
	_templates = {&"san_xiu": _template(&"san_xiu", "散修", 1)}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 三档读数（纯函数）——越级更多、追平居中、压级更少
# ═══════════════════════════════════════════════════════════════════════════════

func test_count_range_even_gap_matches_the_table() -> void:
	# 追平（地图档 = 玩家境界）——区间取表里 gap=0 那一行，测试不另抄数字
	var span: Dictionary = CurveScript.count_range_of(3, 3)
	var row: Dictionary = CurveScript.TIER_TABLE[0]
	assert_eq(int(span["min"]), int(row["count_min"]), "追平的区间下限 = 表里 gap=0 的下限")
	assert_eq(int(span["max"]), int(row["count_max"]), "追平的区间上限 = 表里 gap=0 的上限")
	assert_eq(int(span["gap"]), 0, "档位键随区间一并返回")


func test_count_range_when_player_behind_is_larger() -> void:
	# 越级——玩家炼气(1) 打筑基档(2) / 金丹档(3)。[b]这是本轮的用户可见面[/b]：
	# 改造前这两次的敌方人数完全相同（都取地图配置里那个固定区间）。
	var one: Dictionary = CurveScript.count_range_of(2, 1)
	var two: Dictionary = CurveScript.count_range_of(3, 1)
	var even: Dictionary = CurveScript.count_range_of(1, 1)
	assert_eq(int(CurveScript.tier_key_of(2, 1)), 1, "前置：落后一档")
	assert_eq(int(CurveScript.tier_key_of(3, 1)), 2, "前置：落后两档")
	assert_gt(int(one["min"]), int(even["min"]), "落后一档比追平更多（下限）")
	assert_gt(int(two["min"]), int(one["min"]), "落后两档比落后一档更多（下限）")
	assert_gt(int(two["max"]), int(one["max"]), "落后两档比落后一档更多（上限）")


func test_count_range_when_player_ahead_is_smaller() -> void:
	# 压级——玩家金丹(3) 回炼气档(1)：敌人属性更软、人数也更少
	var ahead: Dictionary = CurveScript.count_range_of(1, 3)
	var even: Dictionary = CurveScript.count_range_of(3, 3)
	assert_eq(int(CurveScript.tier_key_of(1, 3)), CurveScript.TIER_MIN_GAP, "前置：压级两档")
	assert_lt(int(ahead["max"]), int(even["max"]), "压级时人数上限更低")
	assert_lt(int(ahead["min"]), int(even["min"]), "压级时人数下限也更低")


func test_count_range_meets_the_three_acceptance_readings() -> void:
	# 本轮验收目标本身（需求，不是实现细节）：追平 2~3、越级 3~4、压级 1~2。
	# [b]断言的是需求里那几个数字[/b]，所以它们出现在测试里是对的；
	# 而「表里到底怎么写的」由上面两条（从表读）负责。
	var even: Dictionary = CurveScript.count_range_of(3, 3)
	var behind: Dictionary = CurveScript.count_range_of(4, 3)
	var ahead: Dictionary = CurveScript.count_range_of(2, 3)
	assert_eq([int(even["min"]), int(even["max"])], [2, 3], "追平档 2~3 人")
	assert_eq([int(behind["min"]), int(behind["max"])], [3, 4], "越级档 3~4 人")
	assert_eq([int(ahead["min"]), int(ahead["max"])], [1, 2], "压级档 1~2 人")


func test_count_range_is_monotonic_in_map_realm() -> void:
	# 同一位玩家进越来越高的地图档：人数区间不下降（档位轴单调）。
	# 不设地图上限 / 出战名额，单看档位轴本身。
	var previous: int = 0
	for map_realm: int in range(1, 6):
		var span: Dictionary = CurveScript.count_range_of(map_realm, 3)
		assert_gte(int(span["min"]), previous,
				"地图档 %d 的人数下限不应低于前一档" % map_realm)
		assert_lte(int(span["min"]), int(span["max"]), "区间恒非空（min <= max）")
		previous = int(span["min"])


func test_count_range_clamps_to_hard_bounds() -> void:
	# 无任何外部约束时也不越出硬边界（[constant COUNT_MIN] ~ [constant COUNT_MAX]）
	for map_realm: int in range(1, 8):
		for player_realm: int in range(1, 8):
			var span: Dictionary = CurveScript.count_range_of(map_realm, player_realm)
			assert_gte(int(span["min"]), CurveScript.COUNT_MIN,
					"人数下限不低于硬下界（map=%d player=%d）" % [map_realm, player_realm])
			assert_lte(int(span["max"]), CurveScript.COUNT_MAX,
					"人数上限不超过硬上界（map=%d player=%d）" % [map_realm, player_realm])
			assert_lte(int(span["min"]), int(span["max"]), "区间恒非空")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 三层夹取——地图上限兜底 / 出战名额余量 / 未定档
# ═══════════════════════════════════════════════════════════════════════════════

func test_map_cap_keeps_the_first_map_at_one_enemy() -> void:
	# 首图：档位说 2~3 人，地图配置的 enemy_count_max = 1 把它压成 1~1。
	# [b]这就是「首图 L1 仍是 1 人」的落点[/b]——不是把 1 写进档位表（那是全局的），
	# 而是让地图拥有一个上限兜底。
	var config: Dictionary = CatalogScript.config_for(FIRST_MAP, 1)
	var span: Dictionary = CurveScript.count_range_of(
			int(config["enemy_realm"]), 1, int(config["enemy_count_max"]),
			RealmScript.realm_table[1]["max_deploy"])
	assert_eq([int(span["min"]), int(span["max"])], [1, 1], "首图对炼气玩家仍是 1 人")


func test_map_cap_compresses_both_ends_not_only_the_max() -> void:
	# 只压 max 会产出 min > max 的空区间；两端一起压才不会把「补一次夹取」
	# 写进掷骰处（两处口径必然漂移）。
	var span: Dictionary = CurveScript.count_range_of(3, 3, 1)
	assert_eq([int(span["min"]), int(span["max"])], [1, 1], "上限 1 的图收成 1~1")


func test_deploy_allowance_caps_the_count_at_one_over_the_player() -> void:
	# 玩家出战名额 2（炼气）→ 敌人最多 3 个；落后两档本会给出 4~5，被压到 3~3。
	var span: Dictionary = CurveScript.count_range_of(3, 1, 0, 2)
	assert_eq(int(span["max"]), 2 + CurveScript.COUNT_OVER_DEPLOY,
			"上限 = 出战名额 + 余量")
	assert_eq(int(span["min"]), 2 + CurveScript.COUNT_OVER_DEPLOY,
			"下限同样被压（区间恒非空）")


func test_deploy_allowance_only_trims_the_count_axis() -> void:
	# 出战名额宽裕（化神 6 → 上限 7，高于硬上界 5）时，档位区间原样保留。
	var span: Dictionary = CurveScript.count_range_of(3, 3, 0, 6)
	var row: Dictionary = CurveScript.TIER_TABLE[0]
	assert_eq([int(span["min"]), int(span["max"])],
			[int(row["count_min"]), int(row["count_max"])], "名额宽裕时不影响档位区间")


func test_count_range_defaults_to_even_when_the_map_tier_is_unknown() -> void:
	# 未定档（渡劫 / 无探索上下文）→ 档位键 0，与 [method tier_key_of] 同口径
	var span: Dictionary = CurveScript.count_range_of(0, 3)
	assert_eq(int(span["gap"]), 0, "未定档 → 均势键")
	assert_eq(int(span["min"]), int(CurveScript.TIER_TABLE[0]["count_min"]),
			"未定档按均势档取区间（不臆造难度）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 名册层——真实 make_roster 掷出的人数落在纯函数给的区间里
# ═══════════════════════════════════════════════════════════════════════════════

func test_pool_roster_size_follows_the_curve_not_the_map_min() -> void:
	# Arrange——地图配置里 min 写 1（首图口径），但玩家越级两档，档位表说 4~5。
	# [b]配置的 min 不再参与[/b]：若还读它，越级时人数会掉回 1。
	var config: Dictionary = {
		"enemy_pool": [{"template_id": &"san_xiu", "weight": 100}],
		"enemy_realm": 3, "enemy_count_min": 1, "enemy_count_max": 5,
	}
	var span: Dictionary = CurveScript.count_range_of(3, 1, 5,
			RealmScript.realm_table[1]["max_deploy"])
	var pool: RefCounted = PoolScript.new(_lookup)
	# Act
	var roster: Array = pool.call(&"make_roster", &"ladder_map", 1, false, config)
	# Assert——人数落在档位区间（名册条目全部可解析，故条数 = 掷出人数）
	assert_between(roster.size(), int(span["min"]), int(span["max"]),
			"敌方人数应落在难度曲线给的区间")
	assert_gt(roster.size(), int(config["enemy_count_min"]),
			"越级时人数不受地图配置的 min 拖累")


func test_pool_roster_size_is_lower_when_the_map_is_below_the_player() -> void:
	# 同一位玩家（金丹 3）进两张不同境界的地图——人数方向与属性轴一致
	var config: Dictionary = {
		"enemy_pool": [{"template_id": &"san_xiu", "weight": 100}],
		"enemy_count_max": 5,
	}
	var pool: RefCounted = PoolScript.new(_lookup)
	config["enemy_realm"] = 3
	var even: Array = pool.call(&"make_roster", &"even_map", 3, false, config)
	config["enemy_realm"] = 1
	var easy: Array = pool.call(&"make_roster", &"easy_map", 3, false, config)
	# 压级两档的区间是 1~1，恒少于均势档的 2~3
	assert_eq(easy.size(), 1, "压级两档恒为 1 人（区间收成一点）")
	assert_gt(even.size(), easy.size(), "均势档人数应多于压级档")


func test_pool_elite_bonus_never_exceeds_the_hard_ceiling() -> void:
	# 越级两档本身可掷到 5 人，精英再加就爆表——必须被硬上界挡住
	var config: Dictionary = {
		"enemy_pool": [{"template_id": &"san_xiu", "weight": 100}],
		"enemy_realm": 5, "enemy_count_max": 0, "elite_bonus": 3,
	}
	var pool: RefCounted = PoolScript.new(_lookup)
	# Act
	var elite: Array = pool.call(&"make_roster", &"hard_map", 3, true, config)
	# Assert
	assert_lte(elite.size(), CurveScript.COUNT_MAX,
			"精英加成后仍不超过硬上界 %d 人" % CurveScript.COUNT_MAX)
	assert_gt(elite.size(), 0, "前置：仍应产出非空名册（不是被夹成 0）")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 模板查询桩（缺失 ID 返回 null）。
func _lookup(p_template_id: StringName) -> Variant:
	return _templates.get(p_template_id)


## 造一个最小 EnemyTemplate（名册层只读模板的显示名与境界）。
func _template(p_id: StringName, p_name: String, p_realm: int) -> Resource:
	var template: Resource = EnemyTemplateScript.new()
	template.template_id = p_id
	template.display_name = p_name
	template.realm = p_realm
	return template
