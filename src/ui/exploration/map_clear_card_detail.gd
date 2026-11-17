extends RefCounted
## MapClearCardDetail —— 结算面板卡牌详情的[b]模板字段来源[/b]（从 exploration_scene 拆出）。[br]
## [br][b]链路[/b]：面板点开一张奖励卡牌 → 面板的
## [code]detail_provider[/code] 回调 → 本模块按模板 ID 查 [code]CardSystem[/code]
## → 返回 [code]{description, flavor_text}[/code] 给面板拼详情行。[br]
## [br][b]为什么从场景拆出来[/b]：[code]exploration_scene.gd[/code] 已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「卡牌描述从哪来」与「节点图怎么挂、
## 重入怎么落地」是两件事（同 [code]map_clear_presenter.gd[/code] 先例）。[br]
## [br][b]查不到不编造[/b]：CardSystem 未挂载 / 无该模板 / 模板缺字段时返回空字典或空串
## ——面板只用结算载荷里的名称 / 稀有度 / 类型（GDD §7 的详情行是加分项，
## 不是必填项，缺了不该显示一片空白占位）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：纯只读查询，不写 GSM、不发奖励。[br]
##
## 来源: design/gdd/exploration-ui-system.md §7 地图通关结算（点击奖励卡牌查看详情）、
## ADR-0031 §2。

## 卡牌系统的常驻路径（模板注册表的持有者）。
const CARD_SYSTEM_PATH: StringName = &"/root/CardSystem"

## 详情字段名（面板读这两个键——与卡牌模板的同名字段同源）。
const KEY_DESCRIPTION: String = "description"
const KEY_FLAVOR: String = "flavor_text"


## 按模板 ID 查卡牌详情。[br]
## [br][param p_scene] 场景树内的任意节点（用它查常驻 CardSystem）。[br]
## [param p_entry] 结算载荷里的卡牌条目（读 [code]template_id[/code]，
## 缺失时回退 [code]card_id[/code]）。[br]
## [br][b]返回[/b]：[code]{description, flavor_text}[/code]；无法查询时为空字典。[br]
## [br][b]非字典条目按无 ID 处理[/b]：面板允许裸 ID 字符串条目（见
## [code]MapClearPanelRules.cards_of[/code]），这类条目没有模板 ID 可查，
## 如实返回空——不臆造描述文本。
static func extra_of(p_scene: Node, p_entry: Variant) -> Dictionary:
	var entry: Dictionary = p_entry if p_entry is Dictionary else {}
	var card_id: String = str(entry.get("template_id", entry.get("card_id", "")))
	if card_id.is_empty() or p_scene == null or not p_scene.is_inside_tree():
		return {}
	var card_system: Node = p_scene.get_node_or_null(NodePath(CARD_SYSTEM_PATH))
	if card_system == null or not card_system.has_method(&"get_template"):
		return {}
	var template: Variant = card_system.call(&"get_template", StringName(card_id))
	if not _readable(template):
		return {}
	return {
		KEY_DESCRIPTION: str(template.get(KEY_DESCRIPTION)),
		KEY_FLAVOR: str(template.get(KEY_FLAVOR)),
	}


## 模板对象是否可读字段（[code]CardTemplate[/code] 是 Resource 而非字典——
## 判据必须两种都认，只认字典会让详情行永远只有卡名）。[br]
## [br][b]null 不可读[/b]：查不到的模板返回 null（[code]get_template[/code] 的缺省），
## 对它取字段会得到空串而不是报错，但那样就分不出「没有这个模板」与「模板没写描述」。
static func _readable(p_template: Variant) -> bool:
	return p_template is Dictionary or p_template is Resource
