extends RefCounted
## CombatAttackCoverage —— Attack 阶段的防御方百分比减伤覆盖（DEBT-CBT-018-8 残留闭环）。[br]
## [br][b]职责[/b]：遍历攻击队列，把每条攻击的[b]防御方[/b]（[code]target_id[/code]）
## 身上生效的百分比减伤汇总写入条目键 [code]damage_reduction_pcts[/code]，
## 供 [method CombatDamageCalculator.resolve_attack_queue] 与
## [method CardEffectEvaluator.combine_damage_reduction] 消费。[br]
## [br][b]只写来源不算伤害[/b]：本模块不乘算、不封顶——乘算叠加与 60% 上限只有
## 一处真理来源（GDD combat-system.md §公式），避免两套公式漂移。[br]
## [br][b]不覆盖调用方显式值[/b]：条目已有 [code]damage_reduction_pcts[/code] 时原样保留
## （UI / 脚本 / 测试可显式给定，如一次性格挡卡）。[br]
## [br][b]信息不足不猜[/b]：BindingManager 不可用、角色无绑定、来源全部取不到时，
## 不写该键也不写空占位——下游按「无减伤」（[code][] [/code] 缺省）处理，
## 与队列条目缺省语义一致。[br]
## [br]来源: GDD combat-system.md §公式、ADR-0008 §Phase 3/§Phase 4、DEBT-CBT-018-8。

## 父节点引用——CombatSystem 实例（当前仅用于保持子模块模式一致性）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 为队列条目补齐防御方减伤（原地写键）。[br]
## [br][param queue] 攻击队列（[code]Array[Dictionary][/code]）；非字典条目跳过。[br]
## [br][b]返回[/b]: 本次实际写入的条目数（0 = 无来源或全部已有值）。
func annotate_queue(queue: Array) -> int:
	var written: int = 0
	for entry: Variant in queue:
		if not (entry is Dictionary):
			continue
		if (entry as Dictionary).has("damage_reduction_pcts"):
			continue
		var target_id: int = int((entry as Dictionary).get("target_id", -1))
		if target_id < 0:
			continue
		var pcts: Array = _collect_reduction(target_id)
		if pcts.is_empty():
			continue
		(entry as Dictionary)["damage_reduction_pcts"] = pcts
		written += 1
	return written


## 查询某角色的减伤来源——委托 BindingManager 的绑定汇总，取不到时返回空数组。
func _collect_reduction(character_id: int) -> Array:
	var bm: Node = _autoload(&"BindingManager")
	if bm == null or not bm.has_method(&"get_damage_reduction_pcts"):
		return []
	var raw: Variant = bm.call(&"get_damage_reduction_pcts", character_id)
	return raw if raw is Array else []


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
