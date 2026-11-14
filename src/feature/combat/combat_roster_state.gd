extends RefCounted
## CombatRosterState —— 本场战斗敌我角色的运行时状态（HP / 存活）快照。[br]
## [br][b]职责[/b]：为伤害结算提供「防御方角色状态」的写入目标，并把结果回写到
## 真实持有方——敌方写回 [code]EnemyBattleState[/code] 对象或阵容 Dictionary，
## 我方持有本模块自建的状态字典（ADR-0008 §Phase 4「目标 HP 减少；检查阵亡」）。[br]
## [br][b]为什么需要独立文件[/b]：此前全库只有「攻击方-目标-防御力」的即时计算，
## 没有任何地方保存我方角色的 [code]current_hp[/code]——[code]DeploymentSystem._field[/code]
## 只存阵位与状态（ADR-0016 §阵位数据模型），[code]battle.player_field[/code] 尚无写入端。
## 本模块是战斗内的单一 HP 真理来源，开战快照一次、结算写回、战斗结束清空。[br]
## [br][b]建表半边已拆出[/b]（见 [code]combat_roster_seeding.gd[/code]）：「名册 → 状态表」
## 是一次性无状态换算，与「谁在读、谁在写」无交集；拆出后本类只管表的生命期与读写。
## [constant ENEMY_ID_BASE] 一族的编码约定与 [method enemy_id_of] 仍由本类[b]转发[/b]
## 同一实现——外部既有引用点（战斗 UI 建卡、敌方行动播报）一字未改。[br]
## [br][b]信息不足原则[/b]（同 [code]combat_end_check.gd[/code]）：读不到 HP 的角色标记为
## [code]known=false[/code]，伤害不落库、不据此判死——由调用方回退到载荷里的
## [code]is_kill[/code]，避免「读不到数据」把角色误杀。[br]
## [br]来源: ADR-0008 §Phase 4/§Phase 6、ADR-0016 §阵亡清位、GDD combat-system.md §3/§9、
## tech-debt DEBT-CBT-018-1。

## 建表半边（名册 → 状态表；敌方 ID 编码与条目字段读取的唯一实现处）。
const SeedingScript := preload("res://src/feature/combat/combat_roster_seeding.gd")

## 阵营枚举（镜像 [signal CombatSystem.character_died] 的 side 参数——0 己方 / 1 敌方）。
const SIDE_PLAYER: int = SeedingScript.SIDE_PLAYER
const SIDE_ENEMY: int = SeedingScript.SIDE_ENEMY

## 敌方角色 ID 编码基数 / 步长（与 ai_roster_factory 的绑定 ID 同源）。
const ENEMY_ID_BASE: int = SeedingScript.ENEMY_ID_BASE
const ENEMY_ID_STRIDE: int = SeedingScript.ENEMY_ID_STRIDE

## 属性增益存储（战斗内直用法宝）。
const BonusScript := preload("res://src/feature/combat/combat_stat_bonus.gd")
## Debuff 管理器——降攻/降防 debuff 状态管理。
const DebuffScript := preload("res://src/feature/combat/combat_debuff_manager.gd")

## 状态表——[code]{character_id: {side, current_hp, max_hp, atk, defense, is_alive,
## known, ref}}[/code]。我方 [code]defense[/code] 来自 [code]player_stats.defense[/code]，
## 缺省 0（不臆造）。[code]ref[/code] 为外部持有者（敌方阵容条目）；我方条目为 null。
var _states: Dictionary = {}

## Debuff 管理器——降攻/降防 debuff 状态管理。
var _debuff: RefCounted = null

## 属性增益存储——战斗内直用法宝的落点（与 debuff 对称：一个减、一个加）。[br]
## [br][b]为什么与 debuff 分家[/b]：两者的写入契约不同（debuff 拒绝非正数、按回合过期；
## 增益相反）——合成一处会让「amount 的符号」承担两种含义（见
## [code]combat_stat_bonus.gd[/code] 类文档）。读侧在本模块叠加，外部只经
## [method get_atk] / [method get_defense] 取数。
var _bonus: RefCounted = null


## 敌方角色 ID 派生（转发建表模块——见类文档「建表半边已拆出」）。
static func enemy_id_of(entry: Variant, index: int) -> int:
	return SeedingScript.enemy_id_of(entry, index)


## 敌方条目的前后排判定（转发——同 [method enemy_id_of]）。
static func enemy_is_front(entry: Variant) -> bool:
	return SeedingScript.enemy_is_front(entry)


## 清空全部状态——开战重种子与战斗结束共用。
func clear() -> void:
	_states.clear()
	if _debuff != null:
		_debuff.call(&"clear")
	if _bonus != null:
		_bonus.call(&"clear")


## 用我方阵位 + 敌方阵容重建状态表（开战快照）。[br]
## [param player_stats] 可选的 [code]{character_id: {current_hp, max_hp}}[/code]
## （interaction epic 的 battle_start config 扩展；缺省时回退卡牌模板 base_hp）。[br]
## [param card_system] 卡牌系统 Autoload——模板 HP 回退来源，可为 null。
func seed(player_field: Array, player_stats: Dictionary, enemy_roster: Array,
		card_system: Node = null) -> void:
	clear()
	seed_enemy_roster(enemy_roster)
	seed_player_field(player_field, player_stats, card_system)


## 种子敌方阵容（建表委托 [code]combat_roster_seeding.gd[/code]）。
func seed_enemy_roster(roster: Array) -> void:
	_states.merge(SeedingScript.build_enemy_states(roster), true)


## 种子我方阵位（建表委托同 [method seed_enemy_roster]）。
func seed_player_field(field: Array, stats: Dictionary,
		card_system: Node = null) -> void:
	_states.merge(SeedingScript.build_player_states(field, stats, card_system), true)


## 查询角色是否拥有可信 HP 数据（未知时不回写、不据此判死）。
func is_known(character_id: int) -> bool:
	return bool(_states.get(character_id, {}).get("known", false))


## 查询角色存活状态——未知角色按存活处理（不误判）。
func is_alive(character_id: int) -> bool:
	var state: Dictionary = _states.get(character_id, {})
	if state.is_empty():
		return true
	return bool(state.get("is_alive", true))


## HP 读取契约——战斗 UI 的 [code]hp_reader_cb[/code] 期望
## [code]{current, max}[/code]；未知角色返回 0/0（UI 侧已有除零守卫）。
func get_hp(character_id: int) -> Dictionary:
	var state: Dictionary = _states.get(character_id, {})
	if state.is_empty():
		return {"current": 0, "max": 0}
	return {"current": int(state["current_hp"]), "max": int(state["max_hp"])}


## 结算侧的读入口——[code]{known, side, current_hp, max_hp, atk, is_alive}[/code]；
## 未知角色返回 [code]known=false[/code]（值全零，调用方不得据此判死）。
func read_hp(character_id: int) -> Dictionary:
	var state: Variant = _states.get(character_id)
	if not (state is Dictionary):
		return {"known": false, "side": SIDE_PLAYER, "current_hp": 0, "max_hp": 0,
				"atk": 0, "defense": 0, "is_alive": true}
	var st: Dictionary = state
	return {
		"known": bool(st["known"]),
		"side": int(st["side"]),
		"current_hp": int(st["current_hp"]),
		"max_hp": int(st["max_hp"]),
		"atk": int(st.get("atk", 0)),
		"defense": int(st.get("defense", 0)),
		"is_alive": bool(st["is_alive"]),
	}


## 攻击力读取——出牌伤害倍率的取数入口（[code]ATK × 倍率[/code] 的 ATK）。[br]
## 已叠加战斗内法宝增益（[method apply_bonus]），再受降攻 debuff 修正。[br]
## 未知角色返回 0（不臆造伤害）——[b]增益也一并不可见[/b]：[method apply_bonus] 对未知
## 角色根本不记，故这里读到的必然是 0。[br]
## [b]叠加顺序[/b]：先加增益再减 debuff（[code]max(基础 + 增益 − 降攻, 0)[/code]）——
## 降攻是对「当前攻击力」的削减，若先减后加，一个降 5 攻的 debuff 会被后加的增益
## 悄悄抵消掉一部分，与 [code]CombatDebuffManager[/code] 文档写的
## 「ATK 受降攻 debuff 调整后，再算防御减免」同一方向。
func get_atk(character_id: int) -> int:
	var state: Dictionary = _states.get(character_id, {})
	if state.is_empty():
		return 0
	var with_bonus: int = int(state.get("atk", 0)) \
			+ _read_bonus(character_id, BonusScript.STAT_ATK)
	if _debuff != null:
		return int(_debuff.call(&"get_atk_with_debuff", character_id, with_bonus))
	return with_bonus


## 防御力读取——伤害结算的取数入口（防御减免）。叠加口径同 [method get_atk]。[br]
## 未知角色返回 0（不臆造防御数字）。
func get_defense(character_id: int) -> int:
	var state: Dictionary = _states.get(character_id, {})
	if state.is_empty():
		return 0
	var with_bonus: int = int(state.get("defense", 0)) \
			+ _read_bonus(character_id, BonusScript.STAT_DEF)
	if _debuff != null:
		return int(_debuff.call(&"get_def_with_debuff", character_id, with_bonus))
	return with_bonus


## 施加属性增益（战斗内直用法宝）——见 [code]combat_stat_bonus.gd[/code] 的取舍注记。[br]
## [br][b]未知角色不记[/b]：状态表里没有可信数值的角色（未种子 / 已阵亡清位）加上去
## 只会得到一个永远读不到的条目（[method get_atk] 对未知角色直接返回 0）。[br]
## [b]返回[/b]：是否真的记了一笔。
func apply_bonus(character_id: int, p_stat: String, p_amount: int) -> bool:
	if not is_known(character_id):
		return false
	return bool(_get_bonus().call(&"apply", character_id, p_stat, p_amount))


## 获取属性增益存储——用于测试断言 / UI 显示。
func get_bonus_manager() -> RefCounted:
	return _get_bonus()


## 读某属性的增益总量——未知角色一律 0（同 [method get_atk] 的守卫）。
func _read_bonus(character_id: int, p_stat: String) -> int:
	if _bonus == null:
		return 0
	return int(_bonus.call(&"get_bonus", character_id, p_stat))


## 惰性创建增益存储。
func _get_bonus() -> RefCounted:
	if _bonus == null:
		_bonus = BonusScript.new()
	return _bonus


## 施加 debuff——目标收到 debuff（[param p_type] 为 [code]DebuffManager.TYPE_*[/code]）。[br]
## [b]返回[/b]：是否成功施加（层数已满则失败）。
func apply_debuff(p_target_id: int, p_type: int, p_duration: int, p_amount: int,
		p_source_id: int = -1) -> bool:
	return _get_debuff().call(&"apply", p_target_id, p_type, p_duration, p_amount,
			p_source_id)


## 回合结束递减 debuff——调用一次，所有 debuff 持续回合数 -1。[br]
## [br]归零的 debuff 条目会被移除。[br]
## [b]返回[/b]：被移除的 debuff 数量（用于日志/统计）。
func on_turn_end_debuff() -> int:
	if _debuff == null:
		return 0
	return _debuff.call(&"on_turn_end")


## 获取 debuff 管理器——用于测试断言 / UI 显示。
func get_debuff_manager() -> RefCounted:
	return _get_debuff()


## 惰性创建 debuff 管理器。
func _get_debuff() -> RefCounted:
	if _debuff == null:
		_debuff = DebuffScript.new()
	return _debuff


## 全表快照——结算回流用（Sprint 18）：逐角色一条
## [code]{character_id, side, current_hp, max_hp, is_alive, known}[/code]，按 ID 升序。[br]
## [br][b]必须在 clear() 之前调用[/b]：battle_end 清空状态表后这里读到的就是空数组
## （结算对象与 HP 回写都以它为唯一取数来源）。[br]
## [br][b]不含 ref[/b]：外部持有者（敌方阵容条目）不进快照，避免把对象带进结算数据。
func snapshot_all() -> Array:
	var keys: Array = _states.keys()
	keys.sort()
	var out: Array = []
	for key: Variant in keys:
		var st: Dictionary = _states[key]
		out.append({
			"character_id": int(key),
			"side": int(st.get("side", SIDE_PLAYER)),
			"current_hp": int(st.get("current_hp", 0)),
			"max_hp": int(st.get("max_hp", 0)),
			"is_alive": bool(st.get("is_alive", true)),
			"known": bool(st.get("known", false)),
		})
	return out


## 状态只读副本（调试/断言用）。
func get_state(character_id: int) -> Dictionary:
	var state: Dictionary = _states.get(character_id, {})
	if state.is_empty():
		return {}
	var copy: Dictionary = state.duplicate()
	copy.erase("ref")
	return copy


## 应用一次伤害并回写防御方状态（负值 = 治疗，与 UI 的 damage 符号约定同源）。[br]
## [br][b]返回[/b]：[code]{known, died, side, current_hp, max_hp}[/code]。[br]
##   - [code]known=false[/code] → 未落库，调用方回退到载荷的 is_kill；[br]
##   - [code]died=true[/code] → 本次调用让角色由存活转为阵亡（幂等——已阵亡不再为真）。
func apply_damage(character_id: int, damage: int) -> Dictionary:
	var state: Variant = _states.get(character_id)
	if not (state is Dictionary) or not bool((state as Dictionary).get("known", false)):
		return {"known": false, "died": false, "side": SIDE_PLAYER,
				"current_hp": 0, "max_hp": 0}
	var st: Dictionary = state
	var was_alive: bool = bool(st["is_alive"])
	var max_hp: int = int(st["max_hp"])
	var hp: int = int(st["current_hp"]) - damage
	if max_hp > 0:
		hp = mini(hp, max_hp)  # 治疗不超过上限
	if hp <= 0:
		hp = 0
		st["is_alive"] = false
	st["current_hp"] = hp
	_write_back(st, hp, bool(st["is_alive"]))
	return {
		"known": true,
		"died": was_alive and not bool(st["is_alive"]),
		"side": int(st["side"]),
		"current_hp": hp,
		"max_hp": max_hp,
	}


## 回写外部持有者——对象走 set()，Dictionary 原地改键（共享引用，END 判定可见）。
func _write_back(st: Dictionary, hp: int, alive: bool) -> void:
	var ref: Variant = st.get("ref")
	if ref is Object:
		var obj: Object = ref as Object
		obj.set("current_hp", hp)
		obj.set("is_alive", alive)
	elif ref is Dictionary:
		(ref as Dictionary)["current_hp"] = hp
		(ref as Dictionary)["is_alive"] = alive
