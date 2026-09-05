## DeploymentSystem —— 上场阵位系统 Autoload（#17）。
##
## Feature 层 Autoload。采用内部状态机管理阵位数据——阵位分布、角色在场状态、
## 待命/已就绪标记均在内部 [member _field] Dictionary 中管理，战斗期间阵位数据不经过 GSM。
## 采用与 ADR-0011 StatusEffectSystem / ADR-0013 BindingManager 相同的 GSM 边界先例。
##
## [b]Autoload 顺序[/b]：#1-#16 之后（RealmSystem #11 已就绪）。[br]
## [b]本 Story 范围[/b]（4-6 + 4-7 + 4-8 + 4-9）：FieldState 枚举 + 阵位数据模型 + [method setup_field] 自动/手动分配
## + 待命状态机（STANDBY/READY/ACTED）+ 阵位查询 API + 战中补位 [method deploy] + 阵亡清位
## [method remove_character] + 前后排保护查询 [method is_targetable] + 战斗结束快照导出
## [method serialize_field] / [method deserialize_field] / [method sync_unavailable_to_gsm] /
## [method load_unavailable_from_gsm] / [method write_snapshot_to_gsm] + 待命清除 [method clear_standby_state] +
## 不可用生命周期 [method mark_unavailable] / [method revive_character] / [method get_unavailable_characters] /
## [method is_game_over]。[br]
## [b]不注册进 project.godot[/b]——待 CombatSystem 接线（4-22）后统一注册（4-0b 终验）。[br]
## [b]信号[/b]：发射 6 个 Cat 2b 信号（character_deployed / character_removed / front_line_breached /
## standby_cleared / character_unavailable / character_revived），均经 GSM._emit_signal_safe 路由。[br]
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

## 序列化子模块——惰性初始化（Sprint 9 Story 1 拆分）。
var _serializer: RefCounted = null

## 阵位分配子模块——惰性初始化（Sprint 9 Story 1 拆分）。
var _slot_allocator: RefCounted = null

## 信号发射子模块——惰性初始化（Sprint 12 Story 018 拆分）。
var _emitter: RefCounted = null


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

## 回合结束时待命清除发射（Phase 6 END，CombatSystem 调用）。[br]
## [br][b]载荷[/b]: [code](character_ids: Array[int])[/code]——仅含 STANDBY→READY 的角色（不含 ACTED→READY）。
signal standby_cleared(character_ids: Array[int])

## 角色标记为不可用时发射（战斗结算）。[br]
## [br][b]载荷[/b]: [code](character_id: int)[/code]。
signal character_unavailable(character_id: int)

## 角色复活时发射。[br]
## [br][b]载荷[/b]: [code](character_id: int)[/code]。
signal character_revived(character_id: int)


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


# === 不可用角色生命周期（ADR-0016 §跨战斗死亡持久）=================================

## 战斗结算时标记角色不可用——加入 [member _unavailable_characters] 并发射 [signal character_unavailable]。[br]
## [br][b]存储结构[/b]：[code]{death_turn, death_battle_id, revival_methods}[/code]——[param death_context]
## 缺字段填充默认值（death_turn=0 / death_battle_id="" / revival_methods=[]）。[br]
## [br][b]重复标记[/b]：同一角色重复标记时覆盖旧 context（战斗结算逻辑保证一个角色只标记一次）。[br]
## [br][param character_id] 阵亡角色 ID。[br]
## [br][param death_context] 死亡上下文 [code]{death_turn, death_battle_id, revival_methods?}[/code]。
func mark_unavailable(character_id: int, death_context: Dictionary) -> void:
	_unavailable_characters[character_id] = {
		"death_turn": int(death_context.get("death_turn", 0)),
		"death_battle_id": str(death_context.get("death_battle_id", "")),
		"revival_methods": death_context.get("revival_methods", []).duplicate(true),
	}
	_emit_character_unavailable(character_id)


## 返回不可用角色 ID 列表——商店/事件系统查询复活道具可用性。[br]
## [br][b]返回[/b]: [code]Array[int][/code]——[member _unavailable_characters] 的键列表（可为空）。
func get_unavailable_characters() -> Array:
	return _unavailable_characters.keys()


## 复活不可用角色——从 [member _unavailable_characters] 移除并发射 [signal character_revived]。[br]
## [br]角色属性保留但空载（无绑定卡——绑定卡生命周期由 BindingManager 处理）。[br]
## [br][param character_id] 待复活角色 ID。[br]
## [br][b]返回[/b]: true = 成功复活；false = 角色不在不可用列表中（不发射信号）。
func revive_character(character_id: int) -> bool:
	if not _unavailable_characters.has(character_id):
		return false
	_unavailable_characters.erase(character_id)
	_emit_character_revived(character_id)
	return true


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


# === 信号发射包装（委托 → DeploymentEmitter，Sprint 12 Story 018 拆分）============

func _emit_character_deployed(character_id: int, slot_index: int, is_front: bool, deploy_turn: int) -> void:
	_get_emitter().emit_character_deployed(character_id, slot_index, is_front, deploy_turn)

func _emit_character_removed(character_id: int, slot_index: int, reason: String) -> void:
	_get_emitter().emit_character_removed(character_id, slot_index, reason)

func _emit_front_line_breached() -> void:
	_get_emitter().emit_front_line_breached()

func _emit_standby_cleared(character_ids: Array) -> void:
	_get_emitter().emit_standby_cleared(character_ids)

func _emit_character_unavailable(character_id: int) -> void:
	_get_emitter().emit_character_unavailable(character_id)

func _emit_character_revived(character_id: int) -> void:
	_get_emitter().emit_character_revived(character_id)


# === 战斗结束快照导出 / 读档恢复（ADR-0016 §GSM 边界）=============================

## 战斗结束时序列化阵位——委托给 _serializer 子模块。
func serialize_field() -> Dictionary:
	return _get_serializer().serialize_field()


## 从快照恢复阵位——委托给 _serializer 子模块。
func deserialize_field(data: Dictionary) -> void:
	_get_serializer().deserialize_field(data)


## 战斗结束时同步不可用角色列表至 GSM——委托给 _serializer 子模块。
func sync_unavailable_to_gsm() -> void:
	_get_serializer().sync_unavailable_to_gsm()


## 从 GSM 存档数据恢复不可用角色列表——委托给 _serializer 子模块。
func load_unavailable_from_gsm(data: Dictionary) -> void:
	_get_serializer().load_unavailable_from_gsm(data)


## 写阵位快照至 GSM——委托给 _serializer 子模块。
func write_snapshot_to_gsm() -> void:
	_get_serializer().write_snapshot_to_gsm()


## 动态获取 GSM Autoload 节点。[br]
## [br]用 SceneTree.root 查找而非硬引用全局名——避免测试环境无 Autoload 时崩溃
## （同 StatusEffectSystem._get_gsm 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 惰性获取序列化子模块（Sprint 9 Story 1 拆分）。
func _get_serializer() -> RefCounted:
	if _serializer == null:
		_serializer = load("res://src/feature/deployment/deployment_serializer.gd").new(self)
	return _serializer


## 惰性获取阵位分配子模块（Sprint 9 Story 1 拆分）。
func _get_slot_allocator() -> RefCounted:
	if _slot_allocator == null:
		_slot_allocator = load("res://src/feature/deployment/deployment_slot_allocator.gd").new(self)
	return _slot_allocator


## 惰性获取信号发射子模块（Sprint 12 Story 018 拆分）。
func _get_emitter() -> RefCounted:
	if _emitter == null:
		_emitter = load("res://src/feature/deployment/deployment_emitter.gd").new(self)
	return _emitter


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


## 阵位分配——委托给 _slot_allocator 子模块。
func _assign_slots(character_ids: Array, layout: Dictionary) -> Dictionary:
	return _get_slot_allocator().assign_slots(character_ids, layout)


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
