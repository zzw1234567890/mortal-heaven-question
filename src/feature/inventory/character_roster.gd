extends RefCounted
## CharacterRoster —— 角色名册的读取与详情投影（从 [CharacterStatusModel] 拆出）。[br]
## [br][b]为什么单独一处[/b]：角色这一块（名册 → 生命 → 阵亡 → 详情）本轮长出详情
## 之后会把模型推过 300 行软上限；而「角色怎么读出来」与「境界/属性怎么读」本就是
## 两个不相干的口径（同 [code]character_status_rows.gd[/code] 的拆分先例）。[br]
## [br][b]依赖全部由参数传入[/b]：本模块不查 Autoload、不持有引用——解析与降级
## 留在模型那一层（[code]CharacterStatusModel._resolve_*[/code]），这里只做纯读。[br]
## [br][b]三个数值来源各自的归属[/b]：[br]
##   · 名册与基础属性——[code]DeployRosterReader[/code]（[code]deck.slots[/code] → 模板）；[br]
##   · 生命——HP 表由调用方读好传入（[code]CombatHpCarryover.read_all[/code] 是
##     [code]player.character_hp[/code] 的唯一读侧）；[br]
##   · 阵亡——[code]DeploymentSystem.get_unavailable_characters()[/code]（读取器内部消费）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全静态纯函数，不 new 节点、不写任何数据。[br]
## [br][b]文案本地化豁免[/b]：与 character_status_model / inventory_catalog 同源口径。
##
## 来源: GDD combat-system.md §7（跨场残血与死亡持久）、GDD deployment-system.md §10
## （不可用角色）、GDD card-system.md §卡牌类型、ADR-0031 §2、
## 先例 [code]deploy_roster_reader.gd[/code] / [code]character_status_rows.gd[/code]。

## 词条口径（类型/稀有度中文名——本模块不另立词表）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 名册读取器（角色位 → 模板快照，含 is_dead）。
const RosterReaderScript := preload("res://src/ui/combat/deploy/deploy_roster_reader.gd")

## 阵亡 / 存活的中文标记（面板与测试都读这一处——不靠颜色单独承载信息）。
const TEXT_DEAD: String = "已阵亡（不可出战）"
const TEXT_ALIVE: String = "可出战"


## 全部角色位角色——[code]Array[{character_id, name, slot_index, current_hp, max_hp,
## hp_text, hp_known, attack, is_dead, status_text}][/code]。[br]
## [br]按角色位顺序（0-5）输出——界面上的次序与备战面板一致，玩家不必重新找位置。[br]
## [br][b]阵亡角色照实列出[/b]（不隐藏）：GDD combat-system.md §7 要求死亡跨场保持，
## 玩家必须看得到「谁倒了」。[br]
## [br][b]生命回退[/b]：无 [code]player.character_hp[/code] 记录时用模板 [code]base_hp[/code]
## 作分子分母（[code]hp_known = false[/code] 标明这是基准值而非记账值）。[br]
## [br]阵亡角色的 [code]current_hp[/code] 若为 0 则显示 0——[code]CombatHpCarryover[/code]
## 明确「阵亡照实写 0，不夹到 1 冒充存活」，本模块依此展示。
static func entries(p_gsm: Node, p_card_system: Node, p_deployment_system: Node,
		p_binding_manager: Node, p_hp_table: Dictionary) -> Array:
	var out: Array = []
	var roster: Array = RosterReaderScript.read(p_gsm, p_card_system,
			p_deployment_system, p_binding_manager)
	for raw: Variant in roster:
		if not (raw is Dictionary):
			continue
		out.append(_entry(raw, p_hp_table))
	return out


## 单个角色的详情——名册条目（生命/出战态）+ 卡牌模板字段的原样投影。[br]
## [br][param p_base] [method entries] 的一条（生命与出战态已算好）。[br]
## [param p_template] [code]CardTemplate[/code]；为 null（模板查不到）时如实标
## [code]template_known = false[/code]，不拿 0 冒充攻击力。[br]
## [br][b]类型/稀有度给的是中文字（不是枚举序号）[/b]：词条口径在
## [code]InventoryCatalog[/code] 一处（同属性标签的处理）。[br]
## [br][b][code]description[/code] 原样透传[/b]：卡面文案是策划写的，界面不改写它。
static func detail(p_base: Dictionary, p_template: Variant) -> Dictionary:
	var out: Dictionary = p_base.duplicate(true)
	if p_template == null:
		out["template_known"] = false
		return out
	var card_type: int = int(p_template.get("type"))
	out["template_known"] = true
	out["template_id"] = str(p_template.get("card_id"))
	out["card_type"] = card_type
	out["type_name"] = CatalogScript.card_type_name(card_type)
	out["rarity"] = int(p_template.get("rarity"))
	out["rarity_name"] = CatalogScript.rarity_name(int(p_template.get("rarity")))
	out["cost"] = int(p_template.get("cost"))
	out["base_hp"] = int(p_template.get("base_hp"))
	out["base_attack"] = int(p_template.get("base_attack"))
	out["description"] = str(p_template.get("description"))
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 名册条目 + HP 表 → 界面条目。[br]
## [br][b]投影到此的函数正是「角色状态」的全部数值口径[/b]：名字与攻击来自卡牌模板、
## 生命来自 HP 持久化、阵亡来自 DeploymentSystem——三者都不在本模块推算。
static func _entry(p_raw: Dictionary, p_hp_table: Dictionary) -> Dictionary:
	var character_id: int = int(p_raw.get("character_id", -1))
	var is_dead: bool = bool(p_raw.get("is_dead", false))
	var base_hp: int = maxi(int(p_raw.get("hp", 0)), 0)
	var recorded: Dictionary = p_hp_table.get(character_id, {})
	var hp_known: bool = not recorded.is_empty()
	var current_hp: int = int(recorded.get("current_hp", base_hp)) if hp_known else base_hp
	var max_hp: int = int(recorded.get("max_hp", base_hp)) if hp_known else base_hp
	return {
		"character_id": character_id,
		"name": str(p_raw.get("display_name", "")),
		"slot_index": int(p_raw.get("slot_index", -1)),
		"current_hp": current_hp,
		"max_hp": max_hp,
		"hp_text": "%d / %d" % [current_hp, max_hp],
		"hp_known": hp_known,
		"attack": int(p_raw.get("attack", 0)),
		"is_dead": is_dead,
		"status_text": TEXT_DEAD if is_dead else TEXT_ALIVE,
	}
