extends RefCounted
## BattleResumePayload —— 「能不能回到这场战斗」所需的最小状态（纯函数）。[br]
## [br][b]缺在哪一步[/b]：暂停菜单的「存档」在战斗里照常可用，但它写的是
## [code]GSM.serialize()[/code]，而 [code]battle[/code] 域是[b]不可持久化[/b]的
## （ADR-0008 §GSM 边界：战斗结束即置 null）。于是「战斗中存档 → 继续游戏」回到的是
## 探索地图，玩家刚打的那场仗被静默丢弃——本模块把该存的那一份补上。[br]
## [br][b]存什么（最小闭环）[/b]：能重建这场战斗的[b]状态[/b]，不是能重放整场战斗的
## 录像——[br]
##   · 进度：阶段 / 回合 / 当前费用 / 费用上限；[br]
##   · 我方：角色 ID / 当前 HP / 上限 / 存活 / 前后排 / 阵位序号；[br]
##   · 敌方：角色 ID / 模板 ID / 当前 HP / 上限 / 存活 / 阵位；[br]
##   · 来源：origin node id / combat type / 开战配置（模板 ID、等级、掉落）。[br]
## [br][b]为什么不存整套 [code]battle_start[/code] 配置[/b]：配置里带
## [code]enemy_roster[/code]（[code]EnemyBattleState[/code] 对象）——对象过不了
## JSON 兼容校验，整份存档会被判 [code]VALIDATION_ERROR[/code]。故配置按[b]白名单[/b]
## 折叠成 JSON 安全形态（见 [method _safe_config]），名册另走本模块自己的条目结构。[br]
## [br][b]为什么存的是 String 而不是 StringName[/b]：存档往返会把 StringName 变成
## String；若写侧存 StringName、读侧还原成 String，「存前与读后逐项相等」这条断言
## 永远不成立（两处口径各写一遍必然漂移）。写出去时就落 String，读侧回给消费方时
## 由 [code]AISystem[/code] 的 [code]for tid: StringName[/code] 自动转回。[br]
## [br][b]为什么不做「渡劫战」[/b]：渡劫战不经过探索战斗节点（无 origin node / combat
## type），重建它还要带上 [code]tribulation_data[/code] 与渡劫状态机的位置——超出
## 「最小闭环」。此时 [method reason] 给出可读中文原因，由存档侧提示玩家，而不是
## 写一份[b]读回来没人认得[/b]的档（那才是真正的静默失败）。[br]
## [br][b]来源[/b]: ADR-0008 §GSM 边界、ADR-0002 §存档容器、ADR-0014 §决策 1、
## 本轮「战斗中存档 → 读档回到战斗」。

## 键名常量（单一真理来源——读侧不裸写字符串）。
const KEY_IS_ACTIVE: String = "is_active"
const KEY_SCENE_ID: String = "scene_id"
const KEY_PHASE: String = "phase"
const KEY_TURN: String = "turn"
const KEY_CURRENT_COST: String = "current_cost"
const KEY_MAX_COST: String = "max_cost"
const KEY_ORIGIN_NODE_ID: String = "origin_node_id"
const KEY_ORIGIN_COMBAT_TYPE: String = "origin_combat_type"
const KEY_PLAYER_ROSTER: String = "player_roster"
const KEY_ENEMY_ROSTER: String = "enemy_roster"
const KEY_CONFIG: String = "config"

## 牌面段与 debuff 段的[b]形状[/b]归各自的模块（本模块只把它们的产出并进载荷，
## 不重写一份键名——两处各写一遍必然漂移，而漂移的症状是「存了但读不回」）。
## 读侧同样直接问那两个模块（[code]battle_resume_cards.gd[/code] /
## [code]battle_resume_debuffs.gd[/code]）。
const CardsScript := preload("res://src/feature/combat/battle_resume_cards.gd")
const DebuffsScript := preload("res://src/feature/combat/battle_resume_debuffs.gd")

## 条目字段（我方 / 敌方共用同名者）。
const KEY_CHARACTER_ID: String = "character_id"
const KEY_TEMPLATE_ID: String = "template_id"
const KEY_CURRENT_HP: String = "current_hp"
const KEY_MAX_HP: String = "max_hp"
const KEY_IS_ALIVE: String = "is_alive"
const KEY_IS_FRONT: String = "is_front"
const KEY_SLOT_INDEX: String = "slot_index"

## 不可续玩时的中文原因（读侧与存档侧共用同一份文案口径）。
const TEXT_NOT_IN_BATTLE: String = ""
const TEXT_NO_ORIGIN: String = "本场战斗没有探索来源（渡劫等），无法续玩——存档已写入，但读档会回到探索地图"

## 配置白名单——只有这些键会进存档（见类文档「为什么不存整套配置」）。
const SAFE_CONFIG_KEYS: PackedStringArray = [
	"character_ids", "enemy_template_ids", "enemy_level", "rewards",
	"layout", "is_tribulation",
]


## 由战斗侧的一手状态组装存档载荷。[br]
## [br][param p_state] 取数包（各键缺失时按空处理——不臆造）：[br]
##   · [code]scene_id[/code] / [code]phase[/code] / [code]turn[/code] /
##     [code]current_cost[/code] / [code]max_cost[/code]；[br]
##   · [code]origin_node_id[/code] / [code]origin_combat_type[/code]；[br]
##   · [code]player_field[/code]：阵位快照（含 character_id / is_front / slot_index）；[br]
##   · [code]player_hp[/code]：[code]{character_id: {current_hp, max_hp, is_alive}}[/code]；[br]
##   · [code]enemy_roster[/code]：本场敌方名册（对象或字典条目）；[br]
##   · [code]config[/code]：本场 [code]battle_start[/code] 配置（按白名单折叠）；[br]
##   · [code]hand[/code] / [code]draw_pile[/code] / [code]discard_pile[/code]：三堆
##     牌面（[code]owned_cards[/code] 为收藏快照，用于补模板与等级）；[br]
##   · [code]debuffs[/code]：[code]CombatDebuffManager.snapshot()[/code] 的状态快照。[br]
## [br][b]返回[/b]：载荷字典；不可续玩（无探索来源）时返回空字典——调用方据此
## 走 [method reason] 的提示路径，而不是写一份读不回来的档。
static func build(p_state: Dictionary) -> Dictionary:
	if not is_resumable(p_state):
		return {}
	return {
		KEY_IS_ACTIVE: true,
		KEY_SCENE_ID: int(p_state.get("scene_id", 0)),
		KEY_PHASE: int(p_state.get("phase", 0)),
		KEY_TURN: int(p_state.get("turn", 1)),
		KEY_CURRENT_COST: int(p_state.get("current_cost", 0)),
		KEY_MAX_COST: int(p_state.get("max_cost", 0)),
		KEY_ORIGIN_NODE_ID: int(p_state.get("origin_node_id", -1)),
		KEY_ORIGIN_COMBAT_TYPE: str(p_state.get("origin_combat_type", "")),
		KEY_PLAYER_ROSTER: _player_entries(p_state),
		KEY_ENEMY_ROSTER: enemy_entries(p_state.get("enemy_roster", [])),
		KEY_CONFIG: _safe_config(p_state.get("config", {})),
		CardsScript.KEY_CARDS: CardsScript.fold(p_state),
		DebuffsScript.KEY_DEBUFFS: DebuffsScript.fold(p_state.get("debuffs", {})),
	}


## 本场战斗能否续玩——判据是「有探索来源」。[br]
## [br][b]为什么以来源为准[/b]：读档回到战斗要经探索战斗节点那条开战链
## （模板 ID / 等级 / 掉落 / 玩家阵容全由它给出）；没有来源就只剩一份别人认不得的
## 配置，重建出来的会是一场[b]看起来对、打起来不对[/b]的仗。
static func is_resumable(p_state: Dictionary) -> bool:
	if int(p_state.get("origin_node_id", -1)) >= 0:
		return true
	return not str(p_state.get("origin_combat_type", "")).is_empty()


## 不可续玩的中文原因（可续玩时为空串——调用方据此决定要不要提示）。
static func reason(p_state: Dictionary) -> String:
	return TEXT_NOT_IN_BATTLE if is_resumable(p_state) else TEXT_NO_ORIGIN


## 存档里是否有[b]进行中[/b]的战斗段——读档侧的唯一判据。[br]
## [br][b]判据不只看 [code]is_active[/code][/b]：名册为空说明这份载荷是残的
## （写一半 / 手改过），拿它去重建只会得到一场判不出胜负的战斗；此时按「没有战斗段」
## 处理，玩家回到探索地图——比进一场坏仗强。
static func is_resumable_payload(p_payload: Variant) -> bool:
	if not (p_payload is Dictionary):
		return false
	var payload: Dictionary = p_payload
	if not bool(payload.get(KEY_IS_ACTIVE, false)):
		return false
	if not (payload.get(KEY_PLAYER_ROSTER, []) is Array):
		return false
	if not (payload.get(KEY_ENEMY_ROSTER, []) is Array):
		return false
	return not (payload[KEY_PLAYER_ROSTER] as Array).is_empty() \
			and not (payload[KEY_ENEMY_ROSTER] as Array).is_empty()


## 存档里是否有[b]进行中[/b]的战斗——「这份档是不是在战斗中存的」的唯一判据。[br]
## [br][b]与 [method is_resumable_payload] 的分工[/b]：本方法只看标记位
## （[constant KEY_IS_ACTIVE]），回答「有没有」；后者还要求名册齐备，回答
## 「能不能真的重建」。读档侧导航用后者（不许把玩家带进一场判不出胜负的仗），
## 而「这份档该不该被当成战斗中存档」用本方法。[br]
## [br][param p_domain] [code]battle_resume[/code] 段的现值（GSM 域 / 存档片段）。[br]
static func is_in_battle(p_domain: Variant) -> bool:
	if not (p_domain is Dictionary):
		return false
	return bool((p_domain as Dictionary).get(KEY_IS_ACTIVE, false))


## 校验存档里那一段的战斗记录是否完整（空串 = 可续战）。[br]
## [br][b]与 [method reason] 分开[/b]：后者判「战斗侧能不能存」（有没有探索来源，
## 在存档时问），本方法判「存下来的这份载荷能不能读回来」（在组装之后问）——两者
## 都是「不能续战」，但问的时机与调用方不同。[br]
## [br][b]文案要能同时嵌进两头[/b]：存档侧把它接在「当前战斗无法续战：」之后，
## 读档侧单独成句——故只说事实，不说「已回到探索地图」这类读档侧的动作。
static func payload_reason(p_payload: Variant) -> String:
	if not (p_payload is Dictionary) or (p_payload as Dictionary).is_empty():
		return ""
	if bool((p_payload as Dictionary).get(KEY_IS_ACTIVE, false)) \
			and not is_resumable_payload(p_payload):
		return "战斗记录不完整"
	return ""


## 敌方名册条目——对象（[code]EnemyBattleState[/code]）与字典两种形态都读。[br]
## [br][b]character_id 走 [code]enemy_id_of[/code][/b]：与开战种子、战斗 UI 建卡
## 同一套编码；自己再推一遍必然在「同模板多实例」上错位。[br]
## [br][b]幂等[/b]：本函数既是写侧折叠、也是读侧解析（同一份载荷再过一遍），故阵位
## 先读本模块自己的 [constant KEY_SLOT_INDEX]，读不到才退回战斗侧的
## [code]field_position[/code]——只认后者会让「已折叠过的条目」全部丢阵位。[br]
## [br][b]返回[/b]：JSON 安全的字典数组（[code]template_id[/code] 落 String）。
static func enemy_entries(p_roster: Variant) -> Array:
	var Seeding := preload("res://src/feature/combat/combat_roster_seeding.gd")
	var out: Array = []
	if not (p_roster is Array):
		return out
	var roster: Array = p_roster
	for idx: int in range(roster.size()):
		var entry: Variant = roster[idx]
		if entry == null:
			continue
		out.append({
			KEY_CHARACTER_ID: Seeding.enemy_id_of(entry, idx),
			KEY_TEMPLATE_ID: str(Seeding.entry_raw(entry, "template_id")),
			KEY_CURRENT_HP: maxi(Seeding.entry_int(entry, "current_hp", 0), 0),
			KEY_MAX_HP: maxi(Seeding.entry_int(entry, "max_hp", 0), 0),
			KEY_IS_ALIVE: bool(Seeding.entry_int(entry, "is_alive", 1)),
			KEY_SLOT_INDEX: _entry_slot(entry),
			KEY_IS_FRONT: Seeding.enemy_is_front(entry),
		})
	return out


## 条目阵位——先认本模块折叠后的 [constant KEY_SLOT_INDEX]，再退回战斗侧的
## [code]field_position[/code]（见 [method enemy_entries] 的「幂等」说明）。
static func _entry_slot(p_entry: Variant) -> int:
	var Seeding := preload("res://src/feature/combat/combat_roster_seeding.gd")
	if Seeding.entry_raw(p_entry, KEY_SLOT_INDEX) != null:
		return Seeding.entry_int(p_entry, KEY_SLOT_INDEX, -1)
	return Seeding.entry_int(p_entry, "field_position", -1)


## 载荷 → 我方 [code]player_stats[/code]（[code]CombatRosterState.seed[/code] 吃的形态）。[br]
## [br][b]键为 int[/b]：[code]seed_player_field[/code] 按
## [code]stats.get(character_id, {})[/code] 取数；存档里是 String 键的场合由
## [code]combat_hp_carryover.seed_stats[/code] 的兼容读取兜住（本函数只负责内存形态）。
static func player_stats(p_payload: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw: Variant in _entries(p_payload, KEY_PLAYER_ROSTER):
		var cid: int = int((raw as Dictionary).get(KEY_CHARACTER_ID, -1))
		if cid < 0:
			continue
		out[cid] = {
			KEY_CURRENT_HP: int((raw as Dictionary).get(KEY_CURRENT_HP, 0)),
			KEY_MAX_HP: int((raw as Dictionary).get(KEY_MAX_HP, 0)),
		}
	return out


## 载荷 → 我方阵位布局（[code]DeploymentSystem.setup_field[/code] 的 layout 参数）。[br]
## [br][b]为什么必须带上[/b]：读档重建时阵位的分配顺序取决于备战面板的点选顺序，
## 而读档[b]不过面板[/b]——不给 layout 就会把玩家的前后排重新排一遍。
static func player_layout(p_payload: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw: Variant in _entries(p_payload, KEY_PLAYER_ROSTER):
		var cid: int = int((raw as Dictionary).get(KEY_CHARACTER_ID, -1))
		if cid >= 0:
			out[cid] = bool((raw as Dictionary).get(KEY_IS_FRONT, true))
	return out


## 载荷 → 我方出战角色 ID 列表（顺序即存档时的阵位顺序）。
static func player_ids(p_payload: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in _entries(p_payload, KEY_PLAYER_ROSTER):
		var cid: int = int((raw as Dictionary).get(KEY_CHARACTER_ID, -1))
		if cid >= 0 and not out.has(cid):
			out.append(cid)
	return out


## 载荷 → 开战上下文形态（[code]CombatLaunchContext[/code] 的键）。[br]
## [br]读档回战斗要经战斗场景的 [`method CombatSceneLaunch.consume`]，那里要的正是
## 四份输入；本方法把存档里那份折回去，避免在读档路径上再开一条开战链。
static func launch_context(p_payload: Dictionary) -> Dictionary:
	var Context := preload("res://src/feature/combat/combat_launch_context.gd")
	var config: Dictionary = _config(p_payload)
	return {
		Context.KEY_NODE_ID: int(p_payload.get(KEY_ORIGIN_NODE_ID, -1)),
		Context.KEY_COMBAT_TYPE: str(p_payload.get(KEY_ORIGIN_COMBAT_TYPE, "")),
		Context.KEY_TEMPLATE_IDS: config.get("enemy_template_ids", []),
		Context.KEY_ENEMY_ROSTER: [],
		Context.KEY_ENEMY_LEVEL: int(config.get("enemy_level", 0)),
		Context.KEY_REWARDS: config.get("rewards", {}),
		Context.KEY_PLAYER_ROSTER: player_ids(p_payload),
	}


## 存档里那一段的 [code]config[/code] 子字典（缺失时为空）。
static func _config(p_payload: Dictionary) -> Dictionary:
	var raw: Variant = p_payload.get(KEY_CONFIG, {})
	return raw if raw is Dictionary else {}


## 名册条目数组读取（非数组一律空——不臆造）。
static func _entries(p_payload: Dictionary, p_key: String) -> Array:
	var raw: Variant = p_payload.get(p_key, [])
	return raw if raw is Array else []


## 我方条目——阵位快照（[code]DeploymentSystem.get_field()[/code]）与 HP 表求交。[br]
## [br][b]以阵位为准遍历[/b]：没上场但有 HP 记录的角色不该进这份载荷（读档后会被
## 重新摆上场，等于凭空多出一名参战者）。
static func _player_entries(p_state: Dictionary) -> Array:
	var hp_table: Dictionary = p_state.get("player_hp", {})
	var out: Array = []
	for raw: Variant in p_state.get("player_field", []):
		if not (raw is Dictionary):
			continue
		var cid: int = int((raw as Dictionary).get(KEY_CHARACTER_ID, -1))
		if cid < 0:
			continue
		var hp: Dictionary = hp_table.get(cid, {})
		out.append({
			KEY_CHARACTER_ID: cid,
			KEY_CURRENT_HP: maxi(int(hp.get(KEY_CURRENT_HP, 0)), 0),
			KEY_MAX_HP: maxi(int(hp.get(KEY_MAX_HP, 0)), 0),
			KEY_IS_ALIVE: bool(hp.get(KEY_IS_ALIVE, true)),
			KEY_SLOT_INDEX: int((raw as Dictionary).get(KEY_SLOT_INDEX, -1)),
			KEY_IS_FRONT: bool((raw as Dictionary).get(KEY_IS_FRONT, true)),
		})
	return out


## 开战配置折叠为 JSON 安全白名单（见类文档「为什么不存整套配置」）。[br]
## [br][b]白名单的真理来源在本模块[/b]（[constant SAFE_CONFIG_KEYS]），折叠动作归
## [code]battle_resume_sanitize.gd[/code]（那里同时负责递归丢对象与 StringName 归一）。
static func _safe_config(p_config: Variant) -> Dictionary:
	var Sanitize := preload("res://src/feature/combat/battle_resume_sanitize.gd")
	return Sanitize.config(p_config, SAFE_CONFIG_KEYS)
