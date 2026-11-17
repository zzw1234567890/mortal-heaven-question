extends RefCounted
## ExplorationReentry —— 已通关地图的[b]重入编排[/b]：判资格 → 扣传送费 → 放行。[br]
## [br][b]本模块补的断链[/b]：[signal MapSelectScreen.reentry_requested] 自 S16-2
## 起就摆在那里，但[b]全库无消费者[/b]——玩家在重入确认弹窗上点「确认传送」，
## 扣费与进图两件事都不会发生（信号发进虚空，界面停在原地，点击看起来像失灵）。
## [br][b]为什么扣费在 Feature 层[/b]：扣灵石是玩法状态变更（control-manifest：
## UI 只发意图、显示系统返回的文案）。屏幕与弹窗只念 [code]message[/code]
## ——「灵石不足」这类措辞只有一处（同 [code]exploration_shop.gd[/code] 口径）。[br]
## [br][b]拒绝路径全部不扣费[/b]：系统不可用 / 未登记地图 / 尚未通关 / 不可重入 /
## 余额不足，全部在 [code]spend_resource[/code] 之前返回——与商店「拒绝在扣费之前」
## 同源，不存在「钱扣了但没进去」。[br]
## [br][b]费用取经济子模块的唯一公式[/b]：[method ExplorationEconomy.calculate_reentry_cost]
## （永久免费表 / 基价表 / 次数倍率都在那里）——本模块不重算一遍，也就不会出现
## 「卡片报价与实扣金额不一致」。[br]
## [br][b]放行之后不在这里生成地图[/b]：调用方拿到 [code]ok[/code] 后走既有的
## [code]ExplorationSystem.enter_map[/code]——新 seed、已访问重置、行动力回满、
## [code]entry_count[/code] 递增全在系统侧。于是 GDD §1「重入后行动力重置为上
## 限」与「费用按次递增」两条规则自动成立，本模块不各写一遍。[br]
## [br][b]奖励口径不在本模块[/b]：重复挑战只给基础奖励（不发首通彩头）由
## [code]ExplorationMapFlush._settle_boss_defeated[/code] 的
## [code]is_first_clear[/code] 分支保证——重入与首次进入走的是同一条进图路径，
## 不存在第二条发奖分支。[br]
##
## 来源: design/gdd/exploration-system.md §1 地图重入消耗规则 / §公式 10、
## design/gdd/exploration-ui-system.md §1 重入确认弹窗 + §6、
## ADR-0014 §决策 4 经济 / §决策 5 结算、ADR-0031 §2 零状态所有权。

## 地图配置目录（登记名与 [code]reentry_allowed[/code] 的唯一来源）。
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 拒绝原因词表（调用方据此分流——[code]message[/code] 是给玩家看的，本词表是给
## 测试与统计用的稳定键）。
const REASON_NO_SYSTEM: String = "探索系统不可用"
const REASON_UNKNOWN_MAP: String = "未知地图"
const REASON_NOT_CLEARED: String = "尚未通关"
const REASON_NOT_REENTERABLE: String = "不可重入"
const REASON_NO_RESOURCE: String = "资源系统不可用"
const REASON_NO_GSM: String = "存档不可用"
const REASON_NO_LING_SHI: String = "灵石不足"

## 面向玩家的文案（本地化豁免口径同各 [code]TEXT_*[/code]）。
const TEXT_UNKNOWN_MAP: String = "未知地图，无法传送"
const TEXT_NOT_CLEARED: String = "该地图尚未通关，直接进入即可"
const TEXT_NOT_REENTERABLE: String = "%s为剧情地图，通关后不可重入"
const TEXT_NO_RESOURCE: String = "资源系统不可用，无法传送"
const TEXT_NO_GSM: String = "存档不可用，无法传送"
const TEXT_NO_LING_SHI: String = "灵石不足：需要 %d，当前 %d"
const TEXT_NO_SYSTEM: String = "探索系统不可用，无法传送"
## 扣费成功的回报——写清「这是一次重入」，与首次进入区分。
const TEXT_ENTERED: String = "重入%s，消耗 %d 灵石"


## 重入一张已通关的地图——[b]本模块的唯一入口[/b]。[br]
## [br][param p_map_id] 目标地图 ID（历史写法经探明表别名归一）。[br]
## [param p_exploration] 探索系统（费用公式的持有者；缺失时拒绝）。[br]
## [param p_gsm] GSM（读 [code]map_states[/code] 判已通关；缺失时拒绝）。[br]
## [param p_resources] 资源系统（[code]spend_resource[/code] 的唯一出口；缺失时拒绝）。[br]
## [br][b]返回[/b]：[code]{ok, reason, message, cost, balance, map_id}[/code]。[br]
##   · [code]ok[/code] 为真时 [code]cost[/code] 是[b]实扣[/b]金额（永久免费地图为 0），
##     [code]balance[/code] 是扣后余额；[br]
##   · 为假时 [code]reason[/code] 取自上面的词表，[code]cost[/code] 恒为 0
##     （没扣就是没扣，不报一个「本该扣多少」的数字让调用方误会）。[br]
## [br][b]免费地图也走同一条路[/b]：0 费的重入照样过校验与扣费（扣 0 是一次
## 空操作），但同样放行——不因为「免费」就绕开资格判定，否则苍玄古战场会被放进去。
static func enter(p_map_id: StringName, p_exploration: Node, p_gsm: Node,
		p_resources: Node) -> Dictionary:
	var map_id: StringName = CatalogScript.canonical_id(p_map_id)
	if p_exploration == null or not p_exploration.has_method(&"calculate_reentry_cost"):
		return _fail(REASON_NO_SYSTEM, TEXT_NO_SYSTEM, map_id)
	if p_gsm == null:
		return _fail(REASON_NO_GSM, TEXT_NO_GSM, map_id)
	if not CatalogScript.has_map(map_id):
		return _fail(REASON_UNKNOWN_MAP, TEXT_UNKNOWN_MAP, map_id)

	var state: Dictionary = map_state(p_gsm, map_id)
	if not bool(state.get("is_first_clear", false)):
		return _fail(REASON_NOT_CLEARED, TEXT_NOT_CLEARED, map_id)
	if not reentry_allowed(map_id):
		return _fail(REASON_NOT_REENTERABLE,
				TEXT_NOT_REENTERABLE % display_name(map_id), map_id)
	if p_resources == null or not p_resources.has_method(&"spend_resource"):
		return _fail(REASON_NO_RESOURCE, TEXT_NO_RESOURCE, map_id)

	var cost: int = int(p_exploration.call(&"calculate_reentry_cost", map_id))
	var balance: int = balance_of(p_resources)
	if cost > balance:
		return _fail(REASON_NO_LING_SHI, TEXT_NO_LING_SHI % [cost, balance], map_id,
				balance)
	# 扣费——唯一一次写状态，且所有拒绝路径都已在上方返回
	if cost > 0 and not bool(p_resources.call(&"spend_resource", &"ling_shi", cost)):
		# 上面的余额预判与真实扣费之间可能隔着别的消费者（同一帧内的并发扣费）
		var after: int = balance_of(p_resources)
		return _fail(REASON_NO_LING_SHI, TEXT_NO_LING_SHI % [cost, after], map_id, after)
	return {
		"ok": true,
		"reason": "",
		"message": TEXT_ENTERED % [display_name(map_id), cost],
		"cost": cost,
		"balance": balance_of(p_resources),
		"map_id": map_id,
	}


## 该地图是否允许重入（探明表 [code]reentry_allowed[/code]，缺省 true）。[br]
## [br][b]缺省为允许[/b]：17 张地图里只有苍玄古战场显式写 false——表里不写满，
## 读取方承担缺省（同 [method ExplorationMapList._entry_for] 的口径）。
static func reentry_allowed(p_map_id: StringName) -> bool:
	var config: Dictionary = CatalogScript.MAPS.get(
			CatalogScript.canonical_id(p_map_id), {})
	return bool((config as Dictionary).get("reentry_allowed", true))


## 地图中文名（登记名优先，未登记回退地图 ID 字面量——不臆造名字）。
static func display_name(p_map_id: StringName) -> String:
	var map_id: StringName = CatalogScript.canonical_id(p_map_id)
	var config: Variant = CatalogScript.MAPS.get(map_id, {})
	var name: String = str((config as Dictionary).get("name", "")) if config is Dictionary else ""
	return name if not name.is_empty() else str(map_id)


## 当前灵石余额（资源系统不可用时 0——不臆造余额）。[br]
## [br][b]为什么公开[/b]：调用方扣费后要报「扣后余额」，与 [method enter] 内部
## 用的是同一处读取（两处各读一次必然出现口径差异）。
static func balance_of(p_resources: Node) -> int:
	if p_resources == null or not p_resources.has_method(&"get_resource"):
		return 0
	return int(p_resources.call(&"get_resource", &"ling_shi"))


## 某图在 [code]map_states[/code] 里的状态子字典（无记录 / 结构不对 → 空字典）。[br]
## [br][b]与 [code]ExplorationMapClear._state_of[/code] 同结构[/b]：两处读的是
## 同一份存档字段，写法保持一致（谁先改都得同步另一处，注释互为指路）。
static func map_state(p_gsm: Node, p_map_id: StringName) -> Dictionary:
	if p_gsm == null:
		return {}
	var states: Variant = p_gsm.get(&"exploration")
	if not (states is Dictionary):
		return {}
	var map_states: Variant = (states as Dictionary).get("map_states", {})
	if not (map_states is Dictionary):
		return {}
	var state: Variant = (map_states as Dictionary).get(p_map_id, {})
	return state if state is Dictionary else {}


## 拒绝结果（统一形状——[code]cost[/code] 恒 0，见 [method enter] 的返回说明）。[br]
## [br][param p_balance] 拒绝时的余额（只有「灵石不足」这一条给得出具体数；
## 其余拒绝路径连余额都没读到，按 0 如实返回而不是编一个）。
static func _fail(p_reason: String, p_message: String, p_map_id: StringName,
		p_balance: int = 0) -> Dictionary:
	return {"ok": false, "reason": p_reason, "message": p_message, "cost": 0,
			"balance": p_balance, "map_id": p_map_id}
