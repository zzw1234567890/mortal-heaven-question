extends "res://src/feature/exploration/exploration_system_ops.gd"
## ExplorationSystemForward —— 探索系统的[b]子模块转发面[/b]：经济 / 结算刷新 /
## 回复点三类子模块的对外方法。[br]
## [br][b]为什么再拆一层[/b]：继承链各段都要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「系统承诺哪些方法」这一层在本轮新增了
## 地图列表 / 灵泉 / 传送五个方法后，与这批子模块转发合计 317 行。[br]
## [br][b]机械拆分、零行为改动[/b]：方法名、参数名、默认值与拆分前逐字一致——
## 测试与 UI 走的就是这些名字（[code]es.call("end_exploration", ...)[/code] /
## [code]es.call("_flush_map_state", ...)[/code]），继承链上的
## [method Object.call] 沿链解析，故调用方无感。[br]
## [br][b]与 ops 层的分工[/b]：ops 层是「只读查询 + 状态生命周期 + 对外信号」，
## 本层是「命令转发」——两者都不含编排逻辑（编排在链尾
## [code]exploration_system.gd[/code]）。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型 / §GSM 写入契约、
## 本轮「继承链各段 300 行以内」任务。

# ═══════════════════════════════════════════════════════════════════════════════
# 经济（委托给 _economy 子模块）
# ═══════════════════════════════════════════════════════════════════════════════

## 计算地图重入传送费——委托给 _economy 子模块。
func calculate_reentry_cost(map_id: StringName) -> int:
	return _get_economy().calculate_reentry_cost(map_id)


## 计算地图通关奖励——委托给 _economy 子模块。
func calculate_map_clear_rewards(map_id: StringName, is_first_clear: bool, player_realm: int, map_max_realm: int) -> Dictionary:
	return _get_economy().calculate_map_clear_rewards(map_id, is_first_clear, player_realm, map_max_realm)


## 境界差额惩罚系数——委托给 _economy 子模块。
func realm_gap_penalty(player_L: int, map_max_L: int) -> float:
	return _get_economy().realm_gap_penalty(player_L, map_max_L)


## 重入费用倍率——委托给 _economy 子模块。[br]
## [br][b]为什么单独暴露[/b]：地图选择卡片要展示「基础价 × 倍率」的明细，倍率若
## 只在 [method calculate_reentry_cost] 内部算，UI 侧就得把公式抄一遍
## （UI 零数值计算）。[br]
## [br][b]返回[/b]：倍率（首次 1.0，此后 +0.5/次，上限 3.0）。
func reentry_multiplier(map_id: StringName) -> float:
	return _get_economy().reentry_multiplier(map_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 结算刷新（委托给 _map_flush 子模块）
# ═══════════════════════════════════════════════════════════════════════════════

## 收集资源——委托给 _map_flush 子模块（Sprint 12 Story 011 拆分）。
func collect_resource(resource_type: StringName, amount: int) -> void:
	_get_map_flush().collect_resource(resource_type, amount)


## 将 map_states[map_id] 中的 collected_* 转移到 GSM player.* 域——委托给 _map_flush 子模块。
func _flush_map_state(map_id: StringName) -> void:
	_get_map_flush()._flush_map_state(map_id)


## 战败结算——委托给 _map_flush 子模块。
func _flush_map_state_half_cultivation(map_id: StringName) -> void:
	_get_map_flush()._flush_map_state_half_cultivation(map_id)


## 探索结束结算——委托给 _map_flush 子模块（Sprint 12 Story 011 拆分）。
func end_exploration(reason: int) -> Dictionary:
	return _get_map_flush().end_exploration(reason)


## 检查地图是否已通关——委托给 _map_flush 子模块。
func _is_map_cleared(map_id: StringName) -> bool:
	return _get_map_flush()._is_map_cleared(map_id)


## 标记地图通关——委托给 _map_flush 子模块。
func _mark_map_cleared(map_id: StringName) -> void:
	_get_map_flush()._mark_map_cleared(map_id)


## 获取玩家境界——委托给 _map_flush 子模块。
func _get_player_realm() -> int:
	return _get_map_flush()._get_player_realm()


## 获取地图最高允许境界——委托给 _map_flush 子模块。
func _get_map_max_realm(map_id: StringName) -> int:
	return _get_map_flush()._get_map_max_realm(map_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 回复点 / 灵泉（委托给 _rest / _action_spring 子模块）
# ═══════════════════════════════════════════════════════════════════════════════

## 回复点结算——全队回复 50% 已损失 HP（GDD §公式 7），返回实际回复量。[br]
## [br][b]唯一入口[/b]：UI 侧 [code]NodePopupServices.rest_party[/code] 调本方法，
## 面板只显示返回值（UI 零数值计算）。效果实现见 [ExplorationRest]。[br]
## [br][param p_node_id] 回复点节点 ID（透传——实现侧只用于日志）。[br]
## [br][b]返回[/b]：实际回复总量（全队满血 / 无角色登记 HP / GSM 写回入口缺失时为 0）。[br]
## [br]来源: GDD exploration-system.md §公式 7 + §8 边界、exploration-ui-system.md §4c。
func rest_at_node(p_node_id: int) -> int:
	return int(_get_rest().call(&"rest_at_node", p_node_id))


# ═══════════════════════════════════════════════════════════════════════════════
# 采集点（委托给 _harvest 子模块）
# ═══════════════════════════════════════════════════════════════════════════════

## 采集点可采列表——[b]只读[/b]，不修改任何状态。[br]
## [br][param p_node_id] 采集节点 ID。[br]
## [br][b]返回[/b]：条目数组（[code]{slot, name, kind, kind_name, quality,
## quality_name, amount, harvested, room}[/code]）；节点无载荷时空数组。[br]
## [br][b]唯一入口[/b]：UI 侧的面板与弹窗都走这里，不自行拼装材料列表
## （UI 零数值计算）。[br]
## [br]来源: design/gdd/resource-system.md §资源表（灵材）、[ExplorationHarvest]。
func harvest_entries(p_node_id: int) -> Array:
	return _get_harvest().call(&"entries_at", p_node_id)


## 采集一个槽位——材料经 [code]ResourceSystem.add_resource[/code] 入背包，
## 并把这个节点的这个槽位记为已采（随探索域持久化）。[br]
## [br][param p_node_id] 采集节点 ID。[br]
## [param p_slot] 材料槽位（[method harvest_entries] 条目里的 [code]slot[/code]）。[br]
## [br][b]返回[/b]：[code]{success, reason, message, gained, quality}[/code]
## ——[code]message[/code] 为面向玩家的中文提示（面板原样显示）。[br]
## [br][b]拒绝路径[/b]：槽位越界 / 重复采集 / 背包已满 → 不改任何状态。[br]
## [br]来源: design/gdd/resource-system.md §资源表 / §边界（AC-19）、
## ADR-0019 §关键接口、[ExplorationHarvest]。
func harvest_at_node(p_node_id: int, p_slot: int) -> Dictionary:
	return _get_harvest().call(&"harvest_at_node", p_node_id, p_slot)
