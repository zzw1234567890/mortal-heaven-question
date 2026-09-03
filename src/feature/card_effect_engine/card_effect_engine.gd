extends Node
# class_name CardEffectEngine —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突（同 GSM/StatusEffectSystem/ResourceSystem 先例）。

## CardEffectEngine —— 卡牌效果解析引擎 Autoload（#10）。
##
## Feature 层 Autoload。采用双层对象模型——EffectTemplate（Resource, .tres, 只读）+
## EffectBase 运行时实例（RefCounted 子类层级）。
## Sprint 8 Story 8-8：持有子模块实例（PRDEngine / CardEffectEvaluator / ResolutionStack），
## _ready() 从 GSM 获取种子注入 PRDEngine，暴露 getter 供外部访问。
##
## [b]信号路由[/b]（ADR-0007 合规）：Cat 2b 信号发射时经 GSM._emit_signal_safe 路由。
##
## 来源: ADR-0009 §信号路由。

# === 信号声明（Cat 2b）============================================================

## 效果注册到角色时发射（Story 002/003 发射）。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int], target_id: int}[/code]
signal effect_registered(payload: Dictionary)

## 效果从角色移除时发射。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int], target_id: int, reason: String}[/code]
signal effect_removed(payload: Dictionary)

## 效果暂挂时发射（角色离场）。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int], reason: String}[/code]
signal effect_suspended(payload: Dictionary)

## 效果恢复时发射（角色重新上场）。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int]}[/code]
signal effect_restored(payload: Dictionary)

## 触发链栈溢出警告时发射（深度超限）。[br]
## [br][b]payload 结构[/b]: [code]{root_card_id: int, depth: int, chain: Array[int]}[/code]
signal stack_overflow_warning(payload: Dictionary)


# === 子模块实例（Sprint 8 Story 8-8 接线）=====================================

## PRD 引擎——伪随机分布判定。
var _prd_engine: PRDEngine = null

## 效果评估器——AI 干跑评估（纯计算）。
var _evaluator: CardEffectEvaluator = null

## 结算栈——优先级队列 + LIFO 出栈。
var _resolution_stack: ResolutionStack = null


# === 生命周期 =====================================================================

## _ready() 初始化子模块——从 GSM 获取种子注入 PRDEngine。[br]
## GSM 不可用时使用默认种子 0——生产环境不应发生。
func _ready() -> void:
	var seed_value: int = 0
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("get"):
		var meta = gsm.get("meta")
		if meta is Dictionary and meta.has("seed"):
			seed_value = int(meta["seed"])
	_prd_engine = PRDEngine.new()
	_prd_engine.reset_prng_seed(seed_value)
	_evaluator = CardEffectEvaluator.new()
	_resolution_stack = ResolutionStack.new()


## 查询 PRD 引擎实例。
func get_prd_engine() -> PRDEngine:
	if _prd_engine == null:
		_prd_engine = PRDEngine.new()
		_prd_engine.reset_prng_seed(0)
	return _prd_engine


## 查询效果评估器实例。
func get_evaluator() -> CardEffectEvaluator:
	if _evaluator == null:
		_evaluator = CardEffectEvaluator.new()
	return _evaluator


## 查询结算栈实例。
func get_resolution_stack() -> ResolutionStack:
	if _resolution_stack == null:
		_resolution_stack = ResolutionStack.new()
	return _resolution_stack


## 构建评估快照——从 GSM 角色数据构建 GameStateSnapshot。[br]
## [b]桩实现[/b]——返回空快照，后续 Story 接线 DeploymentSystem 角色数据。
func create_evaluation_snapshot() -> GameStateSnapshot:
	return GameStateSnapshot.new({})


## 查找 GSM Autoload。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


# === 生命周期方法（Sprint 8 Story 8-7 薄包装——默认桩行为）===================

## 注册持续效果——绑定卡落位时调用。[br]
## [br][b]桩实现[/b]——不产生实际效果，仅作接缝。后续 Story 接线 card_effect_evaluator。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][param template_id] 卡牌模板 ID。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][param context] 绑定上下文 Dictionary。
func register_persistent_effect(card_instance_id: int, template_id: StringName, character_id: int, context: Dictionary) -> void:
	pass


## 按来源移除效果——绑定卡移除/覆盖/阵亡时调用。[br]
## [br][b]桩实现[/b]——不产生实际效果。[br]
## [br][param card_instance_id] 卡牌实例 ID。
func remove_effects_by_source(card_instance_id: int) -> void:
	pass


## 按来源暂挂效果——角色离场时调用。[br]
## [br][b]桩实现[/b]——不产生实际效果。[br]
## [br][param character_id] 角色 ID。[br]
## [br][param card_ids] 卡牌实例 ID 列表。
func suspend_effects_by_source(character_id: int, card_ids: Array) -> void:
	pass


## 按来源恢复效果——角色重新上场时调用。[br]
## [br][b]桩实现[/b]——不产生实际效果。[br]
## [br][param character_id] 角色 ID。[br]
## [br][param card_ids] 卡牌实例 ID 列表。
func restore_effects_by_source(character_id: int, card_ids: Array) -> void:
	pass


## 查询单卡数值加成——BindingManager.get_accumulated_bonus 调用。[br]
## [br][b]桩实现[/b]——返回 0.0（无加成）。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][param stat_name] 属性名。[br]
## [br][b]返回[/b]: 加成值 float。
func get_stat_bonus(card_instance_id: int, stat_name: String) -> float:
	return 0.0


## 验证卡牌实例是否仍存在——BindingManager.restore_bindings 调用。[br]
## [br][b]桩实现[/b]——返回 true（假设存在）。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][b]返回[/b]: true 表示存在。
func card_exists(card_instance_id: int) -> bool:
	return true
