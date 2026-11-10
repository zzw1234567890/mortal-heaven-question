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
## 目标解析纯函数（默认首个存活敌人 / 显式覆盖）。
const TargetRules := preload("res://src/ui/combat/shared/combat_target_rules.gd")
## 出牌结果与拒绝原因（UI 据此显示提示文本）。
const PlayResult := preload("res://src/feature/combat/combat_play_result.gd")
## 敌方 ID 约定（候选池建键——与战斗状态表同源）。
const RosterState := preload("res://src/feature/combat/combat_roster_state.gd")

## 战斗系统（[code]play_card[/code]）。
var _combat: Node = null
## 部署系统（[code]get_field[/code]——施法者兜底裁定的数据来源）。
var _deployment: Node = null
## 当前操作角色提供者（需实现 [code]current_id()[/code]——「谁在行动」的显式状态）。[br]
## [br][b]可空[/b]：未接线时退化为 [CombatCasterRules] 的阵位顺序裁定（旧口径），
## 不把「还没接角色切换」变成不能出牌。
var _actor_source: Variant = null


## 注入数据源（全部可空——缺失时对应能力退化，不抛错）。
func setup(p_combat: Node, p_deployment: Node) -> void:
	_combat = p_combat
	_deployment = p_deployment


## 注入当前操作角色提供者（[code]CombatActorSelection[/code] 或同形状桩）。[br]
## [br][b]注入后施法者口径改变[/b]：优先用玩家选中的角色；它判不出（无角色 / 阵亡清空）
## 时仍回退阵位顺序——回退是[b]兜底[/b]而不是默认。
func set_actor_source(p_actor_source: Variant) -> void:
	_actor_source = p_actor_source


## 数据源是否齐备。[br]
## [br][b]两份都要[/b]（同 [DeployPanel]/[SettlementHost] 的语义）：缺战斗系统则出牌
## 无从转交，缺部署系统则施法者恒判不出（-1）——两种都不是「可用」状态，
## 只是后者退化为静默不结算。[br]
## [br][b]与 [method play_card] 返回值的分工[/b]：本方法是给调用方（后续交互层）的
## 前置探测；[method play_card] 自身仍只以战斗系统为硬门槛（缺部署系统时照常转交
## -1，让系统侧按既有口径决定是否结算）。
func has_sources() -> bool:
	return _combat != null and _deployment != null


## 当前施法者角色 ID——[b]优先「当前操作角色」[/b]，判不出再回退阵位首个存活角色。[br]
## [br][b]口径来源[/b]：[method set_actor_source] 注入的 [code]CombatActorSelection[/code]
## 是「谁在行动」的唯一真理来源（玩家可切换、阵亡自动顺位）；未接该状态时才用
## [code]CombatCasterRules[/code] 的阵位顺序（旧口径，仅作降级兜底）。[br]
## [br][b]为什么现读而非缓存[/b]：阵亡清位会改变阵位，缓存会让「刚死的人」继续出牌。
func current_caster_id() -> int:
	if _actor_source != null:
		var selected: int = int(_actor_source.call(&"current_id"))
		if selected != CasterRules.NO_CASTER:
			return selected
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
	return PlayResult.is_ok(play_card_detailed(p_card_instance_id, p_target_indices))


## 经 UI 出牌并拿到[b]带原因的结果[/b]——交互层显示提示文本的唯一入口。[br]
## [br][b]目标解析[/b]（combat-ui-interaction 001）：[br]
##   - [param p_target_indices] 为空 → 走默认策略（候选池首个存活敌人）；[br]
##   - 非空 → 显式覆盖，但只保留候选池里存活的那些；全无效则拒绝
##     （[constant CombatTargetRules.SOURCE_NONE]）。[br]
## 候选池取自战斗系统的敌方名册快照 + 当前 HP（UI 不自算存活，见下）。[br]
## [br][b]施法者[/b]：由 [method current_caster_id] 取「当前操作角色」（玩家选中的
## 角色；未接该状态时回退阵位首个存活角色）——多角色阵容里出牌不再一律记在阵位首位。[br]
## [br][b]返回[/b]: [code]{ok, reason, message, context}[/code]；桥自身的降级
## （战斗系统未注入）用 [code]REASON_NO_COMBAT[/code] 表达，形状与系统侧一致。
func play_card_detailed(p_card_instance_id: int, p_target_indices: Array) -> Dictionary:
	if _combat == null or not _combat.has_method(&"play_card"):
		push_warning("CombatPlayBridge.play_card: 战斗系统未注入——出牌中止")
		return PlayResult.fail(PlayResult.REASON_NO_COMBAT)
	var resolution: Dictionary = resolve_targets(p_target_indices)
	if int(resolution.get("source", TargetRules.SOURCE_UNRESOLVED)) \
			== TargetRules.SOURCE_NONE:
		return PlayResult.fail(PlayResult.REASON_BAD_TARGET, {
			"targets": [], "explicit": p_target_indices.duplicate(),
		})
	var targets: Array = resolution.get("targets", [])
	var caster_id: int = current_caster_id()
	if _combat.has_method(&"play_card_detailed"):
		return _combat.call(&"play_card_detailed", p_card_instance_id, targets,
				caster_id)
	# 回退：只实现了 bool 契约的战斗系统（旧桩 / 未升级的替身）——能出牌，但没有
	# 细分原因。降级为「成败 + 通用文案」而不是直接拒绝，否则一个更弱的替身会把
	# 本该成功的出牌变成失败。
	if bool(_combat.call(&"play_card", p_card_instance_id, targets, caster_id)):
		return PlayResult.ok({"targets": targets, "caster_id": caster_id})
	return PlayResult.fail(PlayResult.REASON_SYSTEM_REJECTED,
			{"targets": targets, "caster_id": caster_id})


## 解析本次出牌的目标列表（[b]不落任何副作用[/b]——UI 可在确认前先问一次）。[br]
## [br][b]为什么候选池在桥里组装而非纯函数里[/b]：存活判定要读「当前 HP」，
## 那是战斗状态，不是 UI 能持有的快照——纯函数只做策略（默认/覆盖），取数归本层，
## 这与 [code]CombatActorReader[/code] 「取数收敛到一处」的分工一致。[br]
## [br][b]返回[/b]: [code]{targets, source, reason}[/code]（见 [CombatTargetRules]）。
func resolve_targets(p_explicit: Array) -> Dictionary:
	return TargetRules.resolve(p_explicit, enemy_candidates())


## 敌方候选池——[code][{character_id, is_alive, current_hp, max_hp}][/code]，
## 顺序即名册顺序（= UI 建卡顺序 = 玩家看到的从左到右）。[br]
## [br][b]战斗系统不可用 / 无名册入口 → 空数组[/b]：此时 [CombatTargetRules]
## 的「读不到候选池」分支生效——显式目标原样透传，不越权否决。[br]
## [br][b]ID 与 HP 同源[/b]：ID 经 [method CombatRosterState.enemy_id_of]，
## HP 经战斗系统的 [code]get_character_hp[/code]——与战斗状态表落在同一个键上，
## 否则候选池读到的永远是 0/0（会把活敌人误判成阵亡）。
func enemy_candidates() -> Array:
	var candidates: Array = []
	if _combat == null or not _combat.has_method(&"get_battle_enemy_roster"):
		return candidates
	var roster: Variant = _combat.call(&"get_battle_enemy_roster")
	if not (roster is Array):
		return candidates
	var entries: Array = roster
	for idx: int in range(entries.size()):
		if entries[idx] == null:
			continue
		var character_id: int = RosterState.enemy_id_of(entries[idx], idx)
		var hp: Dictionary = _hp_of(character_id)
		candidates.append({
			"character_id": character_id,
			"is_alive": bool(hp.get("is_alive", true)),
			"current_hp": int(hp.get("current", 0)),
			"max_hp": int(hp.get("max", 0)),
		})
	return candidates


## 角色 HP/存活——战斗系统不可用时返回「未知但存活」
## （[code]max=0[/code] 走 [method CombatTargetRules.is_alive_hp] 的未知分支）。
func _hp_of(character_id: int) -> Dictionary:
	var info: Dictionary = {"current": 0, "max": 0, "is_alive": true}
	if _combat == null:
		return info
	if _combat.has_method(&"get_character_hp"):
		var raw: Variant = _combat.call(&"get_character_hp", character_id)
		if raw is Dictionary:
			info["current"] = int((raw as Dictionary).get("current", 0))
			info["max"] = int((raw as Dictionary).get("max", 0))
	if _combat.has_method(&"is_character_alive"):
		info["is_alive"] = bool(_combat.call(&"is_character_alive", character_id))
	return info
