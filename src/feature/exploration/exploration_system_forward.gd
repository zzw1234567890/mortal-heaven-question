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

## 可达性纯算法（行动力最短路）——本层是它唯一的调用方，故常量就近声明
## （[code]exploration_system_helpers.gd[/code] 已贴 300 行软上限）。
const Reachability := preload("res://src/feature/exploration/exploration_reachability.gd")
## 读档续玩子模块（缓存重建 + 快照重播）——同样因 helpers 贴顶，句柄与获取都放本层。
const ResumeScript := preload("res://src/feature/exploration/exploration_system_resume.gd")

## 读档续玩子模块实例（惰性创建并持有引用——防 RefCounted 提前释放）。
var _resume: RefCounted = null


# ═══════════════════════════════════════════════════════════════════════════════
# 读档续玩（委托给 ResumeScript 子模块）
# ═══════════════════════════════════════════════════════════════════════════════

## 读档续玩——从存档快照重建某张图并广播渲染快照（[b]不重新生成地图[/b]）。[br]
## [br][b]为什么不走 [method enter_map][/b]：那条路会重新生成 DAG（新 seed）、把
## 已访问重置为入口、行动力回满——玩家读档后会被悄悄送回起点。续玩要的正是
## [b]原样恢复[/b]：图、走过的路、剩余行动力全部取自存档。[br]
## [br][b]返回[/b]：广播出去的快照；该图在存档里没有 graph/nodes 时返回空字典
## （调用方据此退回选图界面——不臆造一张图让玩家进去）。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型（读档重建）、GDD save-load-system.md。
func resume_map(p_map_id: StringName) -> Dictionary:
	if _resume == null:
		_resume = ResumeScript.new(self)
	return _resume.call(&"resume_map", p_map_id)


## 从存档快照重建 DAG 缓存（不发信号）——[method resume_map] 的前半段，单独暴露给
## 需要「先建缓存再自己广播」的调用方与测试。[br]
## [br][b]返回[/b]：重建用的 map_data；无快照时返回空字典。
func rebuild_cache_from_storage(p_map_id: StringName) -> Dictionary:
	if _resume == null:
		_resume = ResumeScript.new(self)
	return _resume.call(&"cache_from_storage", p_map_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 可达性查询（委托给 Reachability 纯算法——本层唯一只读方法族）
# ═══════════════════════════════════════════════════════════════════════════════

## 从当前节点走到 Boss 的最少行动力花费。[br]
## [br][b]为什么需要它[/b]：系统里必须有个地方回答得了「还走不走得到 Boss」——
## [method end_exploration] 只看入参。于是行动力见底时玩家无从知道自己还能不能
## 通关，UI 也讲不清「此刻离开会丢掉什么」（GDD §5「行动力归零且无法到达Boss
## → 立即结算」、§8 退出按钮）。[br]
## [br][b]★ 本轮起算的是「直达花费」而不是「沿边最短路」★[/b]（全连通 + 距离定价，
## 老板 2026-11-27 18:40）：既然任一节点到任一节点都能一步走到（只是价钱按距离
## 不同），最短路退化成「所有 Boss 节点里最近的那一个」——绕路不再可能更便宜，
## 因为不存在「必须绕路」这回事。口径与 [method move_to_node] 的扣费共用
## [ExplorationApRules.cost_for_move]。[br]
## [br][b]已访问节点不再是障碍[/b]：本轮起已访问节点可以重入（消耗照算），把走过的
## 格子算成墙会给出一个玩家其实做得到的假拒绝。已在 Boss 节点时为 0。[br]
## [br][b]只读[/b]：不修改任何状态（ADR-0014 §关键接口）。[br]
## [br][b]返回[/b]：最少花费（≥0）；[constant ExplorationReachability.UNREACHABLE]
## （-1）表示图里没有 Boss——也用于 DAG 未就绪 / GSM 不可用（无法作答时不给假答案）。[br]
## [br]来源: GDD exploration-system.md §4/§5/§8、action-point-system.md §公式 2/3、
## 本轮任务书追加规则（全连通 + 距离定价）。
func min_ap_to_boss() -> int:
	if not _dag_ready:
		return Reachability.UNREACHABLE
	var gsm: Node = _get_gsm()
	if gsm == null:
		return Reachability.UNREACHABLE
	return Reachability.min_ap_to_any(_node_graph, _node_details, _map_config,
			_current_node_id(gsm), [NodeType.BOSS])


## 以剩余行动力是否还走得到 Boss。[br]
## [br][b]与 [method min_ap_to_boss] 的分工[/b]：那个报「要花多少」，本方法答
## 「够不够」——UI 只需后者决定退出按钮的呈现（UI 零数值计算）。已在 Boss 节点 /
## 走到 Boss 不花行动力时恒为 true（GDD §8）。[br]
## [br][b]返回[/b]：true = 还走得到；false = 走不到（含 DAG 未就绪 / GSM 不可用 /
## 剩余行动力不足——都无法承诺「还能通关」）。来源 GDD §5 结束条件 / §8 边界。
func can_still_reach_boss() -> bool:
	var need: int = min_ap_to_boss()
	if need == Reachability.UNREACHABLE:
		return false
	var gsm: Node = _get_gsm()
	if gsm == null:
		return false
	return maxi(int(gsm.exploration.get("action_points", 0)), 0) >= need


## 当前所在节点 ID——从 GSM 的层/位反解（编码 [code]layer * 100 + idx[/code]）。[br]
## [br][b]与移动写入同源[/b]：[method move_to_node] 正是按这个编码写
## [code]node_position[/code] 的，反解不会与它分家（用乘法而非整除——避开
## [code]INTEGER_DIVISION[/code] 告警，且编码本身就是乘加）。[br]
## [br][b]越界存档值夹到 0 层 0 位[/b]（入口）：比返回一个图里不存在的 ID 安全
## （同 [method move_to_node] 对负 AP 先夹到 0 的取向）。[br]
func _current_node_id(p_gsm: Node) -> int:
	var pos: Dictionary = p_gsm.exploration.get("node_position", {})
	var layer: int = maxi(int(pos.get("layer", 0)), 0)
	var idx: int = maxi(int(pos.get("idx", 0)), 0)
	return layer * 100 + idx


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


# ═══════════════════════════════════════════════════════════════════════════════
# 炼丹台 / 炼器台（委托给 _craft 子模块）
# ═══════════════════════════════════════════════════════════════════════════════

## 可炼配方列表——[b]只读[/b]，不修改任何状态。[br]
## [br][param p_kind] 配方种类（[code]alchemy[/code] 丹药 / [code]forge[/code] 法宝）。[br]
## [br][b]返回[/b]：条目数组（[code]{index, recipe_id, name, rarity, rarity_name,
## cost_text, costs, locked, lock_reason, full, affordable, enabled, reason}[/code]）；
## 未知种类时空数组（面板显示「无方可炼」而非空白）。[br]
## [br][b]配方来自既有配方资源[/b]：[code]AlchemyRecipes[/code] 是唯一真理来源
## ——本方法只是它的读取面（UI 零数值计算，不自行拼装配方表）。[br]
## [br]来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§4、[ExplorationCraft]。
func craft_entries(p_kind: StringName) -> Array:
	return _get_craft().call(&"entries", p_kind)


## 炼制第 [param p_index] 道配方——扣灵材 + 产卡入收藏（走 GSM 原子写入口）。[br]
## [br][param p_kind] 配方种类（[code]alchemy[/code] / [code]forge[/code]）。[br]
## [param p_index] 行号（取 [method craft_entries] 条目里的 [code]index[/code]）。[br]
## [br][b]返回[/b]：[code]{success, reason, message, recipe_id, card_instance_id,
## final_rarity}[/code]——[code]message[/code] 为面向玩家的中文提示（面板原样显示）。[br]
## [br][b]拒绝路径[/b]：行号越界 / 等级不足 / 收藏已满 / 灵材不足 / 系统不可用
## → 不改任何状态（见 [ExplorationCraft] 的「失败不半完成」）。[br]
## [br]来源: design/gdd/alchemy-crafting-system.md AC-1/AC-13、ADR-0028 §craft_pill。
func craft_at_node(p_kind: StringName, p_index: int) -> Dictionary:
	return _get_craft().call(&"craft", p_kind, p_index)


## 各品质档位的灵材持有量（面板顶部摘要——只读 ResourceSystem）。
func craft_balance() -> Dictionary:
	return _get_craft().call(&"balance")


# ═══════════════════════════════════════════════════════════════════════════════
# 打坐 / 洞府（委托给 _breakthrough 子模块）
# ═══════════════════════════════════════════════════════════════════════════════

## 打坐/洞府的突破状态——[b]只读[/b]，不修改任何状态。[br]
## [br][b]返回[/b]：[code]{can_breakthrough, reason, message, realm, next_realm,
## realm_name, next_realm_name, headline, cultivation, max_cultivation, required,
## success_rate, penalty, at_max, action_text, status_lines}[/code]；文案已由
## Feature 层格式化（UI 零数值计算）。[br]
## [br][b]数值来自既有境界配置表[/b]：所需修为 / 境界名 / 最高境界全部读
## [code]RealmSystem.realm_table[/code]，不硬编码等级与所需修为。[br]
## [br]来源: design/gdd/cultivation-system.md §4/§6、[ExplorationBreakthrough]。
func breakthrough_status() -> Dictionary:
	return _get_breakthrough().call(&"status")


## 尝试突破下一境界——无战斗的冲关（成功扣修为 + 升境界 + 属性按配置重算；
## 失败按配置扣一部分修为、境界不变；任何情况下修为不落负）。[br]
## [br][b]返回[/b]：[code]{success, reason, message, rolled, realm_before,
## realm_after, cultivation_before, cultivation_after, spent, penalty,
## attributes, cultivation_full}[/code]——[code]message[/code] 为面向玩家的中文
## 提示（面板原样显示）。[br]
## [br][b]拒绝路径[/b]（境界已满 / 修为不足 / 配置缺失 / 系统不可用）不改任何状态，
## 且 [code]rolled=false[/code]（据此与「掷骰失败」区分）。[br]
## [br][b]随机源[/b]：注入 [member breakthrough_rng] 优先（测试固定种子——
## 同种子同结果），否则子模块自建随机实例。[br]
## [br]来源: design/gdd/cultivation-system.md §6/§边界、ADR-0010 §realm_up 编排器。
func attempt_breakthrough() -> Dictionary:
	return _get_breakthrough().call(&"attempt")


## 各属性在指定境界的取值（[code]realm_table[/code] 的只读查询快照）。[br]
## [br][param p_level] 境界等级（1 炼气 … 5 化神）。[br]
## [br][b]返回[/b]：[code]{max_cultivation, max_deploy, deck_limit, action_points,
## card_pool_tier, gongfa_slots, fabao_slots}[/code]；境界不在表中时空字典。[br]
## [br][b]用途[/b]：突破后「属性按配置重算」的实证面——UI 与测试都读它，
## 不自己查表推算。[br]
func breakthrough_attributes(p_level: int) -> Dictionary:
	return _get_breakthrough().call(&"attributes_of", p_level)
