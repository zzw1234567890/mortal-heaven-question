extends RefCounted
## CultivationTribulationGate —— 修炼室第二动作行的[b]语义判定单点[/b]。[br]
## [br][b]它回答一个问题[/b]：修为满了之后，这一行到底是「渡劫」还是「直接突破」，
## 能不能点、不能点时给哪句中文。[br]
## [br][b]为什么必须有一处专门判这个[/b]：修炼室原先的「突破」直接调
## [code]RealmSystem.realm_up[/code]，把 [code]TribulationSystem[/code] 整条链绕过去了
## （[code]trigger_tribulation[/code] 在生产里此前没有任何调用者——渡劫场景只有探索侧
## 渡劫台会转过去，而那条路没触发渡劫状态，进战即降级成普通战斗）。
## 「哪一境界该走渡劫」是规则，不是按钮的私有判断；写死在按钮回调里就再也无法单点核对
## （同 [code]node_interaction_rules.gd[/code] 把「渡劫台可不可挑战」收在一处的口径）。[br]
## [br][b]判据读配置，不写死境界数字[/b]：境界表 [code]RealmSystem.realm_table[/code] 的
## 每一行可用 [constant KEY_REQUIRES_TRIBULATION]（[code]requires_tribulation[/code]）
## 显式声明该境界进阶[b]是否必须渡劫[/b]；[b]缺省为 true[/b]——即当前配置下
## 「低于最高境界的每一次大境界提升都要渡劫」，与
## [code]design/gdd/tribulation-system.md[/code] §7「一局最多 4 次渡劫
## （炼气→筑基→金丹→元婴→化神）」一致。[br]
## [b]为什么留一个「不需要渡劫」的分支[/b]：GDD 登记了一处例外（第 2 章苍玄古战场
## 境界跌落后的「重新筑基」由剧情系统直接 [code]realm_up[/code]，不经渡劫）。
## 剧情专属境界一旦落进境界表，只翻那一行的键即可，界面与判定都不用动——本模块
## 先把这道缝留出来，而不是等它出现再改按钮。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块是纯函数——不读 GSM、不持节点、
## 不调任何系统；数字由调用方（[code]CultivationActions[/code]）从
## [code]CultivationSystem.get_breakthrough_status[/code] 与
## [code]TribulationSystem.get_tribulation_status[/code] 取来传进 [method decide]。[br]
## [br][b]为什么连中文也由它给[/b]：判定与措辞分开写就必然有一天漂移成「按钮说渡劫、
## 状态行说突破」。本模块是唯一同时知道两件事的地方，故直接向
## [code]CultivationViewRules[/code]（文案单点）取句子——依赖方向单向
## （gate → view_rules），不构成循环。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——本模块不自己措辞，句子全在
## [code]CultivationViewRules[/code] 的 [code]TEXT_*[/code]。[br]
##
## 来源: design/gdd/tribulation-system.md §1/§6/§7 + §「唯一例外」、
## design/gdd/cultivation-system.md §6、ADR-0021 §check_tribulation_ready、
## ADR-0031 §2、先例 [code]node_interaction_rules.gd[/code]（判定与文案同一处收口）。

## 文案与判定单点（本模块不自己措辞——句子从这里取）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 渡劫系统枚举真理来源（TribulationState.NOT_READY——不写魔数 0）。
const TribulationScript := preload("res://src/feature/tribulation_system.gd")
## 境界配置表的唯一真理来源（ADR-0010——本模块不自己抄一份境界表）。
const RealmScript := preload("res://src/core/realm_system.gd")

## 第二动作行的语义种类。[br]
## [br][b]调用方据此分派「点下去调哪个系统」[/b]：[constant KIND_TRIBULATION] 走
## [code]TribulationSystem.trigger_tribulation[/code] + 转渡劫场景，
## [constant KIND_BREAKTHROUGH] 走 [code]RealmSystem.realm_up[/code]。
const KIND_NONE: StringName = &"none"
const KIND_TRIBULATION: StringName = &"tribulation"
const KIND_BREAKTHROUGH: StringName = &"breakthrough"

## 该境界进阶是否需要渡劫的键名（境界表每行的可选键；缺省 = 需要）。
const KEY_REQUIRES_TRIBULATION: String = "requires_tribulation"

## 境界表（默认取 [code]RealmSystem.realm_table[/code]；测试可注入同一张表的副本——
## 只翻某一行的 [constant KEY_REQUIRES_TRIBULATION]，其余全部走真配置）。
var _table: Dictionary = {}


## 构造。[br]
## [br][param p_table] 境界表覆盖（空 / 非字典 = 用真配置）。[br]
## [br][b]为什么允许注入[/b]：「不需要渡劫的境界」在 GDD 里只有剧情专属的情况
## （第 2 章苍玄古战场重新筑基），当前境界表一行都没标——不注入就构造不出那半边
## 分支，而那条分支正是 [code]RealmSystem.realm_up[/code] 仍要保留的理由（见类文档）。[br]
func _init(p_table: Variant = null) -> void:
	_table = p_table if p_table is Dictionary and not (p_table as Dictionary).is_empty() \
			else RealmScript.realm_table


## 该境界进阶是否需要先渡劫（读境界表；表里没这一行 → false，调用方按「不可渡劫」处理）。
func requires_tribulation(p_realm: int) -> bool:
	var row: Dictionary = _row(p_realm)
	if row.is_empty():
		return false
	return bool(row.get(KEY_REQUIRES_TRIBULATION, true))


## 是否已是最高境界（无处可去——不是「修为不足」，也不存在渡劫）。
func at_max_realm(p_realm: int) -> bool:
	return p_realm >= _table.size()


## 一次完整判定——产出两行的文案 / 可用性 / 状态行 / 语义种类。[br]
## [br][param p_realm] 当前境界。[br]
## [param p_cultivation] 当前修为（只用于「还差多少」那句）。[br]
## [param p_can_break] 修为是否已满（来自 [code]CultivationSystem.get_breakthrough_status[/code]）。[br]
## [param p_trib_state] 渡劫状态机当前值（来自 [code]TribulationSystem.get_tribulation_status[/code]）。[br]
## [param p_trib_available] 渡劫系统是否可用（不可用时不得让玩家点下去没反应）。[br]
## [br][b]返回[/b]：[code]{kind, button_text, enabled, status_text, meditate_enabled,
## meditate_reason}[/code]。[br]
## [br][b]判定顺序[/b]（前三道各自盖住后面的）：到顶 → 修为不足 → 渡劫不可用 / 已在
## 渡劫流程中 → 可点。[br]
## [br][b]到顶时两行都禁用[/b]：没有下一境界可去——攒下的修为兑现不了（溢出属性丹的
## 发放挂在突破上），让玩家继续按「打坐」只是把修为倒进一个出不来的池子。[br]
## [br][b]修为不足时按钮文案仍然给「渡劫」[/b]：玩家在攒修为的路上就该看到这一关要走渡劫，
## 而不是攒满了才发现按钮换了名字。[br]
## [br]来源: GDD tribulation-system.md §1 触发条件 + §2 准备阶段、GDD
## cultivation-system.md §6/§7、ADR-0021 §check_tribulation_ready
## （「已在渡劫流程中则不可再触发」）。
func decide(p_realm: int, p_cultivation: int, p_can_break: bool,
		p_trib_state: int, p_trib_available: bool) -> Dictionary:
	if at_max_realm(p_realm):
		var top: Dictionary = _out(KIND_NONE, RulesScript.TEXT_BREAKTHROUGH, false,
				RulesScript.refusal_line(p_realm, p_cultivation))
		top["meditate_enabled"] = false
		top["meditate_reason"] = RulesScript.TEXT_MEDITATE_AT_MAX
		return top
	var needs: bool = requires_tribulation(p_realm)
	var kind: StringName = KIND_TRIBULATION if needs else KIND_BREAKTHROUGH
	var button_text: String = RulesScript.TEXT_TRIBULATION if needs \
			else RulesScript.TEXT_BREAKTHROUGH
	if not p_can_break:
		return _out(kind, button_text, false, RulesScript.refusal_line(p_realm, p_cultivation))
	if needs and not p_trib_available:
		return _out(kind, button_text, false, RulesScript.TEXT_TRIBULATION_UNAVAILABLE)
	if needs and p_trib_state != TribulationScript.TribulationState.NOT_READY:
		return _out(kind, button_text, false, RulesScript.TEXT_TRIBULATION_BUSY)
	# 可点时的状态行：渡劫那一关自己一句（说得清「点下去要打一场」），
	# 直接突破那一路仍走 [code]CultivationViewRules.status_line[/code]（同一套措辞）。
	var line: String = RulesScript.TEXT_CAN_TRIBULATE if needs \
			else RulesScript.status_line(p_realm, p_cultivation, true)
	return _out(kind, button_text, true, line)


## 组装判定结果（字段名唯一出处——调用方按名取，不按下标）。[br]
## [br][b]打坐那一行的两个字段有缺省值[/b]：它在所有非「到顶」的分支里都是可用的
## （修为满了也照样给——溢出进池是 GSM 既有逻辑），故只有到顶那道会覆盖它们。
func _out(p_kind: StringName, p_button_text: String, p_enabled: bool,
		p_status_text: String) -> Dictionary:
	return {
		"kind": p_kind,
		"button_text": p_button_text,
		"enabled": p_enabled,
		"status_text": p_status_text,
		"meditate_enabled": true,
		"meditate_reason": "",
	}


## 境界表里某一境界的整行（未知等级返回空字典——读取方据此判定无效）。
func _row(p_realm: int) -> Dictionary:
	if not _table.has(p_realm):
		return {}
	return _table[p_realm]
