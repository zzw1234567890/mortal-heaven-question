extends GutTest
## 难度系数表验收：同境界 / 越级 / 压级三档取值 + 档位轴的单调性与单轴语义。[br]
## [br][b]本文件补的缺口[/b]：地图的 [code]enemy_realm[/code] 此前对战斗数值零影响
## （[code]create_enemy_roster[/code] 只吃玩家境界），「炼气玩家打归墟」与
## 「炼气玩家打青云剑宗」面对同样强度的散修。[br]
## [br][b]两个层次[/b]：[br]
##   1. [b]纯函数层[/b]：档位键 / 系数 / 取整夹取（不碰 Autoload，失败点最直白）；[br]
##   2. [b]工厂层[/b]：真实 [code]AISystem.create_enemy_roster[/code] 传
##      [code]map_realm[/code] 后实例属性取值。[br]
## [br][b]端到端层不在这里[/b]：真实战斗场景的回合数断言在
## [code]tests/integration/combat_ui/test_difficulty_curve_battle_tempo.gd[/code]
## （单元测试不挂场景；把它并进来会让本文件同时依赖 Autoload 与场景树，
## 失败点从「系数错了」变成「哪一层错了」）。[br]
## [br][b]系数一律从 [code]DifficultyCurve[/code] 读[/b]（测试不自己抄一份表）：
## 改表即改断言口径，不会出现「测试与实现对不上但都自洽」的漂移。[br]
## [br]本文件独占角色段：卡实例 ID 由 CardSystem 分配，不手写。

const CurveScript := preload("res://assets/enemies/difficulty_curve.gd")
const AI_SCRIPT := preload("res://src/feature/ai_system.gd")
const EnemyTemplate := preload("res://assets/enemies/enemy_template.gd")
const BehaviorProfile := preload("res://assets/enemies/behavior_profile.gd")
const SkillEntry := preload("res://assets/enemies/skill_entry.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 首图（唯一「炼气玩家一进游戏就能进」的地图）——校验它的境界档与池配比。
const FIRST_MAP: StringName = &"qing_yun_jian_zong"
## 散修出厂基准：HP 16 / ATK 2 / DEF 0（[code]assets/enemies/san_xiu.tres[/code]）。
const SAN_XIU_HP: int = 16
const SAN_XIU_ATK: int = 2

## 独立 AISystem 实例（不污染 Autoload——本文件只验工厂层取值）。
var ai: Node = null


func before_each() -> void:
	ai = AI_SCRIPT.new()


func after_each() -> void:
	if ai != null:
		ai.free()
		ai = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 档位轴（纯函数）——地图境界档 − 玩家境界
# ═══════════════════════════════════════════════════════════════════════════════

func test_tier_key_is_map_realm_minus_player_realm() -> void:
	# 地图境界 1..5 对玩家境界 3：档位 = 地图 − 玩家
	assert_eq(CurveScript.tier_key_of(1, 3), -2, "低两档 → 碾压键 -2")
	assert_eq(CurveScript.tier_key_of(2, 3), -1, "低一档 → 轻松键 -1")
	assert_eq(CurveScript.tier_key_of(3, 3), 0, "同档 → 均势键 0")
	assert_eq(CurveScript.tier_key_of(4, 3), 1, "高一档 → 吃力键 1")
	assert_eq(CurveScript.tier_key_of(5, 3), 2, "高两档 → 苦战键 2")


func test_tier_key_clamps_beyond_two_gaps() -> void:
	assert_eq(CurveScript.tier_key_of(5, 1), CurveScript.TIER_MAX_GAP,
			"差 4 档夹到上界（继续放大只会让越级变成必败）")
	assert_eq(CurveScript.tier_key_of(1, 5), CurveScript.TIER_MIN_GAP,
			"差 -4 档夹到下界（继续缩小只会让压级变成无收益）")


func test_tier_key_defaults_to_even_when_map_realm_unknown() -> void:
	# 渡劫 / 无探索上下文的开战路径没有地图档——不臆造难度
	assert_eq(CurveScript.tier_key_of(0, 3), 0, "map_realm=0（未定档）→ 均势")
	assert_eq(CurveScript.tier_key_of(-1, 3), 0, "负值同样按未定档处理")
	assert_eq(CurveScript.tier_key_of(3, 0), 0, "玩家境界缺省 → 均势")


func test_tier_label_matches_the_gap_direction() -> void:
	# 中文档位名是全库唯一词表——调试面板 / 战报 / 断言共用
	assert_eq(CurveScript.tier_label_of(5, 3), "苦战", "玩家落后两档 → 苦战")
	assert_eq(CurveScript.tier_label_of(4, 3), "吃力", "玩家落后一档 → 吃力")
	assert_eq(CurveScript.tier_label_of(3, 3), "均势", "同档 → 均势")
	assert_eq(CurveScript.tier_label_of(2, 3), "轻松", "玩家压制一档 → 轻松")
	assert_eq(CurveScript.tier_label_of(1, 3), "碾压", "玩家压制两档 → 碾压")


func test_multipliers_follow_the_tier_axis_when_map_realm_is_known() -> void:
	# 有地图档 → 只走档位轴：追赶已含在 gap 里（玩家练得越高 gap 越负）
	var mult: Dictionary = CurveScript.multipliers_of(1, 2, 4)
	var tier: Dictionary = CurveScript.tier_of(4, 2)
	assert_almost_eq(float(mult["hp"]), float(tier["hp"]), 0.0001,
			"HP 乘数 = 档位系数（不另乘追赶）")
	assert_almost_eq(float(mult["atk"]), float(tier["atk"]), 0.0001,
			"ATK 乘数 = 档位系数（不另乘追赶）")
	assert_eq(int(mult["gap"]), 2, "档位键随乘数一并返回")
	assert_gt(CurveScript.catch_up_of(1, 2), 1.0,
			"前置：模板境界 1 对玩家 2 本会产生追赶——有地图档时它被取代而非叠加")


func test_multipliers_follow_the_catch_up_axis_when_map_realm_is_unknown() -> void:
	# 未定档（渡劫 / 无探索上下文）→ 只走追赶轴，档位系数 1.0
	var mult: Dictionary = CurveScript.multipliers_of(1, 3, 0)
	var catch_up: float = CurveScript.catch_up_of(1, 3)
	assert_almost_eq(float(mult["hp"]), catch_up, 0.0001, "HP 乘数 = 追赶系数")
	assert_almost_eq(float(mult["atk"]), catch_up, 0.0001, "ATK 乘数 = 追赶系数")
	assert_eq(int(mult["gap"]), 0, "未定档时档位键为 0（均势）")


func test_catch_up_does_not_stack_on_top_of_the_tier_axis() -> void:
	# 防重复计算：元婴玩家进元婴图（gap=0）应恰好是模板原值。
	# 若两轴都乘，这里会变成 模板 × 追赶(1.6) —— 即「玩家越接近这张图的境界，
	# 敌人被堆得越厚」，与「追平后 3~5 回合能赢」正好相反。
	_inject_templates([_san_xiu_like(&"e_no_stack")])
	var state: Variant = _roster_after_scaling(&"e_no_stack", 4, 4)
	assert_eq(int(state.max_hp), SAN_XIU_HP, "gap=0 → 恰好模板原值（追赶不额外叠加）")
	assert_eq(int(state.attack), SAN_XIU_ATK, "ATK 同样不额外叠加")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 敌方属性取值——同境界 / 越级 / 压级（真实工厂，真实模板数值）
# ═══════════════════════════════════════════════════════════════════════════════

func test_enemy_stats_same_realm_equal_template_base() -> void:
	# 同境界（模板境界 = 玩家境界 = 地图档 1）→ 两条轴系数都是 1.0 → 取值 = 模板原值
	# [b]这是基线锚点[/b]：出厂端到端用例按模板原值断言首图敌人 HP，改这个锚点会
	# 连带让「追平后 3~5 回合」失去参照。
	_inject_templates([_san_xiu_like(&"e_same")])
	var state: Variant = _roster_after_scaling(&"e_same", 1, 1)
	assert_eq(int(state.max_hp), SAN_XIU_HP, "同境界 HP = 模板原值（基线锚点）")
	assert_eq(int(state.attack), SAN_XIU_ATK, "同境界 ATK = 模板原值")


func test_enemy_stats_when_player_behind_are_higher() -> void:
	# 越级：玩家炼气(1) 打筑基档地图(2) → 档位 gap=+1「吃力」
	# [b]卡住玩家境界、只抬高地图档[/b]——只动一条轴才能断言是这条轴起的作用。
	_inject_templates([_san_xiu_like(&"e_behind")])
	var even: Variant = _roster_after_scaling(&"e_behind", 1, 1)
	var behind: Variant = _roster_after_scaling(&"e_behind", 1, 2)
	var tier: Dictionary = CurveScript.tier_of(2, 1)
	assert_eq(CurveScript.tier_label_of(2, 1), "吃力", "前置：该组合落在吃力档")
	assert_eq(int(behind.max_hp), _expected(SAN_XIU_HP, 1.0, float(tier["hp"])),
			"落后一档 HP 按吃力档上调（×%.2f）" % float(tier["hp"]))
	assert_eq(int(behind.attack), _expected(SAN_XIU_ATK, 1.0, float(tier["atk"])),
			"落后一档 ATK 按吃力档上调（×%.2f）" % float(tier["atk"]))
	assert_gt(int(behind.max_hp), int(even.max_hp), "落后时更硬——不是与均势档同值")


func test_enemy_stats_when_player_behind_two_tiers_are_higher_still() -> void:
	# 越级两档「苦战」——档位更高的地图还要更硬（档位轴单调）
	_inject_templates([_san_xiu_like(&"e_hard")])
	var one: Variant = _roster_after_scaling(&"e_hard", 1, 2)
	var two: Variant = _roster_after_scaling(&"e_hard", 1, 3)
	assert_eq(CurveScript.tier_label_of(3, 1), "苦战", "前置：该组合落在苦战档")
	assert_gt(int(two.max_hp), int(one.max_hp), "落后两档比落后一档更硬")
	# ATK 只断言「不下降」：基准 ATK 只有 2，×1.25 与 ×1.5 都四舍五入到 3——
	# 用严格大于会把「取整把差异吃掉」误判成实现错。
	assert_gte(int(two.attack), int(one.attack), "ATK 随档位不下降（取整可能吃掉小基准的差）")


func test_enemy_stats_when_player_ahead_are_lower() -> void:
	# 压级：玩家金丹(3) 回炼气档地图(1) → 档位 gap=-2「碾压」
	# [b]卡住玩家境界、只压低地图档[/b]：追赶轴在这个对比里两边相同，差异全部来自
	# 档位轴——这正是「同境界玩家进不同境界地图，敌人强度不同」的直接证据。
	_inject_templates([_san_xiu_like(&"e_ahead")])
	var even: Variant = _roster_after_scaling(&"e_ahead", 3, 3)
	var ahead: Variant = _roster_after_scaling(&"e_ahead", 3, 1)
	var tier: Dictionary = CurveScript.tier_of(1, 3)
	assert_eq(CurveScript.tier_label_of(1, 3), "碾压", "前置：该组合落在碾压档")
	assert_eq(int(ahead.max_hp), _expected(SAN_XIU_HP, 1.0, float(tier["hp"])),
			"压级两档 HP 按碾压档下调（档位 ×%.2f）" % float(tier["hp"]))
	assert_lt(int(ahead.max_hp), int(even.max_hp), "压级时更软——不是与均势档同值")
	assert_lt(float(tier["atk"]), 1.0, "碾压档的 ATK 系数本身小于 1（敌人打得更轻）")


func test_enemy_hp_never_falls_below_floor() -> void:
	# 压级到极限也不产出 0 血敌人（那会让战斗永不结束）
	_inject_templates([_san_xiu_like(&"e_floor")])
	var state: Variant = _roster_after_scaling(&"e_floor", 5, 1)
	assert_gte(int(state.max_hp), CurveScript.MIN_ENEMY_HP, "HP 夹到下限以上")


func test_tiny_base_stats_are_not_scaled_to_zero() -> void:
	# 基准 ATK = 1 的敌人压级两档：1 × 系数 会被四舍五入抹成 0——
	# 夹取必须把它救回 1，否则这类敌人变成「打不动的摆设」。
	_inject_templates([_weakling(&"e_tiny")])
	var state: Variant = _roster_after_scaling(&"e_tiny", 1, 1)
	assert_eq(int(state.max_hp), 1, "HP 1 的敌人压不掉（夹到下限）")
	assert_eq(int(state.attack), 1, "ATK 1 的敌人压不掉（夹到下限）")


func test_higher_map_tier_makes_enemies_harder_at_the_same_player_realm() -> void:
	# 同一位玩家（炼气）进越来越高的地图档：敌人逐个变硬——档位轴单调。
	# [b]这条就是本轮修复的用户可见面[/b]：改造前地图档对战斗数值零影响，
	# 这里三个阶段会取到同一个值。
	_inject_templates([_san_xiu_like(&"e_ladder")])
	var at_first: Variant = _roster_after_scaling(&"e_ladder", 1, 1)
	var at_second: Variant = _roster_after_scaling(&"e_ladder", 1, 2)
	var at_third: Variant = _roster_after_scaling(&"e_ladder", 1, 3)
	assert_lt(int(at_first.max_hp), int(at_second.max_hp), "地图档越高敌人越硬（1 → 2）")
	assert_lt(int(at_second.max_hp), int(at_third.max_hp), "地图档越高敌人越硬（2 → 3）")


func test_unknown_map_realm_still_follows_the_catch_up_axis() -> void:
	# 未定档（渡劫 / 无探索上下文）时追赶轴接管——玩家练高了敌人仍跟着长
	_inject_templates([_san_xiu_like(&"e_catchup")])
	var at_one: Variant = _roster_after_scaling(&"e_catchup", 1, 0)
	var at_three: Variant = _roster_after_scaling(&"e_catchup", 3, 0)
	assert_gt(int(at_three.max_hp), int(at_one.max_hp),
			"未定档时追赶轴生效（玩家 3 > 玩家 1）")
	assert_eq(int(at_three.max_hp),
			_expected(SAN_XIU_HP, CurveScript.catch_up_of(1, 3), 1.0),
			"取值恰为 模板 × 追赶（档位轴不参与）")


func test_map_realm_default_keeps_legacy_two_arg_behavior() -> void:
	# 不传地图档（渡劫 / 无探索上下文）→ 与改造前的两参调用逐位一致
	_inject_templates([_san_xiu_like(&"e_legacy")])
	var legacy: Array = ai.call("create_enemy_roster", [&"e_legacy"], 2)
	var explicit: Array = ai.call("create_enemy_roster", [&"e_legacy"], 2, 0)
	assert_eq(int(legacy[0].max_hp), int(explicit[0].max_hp), "缺省 map_realm 等价于传 0")
	assert_eq(int(legacy[0].attack), int(explicit[0].attack), "ATK 同样等价")


func test_first_map_tier_is_even_for_a_realm_one_player() -> void:
	# 首图（青云剑宗 enemy_realm = 1）对炼气玩家 → 均势档，系数 1.0
	var map_realm: int = CatalogScript.enemy_realm_of(FIRST_MAP, 1)
	assert_eq(map_realm, 1, "前置：首图敌人基准境界为 1")
	assert_eq(CurveScript.tier_key_of(map_realm, 1), 0, "炼气玩家打首图 → 均势（不额外加压）")
	assert_eq(CurveScript.tier_label_of(map_realm, 1), "均势", "首图是基线锚点")


func test_low_realm_map_is_softer_for_an_overleveled_player() -> void:
	# 高境界玩家回首图：gap 为负 → 敌人比模板原值更软——「碾压的回味」有数值落点。
	# 但不会是 0：系数下限 + 属性夹取保证敌人仍站得住（详见夹下限用例）。
	var mult: Dictionary = CurveScript.multipliers_of(1, 4, 1)
	assert_lt(float(mult["hp"]), 1.0, "低境界图对高境界玩家更软（HP 系数 < 1）")
	assert_gte(float(mult["hp"]), float(CurveScript.TIER_TABLE[CurveScript.TIER_MIN_GAP]["hp"]),
			"但仍受档位表下界约束——不会软到无收益")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 走真实工厂生成名册并取首个实例。[br]
## [br][param p_template_id] 已注入注册表的模板 ID。[br]
## [param p_player_realm] 玩家境界（追赶轴）。[br]
## [param p_map_realm] 地图敌人基准境界档（档位轴）。[br]
## [br][b]为什么单独包一层[/b]：本文件全部工厂层用例都只关心「首个实例的属性」，
## 包一层让每个用例只剩「哪个模板 + 哪两个境界」三件事。
func _roster_after_scaling(p_template_id: StringName, p_player_realm: int,
		p_map_realm: int) -> Variant:
	var roster: Array = ai.call("create_enemy_roster", [p_template_id],
			p_player_realm, p_map_realm)
	assert_eq(roster.size(), 1, "前置：名册应产出 1 个实例")
	return roster[0] if not roster.is_empty() else null


## 期望取值——与 [code]DifficultyCurve.apply[/code] 同一算式（取整口径一致）。[br]
## [br][b]为什么不直接读表断死数字[/b]：系数一旦调整（本轮之后必然还会调），
## 写死数字的断言会连带失效、而算式口径没变——改用「同算式 + 同系数」后，
## 用例只锁「哪条轴在起作用 + 取整夹取」这件事，调系数不会误红。[br]
## [br][b]两个乘数由调用方给[/b]：给了地图档的对比传 [code]1.0[/code] 作追赶
## （档位轴取代追赶轴），未定档的对比才传真实追赶系数——传错就等于在测试里
## 复述实现，两轴是否叠加这件事反而测不出来。
func _expected(p_base: int, p_catch_up: float, p_tier_mult: float) -> int:
	return roundi(float(p_base) * p_catch_up * p_tier_mult)


## 造一个与出厂散修同基准的模板（境界 1 / HP 16 / ATK 2 / DEF 0）。[br]
## [br][b]为什么复制散修数值而不是 new 一个空白模板[/b]：空白模板的 HP/ATK 为 0，
## 在 0 上乘任何系数都得 0，三种档位看不出差别——用例会「全绿但什么都没验」。
func _san_xiu_like(p_id: StringName) -> Object:
	var template: Object = EnemyTemplate.new()
	template.template_id = p_id
	template.display_name = str(p_id)
	template.realm = 1
	template.is_elite = false
	template.is_boss = false
	template.base_hp = SAN_XIU_HP
	template.base_attack = SAN_XIU_ATK
	template.base_defense = 0
	template.formation_limit = 0
	template.front_slot = false
	template.behavior_profile = _behavior_profile()
	template.skill_pool = [_skill()]
	return template


## 造一个基准极低的模板（HP 1 / ATK 1）——验夹下限。
func _weakling(p_id: StringName) -> Object:
	var template: Object = _san_xiu_like(p_id)
	template.base_hp = 1
	template.base_attack = 1
	return template


func _behavior_profile() -> Object:
	var profile: Object = BehaviorProfile.new()
	profile.aggression = 0.7
	profile.focus_fire = 0.7
	profile.front_priority = 0.5
	profile.retreat_threshold = 0.0
	return profile


func _skill() -> Object:
	var entry: Object = SkillEntry.new()
	entry.skill_id = &"basic_attack"
	entry.display_name = "基础攻击"
	entry.skill_type = SkillEntry.SkillType.ATTACK
	entry.base_weight = 100
	entry.cost = 0
	entry.cooldown = 0
	entry.target_type = SkillEntry.TargetType.SINGLE_ENEMY
	entry.power_multiplier = 1.0
	return entry


## 注入模板到注册表（绕过 load_templates 目录扫描——同既有 Story 004 用例口径）。
func _inject_templates(p_templates: Array) -> void:
	var registry: Dictionary = ai.get("_template_registry")
	registry.clear()
	for template: Variant in p_templates:
		registry[template.template_id] = template

