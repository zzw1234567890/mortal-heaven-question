extends RefCounted
## CombatRewards —— 战斗奖励的掷骰 / 持久化 / 发放 + 奖励 RNG 播种（从 combat_system.gd 拆分）。[br]
## [br][b]职责边界[/b]：[br]
##   1. [b]掷骰[/b]：胜利时按开战配置 [code]rewards[/code] 掷灵石区间与卡牌掉落；
##      [b]只掷不发[/b]（结果暂存，等 UI 选择）；[br]
##   2. [b]持久化[/b]：掷骰结果写进 [code]GSM.battle.rolled_rewards[/code]——结算面板
##      与读档都要能看到同一份；[br]
##   3. [b]发放[/b]：玩家选定后的入账（灵石 / 修为 / 选定卡牌）；[br]
##   4. [b]奖励 RNG[/b]：播种口径与显式种子 / 注入实例的优先级。[br]
## [br][b]状态归属[/b]（ADR-0008 §状态单一所有者）：[code]_rolled_rewards[/code] /
## [code]_reward_rng[/code] / [code]_reward_rng_explicit[/code] /
## [code]_reward_battle_count[/code] / [code]_battle_serial[/code] /
## [code]_rewards_settled_for[/code] / [code]_battle_config[/code] 七个字段都留在父节点，
## 本模块只经 [code]_parent.get/set[/code] 读写、不自持副本——测试会直接
## [code]cs.set("_rolled_rewards", ...)[/code] 与 [code]cs.set("_battle_config", ...)[/code]
## 注入夹具，字段搬走会让这些既有路径全断。[br]
## [br][b]为什么拆出来[/b]：这一组逻辑只读写父节点少量状态、与阶段推进 / 出牌结算无交集，
## 却是 [code]combat_system.gd[/code] 里最长的一段（17 个方法 / 约 150 行）。拆出后父节点
## 只保留同名薄转发（先例 [code]combat_phase_manager.gd[/code] /
## [code]combat_battle_wiring.gd[/code]）。[br]
## [br]来源: ADR-0008 §生命周期、GDD combat-system.md §9、tech-debt DEBT-CBT-018-3。

## 结局常量——本模块只判「是不是胜利」，不依赖父节点枚举（同
## [code]combat_phase_manager.gd[/code] 的 [code]PHASE_*[/code] 先例；数值与
## [enum CombatSystem.CombatResult.VICTORY] 同源）。
const RESULT_VICTORY: int = 1

## 战斗奖励的掷骰与发放（灵石区间 / 卡牌概率——全场唯一实现）。
const RewardRoller := preload("res://src/feature/combat/combat_reward_roller.gd")

## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 奖励 RNG ====================================================================

## 设置[b]奖励掷骰[/b]的种子（确定性测试用）。[br]
## [br][b]与父节点 [method CombatSystem.set_rng_seed] 分开[/b]：洗牌流的消耗次数随对局
## 走向变化，共用一条流会让「固定种子 → 固定掉落」不成立。[br]
## [br][b]调用后本场及后续各场都不再自动播种[/b]（显式种子优先）；调用
## [method set_reward_rng] 注入实例同样视为显式。[br]
## [br][b]生产自动播种口径[/b]（[method CombatSystem.battle_start]）：[br]
##   [code]reward_seed = GSM.meta.seed + 本进程已开战场数[/code]——同一存档的
##   第一场、第二场……结果各自可复现，且不会两场共用同一串随机数；
##   GSM / meta.seed 缺失时用 [code]本进程已开战场数[/code] 起步（仍可复现，
##   只是不再跨存档对齐）。[br]
## [br][b]一次胜利会消耗的随机数[/b]：灵石区间掷 1 次 [code]randi_range[/code]
## （仅当配置了 [code]lingshi_min/max[/code]）；随后每张 [code]0 < chance < 1[/code]
## 的卡牌掷 1 次 [code]randf()[/code]，顺序与配置数组一致（[code]chance >= 1[/code] /
## [code]<= 0[/code] 与缺 [code]chance[/code] 的条目都不消耗）。
func set_reward_rng_seed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = _parent.get("_reward_rng")
	rng.seed = seed_value
	_parent.set("_reward_rng_explicit", true)


## 注入奖励掷骰 RNG 实例（测试用——自行决定种子与推进方式）。[br]
## [br]注入后 [method CombatSystem.battle_start] 不再自动播种，直到 [method reset_reward_rng]。
func set_reward_rng(p_rng: RandomNumberGenerator) -> void:
	_parent.set("_reward_rng",
			p_rng if p_rng != null else RandomNumberGenerator.new())
	_parent.set("_reward_rng_explicit", p_rng != null)


## 恢复自动播种（注入 / 显式种子之后的复位入口——测试隔离用）。
func reset_reward_rng() -> void:
	_parent.set("_reward_rng", RandomNumberGenerator.new())
	_parent.set("_reward_rng_explicit", false)
	_parent.set("_reward_battle_count", 0)


## 本场奖励掷骰播种——每开一场推进一步（见 [method set_reward_rng_seed]）。[br]
## [br][b]显式种子 / 注入实例优先[/b]：测试设过种子后不被开战覆盖，
## 否则「固定种子」的口径在第二场就断了。
func seed_reward_rng() -> void:
	var count: int = int(_parent.get("_reward_battle_count")) + 1
	_parent.set("_reward_battle_count", count)
	if bool(_parent.get("_reward_rng_explicit")):
		return
	var rng: RandomNumberGenerator = _parent.get("_reward_rng")
	rng.seed = _reward_seed_base() + count


## 自动播种基数——[code]GSM.meta.seed[/code]（缺失 / 类型不符时为 0）。[br]
## [br][b]为什么要全局种子参与[/b]：不同存档（不同轮次）应得到不同掉落；
## 同一存档内按开战场数递增，保证各场互不相同且可复现。
func _reward_seed_base() -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	var meta: Variant = gsm.get("meta")
	if not (meta is Dictionary):
		return 0
	return int((meta as Dictionary).get("seed", 0))


# === 结算 ========================================================================

## 战斗结果结算——按 VICTORY / DEFEAT / RETREAT 分支。[br]
## [br]Sprint 8 Story 005 接线——通过 ResourceSystem / CultivationSystem 派生奖励。[br]
## [br][b]胜利时[/b]：只掷骰不发放，结果存 [code]_rolled_rewards[/code] 并持久化到
## GSM battle 字段；[br]
## [b]失败 / 撤退时[/b]：不发奖、不掷骰，只带 retain_ratio。[br]
## [br][b]返回[/b]: rewards Dictionary。
func settle_result(result: int) -> Dictionary:
	var rewards: Dictionary = {"result": result}
	if result != RESULT_VICTORY:
		# 失败/撤退——保留 50% 资源（不发奖、不掷骰）
		rewards["retain_ratio"] = 0.5
		return rewards
	# 幂等守卫：同一场重复调用不再掷骰、不再发放
	if is_rewards_settled():
		rewards["grant_skipped"] = true
		return rewards
	mark_rewards_settled()
	# 胜利时只掷骰不发放
	var rng: RandomNumberGenerator = _parent.get("_reward_rng")
	var rolled: Dictionary = RewardRoller.roll(configured_rewards(), rng)
	# 未命中条目也要带展示名/稀有度——结算界面要说明「没抽到什么」
	RewardRoller.enrich(rolled.get("cards_missed", []), _get_card_system())
	# 存入内部状态
	_parent.set("_rolled_rewards", rolled.duplicate(true))
	# 持久化到 GSM battle 字段
	persist_rolled_rewards(rolled)
	# 返回掷骰结果（不含发放标记，因为还没发放）
	rewards.merge(rolled, true)
	return rewards


## 本场是否已结算过奖励（重复 [method CombatSystem.battle_end] 的幂等守卫）。[br]
## [br][b]没开过战不参与守卫[/b]：序号为 0 说明没有「场」的概念（测试桩、
## 直接调 [method CombatSystem.battle_end] 的旧用例），重复调用照常走结算——
## 此时掉落本身也是空的。[br]
## [br][b]已结束的场次直接调 [method settle_result] 也算重复[/b]：[code]_battle_config[/code]
## 在战斗结束后不清（旧口径），比对序号正是为了不让「上一场的配置」被再发一次。
func is_rewards_settled() -> bool:
	var serial: int = int(_parent.get("_battle_serial"))
	return serial != 0 and int(_parent.get("_rewards_settled_for")) == serial


## 标记本场已结算——记下当前开战序号；下一场 [method CombatSystem.battle_start]
## 递增后自然失效。
func mark_rewards_settled() -> void:
	_parent.set("_rewards_settled_for", int(_parent.get("_battle_serial")))


# === 持久化（GSM.battle.rolled_rewards）==========================================

## 持久化已掷骰奖励到 GSM battle 字段——供 UI 选择时读取。
func persist_rolled_rewards(p_rolled: Dictionary) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method(&"set"):
		push_warning("CombatSystem: GSM 不可用，奖励掷骰结果无法持久化")
		return
	if gsm.battle == null:
		gsm.battle = {}
	var battle: Dictionary = gsm.battle
	battle["rolled_rewards"] = p_rolled.duplicate(true)
	gsm.set("battle", battle)


## 从 GSM battle 字段读取已掷骰奖励——供 [method grant_reward_selection] 使用。
func load_rolled_rewards() -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null or gsm.battle == null:
		return {}
	var battle: Dictionary = gsm.battle
	return battle.get("rolled_rewards", {})


## 清空 GSM battle 字段中的 rolled_rewards——发放后调用。
func clear_rolled_rewards_from_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or gsm.battle == null:
		return
	var battle: Dictionary = gsm.battle
	battle.erase("rolled_rewards")
	gsm.set("battle", battle)


# === 发放 ========================================================================

## 奖励选择发放——index>=0 发灵石+修为+该张卡，index<0 只发灵石+修为。[br]
## [br]发放后清空 [code]_rolled_rewards[/code]（重复调用返回 no_rolled_rewards
## 且不重复发奖）。[br]
## [br][param index] 卡牌索引（>=0 选择该卡，<0 跳过卡牌）。[br]
## [br][b]返回[/b]: [code]{no_rolled_rewards, lingshi_granted, cultivation_granted,
## cards, cards_failed}[/code]——no_rolled_rewards=true 表示已发放或无掷骰结果。
func grant_reward_selection(index: int) -> Dictionary:
	var result: Dictionary = {"no_rolled_rewards": true}
	# 幂等守卫：已清空或无掷骰结果
	var rolled: Dictionary = _parent.get("_rolled_rewards")
	if rolled.is_empty():
		var loaded: Dictionary = load_rolled_rewards()
		if loaded.is_empty():
			return result
		rolled = loaded.duplicate(true)
		_parent.set("_rolled_rewards", rolled)
	if rolled.is_empty():
		return result

	# 准备发放内容——灵石和修为始终发放，卡牌按 index 选择
	var to_grant: Dictionary = rolled.duplicate(true)
	var cards: Array = to_grant.get("cards", [])
	var selected_cards: Array = []

	if index >= 0 and index < cards.size():
		# 选择指定卡牌
		selected_cards.append(cards[index])
	else:
		# 跳过卡牌
		selected_cards = []

	to_grant["cards"] = selected_cards

	# 发放
	var granted: Dictionary = RewardRoller.apply(to_grant, _get_resource_system(),
			_get_cultivation_system(), _get_card_system(), _get_gsm())

	# 清空掷骰结果（幂等）——[b]就地清空[/b]：读者可能已经持有同一份引用的别名，
	# 换成新字典会让那个别名继续看到未发放的旧内容
	rolled.clear()
	clear_rolled_rewards_from_gsm()

	# 返回发放结果
	result["no_rolled_rewards"] = false
	result["lingshi_granted"] = bool(granted.get("lingshi_granted", true))
	result["cultivation_granted"] = bool(granted.get("cultivation_granted", true))
	result["cards"] = granted.get("cards", [])
	result["cards_failed"] = granted.get("cards_failed", [])
	return result


# === 配置读取（开战 config.rewards）==============================================

## 开战配置里的掉落字典（缺失 / 类型不符时为空——结算侧按 0 / 空处理）。
func configured_rewards() -> Dictionary:
	var config: Variant = _parent.get("_battle_config")
	if not (config is Dictionary):
		return {}
	var raw: Variant = (config as Dictionary).get("rewards", {})
	return raw if raw is Dictionary else {}


## 计算灵石奖励——[b]由开战配置的 [code]rewards[/code] 决定[/b]（探索节点掉落）。[br]
## [br][b]为什么读配置而不是现算[/b]：掉落属于「哪一格打哪一批人、给什么」的
## 探索侧数据（[code]combat_launch_context.gd[/code] 在节点生成时定档）；战斗系统
## 只负责结算，不重复一套掉落表。配置缺失时为 0（不臆造奖励）。[br]
## [br][b]这是预览值[/b]：配置了区间时返回区间中值；实得值见 [method settle_result]
## 掷骰后的 [code]rewards.lingshi[/code]（两者在结算面板上都有展示口径）。[br]
## [br][b]为什么区间也要兜底[/b]：探索侧经 [code]EncounterFields[/code] 写出的配置
## 同时带中值与区间，但手写配置可能只给区间——只读 [code]lingshi[/code] 会让预览恒为 0，
## 与实得对不上。
func calculate_lingshi_reward() -> int:
	var rewards: Dictionary = configured_rewards()
	if rewards.has("lingshi"):
		return maxi(int(rewards.get("lingshi", 0)), 0)
	if rewards.has("lingshi_min") or rewards.has("lingshi_max"):
		var lo: int = maxi(int(rewards.get("lingshi_min", 0)), 0)
		var hi: int = maxi(int(rewards.get("lingshi_max", 0)), 0)
		return int(round((float(lo) + float(hi)) * 0.5))
	return 0


## 计算修为奖励——同上，读开战配置 [code]rewards.cultivation[/code]。
func calculate_cultivation_reward() -> int:
	return maxi(configured_rewards().get("cultivation", 0), 0)


## 计算卡牌掉落配置——读开战配置 [code]rewards.cards[/code]（字典列表深拷贝）。[br]
## [br][b]返回的是配置清单，不是实得[/b]：每项 [code]{card_id, chance}[/code]
## 是否到手由 [method settle_result] 的掷骰决定。
func calculate_card_drops() -> Array:
	var raw: Variant = configured_rewards().get("cards", [])
	if not (raw is Array):
		return []
	return (raw as Array).duplicate(true)


## 应用胜利奖励——[b]保留为公开测试接缝[/b]（旧测试直调它验证资源写入）。[br]
## [br][b]生产路径不再走这里[/b]：结算改由 [constant RewardRoller] 统一掷骰 + 发放
## （灵石 / 修为 / 卡牌三者在同一处），本方法只做「金额已知时发一笔」的兼容入口。
func apply_victory_rewards(rewards: Dictionary) -> void:
	var lingshi: int = int(rewards.get("lingshi", 0))
	if lingshi > 0:
		var rs: Node = _get_resource_system()
		if rs != null and rs.has_method("add_resource"):
			rs.add_resource(&"ling_shi", lingshi)
	var cultivation: int = int(rewards.get("cultivation", 0))
	if cultivation > 0:
		var cs: Node = _get_cultivation_system()
		if cs != null and cs.has_method("gain_cultivation"):
			cs.gain_cultivation(cultivation, "battle_victory")


# === Autoload 查找（子模块内自用）================================================

## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。[br]
## [br][b]口径同 [code]combat_autoload_access.gd[/code][/b]：那边的静态查找器尚未被本模块
## 采用，是为了让 P1 只搬实现面、不动查找方式；后续阶段统一时改这一处即可。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))


func _get_gsm() -> Node:
	return _autoload(&"GameStateManager")


func _get_resource_system() -> Node:
	return _autoload(&"ResourceSystem")


func _get_cultivation_system() -> Node:
	return _autoload(&"CultivationSystem")


func _get_card_system() -> Node:
	return _autoload(&"CardSystem")
