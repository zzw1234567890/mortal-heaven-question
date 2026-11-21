extends GutTest
## TribulationRealmRules 单元测试 —— 「哪一境界的进阶要走渡劫」的配置单点。[br]
## [br][b]为什么单测这一层[/b]：本模块不碰控件、不读 GSM，只有「给一个境界，得到一个
## 布尔」——正是最容易悄悄漂移的地方（漏配一行、把例外翻进主表、越界算出看似合理的
## Boss 境界）。集成测试只走常见路径，边界在这里逐条钉。[br]
## [br][b]断言的是「与 GDD 一致」而不是「等于某个字面量」[/b]：五个境界的要求直接对着
## GDD §7「一局最多 4 次渡劫（炼气→筑基→金丹→元婴→化神）」核——四次渡劫对应四行
## true，最高境界那行 false。谁把哪一行改了，这里先红。[br]
## [br][b]与境界表的档位交叉钉[/b]：[method REALM_COUNT] 是独立存的数（本模块读不到
## RealmSystem），故必须验它与真境界表同档位——两张表档位不一致会让「到顶」判错。
##
## 来源: design/gdd/tribulation-system.md §1/§6/§7 + §「唯一例外」、
## design/gdd/story-system.md §第2章·苍玄古战场、先例
## [code]test_realm_table_query.gd[/code]（配置表的逐项断言）。

const RulesScript := preload("res://src/feature/tribulation/tribulation_realm_rules.gd")
## 真境界表（交叉校验档位用——本模块不读它，测试替它读一次）。
const RealmScript := preload("res://src/core/realm_system.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 逐境界配置 —— 与 GDD §7 一致
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_realm_row_is_configured() -> void:
	# Act + Assert——五行全部显式配过（缺一行即数据缺口，界面会拒绝突破）
	for realm: int in range(1, RulesScript.REALM_COUNT + 1):
		assert_true(RulesScript.is_configured(realm),
				"境界 %d 的渡劫规则必须显式配置（缺键 = 未配置）" % realm)


func test_realm_count_matches_real_realm_table() -> void:
	# Act + Assert——本模块独立存的档位数必须与真境界表一致
	# （不一致会让 at_max_realm 判错：多算一级则到顶时仍以为能渡劫）
	assert_eq(RulesScript.REALM_COUNT, RealmScript.realm_table.size(),
			"REALM_COUNT 应与 RealmSystem.realm_table 的档位数相同")


func test_realms_one_to_four_require_tribulation() -> void:
	# GDD §7：一局最多 4 次渡劫 = 炼气→筑基→金丹→元婴→化神 各一次
	for realm: int in range(1, 5):
		assert_true(RulesScript.requires_tribulation(realm),
				"境界 %d 的进阶应需要渡劫（GDD §7 四次渡劫之一）" % realm)


func test_top_realm_does_not_require_tribulation() -> void:
	# 化神是最高境界——没有更高处可去，不存在「进阶」这件事
	assert_false(RulesScript.requires_tribulation(RulesScript.REALM_COUNT),
			"最高境界不应需要渡劫（无更高境界可去）")


func test_exactly_four_realms_require_tribulation() -> void:
	# Act——数一遍真配置里 true 的行数
	var count: int = 0
	for realm: int in range(1, RulesScript.REALM_COUNT + 1):
		if RulesScript.requires_tribulation(realm):
			count += 1
	# Assert——恰好 4（GDD §7「最多可完成 4 次渡劫」）
	assert_eq(count, 4, "需要渡劫的境界应恰好 4 个（GDD §7 一局最多 4 次渡劫）")


func test_every_row_carries_a_note() -> void:
	# Act + Assert——每行都留了「为什么这么配」，避免后来者只能靠猜
	for realm: int in range(1, RulesScript.REALM_COUNT + 1):
		assert_false(RulesScript.note_for(realm).strip_edges().is_empty(),
				"境界 %d 的行应带一句配置说明" % realm)


# ═══════════════════════════════════════════════════════════════════════════════
# 缺键 / 未配置 —— 不得静默当成「要渡劫」
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_realm_is_not_configured() -> void:
	# Act + Assert——表外的等级（0 / 越界 / 负数）都算未配置
	assert_false(RulesScript.is_configured(0), "境界 0 不应算已配置")
	assert_false(RulesScript.is_configured(RulesScript.REALM_COUNT + 1),
			"越界等级不应算已配置")
	assert_false(RulesScript.is_configured(-1), "负等级不应算已配置")


func test_missing_key_is_not_configured_and_does_not_require_tribulation() -> void:
	# Arrange——把真表某一行复制出来但抽掉那一个键（模拟「加了行忘了配值」）
	var table: Dictionary = RulesScript.TABLE.duplicate(true)
	(table[1] as Dictionary).erase(RulesScript.KEY_REQUIRES_TRIBULATION)
	# Act + Assert——必须先被判为未配置；且 requires 不得默认为 true
	# （旧口径「缺键 = 要渡劫」会把数据缺口伪装成「这一境界也要渡劫」）
	assert_true(table.has(1), "前置：这一行还在表里（只是缺键）")
	assert_false(_configured_with(table, 1), "行内缺键应判未配置")
	assert_false(_requires_with(table, 1),
			"未配置时不得默认为「要渡劫」——那是把缺口伪装成规则")


func test_missing_key_on_any_realm_is_detected() -> void:
	# Arrange + Act + Assert——逐个境界抽掉键，每一行都必须可被检出
	for realm: int in range(1, RulesScript.REALM_COUNT + 1):
		var table: Dictionary = RulesScript.TABLE.duplicate(true)
		(table[realm] as Dictionary).erase(RulesScript.KEY_REQUIRES_TRIBULATION)
		assert_false(_configured_with(table, realm),
				"境界 %d 缺键时应判未配置（漏配必须看得出）" % realm)


# ═══════════════════════════════════════════════════════════════════════════════
# 越阶渡劫（GDD §6）—— 不跳阶、到顶不可越
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_realm_available_below_top_realm() -> void:
	# Act + Assert——炼气~元婴各自都能往上挑一级（+1 仍在表内）
	for realm: int in range(1, RulesScript.REALM_COUNT):
		assert_true(RulesScript.can_cross_realm(realm),
				"境界 %d 应可越阶（+1 仍在境界表内）" % realm)


func test_cross_realm_not_available_at_top_realm() -> void:
	assert_false(RulesScript.can_cross_realm(RulesScript.REALM_COUNT),
			"最高境界无处可越（+1 超出境界表）")


func test_cross_realm_boss_is_exactly_one_realm_above() -> void:
	# Act + Assert——GDD §6「不能跳阶」：越阶 Boss 恒为 +1，绝不是 +2
	for realm: int in range(1, RulesScript.REALM_COUNT):
		assert_eq(RulesScript.cross_realm_boss_realm(realm), realm + 1,
				"境界 %d 的越阶应挑战 %d 的天劫（不得跳阶）" % [realm, realm + 1])


func test_cross_realm_boss_is_zero_when_not_available() -> void:
	# Assert——不可越阶时不给出境界值（给 0 让「忘了先判」一眼看得出，
	# 而不是拿一个看似合理的境界去打 Boss）
	assert_eq(RulesScript.cross_realm_boss_realm(RulesScript.REALM_COUNT), 0,
			"不可越阶时 Boss 境界应为 0")
	assert_eq(RulesScript.cross_realm_boss_realm(0), 0, "表外等级同样给 0")


func test_cross_realm_span_is_one() -> void:
	# 跨度常量是「挑战哪个雷灵」的唯一算式来源——改了它上面两条会一起红
	assert_eq(RulesScript.CROSS_REALM_SPAN, 1,
			"越阶跨度应为 1（GDD §6 不能跳阶）")


# ═══════════════════════════════════════════════════════════════════════════════
# 到顶判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_at_max_realm_only_at_or_above_count() -> void:
	for realm: int in range(1, RulesScript.REALM_COUNT):
		assert_false(RulesScript.at_max_realm(realm), "境界 %d 不是最高境界" % realm)
	assert_true(RulesScript.at_max_realm(RulesScript.REALM_COUNT),
			"境界 %d 应是最高境界" % RulesScript.REALM_COUNT)
	assert_true(RulesScript.at_max_realm(RulesScript.REALM_COUNT + 1),
			"越界等级按到顶处理（不臆造更高境界）")


# ═══════════════════════════════════════════════════════════════════════════════
# 唯一例外（GDD §7 的⚠——剧情专属提升）
# ═══════════════════════════════════════════════════════════════════════════════

func test_story_bypass_is_registered_for_realm_two() -> void:
	# 第 2 章苍玄古战场跌落后「重新筑基」——目标境界为 2
	assert_true(RulesScript.is_story_bypass(2),
			"重新筑基（升回筑基期）应登记为不经渡劫的例外")
	assert_false(RulesScript.story_bypass_reason(2).strip_edges().is_empty(),
			"例外条目应带一句说明（供剧情系统自证其合法性）")


func test_story_bypass_does_not_turn_off_normal_tribulation() -> void:
	# Act + Assert——例外是「谁在调用」的差别，不是「境界 1/2 的规则」
	# （若把它翻成 requires_tribulation=false，GDD §7 的「最多 4 次」就少了一次）
	assert_true(RulesScript.requires_tribulation(1),
			"常规的炼气→筑基仍须渡劫（剧情例外不得污染该境界的规则）")
	assert_true(RulesScript.requires_tribulation(2),
			"常规的筑基→金丹仍须渡劫")


func test_story_bypass_absent_for_other_realms() -> void:
	for realm: int in range(1, RulesScript.REALM_COUNT + 1):
		if realm == 2:
			continue
		assert_false(RulesScript.is_story_bypass(realm),
				"境界 %d 不应有剧情例外（GDD §7：全游戏唯一一次）" % realm)
		assert_eq(RulesScript.story_bypass_reason(realm), "",
				"不存在的例外应给空串（不臆造理由）")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：把真规则表做副本注入判定层（只翻一处，其余全走真配置）
# ═══════════════════════════════════════════════════════════════════════════════

## 判定层实例（注入覆盖表——本文件验的是数据缺口的可观测行为，
## 真配置里每一行都配齐了，不注入就构造不出「缺键」这一形态）。
const GateScript := preload("res://src/ui/cultivation/cultivation_tribulation_gate.gd")


func _configured_with(p_table: Dictionary, p_realm: int) -> bool:
	return bool(GateScript.new(p_table).call(&"is_configured", p_realm))


func _requires_with(p_table: Dictionary, p_realm: int) -> bool:
	return bool(GateScript.new(p_table).call(&"requires_tribulation", p_realm))
