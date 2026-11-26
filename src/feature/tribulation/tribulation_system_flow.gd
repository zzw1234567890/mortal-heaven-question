## TribulationSystem 流程面（继承链第 3 段）——[b]触发 / 取消 / 状态转换 / 查询 / 渡劫丹[/b]。
##
## [b]本层职责[/b]：渡劫生命周期状态机与准备阶段的两条人机交互。[br]
##   · 触发与就绪判定——[method check_tribulation_ready] / [method trigger_tribulation]
##     （内含越阶渡劫的「不能跳 2 级以上」校验）；[br]
##   · 取消——[method cancel_tribulation]（PREPARING → NOT_READY，Story 5-13）；[br]
##   · 状态转换内核——[method _set_state] + [method _validate_state_transition]
##     （白名单 [constant _VALID_TRANSITIONS] 的唯一消费者）；[br]
##   · 查询出口——[method get_tribulation_status]（UI 与 [code]tribulation_launch.gd[/code]
##     都读它）；[br]
##   · 渡劫丹管理——[method use_tribulation_pill]（Story 5-12：仅 PREPARING 可用 /
##     上限 [constant MAX_TRIBULATION_PILLS] 枚 / 同种取高稀有度）。[br]
## [b]不管什么[/b]：不装配（链尾）、不建子模块（祖先段）、不碰结算与 Boss 查询（链尾转发）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  tribulation_system_contract.gd [/code] ← 声明面：2 枚举 / 3 标量常量 / 1 转换白名单 / 5 信号 / 7 实例字段[br]
## [code]  tribulation_system_access.gd   [/code] ← 接缝与访问面：惰性获取器 / 信号发射包装 / GSM 与四个 Autoload 获取器[br]
## [code]  tribulation_system_flow.gd     [/code] ← 本层：触发 / 取消 / 状态转换 / 查询 / 渡劫丹[br]
## [code]  tribulation_system.gd          [/code] ← 链尾：装配（_ready）+ 战斗委托 / 结算 / 雷伤 / Boss 查询出口[br]
##
## 来源: ADR-0021 §trigger_tribulation / §状态与转换 / §use_tribulation_pill /
## §check_tribulation_ready、GDD tribulation-system.md §1-2 + §状态机表。

extends "res://src/feature/tribulation/tribulation_system_access.gd"


# === 渡劫触发 ====================================================================

## 检查是否可以渡劫——修为满值 + 当前不在渡劫流程中。[br]
## [br][b]返回[/b]: [code]true[/code] 可渡劫（tribulation_state == NOT_READY 且 cultivation >= max_cultivation），[code]false[/code] 不可。[br]
## [br]来源: ADR-0021 §check_tribulation_ready + GDD §1 渡劫触发条件。
func check_tribulation_ready() -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem.check_tribulation_ready: GSM 不可用")
		return false
	var state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if state != TribulationState.NOT_READY:
		return false  # 已在渡劫流程中
	var current: int = int(gsm.player.cultivation)
	var max_cult: int = int(gsm.player.max_cultivation)
	return current >= max_cult


## 触发渡劫——进入准备阶段。[br]
## [br][param trib_type] 渡劫类型（NORMAL 或 CROSS_REALM）。[br]
## [br][b]流程[/b]:[br]
##   1. check_tribulation_ready 验证[br]
##   2. 越阶渡劫验证——不能超过最高境界[br]
##   3. 写入 PREPARING 状态到 GSM[br]
##   4. 发射 tribulation_triggered 信号[br]
## [br]来源: ADR-0021 §trigger_tribulation + GDD §1-2。
func trigger_tribulation(trib_type: int = TribulationType.NORMAL) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem.trigger_tribulation: GSM 不可用")
		return

	if not check_tribulation_ready():
		push_warning("TribulationSystem: trigger_tribulation() called but not ready")
		return

	# 越阶渡劫验证——不能跳 2 级以上
	if trib_type == TribulationType.CROSS_REALM:
		var current_realm: int = int(gsm.player.realm)
		var next_realm: int = current_realm + 1
		# RealmSystem 的 realm_table 最大境界为 5
		if next_realm > 5:
			push_warning("TribulationSystem: cross-realm tribulation exceeds max realm")
			return

	_trib_type = trib_type

	# 进入准备阶段——通过 GSM 第二层原子写入
	_set_state(TribulationState.PREPARING)

	# 发射 Cat 2b 信号
	var realm_level: int = int(gsm.player.realm)
	_emit_safe(&"tribulation_triggered", [realm_level])


# === 取消渡劫（Story 5-13）===================================================

## 取消渡劫——准备阶段返回 NOT_READY。[br]
## [br][b]流程[/b]（GDD §状态与转换 PREPARING→NOT_READY）:[br]
##   1. 验证 PREPARING 状态[br]
##   2. _set_state(NOT_READY)[br]
##   3. 清理 _trib_type + _active_pills[br]
## [br][b]非 PREPARING[/b] push_warning + return。[br]
## [br]来源: ADR-0021 §状态与转换 + GDD §2 渡劫准备阶段。
func cancel_tribulation() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem.cancel_tribulation: GSM 不可用")
		return
	var state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if state != TribulationState.PREPARING:
		push_warning("TribulationSystem.cancel_tribulation: 非 PREPARING 状态（%d）" % state)
		return
	_set_state(TribulationState.NOT_READY)
	_trib_type = TribulationType.NORMAL
	_active_pills.clear()


# === 状态管理 ====================================================================

## 状态转换——验证 + 写入 GSM。[br]
## [br][param new_state] 目标状态。[br]
## [br][b]流程[/b]: 验证转换合法性 → 写入 GSM player.tribulation_state。[br]
## [br][b]非法转换[/b] push_warning + return。[br]
## [br]来源: ADR-0021 §状态与转换。
func _set_state(new_state: int) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem._set_state: GSM 不可用")
		return

	var old_state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if not _validate_state_transition(old_state, new_state):
		push_warning("TribulationSystem: 非法状态转换 %d → %d" % [old_state, new_state])
		return

	gsm._set_tribulation_state(new_state)


## 验证状态转换合法性——白名单检查。[br]
## [br][param old_state] 当前状态。[br]
## [br][param new_state] 目标状态。[br]
## [br][b]返回[/b]: [code]true[/code] 合法，[code]false[/code] 非法。[br]
## [br]来源: ADR-0021 §状态与转换 + GDD §状态机表。
func _validate_state_transition(old_state: int, new_state: int) -> bool:
	if not _VALID_TRANSITIONS.has(old_state):
		return false
	var allowed: Array = _VALID_TRANSITIONS[old_state]
	return new_state in allowed


# === 查询接口 ====================================================================

## 获取渡劫状态摘要——供 UI 查询。[br]
## [br][b]返回[/b]: [code]{state, consecutive_failures, trib_type}[/code] Dictionary。[br]
## [br]来源: ADR-0021 §查询接口 + UI 查询需求。
func get_tribulation_status() -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {"state": TribulationState.NOT_READY, "consecutive_failures": 0, "trib_type": TribulationType.NORMAL}
	return {
		"state": int(gsm.player.get("tribulation_state", TribulationState.NOT_READY)),
		"consecutive_failures": int(gsm.player.get("consecutive_tribulation_failures", 0)),
		"trib_type": _trib_type,
	}


# === 渡劫丹管理（Story 5-12）=================================================

## 使用渡劫丹——准备阶段使用，最多 2 枚，同种不叠加取最高稀有度。[br]
## [br][param pill_data] 渡劫丹数据 [code]{type, rarity_tier, ...}[/code] Dictionary。[br]
## [br][b]返回[/b]: [code]true[/code] 使用成功，[code]false[/code] 被拒绝。[br]
## [br][b]规则[/b]（GDD §2 + §边缘情况）:[br]
##   1. 仅 PREPARING 状态可使用[br]
##   2. 总上限 MAX_TRIBULATION_PILLS(2) 枚[br]
##   3. 同种不叠加——高稀有度替换低稀有度，低稀有度被拒绝[br]
## [br]来源: ADR-0021 §use_tribulation_pill + GDD §2 渡劫准备阶段。
func use_tribulation_pill(pill_data: Dictionary) -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem.use_tribulation_pill: GSM 不可用")
		return false
	var state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if state != TribulationState.PREPARING:
		push_warning("TribulationSystem.use_tribulation_pill: 非 PREPARING 状态（%d）" % state)
		return false
	if not pill_data.has("type") or not pill_data.has("rarity_tier"):
		push_warning("TribulationSystem.use_tribulation_pill: pill_data 缺少 type 或 rarity_tier")
		return false
	if _active_pills.size() >= MAX_TRIBULATION_PILLS:
		push_warning("TribulationSystem: 最多使用 %d 枚渡劫丹" % MAX_TRIBULATION_PILLS)
		return false
	var pill_type: String = str(pill_data["type"])
	var pill_rarity: int = int(pill_data["rarity_tier"])
	# 同种不叠加——检查是否已有同类型
	for i in range(_active_pills.size()):
		var existing: Dictionary = _active_pills[i]
		if str(existing["type"]) == pill_type:
			var existing_rarity: int = int(existing["rarity_tier"])
			if existing_rarity >= pill_rarity:
				push_warning("TribulationSystem: 同种渡劫丹已有更高/等同稀有度")
				return false
			else:
				# 替换为更高稀有度版本
				_active_pills[i] = pill_data.duplicate(true)
				return true
	_active_pills.append(pill_data.duplicate(true))
	return true
