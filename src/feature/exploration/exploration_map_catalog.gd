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
## [code]exploration_enemy_pool.gd[/code] 跳过并告警，本目录不校验模板是否存在
## （数据与运行时不耦合）。[br]
##
## 来源: GDD exploration-system.md §1/§3 步骤⑥/§7 回旧地图、ADR-0014 §决策 2、
## DEBT-EUI-006-3 / DEBT-EUI-006-5。

## 难度档位 → 默认层数 / 节点数 / 敌人境界（与 ExplorationSystem.DIFFICULTY_CONFIGS 同构）。
const DIFFICULTY_DEFAULTS: Array = [
	{"layers": 4, "min_nodes": 2, "max_nodes": 3, "elite_count": 1, "shop_count": 1,
		"enemy_realm": 1, "enemy_count_min": 1, "enemy_count_max": 2, "elite_bonus": 1},
	{"layers": 5, "min_nodes": 2, "max_nodes": 4, "elite_count": 2, "shop_count": 1,
		"enemy_realm": 2, "enemy_count_min": 2, "enemy_count_max": 3, "elite_bonus": 1},
	{"layers": 5, "min_nodes": 3, "max_nodes": 4, "elite_count": 2, "shop_count": 2,
		"enemy_realm": 3, "enemy_count_min": 2, "enemy_count_max": 3, "elite_bonus": 1},
	{"layers": 6, "min_nodes": 3, "max_nodes": 4, "elite_count": 3, "shop_count": 2,
		"enemy_realm": 4, "enemy_count_min": 3, "enemy_count_max": 4, "elite_bonus": 1},
]

## 通用敌人池——现有模板只有散修/魔修两名（[code]assets/enemies/[/code]）。
## 每张地图引用同一份键名，后续加模板只需改对应地图的权重表。
const POOL_LIANQI: Array = [
	{"template_id": &"san_xiu", "weight": 70},
	{"template_id": &"mo_xiu", "weight": 30},
]
const POOL_FOUNDATION: Array = [
	{"template_id": &"san_xiu", "weight": 50},
	{"template_id": &"mo_xiu", "weight": 50},
]

## 地图登记表——键为地图 ID（与地图选择界面 / 章节表的地图 ID 对齐）。[br]
## [br][code]difficulty[/code] 为 MapDifficulty 枚举值（0=LOW … 3=VERY_HIGH）；
## [code]enemy_realm[/code] 是该地图的敌人基准境界（GDD「敌人强度按地图本身
## 境界设定」）；[code]max_realm[/code] 是该地图允许的最高玩家境界（通关奖励
## 的境界差额惩罚读它）。[br]
## [br][b]已知命名不一致[/b]：章节表用 [code]cang_xuan_zhengdao_meng[/code] 等
## 无下划线写法，地图选择用 [code]cang_xuan_zheng_dao_meng[/code]——两套 ID
## 并存是既有现状，本目录以地图选择界面的写法为准，未登记写法走难度兜底。
const MAPS: Dictionary = {
	&"qing_yun_jian_zong": {
		"difficulty": 0, "max_realm": 1, "enemy_realm": 1,
		"enemy_pool": POOL_LIANQI, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"xue_yuan_mi_jing": {
		"difficulty": 1, "max_realm": 1, "enemy_realm": 1,
		"enemy_pool": POOL_LIANQI, "enemy_count_min": 2, "enemy_count_max": 2,
	},
	&"yun_lan_cheng": {
		"difficulty": 2, "max_realm": 2, "enemy_realm": 2,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"dan_xia_gu": {
		"difficulty": 3, "max_realm": 2, "enemy_realm": 2,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 3, "enemy_count_max": 4,
	},
	&"cang_xuan_zheng_dao_meng": {
		"difficulty": 0, "max_realm": 2, "enemy_realm": 2,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"cang_xuan_gu_zhan_chang": {
		"difficulty": 1, "max_realm": 2, "enemy_realm": 2,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 2, "enemy_count_max": 2,
	},
	&"sui_xing_wai_huan": {
		"difficulty": 0, "max_realm": 2, "enemy_realm": 2,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 1, "enemy_count_max": 2,
	},
	&"xi_yu_gu_lin": {
		"difficulty": 2, "max_realm": 3, "enemy_realm": 3,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"mu_lan_cao_yuan": {
		"difficulty": 2, "max_realm": 4, "enemy_realm": 4,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 2, "enemy_count_max": 3,
	},
	&"gui_xu_fu_yun_lu": {
		"difficulty": 3, "max_realm": 5, "enemy_realm": 5,
		"enemy_pool": POOL_FOUNDATION, "enemy_count_min": 3, "enemy_count_max": 4,
	},
}


## 地图配置——登记表优先，未登记按玩家境界推难度档位兜底。[br]
## [br][param p_map_id] 地图 ID。[br]
## [param p_player_realm] 玩家境界（仅用于未登记地图的难度兜底，[b]不参与
## 敌人等级[/b]——等级基准恒为地图自身的 [code]enemy_realm[/code]）。[br]
## [br][b]返回[/b]：完整配置字典（含 layers / min_nodes / max_nodes /
## enemy_realm / enemy_pool / enemy_count_min / enemy_count_max / elite_bonus /
## max_realm / weights）。[br]
static func config_for(p_map_id: StringName, p_player_realm: int = 1) -> Dictionary:
	var registered: Variant = MAPS.get(p_map_id)
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


## 该地图是否已登记（未登记走难度兜底——调试/数据核对用）。
static func has_map(p_map_id: StringName) -> bool:
	return MAPS.has(p_map_id)


## 玩家境界 → 难度档位索引（1→LOW，2→MEDIUM，3→HIGH，4+→VERY_HIGH）。
static func _difficulty_of_realm(p_player_realm: int) -> int:
	return clampi(int(p_player_realm) - 1, 0, DIFFICULTY_DEFAULTS.size() - 1)


## 难度档位 → 配置副本（含战斗权重表——与 ExplorationSystem 默认档位一致）。[br]
## [br][param p_difficulty] 档位索引；越界时按 MEDIUM 处理（不崩溃）。
static func _difficulty_defaults(p_difficulty: int) -> Dictionary:
	var index: int = p_difficulty
	if index < 0 or index >= DIFFICULTY_DEFAULTS.size():
		index = 1
	var config: Dictionary = (DIFFICULTY_DEFAULTS[index] as Dictionary).duplicate(true)
	config["difficulty"] = index
	config["weights"] = {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5}
	return config
