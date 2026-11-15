extends GutTest
## 地图解锁门槛与「一路开得下去」的完整性测试。[br]
## [br][b]本轮补的断链[/b]：解锁判定此前只是 [code]ExplorationMapList[/code] 里的
## 一行 [code]player_realm >= unlock_realm[/code]——[br]
##   1. GDD §8 的[b]序列锁[/b]（「青云剑宗 → 血渊秘境 → 云澜城 → 丹霞谷」、
##      「苍玄古战场 → 碎星外环」）在探明表里根本没有字段可写，代码里也就无从判定；[br]
##   2. 文案只有数字（「需3境界」），玩家读不出「筑基期」也读不出「要通关哪张图」；[br]
##   3. 判定散在三处（列表 / 卡片 / 点击），加一条条件要改三处。[br]
## 本文件锁住第 1、2 条的求值结果（判定与文案都在
## [code]exploration_map_gate.gd[/code]），并对[b]全表[/b]做「不存在永远开不了的图」
## 的防回归断言。[br]
## [br][b]纯函数直调[/b]：不实例化系统、不读 GSM——已通关集合由用例自己造
## （先例 [code]test_exploration_ap_rules.gd[/code] 直调规则模块）。[br]
##
## 来源: design/gdd/exploration-system.md §1/§8/§公式 1、
## design/gdd/exploration-ui-system.md §1、ADR-0014 §get_map_list 契约。

const GATE := preload("res://src/feature/exploration/exploration_map_gate.gd")
const CATALOG := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 开局可进的图（GDD §8「初始状态仅解锁青云剑宗」）。
const START_MAP: StringName = &"qing_yun_jian_zong"
## 炼气期四图的推进链（GDD §8 顺序锁）。
const LIANQI_CHAIN: Array[StringName] = [
	&"qing_yun_jian_zong", &"xue_yuan_mi_jing", &"yun_lan_cheng", &"dan_xia_gu",
]
## 剧情锁样例（境界达标但需先通关前置）。
const GK_MAP: StringName = &"sui_xing_wai_huan"
## 剧情锁的前置。
const GK_PREREQ: StringName = &"cang_xuan_gu_zhan_chang"


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 开局解锁面（GDD §8「初始状态仅解锁青云剑宗」）
# ═══════════════════════════════════════════════════════════════════════════════

func test_only_start_map_is_unlocked_at_game_start() -> void:
	# Arrange——新档：炼气期、无任何通关记录
	# Act——全表求值
	var unlocked: Array = []
	for map_id: StringName in CATALOG.MAPS.keys():
		if bool(GATE.evaluate(map_id, 1, {})["is_unlocked"]):
			unlocked.append(map_id)
	# Assert——只有青云剑宗（其余要么境界不够、要么有前置）
	assert_eq(unlocked, [START_MAP] as Array,
			"开局可进的图应只有青云剑宗，实得 %s" % [unlocked])


func test_start_map_has_no_prerequisite() -> void:
	assert_true(GATE.prerequisite_of(START_MAP).is_empty(),
			"青云剑宗是起点——不应有前置（否则开局无图可进）")
	assert_true(bool(GATE.evaluate(START_MAP, 1, {})["is_unlocked"]),
			"青云剑宗在炼气期无通关记录时应可进")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 首通前置（GDD §8 顺序锁）
# ═══════════════════════════════════════════════════════════════════════════════

func test_clearing_previous_map_unlocks_next_without_realm_change() -> void:
	# Arrange——炼气期，刚首通青云剑宗（境界没变）
	var cleared: Dictionary = {START_MAP: true}
	# Act
	var second: Dictionary = GATE.evaluate(&"xue_yuan_mi_jing", 1, cleared)
	# Assert——血渊秘境开（同境界内靠通关推进，不靠突破）
	assert_true(bool(second["is_unlocked"]), "首通青云剑宗后血渊秘境应解锁")
	assert_eq(GATE.prerequisite_of(&"xue_yuan_mi_jing"), START_MAP,
			"血渊秘境的前置应为青云剑宗")
	assert_false(bool(GATE.evaluate(&"xue_yuan_mi_jing", 1, {})["is_unlocked"]),
			"未通关青云剑宗时血渊秘境不应解锁")


func test_lianqi_chain_opens_one_link_at_a_time() -> void:
	# Arrange——从开局逐个首通，每步只应多开一张
	var cleared: Dictionary = {}
	var opened: Array = []
	for map_id: StringName in LIANQI_CHAIN:
		# Act——首通这一张
		cleared[map_id] = true
		# Assert——本张已开；链上后一张恰好由它解锁
		assert_true(bool(GATE.evaluate(map_id, 1, cleared)["is_unlocked"]),
				"%s 首通后应处于已解锁态" % map_id)
		var next_index: int = LIANQI_CHAIN.find(map_id) + 1
		if next_index < LIANQI_CHAIN.size():
			var next_id: StringName = LIANQI_CHAIN[next_index]
			opened.append(next_id)
			assert_true(bool(GATE.evaluate(next_id, 1, cleared)["is_unlocked"]),
					"首通 %s 后 %s 应解锁（GDD §8 顺序锁）" % [map_id, next_id])
			# 只多开这一张：再往后一张仍锁着（链式推进，不是一次性全开）
			if next_index + 1 < LIANQI_CHAIN.size():
				var beyond: StringName = LIANQI_CHAIN[next_index + 1]
				assert_false(bool(GATE.evaluate(beyond, 1, cleared)["is_unlocked"]),
						"%s 不应跳过 %s 直接开" % [beyond, next_id])
	# Assert——四张图在炼气期内全部走到（开局 → 丹霞谷）
	assert_eq(opened.size(), LIANQI_CHAIN.size() - 1,
			"炼气期链上每张图都应有前任解锁（实得 %s）" % [opened])


func test_story_lock_requires_prerequisite_even_at_sufficient_realm() -> void:
	# Arrange——筑基期（境界达标），但苍玄古战场未通关
	# Act
	var locked: Dictionary = GATE.evaluate(GK_MAP, 2, {})
	var opened: Dictionary = GATE.evaluate(GK_MAP, 2, {GK_PREREQ: true})
	# Assert——境界达标仍不开；补齐前置才开（GDD §8 剧情锁）
	assert_true(bool(locked["realm_ok"]), "前置：筑基期应满足碎星外环的境界门槛")
	assert_false(bool(locked["is_unlocked"]), "未通关苍玄古战场时碎星外环不应解锁")
	assert_true(bool(opened["is_unlocked"]), "通关苍玄古战场后碎星外环应解锁")


func test_realm_gate_still_blocks_when_prerequisite_cleared() -> void:
	# Arrange——前置已通关，但玩家还在炼气期（门槛筑基）
	# Act
	var result: Dictionary = GATE.evaluate(GK_MAP, 1, {GK_PREREQ: true})
	# Assert——两项条件是「与」关系，缺一不可
	assert_false(bool(result["is_unlocked"]), "境界不足时前置达标也不应解锁")
	assert_false(bool(result["realm_ok"]), "境界条件应报未达标")
	assert_true(bool(result["prerequisite_cleared"]), "前置条件应报已达标")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 面向玩家的条件文案（GDD exploration-ui-system.md §1 灰色锁 + 标明所需境界）
# ═══════════════════════════════════════════════════════════════════════════════

func test_locked_hint_names_realm_in_chinese() -> void:
	# Arrange——炼气玩家看筑基图（无前置）
	# Act
	var hint: String = str(GATE.evaluate(&"cang_xuan_zheng_dao_meng", 1, {})["locked_hint"])
	# Assert——念得出境界名，不是「需2境界」
	assert_eq(hint, "需筑基期", "境界不足的条件文案应为「需筑基期」")


func test_locked_hint_names_prerequisite_map() -> void:
	# Arrange——境界达标、前置未通关
	# Act
	var hint: String = str(GATE.evaluate(GK_MAP, 2, {})["locked_hint"])
	# Assert——念得出「要通关哪张图」与其中文名
	assert_eq(hint, "需通关苍玄古战场", "剧情锁的条件文案应点名前置地图")


func test_locked_hint_lists_both_conditions_when_both_missing() -> void:
	# Arrange——炼气期 + 前置未通关（两条都缺）
	# Act
	var hint: String = str(GATE.evaluate(GK_MAP, 1, {})["locked_hint"])
	# Assert——两条并排，缺的那条各自成句
	assert_string_contains(hint, "需筑基期", "应包含境界条件")
	assert_string_contains(hint, "需通关苍玄古战场", "应包含前置条件")


func test_locked_hint_is_empty_once_unlocked() -> void:
	# Arrange——两项条件都达成
	# Act
	var result: Dictionary = GATE.evaluate(GK_MAP, 2, {GK_PREREQ: true})
	# Assert——已解锁不说条件（卡片不该挂着「需…」）
	assert_eq(str(result["locked_hint"]), "", "已解锁地图不应有条件文案")


func test_realm_text_falls_back_for_unknown_level() -> void:
	# Arrange——配置写错：境界门槛落在境界表之外
	# Act / Assert——给读得通的兜底，不出「需0期」这类故障字样
	assert_eq(GATE.realm_text(0), "需更高境界", "越界等级应给兜底文案")
	assert_eq(GATE.realm_text(9), "需更高境界", "越界等级应给兜底文案")
	assert_eq(GATE.realm_text(3), "需金丹期", "表内等级应给出中文名")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 全表完整性（防「永远开不了」与「读档重算」两条不变量）
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_prerequisite_is_a_registered_map() -> void:
	# Arrange / Act——全表扫前置字段
	var broken: Array = []
	for map_id: StringName in CATALOG.MAPS.keys():
		var prerequisite: StringName = GATE.prerequisite_of(map_id)
		if prerequisite.is_empty():
			continue
		if not CATALOG.has_map(prerequisite):
			broken.append("%s → %s" % [map_id, prerequisite])
	# Assert——拼错会让前置永不满足（该图永远开不了），故必须全表合法
	assert_eq(broken, [], "前置必须指向已登记地图：%s" % [broken])


func test_prerequisites_are_acyclic_and_ordered_before_dependents() -> void:
	# Arrange——探明表顺序即「卡片顺序 = 剧情顺序」
	var ids: Array = CATALOG.MAPS.keys()
	# Act——前置只允许指向更靠前的图（自指 / 环 / 倒序都会让链子断掉）
	var violations: Array = []
	for index: int in range(ids.size()):
		var map_id: StringName = StringName(str(ids[index]))
		var prerequisite: StringName = GATE.prerequisite_of(map_id)
		if prerequisite.is_empty():
			continue
		if prerequisite == map_id:
			violations.append("%s 以前置指向自己" % map_id)
		elif ids.find(prerequisite) >= index:
			violations.append("%s 的前置 %s 排在它之后" % [map_id, prerequisite])
	# Assert
	assert_eq(violations, [], "前置必须无环且排在依赖方之前：%s" % [violations])


func test_every_map_is_reachable_by_playing_the_chain() -> void:
	# Arrange——按「逐图首通 + 境界随该图门槛推进」模拟一路玩下去
	var cleared: Dictionary = {}
	var unreachable: Array = []
	# Act——反复扫描：只要有图的条件被满足就记为通关，直到一轮无进展
	var progress: bool = true
	var rounds: int = 0
	while progress and rounds <= CATALOG.MAPS.size() + 1:
		progress = false
		rounds += 1
		for map_id: StringName in CATALOG.MAPS.keys():
			if bool(cleared.get(map_id, false)):
				continue
			# 玩家会为这张图突破到它的门槛（境界不是锁死项，前提前提才可能是）
			var requirement: int = int(GATE.evaluate(map_id, 1, cleared)["realm_requirement"])
			if bool(GATE.evaluate(map_id, requirement, cleared)["is_unlocked"]):
				cleared[map_id] = true
				progress = true
	# Assert——不存在需要「通关自己才能开自己」这类死锁
	for map_id: StringName in CATALOG.MAPS.keys():
		if not bool(cleared.get(map_id, false)):
			unreachable.append(map_id)
	assert_eq(unreachable, [],
			"每张图都应能从开局一路解锁（卡住的是 %s）" % [unreachable])


func test_unlock_state_is_derived_not_stored_in_catalog() -> void:
	# Arrange / Act——解锁态是本模块对（境界 × 已通关集合）的纯函数求值
	var stored_flags: Array = []
	for map_id: StringName in CATALOG.MAPS.keys():
		var config: Dictionary = GATE.registered_config(map_id)
		for key: Variant in config.keys():
			var name: String = str(key)
			if name == "is_unlocked" or name == "unlocked" or name.ends_with("_unlocked"):
				stored_flags.append("%s.%s" % [map_id, name])
	# Assert——探明表里没有「一次性写入」的解锁标记（读档后重算即得，
	# 存储态只会与进度漂移——任务要求的「不依赖一次性写入」由这条不变量保证）
	assert_eq(stored_flags, [], "解锁态不得写进探明表：%s" % [stored_flags])


func test_legacy_spelling_resolves_to_same_gate_result() -> void:
	# Arrange——存档 / 外部数据里的历史写法
	# Act
	var legacy: Dictionary = GATE.evaluate(&"yueguo_capital", 1, {})
	# Assert——归一到规范写法后求值一致（且带回规范 ID，便于回读存档）
	assert_eq(legacy["map_id"], &"yun_lan_cheng", "历史写法应归一到规范写法")
	assert_eq(legacy, GATE.evaluate(&"yun_lan_cheng", 1, {}),
			"历史写法与规范写法应得到同一份求值结果")


func test_unregistered_map_falls_back_conservatively() -> void:
	# Arrange——未登记地图（调试 / 旧存档里的图）
	# Act
	var result: Dictionary = GATE.evaluate(&"unknown_map", 1, {})
	# Assert——门槛按炼气、无前置（不借用别张图的解锁规则），求值不崩
	assert_true(bool(result["is_unlocked"]), "未登记地图无门槛约束时应可进")
	assert_eq(int(result["realm_requirement"]), GATE.FALLBACK_REALM,
			"未登记地图的门槛应取保守默认值")
	assert_true(bool(result["prerequisite_cleared"]),
			"无前置时「前置已满足」应为真（消费方不必分两种缺省）")
	assert_eq(str(result["locked_hint"]), "", "已解锁时不应有条件文案")


func test_map_display_name_falls_back_to_id() -> void:
	# Arrange / Act / Assert——未登记地图没有中文名，回退 ID 字面量（不臆造名字）
	assert_eq(GATE.map_display_name(&"unknown_map"), "unknown_map",
			"未登记地图的名字应回退地图 ID")
	assert_eq(GATE.map_display_name(&""), "", "空 ID 应返回空串（无前置时不出现占位字）")
	assert_eq(GATE.map_display_name(GK_PREREQ), "苍玄古战场", "登记地图应给中文名")
