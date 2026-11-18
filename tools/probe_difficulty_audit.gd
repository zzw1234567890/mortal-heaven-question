extends SceneTree
## probe_difficulty_audit —— 难度与人数配平的审计脚本（本轮汇报数字的唯一来源）。[br]
## [br][b]为什么不用估算[/b]：「L1 打第一张图 / L4 打第四张图要几个回合」这类数字
## 手推一遍看似可行，但角色卡排序、敌人名册随机、技能威力取哪一条——每处口径都能
## 差出一倍。本脚本直接跑生产算式（难度系数表 + 敌人池 + 回合模型），把结果打成表。[br]
## [br][b]不依赖 Autoload[/b]：模板用 [code]load()[/code] 直接读
## [code]assets/[/code] 下的 [code].tres[/code]——[code]-s[/code] 模式里 CardSystem /
## AISystem 的异步加载尚未完成（[code]_ready[/code] 之外的时机），读 Autoload 会得到空表。[br]
## [br][b]运行[/b]：[code]godot --headless -s tools/probe_difficulty_audit.gd[/code][br]
## [br]来源: GDD ai-system.md §9、GDD exploration-system.md §7、DEBT-EQT-001。

const TempoModel := preload("res://tests/fixtures/battle_tempo_model.gd")
const CurveScript := preload("res://assets/enemies/difficulty_curve.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const RealmScript := preload("res://src/core/realm_system.gd")

## 审计的两条场景（用户口径）：玩家境界 → 地图 ID。
const SCENARIOS: Array = [
	{"label": "L1 打第一张图", "realm": 1, "map": &"qing_yun_jian_zong"},
	{"label": "L4 打第四张图", "realm": 4, "map": &"gui_xu_tong_dao"},
]


func _initialize() -> void:
	var characters: Array = _load_dir("res://assets/cards/templates/", 0)
	var enemies: Dictionary = _load_enemy_registry()
	var lookup: Callable = func(tid: StringName) -> Variant: return enemies.get(tid, null)

	print("=== 难度配平审计（角色卡 %d 张 / 敌人模板 %d 个）===" % [characters.size(), enemies.size()])
	print("")
	_print_realm_table()
	_print_character_ranking(characters)
	_print_curve_table()
	_print_headcount_table()
	print("")
	_print_scenarios(characters, lookup)
	quit()


## 境界表——max_deploy / cost_per_turn / action_points 与上场人数上限。
func _print_realm_table() -> void:
	print("--- 境界表（RealmSystem.realm_table）---")
	var table: Dictionary = RealmScript.realm_table
	for realm: int in range(1, 6):
		var row: Dictionary = table.get(realm, {})
		print("  L%d %s：max_deploy=%d cost_per_turn=%d action_points=%d card_pool_tier=%d"
				% [realm, str(row.get("name", "?")), int(row.get("max_deploy", 0)),
				int(row.get("cost_per_turn", 0)), int(row.get("action_points", 0)),
				int(row.get("card_pool_tier", 0))])
	print("")


## 角色卡按强度排序——模型取前 N 名（N = max_deploy），此处打印全序供核对。
func _print_character_ranking(p_characters: Array) -> void:
	print("--- 角色卡（ATK 降序 → HP 降序 → card_id 升序）---")
	var table: Dictionary = RealmScript.realm_table
	for realm: int in range(1, 6):
		var deploy: int = TempoModel.max_deploy_of(table, realm)
		var side: Dictionary = TempoModel.player_side(p_characters, deploy)
		var names: Array = []
		for entry: Dictionary in side["chars"]:
			names.append("%s(%d/%d)" % [entry["id"], entry["hp"], entry["atk"]])
		print("  L%d 出战 %d 人：%s  合计 HP=%d ATK/回合=%d"
				% [realm, deploy, ", ".join(names), int(side["total_hp"]), int(side["atk_sum"])])
	print("")


## 难度系数表——档位 × 系数 × 人数区间（全库唯一系数来源）。
func _print_curve_table() -> void:
	print("--- 难度系数表（DifficultyCurve.TIER_TABLE，gap = 地图境界档 − 玩家境界）---")
	for gap: int in range(CurveScript.TIER_MIN_GAP, CurveScript.TIER_MAX_GAP + 1):
		var key: int = clampi(gap, CurveScript.TIER_MIN_GAP, CurveScript.TIER_MAX_GAP)
		var row: Dictionary = CurveScript.TIER_TABLE[key]
		print("  gap=%+d：HP ×%.2f  ATK ×%.2f  人数 %d~%d  档位「%s」"
				% [gap, float(row["hp"]), float(row["atk"]),
				int(row["count_min"]), int(row["count_max"]), str(row["label"])])
	print("  追赶轴：玩家每高出模板基准 1 档 → ×%.2f（%s）"
			% [1.0 + CurveScript.CATCH_UP_PER_REALM, "GDD §9 既有口径"])
	print("")


## 人数表——「每个玩家境界 × 每张地图」进图时的敌方人数区间与地图上限兜底。[br]
## [br][b]这是本轮汇报里那张表的唯一来源[/b]（手推一遍容易漏掉夹取层：档位区间 →
## 出战名额余量 → 地图上限 → 硬边界）。
func _print_headcount_table() -> void:
	var table: Dictionary = RealmScript.realm_table
	print("--- 人数表（行 = 玩家境界，列 = 地图；格 = 该图该境界的敌方人数区间）---")
	var header: Array = ["玩家\\地图"]
	for map_id: StringName in CatalogScript.MAPS.keys():
		header.append(str(CatalogScript.MAPS[map_id].get("name", map_id)))
	print("  %s" % " | ".join(header))
	for realm: int in range(1, 6):
		var cells: Array = ["L%d(max_deploy=%d)" % [realm,
				TempoModel.max_deploy_of(table, realm)]]
		for map_id: StringName in CatalogScript.MAPS.keys():
			var config: Dictionary = CatalogScript.config_for(map_id, realm)
			var span: Dictionary = CurveScript.count_range_of(
					int(config.get("enemy_realm", 0)), realm,
					int(config.get("enemy_count_max", 0)),
					TempoModel.max_deploy_of(table, realm))
			# 未被任何一层夹取的档位区间——与它比较才知道这一格有没有被压低
			var raw_row: Dictionary = CurveScript.TIER_TABLE[
					CurveScript.tier_key_of(int(config.get("enemy_realm", 0)), realm)]
			var squeezed: bool = int(span["max"]) < int(raw_row["count_max"])
			cells.append("%d~%d%s" % [int(span["min"]), int(span["max"]),
					"*" if squeezed else ""])
		print("  %s" % " | ".join(cells))
	print("  * = 该格被兜底压过（地图的 enemy_count_max，或「出战名额 + %d」）——首图对低境界玩家即此类"
			% CurveScript.COUNT_OVER_DEPLOY)
	print("")


## 两条场景的实际算式——人数 / 属性 / 每回合伤害 / 回合数 / 存活回合数。
func _print_scenarios(p_characters: Array, p_lookup: Callable) -> void:
	var table: Dictionary = RealmScript.realm_table
	print("--- 场景实测（算式：ceil(敌方总HP / 玩家每回合伤害)）---")
	for scenario: Dictionary in SCENARIOS:
		var label: String = str(scenario["label"])
		var realm: int = int(scenario["realm"])
		var map_id: StringName = scenario["map"]
		var result: Dictionary = TempoModel.encounter(
				map_id, realm, p_characters, table, p_lookup)
		var player: Dictionary = result["player"]
		var enemy: Dictionary = result["enemy"]
		var config: Dictionary = CatalogScript.config_for(map_id, realm)
		var span: Dictionary = CurveScript.count_range_of(
				int(config.get("enemy_realm", 0)), realm,
				int(config.get("enemy_count_max", 0)),
				TempoModel.max_deploy_of(table, realm))
		print("")
		print("  [%s] 地图=%s（%s）difficulty=%d enemy_realm=%d 人数区间=%d~%d 地图上限兜底=%d"
				% [label, map_id, str(config.get("name", "")),
				int(config.get("difficulty", -1)), int(config.get("enemy_realm", 0)),
				int(span["min"]), int(span["max"]),
				int(config.get("enemy_count_max", 0))])
		print("    玩家：出战 %d 人 → 总 HP %d，每回合伤害 %d"
				% [player["chars"].size(), int(player["total_hp"]), int(player["atk_sum"])])
		var roster_desc: Array = []
		for entry: Dictionary in enemy["roster"]:
			roster_desc.append("%s(HP %d/ATK %d/威 %.1f)"
					% [entry["template_id"], int(entry["max_hp"]),
					int(entry["attack"]), float(entry["power"])])
		print("    敌方：%d 人 → %s" % [int(enemy["count"]), " + ".join(roster_desc)])
		print("    敌方总 HP %d，每回合对我方伤害 %d；档位 gap=%+d「%s」"
				% [int(enemy["total_hp"]), int(enemy["atk_per_turn"]),
				int(result["gap"]), CurveScript.tier_label_of(
						int(enemy["map_realm"]), realm)])
		print("    → 击杀全部敌人需 %d 回合；我方存活 %d 回合；%s"
				% [int(result["turns"]), int(result["survive"]),
				"能赢" if bool(result["wins"]) else "打不过"])


## 读一个 [code].tres[/code] 目录，按卡牌类型筛选（[param p_type] -1 = 不筛）。[br]
## [br][b]为什么直接 load 而不走 CardSystem[/b]：见类文档（[code]-s[/code] 模式下
## 模板注册表还没读满）。
func _load_dir(p_dir: String, p_type: int) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(p_dir)
	if dir == null:
		push_error("probe_difficulty_audit: 打不开目录 %s" % p_dir)
		return out
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Variant = load(p_dir + file_name)
			if res != null and (p_type < 0 or int(res.get("type")) == p_type):
				out.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


## 敌人模板注册表——[code]assets/enemies/*.tres[/code] 里带 [code]template_id[/code]
## 的那些（[code]rewards/[/code] 子目录与 [code]encounter_fields[/code] 等非模板资源
## 按字段探测跳过）。
func _load_enemy_registry() -> Dictionary:
	var registry: Dictionary = {}
	for res: Variant in _load_dir("res://assets/enemies/", -1):
		var tid: StringName = StringName(str(res.get("template_id")))
		if tid != &"" and res.get("base_hp") != null:
			registry[tid] = res
	return registry
