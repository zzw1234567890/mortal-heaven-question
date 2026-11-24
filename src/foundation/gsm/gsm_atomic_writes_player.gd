## GSMAtomicWrites 玩家域写入层（继承链第 2 段）——[b]修为 / 资源 / 身份 / 境界 / 轮回 / 天赋 / 渡劫[/b]。
##
## [b]本层职责[/b]：全部落在 [code]player.*[/code] 域的第二层原子写入。[br]
##   · 修为与资源——[method add_cultivation]（超上限的部分进溢出池）、
##     [method _set_resource_ling_shi] / [method _set_resource_ling_cai]（非负守卫）；[br]
##   · 身份与境界——[method set_identity]（经 [method GameStateManager._set_by_path]
##     写嵌套路径）、[method change_realm]；[br]
##   · 轮回结算——[method reincarnation_reset]（修为 / 溢出池 / 满溢标记 / 境界 /
##     三种资源 / 修为上限整段归零）；[br]
##   · 天赋两制——[method unlock_talent]（[code]talents[/code] 数组，去重 append）与
##     [method set_talent]（[code]talent_map[/code] 键值注册表，ADR-0022）；[br]
##   · 渡劫——[method _set_tribulation_state] /
##     [method _set_consecutive_tribulation_failures]（跨会话保留，ADR-0021）。
##
## [b]为什么这些住同一层[/b]：写入对象全是 [code]player[/code] 域，且都经
## [method GameStateManager._buffer_change] 进帧末信号管线——散到多个文件里，
## 改「玩家域写入口径」时要满链找。
##
## [b]本层不持状态[/b]：[member _gsm] 与三个子域委托全在
## [code]gsm_atomic_writes_contract.gd[/code]，沿链可见。
##
## 来源: ADR-0001 §三层 API / ADR-0010 §GSM 集成合约 / ADR-0019 §第二层扩展方法 /
## ADR-0021 §GSM 新增域与方法 / ADR-0022 §GSM 第二层扩展方法。

extends "res://src/foundation/gsm/gsm_atomic_writes_contract.gd"


## 修为增加——仅 CultivationSystem 调用。
func add_cultivation(amount: int, source: String = "") -> void:
	if amount <= 0:
		push_error("GSM.add_cultivation: amount 必须为正值（收到: %d, 来源: '%s'）" % [amount, source])
		return

	var old_cultivation: int = _gsm.player.cultivation
	var old_full: bool = _gsm.player.cultivation_full
	var old_overflow: int = _gsm.player.overflow_pool

	var space: int = _gsm.player.max_cultivation - _gsm.player.cultivation

	if amount <= space:
		_gsm.player.cultivation += amount
		_gsm._buffer_change("player.cultivation", old_cultivation, _gsm.player.cultivation)
	else:
		_gsm.player.cultivation = _gsm.player.max_cultivation
		var excess: int = amount - space
		_gsm.player.overflow_pool += excess
		_gsm.player.cultivation_full = true
		_gsm._buffer_change("player.cultivation", old_cultivation, _gsm.player.cultivation)
		_gsm._buffer_change("player.cultivation_full", old_full, true)
		_gsm._buffer_change("player.overflow_pool", old_overflow, _gsm.player.overflow_pool)


## 原子写入灵石——仅 ResourceSystem 调用。[br]
## [br][param value] 新值。[br]
## [br][b]非负守卫[/b]：[code]maxi(0, value)[/code]——即便绕过 ResourceSystem 也防止负数。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0019 §GSM 第二层扩展方法。
func _set_resource_ling_shi(value: int) -> void:
	value = maxi(0, value)
	var old_val: int = _gsm.player.resources.ling_shi
	if old_val == value:
		return
	_gsm.player.resources.ling_shi = value
	_gsm._buffer_change("player.resources.ling_shi", old_val, value)


## 原子写入灵材指定品质——仅 ResourceSystem 调用。[br]
## [br][param quality] 品质（1=low, 2=medium, 3=high, 4=top）。[br]
## [br][param value] 新值。[br]
## [br][b]非负守卫[/b]：[code]maxi(0, value)[/code]——各品质同样防止负数。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0019 §GSM 第二层扩展方法。
func _set_resource_ling_cai(quality: int, value: int) -> void:
	if quality < 1 or quality > 4:
		push_error("GSM._set_resource_ling_cai: 无效品质 %d（有效 1-4）" % quality)
		return
	value = maxi(0, value)
	var key: String = ["low", "medium", "high", "top"][quality - 1]
	var old_val: int = _gsm.player.resources.ling_cai[key]
	if old_val == value:
		return
	_gsm.player.resources.ling_cai[key] = value
	_gsm._buffer_change("player.resources.ling_cai.%s" % key, old_val, value)


## 身份设置——仅 IdentitySelectionSystem 调用。
func set_identity(identity_id: StringName) -> void:
	var id_str: String = str(identity_id).strip_edges()
	if id_str.is_empty():
		push_warning("GSM.set_identity: identity_id 为空，拒绝写入")
		return

	var old_val: String = _gsm.player.identity_id
	if old_val == id_str:
		return  # 值无变化，去重

	_gsm._buffer_change("player.identity_id", old_val, id_str)
	if not _gsm._set_by_path("player.identity_id", id_str):
		push_error("GSM.set_identity: 写入失败")


## 原子写入境界等级——仅 RealmSystem.realm_up() 调用。[br]
## [br][param new_level] 新境界等级（1-5）。[br]
## [br][b]Cat 1 信号[/b]：写入后发射 [signal GameStateManager.realm_changed]，携带 old/new int 载荷。[br]
## [br][b]校验跳过模式[/b]：本方法不受 [member GameStateManager.validation_enabled] 影响——境界写入与卡牌校验独立。[br]
## [br]来源: ADR-0001 §三层 API + ADR-0010 §GSM 集成合约。
func change_realm(new_level: int) -> void:
	var old_realm: int = _gsm.player.realm
	if old_realm == new_level:
		return  # 值无变化，去重
	_gsm.player.realm = new_level
	_gsm._buffer_change("player.realm", old_realm, new_level)
	# realm_changed 由帧末 _emit_domain_signal 统一发射——与 reincarnation_reset/add_cultivation 等
	# 所有第二层方法一致，避免单帧重复发射（Cat 1 信号契约一致性）


## 死亡/轮回结算——仅 CombatSystem/StorySystem 调用。
func reincarnation_reset() -> void:
	# 修为归零
	var old_cult: int = _gsm.player.cultivation
	_gsm.player.cultivation = 0
	_gsm._buffer_change("player.cultivation", old_cult, 0)

	# 溢出池归零
	var old_overflow: int = _gsm.player.overflow_pool
	_gsm.player.overflow_pool = 0
	_gsm._buffer_change("player.overflow_pool", old_overflow, 0)

	# cultivation_full 重置
	var old_full: bool = _gsm.player.cultivation_full
	_gsm.player.cultivation_full = false
	_gsm._buffer_change("player.cultivation_full", old_full, false)

	# 境界重置
	var old_realm: int = _gsm.player.realm
	_gsm.player.realm = _gsm.RealmLevel.QI_REFINING
	_gsm._buffer_change("player.realm", old_realm, _gsm.RealmLevel.QI_REFINING)

	# 资源重置
	var resources: Dictionary = _gsm.player.resources
	# 灵石重置
	var old_ls: int = resources.ling_shi
	if old_ls != 0:
		resources.ling_shi = 0
		_gsm._buffer_change("player.resources.ling_shi", old_ls, 0)
	# 灵材四品质重置
	var lc: Dictionary = resources.ling_cai
	for q_key: String in ["low", "medium", "high", "top"]:
		var old_q: int = lc[q_key]
		if old_q != 0:
			lc[q_key] = 0
			_gsm._buffer_change("player.resources.ling_cai.%s" % q_key, old_q, 0)
	# 丹药碎片重置
	var old_dysp: int = resources.dan_yao_sui_pian
	if old_dysp != 0:
		resources.dan_yao_sui_pian = 0
		_gsm._buffer_change("player.resources.dan_yao_sui_pian", old_dysp, 0)

	# 重置 max_cultivation 为基准值
	var old_max: int = _gsm.player.max_cultivation
	_gsm.player.max_cultivation = _gsm.BASE_MAX
	_gsm._buffer_change("player.max_cultivation", old_max, _gsm.BASE_MAX)


## 解锁天赋——写入 player.talents（去重 append）。[br]
## [br][param talent_id] 天赋 ID。[br]
## [br][b]示例[/b]: [code]GameStateManager.unlock_talent(&"talent_003")[/code]
func unlock_talent(talent_id: StringName) -> void:
	var talents: Array = _gsm.player.talents
	if talents.has(talent_id):
		return  # 已拥有——去重

	var old_talents: Array = talents.duplicate()
	talents.append(talent_id)
	_gsm._buffer_change("player.talents", old_talents, talents)


## 写入身份天赋效果——键值映射制（ADR-0022 §天赋效果）。[br]
## [br][b]仅 IdentitySelectionSystem.apply_identity() 调用[/b]——注册身份专属天赋[br]
## 到 [code]player.talent_map[/code] 键值注册表。[br]
## [br]下游系统通过 [code]GSM.player.talent_map.get(talent_id, 0)[/code] 查询——O(1) 字典查找。[br]
## [br][param talent_id] 天赋 ID（如 [code]&"ling_shi_boost"[/code]）。[br]
## [br][param magnitude] 天赋强度值（如 15 表示 +15%）。[br]
## [br][b]覆盖语义[/b]: 同 ID 已存在则覆盖（最后一局的身份选择胜出）。[br]
## [br][b]Cat 1 信号[/b]: 写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0022 §GSM 第二层扩展方法 + GDD §公式#1 天赋效果注册。
func set_talent(talent_id: StringName, magnitude: int) -> void:
	var talent_map: Dictionary = _gsm.player.get("talent_map", {})
	var old_val: Variant = talent_map.get(talent_id, null)
	if old_val != null and int(old_val) == magnitude:
		return  # 值无变化——去重
	talent_map[talent_id] = magnitude
	if not _gsm.player.has("talent_map"):
		_gsm.player["talent_map"] = talent_map
	_gsm._buffer_change("player.talent_map.%s" % talent_id, old_val, magnitude)



## 原子写入渡劫状态——仅 TribulationSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 player.tribulation_state——不操作 player 域其他字段。[br]
## [br][b]null 守卫[/b]：player 为 null 时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0021 §GSM 新增域与方法。
func _set_tribulation_state(state: int) -> void:
	if _gsm.player == null:
		push_warning("GSM._set_tribulation_state: player 域为 null，拒绝写入")
		return

	var old_state: int = int(_gsm.player.get("tribulation_state", 0))
	if old_state == state:
		return  # 值无变化——去重

	_gsm.player.tribulation_state = state
	_gsm._buffer_change("player.tribulation_state", old_state, state)


## 原子写入连续渡劫失败计数——仅 TribulationSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 player.consecutive_tribulation_failures——不操作 player 域其他字段。[br]
## [br][b]持久化[/b]：此字段持久化到存档——连续失败保护跨会话保留（ADR-0021）。[br]
## [br][b]null 守卫[/b]：player 为 null 时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0021 §GSM 新增域与方法。
func _set_consecutive_tribulation_failures(count: int) -> void:
	if _gsm.player == null:
		push_warning("GSM._set_consecutive_tribulation_failures: player 域为 null，拒绝写入")
		return

	if count < 0:
		push_warning("GSM._set_consecutive_tribulation_failures: count 不能为负（收到 %d）" % count)
		return

	var old_count: int = int(_gsm.player.get("consecutive_tribulation_failures", 0))
	if old_count == count:
		return  # 值无变化——去重

	_gsm.player.consecutive_tribulation_failures = count
	_gsm._buffer_change("player.consecutive_tribulation_failures", old_count, count)
