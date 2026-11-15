class_name ExplorationMapCatalog
extends RefCounted
## ExplorationMapCatalog —— 探索地图配置目录（数据驱动的唯一真理来源）。[br]
## [br][b]为什么需要[/b]：[code]ExplorationSystem.get_map_config_cb[/code] 在生产路径
## 此前没有任何注入点——[method ExplorationSystem._get_map_config] 只能按玩家境界
## 退回难度档位表，于是「地图境界」无处表达，节点敌人强度只能拿玩家境界兜底
## （DEBT-EUI-006-3）。本目录把每张地图的层数 / 节点数 / [b]敌人基准境界[/b] /
## 敌人池 / 敌人数量范围收成一处，由启动层装配进探索系统。[br]
## [br][b]缺省语义[/b]：未登记的地图按难度档位兜底（[code]enemy_realm[/code] 取
## 档位默认值）——不静默用玩家境界，也不让地图生成崩溃。[br]
## [br][b]敌人池[/b]：[code]enemy_pool[/code] 是 [code]{template_id, weight}[/code]
## 列表，权重按地图给（不同地图的散修/魔修配比可以不同）。模板不存在时由
## [code]exploration_enemy_pool.gd[/code] 跳过并告警——数据与运行时不耦合。[br]
##
## 来源: GDD exploration-system.md §1/§3 步骤⑥/§7 回旧地图、ADR-0014 §决策 2、
## DEBT-EUI-006-3 / DEBT-EUI-006-5。

## 首通额外奖励表（按难度档——本文件不逐档重复，见类文档「首通额外奖励」）。
const FirstClearRewards := preload(
		"res://src/feature/exploration/exploration_first_clear_rewards.gd")

## 难度档位 → 默认层数 / 节点数 / 敌人境界（与 ExplorationSystem.DIFFICULTY_CONFIGS 同构）。[br]
## [b]首通额外奖励[/b]：不逐档重复，由 [code]exploration_first_clear_rewards.gd[/code]
## 按档位提供（[method _difficulty_defaults] 注入）。[br]
## [code]ap_cost[/code]：本档每次移动的行动力开销（GDD action-point-system.md §调优参数
## 「每格消耗 1，安全范围 1-2」——出厂全档 1，键存在是为了让「按地图配置扣」走配置读取
## 而非硬编码；单张地图可覆盖）。[br]
## [code]action_spring_count[/code]：本档灵泉的每图限次（同 GDD「每图限次 1 次」口径，
## 读取侧是 [code]exploration_action_spring.gd[/code] 的 [code]limit_of[/code]）。
const DIFFICULTY_DEFAULTS: Array = [
	{"layers": 4, "min_nodes": 2, "max_nodes": 3, "elite_count": 1, "shop_count": 1,
		"enemy_realm": 1, "enemy_count_min": 1, "enemy_count_max": 2, "elite_bonus": 1,
		"ap_cost": 1, "action_spring_count": 1},
	{"layers": 5, "min_nodes": 2, "max_nodes": 4, "elite_count": 2, "shop_count": 1,
		"enemy_realm": 2, "enemy_count_min": 2, "enemy_count_max": 3, "elite_bonus": 1,
		"ap_cost": 1, "action_spring_count": 1},
	{"layers": 5, "min_nodes": 3, "max_nodes": 4, "elite_count": 2, "shop_count": 2,
		"enemy_realm": 3, "enemy_count_min": 2, "enemy_count_max": 3, "elite_bonus": 1,
		"ap_cost": 1, "action_spring_count": 1},
	{"layers": 6, "min_nodes": 3, "max_nodes": 4, "elite_count": 3, "shop_count": 2,
		"enemy_realm": 4, "enemy_count_min": 3, "enemy_count_max": 4, "elite_bonus": 1,
		"ap_cost": 1, "action_spring_count": 1},
]

## 敌人池——四类出厂模板（[code]assets/enemies/*.tres[/code]）：
## 散修 / 魔修 / 妖兽 / 鬼修。[br]
## [br][b]每张地图引用自己的配比[/b]，而不是共用一份权重表——「这张图会刷什么
## 敌人」本身就是地图差异的一部分（山野多妖兽、血渊多魔修、古战场多鬼修）。
## 新增模板只需在池里加条目，不必改生成器。
const POOL_LIANQI: Array = [        # 山野：散修 + 妖兽
	{"template_id": &"san_xiu", "weight": 60},
	{"template_id": &"yao_shou", "weight": 40},
]
const POOL_BLOOD: Array = [         # 血渊：魔修主场
	{"template_id": &"mo_xiu", "weight": 50},
	{"template_id": &"san_xiu", "weight": 30},
	{"template_id": &"yao_shou", "weight": 20},
]
const POOL_FOUNDATION: Array = [    # 城镇/宗门：正道散修为主，魔修与妖兽混入
	{"template_id": &"san_xiu", "weight": 45},
	{"template_id": &"mo_xiu", "weight": 30},
	{"template_id": &"yao_shou", "weight": 25},
]
const POOL_GHOST: Array = [         # 古战场/古林：鬼修出没
	{"template_id": &"gui_xiu", "weight": 50},
	{"template_id": &"mo_xiu", "weight": 30},
	{"template_id": &"san_xiu", "weight": 20},
]
const POOL_GUIYU: Array = [         # 归墟：鬼修 + 魔修
	{"template_id": &"gui_xiu", "weight": 60},
	{"template_id": &"mo_xiu", "weight": 40},
]

## 地图 ID 别名表——历史写法 → 规范写法（[method canonical_id] 的唯一转换入口，
## 单向：别名只做读取兼容，不反向解析）。[br]
## [br][b]规范写法以地图选择界面为准[/b]（[constant MAPS] 的键 = 地图卡片列表）：
## 章节表早期用「单词连写」（[code]cang_xuan_zhengdao_meng[/code]），与地图选择的
## 「逐词下划线」（[code]cang_xuan_zheng_dao_meng[/code]）不一致，现已统一。[br]
## [br][b]只收录「同一个地图的两种写法」[/b]——未登记地图不在此表，它们由难度档位
## 兜底，不是命名冲突。2026-11-13 补齐：章节表里此前只有 ID 没有配置的 7 张地图已
## 登记进 [constant MAPS]，其旧写法一并进表。
const MAP_ID_ALIASES: Dictionary = {
	&"cang_xuan_zhengdao_meng": &"cang_xuan_zheng_dao_meng",
	&"cang_xuan_guzhanchang": &"cang_xuan_gu_zhan_chang",
	&"suixing_waihuan": &"sui_xing_wai_huan",
	&"suixing_neihai": &"sui_xing_nei_hai",
	&"xiyu": &"xi_yu_gu_lin",
	&"dajin_gulin": &"xi_yu_gu_lin",
	&"dajin_bianjing": &"xi_yu_bian_jing",
	&"yueguo_capital": &"yun_lan_cheng",
	&"mulan_caoyuan": &"mu_lan_cao_yuan",
	&"guixu_fuyun_lu": &"gui_xu_fu_yun_lu",
	&"guixu_tongdao": &"gui_xu_tong_dao",
	&"guixu_wanyao_gu": &"gui_xu_wan_yao_gu",
	&"guixu_gumo_zhanchang": &"gui_xu_gu_mo_zhan_chang",
}

## 地图登记表（[b]「探明表」[/b]）——键为地图 ID（[b]规范写法[/b]：与地图选择界面一致）。[br]
## [b]这是「有哪些地图」的唯一真理来源[/b]：地图选择列表
## （[code]ExplorationSystem.get_map_list[/code]）按本表的键逐条出卡片，章节表按
## [method canonical_id] 落到本表的键上——两侧不再各存一份地图清单。[br]
## [br][code]name[/code] 是面向玩家的中文名；[code]difficulty[/code] 为 MapDifficulty
## 枚举值（0=LOW … 3=VERY_HIGH，卡片 ⭐ 数取 +1）；[code]unlock_realm[/code] 是
## 解锁所需玩家境界（GDD §8「该境界突破后所有地图一次性解锁」）；
## [code]max_realm[/code] 是该地图允许的最高玩家境界（通关奖励的境界差额惩罚读它）；
## [code]enemy_realm[/code] 是该地图的敌人基准境界（GDD「敌人强度按地图本身境界
## 设定」）。[br]
## [br][code]reentry_allowed[/code] 缺省 [code]true[/code]，只有苍玄古战场显式写
## [code]false[/code]（GDD §8「剧情地图，通关后不可重入」）——缺省由读取方承担，表里不写满。[br]
## [br][code]unlock_after_clear[/code] 是「需先通关哪张图」的前置登记（缺省无前置 =
## 无序列锁）；GDD §8 的两条序列规则此前在代码里没有落点（只有境界门槛），现由它承载：
## 「青云剑宗 → 血渊秘境 → 云澜城 → 丹霞谷」的炼气链，以及「苍玄古战场 → 碎星外环」的
## 剧情锁（该章剧情链在本库尚未接线，暂以「首通苍玄古战场」作可玩到的等价前置）。[br]
## [br]判定与面向玩家的文案统一在 [code]exploration_map_gate.gd[/code]，本表只存事实。
## 字段值一律写 [constant MAPS] 的规范键——写错会让前置永不满足（该图永远开不了），
## 单测对全表做完整性断言。[br]
## [br][b]难度档取值口径[/b]：[code]difficulty[/code] 取
## [code]design/assets/specs/map-card-illustrations-assets.md[/code]（ASSET-211~227，
## 逐张标注「境界·难度」）——它是唯一覆盖全部 17 张地图的逐图规格。
## [code]design/gdd/exploration-system.md[/code] §地图重入消耗规则的重入基价表与之
## 在个别地图上不一致（如归墟·浮云陆：GDD 表作「高」、现有登记作「极高」）——
## 该分歧是存量（本次未改动既有 10 张的档位），不因本次登记而变大。[br]
## [br][b]命名口径[/b]：本表的键一律为规范写法；历史写法的读取兼容见 [constant MAP_ID_ALIASES]。
const MAPS: Dictionary = {
	&"qing_yun_jian_zong": {
		"name": "青云剑宗", "difficulty": 0, "unlock_realm": 1, "max_realm": 1,
		"enemy_realm": 1,
		"enemy_pool": POOL_LIANQI, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"xue_yuan_mi_jing": {
		"name": "血渊秘境", "difficulty": 1, "unlock_realm": 1, "max_realm": 1,
		"enemy_realm": 1, "unlock_after_clear": &"qing_yun_jian_zong",
		"enemy_pool": POOL_BLOOD, "enemy_count_min": 2, "enemy_count_max": 2,
	},
	&"yun_lan_cheng": {
		"name": "云澜城", "difficulty": 2, "unlock_realm": 1, "max_realm": 2,
		"enemy_realm": 2, "unlock_after_clear": &"xue_yuan_mi_jing",
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"dan_xia_gu": {
		"name": "丹霞谷", "difficulty": 3, "unlock_realm": 1, "max_realm": 2,
		"enemy_realm": 2, "unlock_after_clear": &"yun_lan_cheng",
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 3, "enemy_count_max": 4,
	},
	&"cang_xuan_zheng_dao_meng": {
		"name": "苍玄正道盟", "difficulty": 0, "unlock_realm": 2, "max_realm": 2,
		"enemy_realm": 2,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"cang_xuan_gu_zhan_chang": {
		"name": "苍玄古战场", "difficulty": 1, "unlock_realm": 2, "max_realm": 2,
		"enemy_realm": 2, "reentry_allowed": false,
		"enemy_pool": POOL_GHOST, "enemy_count_min": 2, "enemy_count_max": 2,
	},
	&"sui_xing_wai_huan": {
		"name": "碎星外环", "difficulty": 0, "unlock_realm": 2, "max_realm": 2,
		"enemy_realm": 2, "unlock_after_clear": &"cang_xuan_gu_zhan_chang",
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"sui_xing_nei_hai": {
		"name": "碎星内海", "difficulty": 1, "unlock_realm": 2, "max_realm": 2,
		"enemy_realm": 2,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"wan_gu_dian": {
		"name": "万古殿", "difficulty": 0, "unlock_realm": 3, "max_realm": 3,
		"enemy_realm": 3,
		"enemy_pool": POOL_GHOST, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"xi_yu_gu_lin": {
		"name": "西域古林", "difficulty": 2, "unlock_realm": 3, "max_realm": 3,
		"enemy_realm": 3,
		"enemy_pool": POOL_GHOST, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"xi_yu_bian_jing": {
		"name": "西域边境", "difficulty": 2, "unlock_realm": 3, "max_realm": 3,
		"enemy_realm": 3,
		"enemy_pool": POOL_BLOOD, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"xi_yu": {
		"name": "西域", "difficulty": 0, "unlock_realm": 4, "max_realm": 4,
		"enemy_realm": 4,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"mu_lan_cao_yuan": {
		"name": "慕兰草原", "difficulty": 2, "unlock_realm": 4, "max_realm": 4,
		"enemy_realm": 4,
		"enemy_pool": POOL_LIANQI, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"gui_xu_tong_dao": {
		"name": "归墟通道", "difficulty": 2, "unlock_realm": 4, "max_realm": 4,
		"enemy_realm": 4,
		"enemy_pool": POOL_GUIYU, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"gui_xu_fu_yun_lu": {
		"name": "归墟·浮云陆", "difficulty": 3, "unlock_realm": 5, "max_realm": 5,
		"enemy_realm": 5,
		"enemy_pool": POOL_GUIYU, "enemy_count_min": 3, "enemy_count_max": 4,
	},
	&"gui_xu_wan_yao_gu": {
		"name": "归墟·万妖谷", "difficulty": 1, "unlock_realm": 5, "max_realm": 5,
		"enemy_realm": 5,
		"enemy_pool": POOL_LIANQI, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"gui_xu_gu_mo_zhan_chang": {
		"name": "归墟·古魔战场", "difficulty": 2, "unlock_realm": 5, "max_realm": 5,
		"enemy_realm": 5,
		"enemy_pool": POOL_GUIYU, "enemy_count_min": 3, "enemy_count_max": 4,
	},
}


## 地图 ID 规范化——别名表命中的历史写法转成规范写法，其余原样返回。[br]
## [br][b]唯一转换入口[/b]：所有按地图 ID 查表的静态方法（[method config_for] /
## [method enemy_realm_of] / [method has_map]）入口先过本方法，调用方无需自己
## 记住两套写法。[br]
## [br][param p_map_id] 任意写法的地图 ID。[br]
## [br][b]返回[/b]：规范写法（未登记别名时返回入参本身）。[br]
static func canonical_id(p_map_id: StringName) -> StringName:
	return MAP_ID_ALIASES.get(p_map_id, p_map_id)


## 地图配置——登记表优先，未登记按玩家境界推难度档位兜底。[br]
## [br][param p_map_id] 地图 ID（历史写法经 [method canonical_id] 规范化）。[br]
## [br][param p_player_realm] 玩家境界（仅用于未登记地图的难度兜底，[b]不参与
## 敌人等级[/b]——等级基准恒为地图自身的 [code]enemy_realm[/code]）。[br]
## [br][b]返回[/b]：完整配置字典（含 layers / min_nodes / max_nodes /
## enemy_realm / enemy_pool / enemy_count_min / enemy_count_max / elite_bonus /
## max_realm / weights）。[br]
static func config_for(p_map_id: StringName, p_player_realm: int = 1) -> Dictionary:
	var registered: Variant = MAPS.get(canonical_id(p_map_id))
	var config: Dictionary = _difficulty_defaults(
			int((registered as Dictionary).get("difficulty", -1)) if registered is Dictionary
			else _difficulty_of_realm(p_player_realm))
	if registered is Dictionary:
		for key: Variant in (registered as Dictionary).keys():
			config[key] = (registered as Dictionary)[key]
	return config


## 地图的敌人基准境界（未登记地图按难度档位默认值）。[br]
## [br][b]用途[/b]：探索弹窗 / 测试需要单查境界时不必拼整份配置。
static func enemy_realm_of(p_map_id: StringName, p_player_realm: int = 1) -> int:
	return int(config_for(p_map_id, p_player_realm).get("enemy_realm", 1))


## 该地图是否已登记（未登记走难度兜底——调试/数据核对用）。[br]
## [br][b]历史写法算已登记[/b]：别名表命中即视为登记（同一张地图的两种写法
## 不应因为拼写而掉进难度兜底）。[br]
static func has_map(p_map_id: StringName) -> bool:
	return MAPS.has(canonical_id(p_map_id))


## 地图 ID 是否属于别名表登记的历史写法（防回归断言用——见
## [method unknown_map_ids]）。[br]
static func is_legacy_id(p_map_id: StringName) -> bool:
	return MAP_ID_ALIASES.has(p_map_id)


## 一组地图 ID 中「既不是规范写法、也没有别名」的那些。[br]
## [br][b]用途[/b]：章节表 / 存档 / 外部数据里的地图 ID 若拼错，[method
## config_for] 会静默走难度兜底（不报错但配错档位）。本方法把这类「查无此图」
## 的 ID 挑出来，供测试做防回归断言。[br]
## [br][param p_map_ids] 待检查的地图 ID 集合。[br]
## [br][b]返回[/b]：未登记且无别名的 ID 数组（顺序同入参）。[br]
static func unknown_map_ids(p_map_ids: Array) -> Array:
	var unknown: Array = []
	for raw: Variant in p_map_ids:
		var map_id: StringName = StringName(str(raw))
		if not MAPS.has(canonical_id(map_id)):
			unknown.append(map_id)
	return unknown


## 玩家境界 → 难度档位索引（1→LOW，2→MEDIUM，3→HIGH，4+→VERY_HIGH）。
static func _difficulty_of_realm(p_player_realm: int) -> int:
	return clampi(int(p_player_realm) - 1, 0, DIFFICULTY_DEFAULTS.size() - 1)


## 难度档位 → 配置副本（含战斗权重表——与 ExplorationSystem 默认档位一致）。[br]
## [br][param p_difficulty] 档位索引；越界时按 MEDIUM 处理（不崩溃）。[br]
## [br][b]权重表与 [code]exploration_system_helpers.gd[/code] 的
## [code]DIFFICULTY_CONFIGS[/code] 逐字同源[/b]——两处都是「按难度给权重」的
## 真理来源之一（本处服务登记地图，那里服务未注入回调的兜底路径），改一处必须
## 同改另一处；[code]harvest[/code] 为上轮、[code]alchemy[/code] / [code]forge[/code]
## / [code]action_spring[/code] 为本轮新增节点类型的权重。
static func _difficulty_defaults(p_difficulty: int) -> Dictionary:
	var index: int = p_difficulty
	if index < 0 or index >= DIFFICULTY_DEFAULTS.size():
		index = 1
	var config: Dictionary = (DIFFICULTY_DEFAULTS[index] as Dictionary).duplicate(true)
	config["difficulty"] = index
	# 首通额外奖励——按难度档注入（表在 exploration_first_clear_rewards.gd，
	# 避免 17 张地图各抄一遍；消费方是 ExplorationEconomy.calculate_map_clear_rewards
	# 的 config.get("first_clear_reward", {}) 钩子）。
	config["first_clear_reward"] = FirstClearRewards.for_difficulty(index)
	config["weights"] = {"combat": 40, "event": 30, "shop": 15, "rest": 10,
			"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6,
			"elite": 5, "action_spring": 8}
	return config
