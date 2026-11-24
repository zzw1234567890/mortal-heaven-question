## DeploymentSystem 不可用生命周期层（继承链第 6 段）——[b]跨战斗死亡持久[/b]。
##
## [b]本层职责[/b]：阵亡名单的本地权威（[member _unavailable_characters]）与其落库时机。[br]
##   · [method mark_unavailable] / [method revive_character]——标记与解除，两端都[b]写入即落库[/b]
##     （[method _push_unavailable_to_gsm]），避免「阵亡只活在内存里，一存档就复活」；[br]
##   · [method get_unavailable_characters]——商店/事件系统查询复活道具可用性；[br]
##   · [method is_game_over]——战斗开始前由 CombatSystem 调用（触发游戏失败），roster 必传
##     （去掉默认值，强制调用方显式传入，避免「漏传 roster → 永远不判负」的静默失败）。[br]
##
## [b]为什么本层排在战斗操作层之后[/b]：本层是链上最靠后的两段之一，只需祖先段已可见的
## [method _push_unavailable_to_gsm] 与 [member _unavailable_characters]。[br]
##
## 来源: ADR-0016 §不可用角色生命周期 / GDD deployment-system.md §跨战斗死亡持久。

extends "res://src/feature/deployment/deployment_system_battle_ops.gd"

# === 不可用角色生命周期（ADR-0016 §跨战斗死亡持久）=================================

## 战斗结算时标记角色不可用——加入 [member _unavailable_characters] 并发射 [signal character_unavailable]。[br]
## [br][b]存储结构[/b]：[code]{death_turn, death_battle_id, revival_methods}[/code]——[param death_context]
## 缺字段填充默认值（death_turn=0 / death_battle_id="" / revival_methods=[]）。[br]
## [br][b]重复标记[/b]：同一角色重复标记时覆盖旧 context（战斗结算逻辑保证一个角色只标记一次）。[br]
## [br][b]同步落库[/b]：[member _unavailable_characters] 是这份状态的本地权威，但存档读的是
## GSM 的 [code]player.unavailable_characters[/code]——标完立刻 [method _push_unavailable_to_gsm]
## 推一次，避免「阵亡只活在内存里，一存档就复活」。[br]
## [br][param character_id] 阵亡角色 ID。[br]
## [br][param death_context] 死亡上下文 [code]{death_turn, death_battle_id, revival_methods?}[/code]。
func mark_unavailable(character_id: int, death_context: Dictionary) -> void:
	_unavailable_characters[character_id] = {
		"death_turn": int(death_context.get("death_turn", 0)),
		"death_battle_id": str(death_context.get("death_battle_id", "")),
		"revival_methods": death_context.get("revival_methods", []).duplicate(true),
	}
	_push_unavailable_to_gsm()
	_emit_character_unavailable(character_id)


## 返回不可用角色 ID 列表——商店/事件系统查询复活道具可用性。[br]
## [br][b]返回[/b]: [code]Array[int][/code]——[member _unavailable_characters] 的键列表（可为空）。
func get_unavailable_characters() -> Array:
	return _unavailable_characters.keys()


## 复活不可用角色——从 [member _unavailable_characters] 移除并发射 [signal character_revived]。[br]
## [br]角色属性保留但空载（无绑定卡——绑定卡生命周期由 BindingManager 处理）。[br]
## [br][b]同步落库[/b]：与 [method mark_unavailable] 对称——复活也要推一次 GSM，
## 否则存档里那句「此人已阵亡」会在读档时把人重新按死。[br]
## [br][param character_id] 待复活角色 ID。[br]
## [br][b]返回[/b]: true = 成功复活；false = 角色不在不可用列表中（不发射信号）。
func revive_character(character_id: int) -> bool:
	if not _unavailable_characters.has(character_id):
		return false
	_unavailable_characters.erase(character_id)
	_push_unavailable_to_gsm()
	_emit_character_revived(character_id)
	return true


## 把 [member _unavailable_characters] 推给 GSM——[b]写入即落库[/b]的唯一转发点。[br]
## [br][b]为什么标完就推[/b]：存档读的是 GSM 的那份（[code]player.unavailable_characters[/code]），
## 本地表只是权威副本——只在战斗结束时推（[method sync_unavailable_to_gsm] 的旧时机）
## 意味着玩家在路上阵亡、直接退出游戏时，这次死亡从未进过存档。[br]
## [br][b]GSM 不可用[/b]：静默跳过（委托方 [code]deployment_serializer[/code] 的双守卫），
## 内存里的标记照常生效。[br]
func _push_unavailable_to_gsm() -> void:
	_get_serializer().sync_unavailable_to_gsm()


## 全部角色位不可用判定——战斗开始前由 CombatSystem 调用（触发游戏失败）。[br]
## [br][b]角色位数据来源[/b]：DeploymentSystem 不持有角色位总列表（角色位属 CardSystem/CombatSystem 管理），
## 由调用方注入 [param roster]（角色位角色 ID 列表）。[br]
## [br][b]必传参数[/b]：roster 为必传——去掉默认值，强制调用方显式传入，避免「漏传 roster → 永远不判负」
## 的静默失败模式（lead-programmer CONCERNS）。[br]
## [br][b]判定逻辑[/b]：roster 为空 → false（无角色位数据，不误判失败）；
## roster 中存在任一角色不在 [member _unavailable_characters] 中 → false（有可用角色）；
## roster 全部角色均不可用 → true。[br]
## [br][param roster] 角色位角色 ID 列表（6 个角色位的当前持有角色）。[br]
## [br][b]返回[/b]: true = 全部不可用（游戏失败）；false = 有可用角色或列表为空。
func is_game_over(roster: Array) -> bool:
	if roster.is_empty():
		return false
	for cid in roster:
		if not _unavailable_characters.has(int(cid)):
			return false  # 有至少 1 个可用角色
	return true
