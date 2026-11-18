extends RefCounted
## BattleResumeDebuffs —— 续战存档里[b]回合内 debuff 条目[/b]的形状与灌回（纯函数）。[br]
## [br][b]补的断链[/b]：上一轮的续战段记下了「谁、多少血、第几回合、什么阶段、
## 还有多少费」，唯独没记 debuff。读档回来时 [code]battle_start[/code] 会
## [code]clear()[/code] 整张状态表（debuff 随之清空），玩家存档那一刻挂在敌人身上的
## 「降攻 3 层、还剩 2 回合」凭空蒸发——而他读回来的是同一个人、同一场仗。[br]
## [br][b]存哪几条[/b]：目标 ID / 类型 / 剩余回合 / 每层数值 / 来源 ID——正好是
## [code]CombatDebuffManager.apply[/code] 的入参（外加目标）。存成「可以直接再施加
## 一遍」的形状，读侧就不必再推一遍层数×数值。[br]
## [br][b]为什么逐条存而不是存「合并后的总量」[/b]：debuff 的剩余回合是[b]逐条[/b]
## 计时的（同一目标可以挂一条「降攻 2 回合」和一条「降攻 1 回合」），合并成一条会
## 让两批到期的时点塌成一个——玩家读档后多挨或少挨一回合的降攻。[br]
## [br][b]为什么不做 [code]stacks[/code] 字段[/b]：管理器的 [code]apply[/code] 每次
## 只加 1 层（[code]stacks[/code] 恒为 1），层数由条目条数体现。存一个恒为 1 的字段
## 是把「条数」这一事实写两遍——两处一旦不一致（手改档），读回来的是个自相矛盾的
## 状态。故本模块按条数还原层数。[br]
## [br]来源: ADR-0008 §GSM 边界、design/gdd/combat-system.md §公式（debuff 修正 →
## 防御减免）、[code]combat_debuff_manager.gd[/code] §状态表、
## [code]battle_resume_payload.gd[/code] §最小闭环。

## 载荷里的段名（本模块是该段形状的真理来源）。
const KEY_DEBUFFS: String = "debuffs"

## 条目字段（与 [code]CombatDebuffManager.apply[/code] 的入参同名——跨层不另起名）。
const KEY_TARGET_ID: String = "target_id"
const KEY_TYPE: String = "type"
const KEY_DURATION: String = "duration"
const KEY_AMOUNT: String = "amount"
const KEY_SOURCE_ID: String = "source_id"

## 施加者未知（与 [code]apply[/code] 的缺省一致）。
const NO_SOURCE: int = -1
## 不属于任何类型的键（认不出的一律跳过——不臆造一种 debuff）。
const NO_TYPE: int = -1

const DebuffScript := preload("res://src/feature/combat/combat_debuff_manager.gd")


## 把 debuff 管理器的状态快照折成存档条目数组（按目标 ID / 类型 / 到期时序稳定排序）。[br]
## [br][param p_snapshot] [code]CombatDebuffManager.snapshot()[/code] 的产出——
## [code]{character_id: {type_key: [{stacks, duration, amount, source_id}]}}[/code]。[br]
## [br][b]为什么排序[/b]：字典的键序在 Godot 里是插入序，而插入序取决于施加顺序——
## 同一场仗两次抓快照（存档一次、测试再抓一次）可能拿到不同的键序；排序让载荷形状
## 确定，往返等价断言才比的是同一件事。[br]
## [br][b]认不出类型的条目整个丢掉[/b]：留一条读侧还原不了的会变成「挂着一个
## 看不见的 debuff」（数值被扣、界面无图标），比丢一条更难查。[br]
static func fold(p_snapshot: Variant) -> Array:
	var out: Array = []
	if not (p_snapshot is Dictionary):
		return out
	var by_target: Dictionary = p_snapshot
	var target_ids: Array = by_target.keys()
	target_ids.sort()
	for raw_target: Variant in target_ids:
		var target_id: int = int(raw_target)
		var by_type: Variant = by_target[raw_target]
		if not (by_type is Dictionary):
			continue
		var type_keys: Array = (by_type as Dictionary).keys()
		type_keys.sort()
		for raw_key: Variant in type_keys:
			var debuff_type: int = DebuffScript.type_of_key(str(raw_key))
			if debuff_type == NO_TYPE:
				continue
			var entries: Variant = (by_type as Dictionary)[raw_key]
			if not (entries is Array):
				continue
			for raw_entry: Variant in (entries as Array):
				if not (raw_entry is Dictionary):
					continue
				out.append({
					KEY_TARGET_ID: target_id,
					KEY_TYPE: debuff_type,
					KEY_DURATION: int((raw_entry as Dictionary).get(KEY_DURATION, 0)),
					KEY_AMOUNT: int((raw_entry as Dictionary).get(KEY_AMOUNT, 0)),
					KEY_SOURCE_ID: int((raw_entry as Dictionary).get(KEY_SOURCE_ID,
							NO_SOURCE)),
				})
	return out


## 把存档条目逐条灌回 debuff 管理器（读档续战的落点）。[br]
## [br][param p_manager] [code]CombatDebuffManager[/code]（带 [code]apply[/code]）。[br]
## [param p_payload] 存档里的续战段。[br]
## [br][b]返回[/b]：真的被施加的条数（层数已满 / 类型认不出 / 数值非正的会被
## [code]apply[/code] 拒掉，不计入）。[br]
## [br][b]不先 clear[/b]：[code]battle_start[/code] 已经在种子状态表时清过一遍，
## 再清一次会把「读档后重写快照」这类调用方已经落好的状态抹掉。落点由调用方
## 决定（本函数只管「把这一段灌进去」）。[br]
static func restore(p_manager: Variant, p_payload: Variant) -> int:
	if p_manager == null or not (p_manager is Object) \
			or not (p_manager as Object).has_method(&"apply"):
		return 0
	var applied: int = 0
	for raw: Variant in entries_of(p_payload):
		var entry: Dictionary = raw
		var ok: bool = bool((p_manager as Object).call(&"apply",
				int(entry.get(KEY_TARGET_ID, -1)),
				int(entry.get(KEY_TYPE, NO_TYPE)),
				int(entry.get(KEY_DURATION, 0)),
				int(entry.get(KEY_AMOUNT, 0)),
				int(entry.get(KEY_SOURCE_ID, NO_SOURCE))))
		if ok:
			applied += 1
	return applied


## 存档段里的 debuff 条目（非数组一律空——不臆造）。
static func entries_of(p_payload: Variant) -> Array:
	if not (p_payload is Dictionary):
		return []
	var raw: Variant = (p_payload as Dictionary).get(KEY_DEBUFFS, [])
	return raw if raw is Array else []


## 这一份档是否带着 debuff 快照——读档侧「要不要接管 debuff」的判据。[br]
## [br][b]与 [method entries_of] 的分工[/b]：后者读条目（空段与没有段都返回空数组），
## 本方法只回答「有没有」——v3 老档迁移补出的是空数组（形状归一），照它去接管
## 等于把 [code]battle_start[/code] 之后新挂上的 debuff 当成「存档里就有的」。[br]
static func has_state(p_payload: Variant) -> bool:
	return not entries_of(p_payload).is_empty()
