class_name SettlementSectionText
extends RefCounted
## SettlementSectionText —— 结算屏两段文案的分工内核（拆分自 [SettlementRules]）。[br]
##
## [b]职责[/b]：把「选择段」与「入账段」的措辞与顺序固定下来——[br]
##   · [method loot_pick_title]：[b]前[/b]段（要挑的那一份）的标题，按实际候选数写
##     「N 选 1」/「这份直接带走」/空；[br]
##   · [method confirm_button_text]：同段按钮文案（1 项时是「直接带走」）；[br]
##   · [method granted_section_lines]：[b]后[/b]段（已入账清单）的段首标记；[br]
##   · [method pending_section_lines]：胜利面板上那段「尚未入账」预告的段首标记。[br]
## [b]不管什么[/b]：不判定胜负、不建面板、不做发放——发放与「发了什么」归
## [code]CombatSystem.grant_reward_selection[/code]，面板编排归 [code]SettlementPanel[/code]。[br]
## [br][b]为什么单独成文件[/b]：真机走查（DEBT-CUI-008-3）的症状是「两组奖励信息并列、
## 玩家分不清哪组已到手」，根因是文案长度恒写「三选一」且两段没有任何标记区分。
## 这些措辞是一个整块（阈值、空格、冒号位置都互相关联），与 [SettlementRules] 里
## 的几何计算/延迟窗口是两类事；[code]settlement_rules.gd[/code] 挤在一起时超出
## 300 行软上限（编码标准）。[br]
## [br][b]阈值只有一处[/b]：三个分档点（[code]<= 0[/code] / [code]== 1[/code] /
## [code]>= 2[/code]）都写在这里，[SettlementRules] 的提示行文案也走本类的
## [method has_choice]——分档阈值散成两处必然在某一侧漂移。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射。
##
## 来源: combat-ui-layout Story 008（AC-1/AC-3）、DEBT-CUI-008-3（两段并存）、
## 2026-11-23 真机走查（候选不足 3 项仍写「三选一」）、拆分自 settlement_rules。

## 选择段标题（候选 ≥ 2——「几选一」由实际候选数决定，不再恒写「三选一」）。
const TEXT_PICK_TITLE_MULTI: String = "本次奖励：%d 选 1"
## 选择段标题（候选恰好 1——[b]没有可选项[/b]，写「直接带走」而不是「1 选 1」）。
const TEXT_PICK_TITLE_ONE: String = "本次奖励：这份直接带走"
## 就绪期提示（候选恰好 1——没有第二个可选项，「点击选中」是无意义的指引）。
const TEXT_PICK_ONE_HINT: String = "这份没有别的选择，点确认带走"
## 确认按钮文案（候选恰好 1——按钮此时是「收下」，不是「从几项里挑一个」）。
const TEXT_CONFIRM_ONE: String = "直接带走"
## 入账段的段首标记（发放之后那一段——「这是已经到手的」）。
const TEXT_GRANTED_SECTION: String = "已入账："
## 未入账段的段首标记（发放之前那一段——「这些还没进兜里」）。
const TEXT_PENDING_SECTION: String = "本场奖励（尚未入账）："


## 选择段的标题——按[b]实际候选数[/b]写。[br]
## [br][param p_option_count] 候选数（[code]SettlementHostData.victory_options[/code]
## 的实际条数）。[br]
## [br][b]返回[/b]：0 项 → 空串（该段整体隐藏，提示行走「本次无战利品」）；
## 1 项 → [constant TEXT_PICK_TITLE_ONE]；≥2 项 → [constant TEXT_PICK_TITLE_MULTI]。[br]
## [br][b]为什么不再恒写「三选一」[/b]：上游只给 1~2 项时（[code]rewards.cards[/code]
## 是配置出来的，不是补足出来的），「三选一」与网格里的张数直接打架——真机走查里
## 最费解的一条。标题与网格同源，数量变了标题就跟着变。
static func loot_pick_title(p_option_count: int) -> String:
	if p_option_count <= 0:
		return ""
	if p_option_count == 1:
		return TEXT_PICK_TITLE_ONE
	return TEXT_PICK_TITLE_MULTI % p_option_count


## 候选是否构成「选择」（[b]≥2 项[/b]——1 项时只有「带走 / 跳过」，没有挑选）。[br]
## [br][b]为什么单独给一个判定[/b]：选择段的措辞与「有没有得选」是两件事，
## 提示行（[SettlementRules.victory_hint_text]）要按它决定说「点击选中」还是
## 「点确认带走」——判定散在各处迟早与 [method loot_pick_title] 的阈值分叉。
static func has_choice(p_option_count: int) -> bool:
	return p_option_count >= 2


## 确认按钮文案——按候选数分档（1 项时是「直接带走」）。[br]
## [br][param p_option_count] 候选数。[br]
## [br][b]与 [method loot_pick_title] 同一阈值[/b]：一处写「N 选 1」而按钮写「确认选择」，
## 玩家会以为漏了一步（「候选不足 3 项仍写三选一」正是同一类错）。
## [br][param p_multi_text] 候选 ≥2 时的按钮文案（调用方给——战利品面板用
## [code]SettlementRules.TEXT_CONFIRM_LOOT[/code]）。
static func confirm_button_text(p_option_count: int, p_multi_text: String) -> String:
	return TEXT_CONFIRM_ONE if p_option_count == 1 else p_multi_text


## 已入账清单的段首标记（[b]纯前缀拼接[/b]——[code]SettlementGrantLines.granted_lines[/code]
## 产出的行原样保留在其后）。[br]
## [br][param p_lines] 已入账行（来自发放返回值，[b]不重新计算[/b]）。[br]
## [br][b]返回[/b]：新数组——首行前置 [constant TEXT_GRANTED_SECTION]。[br]
## [br][b]为什么是「加标记」而不是「改文案」[/b]：那些行的字面量是发放结果的原文
## （发了什么、发没发成），改它等于让 UI 复述一遍发放逻辑；而玩家需要的只是「这一段
## 是已经到手的」——标记一个前缀就够，且真假由发放返回值决定，不是 UI 自己编的。[br]
## [br][b]空白输入不产生标记[/b]：没有任何行时加一个光秃秃的「已入账：」比不加更费解。
static func granted_section_lines(p_lines: Array) -> Array:
	return mark_first(p_lines, TEXT_GRANTED_SECTION)


## 未入账汇总段的段首标记（胜利面板的汇总行用——与「已入账」对照）。[br]
## [br][param p_lines] 汇总行（实得 / 未抽到 / 未入库）。[br]
## [br][b]返回[/b]：新数组——首行前置 [constant TEXT_PENDING_SECTION]；空输入原样返回。
static func pending_section_lines(p_lines: Array) -> Array:
	return mark_first(p_lines, TEXT_PENDING_SECTION)


## 给首行加段首标记（两段共用——[b]「加在哪一行、空输入怎么办」只写一遍[/b]）。
static func mark_first(p_lines: Array, p_mark: String) -> Array:
	var out: Array = []
	for line: Variant in p_lines:
		out.append(str(line))
	if out.is_empty():
		return out
	out[0] = p_mark + str(out[0])
	return out
