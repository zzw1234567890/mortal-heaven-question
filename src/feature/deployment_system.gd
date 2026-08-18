## DeploymentSystem —— 上场阵位系统 Autoload（#17）。
##
## Feature 层 Autoload。采用内部状态机管理阵位数据——阵位分布、角色在场状态、
## 待命/已就绪标记均在内部 [member _field] Dictionary 中管理，战斗期间阵位数据不经过 GSM。
## 采用与 ADR-0011 StatusEffectSystem / ADR-0013 BindingManager 相同的 GSM 边界先例。
##
## [b]Autoload 顺序[/b]：#1-#16 之后（RealmSystem #11 已就绪）。[br]
## [b]本 Story 范围[/b]（4-6 + 4-7 + 4-8）：FieldState 枚举 + 阵位数据模型 + [method setup_field] 自动/手动分配
## + 待命状态机（STANDBY/READY/ACTED）+ 阵位查询 API + 战中补位 [method deploy] + 阵亡清位
## [method remove_character] + 前后排保护查询 [method is_targetable] + 战斗结束快照导出
## [method serialize_field] / [method deserialize_field] / [method sync_unavailable_to_gsm] /
## [method load_unavailable_from_gsm] / [method write_snapshot_to_gsm]。[br]
## [b]不注册进 project.godot[/b]——待 CombatSystem 接线（4-22）后统一注册（4-0b 终验）。[br]
## [b]信号[/b]：本 Story 发射 character_deployed / character_removed / front_line_breached 三个 Cat 2b 信号
## （经 GSM._emit_signal_safe 路由）；standby_cleared / character_unavailable / character_revived 属 Story 004。[br]
##
## 来源: ADR-0016 §决策 §阵位数据模型 §关键接口 / GDD deployment-system.md。
extends Node
# class_name DeploymentSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 DS_SCRIPT.new() 测试实例无法解析。
# 测试以 var ds: Node 持有 + 动态分派访问（同 GSM/RealmSystem/CostSystem 先例，
# 控制清单 2026-08-05 规则）。


# === 枚举 ========================================================================

## 角色在场状态机——STANDBY（待命）→ READY（已就绪）→ ACTED（已行动）→ 回合结束 → READY；DEAD → 空位。
## 状态转换由 CombatSystem 在回合编排中驱动（clear_standby_state / set_acted）。
enum FieldState {
	EMPTY = 0,    ## 空位——无角色
	STANDBY = 1,  ## 待命——上场回合不可攻击（GDD §5 待命规则）
	READY = 2,    ## 已就绪——可正常行动
	ACTED = 3,    ## 已行动——本回合已执行动作
	DEAD = 4,     ## 阵亡——阵位变为空位
}


# === 常量 ========================================================================

## 固定 6 格阵位（前 3 后 3）——ADR-0016 §阵位数据模型。
const SLOT_COUNT: int = 6

## 前排阵位数量（slot 0-2）。
const FRONT_SLOTS: int = 3

## 境界上场上限 → 前排配额映射（GDD §2 境界阵位分布表）。
## 炼气/筑基/金丹（max_deploy 2-4）→ 前 2；元婴/化神（5-6）→ 前 3。
## 阵位分布是境界属性——由 max_deploy 唯一决定（ADR-0016 境界→人数映射在 RealmSystem，
## 本表为 DeploymentSystem 的阵位分布规则）。
const FRONT_CAPACITY_BY_MAX_DEPLOY: Dictionary = {2: 2, 3: 2, 4: 2, 5: 3, 6: 3}


# === 内部数据 =====================================================================

## 阵位数据——[code]{slot_index: {character_id, is_front, deploy_turn, state}}[/code]。
## slot_index 编码：0=前1, 1=前2, 2=前3, 3=后1, 4=后2, 5=后3。[br]
## 空位为 [code]{character_id: -1, is_front: bool, deploy_turn: -1, state: EMPTY}[/code]。
var _field: Dictionary = {}

## 不可用角色列表（跨战斗持久）——[code]{character_id: {death_turn, death_battle_id, revival_methods}}[/code]。
## 本 Story 仅初始化空字典——mark_unavailable/revive_character 生命周期属 Story 004。
var _unavailable_characters: Dictionary = {}

## 前排破防信号已发射标志——防止 [method is_targetable] 重复发射 front_line_breached。
## 在 [method setup_field] 中重置（ADR-0016 §风险缓解）。
var _front_line_breached_emitted: bool = false


# === 信号声明（Cat 2b）=============================================================

## 角色上场时发射（备战/战中补位）。[br]
## [br][b]载荷[/b]: [code](character_id, slot_index, is_front, deploy_turn)[/code]。
signal character_deployed(character_id: int, slot_index: int, is_front: bool, deploy_turn: int)

## 角色阵亡离场时发射。[br]
## [br][b]载荷[/b]: [code](character_id, slot_index, reason)[/code]——reason 为离场原因字符串。
signal character_removed(character_id: int, slot_index: int, reason: String)

## 前排全灭→后排暴露时发射（仅一次，setup_field 重置标志）。[br]
## [br][b]载荷[/b]: 无参数。
signal front_line_breached()


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


# === 查询 API =====================================================================

## 返回当前阵位分布（按 slot_index 升序）。[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code]——每项含
## [code]{slot_index, character_id, is_front, state, deploy_turn}[/code]；
## 空位为 [code]character_id=-1[/code] + [code]state=EMPTY[/code] + [code]deploy_turn=-1[/code]。
func get_field() -> Array:
	var result: Array = []
	for i in range(SLOT_COUNT):
		var entry: Dictionary = _field[i]
		result.append({
			"slot_index": i,
			"character_id": entry["character_id"],
			"is_front": entry["is_front"],
			"state": entry["state"],
			"deploy_turn": entry["deploy_turn"],
		})
	return result


## 查询角色所在 slot_index（O(n)，n≤6）。[br]
## [br][param character_id] 角色 ID。[br]
## [br][b]返回[/b]: slot_index；未上场返回 -1。[br]
## [br][b]哨兵守卫[/b]：-1 是空位的内部 character_id 哨兵值——传入 -1 直接返回 -1，
## 避免「查询不存在角色」误命中空位（QA 覆盖审查缺口 #3）。
func get_character_slot(character_id: int) -> int:
	if character_id == -1:
		return -1
	for slot in range(SLOT_COUNT):
		if _field[slot]["character_id"] == character_id:
			return slot
	return -1


## 前排角色计数。[br]
## [br][param alive_only] true = 仅存活（排除 DEAD）；false = 占用计数（含阵亡）。均排除空位。[br]
## [br][b]返回[/b]: 前排角色数。
func get_front_count(alive_only: bool = true) -> int:
	var count: int = 0
	for slot in range(FRONT_SLOTS):
		var entry: Dictionary = _field[slot]
		if entry["character_id"] == -1:
			continue
		if alive_only and entry["state"] == FieldState.DEAD:
			continue
		count += 1
	return count


## 返回空阵位 slot_index 列表——前排优先排序（0,1,2,3,4,5）。[br]
## [br][b]返回[/b]: [code]Array[int][/code]。
func get_empty_slots() -> Array:
	var empty: Array = []
	for slot in [0, 1, 2, 3, 4, 5]:
		if _field[slot]["character_id"] == -1:
			empty.append(slot)
	return empty


## 出战前检查。[br]
## [br][b]返回[/b]: [code]{can_deploy: bool, empty_slots: int, max_deploy: int, reason: String}[/code]。
func can_deploy() -> Dictionary:
	var empty_slots: int = get_empty_slots().size()
	var max_deploy: int = _query_max_deploy()
	var deployed: int = SLOT_COUNT - empty_slots
	var can: bool = empty_slots > 0 and deployed < max_deploy
	var reason: String = "可以补位" if can else ("场上已满" if empty_slots == 0 else "已达上场人数上限")
	return {
		"can_deploy": can,
		"empty_slots": empty_slots,
		"max_deploy": max_deploy,
		"reason": reason,
	}


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


# === 信号发射包装（ADR-0007）=======================================================

## 发射 [signal character_deployed]——经 GSM._emit_signal_safe 路由（Cat 2b）。[br]
## GSM 不可用时（测试 mock）回退直接 emit。
func _emit_character_deployed(character_id: int, slot_index: int, is_front: bool, deploy_turn: int) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(self, &"character_deployed", [character_id, slot_index, is_front, deploy_turn])
	else:
		character_deployed.emit(character_id, slot_index, is_front, deploy_turn)


## 发射 [signal character_removed]——经 GSM._emit_signal_safe 路由。
func _emit_character_removed(character_id: int, slot_index: int, reason: String) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(self, &"character_removed", [character_id, slot_index, reason])
	else:
		character_removed.emit(character_id, slot_index, reason)


## 发射 [signal front_line_breached]——经 GSM._emit_signal_safe 路由。
func _emit_front_line_breached() -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(self, &"front_line_breached", [])
	else:
		front_line_breached.emit()


# === 战斗结束快照导出 / 读档恢复（ADR-0016 §GSM 边界）=============================

## 战斗结束时序列化阵位——导出纯 Dictionary 快照至 GSM.battle.deployment_snapshot。[br]
## [br]6 个阵位逐槽序列化，state 用 FieldState 枚举名 String 序列化（可读性 + 前向兼容）。[br]
## [br][b]返回[/b]: [code]{slot_index: {character_id, is_front, state, deploy_turn}, ...}[/code]——
## 纯原始类型，无 RefCounted/Node 引用（可直接 JSON 序列化）。[br]
## [br]来源: ADR-0016 §关键接口 serialize_field。
func serialize_field() -> Dictionary:
	var result: Dictionary = {}
	for slot in range(SLOT_COUNT):
		var entry: Dictionary = _field[slot]
		result[slot] = {
			"character_id": entry["character_id"],
			"is_front": entry["is_front"],
			"state": _state_to_string(entry["state"]),
			"deploy_turn": entry["deploy_turn"],
		}
	return result


## 从快照恢复阵位——读档 / 战斗快照恢复入口。[br]
## [br]快照格式同 [method serialize_field] 输出。[br]
## [br][b]安全处理[/b]：空/无效 data 不崩溃——缺字段的 slot 用空位默认值填充；缺 slot 保持空位。[br]
## [br][b]键归一[/b]：内存快照用 int key，JSON round-trip 后 key 变 String——两者均接受（避免读档静默丢阵位）。[br]
## [br][param data] [method serialize_field] 输出的快照 Dictionary。
func deserialize_field(data: Dictionary) -> void:
	_reset_field()
	if data.is_empty():
		return  # 空快照——保持全空阵位
	for slot in range(SLOT_COUNT):
		# 键归一：内存快照用 int key，JSON round-trip 后 key 变 String——两者均接受（C-1 修复）
		var entry: Variant = null
		if data.has(slot):
			entry = data[slot]
		elif data.has(str(slot)):
			entry = data[str(slot)]
		else:
			continue  # 缺 slot——保持空位
		if not entry is Dictionary:
			continue  # 非法 entry——保持空位
		var cid: int = int(entry.get("character_id", -1))
		var is_front: bool = bool(entry.get("is_front", _is_front(slot)))
		var state: FieldState = _state_from_string(entry.get("state", "EMPTY"))
		var deploy_turn: int = int(entry.get("deploy_turn", -1))
		_field[slot] = {
			"character_id": cid,
			"is_front": is_front,
			"deploy_turn": deploy_turn,
			"state": state,
		}


## 战斗结束时同步不可用角色列表至 GSM——存档持久化入口。[br]
## [br]GSM 不可用时静默跳过（is_instance_valid + has_method 双守卫）。[br]
## [br]来源: ADR-0016 §不可用角色生命周期 §跨战斗持久。
func sync_unavailable_to_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("_set_player_unavailable_characters"):
		return  # GSM 不可用——静默跳过
	gsm.call("_set_player_unavailable_characters", _unavailable_characters.duplicate(true))


## 从 GSM 存档数据恢复不可用角色列表——读档时。[br]
## [br][b]安全处理[/b]：非法 entry（非 Dictionary）跳过，缺字段填充默认值。[br]
## [br][param data] GSM.player.unavailable_characters 快照 Dictionary。
func load_unavailable_from_gsm(data: Dictionary) -> void:
	_unavailable_characters.clear()
	for cid: Variant in data.keys():
		var entry: Variant = data[cid]
		if not entry is Dictionary:
			continue  # 非法 entry——跳过
		_unavailable_characters[int(cid)] = {
			"death_turn": int(entry.get("death_turn", 0)),
			"death_battle_id": str(entry.get("death_battle_id", "")),
			"revival_methods": entry.get("revival_methods", []),
		}


## 写阵位快照至 GSM battle.deployment_snapshot（战斗结束导出委托）。[br]
## [br]GSM 不可用时静默跳过（is_instance_valid + has_method 双守卫）。[br]
## [br]来源: ADR-0016 §GSM 边界 §snapshot 导出。
func write_snapshot_to_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("_set_battle_deployment_snapshot"):
		return  # GSM 不可用——静默跳过
	gsm.call("_set_battle_deployment_snapshot", serialize_field())


## 动态获取 GSM Autoload 节点。[br]
## [br]用 SceneTree.root 查找而非硬引用全局名——避免测试环境无 Autoload 时崩溃
## （同 StatusEffectSystem._get_gsm 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


# === 内部 =========================================================================

## 重置 6 个阵位为空位（前排 is_front=true）。
func _reset_field() -> void:
	_field.clear()
	for i in range(SLOT_COUNT):
		_field[i] = {
			"character_id": -1,
			"is_front": _is_front(i),
			"deploy_turn": -1,
			"state": FieldState.EMPTY,
		}


## 阵位分配——手动布局优先，未指定角色按「前排队列填满后才填后排」分配（GDD §2 关键规则）。[br]
## [br]自动分配算法（前排配额上限，按 [constant FRONT_CAPACITY_BY_MAX_DEPLOY]）：[br]
##   - 前 N 个未指定角色放前排（N = 境界前排配额，直到配额用尽）[br]
##   - 剩余角色放后排（前排优先顺序：前1→前2→前3→后1→后2→后3）[br]
## [br][param character_ids] 上场角色 ID 列表。[br]
## [br][param layout] 手动前后排分配 [code]{char_id: is_front}[/code]。[br]
## [br][b]返回[/b]: [code]{character_id: slot_index}[/code]。
func _assign_slots(character_ids: Array, layout: Dictionary) -> Dictionary:
	var assignment: Dictionary = {}
	var used: Dictionary = {}  # slot_index -> true
	var max_deploy: int = _query_max_deploy()
	var front_capacity: int = FRONT_CAPACITY_BY_MAX_DEPLOY.get(max_deploy, FRONT_SLOTS)
	var front_assigned: int = 0

	# 1. 手动布局优先（指定 is_front 的角色放入对应行列；计入前排配额）
	for cid in character_ids:
		if not layout.has(cid):
			continue
		var is_front: bool = layout[cid]
		var slot: int = _find_empty_in_row(is_front, used)
		if slot == -1:
			slot = _find_empty_slot(used)  # 目标行已满——回退任意空位
		assignment[cid] = slot
		used[slot] = true
		if is_front:
			front_assigned += 1

	# 2. 自动分配剩余角色——前排配额填满后转后排（后排优先顺序：后1→后2→后3）
	for cid in character_ids:
		if assignment.has(cid):
			continue
		var slot: int
		if front_assigned < front_capacity:
			slot = _find_empty_in_row(true, used)
			if slot == -1:
				slot = _find_empty_slot(used)
			front_assigned += 1
		else:
			slot = _find_empty_in_row(false, used)
			if slot == -1:
				slot = _find_empty_slot(used)
		assignment[cid] = slot
		used[slot] = true
	return assignment


## 在指定行列查找空位。[br]
## [br][param is_front] true = 前排（0,1,2）；false = 后排（3,4,5）。[br]
## [br][param used] 已占用 slot 集合。[br]
## [br][b]返回[/b]: 空位 slot_index；行列已满返回 -1。
func _find_empty_in_row(is_front: bool, used: Dictionary) -> int:
	var slots: Array = [0, 1, 2] if is_front else [3, 4, 5]
	for s in slots:
		if not used.has(s):
			return s
	return -1


## 查找任意空位（前排优先排序）。[br]
## [br][b]返回[/b]: 空位 slot_index；全部已满返回 -1。
func _find_empty_slot(used: Dictionary) -> int:
	for s in [0, 1, 2, 3, 4, 5]:
		if not used.has(s):
			return s
	return -1


## slot_index 前后排判定——slot_index ∈ [0,2] 为前排。
func _is_front(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < FRONT_SLOTS


## FieldState 枚举 → String 名映射（序列化用——可读性 + 前向兼容）。[br]
## [br][b]未知状态[/b]：回退 "EMPTY"。
func _state_to_string(state: FieldState) -> String:
	match state:
		FieldState.STANDBY:
			return "STANDBY"
		FieldState.READY:
			return "READY"
		FieldState.ACTED:
			return "ACTED"
		FieldState.DEAD:
			return "DEAD"
		_:
			return "EMPTY"


## String 名 → FieldState 枚举映射（反序列化用）。[br]
## [br][b]未知/缺失[/b]：回退 [constant FieldState.EMPTY]。
func _state_from_string(state_name: String) -> FieldState:
	match state_name:
		"STANDBY":
			return FieldState.STANDBY
		"READY":
			return FieldState.READY
		"ACTED":
			return FieldState.ACTED
		"DEAD":
			return FieldState.DEAD
		_:
			return FieldState.EMPTY


## 查询当前境界的上场人数上限。[br]
## [br]通过 [method RealmSystem.get_current_property] 读取 GSM.player.realm——不自行维护境界→人数映射
## （L+1 公式在 RealmSystem 中，ADR-0016）。[br]
## [br][b]返回[/b]: max_deploy；GSM/realm 无效返回 0。
func _query_max_deploy() -> int:
	var val: Variant = RealmSystem.get_current_property(&"max_deploy")
	if val == null:
		return 0
	return int(val)
