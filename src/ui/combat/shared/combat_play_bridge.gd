class_name CombatPlayBridge
extends RefCounted
## CombatPlayBridge —— UI 出牌入口（DEBT-CBT-018-10 第四阶段：caster_id 接线）。
##
## [b]职责[/b]：给「UI 出牌」一条带[b]施法者裁定[/b]的调用通道——[br]
##   [code]UI → CombatPlayBridge.play_card(id, targets) → CombatSystem.play_card(id, targets, caster)[/code][br]
## [br][b]为什么需要桥[/b]：[code]CombatSystem.play_card()[/code] 的第三个参数
## [code]caster_id[/code] 决定倍率伤害的 ATK 取数对象与治疗落点；此前 UI 侧无人传入，
## 缺省 -1 → 这两类效果在真实对局里从不结算。本桥在调用前用
## [CombatCasterRules.resolve_caster] 从我方阵位现读施法者，判不出就原样传 -1
## （[b]不猜[/b]「谁出的牌」）。[br]
## [br][b]施法者口径（临时）[/b]：我方阵位第一个存活角色——combat-ui-interaction epic
## （0/9 未实现）尚无「当前操作角色」概念，而阵位正是备战确认时写入的那份名册，
## 用它不引入第二份真理来源。interaction epic 落地点选/拖拽出牌后，应改为
## 显式传入玩家选中的角色，本桥降级为兜底。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：战斗系统与部署系统全部经 [method setup]
## 注入、每次现读；本类不缓存战斗状态，也不持有 HP / 阵位副本。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——只由玩家操作驱动。[br]
##
## @experimental
## 来源: ADR-0031、ADR-0016 §阵位数据模型、ADR-0008 §出牌结算流程、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md。

## 施法者裁定纯函数（阵位 → 角色 ID）。
const CasterRules := preload("res://src/ui/combat/shared/combat_caster_rules.gd")

## 战斗系统（[code]play_card[/code]）。
var _combat: Node = null
## 部署系统（[code]get_field[/code]——施法者裁定的数据来源）。
var _deployment: Node = null


## 注入数据源（全部可空——缺失时对应能力退化，不抛错）。
func setup(p_combat: Node, p_deployment: Node) -> void:
	_combat = p_combat
	_deployment = p_deployment


## 数据源是否齐备。[br]
## [br][b]两份都要[/b]（同 [DeployPanel]/[SettlementHost] 的语义）：缺战斗系统则出牌
## 无从转交，缺部署系统则施法者恒判不出（-1）——两种都不是「可用」状态，
## 只是后者退化为静默不结算。[br]
## [br][b]与 [method play_card] 返回值的分工[/b]：本方法是给调用方（后续交互层）的
## 前置探测；[method play_card] 自身仍只以战斗系统为硬门槛（缺部署系统时照常转交
## -1，让系统侧按既有口径决定是否结算）。
func has_sources() -> bool:
	return _combat != null and _deployment != null


## 当前施法者角色 ID——我方阵位第一个已占用且未阵亡的角色；判不出返回 -1。[br]
## [br][b]为什么现读阵位而非缓存[/b]：阵亡清位会改变阵位，缓存会让「刚死的人」继续出牌。
func current_caster_id() -> int:
	if _deployment == null or not _deployment.has_method(&"get_field"):
		return CasterRules.NO_CASTER
	return CasterRules.resolve_caster(_deployment.call(&"get_field"))


## 经 UI 出牌——裁定施法者后转交 [code]CombatSystem.play_card()[/code]。[br]
## [br][b]费用 / 效果 / 手牌移除全部在系统侧完成[/b]（UI 不做任何数值操作——
## ADR-0008 §出牌结算流程、control-manifest「出牌经 CombatSystem API」）。[br]
## [br][param p_card_instance_id] 卡牌实例 ID。[br]
## [param p_target_indices] 目标索引列表（本桥传副本，不改调用方数组）。[br]
## [b]返回[/b]: 出牌是否成功（未注入战斗系统 / 系统拒绝时为 false）。
func play_card(p_card_instance_id: int, p_target_indices: Array) -> bool:
	if _combat == null or not _combat.has_method(&"play_card"):
		push_warning("CombatPlayBridge.play_card: 战斗系统未注入——出牌中止")
		return false
	return bool(_combat.call(&"play_card", p_card_instance_id,
			p_target_indices.duplicate(), current_caster_id()))
