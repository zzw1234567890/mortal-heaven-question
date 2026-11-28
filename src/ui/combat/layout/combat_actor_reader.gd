extends RefCounted
## CombatActorReader —— 战场角色卡的取数入口（Sprint 18 / DEBT-CBT-018-1 残留闭环）。
##
## [b]职责[/b]：把「谁在场上 / 他有多少血和攻」的读取链路收敛到一处，供
## [CombatActorStage] 建卡时使用。名册归属拆两个来源：[br]
##   - 敌方：战斗系统的开战快照（[code]get_battle_enemy_roster[/code]）——与 END
##     判定看同一份数据，跨回合不会读到「下一场」；[br]
##   - 我方：开战配置的 ID 列表优先，缺省回退 DeploymentSystem 阵位
##     （渡劫等不携带名册的开战路径）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全部依赖经 [method setup] 注入，每次
## [b]现读[/b]——本类不缓存 HP/名册；返回的是给 UI 建卡的瞬时快照。[br]
## [br][b]敌方 ID 约定[/b]：与 [code]combat_roster_state.gd[/code] 共用
## [method CombatRosterState.enemy_id_of]——种子与建卡必须落在同一个键上，
## 否则 UI 读到的永远是 0/0。[br]
##
## @experimental
## 来源: ADR-0031、ADR-0008 §Phase 1/Phase 6、design/ux/combat-ui.md §Layout Zones、
## DEBT-CBT-018-1 残留项（战斗 UI 无反馈协调器生产实例化点）。

## 敌方 ID / 阵位约定（单一真理来源）。
const RosterState := preload("res://src/feature/combat/combat_roster_state.gd")
## 显示名解析（敌方开战名册 → 卡牌模板 → ID 段兜底，回退顺序只有那一处）。
const NameText := preload("res://src/ui/combat/feedback/enemy_action_text.gd")

## 战斗系统（名册快照 + HP 读取契约）。
var _combat: Node = null
## 部署系统（我方阵位与前后排判定）。
var _deployment: Node = null
## 卡牌系统（模板 HP/ATK 回退）。
var _card_system: Node = null


## 注入数据源（全部可空——缺失时对应读取退化为「无数据」，不抛错）。
func setup(p_combat: Node, p_deployment: Node, p_card_system: Node = null) -> void:
	_combat = p_combat
	_deployment = p_deployment
	_card_system = p_card_system


## 我方建卡条目——[code][{character_id, is_front}][/code]。[br]
## [param p_player_ids] 开战配置的角色 ID（空 → 读阵位）。
func player_entries(p_player_ids: Array) -> Array:
	var entries: Array = []
	if not p_player_ids.is_empty():
		for raw: Variant in p_player_ids:
			var character_id: int = int(raw)
			entries.append({"character_id": character_id,
					"is_front": _player_is_front(character_id)})
		return entries
	for entry: Variant in _read_player_field():
		var character_id: int = _entry_int(entry, "character_id", -1)
		if character_id < 0:
			continue
		var raw_front: Variant = _entry_raw(entry, "is_front")
		entries.append({"character_id": character_id,
				"is_front": bool(raw_front) if raw_front != null else true})
	return entries


## 敌方建卡条目——[code][{character_id, is_front}][/code]（强度顺序即快照顺序）。
func enemy_entries() -> Array:
	var entries: Array = []
	var roster: Array = read_enemy_roster()
	for idx: int in range(roster.size()):
		var entry: Variant = roster[idx]
		if entry == null:
			continue
		entries.append({
			"character_id": RosterState.enemy_id_of(entry, idx),
			"is_front": RosterState.enemy_is_front(entry),
		})
	return entries


## 敌方开战快照（战斗系统不可用时为空数组）。
func read_enemy_roster() -> Array:
	if _combat == null or not _combat.has_method(&"get_battle_enemy_roster"):
		return []
	var roster: Variant = _combat.call(&"get_battle_enemy_roster")
	return roster if roster is Array else []


## 角色显示名——敌方名册 / 卡牌模板 / ID 段兜底（回退顺序见
## [code]EnemyActionText.name_of[/code]，本方法只做依赖转发）。[br]
## [br][b]为什么收在取数入口[/b]：建卡所需的三样（HP / ATK / 名）都要「现读一次」，
## 三处各接一遍战斗系统与卡牌系统必然漂移；名与播报共用同一个解析器，玩家看到的
## 卡上名与播报里的名永远是同一个。[br]
## [br][b]返回[/b]：非空串——最差也是 [code]敌人 #100000[/code] 这样的可读编号。
## 角色 → 卡种 ID（[code]lin_yuan[/code] 这类骨架名）。
## [br]立绘按卡种 ID 找图：资产名 [code]char_<骨架名>_portrait_full.png[/code]，
## 与卡种 ID 不逐字相等，交给 [code]IdentityPortraitResolver[/code] 归一后查。
## 查不到返回空串（卡面走占位色块）。
func card_id(p_character_id: int) -> String:
	var template: Variant = _template(p_character_id)
	if template == null:
		return ""
	return str(_entry_raw(template, "card_id"))


## 角色卡 L2 侧栏的功法 / 法宝计数——[code]{gongfa, fabao}[/code]。
## [br]绑定系统（Autoload [code]BindingManager[/code]）不可用 / 无记录时返回 0,0，
## 卡面照常画空槽（不抛错、不阻塞建卡）。
func binding_counts(p_character_id: int) -> Dictionary:
	var counts: Dictionary = {"gongfa": 0, "fabao": 0}
	var mgr: Node = _binding_manager()
	if mgr == null or not mgr.has_method(&"count_bound_slots"):
		return counts
	counts["gongfa"] = int(mgr.call(&"count_bound_slots", p_character_id, 0))
	counts["fabao"] = int(mgr.call(&"count_bound_slots", p_character_id, 1))
	return counts


## Autoload [code]BindingManager[/code]（无 SceneTree 的纯单元测试里返回 null）。
func _binding_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null(^"BindingManager")


func display_name(character_id: int) -> String:
	return NameText.name_of(character_id, _combat, _card_system)


## HP 读取——战斗系统的 hp_reader 契约（[code]{current, max}[/code]）。
func hp(character_id: int) -> Dictionary:
	if _combat == null or not _combat.has_method(&"get_character_hp"):
		return {"current": 0, "max": 0}
	var result: Variant = _combat.call(&"get_character_hp", character_id)
	return result if result is Dictionary else {"current": 0, "max": 0}


## ATK——敌方条目（EnemyBattleState.attack）优先，其次卡牌模板 base_attack。
func attack(character_id: int) -> int:
	var enemy: Variant = _find_enemy_entry(character_id)
	if enemy != null:
		var raw: Variant = _entry_raw(enemy, "attack")
		if raw != null:
			return int(raw)
	var template: Variant = _template(character_id)
	if template != null:
		var base: Variant = template.get("base_attack")
		if base != null:
			return int(base)
	return 0


## 基础 HP 回退——敌方条目的 max_hp，其次卡牌模板 base_hp，最后 0（= 未知）。
func base_hp(character_id: int) -> int:
	var enemy: Variant = _find_enemy_entry(character_id)
	if enemy != null:
		var raw: Variant = _entry_raw(enemy, "max_hp")
		if raw != null and int(raw) > 0:
			return int(raw)
	var template: Variant = _template(character_id)
	if template != null:
		var base: Variant = template.get("base_hp")
		if base != null and int(base) > 0:
			return int(base)
	return 0


## 我方阵位快照（部署系统不可用时为空数组）。[br]
## [br][b]公开给装配台用[/b]：当前操作角色的「候选筛出」与「切换校验」都读同一份
## 快照——取数入口只此一处，避免两处各读各的。
func player_field() -> Array:
	return _read_player_field()


## 我方阵位前后排——查不到该角色时按前排处理（不做无依据的臆测）。
func _player_is_front(character_id: int) -> bool:
	for entry: Variant in _read_player_field():
		if _entry_int(entry, "character_id", -1) != character_id:
			continue
		var raw: Variant = _entry_raw(entry, "is_front")
		return bool(raw) if raw != null else true
	return true


## 读我方阵位快照（不可用时为空数组）。
func _read_player_field() -> Array:
	if _deployment == null or not _deployment.has_method(&"get_field"):
		return []
	var field: Variant = _deployment.call(&"get_field")
	return field if field is Array else []


## 在敌方开战快照里按同一 ID 约定反查条目。
func _find_enemy_entry(character_id: int) -> Variant:
	var roster: Array = read_enemy_roster()
	for idx: int in range(roster.size()):
		if RosterState.enemy_id_of(roster[idx], idx) == character_id:
			return roster[idx]
	return null


## 卡牌模板查询（CardSystem 不可用/查不到时返回 null）。
func _template(character_id: int) -> Variant:
	if _card_system == null or not _card_system.has_method(&"get_template_by_instance_id"):
		return null
	return _card_system.call(&"get_template_by_instance_id", character_id)


# === 条目字段读取（兼容 Dictionary / Object）=================================

func _entry_int(entry: Variant, key: String, fallback: int) -> int:
	if entry is Dictionary:
		return int((entry as Dictionary).get(key, fallback))
	if entry is Object and (entry as Object).has_method(&"get"):
		var raw: Variant = (entry as Object).get(key)
		return int(raw) if raw != null else fallback
	return fallback


func _entry_raw(entry: Variant, key: String) -> Variant:
	if entry is Dictionary:
		return (entry as Dictionary).get(key)
	if entry is Object and (entry as Object).has_method(&"get"):
		return (entry as Object).get(key)
	return null
