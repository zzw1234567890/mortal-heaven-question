class_name CombatPlayResult
extends RefCounted
## CombatPlayResult —— 出牌结果与拒绝原因的单一来源（combat-ui-interaction 001）。
##
## [b]为什么需要[/b]：[code]play_card()[/code] 此前只返回 [code]bool[/code]，
## 「费用不足」与「目标非法」「阶段不对」在调用方看来完全一样，UI 无从给出
## 提示文本——玩家点了没反应，只能猜。本模块把拒绝原因规范化成常量 + 中文
## 提示文本，出牌链路各层（[code]CombatCardResolver[/code] → [code]CombatSystem[/code]
## → [code]CombatPlayBridge[/code] → [code]CombatLayout[/code]）统一透传同一个
## 结果字典。[br]
## [br][b]返回形状[/b]（[method ok] / [method fail] 全库唯一构造处）：[br]
##   [code]{ok: bool, reason: StringName, message: String, context: Dictionary}[/code][br]
## [br][b]向后兼容[/b]：[code]play_card()[/code] 的 [code]bool[/code] 契约不变
## （[method is_ok] 即其实现口径），新增的是 [code]play_card_detailed()[/code]
## 一族——既有调用方零改动。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射。[br]
##
## @experimental
## 来源: ADR-0008 §出牌结算流程、ADR-0031、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md（AC-4）、
## story-005-target-selection.md。

## 成功哨兵（[code]reason[/code] 字段在成功时取此值，便于日志统一打印）。
const REASON_OK: StringName = &"ok"
## 非 PLAY 阶段（ADR-0008 §Phase 2 守卫）。
const REASON_WRONG_PHASE: StringName = &"wrong_phase"
## 卡牌实例 ID 在手牌/实例表中查不到。
const REASON_CARD_NOT_FOUND: StringName = &"card_not_found"
## 费用不足——[b]本轮要求的重点[/b]：拒绝且不扣费、不结算。
const REASON_COST_NOT_ENOUGH: StringName = &"cost_not_enough"
## 目标校验不通过（含「UI 侧解析出零个合法目标」）。
const REASON_BAD_TARGET: StringName = &"bad_target"
## 战斗系统未注入（桥 / 门面的降级态）。
const REASON_NO_COMBAT: StringName = &"no_combat"
## 系统侧拒绝了出牌，但[b]拿不到细分原因[/b]——只实现了 [code]bool[/code] 契约的
## 战斗系统（旧桩 / 未升级的替身）走这条路。文案刻意笼统：这里确实不知道是费用、
## 阶段还是目标，编一个具体原因（如「效果未生效」）会把真实原因藏起来。
const REASON_SYSTEM_REJECTED: StringName = &"system_rejected"


## 成功结果。[br]
## [param extra] 调用方附加字段（如 [code]targets[/code] / [code]cost[/code]）——
## [b]不覆盖[/b]三个标准键（同名键会被忽略，防止下游把 ok 改成 false 却仍报成功）。
static func ok(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": true, "reason": REASON_OK, "message": "", "context": {},
	}
	for key: Variant in extra:
		if result.has(key):
			continue
		result[key] = extra[key]
	return result


## 失败结果——[code]message[/code] 由 [method message_for] 从 [param context] 生成。[br]
## [param context] 同时原样带出（UI 若要自己组文案可取数字，不必解析 message）。
static func fail(reason: StringName, context: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"message": message_for(reason, context),
		"context": context,
	}


## 结果是否成功——[code]play_card()[/code] 的 [code]bool[/code] 契约唯一实现口径。
static func is_ok(result: Variant) -> bool:
	return result is Dictionary and bool((result as Dictionary).get("ok", false))


## 拒绝原因 → 面向玩家的中文提示文本。[br]
## [br][b]集中在此[/b]（control-manifest 禁止散落硬编码文案）：UI 侧只显示
## [code]result.message[/code]，不自己拼字符串——否则同一原因会在多处出现不同措辞。[br]
## [br]未知原因返回空串（[b]不臆造[/b]文案；调用方以空串判定「无提示可显示」）。
static func message_for(reason: StringName, context: Dictionary = {}) -> String:
	match reason:
		REASON_WRONG_PHASE:
			return "当前阶段不能出牌"
		REASON_CARD_NOT_FOUND:
			return "找不到该卡牌"
		REASON_COST_NOT_ENOUGH:
			return "灵力不足：需要 %d 点，当前 %d 点" % [
				int(context.get("cost", 0)), int(context.get("current", 0)),
			]
		REASON_BAD_TARGET:
			return "目标无效或已阵亡"
		REASON_NO_COMBAT:
			return "战斗系统未就绪"
		REASON_SYSTEM_REJECTED:
			return "无法出牌"
	return ""
