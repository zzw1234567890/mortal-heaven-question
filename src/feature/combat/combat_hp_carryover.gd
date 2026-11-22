extends RefCounted
## CombatHpCarryover —— 我方角色 HP 的跨战斗持久化（DEBT-CBT-018-3 收口）。[br]
## [br][b]缺在哪一步[/b]：此前 [code]CombatRosterState[/code] 的种子来源只有
## [code]battle_start.player_stats[/code]（可选键，实际为空）→ 回退卡牌模板
## [code]base_hp[/code]，即每场战斗都从满血开始；战斗结束清空状态表后残血无处可写。
## 本模块补上「开战读、结束写」两条口子，让「带伤进入下一场」成立。[br]
## [br][b]存储位置[/b]：[code]GameStateManager.player.character_hp[/code]——[br]
##   [code]{"<character_id>": {"current_hp": int, "max_hp": int}}[/code]（键为字符串，
##   与存档 JSON 的「对象键必为字符串」事实一致；读取时兼容整数键）。[br]
##   选 [code]player[/code] 域而非 [code]battle[/code] 域：后者战斗结束即被置 null
##   （ADR-0008 §GSM 边界），存不下跨场数据。[br]
## [br][b]写入路径唯一[/b]：经 GSM 第二层原子方法 [code]_set_player_character_hp[/code]
## （ADR-0001 §第二层原子写入），不直接改属性、不另开存储。逐角色写入，
## 带同值去重（[code]player.character_hp.<id>[/code] 路径）。[br]
## [br][b]回读接口[/b]（本模块即唯一读侧，外部不直接摸 GSM 内部结构）：[br]
##   · [method read_all] —— 全表 [code]{int_character_id: {current_hp, max_hp}}[/code]；[br]
##   · [method read_one] —— 单角色；无记录返回空字典（调用方据此回退模板）；[br]
##   · [method seed_stats] —— 折成 [method CombatRosterState.seed] 吃的 [code]player_stats[/code] 形态。[br]
## [br][b]上游没有存档口径时的降级行为[/b]（显式裁定，不静默）：[br]
##   · [b]读[/b]：GSM 不可用 / [code]player[/code] 非字典 / 域内无 [code]character_hp[/code]
##     键 / 键值不是字典 → 一律返回空表，开战即回退卡牌模板 [code]base_hp[/code]
##     （旧存档与剥离 Autoload 的测试环境都走这条，战斗照常进行，不崩溃）；[br]
##   · [b]写[/b]：GSM 不可用或缺少 [code]_set_player_character_hp[/code] 入口 →
##     [code]push_warning[/code] 并整场跳过回写，返回 [constant WRITE_UNAVAILABLE]（-1）——
##     本场残血丢失，但战斗结算本身不受影响（宁可丢一次持久化，也不为它造第二条存储）。[br]
##     返回 -1 而不是 0：0 是「场上没有可写条目」的合法结果，调用方据此区分
##     「没数据」与「写了但没写成」，日志与诊断不混淆。[br]
## [br][b]口径裁定[/b]：阵亡角色照实写 [code]current_hp = 0[/code]——不夹到 1 冒充存活
## （GDD combat-system.md §7「跨战斗死亡持久性」要求死亡跨场保持）。
## 「阵亡 → 不可用」的 [code]mark_unavailable[/code] 仍归 interaction epic（本模块只管 HP）。[br]
## [br][b]未知角色不写[/b]：状态表 [code]known=false[/code]（模板缺失 / 未种子）的条目
## 没有可信数值，写入 0/0 会把「读不到数据」变成「角色已死」——按信息不足原则跳过。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、
## tech-debt DEBT-CBT-018-3、ADR-0001 §第二层原子写入、ADR-0008 §GSM 边界、
## GDD combat-system.md §7/§9、GDD deployment-system.md §10。

## 阵营常量——镜像 [code]combat_roster_state.gd[/code]（0 己方 / 1 敌方）。
const SIDE_PLAYER: int = 0

## Autoload 查找器——本模块内的查找已收拢到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")

## GSM [code]player[/code] 域内的存储键。
const STORAGE_KEY: String = "character_hp"

## 回写不可用（GSM 缺入口）时的返回值——区别于 0（无条目可写）。
const WRITE_UNAVAILABLE: int = -1

## 父节点引用——CombatSystem 实例（仅用于表明归属，查找走 SceneTree）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 读 ==========================================================================

## 读取全部持久 HP——[code]{int_character_id: {current_hp, max_hp}}[/code]。[br]
## 任何一层读不到（GSM 缺失 / 域非字典 / 无该键）都返回空表（见类文档降级节）。
func read_all() -> Dictionary:
	var raw: Variant = _raw_storage()
	if not (raw is Dictionary):
		return {}
	var out: Dictionary = {}
	for key: Variant in (raw as Dictionary).keys():
		var character_id: int = _parse_id(key)
		if character_id < 0:
			continue
		var entry: Dictionary = _normalize(raw[key])
		if entry.is_empty():
			continue
		out[character_id] = entry
	return out


## 读取单个角色的持久 HP——无记录返回空字典（调用方据此回退模板）。
func read_one(character_id: int) -> Dictionary:
	return read_all().get(character_id, {})


## 开战种子——把持久 HP 与显式 [code]player_stats[/code] 合成一张表。[br]
## [br][b]优先级[/b]：显式 [code]player_stats[/code] > 持久 HP（显式即「上游已裁定」）；
## 两者都没有的角色不出现在结果里 → [code]seed_player_field[/code] 回退模板 [code]base_hp[/code]。[br]
## [br][b]阵亡角色警告[/b]：读回 [code]current_hp == 0[/code] 时发射警告，调用方据此处理
## 「跳过上场」或「不可用」逻辑（GDD combat-system.md §7）。[br]
## [br][param player_field] [code]DeploymentSystem.get_field()[/code] 快照（取上场角色）。[br]
## [param explicit_stats] [code]battle_start.player_stats[/code]（可为空字典）。[br]
## [br][b]返回[/b]：合并后的 HP 表 + 零 HP 角色列表（警告用）。
func seed_stats(player_field: Array, explicit_stats: Dictionary) -> Dictionary:
	var merged: Dictionary = read_all()
	if explicit_stats.is_empty():
		return merged
	for raw: Variant in player_field:
		var character_id: int = _field_id(raw)
		if character_id < 0:
			continue
		var override: Variant = explicit_stats.get(character_id,
				explicit_stats.get(str(character_id), null))
		if override is Dictionary and not (override as Dictionary).is_empty():
			merged[character_id] = (override as Dictionary).duplicate(true)
	return merged


# === 写 ==========================================================================

## 战斗结束回写我方 HP——[param entries] 为 [method CombatRosterState.snapshot_all] 的产出。[br]
## [br][b]写入范围[/b]：只写 [code]side == SIDE_PLAYER[/code] 且 [code]known == true[/code] 的条目
## （敌方 HP 由 AI epic 持有；未知角色不臆造数值）。[br]
## [br][b]返回[/b]：实际回写条目数；[constant WRITE_UNAVAILABLE] = 无 GSM 入口、整场跳过；
## 0 = 场上有条目但没有一条可写（全敌方 / 全未知 / 空表）。[br]
func write_back(entries: Array) -> int:
	var gsm: Node = _gsm()
	if gsm == null or not gsm.has_method(&"_set_player_character_hp"):
		push_warning("CombatHpCarryover: 无 GSM 回写入口——本场 HP 未持久化"
				+ "（降级：下一场按模板满血开局）")
		return WRITE_UNAVAILABLE
	var written: int = 0
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if int(entry.get("side", SIDE_PLAYER)) != SIDE_PLAYER:
			continue
		if not bool(entry.get("known", false)):
			continue
		var character_id: int = int(entry.get("character_id", -1))
		if character_id < 0:
			continue
		gsm.call(&"_set_player_character_hp", character_id, {
			"current_hp": int(entry.get("current_hp", 0)),
			"max_hp": int(entry.get("max_hp", 0)),
		})
		written += 1
	return written


# === 内部 ========================================================================

## GSM [code]player.character_hp[/code] 的原始值——任一层缺失返回 null。
func _raw_storage() -> Variant:
	var gsm: Node = _gsm()
	if gsm == null:
		return null
	var player: Variant = gsm.get("player")
	if not (player is Dictionary):
		return null
	return (player as Dictionary).get(STORAGE_KEY, null)


## 条目归一——非字典 / 缺 max_hp 且无 current_hp 的条目视为无效（返回空）。
func _normalize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var item: Dictionary = raw
	if not item.has("current_hp") and not item.has("max_hp"):
		return {}
	var max_hp: int = maxi(int(item.get("max_hp", 0)), 0)
	var hp: int = maxi(int(item.get("current_hp", 0)), 0)
	if max_hp > 0:
		hp = mini(hp, max_hp)  # 存档值越界时夹进上限（不放大生命）
	return {"current_hp": hp, "max_hp": max_hp}


## 存储键 → 角色 ID（兼容字符串键与整数键；非数字键返回 -1）。
func _parse_id(key: Variant) -> int:
	if key is int:
		return key if key >= 0 else -1
	var text: String = str(key).strip_edges()
	if not text.is_valid_int():
		return -1
	var parsed: int = text.to_int()
	return parsed if parsed >= 0 else -1


## 阵位条目 → 角色 ID（Dictionary / Object 两种形态都读）。
func _field_id(entry: Variant) -> int:
	if entry is Dictionary:
		return int((entry as Dictionary).get("character_id", -1))
	if entry is Object and (entry as Object).has_method("get"):
		var raw: Variant = (entry as Object).get("character_id")
		return int(raw) if raw != null else -1
	return -1


## GSM Autoload——不可用返回 null（父节点引用仅用于表明归属，查找走统一查找器）。
func _gsm() -> Node:
	return AutoloadAccess.find(AutoloadAccess.GAME_STATE_MANAGER)
