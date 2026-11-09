extends RefCounted
## BindingDamageReduction —— 绑定卡的百分比减伤汇总（DEBT-CBT-018-8 残留闭环）。[br]
## [br][b]职责[/b]：把「某角色身上绑了哪些 [code]damage_reduce[/code] 卡」收敛成一份
## 减伤来源列表（百分比数组），供战斗 Attack 阶段写入攻击队列条目的
## [code]damage_reduction_pcts[/code]。[br]
## [br][b]本模块不算最终伤害[/b]：乘算叠加与 60% 封顶由
## [method CardEffectEvaluator.combine_damage_reduction] 统一负责
## （GDD combat-system.md §公式：「伤害 × 0.9 × 0.85 …，上限 60%」）——
## 这里只回答「有哪些来源、各是多少」。[br]
## [br][b]单卡数值口径[/b]：与 AI 干跑同一入口 [method CardEffectEvaluator.evaluate_effect]，
## 因此 [code]damage_reduce[/code] 分类判定、0~60 钳制、本命非线性值（10%→15%、
## 15%→20%）全部沿用效果词表，本模块不重复解析 [code]effect_type[/code]
## （未知/留空类型评估为 0，自然被过滤，不会猜成别的效果）。[br]
## [br][b]信息不足不猜[/b]：模板查不到（CardSystem 未就绪 / 模板缺失 / 模板 ID 为空）时，
## 该绑定不贡献任何数值——不填默认值、不当 0% 之外的近似值。全部来源都取不到时
## 返回空数组，由调用方按「无减伤」处理。[br]
## [br][b]参与条件[/b]：跳过暂挂绑定（[member BindingRecord.is_suspended]——角色离场期
## 减伤不应生效）。[br]
## [br][b]同名叠层放大[/b]：一条 [code]BindingRecord[/code] 贡献一份，但按叠层放大——
## [code]贡献 = pct × stack_multiplier^(stack_count-1)[/code]，与数值类叠加公式同口径
## （GDD §10：「受到伤害降低」归入[b]可叠加放大类[/b]，与免疫/概率/持续回合等五类并列；
## §3 叠加公式给出 stack_multiplier）。[code]stack_multiplier[/code] 读模板字段
## [member CardTemplate.stack_multiplier]（默认 1.5），模板未声明时回退
## [constant DEFAULT_STACK_MULTIPLIER]。例：10% 卡叠 2 层 → 15%，叠 3 层 → 22.5%。[br]
## [br]来源: GDD combat-system.md §公式、GDD binding-system.md §10 / §3、DEBT-CBT-018-8。

## 同名叠加默认系数——GDD §3「stack_multiplier: 1.2-2.0，默认 1.5」。
const DEFAULT_STACK_MULTIPLIER: float = 1.5

## 效果评估器——单卡减伤百分比与词表对齐的唯一入口。
const EvaluatorScript: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")

## 空快照——[code]damage_reduce[/code] 分支只读卡片自身数值，不读目标 HP/ATK。
const SnapshotScript: GDScript = preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

## 父节点引用——BindingManager 实例（经 [method get_binding] 等公共 API 取数）。
var _parent: Node = null

## 惰性创建的效果评估器实例（无状态，可复用）。
var _evaluator: RefCounted = null


## 构造——传入 BindingManager 引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 汇总某角色全部生效绑定的百分比减伤。[br]
## [br][param character_id] 角色 ID。[br]
## [br][b]返回[/b]: [code]Array[float][/code]——各来源的减伤百分比（如 [code][10.0, 15.0][/code]）；
## 无绑定 / 无减伤卡 / 取不到模板时返回空数组（= 无减伤，不臆造 0）。
func collect(character_id: int) -> Array:
	var pcts: Array = []
	if _parent == null or character_id < 0:
		return pcts
	var ids: Array = _parent.call("get_binding_ids_by_character", character_id)
	for binding_id: int in ids:
		var record: Variant = _parent.call("get_binding", binding_id)
		if record == null or bool(record.get("is_suspended")):
			continue
		var pct: float = _reduction_pct_of(record)
		if pct > 0.0:
			pcts.append(pct)
	return pcts


## 单条绑定的减伤百分比——基础 pct 经同名叠层放大：
## [code]pct × stack_multiplier^(stack_count-1)[/code]。模板取不到或评估为 0 时返回 0.0（调用方跳过）。
func _reduction_pct_of(record: Object) -> float:
	var template: Variant = _read_template(record.get("card_template_id"))
	if template == null:
		return 0.0
	var eval: RefCounted = _get_evaluator().evaluate_effect(
		_card_data(record, template), int(record.get("bound_character_id")),
		SnapshotScript.new())
	var base_pct: float = float(eval.get("damage_reduction_pct"))
	if base_pct <= 0.0:
		return 0.0
	return base_pct * _stack_factor(record, template)


## 同名叠层放大系数——[code]stack_multiplier^(stack_count-1)[/code]（stack_count=1 → 1.0）。
## [br][b]系数来源[/b]：模板 [member CardTemplate.stack_multiplier]（GDD §3 可配置项）；
## 模板未声明（≤0）时回退 [constant DEFAULT_STACK_MULTIPLIER]。stack_count 缺省按 1 层。
func _stack_factor(record: Object, template: Object) -> float:
	var count: int = int(record.get("stack_count"))
	if count <= 1:
		return 1.0
	var multiplier: float = float(template.get("stack_multiplier"))
	if multiplier <= 0.0:
		multiplier = DEFAULT_STACK_MULTIPLIER
	return pow(multiplier, count - 1)


## 构造评估输入——只放效果词表与减伤相关的四个字段（含本命覆盖）。
func _card_data(record: Object, template: Object) -> Dictionary:
	return {
		"effect_type": template.get("effect_type"),
		"effect_value": template.get("effect_value"),
		"native_effect_value": template.get("native_effect_value"),
		"is_native": record.get("is_native"),
	}


## 按模板 ID 查模板——CardSystem 不可用或模板缺失时返回 null（信息不足）。
func _read_template(template_id: Variant) -> Variant:
	var card_system: Node = _autoload(&"CardSystem")
	if card_system == null or not card_system.has_method(&"get_template"):
		return null
	var id: StringName = StringName(template_id)
	if id == &"":
		return null
	return card_system.call(&"get_template", id)


## 惰性获取评估器。
func _get_evaluator() -> RefCounted:
	if _evaluator == null:
		_evaluator = EvaluatorScript.new()
	return _evaluator


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
