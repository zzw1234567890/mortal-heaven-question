## BindingManager 定义层（继承链首段）——[b]信号、常量、实例字段、依赖注入[/b]住在这一层。
##
## [b]为什么拆出这一层[/b]：[code]binding_manager.gd[/code] 732 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。拆法用[b]继承链[/b]而非组合——产品代码、7 个既有
## 测试文件，以及三个 RefCounted 子模块（BindingSlotOps / BindingDamageReduction /
## BindingSerializer）全都直取这个面：前者写 [code]bm.call("bind_card", ...)[/code] /
## [code]bm.get("_bindings")[/code] / [code]bm.set("stat_bonus_cb", ...)[/code] /
## [code]BM_SCRIPT.NATIVE_MULTIPLIER[/code]，后者经
## [code]_parent.get("_next_binding_id")[/code] 这类动态分派回取。组合式拆分要给每个成员
## 补一层转发器，而转发器与实体漂移是[b]静默失效[/b]——[code]call / get / set[/code] 传错
## 名字不报语法错，只 push_error 或静默返回 null。守卫用例
## （[code]tests/unit/binding_system/test_binding_public_face_lock.gd[/code]）实测：
## 常量 / 信号 / 实例字段 / 方法与 [method Object.get] / [method Object.set] /
## [method Object.call] [b]都沿继承链解析[/b]，故逐字搬家即逐位等价，无需转发器。[br]
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  binding_manager_contract.gd [/code] ← 本层：7 信号 / 4 常量 / 16 实例字段 / 依赖注入[br]
## [code]  binding_manager_registry.gd [/code] ← 存取层：三索引读写 + 查询 API + 绑定位上限[br]
## [code]  binding_manager_compute.gd  [/code] ← 计算层：叠加公式 / 加成汇总 / 减伤来源 / 上下文[br]
## [code]  binding_manager_serialize.gd[/code] ← 序列化层：记录序列化 + 快照导出 / 恢复[br]
## [code]  binding_manager.gd          [/code] ← 链尾：绑定生命周期编排（Autoload 入口不变）[br]
##
## [b]本层职责[/b]：[b]定义面[/b]——Cat 2b 生命周期信号的载荷形状（值即契约）、四个脚本常量、
## 全部实例字段（三索引 + 子模块引用 + 存根回调接缝），以及依赖注入口径
## （[method _inject_callbacks] 的 8 个 Callable 接线 + [method _get_gsm] 的动态取用）。[br]
##
## [b]信号只声明一处[/b]：重复声明会被当成两个不同信号，发了外部连不上——故 7 个 Cat 2b 信号
## 全部落在本层，由链上各段发射（探针已验证基类信号可在派生段 emit）。[br]
##
## 来源: ADR-0013 §决策 §对象模型 §Cat 2b 信号 §关键接口 / GDD binding-system.md §1 绑定数据结构、
## .claude/docs/coding-standards.md §文件行数限制。
extends Node


# === Cat 2b 生命周期信号（ADR-0013 §Cat 2b 信号，经 GSM._emit_signal_safe 路由）====

## 绑定成功——新卡落位（含 is_native 标志，CombatUI 据此创建图标/动画 + 本命星标）。
signal binding_applied(binding_id: int, card_instance_id: int, template_id: StringName, character_id: int, slot_type: int, is_native: bool)


## 绑定解除（reason 区分阵亡 'death' / 覆盖 'overwritten' / 移除 'removed'）。
signal binding_removed(binding_id: int, card_instance_id: int, character_id: int, reason: String)


## 覆盖完成（携带 old/new binding_id，UI 据此替换图标 + 过渡动画）。
signal binding_overwritten(old_binding_id: int, new_binding_id: int, character_id: int, slot_index: int)


## 同名叠加（携带 new_stack_count，UI 据此更新 "+1层" 文字特效 + 层数徽章）。
signal binding_stacked(binding_id: int, template_id: StringName, character_id: int, new_stack_count: int)


## 角色离场暂挂（携带 binding_ids: Array[int]，UI 据此图标灰显+半透明）。
signal binding_suspended(character_id: int, binding_ids: Array[int])


## 角色重新上场恢复（携带 binding_ids: Array[int]，UI 据此图标恢复色彩）。
signal binding_restored(character_id: int, binding_ids: Array[int])


## 本命绑定激活（CombatUI 据此点亮 ★金色星标 + Audio 金色共鸣音）。
signal native_activated(binding_id: int, template_id: StringName, character_id: int)


# === 实例字段：三索引 + 子模块引用 =============================================

## 绑定主索引——[code]key=binding_id[/code] → [BindingRecord]。
var _bindings: Dictionary[int, BindingRecord] = {}


## 角色 → 绑定 ID 列表索引——[code]key=character_id[/code] → [code]Array[int][/code]。
## 零分配热路径查询 [method get_binding_ids_by_character] 直接返回已有数组引用。[br]
## [b]声明为无类型 [code]Dictionary[/code][/b]——[code]Dictionary[int, Array[int]][/code] 是
## 嵌套类型化集合，Godot 4.6 GDScript 不支持（"Nested typed collections are not supported"）。
## 值仍为 [code]Array[int][/code]，类型保证由 [method _register_binding] 的构造路径维护。
var _by_character: Dictionary = {}


## 卡牌实例 → 角色反向索引——[code]key=card_instance_id[/code] → [code]character_id[/code]。
## O(1) 反向查询 [method get_character_by_card]。
var _card_to_character: Dictionary[int, int] = {}


## 槽位操作子模块（Sprint 12 Story 2 拆分）。
var _slot_ops: RefCounted = null


## 百分比减伤汇总子模块（DEBT-CBT-018-8 残留闭环——绑定卡减伤接入攻击队列）。
var _damage_reduction: RefCounted = null


# === 常量 ========================================================================

## 本命加成乘数——[code]native_owner[/code] 匹配且本命位空闲时锁定 1.5（ADR-0013 §本命绑定判定算法）。
const NATIVE_MULTIPLIER: float = 1.5


## 同名叠层放大系数取数模块——与减伤路径（[BindingDamageReduction]）的[b]唯一共用口径[/b]：
## 模板 [member CardTemplate.stack_multiplier] → 缺失回退 1.5。
const StackFactor := preload("res://src/feature/binding/binding_stack_factor.gd")


## 默认叠加乘数——GDD §3「默认 1.5」。仅作为 [constant StackFactor] 的公开别名保留
## （向后兼容既有引用），取数逻辑不在本文件重复实现。
const DEFAULT_STACK_MULTIPLIER: float = StackFactor.DEFAULT_STACK_MULTIPLIER


## 默认绑定位上限——RealmSystem 槽位数据缺失时的保守回退（炼气基准 1，防止越界分配）。
const DEFAULT_SLOT_LIMIT: int = 1


# === 实例字段：内部状态 ==========================================================

## 绑定 ID 单调递增分配器——每次注册新 BindingRecord 递增。
var _next_binding_id: int = 1


## 绑定位上限缓存——[code]{slot_type: limit}[/code]。由 [method cache_slot_limits] 在战斗开始时填充。
## 战斗期间从 RealmSystem 缓存，不运行时重查（ADR-0013 §绑定上限缓存）。
var _slot_limits: Dictionary = {}


## 序列化子模块——惰性初始化（Sprint 8 Story 8-12 拆分）。
var _serializer: RefCounted = null


# === 存根回调（Story 004 / 战斗 Epic 注入真实实现，sprint §风险登记 存根策略）=====

## 效果引擎 register_persistent_effect 存根——[code](card_instance_id, character_id)[/code]。默认空操作。
var effect_register_cb: Callable = Callable()


## 效果引擎 remove_effects_by_source 存根——[code](card_instance_id)[/code]。默认空操作。
var effect_remove_cb: Callable = Callable()


## 效果引擎 suspend_effects_by_source 存根——[code](character_id, card_ids)[/code]。默认空操作。
var effect_suspend_cb: Callable = Callable()


## 效果引擎 restore_effects_by_source 存根——[code](character_id, card_ids)[/code]。默认空操作。
var effect_restore_cb: Callable = Callable()


## 阵亡洗回牌库存根——[code](card_instance_id)[/code]。默认空操作。
var card_shuffle_cb: Callable = Callable()


## 覆盖旧卡进弃牌堆存根——[code](card_instance_id)[/code]。默认空操作。
var card_discard_cb: Callable = Callable()


## 卡牌实例存在性验证存根——[code](card_instance_id) -> bool[/code]。默认返回 true（假设存在）。
var card_exists_cb: Callable = Callable()


## 单卡数值加成查询存根——[code](card_instance_id, stat_name) -> float[/code]。默认返回 0.0。
var stat_bonus_cb: Callable = Callable()


# === 依赖注入 + 回调/信号路由 ====================================================

##
## _ready() 在 Autoload 实例上注入 8 个回调到 CardEffectEngine + CombatSystem。[br]
## BM_SCRIPT.new() 测试实例不触发 _ready()（未加入 SceneTree），不注入——保留 Callable 接缝。
## 测试通过 bm.set("effect_register_cb", ...) 覆盖注入的回调，行为不变。

func _ready() -> void:
	# 仅 Autoload 实例注入（BM_SCRIPT.new() 未加入 SceneTree 不触发 _ready）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var autoload_bm = tree.root.get_node_or_null("/root/BindingManager")
	if autoload_bm != self:
		return  # 非 Autoload 实例——不注入
	_inject_callbacks()


## 惰性注入回调——_ready() 或脚本替换后调用。[br]
## 仅在 Callable 为空时填充，不覆盖测试注入的回调。
func _inject_callbacks() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	# 注入回调到 CardEffectEngine
	var cee = tree.root.get_node_or_null("/root/CardEffectEngine")
	if cee != null:
		if effect_register_cb.is_null():
			effect_register_cb = Callable(cee, "register_persistent_effect")
		if effect_remove_cb.is_null():
			effect_remove_cb = Callable(cee, "remove_effects_by_source")
		if effect_suspend_cb.is_null():
			effect_suspend_cb = Callable(cee, "suspend_effects_by_source")
		if effect_restore_cb.is_null():
			effect_restore_cb = Callable(cee, "restore_effects_by_source")
		if stat_bonus_cb.is_null():
			stat_bonus_cb = Callable(cee, "get_stat_bonus")
		if card_exists_cb.is_null():
			card_exists_cb = Callable(cee, "card_exists")
	# 注入回调到 CombatSystem（牌库操作）
	var cs = tree.root.get_node_or_null("/root/CombatSystem")
	if cs != null:
		if card_shuffle_cb.is_null():
			card_shuffle_cb = Callable(cs, "add_card_to_deck")
		if card_discard_cb.is_null():
			card_discard_cb = Callable(cs, "add_card_to_discard")


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## 非 Autoload 测试实例（BM_SCRIPT.new()）下 GSM 仍为全局 Autoload，可正常路由。[br]
## [br][param signal_name] 信号名。[br]
## [br][param args] 参数数组。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(self, signal_name, args)
	else:
		var call_args: Array = [signal_name]
		call_args.append_array(args)
		callv("emit_signal", call_args)


## 调用存根回调——空 Callable 或无效 Callable 跳过。[br]
## [br][param cb] 待调用的 Callable。[br]
## [br][param args] 参数数组。
func _invoke_cb(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)


## 动态获取 GSM Autoload 节点。[br]
## 用 SceneTree.root 查找而非硬引用全局名——避免测试环境无 Autoload 时崩溃
## （同 DeploymentSystem._get_gsm 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")
