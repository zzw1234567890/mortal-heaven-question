## DeploymentSystem 战斗操作层（继承链第 5 段）——[b]构造 / 备战 / 待命机 / 补位 / 目标查询[/b]。
##
## [b]本层职责[/b]：一场战斗里阵位的全部变更入口。[br]
##   · [method _init]——初始化 6 个空位（[code]DS_SCRIPT.new()[/code] 无需入树即已初始化）；[br]
##   · [method setup_field]——备战阶段校验（非空 / 人数上限 / 可用性）后自动或手动分配 + 全部 STANDBY；[br]
##   · 待命状态机（[method is_standby] / [method set_acted] / [method clear_standby_state]）——
##     由 CombatSystem 在回合编排中驱动；[br]
##   · 战中补位 [method deploy] 与阵亡清位 [method remove_character]；[br]
##   · 前后排保护查询 [method is_targetable]——AI 目标选择每帧调用。[br]
##
## [b]为什么本层排在数据层之后[/b]：[method setup_field] 调 [method _query_max_deploy] /
## [method _reset_field] / [method _assign_slots]，[method deploy] 调
## [method get_empty_slots] / [method _is_front]——解析期要求这些口在本段或祖先段（探针实测）。[br]
##
## 来源: ADR-0016 §备战阶段流程 §待命状态清除 §战中补位流程 §前后排保护查询、
## GDD deployment-system.md §2 §5。

extends "res://src/feature/deployment/deployment_system_field_queries.gd"

# === 构造 =========================================================================

## 初始化 6 个阵位为空位（前排 is_front=true）。[br]
## 覆盖 Node._init——测试 [code]DS_SCRIPT.new()[/code] 无需加入场景树即可获得已初始化阵位。
func _init() -> void:
	_reset_field()

# === 备战阶段 =====================================================================

## 备战阶段初始化阵位（自动/手动分配 + 全部 STANDBY）。[br]
## [br][b]验证顺序[/b]（ADR-0016 §备战阶段流程）：[br]
##   1. 查询 [code]max_deploy[/code]（[method RealmSystem.get_current_property]）[br]
##   2. 非空校验（至少 1 人）[br]
##   3. 人数 ≤ max_deploy 校验[br]
##   4. 所有角色「可用」校验（对 [member _unavailable_characters] 判空）[br]
##   5. 自动/手动分配阵位（前排优先）[br]
##   6. 全部标记 STANDBY + 重置 [member _front_line_breached_emitted][br]
## [br][b]失败语义[/b]：校验失败返回 false 且不修改现有阵位。[br]
## [br][param character_ids] 上场角色 ID 列表。[br]
## [br][param layout] 手动前后排分配 [code]{char_id: is_front}[/code]——未指定的角色自动前排优先。[br]
## [br][b]返回[/b]: true = 成功；false = 空选择 / 人数超上限 / 角色不可用。
func setup_field(character_ids: Array, layout: Dictionary = {}) -> bool:
	var max_deploy: int = _query_max_deploy()
	if character_ids.is_empty():
		return false  # AC-005：至少选择 1 个角色上场
	if character_ids.size() > max_deploy:
		return false  # AC-007：人数超上限
	for cid in character_ids:
		if _unavailable_characters.has(cid):
			return false  # 角色不可用（Story 004 填充列表）

	# 校验通过后才重置阵位——失败不污染现有状态
	_reset_field()
	_front_line_breached_emitted = false

	var assignment: Dictionary = _assign_slots(character_ids, layout)
	for cid in character_ids:
		var slot: int = assignment[cid]
		_field[slot] = {
			"character_id": cid,
			"is_front": _is_front(slot),
			"deploy_turn": 0,
			"state": FieldState.STANDBY,
		}
	return true

# === 待命状态机 ===================================================================

## 查询角色是否处于待命状态（O(1) 阵位查找）。[br]
## [br][param character_id] 角色 ID。[br]
## [br][b]返回[/b]: STANDBY 角色 true；READY/ACTED/DEAD/未上场角色 false。
func is_standby(character_id: int) -> bool:
	var slot: int = get_character_slot(character_id)
	if slot == -1:
		return false
	return _field[slot]["state"] == FieldState.STANDBY


## 将 READY 角色标记为 ACTED（攻击后由 CombatSystem 调用）。[br]
## [br]非 READY 角色（STANDBY/ACTED/DEAD/EMPTY/未上场）状态不变。[br]
## [br][param character_id] 角色 ID。
func set_acted(character_id: int) -> void:
	var slot: int = get_character_slot(character_id)
	if slot == -1:
		return
	if _field[slot]["state"] == FieldState.READY:
		_field[slot]["state"] = FieldState.ACTED


## 回合结束时清除待命状态——由 CombatSystem 在 Phase 6 END 调用。[br]
## [br][b]状态转换[/b]（ADR-0016 §待命状态清除）：[br]
##   - STANDBY → READY（加入 cleared_ids，待命清除）[br]
##   - ACTED → READY（已行动恢复，回合循环——不计入 cleared_ids）[br]
##   - READY / DEAD 不变；空位（character_id==-1）跳过[br]
## [br][b]信号[/b]：有 STANDBY→READY 转换时发射 [signal standby_cleared]，载荷仅含待命清除角色。
func clear_standby_state() -> void:
	var cleared_ids: Array = []
	for slot in range(SLOT_COUNT):
		var entry: Dictionary = _field[slot]
		if entry["character_id"] == -1:
			continue  # 空位跳过
		match entry["state"]:
			FieldState.STANDBY:
				entry["state"] = FieldState.READY
				cleared_ids.append(entry["character_id"])
			FieldState.ACTED:
				entry["state"] = FieldState.READY  # ACTED→READY 不加入 cleared_ids
			_:  # READY / DEAD 不变
				pass
	if not cleared_ids.is_empty():
		_emit_standby_cleared(cleared_ids)

# === 战中补位 / 阵亡清位 ============================================================

## 战中补位——检查空位→分配阵位→标记 STANDBY→发射 [signal character_deployed]。[br]
## [br][b]前置检查顺序[/b]（ADR-0016 §战中补位流程）：[br]
##   1. 角色不可用检查（[member _unavailable_characters]）[br]
##   2. 已在场上检查（防重复部署）[br]
##   3. 境界上场上限检查（[code]deployed >= max_deploy[/code] → field_full）[br]
##   4. 物理空位检查（[method get_empty_slots]）[br]
##   5. 槽位合法性检查（越界/已占用）[br]
## [br][param card_instance_id] 卡牌实例 ID（本 Story 仅透传，供后续 BindingManager 恢复绑定）。[br]
## [br][param character_id] 上场角色 ID。[br]
## [br][param slot_index] 目标阵位——-1 = 自动分配前排优先空位。[br]
## [br][b]返回[/b]: [code]{success: bool, slot_index: int, reason: String}[/code]——
## reason ∈ 'deployed' / 'field_full' / 'character_unavailable' / 'invalid_slot'。
func deploy(card_instance_id: int, character_id: int, slot_index: int = -1) -> Dictionary:
	if _unavailable_characters.has(character_id):
		return {"success": false, "slot_index": -1, "reason": "character_unavailable"}
	if get_character_slot(character_id) != -1:
		return {"success": false, "slot_index": -1, "reason": "invalid_slot"}  # 已在场上

	# 境界上场上限检查（max_deploy）——field_full 同时涵盖「境界上限满」与「物理满」
	var deployed: int = SLOT_COUNT - get_empty_slots().size()
	if deployed >= _query_max_deploy():
		return {"success": false, "slot_index": -1, "reason": "field_full"}

	var target_slot: int = slot_index
	if slot_index == -1:
		# 自动分配——前排优先第一个空位
		var empty: Array = get_empty_slots()
		if empty.is_empty():
			return {"success": false, "slot_index": -1, "reason": "field_full"}
		target_slot = empty[0]
	else:
		if slot_index < 0 or slot_index >= SLOT_COUNT:
			return {"success": false, "slot_index": -1, "reason": "invalid_slot"}
		if _field[slot_index]["character_id"] != -1:
			return {"success": false, "slot_index": -1, "reason": "invalid_slot"}

	# 写入阵位 + 标记 STANDBY（本回合不可攻击）
	# deploy_turn=0 为临时桩——待 CombatSystem 接入真实回合计数（Story Notes #10）
	_field[target_slot] = {
		"character_id": character_id,
		"is_front": _is_front(target_slot),
		"deploy_turn": 0,
		"state": FieldState.STANDBY,
	}
	_emit_character_deployed(character_id, target_slot, _is_front(target_slot), 0)
	return {"success": true, "slot_index": target_slot, "reason": "deployed"}


## 角色阵亡时调用——清空阵位 + 发射 [signal character_removed]。[br]
## [br]绑定卡洗回由 BindingManager 处理——DeploymentSystem 不负责绑定卡生命周期（ADR-0016）。[br]
## [br][param character_id] 阵亡角色 ID。[br]
## [br][param reason] 离场原因字符串（默认 [code]"died"[/code]）。
func remove_character(character_id: int, reason: String = "died") -> void:
	var slot: int = get_character_slot(character_id)
	if slot == -1:
		return  # 不在场上——无操作
	_field[slot] = {
		"character_id": -1,
		"is_front": _is_front(slot),
		"deploy_turn": -1,
		"state": FieldState.EMPTY,
	}
	_emit_character_removed(character_id, slot, reason)

# === 前后排保护查询 ================================================================

## O(1) 前后排保护查询——AI 目标选择时每帧调用。[br]
## [br][b]6 步判断[/b]（ADR-0016 §前后排保护查询）：[br]
##   1. 角色必须在场上（[method get_character_slot] ≠ -1）[br]
##   2. 角色非 DEAD[br]
##   3. 前排角色 → 始终可被攻击 true[br]
##   4. 穿透效果 → 可被攻击 true[br]
##   5. 后排 + 前排无存活 → 可被攻击 true + 发射 [signal front_line_breached]（仅一次）[br]
##   6. 后排 + 前排有存活 → 受保护 false[br]
## [br][param character_id] 被查询的目标角色。[br]
## [br][param attacker_has_penetration] 攻击者是否有穿透效果（符箓/特殊功法）。[br]
## [br][b]返回[/b]: 是否可被攻击。
func is_targetable(character_id: int, attacker_has_penetration: bool = false) -> bool:
	var slot: int = get_character_slot(character_id)
	if slot == -1:
		return false  # 1. 不在场上
	var entry: Dictionary = _field[slot]
	if entry["state"] == FieldState.DEAD:
		return false  # 2. 已阵亡
	if entry["is_front"]:
		return true  # 3. 前排始终可攻击
	if attacker_has_penetration:
		return true  # 4. 穿透无视保护
	if get_front_count(true) == 0:
		# 5. 后排 + 前排无存活 → 可攻击 + 破防信号（仅一次）
		if not _front_line_breached_emitted:
			_front_line_breached_emitted = true
			_emit_front_line_breached()
		return true
	return false  # 6. 后排受保护
