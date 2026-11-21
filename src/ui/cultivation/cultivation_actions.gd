extends RefCounted
## CultivationActions —— 修炼室的[b]玩法接入半边[/b]：读状态、打坐、渡劫/突破、给拒绝原因。[br]
## [br][b]为什么单独一处[/b]：[code]cultivation_screen.gd[/code] 要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「调哪个系统、什么情况下不写、失败说什么」
## 与「控件怎么搭、焦点怎么走」是两件事（同 [code]meditation_node_presenter.gd[/code]
## ↔ [code]meditation_panel_screen.gd[/code] 的分工：接线归 Presenter，呈现归面板）。[br]
## [br][b]修为与境界各走既有唯一入口[/b]：[code]CultivationSystem.gain_cultivation[/code]
## 是修为获取的唯一入口，[code]RealmSystem.realm_up[/code] 是境界写入的唯一编排器
## （ADR-0010）——上限的重算由 [code]CultivationSystem[/code] 订阅
## [code]realm_changed[/code] 完成（GDD §6），本模块[b]不代算[/b]（同一条链上重算两次
## 必然漂移）。[br]
## [br][b]第二动作行有两个语义[/b]：修为满之后该走[b]渡劫[/b]（打一场天劫战才进境）
## 还是[b]直接突破[/b]（[code]realm_up[/code]），由
## [code]CultivationTribulationGate[/code] 按境界配置单点判定——本模块只按它的
## [code]kind[/code] 分派到对应系统，不自己猜。[br]
## [b]渡劫那条路以前是断的[/b]：本屏原先无论哪一境界都直调
## [code]realm_up[/code]，[code]TribulationSystem.trigger_tribulation[/code] 在生产代码里
## 一个调用者都没有——渡劫战打完了 [code]_on_battle_ended[/code] 因状态不是
## [code]IN_COMBAT[/code] 直接 return，[b]赢了也不进境[/b]。现在渡劫这条路先在修炼室
## 触发（状态机进 [code]PREPARING[/code]），再经 [code]SceneManager[/code] 转渡劫场景。[br]
## [br][b]拒绝路径不改任何状态[/b]：修为不足 / 已达最高境界 / 渡劫系统不可用 /
## 渡劫流程进行中，全都在写入之前返回，只把中文原因交回给屏幕（措辞由
## [code]CultivationViewRules[/code] 与判定层单点给出）。[br]
## [br][b]依赖从屏幕现取[/b]：[member cultivation_system] / [member realm_system] /
## [member tribulation_system] / [member gsm] / [member scene_manager] 是屏幕上的注入
## 字段（测试可替换），本模块每次现读——不在构造时缓存，否则「进树前注入」的那次替换
## 会被错过。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持有任何玩法数据，读经系统、写经
## 系统，自己只组织调用顺序与文案。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§5/§6、design/gdd/tribulation-system.md
## §1/§2/§7、ADR-0010 §realm_up 编排器、ADR-0021 §trigger_tribulation、ADR-0031 §2、
## 先例 [code]meditation_node_presenter.gd[/code]（同一套突破语义的接线）。

## 措辞与判定单点（打坐增量 / 状态行 / 拒绝原因 / 按钮可用性）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 第二动作行的语义判定单点（渡劫 vs 直接突破——纯函数）。
const GateScript := preload("res://src/ui/cultivation/cultivation_tribulation_gate.gd")
## 依赖解析（注入优先、否则 Autoload——与坊市 / 卡组编辑同口径）。
const SourcesScript := preload("res://src/ui/hud/deck_view_sources.gd")
## 渡劫状态枚举真理来源（默认态用——不写魔数 0）。
const TribulationScript := preload("res://src/feature/tribulation_system.gd")
## 渡劫入口共用件（顺序 + 收尾 + 回执——探索节点图那条入口同调它）。
const LaunchScript := preload("res://src/feature/tribulation/tribulation_launch.gd")
## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 屏幕（注入字段的持有者——本模块只读它的依赖字段）。
var _screen: Control = null


func _init(p_screen: Control) -> void:
	_screen = p_screen


# ═══════════════════════════════════════════════════════════════════════════════
# 只读
# ═══════════════════════════════════════════════════════════════════════════════

## 一屏所需的全部读数与判定（不可读时空字典——调用方据此走降级形态）。[br]
## [br][b]返回[/b]：[code]{current, max, realm, can_break, kind, button_text,
## enabled, status_text, meditate_enabled, meditate_reason}[/code]。[br]
## [br][b]为什么一次读齐[/b]：修为 / 境界 / 渡劫状态分属三个系统，但屏幕要的是
## 「一帧的完整画面」——分开读会让几段数字来自不同时刻，也会让按钮文案与状态行各说一套。[br]
## [br][b]判定不在这里[/b]：两行能不能点、写什么字，全部委托
## [code]CultivationTribulationGate.decide[/code]（本模块只负责把三处读数凑齐喂进去）。
func status() -> Dictionary:
	var cs: Node = cultivation_system()
	if cs == null or not cs.has_method(&"get_cultivation_status") \
			or not cs.has_method(&"get_breakthrough_status"):
		return {}
	var cultivation: Dictionary = cs.call(&"get_cultivation_status")
	var breakthrough: Dictionary = cs.call(&"get_breakthrough_status")
	var realm: int = int(breakthrough.get("realm", 0))
	var current: int = int(cultivation.get("current", 0))
	var decision: Dictionary = _decide(realm, current,
			bool(breakthrough.get("can_breakthrough", false)))
	return {
		"current": current,
		"max": int(cultivation.get("max", 0)),
		"realm": realm,
		"can_break": bool(breakthrough.get("can_breakthrough", false)),
		"kind": decision.get("kind", GateScript.KIND_NONE),
		"button_text": str(decision.get("button_text", RulesScript.TEXT_BREAKTHROUGH)),
		"enabled": bool(decision.get("enabled", false)),
		"status_text": str(decision.get("status_text", "")),
		"meditate_enabled": bool(decision.get("meditate_enabled", true)),
		"meditate_reason": str(decision.get("meditate_reason", "")),
		"cross_realm_available": bool(decision.get("cross_realm_available", false)),
	}


## 只读的突破请求（系统缺失 / 无该方法时返回空字典——调用方据此走降级）。
func request() -> Dictionary:
	var cs: Node = cultivation_system()
	if cs == null or not cs.has_method(&"request_breakthrough"):
		return {}
	var raw: Variant = cs.call(&"request_breakthrough")
	return raw if raw is Dictionary else {}


## 当前灵石（只读——本屏不持有资源，[code]ResourceSystem[/code] 才是写入口）。
func ling_shi() -> int:
	var store: Node = gsm()
	if store == null:
		return 0
	var player: Variant = store.get(&"player")
	if not (player is Dictionary):
		return 0
	var resources: Variant = (player as Dictionary).get("resources", {})
	if not (resources is Dictionary):
		return 0
	return int((resources as Dictionary).get("ling_shi", 0))


# ═══════════════════════════════════════════════════════════════════════════════
# 三个动作（返回面向玩家的中文回执——屏幕原样写进提示行）
# ═══════════════════════════════════════════════════════════════════════════════

## 打坐——经 [code]CultivationSystem.gain_cultivation[/code] 加修为（唯一入口）。[br]
## [br][b]修为满后照样给[/b]：溢出进 [code]overflow_pool[/code]（GSM 既有逻辑），
## 本模块不做判断——「满了还能不能打坐」是玩法问题，不是界面的问题。
func meditate() -> String:
	var cs: Node = cultivation_system()
	if cs == null or not cs.has_method(&"gain_cultivation"):
		return RulesScript.TEXT_UNAVAILABLE
	cs.call(&"gain_cultivation", RulesScript.MEDITATE_AMOUNT, RulesScript.MEDITATE_SOURCE)
	return RulesScript.meditate_done_line(RulesScript.MEDITATE_AMOUNT)


## 第二动作行——按判定层的 [code]kind[/code] 分派（渡劫 / 直接突破，见类文档）。[br]
## [br][param p_cross_realm] 玩家是否勾了「越阶渡劫」（GDD §6 主动选项）。
## [b]默认 false[/b]——不勾就是普通渡劫，与共用件的默认同一口径。[br]
## [br][b]返回[/b]：面向玩家的中文回执——渡劫写明即将前往，直接突破写明境界跃迁，
## 被拒写明原因。
func breakthrough(p_cross_realm: bool = false) -> String:
	var req: Dictionary = request()
	if req.is_empty():
		return RulesScript.TEXT_UNAVAILABLE
	var realm: int = int(req.get("current_realm", 0))
	var current: int = int(req.get("cultivation", 0))
	var decision: Dictionary = _decide(realm, current,
			bool(req.get("can_breakthrough", false)))
	if not bool(decision.get("enabled", false)):
		return str(decision.get("status_text", RulesScript.refusal_line(realm, current)))
	if StringName(decision.get("kind", GateScript.KIND_NONE)) == GateScript.KIND_TRIBULATION:
		return start_tribulation(p_cross_realm)
	return _raise_realm(realm)


## 第二动作行当前的语义（[code]&"tribulation"[/code] / [code]&"breakthrough"[/code] /
## [code]&"none"[/code]）。[br]
## [br][b]为什么独立于 [method status] 再查一次[/b]：判断与取值只有一处来源
## （[code]CultivationTribulationGate[/code]）；把上一次的结果记在字段里就等于把同一件
## 事存两份，读数还会随打坐漂移（同 [method refusal] 的口径）。
func kind() -> StringName:
	var req: Dictionary = request()
	if req.is_empty():
		return GateScript.KIND_NONE
	var decision: Dictionary = _decide(int(req.get("current_realm", 0)),
			int(req.get("cultivation", 0)), bool(req.get("can_breakthrough", false)))
	return StringName(decision.get("kind", GateScript.KIND_NONE))


## 一次「不改变状态」的拒绝原因——按行取（[param p_row] 0 打坐 / 其余 = 第二动作行）。[br]
## [br][b]为什么再查一次而不是记着上一次[/b]：判断与措辞只有一处来源；缓存一份
## 「上次为什么不能动」就等于把同一件事记两遍，数字还会随打坐漂移。[br]
## [br][b]禁用行同样给原因[/b]：禁用的 [Button] 不发 [signal Button.pressed]，
## 不补这条路玩家就只看到「点了没反应」（同坊市买不起的行）。[br]
## [br][b]覆盖的不只是「修为不足」[/b]：渡劫系统不可用、渡劫流程进行中、到顶时打坐
## 无处可用——它们同样是「灰着的行」，各有各的说法。[br]
## [br][b]打坐那一行常驻可用[/b]：修为满了照样给（溢出进池是 GSM 既有逻辑），
## 故它只有「到顶」一种拒绝理由——由判定层在 [code]meditate_reason[/code] 里给出。
func refusal(p_row: int = 1) -> String:
	var req: Dictionary = request()
	if req.is_empty():
		return RulesScript.TEXT_UNAVAILABLE
	var realm: int = int(req.get("current_realm", 0))
	var current: int = int(req.get("cultivation", 0))
	var decision: Dictionary = _decide(realm, current,
			bool(req.get("can_breakthrough", false)))
	if p_row == 0:
		return str(decision.get("meditate_reason", ""))
	return str(decision.get("status_text", RulesScript.refusal_line(realm, current)))


## 触发渡劫并请求转往渡劫场景（本屏的渡劫入口）。[br]
## [br][b]顺序不可颠倒[/b]：先 [code]trigger_tribulation[/code] 把状态机推进
## [code]PREPARING[/code]，再转场——渡劫场景进战时 [code]start_tribulation_combat[/code]
## 会校验这个状态，反过来做就会降级成一场普通战斗（赢了也不进境）。[br]
## [br][b]顺序与收尾都委托 [code]TribulationLaunch.launch[/code][/b]：探索节点图那条
## 入口（渡劫台）要的是同一段逻辑——写在两处就必然有一天只改对一处（节点图原先正是
## 只转场、从不触发，玩家从地图进渡劫是空打一场）。故本方法只负责「取依赖、把结果句
## 交回屏幕」，不再自己组织调用序列。[br]
## [br][b]触发被状态机拒绝时不谎报成功[/b]：共用件会回读一次状态，没进
## [code]PREPARING[/code] 就把「流程进行中」那句交回去。[br]
## [br][b]转场不可用 / 被拒时把状态退回去[/b]：已进 [code]PREPARING[/code] 却去不了渡劫
## 场景，会把玩家永久卡在「渡劫流程进行中」——共用件在两路都用
## [code]cancel_tribulation[/code] 收尾。[br]
## [br][b]越阶由玩家的勾选决定[/b]（GDD §6 主动选项）：[param p_cross_realm] 由屏幕从
## 勾选框读来原样透传，[b]本模块不自己判能不能越阶[/b]——那条规则在
## [code]CultivationTribulationGate.cross_realm_available[/code]（判定层单点），
## 界面按它决定要不要露出那个勾选框。状态机对越界（跳 2 级）有自己的一道校验，
## 真被拒时共用件的回读会给出「流程进行中」的中文回执，不会静默失败。[br]
## [br]来源: GDD tribulation-system.md §1 地图渡劫点 + §2 准备阶段 + §6 越阶渡劫、
## ADR-0021 §trigger_tribulation / §cancel_tribulation。
func start_tribulation(p_cross_realm: bool = false) -> String:
	var result: Dictionary = LaunchScript.launch(tribulation_system(), scene_manager(),
			SceneManagerScript.SceneID.CULTIVATION, p_cross_realm)
	return str(result.get("text", RulesScript.TEXT_TRIBULATION_UNAVAILABLE))


## 请 [code]RealmSystem.realm_up[/code] 动手（不走渡劫的境界——见类文档）。[br]
## [br][b]本方法的调用者已先问过判定层[/b]：到顶与修为不足都在上面拦住了，
## 这里不再重复判断（同一条规则写两遍就必然漂移）。
func _raise_realm(p_realm: int) -> String:
	var rs: Node = realm_system()
	if rs == null or not rs.has_method(&"realm_up"):
		return RulesScript.TEXT_UPGRADE_UNAVAILABLE
	rs.call(&"realm_up", p_realm)
	return RulesScript.breakthrough_done_line(p_realm)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 判定层调用——把三处读数喂给 [code]CultivationTribulationGate.decide[/code]。[br]
## [br][b]「可用」判的是能力不是存在[/b]：拿得到一个对象不等于它能干活——桩替身 / 半个
## 系统都可能是非 null。故按 [code]has_method[/code]（触发与查状态两个方法）判，
## 判不过就让按钮灰着并给可读原因，而不是让玩家点下去什么都没发生。[br]
## [br][b]渡劫状态读不到时按 NOT_READY 传[/b]：此时 [code]p_trib_available[/code] 已是
## false，判定层会在状态这一道之前就给「渡劫系统不可用」，传进去的值不会被用到。
func _decide(p_realm: int, p_cultivation: int, p_can_break: bool) -> Dictionary:
	return _gate().call(&"decide", p_realm, p_cultivation, p_can_break,
			int(_tribulation_status().get("state", TribulationScript.TribulationState.NOT_READY)),
			_is_tribulation_usable())


## 渡劫系统是否真的能用（两个方法齐备——见 [method _decide]）。
func _is_tribulation_usable() -> bool:
	var ts: Node = tribulation_system()
	return ts != null and ts.has_method(&"trigger_tribulation") \
			and ts.has_method(&"get_tribulation_status")


## 渡劫状态摘要（系统缺失 / 无该方法时空字典）。
func _tribulation_status() -> Dictionary:
	var ts: Node = tribulation_system()
	if ts == null or not ts.has_method(&"get_tribulation_status"):
		return {}
	var raw: Variant = ts.call(&"get_tribulation_status")
	return raw if raw is Dictionary else {}


## 判定层实例（无状态、纯函数——每次新建即可，不持有跨调用状态）。[br]
## [br][b]境界表可经屏幕注入[/b]（[code]tribulation_table[/code] 字段，空 = 真配置）：
## 「不需要渡劫的境界」在真配置里一行都没标（GDD 只在故事线里留了一处例外），
## 不注入就构造不出那半边分支——测试据此覆盖「保持原「突破」」这条路。
func _gate() -> RefCounted:
	return GateScript.new(_injected(&"tribulation_table"))


# ═══════════════════════════════════════════════════════════════════════════════
# 系统接入（每次现取——见类文档「依赖从屏幕现取」）
# ═══════════════════════════════════════════════════════════════════════════════

func cultivation_system() -> Node:
	return SourcesScript.resolve(_injected(&"cultivation_system"), &"CultivationSystem")


func realm_system() -> Node:
	return SourcesScript.resolve(_injected(&"realm_system"), &"RealmSystem")


func tribulation_system() -> Node:
	return SourcesScript.resolve(_injected(&"tribulation_system"), &"TribulationSystem")


func gsm() -> Node:
	return SourcesScript.resolve(_injected(&"gsm"), &"GameStateManager")


func scene_manager() -> Node:
	return SourcesScript.resolve(_injected(&"scene_manager"), &"SceneManager")


## 屏幕上的注入字段（屏幕已释放 / 字段不存在时为 null——不臆造替身）。
func _injected(p_field: StringName) -> Variant:
	if _screen == null or not is_instance_valid(_screen):
		return null
	return _screen.get(p_field)
