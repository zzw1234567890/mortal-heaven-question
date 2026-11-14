extends "res://tests/unit/inventory/inventory_pill_use_fixture.gd"
## InventoryPillUse 单元测试（三）：回复行动力类丹药。[br]
## [br][b]本文件补的断链[/b]：[code]use_entry[/code] 此前只走治疗类效果——AP 类丹药在
## 战斗评估层落 [code]UNEVALUABLE[/code]（词表里没有 AP 这一类别），治疗量为 0，
## 于是被当成「效用未参透」拒掉。GDD action-point-system.md §3 明写「回复丹药 |
## 按丹药类型 | 玩家在探索中使用丹药」，这条路径必须能走通。[br]
## [br][b]覆盖[/b]（本轮任务点名的断言）：[br]
##   1. 回复行动力[b]真的写进 GSM[/b] 且行囊少一枚；[br]
##   2. 回复量[b]不超上限[/b]——差多少回多少，上限为 0（未知）时不夹；[br]
##   3. 已满时拒绝且[b]不消耗丹药[/b]，文案为 GDD 验收项「行动力已满」；[br]
##   4. 取出失败时行动力按原值回滚（失败不半完成）。[br]
## [br][b]装置见 [inventory_pill_use_fixture.gd][/b]（GSM 桩含探索域 AP 的读写）。[br]
##
## 来源: design/gdd/action-point-system.md §3/§8/§验收标准、本轮任务书第 2 条。

const ApScript := preload("res://src/feature/inventory/inventory_pill_ap.gd")

## AP 类丹药的效果类型词表字符串（本模块与模板之间的口径）。
const TYPE_RESTORE_AP: String = "restore_ap"
## 中文别名的效果类型（同一条路径的另一条词表入口）。
const TYPE_AP_CN: String = "回复行动力"


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 回复行动力
# ═══════════════════════════════════════════════════════════════════════════════

func test_ap_pill_restores_action_points_and_consumes_one() -> void:
	## 定点断言：行动力真的涨了，行囊真的少一枚。
	# Arrange——2/5，一枚 +2 的丹
	add_pill("ap1", "回气丹", 2, "self", TYPE_RESTORE_AP)
	set_ap(2, 5)
	gsm.removable = [101]
	# Act
	var result: Dictionary = use.use_entry(entry("ap1", [101]))
	# Assert
	assert_true(bool(result["ok"]), "应成功：%s" % str(result["message"]))
	assert_eq(ap(), 4, "行动力应从 2 涨到 4（回复 2 点）")
	assert_eq(int(result["healed"]), 2, "回报的实际回复量应为 2")
	assert_true(bool(result["consumed"]), "应报告已消耗")
	assert_eq(gsm.removals, [101], "应移除那一枚实例")
	assert_eq(gsm.removable, [], "实例不应还在收藏里")
	assert_true(str(result["message"]).contains("行动力"),
			"文案应说明回的是行动力而不是生命：%s" % str(result["message"]))


func test_ap_pill_uses_the_shared_exploration_write_entry() -> void:
	## 写入走 GSM 第二层原子方法（[code]restore_action_points[/code]）——
	## 不另开第二条 AP 通路；回滚才用 [code]set_exploration_ap[/code]。
	# Arrange
	add_pill("ap2", "回气丹", 3, "self", TYPE_RESTORE_AP)
	set_ap(1, 9)
	gsm.removable = [102]
	# Act
	use.use_entry(entry("ap2", [102]))
	# Assert
	assert_eq(gsm.ap_restores, [3], "应经 restore_action_points 写入 3 点")
	assert_eq(gsm.ap_sets, [], "成功路径不应走「设回原值」的入口")


func test_ap_pill_reads_value_from_the_template() -> void:
	## 数值逐字取自模板——本模块不认识「回气丹是 2 点」。
	# Arrange
	add_pill("ap3", "大回气丹", 5, "self", TYPE_RESTORE_AP)
	set_ap(0, 10)
	gsm.removable = [103]
	# Act
	var result: Dictionary = use.use_entry(entry("ap3", [103]))
	# Assert
	assert_eq(ap(), 5, "5 点模板值应原样入账")
	assert_eq(int(result["healed"]), 5, "回报量应与模板一致")


func test_ap_alias_effect_type_is_recognized() -> void:
	## 中文别名（[code]回复行动力[/code]）与英文前缀同走一条路径——
	## 与评估层「中文分支同样要先判」的口径一致。
	# Arrange
	add_pill("ap4", "回气丹", 2, "self", TYPE_AP_CN)
	set_ap(1, 5)
	gsm.removable = [104]
	# Act
	var result: Dictionary = use.use_entry(entry("ap4", [104]))
	# Assert
	assert_true(bool(result["ok"]), "中文别名的 AP 丹也应能用")
	assert_eq(ap(), 3, "应回复 2 点")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 不超上限
# ═══════════════════════════════════════════════════════════════════════════════

func test_ap_pill_clamps_to_the_cap() -> void:
	## 回复量超过缺口时只补到上限——不虚报被上限吃掉的部分，也不越界。
	# Arrange——4/5，一枚 +3 的丹
	add_pill("ap5", "大回气丹", 3, "self", TYPE_RESTORE_AP)
	set_ap(4, 5)
	gsm.removable = [105]
	# Act
	var result: Dictionary = use.use_entry(entry("ap5", [105]))
	# Assert
	assert_eq(ap(), 5, "应夹在上限，绝不越界")
	assert_eq(int(result["healed"]), 1, "实际回复量应为缺口 1 点")


func test_ap_pill_does_not_clamp_when_cap_is_unknown() -> void:
	## 上限为 0 = 「尚未进入任何地图、上限未知」（出厂存档即如此）——
	## 此时按原值累加，不臆造一个上限把恢复吞掉（同
	## [code]GSMExplorationWrites.restore_action_points[/code] 的注记）。
	# Arrange
	add_pill("ap6", "回气丹", 2, "self", TYPE_RESTORE_AP)
	set_ap(0, 0)
	gsm.removable = [106]
	# Act
	var result: Dictionary = use.use_entry(entry("ap6", [106]))
	# Assert
	assert_eq(ap(), 2, "上限未知时不应夹取")
	assert_eq(int(result["healed"]), 2, "回报量应为全量")


func test_ap_pill_clamps_oversized_save_value() -> void:
	## 越界存档值（行动力已超上限）不产生回复量——不倒扣也不放大；
	## 与事件 RESTORE_AP / 灵泉同一口径。
	# Arrange
	add_pill("ap7", "回气丹", 2, "self", TYPE_RESTORE_AP)
	set_ap(9, 5)
	gsm.removable = [107]
	# Act
	var result: Dictionary = use.use_entry(entry("ap7", [107]))
	# Assert
	assert_false(bool(result["ok"]), "已超上限时不应成功")
	assert_eq(ap(), 9, "越界存档值不应被倒扣或抬高")
	assert_eq(gsm.removals, [], "拒绝路径不应动收藏")
	assert_eq(gsm.ap_restores, [], "拒绝路径不应写行动力")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 已满时拒绝（GDD 验收标准）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ap_pill_at_full_cap_is_refused_with_the_gdd_message() -> void:
	## GDD action-point-system.md §验收标准：「GIVEN 使用回复丹药但行动力已满，
	## WHEN 尝试使用，THEN 提示"行动力已满"」——文案逐字锁定。
	# Arrange——满行动力
	add_pill("ap8", "回气丹", 2, "self", TYPE_RESTORE_AP)
	set_ap(5, 5)
	gsm.removable = [108]
	# Act
	var result: Dictionary = use.use_entry(entry("ap8", [108]))
	# Assert
	assert_false(bool(result["ok"]), "行动力已满时应拒绝")
	assert_true(str(result["message"]).contains("行动力已满"),
			"应提示「行动力已满」（GDD 验收项）：%s" % str(result["message"]))
	assert_false(bool(result["consumed"]), "已满时不应消耗丹药")
	assert_eq(gsm.removable, [108], "丹药应原样留在行囊里")
	assert_eq(ap(), 5, "行动力不应被写坏")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 失败不半完成
# ═══════════════════════════════════════════════════════════════════════════════

func test_ap_pill_rolls_the_action_points_back_when_consume_fails() -> void:
	## 取出失败时行动力按原值回滚——先写 AP 再发现取不出药，等于白送一次回复。
	# Arrange
	add_pill("ap9", "回气丹", 2, "self", TYPE_RESTORE_AP)
	set_ap(1, 5)
	gsm.removable = []   # 移除一定失败
	# Act
	var result: Dictionary = use.use_entry(entry("ap9", [109]))
	# Assert
	assert_false(bool(result["ok"]), "取出失败应整体失败")
	assert_false(bool(result["consumed"]), "失败时不应报告已消耗")
	assert_eq(ap(), 1, "行动力应回滚到原值")
	assert_eq(gsm.ap_sets, [[1, 5]], "回滚应经 set_exploration_ap 写回原值与原上限")


func test_ap_pill_without_gsm_is_refused_not_crashed() -> void:
	## GSM 不可用（缺 [code]restore_action_points[/code] 的降级形态）→ 拒绝并给出
	## 中文原因，不崩、不吞丹药。
	# Arrange
	add_pill("ap10", "回气丹", 2, "self", TYPE_RESTORE_AP)
	var bare: Node = Node.new()
	add_child_autofree(bare)
	use.gsm = bare
	# Act
	var result: Dictionary = use.use_entry(entry("ap10", [110]))
	# Assert
	assert_false(bool(result["ok"]), "GSM 缺写入口时应拒绝")
	assert_false(str(result["message"]).strip_edges().is_empty(), "应给中文原因")
	assert_eq(gsm.removals, [], "不应动收藏")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 与治疗路径互不干扰
# ═══════════════════════════════════════════════════════════════════════════════

func test_heal_pill_still_takes_the_healing_path() -> void:
	## 回归锁定：治疗类丹药仍走原路径（不因新增 AP 分支而改道）——
	## 行动力与 HP 一字不动另一侧。
	# Arrange
	add_pill("h1", "玉灵丹", 8)
	set_hp(101, 3, 10)
	set_ap(1, 5)
	gsm.removable = [201]
	# Act
	var result: Dictionary = use.use_entry(entry("h1", [201]))
	# Assert
	assert_eq(int(hp.table[101]["current_hp"]), 10, "治疗路径应照常回血")
	assert_eq(ap(), 1, "治疗类丹药不应碰行动力")
	assert_eq(gsm.ap_restores, [], "治疗路径不应走 AP 写入")


func test_unknown_effect_pill_is_still_refused() -> void:
	## 既不是治疗也不是回复行动力（九转金丹那种「永久 +1 最大生命」）→
	## 仍如实说用不了，不拿 0 点回血冒充成功。
	# Arrange
	add_pill("u1", "九转金丹", 0, "self", "permanent_max_hp")
	set_ap(1, 5)
	# Act
	var result: Dictionary = use.use_entry(entry("u1", [301]))
	# Assert
	assert_false(bool(result["ok"]), "未建模的效果类型应拒绝")
	assert_eq(str(result["message"]), UseScript.TEXT_EFFECT_UNKNOWN,
			"应给「效用尚未参透」")
	assert_eq(gsm.removals, [], "不应动收藏")
	assert_eq(ap(), 1, "不应碰行动力")


func test_amount_of_ignores_non_ap_effects() -> void:
	## 纯读取口径：只有 [code]restore_ap[/code] / 中文别名算 AP 量，
	## 其余效果类型一律 0（治疗量不会被误当成行动力）。
	assert_eq(ApScript.amount_of({"effect_type": "heal", "effect_value": 5}), 0,
			"治疗类不应被读成 AP")
	assert_eq(ApScript.amount_of({"effect_type": "restore_ap", "effect_value": 5}), 5,
			"英文前缀应被识别")
	assert_eq(ApScript.amount_of({"effect_type": "回复行动力", "effect_value": 2}), 2,
			"中文别名应被识别")
	assert_eq(ApScript.amount_of({"effect_type": "行动力上限", "effect_value": 2}), 0,
			"只有「行动力」二字不足以判定（上限类描述不应被误读）")
	assert_eq(ApScript.amount_of(null), 0, "空模板应返回 0 而不是崩")
