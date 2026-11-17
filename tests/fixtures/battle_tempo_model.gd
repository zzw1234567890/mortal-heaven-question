extends RefCounted
## BattleTempoModel —— 难度配平的「一场遭遇」算式模型（测试与审计脚本共用的唯一实现）。[br]
## [br][b]为什么需要[/b]：「追平后 3~5 回合能赢」是数值目标，不实测就只是口号；
## 而实测若在测试文件里现写一遍、审计脚本里再写一遍，两处口径必然漂移
## （改动系数后一处跟着变、另一处悄悄过期）。本模块把算式收成一处，
## 测试与 [code]tools/probe_difficulty_audit.gd[/code] 都调它。[br]
## [br][b]模型（一次遭遇，不含技能/减伤/治疗/阵法）[/b]：[br]
##   · [b]玩家侧[/b]：出战名额取 [code]RealmSystem.realm_table[境界].max_deploy[/code]；
##     角色取全部角色卡里（[code]type == CHARACTER[/code]）按「ATK 降序 → HP 降序 →
##     card_id 升序」排序的前 N 名——这是[b]战力上界[/b]（玩家会把最强的摆上场），
##     不是某一局的真实阵容；[br]
##   · [b]敌方侧[/b]：名册取 [code]ExplorationEnemyPool[/code] 对「该图 + 该玩家境界」
##     的真实输出（种子由地图 ID 决定 → 同一张图恒得同一份名册，可复现）；[br]
##   · [b]每回合玩家伤害[/b] = Σ 出战角色 ATK——每个出战角色每回合打出一张基础攻击
##     （威力 ×1.0），走「打出即生效」路径，[b]不扣 DEF[/b]（该路径本就不减防御，
##     见 [code]combat_on_play_effects.gd[/code]）；[br]
##   · [b]每回合敌方伤害[/b] = Σ 敌人 [code]max(0, round(ATK × 最强技能威力) − 玩家 DEF)[/code]
##     ——玩家角色卡无 [code]base_defense[/code]，出厂 DEF 为 0；[br]
##   · [b]回合数[/b] = [code]ceil(敌方总 HP / 玩家每回合伤害)[/code]；
##     [b]我方存活回合数[/b] = [code]ceil(玩家总 HP / 敌方每回合伤害)[/code]。[br]
## [br][b]模型不覆盖的**：卡牌费用/抽牌约束（每个角色能否每回合都出牌）与技能池差异
## ——它们会把回合数往上或往下推，故 [code]turns_to_win[/code] 是[b]乐观下界[/b]；
## 端到端用例跑的是真实战斗系统，两者互为上下界。[br]
##
## 来源: GDD combat-system.md §3 伤害公式、GDD ai-system.md §9 难度缩放、
## 本轮「难度与人数配平」。

## 地图配置目录（敌人池与人数范围）。
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
## 敌人名册生成器（与生产同一条路径——种子由地图 ID 与境界派生）。
const PoolScript := preload("res://src/feature/exploration/exploration_enemy_pool.gd")
## 难度系数表（全库唯一系数来源）。
const CurveScript := preload("res://assets/enemies/difficulty_curve.gd")

## 敌人技能威力缺省（技能池读不到时按 1.0——普通攻击）。
const DEFAULT_POWER: float = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# 玩家侧
# ═══════════════════════════════════════════════════════════════════════════════

## 出战名额——RealmSystem 境界表 [code]max_deploy[/code]（表缺失时回退 2）。[br]
## [br][param p_realm_table] [code]RealmSystem.realm_table[/code]（注入而非现查 Autoload，
## 便于纯函数测试）。[br]
## [param p_realm] 玩家境界。
static func max_deploy_of(p_realm_table: Dictionary, p_realm: int) -> int:
	var row: Variant = p_realm_table.get(p_realm, {})
	if not (row is Dictionary):
		return 2
	return maxi(int((row as Dictionary).get("max_deploy", 2)), 1)


## 玩家侧战力上界——前排 N 名角色卡。[br]
## [br][param p_characters] 角色卡模板数组（[code]CardTemplate[/code]，[code]type == 0[/code]）。[br]
## [param p_max_deploy] 出战名额。[br]
## [br][b]返回[/b]：[code]{chars: Array[{id, hp, atk}], total_hp, atk_sum}[/code]。
static func player_side(p_characters: Array, p_max_deploy: int) -> Dictionary:
	var ranked: Array = p_characters.duplicate()
	ranked.sort_custom(_stronger_first)
	var picked: Array = []
	for i: int in range(mini(p_max_deploy, ranked.size())):
		var template: Variant = ranked[i]
		picked.append({
			"id": str(template.get("card_id")),
			"hp": int(template.get("base_hp")),
			"atk": int(template.get("base_attack")),
		})
	var total_hp: int = 0
	var atk_sum: int = 0
	for entry: Dictionary in picked:
		total_hp += int(entry["hp"])
		atk_sum += int(entry["atk"])
	return {"chars": picked, "total_hp": total_hp, "atk_sum": atk_sum}


## 强度排序——ATK 降序 → HP 降序 → card_id 升序（末项保证确定性，同分不乱序）。
static func _stronger_first(a: Variant, b: Variant) -> bool:
	var atk_a: int = int(a.get("base_attack"))
	var atk_b: int = int(b.get("base_attack"))
	if atk_a != atk_b:
		return atk_a > atk_b
	var hp_a: int = int(a.get("base_hp"))
	var hp_b: int = int(b.get("base_hp"))
	if hp_a != hp_b:
		return hp_a > hp_b
	return str(a.get("card_id")) < str(b.get("card_id"))


# ═══════════════════════════════════════════════════════════════════════════════
# 敌方侧
# ═══════════════════════════════════════════════════════════════════════════════

## 敌方侧——该图的真实名册 + 按难度系数表缩放后的属性。[br]
## [br][param p_map_id] 地图 ID。[br]
## [param p_player_realm] 玩家境界（档位轴的输入）。[br]
## [param p_lookup] 模板查询闭包 [code]func(template_id) -> Resource[/code]。[br]
## [param p_is_elite] 是否精英档（人数 +[code]elite_bonus[/code]）。[br]
## [br][b]返回[/b]：[code]{roster, total_hp, atk_per_turn, count, tier, power}[/code]——
## 每个名册条目带 [code]{template_id, max_hp, attack, defense}[/code]（缩放后）。[br]
## [br][b]权威缩放走 [method CurveScript.apply][/b]：模型不自己乘系数，改表即改这里。
static func enemy_side(p_map_id: StringName, p_player_realm: int, p_lookup: Callable,
		p_is_elite: bool = false) -> Dictionary:
	var config: Dictionary = CatalogScript.config_for(p_map_id, p_player_realm)
	var map_realm: int = int(config.get("enemy_realm", 0))
	var pool: RefCounted = PoolScript.new(p_lookup)
	var raw: Array = pool.call(&"make_roster", p_map_id, p_player_realm, p_is_elite, config)
	var roster: Array = []
	var total_hp: int = 0
	var atk_per_turn: int = 0
	for entry: Variant in raw:
		var template: Variant = p_lookup.call(StringName(str((entry as Dictionary)["template_id"])))
		if template == null:
			continue
		var scaled: Dictionary = CurveScript.apply(
				int(template.get("base_hp")), int(template.get("base_attack")),
				int(template.get("base_defense")), int(template.get("realm")),
				p_player_realm, map_realm)
		var power: float = strongest_power(template)
		var attack: int = int(scaled["attack"])
		roster.append({
			"template_id": str((entry as Dictionary)["template_id"]),
			"max_hp": int(scaled["max_hp"]),
			"attack": attack,
			"defense": int(scaled["defense"]),
			"power": power,
		})
		total_hp += int(scaled["max_hp"])
		atk_per_turn += maxi(roundi(float(attack) * power), 0)
	return {
		"roster": roster,
		"total_hp": total_hp,
		"atk_per_turn": atk_per_turn,
		"count": roster.size(),
		"tier": CurveScript.tier_of(map_realm, p_player_realm),
		"map_realm": map_realm,
	}


## 敌人最强技能威力——技能池里 [code]power_multiplier[/code] 的最大值（空池按 1.0）。[br]
## [br][b]取最强而非平均[/b]：回合数是给玩家看的难度下界，用「敌人每回合都放最强技能」
## 的口径更保守；实际 AI 按权重选技能，威力只会更低。[br]
static func strongest_power(p_template: Variant) -> float:
	var pool: Variant = p_template.get("skill_pool")
	if not (pool is Array) or (pool as Array).is_empty():
		return DEFAULT_POWER
	var best: float = 0.0
	for skill: Variant in pool:
		if skill == null:
			continue
		best = maxf(best, float(skill.get("power_multiplier")))
	return best if best > 0.0 else DEFAULT_POWER


# ═══════════════════════════════════════════════════════════════════════════════
# 回合数
# ═══════════════════════════════════════════════════════════════════════════════

## 击杀全部敌人所需回合数——[code]ceil(敌方总 HP / 玩家每回合伤害)[/code]。[br]
## [br][b]返回 0[/b]：玩家每回合伤害为 0（读不到角色卡）——不臆造「无限回合」。
static func turns_to_win(p_enemy_total_hp: int, p_player_atk_per_turn: int) -> int:
	if p_player_atk_per_turn <= 0:
		return 0
	return int(ceil(float(p_enemy_total_hp) / float(p_player_atk_per_turn)))


## 我方存活回合数——[code]ceil(玩家总 HP / 敌方每回合伤害)[/code]。[br]
## [br][b]返回 0[/b]：敌方每回合伤害为 0（0 伤敌人打不死人——不是 0 回合阵亡）。
static func survivable_turns(p_player_total_hp: int, p_enemy_atk_per_turn: int) -> int:
	if p_enemy_atk_per_turn <= 0:
		return 0
	return int(ceil(float(p_player_total_hp) / float(p_enemy_atk_per_turn)))


## 一次遭遇的完整算式——[code]{player, enemy, turns, survive, wins, gap}[/code]。[br]
## [br][b]wins[/b]：玩家先手（每回合先打）时 [code]turns <= survive[/code] 即胜。
static func encounter(p_map_id: StringName, p_player_realm: int, p_characters: Array,
		p_realm_table: Dictionary, p_lookup: Callable, p_is_elite: bool = false) -> Dictionary:
	var player: Dictionary = player_side(p_characters,
			max_deploy_of(p_realm_table, p_player_realm))
	var enemy: Dictionary = enemy_side(p_map_id, p_player_realm, p_lookup, p_is_elite)
	var turns: int = turns_to_win(int(enemy["total_hp"]), int(player["atk_sum"]))
	var survive: int = survivable_turns(int(player["total_hp"]), int(enemy["atk_per_turn"]))
	return {
		"player": player,
		"enemy": enemy,
		"turns": turns,
		"survive": survive,
		"wins": turns > 0 and turns <= survive,
		"gap": int((enemy["tier"] as Dictionary)["gap"]),
	}
