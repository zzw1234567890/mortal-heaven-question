extends RefCounted
## GameStateManager.GSMAtomicWrites —— 第二层原子写入方法（提取自 game_state_manager.gd）。
##
## 持有对 GSM 父节点的引用，提供全部第二层原子写入方法——修为、资源、战斗、
## 身份、境界、轮回、卡牌收藏、输入锁、场景、剧情 flag、行动力、天赋、章节。
## 每个方法写入数据后通过 [method GameStateManager._buffer_change] 进入帧末信号缓冲管线。
##
## [b]提取原因[/b]：game_state_manager.gd 1080 行 → 拆分（Story 3-9 技术债，Sprint 1 回顾行动项 #2）。
##
## 来源: ADR-0001 §第二层原子写入 + 各系统 ADR 的 GSM 集成合约。

## 指向 GSM 父节点的引用。
var _gsm: Node = null


## 绑定 GSM 父节点引用。
func init(gsm: Node) -> void:
	_gsm = gsm


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


## 原子写入战斗费用——仅 CostSystem 调用（从 CombatSystem 委托写入权）。[br]
## [br][b]窄范围[/b]：仅写入 battle.current_cost / battle.max_cost——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0015 §GSM 第二层扩展。
func _set_battle_cost(current_cost: int, max_cost: int) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_cost: 无活跃战斗，拒绝写入")
		return

	var old_current: int = _gsm.battle.get("current_cost", 0)
	var old_max: int = _gsm.battle.get("max_cost", 0)

	if old_current == current_cost and old_max == max_cost:
		return  # 值无变化——去重

	_gsm.battle.current_cost = current_cost
	_gsm.battle.max_cost = max_cost

	_gsm._buffer_change("battle.current_cost", old_current, current_cost)
	_gsm._buffer_change("battle.max_cost", old_max, max_cost)


## 原子写入战斗状态快照——仅 StatusEffectSystem 调用（战斗结束导出）。[br]
## [br][b]窄范围[/b]：仅写入 battle.status_snapshot——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播（展平路径 [code]"battle.status_snapshot"[/code]）。[br]
## [br]来源: ADR-0011 §snapshot 导出 §GSM 例外模式。
func _set_battle_status_snapshot(snapshot: Array) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_status_snapshot: 无活跃战斗，拒绝写入")
		return

	var old_snapshot: Array = _gsm.battle.get("status_snapshot", [])
	if _gsm._deep_equal(old_snapshot, snapshot):
		return  # 值无变化——去重

	_gsm.battle.status_snapshot = snapshot
	_gsm._buffer_change("battle.status_snapshot", old_snapshot, snapshot)


## 原子写入战斗阵位快照——仅 DeploymentSystem 调用（战斗结束导出）。[br]
## [br][b]窄范围[/b]：仅写入 battle.deployment_snapshot——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播（展平路径 [code]"battle.deployment_snapshot"[/code]）。[br]
## [br]来源: ADR-0016 §GSM 边界 §snapshot 导出。
func _set_battle_deployment_snapshot(snapshot: Dictionary) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_deployment_snapshot: 无活跃战斗，拒绝写入")
		return

	var old_snapshot: Dictionary = _gsm.battle.get("deployment_snapshot", {})
	if _gsm._deep_equal(old_snapshot, snapshot):
		return  # 值无变化——去重

	_gsm.battle.deployment_snapshot = snapshot
	_gsm._buffer_change("battle.deployment_snapshot", old_snapshot, snapshot)


## 原子写入不可用角色列表——仅 DeploymentSystem 调用（战斗结束存档持久化入口）。[br]
## [br][b]窄范围[/b]：仅写入 player.unavailable_characters——不操作 player 域其他字段。[br]
## [br][b]去重[/b]：同值（深层相等）不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播（展平路径 [code]"player.unavailable_characters"[/code]）。[br]
## [br]来源: ADR-0016 §不可用角色生命周期 §跨战斗持久。
func _set_player_unavailable_characters(data: Dictionary) -> void:
	var old: Dictionary = _gsm.player.get("unavailable_characters", {})
	if _gsm._deep_equal(old, data):
		return  # 值无变化——去重

	_gsm.player.unavailable_characters = data
	_gsm._buffer_change("player.unavailable_characters", old, data)


## 原子写入战斗绑定快照——仅 BindingManager 调用（战斗结束导出）。[br]
## [br][b]窄范围[/b]：仅写入 battle.bindings——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播（展平路径 [code]"battle.bindings"[/code]）。[br]
## [br]来源: ADR-0013 §GSM 边界 §serialize_all。
func _set_battle_bindings(snapshot: Array) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_bindings: 无活跃战斗，拒绝写入")
		return

	# 首次写入——battle 中尚无 bindings 键，跳过去重确保键被创建
	if not _gsm.battle.has("bindings"):
		_gsm.battle.bindings = snapshot
		_gsm._buffer_change("battle.bindings", [], snapshot)
		return

	var old: Array = _gsm.battle.get("bindings", [])
	if _gsm._deep_equal(old, snapshot):
		return  # 值无变化——去重

	_gsm.battle.bindings = snapshot
	_gsm._buffer_change("battle.bindings", old, snapshot)


## 原子写入战斗阵法快照——仅 FormationSystem 调用（战斗结束导出）。[br]
## [br][b]窄范围[/b]：仅写入 battle.formation_snapshot——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入。[br]
## [br][b]首次写入[/b]：battle 无 formation_snapshot 键时跳过去重直接创建。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0024 §GSM 边界 §serialize_all。
func _set_battle_formation_snapshot(snapshot: Dictionary) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_formation_snapshot: 无活跃战斗，拒绝写入")
		return

	if not _gsm.battle.has("formation_snapshot"):
		_gsm.battle.formation_snapshot = snapshot
		_gsm._buffer_change("battle.formation_snapshot", {}, snapshot)
		return

	var old: Dictionary = _gsm.battle.get("formation_snapshot", {})
	if _gsm._deep_equal(old, snapshot):
		return  # 值无变化——去重

	_gsm.battle.formation_snapshot = snapshot
	_gsm._buffer_change("battle.formation_snapshot", old, snapshot)


## 原子写入战斗阶段——仅 CombatSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 battle.phase——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0008 §GSM battle.* 域写入所有权例外。
func _set_battle_phase(phase: int) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_phase: 无活跃战斗，拒绝写入")
		return

	var old_phase: int = int(_gsm.battle.get("phase", 0))
	if old_phase == phase:
		return  # 值无变化——去重

	_gsm.battle.phase = phase
	_gsm._buffer_change("battle.phase", old_phase, phase)


## 原子递增战斗回合数——仅 CombatSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 battle.turn——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0008 §GSM battle.* 域写入所有权例外。
func _increment_battle_turn() -> void:
	if _gsm.battle == null:
		push_warning("GSM._increment_battle_turn: 无活跃战斗，拒绝写入")
		return

	var old_turn: int = int(_gsm.battle.get("turn", 1))
	_gsm.battle.turn = old_turn + 1
	_gsm._buffer_change("battle.turn", old_turn, old_turn + 1)


## 原子写入战斗活跃标志——仅 CombatSystem 调用。[br]
## [br][b]active=true 时创建 battle 域[/b]：若 battle == null，初始化默认 battle 字典[br]
## （phase=PREPARATION, turn=1, is_active=true, player_field=[], enemy_field=[]）。[br]
## [br][b]active=false 时清理 battle 域[/b]：ADR-0008 §GSM 边界要求 _set_battle_active(false)[br]
## 同时清理 battle.* 域（设为 null）——battle_end() 调用本方法即完成全部清理。[br]
## [br][b]去重[/b]：同值不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0008 §GSM battle.* 域写入所有权例外。
func _set_battle_active(active: bool) -> void:
	if active:
		# active=true：如果 battle 域不存在，初始化默认值
		if _gsm.battle == null:
			_gsm.battle = {
				"is_active": true,
				"phase": 0,  # CombatPhase.PREPARATION
				"turn": 1,
				"current_cost": 0,
				"max_cost": 0,
				"player_field": [],
				"enemy_field": [],
				"result": null,
			}
			_gsm._buffer_change("battle", null, _gsm.battle)
			return
		# battle 域已存在——仅更新 is_active
		var old_active: bool = bool(_gsm.battle.get("is_active", false))
		if old_active == active:
			return  # 值无变化——去重
		_gsm.battle.is_active = active
		_gsm._buffer_change("battle.is_active", old_active, active)
	else:
		# active=false：清理 battle 域（设为 null）——ADR-0008 §GSM 边界
		if _gsm.battle == null:
			push_warning("GSM._set_battle_active: 无活跃战斗，拒绝写入")
			return
		var old_battle: Dictionary = _gsm.battle
		_gsm.battle = null
		_gsm._buffer_change("battle", old_battle, null)


## 战斗开始——仅 CombatSystem 调用。Cat 2a 生命周期信号，立即发射不缓冲。
func battle_start(config: Dictionary) -> void:
	if _gsm.battle != null:
		push_warning("GSM.battle_start: 已有活跃战斗，拒绝重复调用")
		return

	_gsm.battle = {
		"config": config.duplicate(true),
		"player_snapshot": _gsm.player.duplicate(true),
		"collection_snapshot": _gsm.collection.duplicate(true),
		"snapshot_realm": _gsm.player.realm,
	}

	_gsm.battle_started.emit(config.duplicate(true))


## 战斗结束——仅 CombatSystem 调用。Cat 2a 生命周期信号，立即发射不缓冲。
func battle_end(result: Dictionary) -> void:
	if _gsm.battle == null:
		push_warning("GSM.battle_end: 没有活跃战斗，拒绝调用")
		return

	_gsm.battle = null
	_gsm.battle_ended.emit(result.duplicate(true))


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


## 分配全局唯一的卡牌实例 ID——单调递增。[br]
## [br]由 CardSystem.create_instance() 调用，确保每张卡牌实例拥有全局唯一 ID。[br]
## [br][b]返回[/b]: 下一个未使用的卡牌实例 ID（从 1 开始，0 保留为"未分配"哨兵）。[br]
## [br][b]示例[/b]: [code]var inst_id: int = GameStateManager.allocate_card_id()[/code][br]
## [br]来源: ADR-0006 §GSM 集成合约——GSM 是卡牌实例 ID 的全局唯一分配者。
func allocate_card_id() -> int:
	var allocated: int = _gsm._next_card_instance_id
	_gsm._next_card_instance_id += 1
	return allocated


## 添加卡牌到收藏——仅 CardSystem 调用。[br]
## [br][b]校验跳过模式[/b]：若 [member GameStateManager.validation_enabled] 为 false，拒绝写入并返回 false。[br]
## [br][b]校验开启后[/b]：检查 [param inst_dict] 的 [code]template_id[/code] 是否存在于模板数据库中。
func add_card_to_collection(inst_dict: Dictionary) -> bool:
	if not _gsm.validation_enabled:
		push_warning("GSM.add_card_to_collection: 校验未开启——请先调用 GSM.enable_validation()（由 CardSystem._ready() 执行）")
		return false

	var template_id: String = inst_dict.get("template_id", "")
	if not _validate_card_ref(template_id):
		push_error("GSM.add_card_to_collection: 无效 template_id '%s'" % template_id)
		return false

	var old_cards: Array = _gsm.collection.owned_cards
	var old_count: int = _gsm.collection.total_count

	_gsm.collection.owned_cards.append(inst_dict.duplicate(true))
	_gsm.collection.total_count += 1

	_gsm._buffer_change("collection.owned_cards", old_cards.duplicate(), _gsm.collection.owned_cards)
	_gsm._buffer_change("collection.total_count", old_count, _gsm.collection.total_count)

	var card_id: int = inst_dict.get("card_instance_id", inst_dict.get("instance_id", 0))
	_gsm.card_collection_changed.emit(card_id, &"added")
	return true


## 激活卡牌校验——仅 CardSystem 在一次性的 [method Node._ready] 中调用。[br]
## [br][param card_template_database] 为模板 ID → 模板数据的映射字典。[br]
## [br]重复调用会触发 [method @GDScript.push_warning] 但不覆盖已有数据库。
func enable_validation(card_template_database: Dictionary) -> void:
	if _gsm.validation_enabled:
		push_warning("GSM.enable_validation: 校验已开启——忽略重复调用")
		return

	if card_template_database.is_empty():
		push_error("GSM.enable_validation: 模板数据库为空——校验未开启")
		return

	_gsm._card_template_database = card_template_database
	_gsm.validation_enabled = true
	_gsm.card_validation_ready.emit()

	# 回溯校验：修复校验跳过期间可能已写入的卡牌数据
	_retroactive_validate_collection()


## 校验卡牌模板 ID 是否存在于模板数据库中。
func _validate_card_ref(template_id: String) -> bool:
	if template_id.is_empty():
		return false
	return template_id in _gsm._card_template_database


## 回溯校验——清洗在 enable_validation() 调用前可能被污染的 collection 数据。
func _retroactive_validate_collection() -> void:
	var cards: Array = _gsm.collection.owned_cards
	var removed: int = 0
	var i: int = cards.size() - 1
	while i >= 0:
		var inst: Dictionary = cards[i]
		var tid: String = inst.get("template_id", "")
		if not _validate_card_ref(tid):
			push_warning("GSM._retroactive_validate_collection: 移除无效卡牌实例（template_id='%s'）" % tid)
			cards.remove_at(i)
			removed += 1
		i -= 1
	if removed > 0:
		_gsm.collection.total_count = cards.size()
		push_warning("GSM._retroactive_validate_collection: 共移除 %d 个无效卡牌实例" % removed)


## 设置输入锁栈——仅 [b]InputManager[/b] 调用。[br]
## [br]写入 [code]session.input_locks[/code] 并通过 [signal GameStateManager.batch_updated] 传播变更。[br]
## [br][param locks] [code]Array[Dictionary][/code]——每个元素 [code]{type: int, source: StringName, device_mask: int}[/code]。
func set_input_locks(locks: Array[Dictionary]) -> void:
	var old: Array = _gsm.session.input_locks.duplicate(true)
	_gsm.session.input_locks = locks.duplicate(true)
	_gsm._buffer_change("session.input_locks", old, _gsm.session.input_locks)


## 设置当前场景——仅 [b]SceneManager[/b] 调用（ADR-0005 独占写入授权）。[br]
## [br]写入 [code]session.scene_id[/code] 和 [code]session.current_scene[/code]，
## 通过 [signal GameStateManager.batch_updated] 传播 [signal GameStateManager.scene_changed]。
func set_session_scene(id: int, path: String) -> void:
	var old_id: int = _gsm.session.get("scene_id", 0)
	var old_path: String = _gsm.session.get("current_scene", "")
	_gsm.session.scene_id = id
	_gsm.session.current_scene = path
	_gsm._buffer_change("session.scene_id", old_id, id)
	_gsm._buffer_change("session.current_scene", old_path, path)


## story_flags 写入——仅 [b]EventSystem.set_flag()[/b] 调用（ADR-0003 唯一写入者契约）。[br]
## [br][b]委托链[/b]: EventSystem.set_flag() → 此方法 → [method GameStateManager._buffer_change] → 帧末 [signal GameStateManager.batch_updated]。[br]
## [br]相同值重复写入不缓冲变更（去重），减少 SaveLoad 误触发自动存档。[br]
## [br][param flag] flag 键名；[param value] flag 值（Variant——仅接口处使用，不在 Resource @export 中使用）。[br]
## [br][b]示例[/b]: [code]GameStateManager.set_narrative_flag(&"chapter_1", true)[/code]
func set_narrative_flag(flag: StringName, value: Variant) -> void:
	var old: Variant = _gsm.narrative.story_flags.get(flag, null)
	if old == value:
		return
	_gsm.narrative.story_flags[flag] = value
	_gsm._buffer_change("narrative.story_flags.%s" % flag, old, value)


## 移除卡牌实例——按 card_instance_id 查找并从 collection.owned_cards 移除。[br]
## [br][b]校验跳过模式[/b]：若 [member GameStateManager.validation_enabled] 为 false，拒绝写入并返回 false。[br]
## [br]兼容 [code]card_instance_id[/code]（ADR-0006 权威字段）与 [code]instance_id[/code] 两种字段命名。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功移除，[code]false[/code] 未找到或校验未开启。[br]
## [br][b]示例[/b]: [code]var ok := GameStateManager.remove_card_from_collection(42)[/code]
func remove_card_from_collection(card_instance_id: int) -> bool:
	if not _gsm.validation_enabled:
		push_warning("GSM.remove_card_from_collection: 校验未开启——请先调用 GSM.enable_validation()")
		return false

	var cards: Array = _gsm.collection.owned_cards
	var idx_to_remove: int = -1
	for i: int in range(cards.size()):
		var inst: Dictionary = cards[i]
		# 兼容 card_instance_id（ADR-0006 权威）与 instance_id 两种字段命名
		var stored_id: Variant = inst.get("card_instance_id", inst.get("instance_id", -1))
		if stored_id == card_instance_id:
			idx_to_remove = i
			break

	if idx_to_remove == -1:
		push_warning("GSM.remove_card_from_collection: 未找到 card_instance_id=%d" % card_instance_id)
		return false

	var old_cards: Array = _gsm.collection.owned_cards.duplicate()
	var old_count: int = _gsm.collection.total_count

	cards.remove_at(idx_to_remove)
	_gsm.collection.total_count = cards.size()

	_gsm._buffer_change("collection.owned_cards", old_cards, _gsm.collection.owned_cards)
	_gsm._buffer_change("collection.total_count", old_count, _gsm.collection.total_count)

	_gsm.card_collection_changed.emit(card_instance_id, &"removed")
	return true


## 恢复行动力——写入 exploration.action_points。[br]
## [br]行动力属探索系统（ADR-0014），AP 上限由 ExplorationSystem 管理——本方法不 clamp。[br]
## [br][param amount] 恢复量（必须为正值）。[br]
## [br][b]示例[/b]: [code]GameStateManager.restore_action_points(2)[/code]
func restore_action_points(amount: int) -> void:
	if amount <= 0:
		push_error("GSM.restore_action_points: amount 必须为正值（收到: %d）" % amount)
		return

	var old_val: int = _gsm.exploration.action_points
	_gsm.exploration.action_points = old_val + amount
	_gsm._buffer_change("exploration.action_points", old_val, _gsm.exploration.action_points)


# === 探索导航状态（ADR-0014 §GSM 写入契约）===================================

## 设置当前地图——写入 exploration.current_map 并重置 node_position 为入口。[br]
## [br][b]仅 ExplorationSystem.enter_map() 调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br][param map_id] 地图 ID。[br]
## [br][b]batch_updated[/b]：current_map + node_position 两条路径变更帧末传播。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func set_exploration_map(map_id: StringName) -> void:
	var old_map: StringName = _gsm.exploration.get("current_map", &"")
	var old_pos: Dictionary = _gsm.exploration.get("node_position", {}).duplicate(true)
	var new_pos: Dictionary = {"layer": 0, "idx": 0}

	_gsm.exploration.current_map = map_id
	_gsm.exploration.node_position = new_pos.duplicate(true)

	_gsm._buffer_change("exploration.current_map", old_map, map_id)
	_gsm._buffer_change("exploration.node_position", old_pos, new_pos)


## 更新节点位置——写入 exploration.node_position。[br]
## [br][b]仅 ExplorationSystem.move_to_node() 调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br][param layer] 层级。[br]
## [br][param idx] 层内索引。[br]
## [br][b]batch_updated[/b]：node_position 路径变更帧末传播。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func set_exploration_position(layer: int, idx: int) -> void:
	var old_pos: Dictionary = _gsm.exploration.get("node_position", {}).duplicate(true)
	var new_pos: Dictionary = {"layer": layer, "idx": idx}

	_gsm.exploration.node_position = new_pos.duplicate(true)
	_gsm._buffer_change("exploration.node_position", old_pos, new_pos)


## 追加已访问节点——写入 exploration.visited_nodes（去重）。[br]
## [br][b]仅 ExplorationSystem.move_to_node() 调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br][param node_id] 节点 ID。[br]
## [br][b]去重[/b]：已存在不追加，不触发 buffer_change。[br]
## [br][b]batch_updated[/b]：visited_nodes 路径变更帧末传播。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func add_visited_node(node_id: int) -> void:
	var visited: Array = _gsm.exploration.get("visited_nodes", [])
	if visited.has(node_id):
		return  # 去重
	var old_visited: Array = visited.duplicate()
	visited.append(node_id)
	_gsm._buffer_change("exploration.visited_nodes", old_visited, visited)


## 设置行动力——同时写入 exploration.action_points + max_action_points。[br]
## [br][b]仅 ExplorationSystem.enter_map() / 恢复节点调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br][param current] 当前行动力。[br]
## [br][param max_ap] 行动力上限。[br]
## [br][b]batch_updated[/b]：action_points + max_action_points 两条路径变更帧末传播。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func set_exploration_ap(current: int, max_ap: int) -> void:
	var old_current: int = int(_gsm.exploration.get("action_points", 0))
	var old_max: int = int(_gsm.exploration.get("max_action_points", 0))

	_gsm.exploration.action_points = current
	_gsm.exploration.max_action_points = max_ap

	_gsm._buffer_change("exploration.action_points", old_current, current)
	_gsm._buffer_change("exploration.max_action_points", old_max, max_ap)


## 合并写入地图状态——更新 exploration.map_states[map_id] 子字段。[br]
## [br][b]仅 ExplorationSystem 调用[/b]——用于 entry_count、collected_* 等跨地图累计数据。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param changes] 要合并的子字段 Dictionary。[br]
## [br][b]batch_updated[/b]：map_states.<map_id> 路径变更帧末传播。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func update_exploration_map_state(map_id: StringName, changes: Dictionary) -> void:
	var map_states: Dictionary = _gsm.exploration.get("map_states", {})
	var key_str: String = str(map_id)
	var old_state: Dictionary = (map_states.get(map_id, {}) as Dictionary).duplicate(true)

	if not map_states.has(map_id):
		map_states[map_id] = {}
	var target: Dictionary = map_states[map_id]
	for k in changes:
		target[k] = changes[k]

	var new_state: Dictionary = target.duplicate(true)
	_gsm._buffer_change("exploration.map_states.%s" % key_str, old_state, new_state)


## 清除导航状态——重置 current_map/node_position/visited_nodes，保留 map_states。[br]
## [br][b]仅 ExplorationSystem.end_exploration() 调用[/b]——ADR-0014 §决策 5 探索结束结算。[br]
## [br]导航字段重置为默认值（current_map=&"", node_position={layer:0,idx:0}, visited_nodes=[]），[br]
## map_states（跨地图累计数据——entry_count、collected_*、is_first_clear）保留。[br]
## [br][b]batch_updated[/b]：3 条路径变更帧末传播。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func clear_exploration_navigation() -> void:
	var old_map: StringName = _gsm.exploration.get("current_map", &"")
	var old_pos: Dictionary = _gsm.exploration.get("node_position", {}).duplicate(true)
	var old_visited: Array = (_gsm.exploration.get("visited_nodes", []) as Array).duplicate()

	_gsm.exploration.current_map = &""
	_gsm.exploration.node_position = {"layer": 0, "idx": 0}
	_gsm.exploration.visited_nodes = []

	_gsm._buffer_change("exploration.current_map", old_map, &"")
	_gsm._buffer_change("exploration.node_position", old_pos, {"layer": 0, "idx": 0})
	_gsm._buffer_change("exploration.visited_nodes", old_visited, [])


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


## 推进章节——写入 narrative.current_chapter + completed_chapters。[br]
## [br]若 [code]narrative.current_chapter[/code] 非空且与新章节不同，将旧章节 append 到 [code]completed_chapters[/code]。[br]
## [br][param chapter_id] 新章节 ID。[br]
## [br][b]示例[/b]: [code]GameStateManager.advance_chapter(&"chapter_2")[/code]
func advance_chapter(chapter_id: StringName) -> void:
	var chapter_str: String = str(chapter_id)
	if chapter_str.is_empty():
		push_warning("GSM.advance_chapter: chapter_id 为空，拒绝写入")
		return

	var old_current: String = _gsm.narrative.current_chapter
	if old_current == chapter_str:
		return  # 相同章节——去重

	var old_completed: Array = _gsm.narrative.completed_chapters.duplicate()
	if not old_current.is_empty():
		_gsm.narrative.completed_chapters.append(old_current)

	_gsm.narrative.current_chapter = chapter_str
	_gsm._buffer_change("narrative.current_chapter", old_current, chapter_str)
	_gsm._buffer_change("narrative.completed_chapters", old_completed, _gsm.narrative.completed_chapters)


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
