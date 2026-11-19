extends RefCounted
## CombatRosterSeeding —— 战斗状态表的[b]建表半边[/b]（名册 → 状态表，纯函数）。[br]
## [br][b]为什么拆出来[/b]：[code]combat_roster_state.gd[/code] 同时持「怎么建表」与
## 「怎么读/写表」两件事，加上战斗内法宝增益的落点后越过 300 行软上限
## （coding-standards）。建表是[b]一次性、无状态[/b]的换算（输入名册与注入数值，
## 输出一张新表），与「谁在读、谁在写」没有交集——是最干净的一条切线。[br]
## [br][b]纯函数，不持状态[/b]：本模块一个字段都没有，[code]build_*[/code] 每次都
## 返回[b]新表[/b]（调用方 merge 进自己的状态表）。这样「建表逻辑」可以脱离
## [CombatRosterState] 单独断言——状态表的写入路径只有一处（[code]apply_damage[/code]）。[br]
## [br][b]键编码与读取口径仍与状态表同源[/b]：[method enemy_id_of] /
## [method enemy_is_front] 的约定由本模块持有，状态表以 [code]const[/code] 转发
## 同名常量与静态方法——外部既有引用点（战斗 UI 建卡、敌方行动播报）一字未改。[br]
## [br][b]显示名也归本模块[/b]：名字长在名册条目与卡牌模板上，而「条目字段怎么读」
## 已经是本模块的口径（[method entry_raw] / [method read_template_field]）——
## 名字解析若留在 UI 层，Feature 层的战绩记录就只能写「角色 #ID」。见
## [method enemy_display_name] / [method resolve_name]。[br]
##
## 来源: ADR-0008 §Phase 4、ADR-0016 §阵位数据模型、tech-debt DEBT-CBT-018-1、
## 先例 [code]combat_roster_state.gd[/code] 的拆分注记。

## 阵营枚举（镜像 [signal CombatSystem.character_died] 的 side 参数——0 己方 / 1 敌方）。
const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1

## 敌方角色 ID 编码基数（与 ai_roster_factory 的绑定 ID 同源）。
const ENEMY_ID_BASE: int = 100000
## 敌方角色 ID 步长（每实例一段，避免同模板多实例 ID 冲突）。
const ENEMY_ID_STRIDE: int = 10000

## 名字全缺时的兜底文案（不让空名把一行战报变成「对『』造成…」）。
const NAME_UNKNOWN: String = "未知目标"


## 敌方角色 ID 派生——[b]单一来源[/b]：开战种子与战斗 UI 建卡必须落在同一键上，
## 否则 UI 读到的永远是 0/0。[br]
## [param entry] 阵容条目（自带 character_id 时优先——测试/预配置阵容可显式指定）。[br]
## [param index] 阵容下标（无显式 ID 时按约定派生）。
static func enemy_id_of(entry: Variant, index: int) -> int:
	var explicit: int = entry_int(entry, "character_id", -1)
	return explicit if explicit >= 0 else ENEMY_ID_BASE + index * ENEMY_ID_STRIDE


## 敌方条目的前后排判定——条目自带阵位信息时以其为准，缺省视为前排
## （敌方阵容快照通常不带阵位，UI 侧统一摆前排，不做无依据的臆测）。
static func enemy_is_front(entry: Variant) -> bool:
	var raw: Variant = entry_raw(entry, "is_front_row")
	if raw == null:
		raw = entry_raw(entry, "is_front")
	if raw is bool:
		return raw
	return true


## 建敌方阵容状态表——条目自带 character_id 时优先，否则按 AI 绑定 ID 约定派生。[br]
## [br][b]写回目标[/b]：[member ref] 记下条目本体（对象或 Dictionary）——状态表改动
## 时经它回写到外部持有方（见 [code]combat_roster_state._write_back[/code]）。[br]
## [br][b]返回[/b]：[code]{character_id: state}[/code]（新表；调用方自行 merge）。
static func build_enemy_states(roster: Array) -> Dictionary:
	var states: Dictionary = {}
	for idx: int in range(roster.size()):
		var entry: Variant = roster[idx]
		if entry == null:
			continue
		var character_id: int = enemy_id_of(entry, idx)
		var max_hp: int = entry_int(entry, "max_hp", 0)
		var hp: int = entry_int(entry, "current_hp", max_hp)
		var known: bool = max_hp > 0
		var state: Dictionary = make_state(SIDE_ENEMY, hp, max_hp,
				entry_int(entry, "attack", 0),
				entry_int(entry, "defense", 0),
				bool(entry_int(entry, "is_alive", 1)) and (hp > 0 or not known), known, entry)
		state["display_name"] = enemy_display_name(entry)
		states[character_id] = state
	return states


## 建我方阵位状态表——HP/ATK 来源优先级：注入 stats > 卡牌模板基础值 > 未知。[br]
## [br][param stats] 可带 [code]atk[/code] / [code]attack[/code]（任选其一）作为攻击力覆盖；
## 缺省回退模板 [code]base_attack[/code]（与战斗 UI 的 ATK 取数同源）。[br]
## [br][member ref] 恒为 null：我方条目的真理来源就是状态表本身（无外部持有者）。[br]
## [br][b]名字在开战时定格[/b]：从卡牌模板取一次写进状态表——结算战报读的是本场
## 开战时的名字，中途换绑/换模板不会让战报里的名字与战斗中看到的对不上。
static func build_player_states(field: Array, stats: Dictionary,
		card_system: Node = null) -> Dictionary:
	var states: Dictionary = {}
	for entry: Variant in field:
		var character_id: int = entry_int(entry, "character_id", -1)
		if character_id < 0:
			continue
		var injected: Variant = stats.get(character_id, {})
		var max_hp: int = 0
		var hp: int = 0
		var atk: int = 0
		var defense: int = 0
		if injected is Dictionary and not (injected as Dictionary).is_empty():
			max_hp = int((injected as Dictionary).get("max_hp", 0))
			hp = int((injected as Dictionary).get("current_hp",
					(injected as Dictionary).get("hp", max_hp)))
			atk = int((injected as Dictionary).get("atk",
					(injected as Dictionary).get("attack", 0)))
			defense = int((injected as Dictionary).get("defense",
					(injected as Dictionary).get("def", 0)))
		else:
			max_hp = read_template_field(card_system, character_id, "base_hp")
			hp = max_hp
			# 模板 base_defense 缺省 0 = 「未配置」，防御不加成也不臆造。
			defense = read_template_field(card_system, character_id, "base_defense")
		if atk <= 0:
			atk = read_template_field(card_system, character_id, "base_attack")
		var known: bool = max_hp > 0 or hp > 0
		var state: Dictionary = make_state(SIDE_PLAYER, hp, max_hp, atk, defense,
				hp > 0 or not known, known, null)
		state["display_name"] = card_display_name(card_system, character_id)
		states[character_id] = state
	return states


## 一条状态记录——负值一律夹到 0（不臆造负 HP / 负攻击）。[br]
## [param ref] 外部持有者（敌方阵容条目）；我方条目为 null。[br]
## [br][b]不含 display_name[/b]：名字不是「一条状态」的固有属性（同一张表里
## 敌方从名册条目取、我方从卡牌模板取），由两个 [code]build_*[/code] 各自写入——
## 塞进本函数就得额外传一个「从哪儿找名字」的参数。
static func make_state(side: int, hp: int, max_hp: int, atk: int, defense: int,
		is_alive: bool, known: bool, ref: Variant) -> Dictionary:
	return {
		"side": side,
		"current_hp": maxi(hp, 0),
		"max_hp": maxi(max_hp, 0),
		"atk": maxi(atk, 0),
		"defense": maxi(defense, 0),
		"is_alive": is_alive,
		"known": known,
		"ref": ref,
	}


# === 显示名解析（Feature 层口径——UI 与战报共用）=============================

## 名册条目的显示名——[code]display_name[/code] 直取优先，其次模板对象/模板 ID。[br]
## [br][b]为什么 db 层要给名字[/b]：结算战报要写「谁还剩多少血」，只给
## [code]角色 #12[/code] 的报表玩家读不出是谁；而名册条目与卡牌模板都是本层
## 的数据，解析留在这里才不必让 Feature 反向依赖 UI 的命名解析器。[br]
## [br][b]取不到返回空串[/b]：空串 = 「这里没有名字」，交给 [method resolve_name]
## 决定兜底文案（本方法不擅自编一个）。
static func enemy_display_name(entry: Variant) -> String:
	if entry == null:
		return ""
	var direct: String = _non_empty(entry_raw(entry, "display_name"))
	if direct != "":
		return direct
	var template_name: String = _template_name(entry_raw(entry, "template"))
	if template_name != "":
		return template_name
	return _non_empty(entry_raw(entry, "template_id"))


## 卡牌模板的显示名——[code]display_name[/code] 优先，回退旧字段 [code]name[/code]。[br]
## [br][b]取不到返回空串[/b]：CardSystem 缺失 / 查不到该实例时同样给空串
## （「读不到」与「没名字」在展示端是同一条兜底路径）。
static func card_display_name(card_system: Node, character_id: int) -> String:
	if card_system == null or not card_system.has_method(&"get_template_by_instance_id"):
		return ""
	var template: Variant = card_system.call(&"get_template_by_instance_id", character_id)
	if template == null:
		return ""
	for key: String in ["display_name", "name"]:
		var value: Variant = template.get(key)
		if value != null and str(value) != "":
			return str(value)
	return ""


## 名字解析的[b]唯一兜底入口[/b]：拿到空名字时按 ID 段给可读编号。[br]
## [br][b]返回[/b]：非空串——最差也是 [code]敌人 #100000[/code] / [code]角色 #12[/code]。[br]
## [br][b]为什么兜底要分段[/b]：敌方 ID 从 [constant ENEMY_ID_BASE] 起算，玩家看到
## 「敌人 #100000」知道那是敌人，看到「角色 #12」知道那是自己人——统一叫「角色」
## 会让敌我两栏认不出谁是谁。
static func resolve_name(p_display_name: String, p_character_id: int) -> String:
	if p_display_name != "":
		return p_display_name
	return fallback_name(p_character_id)


## 兜底名——按 ID 段区分「敌人」与「角色」（保证玩家至少能看到编号）。
static func fallback_name(p_character_id: int) -> String:
	if p_character_id < 0:
		return NAME_UNKNOWN
	if p_character_id >= ENEMY_ID_BASE:
		return "敌人 #%d" % p_character_id
	return "角色 #%d" % p_character_id


## 模板对象的显示名（[code]display_name[/code] / [code]name[/code]）。
static func _template_name(template: Variant) -> String:
	if not (template is Object):
		return ""
	for key: String in ["display_name", "name"]:
		var value: Variant = (template as Object).get(key)
		var text: String = _non_empty(value)
		if text != "":
			return text
	return ""


## 非空字符串化——null / 空串一律归一成空串（「读不到」与「是空名」同一条兜底路径）。
static func _non_empty(value: Variant) -> String:
	return "" if value == null else str(value)


## 卡牌模板字段回退——CardSystem/模板不可用时返回 0（= 未知）。[br]
## [br][param key] 模板字段名（[code]base_hp[/code] / [code]base_attack[/code]）。
static func read_template_field(card_system: Node, character_id: int, key: String) -> int:
	if card_system == null or not card_system.has_method(&"get_template_by_instance_id"):
		return 0
	var template: Variant = card_system.call(&"get_template_by_instance_id", character_id)
	if template == null:
		return 0
	var raw: Variant = template.get(key)
	return maxi(int(raw), 0) if raw != null else 0


## 条目整数字段读取——兼容 Dictionary 与 Object（EnemyBattleState）。
static func entry_int(entry: Variant, key: String, fallback: int) -> int:
	if entry is Dictionary:
		return int((entry as Dictionary).get(key, fallback))
	if entry is Object and (entry as Object).has_method(&"get"):
		var raw: Variant = (entry as Object).get(key)
		return int(raw) if raw != null else fallback
	return fallback


## 条目任意字段读取——读不到时返回 null（区别于「读到 0」）。
static func entry_raw(entry: Variant, key: String) -> Variant:
	if entry is Dictionary:
		return (entry as Dictionary).get(key)
	if entry is Object and (entry as Object).has_method(&"get"):
		return (entry as Object).get(key)
	return null
