extends GutTest
## 续战存档里[b]debuff 条目[/b]的形状与灌回验收（[code]battle_resume_debuffs.gd[/code]）。[br]
## [br][b]为什么需要[/b]：debuff 不进存档的后果是「读档回来敌人身上的降攻凭空蒸发」
## ——数值对不上，而那要到真机上打一拳才看得见。[br]
## [br][b]覆盖[/b]：[br]
##   1. 折叠：逐条落 [code]{target_id, type, duration, amount, source_id}[/code]，
##      且[b]逐条[/b]保留剩余回合（合并成总量会让两批到期的时点塌成一个）；[br]
##   2. 类型键名 ↔ 枚举的双向映射（认不出的键整个丢掉）；[br]
##   3. 灌回：真管理器上逐条 [code]apply[/code]，层数与剩余回合与存档一致；[br]
##   4. [b]不先 clear[/b]：调用方已经落好的状态不该被这一层抹掉；[br]
##   5. JSON 安全与「有没有快照」的判据。[br]
## [br]来源: ADR-0002 §JSON 容器、design/gdd/combat-system.md §公式、
## 本轮「debuff 进存档」。

const DebuffsScript := preload("res://src/feature/combat/battle_resume_debuffs.gd")
const DebuffScript := preload("res://src/feature/combat/combat_debuff_manager.gd")
const SLS := preload("res://src/foundation/save_load_system.gd")

const TARGET_A: int = 200001
const TARGET_B: int = 200002


## 一份 debuff 管理器的状态快照（[code]snapshot()[/code] 的形状）。[br]
## [br][b]同一目标同类型挂两条、剩余回合不同[/b]：这正是「不能合并成总量」的场景。
func _snapshot() -> Dictionary:
	return {
		TARGET_A: {
			"atk_down": [
				{"stacks": 1, "duration": 3, "amount": 2, "source_id": 11},
				{"stacks": 1, "duration": 1, "amount": 4, "source_id": 12},
			],
		},
		TARGET_B: {
			"def_down": [{"stacks": 1, "duration": 2, "amount": 5, "source_id": 13}],
		},
	}


func _payload(p_entries: Array) -> Dictionary:
	return {DebuffsScript.KEY_DEBUFFS: p_entries}


# ═══════════════════════════════════════════════════════════════════════════════
# 折叠
# ═══════════════════════════════════════════════════════════════════════════════

func test_fold_keeps_one_entry_per_application() -> void:
	## 逐条存——同一目标同类型的两批到期时点不同，合并会让其中一批多挨或少挨一回合。
	var entries: Array = DebuffsScript.fold(_snapshot())
	assert_eq(entries.size(), 3, "三次施加 = 三条（不按目标+类型合并）")
	var durations: Array = []
	for raw: Variant in entries:
		if int((raw as Dictionary)[DebuffsScript.KEY_TARGET_ID]) == TARGET_A:
			durations.append(int((raw as Dictionary)[DebuffsScript.KEY_DURATION]))
	durations.sort()
	assert_eq(durations, [1, 3], "同一目标的两条各自保留自己的剩余回合")


func test_fold_maps_type_key_to_enum() -> void:
	var entries: Array = DebuffsScript.fold(_snapshot())
	var by_type: Dictionary = {}
	for raw: Variant in entries:
		by_type[int((raw as Dictionary)[DebuffsScript.KEY_TARGET_ID])] = \
				int((raw as Dictionary)[DebuffsScript.KEY_TYPE])
	assert_eq(int(by_type[TARGET_A]), DebuffScript.TYPE_ATK, "atk_down 应还原成 TYPE_ATK")
	assert_eq(int(by_type[TARGET_B]), DebuffScript.TYPE_DEF, "def_down 应还原成 TYPE_DEF")


func test_fold_keeps_amount_and_source() -> void:
	## 按剩余回合定位那一条（同目标同类型的两条顺序由快照的插入序决定——
	## 断言按内容找，不押在数组下标上）。
	var entries: Array = DebuffsScript.fold(_snapshot())
	var second: Dictionary = {}
	for raw: Variant in entries:
		var entry: Dictionary = raw
		if int(entry[DebuffsScript.KEY_TARGET_ID]) == TARGET_A \
				and int(entry[DebuffsScript.KEY_DURATION]) == 1:
			second = entry
	assert_false(second.is_empty(), "前置：能找到「还剩 1 回合」的那一条")
	assert_eq(int(second[DebuffsScript.KEY_AMOUNT]), 4, "数值逐条保留（不是层数×数值）")
	assert_eq(int(second[DebuffsScript.KEY_SOURCE_ID]), 12, "施加者也保留（反向追踪用）")


func test_fold_drops_unknown_type_keys() -> void:
	## 认不出类型的条目读侧还原不了——留一条会变成「看不见的 debuff」（扣了数值无图标）。
	var entries: Array = DebuffsScript.fold({
		TARGET_A: {"atk_down": [{"duration": 1, "amount": 2, "source_id": 1}],
			"poison": [{"duration": 5, "amount": 9, "source_id": 1}]},
	})
	assert_eq(entries.size(), 1, "只有认得出的类型进载荷")
	assert_eq(int((entries[0] as Dictionary)[DebuffsScript.KEY_AMOUNT]), 2,
			"进来的是 atk_down 那条（不是 poison）")


func test_fold_output_is_json_compatible() -> void:
	var entries: Array = DebuffsScript.fold(_snapshot())
	assert_true(SLS._is_json_compatible(entries),
			"折出的条目必须只含 JSON 兼容类型（否则整份存档被判 VALIDATION_ERROR）")
	var sample: Dictionary = entries[0]
	assert_eq(typeof(sample[DebuffsScript.KEY_TARGET_ID]), TYPE_INT, "目标 ID 是 int")
	assert_eq(typeof(sample[DebuffsScript.KEY_TYPE]), TYPE_INT, "类型是 int 枚举")


func test_fold_is_order_stable() -> void:
	## 键序若随插入序，两次抓快照会得到不同顺序的载荷——排序让形状确定。
	var snapshot: Dictionary = _snapshot()
	assert_eq(DebuffsScript.fold(snapshot), DebuffsScript.fold(snapshot),
			"同一份快照折两次结果逐项相同")


func test_fold_tolerates_empty_and_malformed() -> void:
	assert_eq(DebuffsScript.fold({}), [], "没有 debuff = 空条目")
	assert_eq(DebuffsScript.fold(null), [], "非字典一律空——不臆造")
	assert_eq(DebuffsScript.fold({TARGET_A: "not_a_dict"}), [], "目标条目非字典时跳过")


# ═══════════════════════════════════════════════════════════════════════════════
# 灌回
# ═══════════════════════════════════════════════════════════════════════════════

func test_restore_applies_every_entry_to_manager() -> void:
	# Arrange
	var manager: RefCounted = DebuffScript.new()
	var entries: Array = DebuffsScript.fold(_snapshot())
	# Act
	var applied: int = DebuffsScript.restore(manager, _payload(entries))
	# Assert——逐条生效
	assert_eq(applied, 3, "三条都应施加成功")
	assert_eq(int(manager.call(&"get_stacks", TARGET_A, DebuffScript.TYPE_ATK)), 2,
			"同一目标的两条 = 2 层")
	assert_eq(int(manager.call(&"get_stacks", TARGET_B, DebuffScript.TYPE_DEF)), 1,
			"另一目标 1 层")
	assert_eq(int(manager.call(&"get_duration", TARGET_A, DebuffScript.TYPE_ATK)), 1,
			"最早到期的那条决定剩余回合（两条中 1 更早）")


func test_restore_makes_debuff_actually_bite() -> void:
	## 灌回去的 debuff 要真的从战斗取数里扣掉——挂上了但数值不生效等于没存。
	# Arrange
	var manager: RefCounted = DebuffScript.new()
	var entries: Array = DebuffsScript.fold(_snapshot())
	# Act
	DebuffsScript.restore(manager, _payload(entries))
	# Assert——降攻总量 = 2 + 4 = 6
	assert_eq(int(manager.call(&"get_atk_with_debuff", TARGET_A, 20)), 14,
			"降攻应真的扣掉（2 + 4 = 6）")
	# Assert——降防总量 = 5
	assert_eq(int(manager.call(&"get_def_with_debuff", TARGET_B, 12)), 7,
			"降防应真的扣掉（5）")


func test_restore_survives_json_round_trip() -> void:
	## 存档往返后条目里的数字是 float——灌回路径必须照样施加（读侧一律 int()）。
	# Arrange
	var manager: RefCounted = DebuffScript.new()
	var entries: Array = DebuffsScript.fold(_snapshot())
	var round_tripped: Variant = JSON.parse_string(JSON.stringify(_payload(entries)))
	# Act
	var applied: int = DebuffsScript.restore(manager, round_tripped)
	# Assert
	assert_eq(applied, 3, "经 JSON 往返后仍应逐条施加成功")
	assert_eq(int(manager.call(&"get_stacks", TARGET_A, DebuffScript.TYPE_ATK)), 2,
			"层数与存档一致（float 数字没有被吞掉）")


func test_restore_does_not_clear_existing_state() -> void:
	## 不先 clear——[code]battle_start[/code] 已经清过一遍，再清会把调用方已落好的状态抹掉。
	# Arrange
	var manager: RefCounted = DebuffScript.new()
	manager.call(&"apply", TARGET_B, DebuffScript.TYPE_ATK, 5, 7, 99)
	# Act——只灌存档里那三条
	DebuffsScript.restore(manager, _payload(DebuffsScript.fold(_snapshot())))
	# Assert——既有的那条仍在
	assert_eq(int(manager.call(&"get_stacks", TARGET_B, DebuffScript.TYPE_ATK)), 1,
			"灌回不得清掉管理器里已有的 debuff")


func test_restore_counts_only_accepted_entries() -> void:
	## 层数已满 / 类型认不出 / 数值非正的会被 [code]apply[/code] 拒掉——返回值如实计数。
	# Arrange——同一目标同一类型连着 6 条（上限 5）
	var entries: Array = []
	for i: int in range(6):
		entries.append({
			DebuffsScript.KEY_TARGET_ID: TARGET_A,
			DebuffsScript.KEY_TYPE: DebuffScript.TYPE_ATK,
			DebuffsScript.KEY_DURATION: 2,
			DebuffsScript.KEY_AMOUNT: 1,
			DebuffsScript.KEY_SOURCE_ID: 1,
		})
	var manager: RefCounted = DebuffScript.new()
	# Act
	var applied: int = DebuffsScript.restore(manager, _payload(entries))
	# Assert——上限封顶 5 条
	assert_eq(applied, 5, "超出层数上限的条目不计入（管理器拒了就是拒了）")
	assert_eq(int(manager.call(&"get_stacks", TARGET_A, DebuffScript.TYPE_ATK)),
			DebuffScript.MAX_STACKS, "层数封顶")


func test_restore_without_manager_is_noop() -> void:
	assert_eq(DebuffsScript.restore(null, _payload([{DebuffsScript.KEY_TARGET_ID: 1}])), 0,
			"管理器缺失时如实返回 0（不崩、不臆造）")


# ═══════════════════════════════════════════════════════════════════════════════
# 判据
# ═══════════════════════════════════════════════════════════════════════════════

func test_has_state_requires_actual_entries() -> void:
	assert_false(DebuffsScript.has_state({}), "没有这个段 = 没有快照")
	assert_false(DebuffsScript.has_state(_payload([])), "空段 = 没有快照（v3 老档形态）")
	assert_true(DebuffsScript.has_state(_payload(
			[{DebuffsScript.KEY_TARGET_ID: TARGET_A}])), "有条目即为有快照")


func test_type_key_round_trip_via_manager() -> void:
	## 键名 ↔ 枚举的映射是管理器持有的唯一真理来源——两处各写一遍必然漂移。
	assert_eq(DebuffScript.key_of_type(DebuffScript.TYPE_ATK), "atk_down", "ATK 的键名")
	assert_eq(DebuffScript.type_of_key("atk_down"), DebuffScript.TYPE_ATK, "键名反查回 ATK")
	assert_eq(DebuffScript.type_of_key("def_down"), DebuffScript.TYPE_DEF, "DEF 反查")
	assert_eq(DebuffScript.type_of_key("poison"), DebuffScript.NO_TYPE,
			"认不出的键给哨兵值（不臆造一种 debuff）")
