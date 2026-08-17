## TriggerChainState —— 触发链深度追踪状态（纯逻辑辅助类）。
##
## 承载触发链管理的三个状态字段（ADR-0009 L142-144）：
##   - [member root_card_instance_id]——触发链根卡牌（玩家打出的第一张卡）
##   - [member current_depth]——当前深度（从 1 开始计）
##   - [member visited_card_ids]——已触发过的 card_instance_id 集合（Dictionary[int, bool]）
##
## [b]纯逻辑、无副作用[/b]——检查深度与循环，返回决策枚举；不产生日志/信号
## （日志与信号由调用方 ResolutionStack.resolve_all / CardEffectEngine 负责）。
## 检查单元是 [param card_instance_id]（int），与 [EffectBase] 解耦——可独立单测。
##
## [b]深度语义[/b]（ADR-0009 L146-161）：[method check_and_record] 每次调用
## [member current_depth] 无条件 +1（含被循环跳过者），超过 [constant MAX_DEPTH] 即截断。
## 扇出分支共享同一计数器——总节点数（非最深分支）达到 11 即截断。
##
## 来源: ADR-0009 §触发链管理。
class_name TriggerChainState
extends RefCounted


# === 常量 =========================================================================

## 触发链硬限制深度——GDD §边缘情况 / ADR-0009 L150。
const MAX_DEPTH := 10


# === 检查决策枚举 =================================================================

## check_and_record 的返回决策。
enum CheckResult {
	RESOLVE = 0,        ## 可结算——深度未超限且未循环
	DEPTH_EXCEEDED = 1, ## 深度超限——第 11 层截断
	ALREADY_VISITED = 2, ## 循环检测——同一 card_instance_id 已触发过
}


# === 追踪状态 =====================================================================

## 触发链根卡牌——玩家打出的第一张卡（WARN 日志 root_card_id）。
var root_card_instance_id: int = 0

## 当前深度——从 1 开始计（每 pop 一个效果 +1）。
var current_depth: int = 0

## 已触发过的 card_instance_id 集合。[code]{card_instance_id: true}[/code]。
## GDScript 4.x 无内置 Set 类型——字典键 O(1) 查找（ADR-0009 L143）。
var visited_card_ids: Dictionary[int, bool] = {}

## 已结算效果的 card_instance_id 序列——用于 WARN 日志 [code]chain=A→B→...→K[/code]。
var chain: Array[int] = []

## 触发深度超限的效果 card_instance_id（第 11 层截断者）。-1 = 尚未溢出。
## 溢出节点不在 [member chain] 中（chain 仅记录已结算者），但 AC-003 字面 [code]chain=<A→B→...→K>[/code]
## 要求日志包含截断者 K——故单独记录，[method build_overflow_message] 时追加到链尾。
var overflowing_card_id: int = -1


# === 检查逻辑 =====================================================================

## 检查并记录一个 card_instance_id。[br]
## [br][b]顺序[/b]（严格遵循 ADR-0009 L147-158）：先 depth+1 判超限，再判循环，最后记录。[br]
## [br][param card_instance_id] 待检查的效果来源卡牌实例 ID。[br]
## [br][b]返回[/b]: [enum CheckResult]——RESOLVE / DEPTH_EXCEEDED / ALREADY_VISITED。
func check_and_record(card_instance_id: int) -> CheckResult:
	current_depth += 1
	if current_depth > MAX_DEPTH:
		overflowing_card_id = card_instance_id  # 记录截断者 K（供 WARN 日志）
		return CheckResult.DEPTH_EXCEEDED
	if visited_card_ids.get(card_instance_id, false):
		return CheckResult.ALREADY_VISITED
	visited_card_ids[card_instance_id] = true
	chain.append(card_instance_id)
	return CheckResult.RESOLVE


## 生成深度超限 WARN 消息——严格匹配 AC-003 格式。[br]
## [br][b]chain 内容[/b]：已结算链（[member chain]）+ 截断者（[member overflowing_card_id]）——[code]A→B→...→K[/code]。[br]
## [br]格式：[code][CardEffectEngine] Trigger chain depth exceeded: max=10, root_card_id=<ID>, chain=<A→B→...→K>[/code]
func build_overflow_message() -> String:
	var chain_parts: Array = []
	for id in chain:
		chain_parts.append(str(id))
	if overflowing_card_id != -1:
		chain_parts.append(str(overflowing_card_id))
	var chain_str: String = "→".join(chain_parts)
	return "[CardEffectEngine] Trigger chain depth exceeded: max=%d, root_card_id=%d, chain=%s" % [
		MAX_DEPTH, root_card_instance_id, chain_str,
	]


## 是否已触发过该 card_instance_id。
func is_visited(card_instance_id: int) -> bool:
	return visited_card_ids.get(card_instance_id, false)


## 重置追踪状态（深度清零、visited/chain/overflowing 清空）——用于下一触发链。
func reset() -> void:
	current_depth = 0
	visited_card_ids.clear()
	chain.clear()
	overflowing_card_id = -1
