extends RefCounted
## CombatRosterState —— 本场战斗敌我角色的运行时状态（HP / 存活）快照。[br]
## [br][b]职责[/b]：为伤害结算提供「防御方角色状态」的写入目标，并把结果回写到
## 真实持有方——敌方写回 [code]EnemyBattleState[/code] 对象或阵容 Dictionary，
## 我方持有本模块自建的状态字典（ADR-0008 §Phase 4「目标 HP 减少；检查阵亡」）。[br]
## [br][b]为什么需要独立文件[/b]：此前全库只有「攻击方-目标-防御力」的即时计算，
## 没有任何地方保存我方角色的 [code]current_hp[/code]——[code]DeploymentSystem._field[/code]
## 只存阵位与状态（ADR-0016 §阵位数据模型），[code]battle.player_field[/code] 尚无写入端。
## 本模块是战斗内的单一 HP 真理来源，开战快照一次、结算写回、战斗结束清空。[br]
## [br][b]信息不足原则[/b]（同 [code]combat_end_check.gd[/code]）：读不到 HP 的角色标记为
## [code]known=false[/code]，伤害不落库、不据此判死——由调用方回退到载荷里的
## [code]is_kill[/code]，避免「读不到数据」把角色误杀。[br]
## [br][b]敌方 ID 编码[/b]：[code]EnemyBattleState[/code] 自身不持有 character_id，
## 绑定注册侧以「实例索引 × 10000 + 100000」派生（[code]ai_roster_factory.gd[/code]
## §register_preconfigured_bindings）。本模块按同一约定落键，条目自带
## [code]character_id[/code] 时以条目为准。[br]
## [br]来源: ADR-0008 §Phase 4/§Phase 6、ADR-0016 §阵亡清位、GDD combat-system.md §3/§9、
## tech-debt DEBT-CBT-018-1。

## 阵营枚举（镜像 [signal CombatSystem.character_died] 的 side 参数——0 己方 / 1 敌方）。
const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1

## 敌方角色 ID 编码基数（与 ai_roster_factory 的绑定 ID 同源）。
const ENEMY_ID_BASE: int = 100000
## 敌方角色 ID 步长（每实例一段，避免同模板多实例 ID 冲突）。
const ENEMY_ID_STRIDE: int = 10000

## 状态表——[code]{character_id: {side, current_hp, max_hp, is_alive, known, ref}}[/code]。
## [code]ref[/code] 为外部持有者（敌方阵容条目）；我方条目为 null（本表即真理来源）。
var _states: Dictionary = {}


## 敌方角色 ID 派生——[b]单一来源[/b]：开战种子与战斗 UI 建卡必须落在同一键上，
## 否则 UI 读到的永远是 0/0。[br]
## [param entry] 阵容条目（自带 character_id 时优先——测试/预配置阵容可显式指定）。[br]
## [param index] 阵容下标（无显式 ID 时按约定派生）。
static func enemy_id_of(entry: Variant, index: int) -> int:
	var explicit: int = _entry_int_static(entry, "character_id", -1)
	return explicit if explicit >= 0 else ENEMY_ID_BASE + index * ENEMY_ID_STRIDE


## 敌方条目的前后排判定——条目自带阵位信息时以其为准，缺省视为前排
## （敌方阵容快照通常不带阵位，UI 侧统一摆前排，不做无依据的臆测）。
static func enemy_is_front(entry: Variant) -> bool:
	var raw: Variant = _entry_raw_static(entry, "is_front_row")
	if raw == null:
		raw = _entry_raw_static(entry, "is_front")
	if raw is bool:
		return raw
	return true


## 清空全部状态——开战重种子与战斗结束共用。
func clear() -> void:
	_states.clear()


## 用我方阵位 + 敌方阵容重建状态表（开战快照）。[br]
## [br][param player_field] [code]DeploymentSystem.get_field()[/code] 快照。[br]
## [param player_stats] 可选的 [code]{character_id: {current_hp, max_hp}}[/code]
## （interaction epic 的 battle_start config 扩展；缺省时回退卡牌模板 base_hp）。[br]
## [param enemy_roster] 敌方阵容快照（EnemyBattleState 对象或 Dictionary）。[br]
## [param card_system] 卡牌系统 Autoload——模板 HP 回退来源，可为 null。
func seed(player_field: Array, player_stats: Dictionary, enemy_roster: Array,
		card_system: Node = null) -> void:
	clear()
	seed_enemy_roster(enemy_roster)
	seed_player_field(player_field, player_stats, card_system)


## 种子敌方阵容——条目自带 character_id 时优先，否则按 AI 绑定 ID 约定派生。[br]
## [br][b]写回目标[/b]：对象条目直接改其 [code]current_hp[/code]/[code]is_alive[/code]；
## Dictionary 条目原地改键（[b]浅拷贝的数组仍共享同一 Dictionary[/b]，改动对
## END 判定可见）。[br]
func seed_enemy_roster(roster: Array) -> void:
	for idx: int in range(roster.size()):
		var entry: Variant = roster[idx]
		if entry == null:
			continue
		var character_id: int = enemy_id_of(entry, idx)
		var max_hp: int = _entry_int(entry, "max_hp", 0)
		var hp: int = _entry_int(entry, "current_hp", max_hp)
		var known: bool = max_hp > 0
		_states[character_id] = _make_state(SIDE_ENEMY, hp, max_hp,
				bool(_entry_int(entry, "is_alive", 1)) and (hp > 0 or not known), known, entry)


## 种子我方阵位——HP 来源优先级：注入 stats > 卡牌模板 base_hp > 未知。[br]
func seed_player_field(field: Array, stats: Dictionary,
		card_system: Node = null) -> void:
	for entry: Variant in field:
		var character_id: int = _entry_int(entry, "character_id", -1)
		if character_id < 0:
			continue
		var injected: Variant = stats.get(character_id, {})
		var max_hp: int = 0
		var hp: int = 0
		if injected is Dictionary and not (injected as Dictionary).is_empty():
			max_hp = int((injected as Dictionary).get("max_hp", 0))
			hp = int((injected as Dictionary).get("current_hp",
					(injected as Dictionary).get("hp", max_hp)))
		else:
			max_hp = _read_template_max_hp(card_system, character_id)
			hp = max_hp
		var known: bool = max_hp > 0 or hp > 0
		_states[character_id] = _make_state(SIDE_PLAYER, hp, max_hp,
				hp > 0 or not known, known, null)


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
## [code]{current, max}[/code]；未知角色返回 0/0（UI 侧已有除零守卫）。[br]
func get_hp(character_id: int) -> Dictionary:
	var state: Dictionary = _states.get(character_id, {})
	if state.is_empty():
		return {"current": 0, "max": 0}
	return {"current": int(state["current_hp"]), "max": int(state["max_hp"])}


## 结算侧的读入口——[code]{known, side, current_hp, max_hp, is_alive}[/code]；
## 未知角色返回 [code]known=false[/code]（值全零，调用方不得据此判死）。
func read_hp(character_id: int) -> Dictionary:
	var state: Variant = _states.get(character_id)
	if not (state is Dictionary):
		return {"known": false, "side": SIDE_PLAYER, "current_hp": 0, "max_hp": 0, "is_alive": true}
	var st: Dictionary = state
	return {
		"known": bool(st["known"]),
		"side": int(st["side"]),
		"current_hp": int(st["current_hp"]),
		"max_hp": int(st["max_hp"]),
		"is_alive": bool(st["is_alive"]),
	}


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
##   - [code]died=true[/code] → 本次调用让角色由存活转为阵亡（幂等——已阵亡不再为真）。[br]
func apply_damage(character_id: int, damage: int) -> Dictionary:
	var state: Variant = _states.get(character_id)
	if not (state is Dictionary) or not bool((state as Dictionary).get("known", false)):
		return {"known": false, "died": false, "side": SIDE_PLAYER, "current_hp": 0, "max_hp": 0}
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


# === 内部 ========================================================================

func _make_state(side: int, hp: int, max_hp: int, is_alive: bool, known: bool,
		ref: Variant) -> Dictionary:
	return {
		"side": side,
		"current_hp": maxi(hp, 0),
		"max_hp": maxi(max_hp, 0),
		"is_alive": is_alive,
		"known": known,
		"ref": ref,
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


## 卡牌模板 HP 回退——CardSystem/模板不可用时返回 0（= 未知）。
func _read_template_max_hp(card_system: Node, character_id: int) -> int:
	if card_system == null or not card_system.has_method(&"get_template_by_instance_id"):
		return 0
	var template: Variant = card_system.call(&"get_template_by_instance_id", character_id)
	if template == null:
		return 0
	var raw: Variant = template.get("base_hp")
	return maxi(int(raw), 0) if raw != null else 0


## 条目整数字段读取——兼容 Dictionary 与 Object（EnemyBattleState）。
func _entry_int(entry: Variant, key: String, fallback: int) -> int:
	return _entry_int_static(entry, key, fallback)


## 条目整数字段读取的静态变体（[method enemy_id_of] 等无实例入口复用）。
static func _entry_int_static(entry: Variant, key: String, fallback: int) -> int:
	if entry is Dictionary:
		return int((entry as Dictionary).get(key, fallback))
	if entry is Object and (entry as Object).has_method(&"get"):
		var raw: Variant = (entry as Object).get(key)
		return int(raw) if raw != null else fallback
	return fallback


## 条目任意字段读取——读不到时返回 null（区别于「读到 0」）。
static func _entry_raw_static(entry: Variant, key: String) -> Variant:
	if entry is Dictionary:
		return (entry as Dictionary).get(key)
	if entry is Object and (entry as Object).has_method(&"get"):
		return (entry as Object).get(key)
	return null
