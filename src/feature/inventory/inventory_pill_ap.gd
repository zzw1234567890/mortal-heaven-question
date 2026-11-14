extends RefCounted
## InventoryPillAp —— 丹药「回复行动力」的读取与结算半边（从
## [code]inventory_pill_use.gd[/code] 拆出）。[br]
## [br][b]为什么需要它[/b]：[code]InventoryPillUse.use_entry[/code] 此前只走治疗类效果
## （治疗量经 [code]CardEffectEvaluator[/code] 取 [code]healing[/code]），而
## [code]restore_ap[/code] 类丹药在评估层落 [code]UNEVALUABLE[/code]（词表里没有 AP
## 这一类别）——治疗量为 0，于是被当成「效用未参透」拒掉。GDD action-point-system.md
## §3 明写「回复丹药 | 按丹药类型 | 玩家在探索中使用丹药」，这条路径必须能走通。[br]
## [br][b]为什么不给词表加一个 AP 类别[/b]：行动力[b]不是战斗期属性[/b]——它住在
## [code]GSM.exploration[/code] 里，而 [code]EffectEvaluation[/code] 描述的是「一张卡
## 对某个战斗目标做什么」（目标 ID + 战斗快照）。把探索域资源塞进战斗评估结果，
## 会让 [code]EffectEvaluation[/code] 从此有两个域的读者，且 AI 干跑会开始看到
## 一个它无权处置的字段。故本模块[b]自行读模板[/b]，走的是同一套词表字符串
## （[code]effect_type[/code]）——只解释、不新增类别。[br]
## [br][b]写入走既有入口[/b]：[code]GSM.restore_action_points[/code]（第二层原子方法，
## 自带夹上限——GDD §8「回复时取 min(current + amount, max_action_points)」）。
## [method plan] 只为在[b]写之前[/b]算出「实际能回多少」，以便如实回报与提前拒绝
## （满行动力时不吞丹药），算式与那一层同口径。[br]
## [br][b]上限为 0 视为「上限未知」[/b]（同 [code]GSMExplorationWrites.restore_action_points]
## 的注记：出厂存档两个字段都是 0）——此时不夹取，按原值累加。[br]
## [br][b]失败不半完成[/b]：[b]先写行动力、再取出丹药[/b]；取出失败则按原值回滚。
## 与 [code]inventory_pill_use.gd[/code] 的治疗路径同一取舍——丹药是有限资源，
## 宁可丢掉一次回复也不能凭空吞掉玩家的物品。[br]
## [br][b]返回形状复用治疗路径的契约[/b]：[code]{ok, consumed, healed, message}[/code]
## ——面板只读 [code]message[/code] 与 [code]consumed[/code]（见
## [code]inventory_screens_host.gd[/code]），[code]healed[/code] 在这条路径上承载
## [b]实际回复的行动力[/b]（键名由共享契约固定，不为一条路径另立一套形状）。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_catalog / inventory_pill_use 同源口径。[br]
##
## 来源: design/gdd/action-point-system.md §3 行动力回复 / §8 边界 / §调优参数
## （丹药回复量 +2，范围 1-3）、inventory_pill_use.gd 类文档（读 → 计划 → 写回）、
## 先例 [code]combat_hp_carryover.gd[/code]（读写口分离）。

## 效果条目取列表（与评估层同一份「扁平字段 ↔ effects 列表」兼容通道）。
const ComposerScript := preload("res://src/feature/card_effect_engine/card_effect_composer.gd")

## 回复行动力的效果类型前缀（英文词表口径——与评估层的 [code]damage_reduce[/code]
## 等同类，写作 [code]restore_ap[/code]）。
const TYPE_RESTORE_AP: String = "restore_ap"
## 中文别名里必须出现的两个词——「回复」+「行动力」。[br]
## [br][b]为什么两个都要[/b]：裸「行动力」也出现在「行动力上限」这类表述里，
## 只认一个词会把上限类描述误判成回复效果；两个词同时出现才是动宾写法。[br]
## 与评估层「中文分支同样要先判」的口径一致（见
## [code]card_effect_evaluator._category_for[/code] 的注记）。
const ALIAS_AP: String = "行动力"
const ALIAS_AP_ACTION: String = "回复"

## 结果文案（本模块是这些句子的唯一来源）。[br]
## [br][b]「行动力已满」逐字保留[/b]：GDD action-point-system.md §验收标准
## 「GIVEN 使用回复丹药但行动力已满，WHEN 尝试使用，THEN 提示"行动力已满"」——
## 这句提示是验收项，不改成别的话术。
const TEXT_RESTORED: String = "%s已服下 · 回复 %d 点行动力"
const TEXT_FULL: String = "行动力已满，无需服用此丹。"
const TEXT_UNAVAILABLE: String = "此刻气机紊乱，丹药未能入腹——已原样留在行囊里。"
const TEXT_CONSUME_FAILED: String = "丹药未能从行囊中取出——行动力已复原。"


# ═══════════════════════════════════════════════════════════════════════════════
# 读取（纯函数——不读不写任何状态，GUT 直调可测）
# ═══════════════════════════════════════════════════════════════════════════════

## 该效果类型是否为「回复行动力」。
static func is_ap_effect(p_effect_type: String) -> bool:
	var text: String = p_effect_type.to_lower()
	if text.begins_with(TYPE_RESTORE_AP):
		return true
	return text.contains(ALIAS_AP) and text.contains(ALIAS_AP_ACTION)


## 模板的回复行动力总量（多条累加；无此类效果为 0）。[br]
## [br][b]只算「打出即生效」的条目[/b]：击杀触发类条目（[code]trigger="kill"[/code]）
## 在背包里没有触发时机可言，计入等于凭空多回一次（同评估层的触发时机分离口径）。[br]
## [br][b]读法与评估层同源[/b]：经 [method CardEffectComposer.effects_of] 取列表——
## 扁平字段的旧模板与 [code]effects[/code] 列表的新模板走同一条路。[br]
## [br][param p_template] 卡牌模板（CardTemplate 或同形 Dictionary）。[br]
## [br][b]返回[/b]：非负整数回复量（0 = 这枚丹不回行动力）。
static func amount_of(p_template: Variant) -> int:
	if p_template == null:
		return 0
	var total: int = 0
	for entry: Variant in ComposerScript.effects_of(p_template):
		if not bool(entry.call(&"is_play_triggered")):
			continue
		var data: Dictionary = entry.call(&"to_card_data")
		if not is_ap_effect(str(data.get("effect_type", ""))):
			continue
		total += maxi(int(data.get("value", 0)), 0)
	return total


# ═══════════════════════════════════════════════════════════════════════════════
# 计划（写之前算出实际回复量——纯查询）
# ═══════════════════════════════════════════════════════════════════════════════

## 结算计划。[br]
## [br][param p_gsm] GSM 引用（缺失时 [code]ok[/code] 为假）。[br]
## [param p_amount] 模板给出的回复量。[br]
## [br][b]返回[/b]：[code]{ok, restored, current, max_ap}[/code]——[code]restored[/code]
## 为 0 表示无缺口（调用方据此拒绝并保留丹药）；[code]current[/code] / [code]max_ap[/code]
## 是回滚用的原值快照。[br]
## [br][b]越界存档值按夹取口径参与[/b]：负数当前值视为 0（不放大），已超上限的当前值
## 不产生回复量（[code]restored[/code] 为 0 → 拒绝），与事件 RESTORE_AP / 灵泉同一口径。
static func plan(p_gsm: Node, p_amount: int) -> Dictionary:
	if p_gsm == null or p_amount <= 0:
		return {"ok": false, "restored": 0, "current": 0, "max_ap": 0}
	var exploration: Variant = p_gsm.get(&"exploration")
	if not (exploration is Dictionary):
		return {"ok": false, "restored": 0, "current": 0, "max_ap": 0}
	var current: int = int((exploration as Dictionary).get("action_points", 0))
	var max_ap: int = int((exploration as Dictionary).get("max_action_points", 0))
	var restored: int = p_amount
	if max_ap > 0:
		restored = mini(p_amount, maxi(max_ap - current, 0))
	return {"ok": true, "restored": maxi(restored, 0), "current": current, "max_ap": max_ap}


# ═══════════════════════════════════════════════════════════════════════════════
# 结算（写 → 取出 → 失败回滚）
# ═══════════════════════════════════════════════════════════════════════════════

## 使用一枚回复行动力的丹药。[br]
## [br][param p_gsm] GSM 引用（写入走它的第二层原子方法）。[br]
## [param p_template] 丹药模板（数值与名称都取自它）。[br]
## [param p_instance_id] 要取出的卡牌实例 ID。[br]
## [param p_consume] 取出回调 [code]func(instance_id) -> bool[/code]（由调用方提供——
## 本模块不认识收藏域的写入口，只负责「什么时候取、失败了怎么补」）。[br]
## [br][b]返回[/b]：[code]{ok, consumed, healed, message}[/code]（见类文档）。[br]
## [br][b]拒绝路径全在动手之前[/b]：系统不可用、无缺口两道门全过才开始写状态——
## 任何一道没过，存档与行囊一字未动。
static func use_pill(p_gsm: Node, p_template: Variant, p_instance_id: int,
		p_consume: Callable) -> Dictionary:
	var amount: int = amount_of(p_template)
	var state: Dictionary = plan(p_gsm, amount)
	if not bool(state.get("ok", false)):
		return failed(TEXT_UNAVAILABLE)
	var restored: int = int(state.get("restored", 0))
	if restored <= 0:
		return failed(TEXT_FULL)
	if not apply(p_gsm, restored):
		return failed(TEXT_UNAVAILABLE)
	if not bool(p_consume.call(p_instance_id)):
		rollback(p_gsm, state)
		return failed(TEXT_CONSUME_FAILED)
	return {
		"ok": true,
		"consumed": true,
		"healed": restored,
		"message": TEXT_RESTORED % [str(_name_of(p_template)), restored],
	}


## 按计划写回行动力——走 GSM 第二层原子方法，上限夹取由那一层负责。[br]
## [br][b]返回[/b]：是否真的写入（GSM 缺入口时为 false，调用方据此保留丹药）。
static func apply(p_gsm: Node, p_amount: int) -> bool:
	if p_gsm == null or not p_gsm.has_method(&"restore_action_points"):
		push_warning("InventoryPillAp: GSM 缺少 restore_action_points，丹药未能回复行动力")
		return false
	p_gsm.call(&"restore_action_points", p_amount)
	return true


## 回滚——把行动力按计划里的原值写回去（取出丹药失败时用，见类文档「失败不半完成」）。[br]
## [br][b]为什么不用 restore_action_points 的负数[/b]：那一层收负值会 push_error 并
## 原样返回——回滚是「设回原值」，正是 [code]set_exploration_ap[/code] 的语义。
static func rollback(p_gsm: Node, p_plan: Dictionary) -> void:
	if p_gsm == null or not p_gsm.has_method(&"set_exploration_ap"):
		return
	p_gsm.call(&"set_exploration_ap", int(p_plan.get("current", 0)),
			int(p_plan.get("max_ap", 0)))


## 失败结果（[code]consumed[/code] 恒为假——拒绝路径不消耗任何东西）。
static func failed(p_message: String) -> Dictionary:
	return {"ok": false, "consumed": false, "healed": 0, "message": p_message}


## 模板名称（缺失时回退空串——文案成了「已服下 · 回复 N 点行动力」，不臆造名字）。
static func _name_of(p_template: Variant) -> String:
	if p_template is Dictionary:
		return str((p_template as Dictionary).get("name", ""))
	if p_template != null:
		return str(p_template.get("name"))
	return ""
