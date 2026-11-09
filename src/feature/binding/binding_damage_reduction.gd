extends RefCounted
## BindingDamageReduction —— 绑定卡的百分比减伤汇总（DEBT-CBT-018-8 残留闭环）。[br]
## [br][b]职责[/b]：把「某角色身上绑了哪些 [code]damage_reduce[/code] 卡」收敛成一份
## 减伤来源列表（百分比数组），供战斗 Attack 阶段写入攻击队列条目的
## [code]damage_reduction_pcts[/code]。[br]
## [br][b]本模块不算最终伤害[/b]：乘算叠加与 60% 封顶由
## [method CardEffectEvaluator.combine_damage_reduction] 统一负责
## （GDD combat-system.md §公式：「伤害 × 0.9 × 0.85 …，上限 60%」）——
## 这里只回答「有哪些来源、各是多少」。[br]
## [br][b]单卡数值口径[/b]：与 AI 干跑同一入口 [method CardEffectEvaluator.evaluate_effects]
## （多效果汇总），因此 [code]damage_reduce[/code] 分类判定、0~60 钳制、本命非线性值
## （10%→15%、15%→20%）全部沿用效果词表，本模块不重复解析 [code]effect_type[/code]
## （未知/留空类型评估为 0，自然被过滤，不会猜成别的效果）。[br]
## [br][b]迁移后不丢减伤[/b]（DEBT-CBT-018-10）：此前本模块直接读模板[b]扁平[/b]字段
## （[code]effect_type[/code] / [code]effect_value[/code]），减伤卡一旦迁到
## [member CardTemplate.effects] 并清空扁平字段，这里会[b]静默读出 0%[/b]
## （不报错、不崩溃，玩家侧只表现为减伤消失）。改走 [method
## CardEffectEvaluator.evaluate_effects] 后：未迁移卡（[code]effects[/code] 为空）
## 由汇总器合成一条走同一个评估器，行为逐位不变；已迁移卡取列表汇总值。[br]
## [br][b]信息不足不猜[/b]：模板查不到（CardSystem 未就绪 / 模板缺失 / 模板 ID 为空）时，
## 该绑定不贡献任何数值——不填默认值、不当 0% 之外的近似值。全部来源都取不到时
## 返回空数组，由调用方按「无减伤」处理。[br]
## [br][b]参与条件[/b]：跳过暂挂绑定（[member BindingRecord.is_suspended]——角色离场期
## 减伤不应生效）。[br]
## [br][b]同名叠层放大[/b]：一条 [code]BindingRecord[/code] 贡献一份，但按叠层放大——
## [code]贡献 = 汇总pct × stack_multiplier^(stack_count-1)[/code]，[b]作用在汇总 pct
## 之上[/b]（不是逐条放大后再汇总），与 [method BindingManager.get_binding_context]
## 的 multiplier 口径一致（GDD §10：「受到伤害降低」归入[b]可叠加放大类[/b]，
## 与免疫/概率/持续回合等五类并列；§3 叠加公式给出 stack_multiplier）。系数取数
## （模板字段 → 默认 1.5 回退）统一走 [BindingStackFactor]，不在本模块另写一份。
## 例：10% 卡叠 2 层 → 15%，叠 3 层 → 22.5%。[br]
## [br]来源: GDD combat-system.md §公式、GDD binding-system.md §10 / §3、DEBT-CBT-018-8 /
## DEBT-CBT-018-10。

## 同名叠层放大系数取数模块——与 get_binding_context 的唯一共用口径。
const StackFactor := preload("res://src/feature/binding/binding_stack_factor.gd")

## 效果评估器——单卡减伤百分比与词表对齐的唯一入口。
const EvaluatorScript: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")

## 效果条目类型——取「打出即生效」的触发时机常量。
const EntryScript: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 评估快照类型——减伤条目只读卡片自身数值，但上下限仍走快照契约。
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


## 单条绑定的减伤百分比——[b]聚合后的 pct[/b] 经同名叠层放大：
## [code]pct × stack_multiplier^(stack_count-1)[/code]。模板取不到或评估为 0 时返回 0.0（调用方跳过）。[br]
## [br][b]放大作用在汇总值之上[/b]：一张卡挂多条减伤时先汇总（乘算 + 60% 封顶，
## 由 [method CardEffectEvaluator.combine_damage_reduction] 唯一实现），再乘叠层系数——
## 与 [method BindingManager.get_binding_context] 的 multiplier 口径一致
## （GDD §10「叠层放大先于多来源乘算合并发生」：这里的「多来源」指多条[b]绑定[/b]，
## 同一个 binding 内的多条条目先合成一份来源）。
func _reduction_pct_of(record: Object) -> float:
	var template: Variant = StackFactor.read_template(record.get("card_template_id"))
	if template == null:
		return 0.0
	var eval: RefCounted = _get_evaluator().evaluate_effects(
		template, int(record.get("bound_character_id")), _snapshot(record),
		EntryScript.TRIGGER_ON_PLAY, _context(record))
	var base_pct: float = float(eval.get("damage_reduction_pct"))
	if base_pct <= 0.0:
		return 0.0
	return base_pct * StackFactor.stack_factor(int(record.get("stack_count")), template)


## 卡片级上下文——把绑定的本命状态交给评估器（[code]is_native[/code] 在 BindingRecord 上，
## 不在模板里；缺了它本命减伤会退回基础值）。只给这一个键，不搬运效果字段。
func _context(record: Object) -> Dictionary:
	return {"is_native": bool(record.get("is_native"))}


## 评估快照——减伤条目只读卡片自身数值，不读目标 HP/ATK，故给空快照即可
## （汇总器仍会按快照重算溢出标记，空快照下不影响减伤字段）。
func _snapshot(record: Object) -> RefCounted:
	var character_id: int = int(record.get("bound_character_id"))
	return SnapshotScript.build({character_id: {"hp": 0, "max_hp": 0}})


## 惰性获取评估器。
func _get_evaluator() -> RefCounted:
	if _evaluator == null:
		_evaluator = EvaluatorScript.new()
	return _evaluator
