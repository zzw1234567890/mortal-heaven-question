extends RefCounted
## BossConfirmRules —— Boss 战前确认弹窗的文案内核（GDD §5 独立规格）。[br]
## [br][b]为什么单独一处[/b]：[code]node_interaction_rules.gd[/code] 已贴 300 行软
## 上限（.claude/docs/coding-standards.md），而 Boss 战确认是它内部唯一一条
## 「独立规格」——GDD 给 Boss 弹窗单开了一节（§5），文案组与警示数值都与普通
## 战斗、渡劫台不同，值得单独推理与单独测试（同
## [code]node_combat_preview_rules.gd[/code] 的拆分先例）。[br]
## [br][b]两个警示数值绝不混用[/b]（GDD §4b / §5 两处都明写）：[br]
##   · [b]Boss 战[/b]——撤退视为战败处理，保留 [b]50%[/b] 本局修为；[br]
##   · [b]渡劫台[/b]——撤退损失 [b]80%[/b] 本局修为（
##     [code]NodeInteractionRules.tribulation_warning_lines[/code]）。[br]
##   两边各是一个具名方法（不是带参数的一个方法）——传错就编译不过，而不是
##   静默显示一个错的百分比。[br]
## [br][b]正文复用战斗预览内核[/b]：敌人行 / 境界行 / 推荐行与普通战斗同源
## （[code]NodeCombatPreviewRules.lines_for_encounter[/code]），只在最前面多一行
## 地图名——两处各拼一套必然漂移。[br]
## [br][b]零状态纯函数[/b]（ADR-0031 §2）：不读 Autoload、不写任何状态。[br]
## [br][b]文案本地化豁免[/b]：与 [code]node_interaction_rules.gd[/code] 同源口径
## （项目暂无本地化系统）。[br]
##
## 来源: design/gdd/exploration-ui-system.md §5 Boss战前确认 / §4b 渡劫台弹窗、
## design/gdd/combat-system.md §9（撤退惩罚）、ADR-0031 §2。

## 战斗预览内核（正文行的唯一实现——与普通战斗弹窗共用）。
const CombatPreview := preload("res://src/ui/exploration/node_combat_preview_rules.gd")

## Boss 战专属警示行（GDD §5）——朱砂红渲染，与渡劫台的 80% 明确区分。
const BOSS_WARNING: String = "⚠ 进入Boss战后撤退将视为战败处理"
## Boss 战警示补注（GDD §5 线框第二行）——「保留 50% 本局修为」。
const BOSS_WARNING_NOTE: String = "保留 50% 本局修为（combat-system.md §9）"
## 正文首行的地图名前缀（GDD §5 线框「地图：青云剑宗」）。
const TEXT_MAP_PREFIX: String = "地图："


## Boss 战警示行（GDD §5——撤退视为战败，保留 50% 本局修为）。[br]
## [br][b]返回[/b]：两行文案——第一行陈述处理方式，第二行给具体数值与出处。
static func warning_lines() -> Array:
	return [BOSS_WARNING, BOSS_WARNING_NOTE]


## Boss 战弹窗的动态正文行（GDD §5 线框：地图 → 敌人 → 境界 → 推荐上场）。[br]
## [br][param p_map_name] 地图中文名（空串则省略该行——不写「地图：」空壳）。[br]
## [param p_encounter] 规范化遭遇配置（[code]EncounterFields[/code] 五键契约——
## 与开战上下文读同一份节点数据）。[br]
## [param p_roster] 到达名册（可为空——数量退化为模板 ID 数）。[br]
## [param p_max_deploy] 当前境界上场人数上限（[code]RealmSystem[/code] 查询值，
## UI 不推算）。
static func body_lines(p_map_name: String, p_encounter: Dictionary,
		p_roster: Array, p_max_deploy: int) -> Array:
	var lines: Array = []
	if not p_map_name.strip_edges().is_empty():
		lines.append(TEXT_MAP_PREFIX + p_map_name)
	lines.append_array(CombatPreview.lines_for_encounter(p_encounter, p_roster,
			p_max_deploy))
	return lines
