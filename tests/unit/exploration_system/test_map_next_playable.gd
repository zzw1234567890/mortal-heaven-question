extends GutTest
## 「下一张去哪」——通关之后该玩哪张的推荐求值（[code]ExplorationMapGate.next_playable[/code]）。[br]
## [br][b]本文件补的断链[/b]：打完 Boss 回到选图界面时，玩家面对 17 张卡片，而
## 「刚通完的这张」是最显眼的那张（它亮着「已通关」）。没有任何引导时，玩家的默认
## 动作是再点回同一张图重刷，新内容要靠自己逐张比对解锁条件才能找到。[br]
## [br][b]为什么从 [code]test_map_unlock_gate.gd[/code] 分出来[/b]：[code]next_playable[/code]
## 与 [code]evaluate[/code] 虽同属门槛模块，但回答的是两个问题——「这张图能不能进」
## 与「下一张该进哪张」。两个文件的用例数都在增长，合在一起会越过 300 行软上限
## （.claude/docs/coding-standards.md）。[br]
## [br][b]纯函数直调[/b]：不实例化系统、不读 GSM——已通关集合由用例自己造
## （同 [code]test_map_unlock_gate.gd[/code] 口径）。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面 / §7 通关结算、
## design/gdd/exploration-system.md §8 地图初始解锁顺序、ADR-0014 §get_map_list 契约。

const GATE := preload("res://src/feature/exploration/exploration_map_gate.gd")
const CATALOG := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 开局可进的图（GDD §8「初始状态仅解锁青云剑宗」）。
const START_MAP: StringName = &"qing_yun_jian_zong"
## 炼气期四图的推进链（GDD §8 顺序锁）。
const LIANQI_CHAIN: Array[StringName] = [
	&"qing_yun_jian_zong", &"xue_yuan_mi_jing", &"yun_lan_cheng", &"dan_xia_gu",
]


func test_next_playable_points_at_the_next_chained_map() -> void:
	# Arrange——刚首通青云剑宗（炼气期）
	var cleared: Dictionary = {START_MAP: true}
	# Act
	var next: Dictionary = GATE.next_playable(START_MAP, 1, cleared)
	# Assert——推荐的是链上的下一张，且已解锁（点得进去）
	assert_eq(next["map_id"], &"xue_yuan_mi_jing", "刚通青云剑宗应推荐血渊秘境")
	assert_true(bool(next["is_unlocked"]), "推荐图应处于已解锁态（点得进去）")
	assert_eq(str(next["name"]), "血渊秘境", "推荐图应带中文名")


func test_next_playable_never_returns_the_just_cleared_map() -> void:
	## 推荐回原地等于没有引导——刚通完那张还亮着「已通关」，最容易被再点一次。
	# Arrange——炼气期四张全通
	var cleared: Dictionary = {}
	for map_id: StringName in LIANQI_CHAIN:
		cleared[map_id] = true
	# Act
	var next: Dictionary = GATE.next_playable(&"dan_xia_gu", 1, cleared)
	# Assert——不回原地（此时它是第一张未通关但锁着的图，理由在返回值里）
	assert_ne(next.get("map_id", &""), &"dan_xia_gu", "不该把刚通关的那张推荐回去")


func test_next_playable_prefers_unlocked_over_locked() -> void:
	## 有几张可选时先给「点得动」的那张，而不是表里遇到的第一个锁着的。
	# Arrange——炼气期、只通了青云剑宗（血渊开、其余锁）
	var cleared: Dictionary = {START_MAP: true}
	# Act
	var next: Dictionary = GATE.next_playable(START_MAP, 1, cleared)
	# Assert
	assert_true(bool(next["is_unlocked"]), "有已解锁的候选时不返回锁定图")


func test_next_playable_falls_back_to_locked_map_with_hint() -> void:
	## 全图通关之后没有「可玩」的下一张时，仍应告诉玩家「下一步解锁哪张、缺什么」，
	## 而不是一句「暂无」。
	# Arrange——炼气期四图全通，下一批图要筑基期
	var cleared: Dictionary = {}
	for map_id: StringName in LIANQI_CHAIN:
		cleared[map_id] = true
	# Act
	var next: Dictionary = GATE.next_playable(&"dan_xia_gu", 1, cleared)
	# Assert——退而给第一张未通关但锁着的图，且带得上条件文案
	assert_false(next.is_empty(), "还有未通关的图时应给出候选，而不是空")
	assert_false(bool(next["is_unlocked"]), "此时候选仍是锁定态")
	assert_false(str(next["locked_hint"]).is_empty(),
			"锁定候选必须带条件文案（否则玩家不知道该去解锁什么）")


func test_next_playable_is_empty_when_everything_is_cleared() -> void:
	# Arrange——全表通关
	var cleared: Dictionary = {}
	for map_id: StringName in CATALOG.MAPS.keys():
		cleared[map_id] = true
	# Act
	var next: Dictionary = GATE.next_playable(&"qing_yun_jian_zong", 5, cleared)
	# Assert——不臆造一张图（面板据此出「已通关全部地图」）
	assert_true(next.is_empty(), "全部通关时应返回空字典")


func test_next_playable_is_a_pure_function() -> void:
	## 同一份入参给同一份结果——推荐态不写任何状态（读档后重算即得）。
	var cleared: Dictionary = {START_MAP: true}
	assert_eq(GATE.next_playable(START_MAP, 1, cleared),
			GATE.next_playable(START_MAP, 1, cleared),
			"同入参应得到同一份推荐结果")


func test_next_playable_ignores_realm_for_already_unlocked_maps() -> void:
	## 境界足够高时，链上的下一张照样是推荐对象（不会因为「都解锁了」而乱指）。
	var cleared: Dictionary = {START_MAP: true}
	var next: Dictionary = GATE.next_playable(START_MAP, 5, cleared)
	assert_eq(next["map_id"], &"xue_yuan_mi_jing",
			"表序即推荐序——境界再高也按剧情顺序给下一张")


# ═══════════════════════════════════════════════════════════════════════════════
# 演出一致性——推荐的那张必须真的点得动
# ═══════════════════════════════════════════════════════════════════════════════

func test_recommended_map_is_enterable_under_the_same_inputs() -> void:
	## 推荐与「能不能进」是同一份求值的两个读法——两者不一致时卡片会亮着金色边框
	## 却点了没反应（`_entry_for` 用的是 [method ExplorationMapGate.evaluate]，
	## 本文件用的是 [method ExplorationMapGate.next_playable]）。
	# Arrange——炼气期、逐图首通（每次都是「刚通完前一张」的真实处境）
	var cleared: Dictionary = {}
	for map_id: StringName in LIANQI_CHAIN:
		cleared[map_id] = true
		# Act——刚通完这一张，问下一张去哪
		var next: Dictionary = GATE.next_playable(map_id, 1, cleared)
		if next.is_empty():
			continue
		# Assert——推荐态与列表条目对同一张图的判定一致
		var entry_gate: Dictionary = GATE.evaluate(
				StringName(str(next["map_id"])), 1, cleared)
		assert_eq(bool(next["is_unlocked"]), bool(entry_gate["is_unlocked"]),
				"%s 的推荐态应与列表条目一致（推荐一张点不动的图等于没推荐）"
				% next["map_id"])
