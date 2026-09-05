extends RefCounted
## ExplorationMapFlush —— 探索结算/资源刷新子模块（从 exploration_system.gd 拆分）。
##
## RefCounted 子模块——持有 `_parent: Node` 引用（ExplorationSystem Autoload）。
## 包含资源收集、map_state 刷新、探索结束结算逻辑。
##
## [br]来源: ADR-0014 §决策 5 探索结束结算 / GDD exploration-system.md §公式 11。
## [br]Sprint 12 Story 011：从 exploration_system.gd 拆分。


# === EndReason 枚举值常量（避免依赖父节点枚举声明）=============================

const BOSS_DEFEATED: int = 0
const BATTLE_LOST: int = 1
const AP_DEPLETED: int = 2
const PLAYER_QUIT: int = 3


var _parent: Node = null


func _init(parent: Node = null) -> void:
	_parent = parent


# === 资源收集 ================================================================

## 收集资源——累积到 map_states[current_map].collected_*。[br]
## [br][param resource_type] 资源类型（"ling_shi" / "cultivation" / "cards"）。[br]
## [br][param amount] 数量。[br]
## [br][b]不直接写入 GSM player.* 域[/b]——仅累积到 map_states，结算时 _flush_map_state 转移。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func collect_resource(resource_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		push_warning("ExplorationSystem.collect_resource: GSM 不可用")
		return
	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		push_warning("ExplorationSystem.collect_resource: 无活跃地图")
		return
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(current_map, {})
	var key_str: String = "collected_" + str(resource_type)
	var current_val: int = int(state.get(key_str, 0))
	# 通过 update_exploration_map_state 传增量字典——不直接修改 GSM 内部引用（H-1 修复）
	gsm.update_exploration_map_state(current_map, {key_str: current_val + amount})


# === map_state 刷新 ========================================================

## 将 map_states[map_id] 中的 collected_* 转移到 GSM player.* 域。[br]
## [br][param map_id] 地图 ID。[br]
## [br][b]流程[/b]: 读取 collected_ling_shi / collected_cultivation → GSM 原子写入 → 清零 collected_*。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func _flush_map_state(map_id: StringName) -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	var changes: Dictionary = {}
	# 转移灵石
	var collected_ls: int = int(state.get("collected_ling_shi", 0))
	if collected_ls > 0:
		var current_ls: int = int(gsm.player.resources.get("ling_shi", 0))
		gsm._set_resource_ling_shi(current_ls + collected_ls)
		changes["collected_ling_shi"] = 0
	# 转移修为
	var collected_cult: int = int(state.get("collected_cultivation", 0))
	if collected_cult > 0:
		gsm.add_cultivation(collected_cult, "exploration_flush")
		changes["collected_cultivation"] = 0
	# 回写清零后的 state——传增量字典（H-1 修复：不直接修改 GSM 内部引用）
	if not changes.is_empty():
		gsm.update_exploration_map_state(map_id, changes)


## 战败结算——灵石全额，修为保留 50%（GDD §公式 11）。
func _flush_map_state_half_cultivation(map_id: StringName) -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	var changes: Dictionary = {}
	# 灵石全额
	var collected_ls: int = int(state.get("collected_ling_shi", 0))
	if collected_ls > 0:
		var current_ls: int = int(gsm.player.resources.get("ling_shi", 0))
		gsm._set_resource_ling_shi(current_ls + collected_ls)
		changes["collected_ling_shi"] = 0
	# 修为保留 50%
	var collected_cult: int = int(state.get("collected_cultivation", 0))
	if collected_cult > 0:
		var retained: int = int(floor(collected_cult * 0.5))
		if retained > 0:
			gsm.add_cultivation(retained, "battle_lost_half")
		changes["collected_cultivation"] = 0
	# 回写清零后的 state——传增量字典（H-1 修复：不直接修改 GSM 内部引用）
	if not changes.is_empty():
		gsm.update_exploration_map_state(map_id, changes)


# === 探索结束结算 ============================================================

## 探索结束结算——三种路径（GDD §公式 11 + ADR-0014 §决策 5）。[br]
## [br][param reason] 结束原因（EndReason 枚举）。[br]
## [br][b]结算路径[/b]:[br]
## [br]BOSS_DEFEATED → 通关奖励 + collected_* 全额转移[br]
## [br]BATTLE_LOST → collected_ling_shi 全额转移，collected_cultivation 保留 50%[br]
## [br]AP_DEPLETED / PLAYER_QUIT → collected_* 全额转移[br]
## [br][b]流程[/b]: _flush_map_state → clear_exploration_navigation → clear_dag_cache。[br]
## [br]来源: ADR-0014 §决策 5 + GDD §公式 11。
func end_exploration(reason: int) -> Dictionary:
	var gsm: Node = _parent.call("_get_gsm")
	var summary: Dictionary = {"reason": reason, "rewards": {}}
	if gsm == null:
		push_warning("ExplorationSystem.end_exploration: GSM 不可用")
		return summary
	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		push_warning("ExplorationSystem.end_exploration: 无活跃地图")
		return summary

	match reason:
		BOSS_DEFEATED:
			# 通关奖励
			var is_first: bool = not _is_map_cleared(current_map)
			var player_realm: int = _get_player_realm()
			var map_max_realm: int = _get_map_max_realm(current_map)
			var rewards: Dictionary = _parent.call("calculate_map_clear_rewards", current_map, is_first, player_realm, map_max_realm)
			summary["rewards"] = rewards
			# 发放通关奖励
			if rewards.has("ling_shi") and rewards["ling_shi"] > 0:
				var current_ls: int = int(gsm.player.resources.get("ling_shi", 0))
				gsm._set_resource_ling_shi(current_ls + rewards["ling_shi"])
			if rewards.has("cultivation") and rewards["cultivation"] > 0:
				gsm.add_cultivation(rewards["cultivation"], "map_clear")
			# 标记地图通关
			_mark_map_cleared(current_map)
			# 转移已收集资源
			_flush_map_state(current_map)
		BATTLE_LOST:
			# 灵石全额保留，修为保留 50%
			_flush_map_state_half_cultivation(current_map)
		AP_DEPLETED, PLAYER_QUIT:
			# 全额保留已收集资源
			_flush_map_state(current_map)

	# 清理导航状态 + DAG 缓存
	gsm.clear_exploration_navigation()
	_parent.call("clear_dag_cache")

	# 发射探索结束信号
	_parent.call("_emit_safe", &"exploration_ended", [reason, summary])

	return summary


# === 辅助查询 ================================================================

## 检查地图是否已通关——从 map_states 读取 is_first_clear。
func _is_map_cleared(map_id: StringName) -> bool:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return false
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	return bool(state.get("is_first_clear", false))


## 标记地图通关——写入 is_first_clear=true。
func _mark_map_cleared(map_id: StringName) -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	gsm.update_exploration_map_state(map_id, {"is_first_clear": true})


## 获取玩家境界——从 GSM player.realm 读取。
func _get_player_realm() -> int:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return 1
	return int(gsm.player.get("realm", 1))


## 获取地图最高允许境界——从 PERMANENT_FREE_MAPS 或配置读取。
func _get_map_max_realm(map_id: StringName) -> int:
	var permanent_free: Dictionary = _parent.get("PERMANENT_FREE_MAPS")
	if permanent_free.has(map_id):
		return int(permanent_free[map_id])
	var config: Dictionary = _parent.call("_get_map_config", map_id, _get_player_realm())
	return int(config.get("max_realm", 1))
