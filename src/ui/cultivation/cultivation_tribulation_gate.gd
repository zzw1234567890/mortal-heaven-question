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
## [br][b]判据读配置，不写死境界数字[/b]：渡劫规则表
## [code]TribulationRealmRules.TABLE[/code]（Feature 层单点）逐境界显式声明该境界进阶
## [b]是否必须渡劫[/b]——炼气~元婴四行各 true（合计正好 GDD §7 的「一局最多 4 次渡劫」），
## 化神那一行 false（最高境界没有更高处可去）。[br]
## [b]缺键不再等于「要渡劫」[/b]：本模块先问 [code]is_configured[/code]，
## 未配置的境界给的是[b]可读的「规则未配置」且不可点[/b]，而不是静默按 true 把玩家推进
## 渡劫（原先读境界表、缺键默认 true 的隐式约定已废——加境界忘了配键会表现为
## 「这一境界莫名其妙也要渡劫」，看不出是数据缺口）。[br]
## [b]唯一例外另立一处[/b]：GDD 登记的第 2 章苍玄古战场「重新筑基」（剧情系统直接
## [code]realm_up[/code]、不经渡劫）不是「炼气期不用渡劫」，而是「调用方不同」——
## 故它登记在 [code]TribulationRealmRules.STORY_BYPASS_REALMS[/code]，不翻境界 1 那行。[br]
## [b]越阶渡劫是玩家主动选项[/b]（GDD §6「非默认」）：本模块只回答「这一境界能不能越阶」
## （[code]cross_available[/code]），选中与否由界面上的开关承载——本模块不认识控件。[br]
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
## design/gdd/story-system.md §第2章·苍玄古战场、design/gdd/cultivation-system.md §6、
## ADR-0021 §check_tribulation_ready、ADR-0010 §realm_up 编排器、ADR-0031 §2、
## 先例 [code]node_interaction_rules.gd[/code]（判定与文案同一处收口）。

## 文案与判定单点（本模块不自己措辞——句子从这里取）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 渡劫系统枚举真理来源（TribulationState.NOT_READY——不写魔数 0）。
const TribulationScript := preload("res://src/feature/tribulation_system.gd")
## 渡劫规则表的唯一真理来源（哪一境界要渡劫、能不能越阶——本模块不自己抄一份）。
const RealmRulesScript := preload("res://src/feature/tribulation/tribulation_realm_rules.gd")

## 第二动作行的语义种类。[br]
## [br][b]调用方据此分派「点下去调哪个系统」[/b]：[constant KIND_TRIBULATION] 走
## [code]TribulationSystem.trigger_tribulation[/code] + 转渡劫场景，
## [constant KIND_BREAKTHROUGH] 走 [code]RealmSystem.realm_up[/code]。
const KIND_NONE: StringName = &"none"
const KIND_TRIBULATION: StringName = &"tribulation"
const KIND_BREAKTHROUGH: StringName = &"breakthrough"

## 该境界进阶是否需要渡劫的键名（规则表每行的必填键；缺键 = 未配置）。
## 取值口径与 [code]TribulationRealmRules.KEY_REQUIRES_TRIBULATION[/code] 同一处
## （这里是它的转发，别处引用任一名字都指同一个键）。
const KEY_REQUIRES_TRIBULATION: String = RealmRulesScript.KEY_REQUIRES_TRIBULATION

## 规则表（默认取 [code]TribulationRealmRules.TABLE[/code]；测试可注入同一形状的
## 覆盖表——只翻某一行的 [constant KEY_REQUIRES_TRIBULATION]，其余全部走真配置）。
var _table: Dictionary = {}


## 构造。[br]
## [br][param p_table] 规则表覆盖（空 / 非字典 = 用真配置）。[br]
## [br][b]为什么允许注入[/b]：注入侧要能构造出两种半边分支——「这一境界不需要渡劫」
## （剧情专属提升的形态）与「这一境界的规则没配」（数据缺口的形态）。真配置里
## 前者只以 [code]STORY_BYPASS_REALMS[/code] 的形态存在，后者一行都没有。[br]
func _init(p_table: Variant = null) -> void:
	_table = p_table if p_table is Dictionary and not (p_table as Dictionary).is_empty() \
			else RealmRulesScript.TABLE


## 该境界的渡劫规则是否已在表里配过（等级不在表内 / 行内缺键都算未配置）。[br]
## [br][b]必须先于 [method requires_tribulation] 被调用[/b]：「没配」与「配了 false」
## 是两回事，前者要给出可读的降级呈现，后者才允许直接突破。
func is_configured(p_realm: int) -> bool:
	if not _table.has(p_realm):
		return false
	return (_table[p_realm] as Dictionary).has(KEY_REQUIRES_TRIBULATION)


## 该境界进阶是否需要先渡劫（读规则表；[b]未配置时给 false[/b]——调用方先过
## [method is_configured]，本函数不替它决定未配置该怎么办）。[br]
## [br][b]为什么不默认 true[/b]：静默默认会把「加境界忘了配键」变成「这一境界也要
## 渡劫」——一个看上去完全合理的错，玩家绕不过去也说不清。
func requires_tribulation(p_realm: int) -> bool:
	if not is_configured(p_realm):
		return false
	return bool((_table[p_realm] as Dictionary).get(KEY_REQUIRES_TRIBULATION, false))


## 这一境界能否选越阶渡劫（挑战高一级天劫——GDD §6）。[br]
## [br][b]条件[/b]：该境界进阶需要渡劫（否则根本没有渡劫这一行）且「当前境界 + 1」
## 仍在境界表内（不能跳阶；到顶那一级无处可越）。[br]
## [br][b]为什么与 [param p_realm] 的修为无关[/b]：越阶是「打哪个 Boss」的选择，
## 不是「能不能打」——修为不足由第二动作行的可用性拦，开关本身不必跟着灰。
func cross_realm_available(p_realm: int) -> bool:
	if not is_configured(p_realm) or not requires_tribulation(p_realm):
		return false
	return RealmRulesScript.can_cross_realm(p_realm)


## 是否已是最高境界（无处可去——不是「修为不足」，也不存在渡劫）。
func at_max_realm(p_realm: int) -> bool:
	return RealmRulesScript.at_max_realm(p_realm)


## 一次完整判定——产出两行的文案 / 可用性 / 状态行 / 语义种类。[br]
## [br][param p_realm] 当前境界。[br]
## [param p_cultivation] 当前修为（只用于「还差多少」那句）。[br]
## [param p_can_break] 修为是否已满（来自 [code]CultivationSystem.get_breakthrough_status[/code]）。[br]
## [param p_trib_state] 渡劫状态机当前值（来自 [code]TribulationSystem.get_tribulation_status[/code]）。[br]
## [param p_trib_available] 渡劫系统是否可用（不可用时不得让玩家点下去没反应）。[br]
## [br][b]返回[/b]：[code]{kind, button_text, enabled, status_text, meditate_enabled,
## meditate_reason, cross_realm_available}[/code]。[br]
## [br][b]判定顺序[/b]（前四道各自盖住后面的）：到顶 → [b]规则未配置[/b] → 修为不足 →
## 渡劫不可用 / 已在渡劫流程中 → 可点。[br]
## [br][b]「规则未配置」单列一道[/b]（不是并进修为不足）：这一境界该不该渡劫是数据缺口，
## 与玩家攒没攒够修为无关——把它当成「修为不足」，玩家会一直打坐却永远等不到那扇门
## 打开（也看不出是配置漏了）。故给可读的 [code]TEXT_TRIBULATION_UNCONFIGURED[/code]
## 且不可点，让人一眼看得出要去补配置。[br]
## [br][b]到顶时两行都禁用[/b]：没有下一境界可去——攒下的修为兑现不了（溢出属性丹的
## 发放挂在突破上），让玩家继续按「打坐」只是把修为倒进一个出不来的池子。[br]
## [br][b]修为不足时按钮文案仍然给「渡劫」[/b]：玩家在攒修为的路上就该看到这一关要走渡劫，
## 而不是攒满了才发现按钮换了名字。[br]
## [br][b]越阶可用性随判定一起给[/b]（[code]cross_realm_available[/code]）：它是「这一境界
## 能不能越阶」的规则判定（GDD §6 只在 +1 存在时成立），与玩家选没选无关——界面上的开关
## 据此亮或灰，选中的值由界面持有并透传给渡劫入口（见 [code]CultivationActions[/code]）。[br]
## [br]来源: GDD tribulation-system.md §1 触发条件 + §2 准备阶段 + §6 越阶渡劫、
## GDD cultivation-system.md §6/§7、ADR-0021 §check_tribulation_ready
## （「已在渡劫流程中则不可再触发」）。
func decide(p_realm: int, p_cultivation: int, p_can_break: bool,
		p_trib_state: int, p_trib_available: bool) -> Dictionary:
	if at_max_realm(p_realm):
		var top: Dictionary = _out(p_realm, KIND_NONE, RulesScript.TEXT_BREAKTHROUGH, false,
				RulesScript.refusal_line(p_realm, p_cultivation))
		top["meditate_enabled"] = false
		top["meditate_reason"] = RulesScript.TEXT_MEDITATE_AT_MAX
		return top
	if not is_configured(p_realm):
		# 数据缺口——不冒充「修为不足」，也不冒充「要渡劫」。
		return _out(p_realm, KIND_NONE, RulesScript.TEXT_BREAKTHROUGH, false,
				RulesScript.TEXT_TRIBULATION_UNCONFIGURED)
	var needs: bool = requires_tribulation(p_realm)
	var kind: StringName = KIND_TRIBULATION if needs else KIND_BREAKTHROUGH
	var button_text: String = RulesScript.TEXT_TRIBULATION if needs \
			else RulesScript.TEXT_BREAKTHROUGH
	if not p_can_break:
		return _out(p_realm, kind, button_text, false,
				RulesScript.refusal_line(p_realm, p_cultivation))
	if needs and not p_trib_available:
		return _out(p_realm, kind, button_text, false,
				RulesScript.TEXT_TRIBULATION_UNAVAILABLE)
	if needs and p_trib_state != TribulationScript.TribulationState.NOT_READY:
		return _out(p_realm, kind, button_text, false, RulesScript.TEXT_TRIBULATION_BUSY)
	# 可点时的状态行：渡劫那一关自己一句（说得清「点下去要打一场」），
	# 直接突破那一路仍走 [code]CultivationViewRules.status_line[/code]（同一套措辞）。
	var line: String = RulesScript.TEXT_CAN_TRIBULATE if needs \
			else RulesScript.status_line(p_realm, p_cultivation, true)
	return _out(p_realm, kind, button_text, true, line)


## 组装判定结果（字段名唯一出处——调用方按名取，不按下标）。[br]
## [br][b]打坐那一行的两个字段有缺省值[/b]：它在所有非「到顶」的分支里都是可用的
## （修为满了也照样给——溢出进池是 GSM 既有逻辑），故只有到顶那道会覆盖它们。[br]
## [br][b]越阶字段在这里统一算[/b]（故本函数吃 [param p_realm]）：它不是某一条分支的
## 产物，而是按境界规则恒定成立的属性——放在各处自己填，迟早有一条分支漏给
## （漏了界面上的开关会永远灰着，且没有任何报错）。
func _out(p_realm: int, p_kind: StringName, p_button_text: String, p_enabled: bool,
		p_status_text: String) -> Dictionary:
	return {
		"kind": p_kind,
		"button_text": p_button_text,
		"enabled": p_enabled,
		"status_text": p_status_text,
		"meditate_enabled": true,
		"meditate_reason": "",
		"cross_realm_available": cross_realm_available(p_realm),
	}
