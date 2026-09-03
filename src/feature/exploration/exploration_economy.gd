## ExplorationEconomy —— 经济计算子模块（RefCounted）。
##
## 从 exploration_system.gd 提取的经济计算逻辑。[br]
## 持有父节点 ExplorationSystem 引用，通过它访问 GSM / 常量。[br]
## [br]常量 PERMANENT_FREE_MAPS / REENTRY_BASE_COSTS / CLEAR_REWARDS 保留在主文件（测试通过 es.get 访问）。[br]
## [br]来源: ADR-0014 §决策 4/5 + GDD §公式 5/6/10/11。[br]
## [br]Sprint 8 Story 8-9：从 exploration_system.gd 拆分。
extends RefCounted


## 父节点引用——ExplorationSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 计算地图重入传送费（GDD §公式 10）。[br]
## [br][param map_id] 地图 ID。[br]
## [br][b]返回[/b]: 灵石费用（0=免费）。[br]
## [br][b]规则[/b]: 首次进入免费；永久免费地图始终 0；后续按 base×multiplier。[br]
## [br]来源: ADR-0014 §决策 4 + GDD §公式 10。
func calculate_reentry_cost(map_id: StringName) -> int:
	# 永久免费地图——始终 0
	if _parent.get("PERMANENT_FREE_MAPS").has(map_id):
		return 0
	var stored_count: int = _parent.call("_get_entry_count", map_id)
	var entry_count: int = stored_count + 1  # 本次进入的序号（1=首次, 2=第二次, ...）
	# 首次进入免费
	if entry_count <= 1:
		return 0
	# 获取地图难度
	var config: Dictionary = _parent.call("_get_map_config", map_id, _parent.call("_get_player_realm"))
	var difficulty: int = _get_difficulty_from_config(config)
	var base: int = _parent.get("REENTRY_BASE_COSTS")[difficulty]
	# multiplier = min(1.0 + (entry_count - 2) * 0.5, 3.0)
	var multiplier: float = 1.0 + (entry_count - 2) * 0.5
	multiplier = minf(multiplier, 3.0)
	return int(floor(base * multiplier))


## 计算地图通关奖励（GDD §公式 5+6）。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param is_first_clear] 是否首次通关。[br]
## [br][param player_realm] 玩家境界。[br]
## [br][param map_max_realm] 地图最高允许境界。[br]
## [br][b]返回[/b]: [code]{ling_shi, cultivation, extra}[/code] Dictionary。[br]
## [br][b]规则[/b]: 灵石受境界差额惩罚；修为不受。[br]
## [br]来源: ADR-0014 §决策 4 + GDD §公式 5+6。
func calculate_map_clear_rewards(map_id: StringName, is_first_clear: bool, player_realm: int, map_max_realm: int) -> Dictionary:
	var config: Dictionary = _parent.call("_get_map_config", map_id, player_realm)
	var difficulty: int = _get_difficulty_from_config(config)
	var base: Dictionary = _parent.get("CLEAR_REWARDS")[difficulty]
	var penalty: float = realm_gap_penalty(player_realm, map_max_realm)
	var rewards: Dictionary = {
		"ling_shi": int(floor(base["ling_shi"] * penalty)),
		"cultivation": int(base["cultivation"]),  # 修为不受惩罚
	}
	if is_first_clear:
		rewards["extra"] = config.get("first_clear_reward", {})
	return rewards


## 境界差额惩罚系数（GDD §公式 6）。[br]
## [br][param player_L] 玩家实际境界。[br]
## [br][param map_max_L] 地图最高允许境界。[br]
## [br][b]返回[/b]: float [0.1, 1.0]——灵石惩罚系数。[br]
## [br][b]规则[/b]: gap<=0→1.0；gap>=1→max(0.1, 1.0-gap*0.3)。[br]
## [br]来源: ADR-0014 §决策 4 + GDD §公式 6。
func realm_gap_penalty(player_L: int, map_max_L: int) -> float:
	var gap: int = player_L - map_max_L
	if gap <= 0:
		return 1.0
	return maxf(0.1, 1.0 - gap * 0.3)


## 从配置获取难度索引。
func _get_difficulty_from_config(config: Dictionary) -> int:
	var layers: int = int(config.get("layers", 5))
	match layers:
		4: return 0  # LOW
		6: return 3  # VERY_HIGH
		5:
			var min_n: int = int(config.get("min_nodes", 2))
			if min_n >= 3:
				return 2  # HIGH
			return 1  # MEDIUM
		_: return 1  # MEDIUM fallback
