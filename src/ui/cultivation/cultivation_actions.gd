extends RefCounted
## CultivationActions —— 修炼室的[b]玩法接入半边[/b]：读状态、打坐、突破、给拒绝原因。[br]
## [br][b]为什么单独一处[/b]：[code]cultivation_screen.gd[/code] 要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「调哪个系统、什么情况下不写、失败说什么」
## 与「控件怎么搭、焦点怎么走」是两件事（同 [code]meditation_node_presenter.gd[/code]
## ↔ [code]meditation_panel_screen.gd[/code] 的分工：接线归 Presenter，呈现归面板）。[br]
## [br][b]修为与境界各走既有唯一入口[/b]：[code]CultivationSystem.gain_cultivation[/code]
## 是修为获取的唯一入口，[code]RealmSystem.realm_up[/code] 是境界写入的唯一编排器
## （ADR-0010）——上限的重算由 [code]CultivationSystem[/code] 订阅
## [code]realm_changed[/code] 完成（GDD §6），本模块[b]不代算[/b]（同一条链上重算两次
## 必然漂移）。[br]
## [br][b]突破是「先问能不能，再请编排器动手」[/b]：[code]request_breakthrough()[/code]
## 是只读查询（返回能不能突破与当前数值），一行都不写；写入只有
## [code]realm_up(old)[/code] 一处。且它[b]只看修为满没满[/b]——到顶时仍返回 true，
## 故「未到顶」这道闸由 [code]CultivationViewRules.allows_breakthrough[/code] 补上
## （不补就会变成「按钮能点、点了报错」）。[br]
## [br][b]拒绝路径不改任何状态[/b]：修为不足 / 已达最高境界都在写入之前返回，只把中文
## 原因交回给屏幕（措辞由 [code]CultivationViewRules[/code] 单点给出）。[br]
## [br][b]依赖从屏幕现取[/b]：[member cultivation_system] / [member realm_system] /
## [member gsm] 是屏幕上的注入字段（测试可替换），本模块每次现读——不在构造时缓存，
## 否则「进树前注入」的那次替换会被错过。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持有任何玩法数据，读经系统、写经
## 系统，自己只组织调用顺序与文案。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§5/§6、ADR-0010 §realm_up 编排器、
## ADR-0031 §2、先例 [code]meditation_node_presenter.gd[/code]（同一套突破语义的接线）。

## 措辞与判定单点（打坐增量 / 状态行 / 拒绝原因 / 按钮可用性）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 依赖解析（注入优先、否则 Autoload——与坊市 / 卡组编辑同口径）。
const SourcesScript := preload("res://src/ui/hud/deck_view_sources.gd")

## 屏幕（注入字段的持有者——本模块只读它的三个依赖字段）。
var _screen: Control = null


func _init(p_screen: Control) -> void:
	_screen = p_screen


# ═══════════════════════════════════════════════════════════════════════════════
# 只读
# ═══════════════════════════════════════════════════════════════════════════════

## 一屏所需的全部数字（不可读时空字典——调用方据此走降级形态）。[br]
## [br][b]返回[/b]：[code]{current, max, realm, can_break}[/code]。[br]
## [br][b]为什么两个查询一起读[/b]：修为与境界分属两个系统，但屏幕要的是「一帧的
## 完整画面」——分开读会让两段数字来自不同时刻。
func status() -> Dictionary:
	var cs: Node = cultivation_system()
	if cs == null or not cs.has_method(&"get_cultivation_status") \
			or not cs.has_method(&"get_breakthrough_status"):
		return {}
	var cultivation: Dictionary = cs.call(&"get_cultivation_status")
	var breakthrough: Dictionary = cs.call(&"get_breakthrough_status")
	return {
		"current": int(cultivation.get("current", 0)),
		"max": int(cultivation.get("max", 0)),
		"realm": int(breakthrough.get("realm", 0)),
		"can_break": bool(breakthrough.get("can_breakthrough", false)),
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
# 两个动作（返回面向玩家的中文回执——屏幕原样写进提示行）
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


## 突破——先问能不能，再请 [code]RealmSystem.realm_up[/code] 动手（见类文档）。[br]
## [br][b]返回[/b]：面向玩家的中文回执——成功写明境界跃迁，被拒写明原因。
func breakthrough() -> String:
	var req: Dictionary = request()
	if req.is_empty():
		return RulesScript.TEXT_UNAVAILABLE
	var realm: int = int(req.get("current_realm", 0))
	if not RulesScript.allows_breakthrough(realm, bool(req.get("can_breakthrough", false))):
		return RulesScript.refusal_line(realm, int(req.get("cultivation", 0)))
	var rs: Node = realm_system()
	if rs == null or not rs.has_method(&"realm_up"):
		return RulesScript.TEXT_UPGRADE_UNAVAILABLE
	rs.call(&"realm_up", realm)
	return RulesScript.breakthrough_done_line(realm)


## 一次「不改变状态」的拒绝原因（复用突破查询的只读口径）。[br]
## [br][b]为什么再查一次而不是记着上一次[/b]：判断与措辞只有一处来源；缓存一份
## 「上次为什么不能突破」就等于把同一件事记两遍，数字还会随打坐漂移。[br]
## [br][b]禁用行同样给原因[/b]：禁用的 [Button] 不发 [signal Button.pressed]，
## 不补这条路玩家就只看到「点了没反应」（同坊市买不起的行）。
func refusal() -> String:
	var req: Dictionary = request()
	if req.is_empty():
		return RulesScript.TEXT_UNAVAILABLE
	return RulesScript.refusal_line(int(req.get("current_realm", 0)),
			int(req.get("cultivation", 0)))


# ═══════════════════════════════════════════════════════════════════════════════
# 系统接入（每次现取——见类文档「依赖从屏幕现取」）
# ═══════════════════════════════════════════════════════════════════════════════

func cultivation_system() -> Node:
	return SourcesScript.resolve(_injected(&"cultivation_system"), &"CultivationSystem")


func realm_system() -> Node:
	return SourcesScript.resolve(_injected(&"realm_system"), &"RealmSystem")


func gsm() -> Node:
	return SourcesScript.resolve(_injected(&"gsm"), &"GameStateManager")


## 屏幕上的注入字段（屏幕已释放 / 字段不存在时为 null——不臆造替身）。
func _injected(p_field: StringName) -> Variant:
	if _screen == null or not is_instance_valid(_screen):
		return null
	return _screen.get(p_field)
