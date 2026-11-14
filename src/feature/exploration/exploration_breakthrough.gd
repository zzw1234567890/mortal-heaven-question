extends "res://src/feature/exploration/exploration_breakthrough_status.gd"
## ExplorationBreakthrough —— 打坐/洞府节点的「境界突破」[b]结算半边[/b]（Feature 层）。[br]
## [br][b]职责[/b]：把「到达洞府后打坐冲关」落到玩法状态上——校验修为是否够 →
## 用[b]注入的随机源[/b]掷成功率 → 成功则扣修为 + 升境界（属性按配置重算并落盘），
## 失败则按配置扣一部分修为且境界不变。两种结果的[b]中文提示都由本层产出[/b]
## （面板原样显示，措辞只有一处）。[br]
## [br][b]只读半边在父类[/b]（[code]exploration_breakthrough_status.gd[/code]）：
## 状态查询 / 属性快照 / 结果形状 / 系统接入。本文件只写。[br]
## [br][b]属性重算走既有单写者，不另开第二条通路[/b]：[br]
##   · 境界写入——[code]RealmSystem.realm_up(old)[/code] → GSM
##     [code]change_realm[/code]（ADR-0010 §realm_up 编排器）；[br]
##   · 修为上限重算——[code]realm_changed[/code]（Cat 1）→
##     [code]CultivationSystem.update_max_cultivation[/code]，并顺带
##     [code]settle_overflow[/code]（GDD §6/§7）。本模块[b]不自己算
##     max_cultivation[/b]——那是境界表的派生值，重算一次就够了；[br]
##   · 其余属性（[code]max_deploy[/code] / [code]deck_limit[/code] / …）是
##     [code]realm_table[/code] 的[b]查询值[/b]，境界一变即生效——本模块把它们
##     快照进返回值供 UI/测试读取（[code]attributes[/code]）。[br]
## [br][b]落盘[/b]：修为与境界都写在 GSM 的 [code]player[/code] 域
## （[code]PERSISTABLE_DOMAINS[/code] 含 [code]player[/code]），随
## [code]GameStateManager.serialize()[/code] 一并落盘——与渡劫结算同一条通路。[br]
## [br][b]修为永不落负[/b]：成功与失败两条扣减路径都过 [code]maxi(..., 0)[/code]，
## 且所有拒绝路径（境界已满 / 修为不足 / 配置缺失 / 系统不可用）都在[b]任何写入
## 之前[/b]返回——同商店「拒绝路径在扣费之前」、采集「拒绝路径在写包之前」口径。[br]
## [br][b]半成品防护[/b]：境界写入通道不可用时把已扣的修为[b]原样退回[/b]
## （「扣了修为没升境界」不该存在——同商店「卡没到就把灵石退回」）。[br]
## [br][b]与渡劫台的边界[/b]：渡劫台是[b]战斗[/b]（打赢才升境界，撤退扣 15%），
## 本节点是[b]无战斗的冲关尝试[/b]——成功率与惩罚刻意分开（见
## [code]ExplorationBreakthroughTable[/code] §10% 的来源）。同一境界表、同一
## [code]realm_up[/code] 编排器，只有「要不要打一场」不同。[br]
## [br][b]可重复尝试[/b]：本节点不记「本节点已用过」——失败后修为还够就能再冲，
## 这正是失败惩罚存在的意义（对比采集点的「同槽位只此一次」）。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§6/§边界/§调优参数、
## docs/decisions/ADR-0010 §realm_up 编排器、ADR-0021 §_handle_tribulation_failure、
## 先例 [code]exploration_craft.gd[/code]（校验先于写入 + 可注入 RNG）/
## [code]exploration_harvest.gd[/code]（结算与中文提示单点）。


## 尝试突破下一境界。[br]
## [br][b]返回[/b]：[code]{success, reason, message, rolled, realm_before,
## realm_after, cultivation_before, cultivation_after, spent, penalty,
## attributes, cultivation_full}[/code]——[code]success[/code] 为「本次尝试成立
## 且掷中」（被拒时 false 且 [code]rolled=false[/code]，据此与「掷骰失败」区分）；
## [code]message[/code] 为面向玩家的中文提示。[br]
## [br][b]成功路径[/b]：扣 [code]required[/code] 修为（夹 0）→
## [code]RealmSystem.realm_up[/code] 升境界（属性按配置重算 + 落盘）。[br]
## [br][b]失败路径[/b]：扣 [code]penalty[/code] 修为（夹 0），境界不变。[br]
## [br][b]随机源[/b]：[member rng] 注入优先，缺口时自建随机实例——同种子恒同结果。[br]
## [br][b]拒绝路径全在任何写入之前[/b]：见类文档「修为永不落负」。
func attempt() -> Dictionary:
	var store: Node = _gsm()
	if store == null:
		return reject("system_unavailable", "系统不可用，突破未执行", 0, 0)
	var player: Dictionary = store.get(&"player")
	var realm: int = int(player.get("realm", 1))
	var cultivation: int = int(player.get("cultivation", 0))
	var max_cult: int = int(player.get("max_cultivation", 0))
	if realm >= TableScript.max_realm():
		return reject("at_max", TableScript.TEXT_AT_MAX, realm, cultivation)
	var required: int = TableScript.required_cultivation(realm)
	if required <= 0:
		return reject("no_config", "境界配置缺失，突破未执行", realm, cultivation)
	if cultivation < required:
		return reject("not_enough",
				TableScript.TEXT_NOT_ENOUGH % [cultivation, required],
				realm, cultivation)

	if not TableScript.roll_success(rng_instance(),
			TableScript.success_rate_for(realm)):
		return _settle_failure(store, realm, cultivation, max_cult)

	var spent: int = required
	var after: int = _write_cultivation(store, cultivation - spent)
	var upgrade_error: String = _raise_realm(store, realm)
	if not upgrade_error.is_empty():
		# 境界写入通道不可用——把修为退回，不留「扣了修为没升境界」的半成品
		_write_cultivation(store, cultivation)
		return reject("upgrade_failed", upgrade_error, realm, cultivation)

	return {
		"success": true,
		"reason": "",
		"message": TableScript.TEXT_SUCCESS % [TableScript.realm_name(realm),
				TableScript.realm_name(realm + 1), spent],
		"rolled": true,
		"realm_before": realm,
		"realm_after": realm + 1,
		"cultivation_before": cultivation,
		"cultivation_after": after,
		"spent": spent,
		"penalty": 0,
		"attributes": attributes_of(realm + 1),
		"cultivation_full": bool(store.get(&"player").get("cultivation_full", false)),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部（写入）
# ═══════════════════════════════════════════════════════════════════════════════

## 失败结算——按配置扣一部分修为，境界不变。[br]
## [br][b]基数取 [code]max_cultivation[/code][/b]（同渡劫口径）：以当前修为为基数
## 会让「压着修为不攒满」变成省钱策略，惩罚失去意义。
func _settle_failure(p_store: Node, p_realm: int, p_cultivation: int,
		p_max_cult: int) -> Dictionary:
	var penalty: int = TableScript.penalty_for(p_realm, p_max_cult)
	var after: int = _write_cultivation(p_store, p_cultivation - penalty)
	return {
		"success": false,
		"reason": "roll_failed",
		"message": TableScript.TEXT_FAILURE % [p_cultivation - after,
				p_cultivation, after],
		"rolled": true,
		"realm_before": p_realm,
		"realm_after": p_realm,
		"cultivation_before": p_cultivation,
		"cultivation_after": after,
		"spent": 0,
		"penalty": penalty,
		"attributes": attributes_of(p_realm),
		"cultivation_full": bool(p_store.get(&"player").get("cultivation_full", false)),
	}


## 写修为（经 GSM [code]_buffer_change[/code] 传播 Cat 1）——[b]永不落负[/b]。[br]
## [br][param p_value] 目标值（负数归零）。[br]
## [br][b]返回[/b]：实际写入值。[br]
## [br][b]为什么不用第二层方法[/b]：GSM 既有的修为写入口
## （[code]add_cultivation[/code] / [code]restore_action_points[/code]）全是[b]只增不减[/b]
## ——扣修为的既有先例是渡劫结算的直接写 + [code]_buffer_change[/code]
## （[code]tribulation_settlement.gd[/code] §handle_failure），本模块沿用同一口径，
## 不新开第二层 API（避免与 GSM 的原子写面重叠）。
func _write_cultivation(p_store: Node, p_value: int) -> int:
	var player: Dictionary = p_store.get(&"player")
	var old_value: int = int(player.get("cultivation", 0))
	var new_value: int = maxi(p_value, 0)
	if new_value != old_value:
		player["cultivation"] = new_value
		p_store.call(&"_buffer_change", "player.cultivation", old_value, new_value)
	return new_value


## 升境界——走既有编排器（[code]realm_up[/code] → GSM [code]change_realm[/code] →
## [code]realm_changed[/code] → 下游按其订阅重算）。[br]
## [br][b]返回[/b]：空串 = 成功；非空 = 中文失败原因（调用方据此退回修为）。
func _raise_realm(p_store: Node, p_realm: int) -> String:
	var rs: Node = _realm_system()
	if rs == null or not rs.has_method(&"realm_up"):
		push_warning("ExplorationBreakthrough: RealmSystem 不可用，境界未提升")
		return "境界系统不可用，突破未生效"
	rs.call(&"realm_up", p_realm)
	if int(p_store.get(&"player").get("realm", 0)) == p_realm:
		push_warning("ExplorationBreakthrough: realm_up 未改变境界（realm=%d）" % p_realm)
		return "境界提升被拒绝，突破未生效"
	# 修为上限的重算由 CultivationSystem 订阅 realm_changed 完成（GDD §6）——
	# 不在这里再算一遍（同一条链上重算两次必然漂移）。
	if _cultivation_system() == null:
		push_warning("ExplorationBreakthrough: CultivationSystem 不可用，修为上限未重算")
	return ""
