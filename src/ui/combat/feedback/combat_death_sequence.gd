class_name CombatDeathSequence
extends RefCounted
## CombatDeathSequence —— 单个角色的阵亡动画生命周期（拆分自 feedback 编排器）。[br]
##
## [b]职责[/b]：把一个角色从「还在场上」送到「卡已移除、原位换成带戳记的空位框」，
## 全程只有一条通道——[method play] 起 0.5s 淡出，动画结束回调 [method finalize]
## 做接替；[method kill] 中途中止（全灭短路 / 战斗结束清理）；[method play] 幂等
## （已在播的不重播）。[br]
## [b]不管什么[/b]：不认信号、不读源系统、不改裁定（谁该阵亡、全灭要不要播动画
## 都由调用方决定），也不碰伤害增量账。[br]
## [br][b]卡表与 Tween 账是借来的引用[/b]：构造时接收调用方的
## [code]_cards[/code] 与 [code]_death_tweens[/code] 两份字典（GDScript 字典是
## 引用类型）——本件就地记账，调用方照旧能读到同一份；不复制、不换新字典，
## 否则「编排器摘了卡表、序列件还在旧表上找卡」这类错位会立刻出现。[br]
## [br][b]reduce_motion[/b]：直接落终态（不起 Tween、无动画窗口——UX 减少动态条款）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——一次性 [Tween] 驱动
## （[code]await[/code] 也不用，回调即完成）。
##
## 来源: combat-ui-layout Story 003 AC-4（阵亡 0.5s 淡出 → 移除卡 → 空位虚线框）、
## design/gdd/combat-ui-system.md 动画表「角色阵亡 0.5s」、
## combat_feedback_coordinator（拆分——行数预算，编码标准「单文件 ≤300 行」）。

## 阵亡动画时长（秒——GDD 动画表「角色阵亡 0.5s」）。
const DEATH_DURATION_SEC: float = 0.5

## 阵亡终态的空位接替（卡 → 带「已阵亡」戳记的空位虚线框，见该模块类文档）。
const DeathHandoff := preload("res://src/ui/combat/feedback/combat_death_handoff.gd")

## Tween 宿主（[method Node.create_tween] 的归属者——编排器本体）。
var _host: Node = null
## 角色 ID → 角色卡映射（调用方的卡表引用——本件只摘除、不新建）。
var _cards: Dictionary = {}
## 阵亡动画 Tween 句柄表——[code]{character_id: Tween}[/code]（调用方的引用）。
var _tweens: Dictionary = {}


## 构造——借入调用方的 Tween 宿主与两份记账表。[br]
## [param p_host]: Tween 宿主（须能 [method Node.create_tween]）。[br]
## [param p_cards]: 角色 ID → 卡节点表（同一份字典引用）。[br]
## [param p_tweens]: 阵亡 Tween 句柄表（同一份字典引用——调用方可读）。
func _init(p_host: Node, p_cards: Dictionary, p_tweens: Dictionary) -> void:
	_host = p_host
	_cards = p_cards
	_tweens = p_tweens


## 播放阵亡动画。[br]
## [br][param p_blocked] 为真时直接返回（全灭短路——结算面板已接管，不再播动画）。[br]
## [param p_reduce_motion] 为真时直落终态（瞬时替代）。[br]
## [br][b]幂等[/b]：同一角色重复调用不重播（已在播 → 返回）——[code]pending_death[/code]
## 结算帧与 [code]character_died[/code] 信号两条路径会汇合到这里，不去重就会双播。[br]
## [br][b]返回[/b]：本次是否真的起了动画或落了终态（未注册 / 已在播 / 被阻断为 false）。
func play(character_id: int, p_blocked: bool, p_reduce_motion: bool) -> bool:
	if p_blocked:
		return false
	var card: Control = _cards.get(character_id)
	if card == null:
		return false
	if _tweens.has(character_id):
		return false  # 幂等——动画进行中不重播
	if p_reduce_motion:
		finalize(character_id)
		return true
	kill(character_id)
	var tween: Tween = _host.create_tween()
	# 碎裂+消散 stub：整体 modulate alpha 淡出 0.5s（美术碎裂素材归后续 story）
	tween.tween_property(card, "modulate:a", 0.0, DEATH_DURATION_SEC)
	tween.tween_callback(finalize.bind(character_id))
	_tweens[character_id] = tween
	return true


## 阵亡动画完成——移除卡节点 + 原位显示带戳记的空位虚线框。[br]
## [br][b]接替动作委托 [code]CombatDeathHandoff[/code][/b]：搬运节点与填「已阵亡」
## 文字是同一件事的两半（框上没有字的终态等于把信息丢掉），收在一处才拆不开。[br]
## [br][b]三层清理的分工[/b]：本方法只摘卡表（[code]_cards[/code]）；
## 调用方的 [code]_pending_deltas[/code] 留给它自己的
## [code]unregister_card[/code]（战斗结束统一清扫），阵亡 Tween 表由
## [method kill] 先行摘干净——三者不合并，避免「战斗结束清理」与「单个角色阵亡」
## 两条路径互相误伤。
func finalize(character_id: int) -> void:
	kill(character_id)
	var card: Control = _cards.get(character_id)
	if card == null:
		return
	DeathHandoff.replace_with_empty_slot(card)
	_cards.erase(character_id)
	card.queue_free()


## 中途中止某个角色的阵亡动画（幂等——没在播时是空操作）。[br]
## [br][b]必须杀 Tween[/b]：不杀的话回调仍会在 0.5s 后打到已经不该播的卡上
## （全灭短路后把卡从结算面板底下抹掉）。
func kill(character_id: int) -> void:
	var tween: Tween = _tweens.get(character_id)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(character_id)


## 中止全部在播的阵亡动画（全灭短路 / 战斗结束）。[br]
## [br][b]顺手恢复不透明[/b]（L-2）：动画被杀在半途时卡的 [code]modulate.a[/code]
## 停在中间值，不还原会留下一张半透明的卡悬在场上。
func kill_all() -> void:
	for character_id: int in _tweens.keys():
		var card: Control = _cards.get(character_id)
		if card != null:
			card.modulate.a = 1.0
		kill(character_id)


## 该角色是否正在播阵亡动画（测试探针）。
func is_playing(character_id: int) -> bool:
	return _tweens.has(character_id)
