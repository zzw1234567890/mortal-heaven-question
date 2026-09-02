class_name AchievementSystem
extends RefCounted
## AchievementSystem —— 成就系统（RefCounted 服务类，ADR-0012）。
##
## Feature 层 RefCounted（非 Autoload）。持有 62 个成就定义的 const Dictionary，
## 初始化时注册到 ProgressionSystem。提供成就定义查询 API。[br]
## [br]来源: GDD achievement-system.md §1~§3 + ADR-0012 §achievements 领域。


# === 成就分类枚举 ============================================================

const CATEGORY_COMBAT: String = "combat"
const CATEGORY_PROGRESSION: String = "progression"
const CATEGORY_COLLECTION: String = "collection"
const CATEGORY_EXPLORATION: String = "exploration"
const CATEGORY_NARRATIVE: String = "narrative"
const CATEGORY_MASTERY: String = "mastery"
const CATEGORY_CHALLENGE: String = "challenge"


# === 62 个成就定义 ===========================================================

const ACHIEVEMENT_DEFS: Dictionary = {
	# --- 战斗成就 (Combat) —— 12 个 ---
	"ach_first_elite_kill": {"id": "ach_first_elite_kill", "name": "初出茅庐", "description": "首次击杀精英敌人", "category": "combat", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "elite_defeated", "threshold": 1}},
	"ach_elite_hunter": {"id": "ach_elite_hunter", "name": "精英猎手", "description": "累计击杀 50 个精英敌人", "category": "combat", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "elite_defeated", "threshold": 50}},
	"ach_elite_slayer": {"id": "ach_elite_slayer", "name": "精英屠夫", "description": "累计击杀 200 个精英敌人", "category": "combat", "tier": "gold", "points": 20, "hidden_until_unlocked": false, "unlock_condition": {"event": "elite_defeated", "threshold": 200}},
	"ach_first_boss_kill": {"id": "ach_first_boss_kill", "name": "弑师", "description": "首次击杀章末 BOSS", "category": "combat", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "boss_defeated", "threshold": 1}},
	"ach_all_bosses": {"id": "ach_all_bosses", "name": "八荒荡魔", "description": "击杀全部 5 个章末 BOSS", "category": "combat", "tier": "gold", "points": 25, "hidden_until_unlocked": false, "unlock_condition": {"event": "all_bosses_defeated", "threshold": 5}},
	"ach_no_damage_boss": {"id": "ach_no_damage_boss", "name": "枯木逢春", "description": "无伤击败任意章末 BOSS", "category": "combat", "tier": "gold", "points": 20, "hidden_until_unlocked": true, "unlock_condition": {"event": "boss_no_damage", "threshold": 1}},
	"ach_one_turn_kill": {"id": "ach_one_turn_kill", "name": "一击灭敌", "description": "在 1 回合内击杀任意 BOSS", "category": "combat", "tier": "gold", "points": 25, "hidden_until_unlocked": true, "unlock_condition": {"event": "boss_one_turn_kill", "threshold": 1}},
	"ach_status_stack_5": {"id": "ach_status_stack_5", "name": "五毒俱全", "description": "单个敌人身上同时拥有 5+ 种不同异常状态", "category": "combat", "tier": "silver", "points": 10, "hidden_until_unlocked": true, "unlock_condition": {"event": "status_stack_reached", "threshold": 5}},
	"ach_overkill_100": {"id": "ach_overkill_100", "name": "伤害溢出", "description": "单次攻击造成超过 100 点溢出伤害", "category": "combat", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "overkill_dealt", "threshold": 100}},
	"ach_first_formation_trigger": {"id": "ach_first_formation_trigger", "name": "阵法初成", "description": "首次触发阵法效果", "category": "combat", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "formation_triggered", "threshold": 1}},
	"ach_formation_master": {"id": "ach_formation_master", "name": "阵法大师", "description": "一局游戏中触发过全部已拥有阵法的效果", "category": "combat", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "all_formations_triggered", "threshold": 1}},
	"ach_deploy_6": {"id": "ach_deploy_6", "name": "六合归一", "description": "同时上场 6 个角色", "category": "combat", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "deploy_count_reached", "threshold": 6}},

	# --- 成长成就 (Progression) —— 10 个 ---
	"ach_first_realm_break": {"id": "ach_first_realm_break", "name": "踏入道途", "description": "首次突破到筑基期", "category": "progression", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "realm_upgraded", "threshold": 2}},
	"ach_realm_golden_core": {"id": "ach_realm_golden_core", "name": "金丹大成", "description": "首次突破到金丹期", "category": "progression", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "realm_upgraded", "threshold": 3}},
	"ach_realm_nascent_soul": {"id": "ach_realm_nascent_soul", "name": "元婴出世", "description": "首次突破到元婴期", "category": "progression", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "realm_upgraded", "threshold": 4}},
	"ach_realm_deity": {"id": "ach_realm_deity", "name": "半步飞升", "description": "首次突破到化神期", "category": "progression", "tier": "gold", "points": 20, "hidden_until_unlocked": false, "unlock_condition": {"event": "realm_upgraded", "threshold": 5}},
	"ach_first_tribulation": {"id": "ach_first_tribulation", "name": "天劫降临", "description": "首次完成渡劫突破", "category": "progression", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "tribulation_completed", "threshold": 1}},
	"ach_transcend_tribulation": {"id": "ach_transcend_tribulation", "name": "越阶渡劫", "description": "在修为未满 80% 时成功渡劫", "category": "progression", "tier": "gold", "points": 20, "hidden_until_unlocked": true, "unlock_condition": {"event": "tribulation_low_cultivation", "threshold": 1}},
	"ach_tribulation_no_hp_loss": {"id": "ach_tribulation_no_hp_loss", "name": "天劫无伤", "description": "渡劫战中 HP 从未低于 50%", "category": "progression", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "tribulation_no_hp_loss", "threshold": 1}},
	"ach_cultivation_overflow": {"id": "ach_cultivation_overflow", "name": "修为如海", "description": "跨局累计修为溢出转化≥10 次", "category": "progression", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "cultivation_overflow_converted", "threshold": 10}},
	"ach_action_points_max": {"id": "ach_action_points_max", "name": "行遍天下", "description": "单局行动力上限达到最大值", "category": "progression", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "action_points_maxed", "threshold": 13}},
	"ach_reincarnation_10": {"id": "ach_reincarnation_10", "name": "轮回百转", "description": "累计轮回 10 次", "category": "progression", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "total_reincarnations", "threshold": 10}},

	# --- 收集成就 (Collection) —— 10 个 ---
	"ach_cards_50": {"id": "ach_cards_50", "name": "初涉卡道", "description": "图鉴中收录 50 种卡牌", "category": "collection", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "cards_discovered", "threshold": 50}},
	"ach_cards_100": {"id": "ach_cards_100", "name": "百卡争鸣", "description": "图鉴中收录 100 种卡牌", "category": "collection", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "cards_discovered", "threshold": 100}},
	"ach_cards_200": {"id": "ach_cards_200", "name": "万法归藏", "description": "图鉴中收录 200 种卡牌", "category": "collection", "tier": "gold", "points": 20, "hidden_until_unlocked": false, "unlock_condition": {"event": "cards_discovered", "threshold": 200}},
	"ach_cards_all": {"id": "ach_cards_all", "name": "仙途问道", "description": "图鉴中收录全部 222 张卡牌", "category": "collection", "tier": "gold", "points": 30, "hidden_until_unlocked": false, "unlock_condition": {"event": "cards_discovered", "threshold": 222}},
	"ach_first_dark_gold": {"id": "ach_first_dark_gold", "name": "暗金初现", "description": "首次获得暗金品质卡牌", "category": "collection", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "first_dark_gold", "threshold": 1}},
	"ach_dark_gold_5": {"id": "ach_dark_gold_5", "name": "五行暗金", "description": "图鉴中拥有 5 张不同暗金卡牌", "category": "collection", "tier": "gold", "points": 20, "hidden_until_unlocked": false, "unlock_condition": {"event": "dark_gold_count", "threshold": 5}},
	"ach_ling_shi_10000": {"id": "ach_ling_shi_10000", "name": "富甲一方", "description": "单局灵石累计消费≥5000", "category": "collection", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "ling_shi_spent", "threshold": 5000}},
	"ach_alchemy_50": {"id": "ach_alchemy_50", "name": "丹道宗师", "description": "累计完成 50 次炼丹", "category": "collection", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "alchemy_count", "threshold": 50}},
	"ach_craft_50": {"id": "ach_craft_50", "name": "炼器宗师", "description": "累计完成 50 次炼器", "category": "collection", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "craft_count", "threshold": 50}},
	"ach_inscription_20": {"id": "ach_inscription_20", "name": "铭文大师", "description": "累计完成 20 次法宝铭刻", "category": "collection", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "inscription_count", "threshold": 20}},

	# --- 探索成就 (Exploration) —— 8 个 ---
	"ach_all_maps_ch1": {"id": "ach_all_maps_ch1", "name": "青云剑宗全境", "description": "第 1 章全部地图均通关", "category": "exploration", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "maps_cleared_ch1", "threshold": 4}},
	"ach_all_maps_all": {"id": "ach_all_maps_all", "name": "踏遍九州", "description": "全部 18 张地图均通关", "category": "exploration", "tier": "gold", "points": 20, "hidden_until_unlocked": false, "unlock_condition": {"event": "maps_cleared_all", "threshold": 18}},
	"ach_secret_room": {"id": "ach_secret_room", "name": "别有洞天", "description": "首次发现隐藏房间", "category": "exploration", "tier": "silver", "points": 10, "hidden_until_unlocked": true, "unlock_condition": {"event": "secret_room_found", "threshold": 1}},
	"ach_event_100": {"id": "ach_event_100", "name": "阅历丰富", "description": "累计触发 100 个事件", "category": "exploration", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "events_triggered", "threshold": 100}},
	"ach_all_events_map": {"id": "ach_all_events_map", "name": "一地洞悉", "description": "单张地图触发全部可能事件", "category": "exploration", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "all_events_single_map", "threshold": 1}},
	"ach_no_damage_map": {"id": "ach_no_damage_map", "name": "闲庭信步", "description": "一张地图全程未触发战斗", "category": "exploration", "tier": "silver", "points": 10, "hidden_until_unlocked": true, "unlock_condition": {"event": "no_battle_map", "threshold": 1}},
	"ach_map_full_clear": {"id": "ach_map_full_clear", "name": "扫荡一空", "description": "清空一张地图全部节点", "category": "exploration", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "map_full_clear", "threshold": 1}},
	"ach_node_50_single_run": {"id": "ach_node_50_single_run", "name": "行者无疆", "description": "单局累计访问 50 个节点", "category": "exploration", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "nodes_visited_single_run", "threshold": 50}},

	# --- 叙事成就 (Narrative) —— 8 个 ---
	"ach_chapter_1_clear": {"id": "ach_chapter_1_clear", "name": "青云入世", "description": "首次通关第 1 章", "category": "narrative", "tier": "bronze", "points": 5, "hidden_until_unlocked": false, "unlock_condition": {"event": "chapter_cleared", "threshold": 1}},
	"ach_chapter_3_clear": {"id": "ach_chapter_3_clear", "name": "苍玄之争", "description": "首次通关第 3 章", "category": "narrative", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "chapter_cleared", "threshold": 3}},
	"ach_chapter_5_clear": {"id": "ach_chapter_5_clear", "name": "归墟探索", "description": "首次通关第 5 章", "category": "narrative", "tier": "gold", "points": 20, "hidden_until_unlocked": false, "unlock_condition": {"event": "chapter_cleared", "threshold": 5}},
	"ach_ending_ascension": {"id": "ach_ending_ascension", "name": "飞升仙界", "description": "解锁飞升仙界结局线", "category": "narrative", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "ending_unlocked", "threshold": 1, "extra": "ascend"}},
	"ach_ending_guardian": {"id": "ach_ending_guardian", "name": "归墟守护", "description": "解锁留在归墟结局线", "category": "narrative", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "ending_unlocked", "threshold": 1, "extra": "guard"}},
	"ach_ending_return": {"id": "ach_ending_return", "name": "归乡之人", "description": "解锁归隐东域结局线", "category": "narrative", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "ending_unlocked", "threshold": 1, "extra": "return"}},
	"ach_all_endings": {"id": "ach_all_endings", "name": "超凡入圣", "description": "解锁全部 6 个结局", "category": "narrative", "tier": "gold", "points": 30, "hidden_until_unlocked": false, "unlock_condition": {"event": "all_endings_unlocked", "threshold": 6}},
	"ach_story_flag_30": {"id": "ach_story_flag_30", "name": "因果交织", "description": "跨局累计收集 25 个 story_flag", "category": "narrative", "tier": "gold", "points": 20, "hidden_until_unlocked": true, "unlock_condition": {"event": "story_flags_collected", "threshold": 25}},

	# --- 精通成就 (Mastery) —— 8 个 ---
	"ach_school_win_zhengdao": {"id": "ach_school_win_zhengdao", "name": "正道砥柱", "description": "使用正道发育流通关", "category": "mastery", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "school_win", "threshold": 1, "extra": "zhengdao"}},
	"ach_school_win_modao": {"id": "ach_school_win_modao", "name": "魔道至尊", "description": "使用魔道快攻流通关", "category": "mastery", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "school_win", "threshold": 1, "extra": "modao"}},
	"ach_school_win_hybrid": {"id": "ach_school_win_hybrid", "name": "正邪兼修", "description": "使用正邪混合流通关", "category": "mastery", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "school_win", "threshold": 1, "extra": "hybrid"}},
	"ach_school_win_spirit": {"id": "ach_school_win_spirit", "name": "真灵之主", "description": "使用归墟真灵流通关", "category": "mastery", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "school_win", "threshold": 1, "extra": "spirit"}},
	"ach_school_win_alchemy": {"id": "ach_school_win_alchemy", "name": "百艺宗师", "description": "使用百艺炼丹流通关", "category": "mastery", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "school_win", "threshold": 1, "extra": "alchemy"}},
	"ach_all_schools": {"id": "ach_all_schools", "name": "万法归宗", "description": "全部 5 种流派各通关 1 次", "category": "mastery", "tier": "gold", "points": 25, "hidden_until_unlocked": false, "unlock_condition": {"event": "all_schools_won", "threshold": 5}},
	"ach_identity_win_3": {"id": "ach_identity_win_3", "name": "三生万物", "description": "使用 3 种不同身份各通关 1 次", "category": "mastery", "tier": "silver", "points": 10, "hidden_until_unlocked": false, "unlock_condition": {"event": "identity_wins", "threshold": 3}},
	"ach_deck_minimal": {"id": "ach_deck_minimal", "name": "极简之道", "description": "使用不超过 25 张卡牌通关", "category": "mastery", "tier": "gold", "points": 20, "hidden_until_unlocked": true, "unlock_condition": {"event": "minimal_deck_win", "threshold": 25}},

	# --- 挑战成就 (Challenge) —— 6 个 ---
	"ach_speed_run": {"id": "ach_speed_run", "name": "元婴速通", "description": "在 2 小时内通关", "category": "challenge", "tier": "gold", "points": 20, "hidden_until_unlocked": false, "unlock_condition": {"event": "speed_run", "threshold": 7200}},
	"ach_no_talent_win": {"id": "ach_no_talent_win", "name": "凡人之躯", "description": "不激活任何轮回天赋通关", "category": "challenge", "tier": "gold", "points": 25, "hidden_until_unlocked": false, "unlock_condition": {"event": "no_talent_win", "threshold": 1}},
	"ach_no_shop": {"id": "ach_no_shop", "name": "自给自足", "description": "一局从未在商店购买物品", "category": "challenge", "tier": "silver", "points": 10, "hidden_until_unlocked": true, "unlock_condition": {"event": "no_shop_run", "threshold": 1}},
	"ach_no_death": {"id": "ach_no_death", "name": "不死不灭", "description": "一局所有角色从未阵亡", "category": "challenge", "tier": "gold", "points": 25, "hidden_until_unlocked": false, "unlock_condition": {"event": "no_death_run", "threshold": 1}},
	"ach_realm_1_boss": {"id": "ach_realm_1_boss", "name": "以凡弑仙", "description": "以炼气期击败第 1 章章末 BOSS", "category": "challenge", "tier": "gold", "points": 25, "hidden_until_unlocked": true, "unlock_condition": {"event": "low_realm_boss_kill", "threshold": 1}},
	"ach_win_rate_100": {"id": "ach_win_rate_100", "name": "百战百胜", "description": "通关一局中胜率 100%", "category": "challenge", "tier": "gold", "points": 25, "hidden_until_unlocked": false, "unlock_condition": {"event": "perfect_win_rate", "threshold": 100}},
}

## ProgressionSystem 引用——测试注入优先。
static var _progression_override: Node = null


# === 初始化 =================================================================

## 初始化——将 62 个成就定义注册到 ProgressionSystem。
static func initialize() -> void:
	var ps: Node = _get_progression_system()
	if ps == null:
		return
	for ach_id: String in ACHIEVEMENT_DEFS:
		var def: Dictionary = ACHIEVEMENT_DEFS[ach_id]
		var threshold: int = int(def.get("unlock_condition", {}).get("threshold", 0))
		# threshold<=1 为即时型成就（无进度条），threshold>1 为累计型（有进度条）
		var target: int = threshold if threshold > 1 else 0
		ps.register_achievement(ach_id, {"name": def["name"], "category": def["category"], "tier": def["tier"], "target": target})


# === 查询 API ================================================================

## 获取单个成就定义。
static func get_achievement_definition(ach_id: String) -> Dictionary:
	return ACHIEVEMENT_DEFS.get(ach_id, {}).duplicate(true)

## 获取全部成就定义（62 个）。
static func get_all_definitions() -> Array:
	var result: Array = []
	for ach_id: String in ACHIEVEMENT_DEFS:
		result.append(ACHIEVEMENT_DEFS[ach_id].duplicate(true))
	return result

## 按类别过滤成就定义。
static func get_definitions_by_category(category: String) -> Array:
	var result: Array = []
	for ach_id: String in ACHIEVEMENT_DEFS:
		var def: Dictionary = ACHIEVEMENT_DEFS[ach_id]
		if str(def.get("category", "")) == category:
			result.append(def.duplicate(true))
	return result


# === 内部辅助 =================================================================

## 获取 ProgressionSystem 引用——注入优先，否则 Autoload。
static func _get_progression_system() -> Node:
	if _progression_override != null:
		return _progression_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	for i: int in range(root.get_child_count()):
		var child: Node = root.get_child(i)
		if child != null and child.name == &"ProgressionSystem":
			return child
	return null


# === 判定引擎（Story 7-10）===================================================

## 跨局累计型事件——使用 update_achievement_progress 而非 unlock_achievement。
const CUMULATIVE_EVENTS: Array = [
	"elite_defeated", "boss_defeated", "alchemy_count", "craft_count",
	"inscription_count", "cards_discovered", "events_triggered",
	"dark_gold_count", "ling_shi_spent", "story_flags_collected",
	"total_reincarnations",
]

## 判定引擎——扫描全部成就定义，匹配 event + threshold + extra。[br]
## 返回本次触发解锁的 ach_id 列表。
static func check_achievements(event_name: String, current_value: int, extra: String = "") -> Array:
	var ps: Node = _get_progression_system()
	if ps == null:
		return []
	var unlocked_now: Array = []
	var is_cumulative: bool = event_name in CUMULATIVE_EVENTS

	for ach_id: String in ACHIEVEMENT_DEFS:
		var def: Dictionary = ACHIEVEMENT_DEFS[ach_id]
		var cond: Dictionary = def.get("unlock_condition", {})
		# 匹配 event
		if str(cond.get("event", "")) != event_name:
			continue
		# 匹配 extra（如有）
		if cond.has("extra"):
			if str(cond["extra"]) != extra:
				continue
		# 检查是否已解锁
		var ach_state: Dictionary = ps.get_achievement(ach_id)
		if bool(ach_state.get("unlocked", false)):
			continue  # 幂等——不重复解锁
		var threshold: int = int(cond.get("threshold", 0))
		if is_cumulative:
			# 跨局累计型——递增进度
			var increment: int = _calculate_increment(event_name, current_value, threshold, ach_state)
			if increment > 0:
				ps.update_achievement_progress(ach_id, increment)
			# 检查是否达到 threshold
			var updated: Dictionary = ps.get_achievement(ach_id)
			if bool(updated.get("unlocked", false)):
				unlocked_now.append(ach_id)
		else:
			# 即时型——达到 threshold 直接解锁
			if current_value >= threshold:
				var result: Dictionary = ps.unlock_achievement(ach_id)
				if bool(result.get("success", false)):
					unlocked_now.append(ach_id)

	return unlocked_now

## 计算跨局累计型成就的递增量。
static func _calculate_increment(event_name: String, current_value: int, threshold: int, ach_state: Dictionary) -> int:
	# 对于累计型，current_value 是本次事件的新值（如本次击杀数）
	# 简化模型：每次事件 increment=1（单次触发）
	# 对于 threshold 型（如 cards_discovered=50），current_value 是当前总数
	# progress.current 应递增到 current_value
	var progress: Variant = ach_state.get("progress", null)
	if progress == null:
		return 1
	var p: Dictionary = progress
	var current_progress: int = int(p.get("current", 0))
	# 如果 current_value > current_progress，递增差值
	if current_value > current_progress:
		return current_value - current_progress
	return 0


# === 查询 + 图鉴集成（Story 7-11）==============================================

## 获取已解锁成就列表——委托 ProgressionSystem.get_achievements 过滤 unlocked。
static func get_unlocked_achievements() -> Array:
	var ps: Node = _get_progression_system()
	if ps == null:
		return []
	var all: Array = ps.get_achievements()
	var result: Array = []
	for ach: Dictionary in all:
		if bool(ach.get("unlocked", false)):
			result.append(ach)
	return result

## 获取成就摘要——{total, unlocked, categories}。
static func get_achievement_summary() -> Dictionary:
	var ps: Node = _get_progression_system()
	var all_defs: Array = get_all_definitions()
	var total: int = all_defs.size()
	var unlocked_count: int = 0
	var categories: Dictionary = {}
	# 初始化 categories
	for cat: String in ["combat", "progression", "collection", "exploration", "narrative", "mastery", "challenge"]:
		categories[cat] = {"unlocked": 0, "total": 0}
	# 统计定义
	for def: Dictionary in all_defs:
		var cat: String = str(def.get("category", ""))
		if categories.has(cat):
			categories[cat]["total"] = int(categories[cat]["total"]) + 1
	# 统计已解锁
	if ps != null:
		var all_states: Array = ps.get_achievements()
		for ach: Dictionary in all_states:
			if bool(ach.get("unlocked", false)):
				unlocked_count += 1
				var ach_def: Dictionary = ACHIEVEMENT_DEFS.get(str(ach.get("id", "")), {})
				var cat2: String = str(ach_def.get("category", ""))
				if categories.has(cat2):
					categories[cat2]["unlocked"] = int(categories[cat2]["unlocked"]) + 1
	return {
		"total": total,
		"unlocked": unlocked_count,
		"categories": categories,
	}

## 获取隐藏成就列表——hidden_until_unlocked=true 且未解锁。
static func get_hidden_achievements() -> Array:
	var ps: Node = _get_progression_system()
	var result: Array = []
	for ach_id: String in ACHIEVEMENT_DEFS:
		var def: Dictionary = ACHIEVEMENT_DEFS[ach_id]
		if not bool(def.get("hidden_until_unlocked", false)):
			continue
		# 检查是否已解锁
		var unlocked: bool = false
		if ps != null:
			var state: Dictionary = ps.get_achievement(ach_id)
			unlocked = bool(state.get("unlocked", false))
		if not unlocked:
			result.append(def.duplicate(true))
	return result

## 获取成就进度——返回 {current, target} 或 null。
static func get_achievement_progress(ach_id: String) -> Variant:
	var ps: Node = _get_progression_system()
	if ps == null:
		return null
	var state: Dictionary = ps.get_achievement(ach_id)
	return state.get("progress", null)
