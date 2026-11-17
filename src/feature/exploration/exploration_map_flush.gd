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

## 通关状态标记与卡牌发放（[code]is_first_clear[/code] / [code]clear_count[/code]
## 同一次写入；卡牌走既有发放器）。
const MapClear := preload("res://src/feature/exploration/exploration_map_clear.gd")
## 结算面板的视图组装（含「下一张去哪」的求值——与发奖分开，见该类文档）。
const ClearReport := preload("res://src/feature/exploration/exploration_clear_report.gd")

## 通关基础奖励的修为来源标记（[code]summary[/code] 与存档审计读它）。
const SOURCE_CLEAR: String = "map_clear"
## 首通额外奖励的来源标记——与基础奖励分开，统计里能看出「这份是首通彩头」。
const SOURCE_FIRST_CLEAR: String = "map_first_clear"


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
## [b]结算路径[/b]:[br]
## [br]BOSS_DEFEATED → 通关奖励（基础 + 首通额外，含卡牌）+ collected_* 全额转移[br]
## [br]BATTLE_LOST → collected_ling_shi 全额转移，collected_cultivation 保留 50%[br]
## [br]AP_DEPLETED / PLAYER_QUIT → collected_* 全额转移[br]
## [br][b]流程[/b]: _flush_map_state → clear_exploration_navigation → clear_dag_cache。[br]
## [br][b]返回值即结算摘要[/b]：BOSS_DEFEATED 时额外带 [code]is_first_clear[/code] /
## [code]clear_count[/code] / [code]first_clear[/code] / [code]cards[/code] /
## [code]cards_failed[/code]——[code]exploration_ended[/code] 的载荷就是它，UI/统计
## 不必再回读存档。[br]
## [br]来源: ADR-0014 §决策 5 + GDD §公式 11、GDD exploration-system.md §5、
## GDD exploration-ui-system.md §7。
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
			_settle_boss_defeated(gsm, current_map, summary)
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


# === 通关结算（BOSS_DEFEATED 分支）==========================================

## 通关结算——标记通关 + 发基础奖励 + 发首通额外奖励 + 备好结算面板的视图。[br]
## [br][b]顺序[/b]：先 [method ExplorationMapClear.mark_cleared] 拿到
## 「本次是否为首次」，再按这个结果算奖励——[code]calculate_map_clear_rewards[/code]
## 的 [code]is_first_clear[/code] 入参就是它。反过来先算奖励再标记，会永远算成首通。[br]
## [br][b]基础与首通分批发放[/b]：结算面板要把两段分开画（GDD §7 首通行独立高亮），
## 合并成一批后无从区分哪张卡是首通彩头（见 [ExplorationMapClear] 类文档）。[br]
## [br][b]重复通关不发卡[/b]：首通档位表是首通专属，重复通关的
## [code]extra[/code] 根本不存在（[code]calculate_map_clear_rewards[/code] 只在
## [code]is_first_clear[/code] 时塞这个键）——「不发稀有奖励」由这一条保证，
## 不是靠发放侧再判一次。[br]
## [br][b]结算视图一定发布[/b]（含重复通关）：面板据此显示「地图通关！+ 通关奖励」，
## 只是没有首通行；不发布的话重复通关的玩家点完 Boss 什么反馈都没有。[br]
## [br][param p_gsm] GSM（非空——调用方已守卫）。[br]
## [param p_map_id] 当前地图 ID。[br]
## [param p_summary] 结算摘要（就地补键——调用方返回它）。
func _settle_boss_defeated(p_gsm: Node, p_map_id: StringName,
		p_summary: Dictionary) -> void:
	var clearer: RefCounted = MapClear.new(_parent)
	var mark: Dictionary = clearer.call(&"mark_cleared", p_map_id, p_gsm)
	var is_first: bool = bool(mark.get("is_first_clear", true))
	var clear_count: int = int(mark.get("clear_count", 1))

	var player_realm: int = _get_player_realm()
	var map_max_realm: int = _get_map_max_realm(p_map_id)
	var rewards: Dictionary = _parent.call("calculate_map_clear_rewards",
			p_map_id, is_first, player_realm, map_max_realm)
	var extra: Dictionary = _extra_rewards(rewards)

	# 基础奖励——灵石 + 修为（卡牌清单由地图配置给，出厂为空）
	_grant_ling_shi(p_gsm, int(rewards.get("ling_shi", 0)))
	_grant_cultivation(p_gsm, int(rewards.get("cultivation", 0)), SOURCE_CLEAR)
	# 首通额外奖励——灵石 + 修为 + 卡牌（重复通关时 extra 为 {}，三项皆 0）
	var first_ling_shi: int = int(extra.get("ling_shi", 0))
	var first_cultivation: int = int(extra.get("cultivation", 0))
	_grant_ling_shi(p_gsm, first_ling_shi)
	_grant_cultivation(p_gsm, first_cultivation, SOURCE_FIRST_CLEAR)

	# 卡牌——基础一批、首通一批（顺序即配置顺序）
	var base_cards: Dictionary = clearer.call(&"grant_cards",
			MapClear.cards_of(rewards), p_gsm)
	var first_cards: Dictionary = clearer.call(&"grant_cards",
			MapClear.cards_of(extra), p_gsm)

	p_summary["rewards"] = rewards
	p_summary["is_first_clear"] = is_first
	p_summary["clear_count"] = clear_count
	p_summary["first_clear"] = extra
	p_summary["cards"] = base_cards.get("cards", [])
	p_summary["cards_failed"] = base_cards.get("cards_failed", []) \
			+ first_cards.get("cards_failed", [])

	# 转移已收集资源（在通关奖励之后——两者都加在 player.* 上，顺序不影响总额）
	_flush_map_state(p_map_id)

	# 备好结算面板的视图（跨场景缓存——面板在场景切换之后才挂载）。
	# 「下一张去哪」的求值在报告模块（读探明表 × 境界 × 已通关集合），与发奖分开。
	ClearReport.publish(p_gsm, p_map_id, is_first, clear_count, rewards, extra,
			base_cards, first_cards)


## 首通额外奖励——重复通关时 [code]rewards[/code] 里没有 [code]extra[/code] 键
## （[code]calculate_map_clear_rewards[/code] 只在首通时塞），返回空字典。
func _extra_rewards(p_rewards: Dictionary) -> Dictionary:
	var raw: Variant = p_rewards.get("extra", {})
	return raw if raw is Dictionary else {}


## 灵石入账——非正数不写（避免一次无意义的 GSM 变更广播）。
func _grant_ling_shi(p_gsm: Node, p_amount: int) -> void:
	if p_amount <= 0:
		return
	var current: int = int(p_gsm.player.resources.get("ling_shi", 0))
	p_gsm._set_resource_ling_shi(current + p_amount)


## 修为入账——非正数不写；[param p_source] 进存档审计（区分基础与首通）。
func _grant_cultivation(p_gsm: Node, p_amount: int, p_source: String) -> void:
	if p_amount <= 0:
		return
	p_gsm.add_cultivation(p_amount, p_source)


## 地图中文名——[b]已随视图组装迁到 [code]exploration_clear_report.gd[/code][/b]
## （[code]ExplorationMapGate.map_display_name[/code] 是登记名读取的唯一实现）。
## 此处曾有一份同口径的副本，与探明表读取重复——删掉免得两处漂移。


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
