extends RefCounted
## TribulationRealmRules —— 「哪一个境界的进阶要走渡劫」的[b]显式配置单点[/b]。[br]
## [br][b]它回答一个问题[/b]：境界 L 的进阶要不要先打一场天劫战？[br]
## [br][b]为什么单独一张表，而不写进 [code]RealmSystem.realm_table[/code][/b]：[br]
##   · 境界表是 [b]Foundation 层的战力/上限配置[/b]（ADR-0010），渡劫归属 Feature 层——
##     往那张表里塞规则键会让基础数据依赖上玩法系统；[br]
##   · 境界表每行的键数被既有冒烟测试钉死（[code]test_realm_table_query.gd[/code]
##     AC-002 逐行断言 12 个属性），加键即改既有用例的断言口径；[br]
##   · 最要紧的一条：渡劫规则要能被[b]单独注入[/b]（剧情专属境界、测试半边分支），
##     与「境界数值」混在一张表里就分不开。[br]
## [br][b]为什么要「显式写满」而不是「缺键默认 true」[/b]：原先判定层读
## [code]realm_table[/code] 的 [code]requires_tribulation[/code] 键、缺键按 true 处理
## ——于是「这一行还没配」与「这一行配了要渡劫」在代码里长得一模一样，加一个新境界
## 忘了配键，玩家会莫名其妙被推进渡劫。【缺键 = 未配置】才看得出区别
## （见 [method is_configured] / [method requires_tribulation] 的返回值口径）。[br]
## [br][b]五个境界逐项写满[/b]（GDD tribulation-system.md §7「渡劫的整局次数」：
## 「一局游戏中，玩家最多可完成 4 次渡劫（炼气→筑基→金丹→元婴→化神）」）：[br]
##   · 境界 1-4（炼气/筑基/金丹/元婴）的进阶各需一次渡劫 → 恰好 4 次；[br]
##   · 境界 5（化神）是最高境界，没有更高处可去 → 不存在「进阶」，故 false
##     （玩家到顶后停在结算/最终 Boss，不由本系统处理）。[br]
## [br][b]唯一例外必须显式登记[/b]（GDD §7 那条⚠）：第 2 章苍玄古战场境界跌落后的
## 「重新筑基」由剧情系统直接调 [code]realm_up()[/code]，不经渡劫战。[b]这条例外
## 不翻境界 1 的那一行[/b]——常规的炼气→筑基照样要渡劫（否则 §7 的「最多 4 次」
## 就少了一次）。例外是「谁在调用」的差别，故登记为独立的
## [constant STORY_BYPASS_REALMS] 条目，由剧情系统按境界查
## [method story_bypass_reason] 自证其合法性。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是常量与纯函数——不读 GSM、不持节点、
## 不调任何系统；判定层（[code]cultivation_tribulation_gate.gd[/code]）读它，
## 本模块不认识界面。[br]
##
## 来源: design/gdd/tribulation-system.md §1 触发条件 / §6 越阶渡劫 / §7 整局次数
## + §7 唯一例外、design/gdd/story-system.md §第2章·苍玄古战场（§验收
## 「碎星外环修炼到 1000/1000，触发重新筑基事件，境界升回筑基（剧情突破，无渡劫战）」）、
## ADR-0010 §realm_up 编排器、ADR-0021 §check_tribulation_ready、ADR-0031 §2。

## 该境界进阶是否需要先渡劫的键名（本表每行[b]必写[/b]——缺键即未配置）。
const KEY_REQUIRES_TRIBULATION: String = "requires_tribulation"
## 该行为什么这么配的说明键（不是规则，只为「这张表为什么长这样」留痕）。
const KEY_NOTE: String = "note"

## 境界数量——与 [code]RealmSystem.realm_table[/code] 的档位一一对应
## （1 炼气 ~ 5 化神）。[br]
## [br][b]为什么这里另存一个数而不是读 RealmSystem[/b]：本模块在判定层被调用时
## 不持有任何系统引用（纯函数），而「有几个境界」直接决定 [method at_max_realm]
## 与越阶能否成立——读不到系统时它也必须答得出来。两张表同档位由
## 冒烟测试交叉钉住（见 [code]test_tribulation_realm_rules.gd[/code]）。
const REALM_COUNT: int = 5

## 逐境界的渡劫规则配置（1 炼气 ~ 5 化神）。[br]
## [br][b]每行都必须显式带 [constant KEY_REQUIRES_TRIBULATION][/b]——加境界时
## 漏写即被 [method is_configured] 判为未配置，界面会给出可读的「未配置」而不是
## 悄悄按「要渡劫」放玩家进去。[br]
const TABLE: Dictionary = {
	1: {
		KEY_REQUIRES_TRIBULATION: true,
		KEY_NOTE: "炼气→筑基——GDD §7 四次渡劫之一",
	},
	2: {
		KEY_REQUIRES_TRIBULATION: true,
		KEY_NOTE: "筑基→金丹——GDD §7 四次渡劫之一",
	},
	3: {
		KEY_REQUIRES_TRIBULATION: true,
		KEY_NOTE: "金丹→元婴——GDD §7 四次渡劫之一",
	},
	4: {
		KEY_REQUIRES_TRIBULATION: true,
		KEY_NOTE: "元婴→化神——GDD §7 四次渡劫之一",
	},
	5: {
		KEY_REQUIRES_TRIBULATION: false,
		KEY_NOTE: "化神为最高境界，无更高境界可去——进阶不存在，故不渡劫",
	},
}

## 不经渡劫的境界提升——[b]唯一例外[/b]（GDD §7 的⚠）。[br]
## [br]形状：境界等级 → 例外说明。等级是[b]提升后的目标境界[/b]（重新筑基 = 升回
## 境界 2 的那个动作由剧情发起）。[br]
## [br][b]为什么不直接翻 [constant TABLE] 里境界 1 的那一行[/b]：那样常规的
## 炼气→筑基也会变成「不需要渡劫」，与 §7「最多 4 次」直接冲突。例外的本质是
## [b]调用方不同[/b]（剧情系统而非玩家在渡劫台触发），不是该境界的规则不同。[br]
const STORY_BYPASS_REALMS: Dictionary = {
	2: "第2章苍玄古战场境界跌落后的「重新筑基」——剧情系统直接 realm_up()，不经渡劫战、无渡劫丹、无金卡奖励、无越阶判定",
}

## 越阶渡劫的跨度——高 [b]1[/b] 级（GDD §6「不能跳阶」：炼气期最多渡筑基劫，
## 不能跳过筑基直接渡金丹劫）。这个常量是「越阶挑战哪个雷灵」的唯一算式来源。
const CROSS_REALM_SPAN: int = 1


# ═══════════════════════════════════════════════════════════════════════════════
# 规则查询
# ═══════════════════════════════════════════════════════════════════════════════

## 境界 [param p_realm] 的进阶是否已在本表里配过。[br]
## [br][b]未配置的两种形态[/b]：等级不在表内（新增境界忘了加行）、行内缺
## [constant KEY_REQUIRES_TRIBULATION]（加了行忘了配值）——两者都必须能被
## 判定层看出来，故本函数先于 [method requires_tribulation] 被调用。[br]
## [br][b]刻意不读 [code]RealmSystem[/code][/b]：本模块判的是「渡劫规则表」，与
## 境界数值表是否含该等级无关（两张表各自演进，界面只认这一张）。
static func is_configured(p_realm: int) -> bool:
	if not TABLE.has(p_realm):
		return false
	return (TABLE[p_realm] as Dictionary).has(KEY_REQUIRES_TRIBULATION)


## 境界 [param p_realm] 的进阶是否需要渡劫。[br]
## [br][b]返回[/b]：已配置时给配置值；[b]未配置时给 false[/b]——调用方必须先过
## [method is_configured]（「未配置」不等于「不需要渡劫」，本函数不替调用方决定
## 未配置该怎么办，故不会静默返回 true 把玩家推进渡劫）。[br]
## [br][b]为什么要这个区分[/b]：GDD §7 的「最多 4 次渡劫」全靠这张表对，
## 静默默认 true 会让「漏配」表现为「炼气期也要渡劫」这种看似合理的错。
static func requires_tribulation(p_realm: int) -> bool:
	if not is_configured(p_realm):
		return false
	return bool((TABLE[p_realm] as Dictionary).get(KEY_REQUIRES_TRIBULATION, false))


## 该境界的配置说明（未配置或没写说明时为空串——本模块不臆造文案）。
static func note_for(p_realm: int) -> String:
	if not TABLE.has(p_realm):
		return ""
	return str((TABLE[p_realm] as Dictionary).get(KEY_NOTE, ""))


## 是否已是最高境界（没有更高处可去——不存在「进阶」，也不存在渡劫）。[br]
## [br][b]「到顶」与「未配置」是两件事[/b]：到顶是规则（化神期修为满了也突破不了），
## 未配置是数据缺口；界面上的措辞与可用性都不同，故分成两个判据。
static func at_max_realm(p_realm: int) -> bool:
	return p_realm >= REALM_COUNT


# ═══════════════════════════════════════════════════════════════════════════════
# 越阶渡劫（GDD §6）
# ═══════════════════════════════════════════════════════════════════════════════

## 境界 [param p_realm] 的玩家能否选择越阶渡劫。[br]
## [br][b]越阶是「提前挑战高一级的天劫」，不是跨级[/b]（GDD §6）：天劫 Boss 取
## 当前境界 + 1，胜则境界照常 +1。[b]不能跳阶[/b]——炼气最多渡筑基劫。故只有
## 「当前境界 + 1 仍在境界表内」时才成立（到顶的前一级不行，化神更不行）。[br]
## [br][b]为什么另判一次而不复用 [method at_max_realm][/b]：越阶的上界是
## 「+1 存在」，[method at_max_realm] 判的是「当前即最高」——两者在最后一级相同、
## 在其余各级也相同，但语义不同（一个是「能不能往上挑」，一个是「还有没有往上」），
## 合并会在将来加入「跳 2 级」之类的改动时把两处一起弄错。[br]
## [br][b]表外等级（0 / 负数）一律 false[/b]：不存在的境界没有「越阶」可言——
## 放过去会让 [method cross_realm_boss_realm] 算出一个看似合理的 Boss 境界
## （境界 0 越阶 → 挑战境界 1 的雷灵），而玩家根本不在那里。
static func can_cross_realm(p_realm: int) -> bool:
	if p_realm < 1 or at_max_realm(p_realm):
		return false
	return p_realm + CROSS_REALM_SPAN <= REALM_COUNT


## 越阶渡劫会挑战的天劫 Boss 境界（当前境界 + 1——GDD §6「天劫Boss = 当前境界+1 的雷灵」）。[br]
## [br][b]不能越阶时返回 0[/b]（不是 p_realm、也不是 p_realm+1）：调用方已先过
## [method can_cross_realm]，给 0 是为了让「忘了先判」的调用一眼看得出来，
## 而不是拿一个看似合理的境界值去打 Boss。
static func cross_realm_boss_realm(p_realm: int) -> int:
	if not can_cross_realm(p_realm):
		return 0
	return p_realm + CROSS_REALM_SPAN

# ═══════════════════════════════════════════════════════════════════════════════
# 唯一例外（剧情专属境界提升）
# ═══════════════════════════════════════════════════════════════════════════════

## 境界 [param p_realm] 的提升是否登记的「不经渡劫」例外；是则给出说明，否则空串。[br]
## [br][b]用途[/b]：剧情系统在直接调 [code]RealmSystem.realm_up()[/code] 之前查一下
## 自己这次提升是否在册——不在册就说明走错了路（常规提升必须经渡劫）。[br]
## [br][b]刻意不做成「[method requires_tribulation] 返回 false」[/b]：那会让常规的
## 炼气→筑基也免渡劫，见 [constant STORY_BYPASS_REALMS] 的说明。
static func story_bypass_reason(p_realm: int) -> String:
	return str(STORY_BYPASS_REALMS.get(p_realm, ""))


## 该提升是否属于剧情例外。
static func is_story_bypass(p_realm: int) -> bool:
	return STORY_BYPASS_REALMS.has(p_realm)
