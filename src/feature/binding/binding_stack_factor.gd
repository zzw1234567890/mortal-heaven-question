extends RefCounted
## BindingStackFactor —— 同名叠层放大系数的[b]唯一取数口径[/b]。
##
## 两处消费者共用本模块，避免同一规则出现两套实现（口径分叉即数值分叉）：
##   · [method BindingManager.get_binding_context] —— 预计算 multiplier 供效果引擎查询
##     （ADR-0013 §同名叠加乘法公式：「CardEffectEngine 查询预计算的 multiplier 乘积，
##     不在引擎中重复计算」）；[br]
##   · [BindingDamageReduction] —— 减伤百分比单条贡献的叠层放大
##     （GDD binding-system.md §10「受到伤害降低」属可叠加放大类）。
##
## [b]系数来源[/b]：卡牌模板 [member CardTemplate.stack_multiplier]（GDD §3 可配置项，1.2~2.0）。[br]
## [b]回退口径[/b]：模板取不到 / 未声明该字段 / 值 ≤ 0 一律回退
## [constant DEFAULT_STACK_MULTIPLIER]——不臆造 0 或 1.0。[br]
## [code]stack_count ≤ 1[/code] 时恒为 1.0（不做 pow，公式退化项）。
##
## [br][b]模板存在性不在此判定[/b]：[method read_template] 返回 [code]null[/code] 只表示
## 「查不到」，由调用方决定是跳过该来源（减伤路径：信息不足不猜）还是按默认系数继续
## （[method BindingManager.get_binding_context]：上下文必须给出 multiplier）。
##
## 来源: ADR-0013 §同名叠加乘法公式 / GDD binding-system.md §3 叠加公式 §10 非数值效果叠加。

## 默认叠加乘数——GDD §3「stack_multiplier: 1.2-2.0，默认 1.5」。
const DEFAULT_STACK_MULTIPLIER: float = 1.5


## 按模板 ID 查模板——CardSystem 不可用 / 模板 ID 为空 / 模板缺失时返回 [code]null[/code]。[br]
## [br][param template_id] 卡牌模板 ID（StringName / String / 可转字符串的 Variant）。[br]
## [br][b]返回[/b]: [code]CardTemplate[/code] 或 [code]null[/code]。
static func read_template(template_id: Variant) -> Variant:
	var card_system: Node = _autoload(&"CardSystem")
	if card_system == null or not card_system.has_method(&"get_template"):
		return null
	var id: StringName = StringName(template_id)
	if id == &"":
		return null
	return card_system.call(&"get_template", id)


## 解析模板的每层叠加乘数——模板为空 / 无该字段 / 值 ≤ 0 时回退默认 1.5。[br]
## [br][param template] 模板对象（[code]CardTemplate[/code]）或同名字段的 Dictionary / null。[br]
## [br][b]返回[/b]: 每层叠加乘数（恒 > 0）。
static func multiplier_of(template: Variant) -> float:
	if template == null:
		return DEFAULT_STACK_MULTIPLIER
	var raw: Variant = template.get("stack_multiplier")
	if raw == null:
		return DEFAULT_STACK_MULTIPLIER
	var multiplier: float = float(raw)
	if multiplier <= 0.0:
		return DEFAULT_STACK_MULTIPLIER
	return multiplier


## 叠层放大系数——[code]stack_multiplier^(stack_count-1)[/code]（[code]stack_count ≤ 1[/code] → 1.0）。[br]
## [br][param stack_count] 同名叠加张数（含本实例，≥1）。[br]
## [br][param template] 模板对象 / Dictionary / null（null 走默认系数）。[br]
## [br][b]返回[/b]: 放大系数 float。
static func stack_factor(stack_count: int, template: Variant) -> float:
	if stack_count <= 1:
		return 1.0
	return pow(multiplier_of(template), stack_count - 1)


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
static func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
