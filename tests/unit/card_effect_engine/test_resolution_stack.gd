extends GutTest
## Story 002 验收测试：ResolutionStack 栈式结算引擎（优先级队列 + LIFO + 中分辨率插入）。
##
## 覆盖 AC-001（激活时间从新到旧）与 AC-002（先发无视激活时间优先）
## + QA Edge cases（同 t 按 card_id 升序、priority 次级决胜、中分辨率插入、栈式 LIFO）。
##
## 用 [EffectBase] 的轻量匿名子类（override _resolve 记录执行顺序）模拟效果——
## 不依赖 Story 001 的 4 个具体子类，聚焦排序语义本身。
##
## [b]测试确定性[/b]：排序键（activation_sequence/priority/card_id）均为显式 int，
## 不涉及时钟/随机——每次运行结果一致。

const ResolutionStackClass := preload("res://src/feature/card_effect_engine/resolution_stack.gd")
const EffectBaseClass := preload("res://src/feature/card_effect_engine/effect_base.gd")


# === 测试辅助 =====================================================================

## 记录 _resolve 执行顺序的轻量效果子类。
class RecordingEffect:
	extends EffectBase

	## 共享的结算记录列表——由测试注入。
	var log: Array = []

	## 记录自身 card_instance_id 到共享 log（模拟结算执行）。
	func _resolve() -> void:
		log.append(source_card_instance_id)


## 构造一个指定字段的效果实例（priority 可选，默认 0）。
func _make_effect(card_id: int, seq: int, priority: int = 0) -> EffectBase:
	var effect := RecordingEffect.new()
	effect.source_card_instance_id = card_id
	effect.activation_sequence = seq
	effect.priority = priority
	return effect


# ============================================================================
# AC-001：激活时间从新到旧（先发均关）
# ============================================================================

func test_ac001_newer_activation_sequence_resolves_first() -> void:
	## A（t=3）与 B（t=5）同为普通己方效果——B 先于 A。
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.set_sort_context(-1, {}, {1: true, 2: true})  # 两效果均己方、非先发
	var a := _make_effect(1, 3)
	var b := _make_effect(2, 5)
	var log: Array = []
	a.log = log
	b.log = log

	stack.push(a)
	stack.push(b)
	stack.resolve_all(func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))

	assert_eq(log, [2, 1], "较新的效果 B(t=5) 应先于 A(t=3)")


func test_ac001_same_sequence_ties_by_card_id_ascending() -> void:
	## QA Edge：t 相同 → 按 card_instance_id 升序决胜。
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.set_sort_context(-1, {}, {10: true, 20: true})
	var a := _make_effect(10, 5)
	var b := _make_effect(20, 5)
	var log: Array = []
	a.log = log
	b.log = log

	stack.push(b)  # 入队顺序故意反序，验证排序而非入队顺序
	stack.push(a)
	stack.resolve_all(func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))

	assert_eq(log, [10, 20], "同 t 应按 card_instance_id 升序")


# ============================================================================
# AC-002：先发无视激活时间优先
# ============================================================================

func test_ac002_first_strike_beats_newer_normal() -> void:
	## A（先发，t=1）与 B（普通，t=10）——A 先于 B，尽管 A 激活更早。
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.set_sort_context(-1, {1: true}, {1: true, 2: true})
	var a := _make_effect(1, 1)
	var b := _make_effect(2, 10)
	var log: Array = []
	a.log = log
	b.log = log

	stack.push(b)
	stack.push(a)
	stack.resolve_all(func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))

	assert_eq(log, [1, 2], "先发效果 A 应无视激活时间先于普通 B")


func test_ac002_two_first_strike_order_by_activation_desc() -> void:
	## QA Edge：两个先发效果之间仍按激活时间从新到旧。
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.set_sort_context(-1, {1: true, 2: true}, {1: true, 2: true})
	var a := _make_effect(1, 3)
	var b := _make_effect(2, 5)
	var log: Array = []
	a.log = log
	b.log = log

	stack.push(a)
	stack.push(b)
	stack.resolve_all(func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))

	assert_eq(log, [2, 1], "两个先发效果应按激活时间从新到旧")


# ============================================================================
# 次级 priority 决胜（同主排序层级 + 同 activation_sequence）
# ============================================================================

func test_priority_breaks_tie_within_same_tier() -> void:
	## QA Edge：同层级同 t → priority 降序（大的先）。
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.set_sort_context(-1, {}, {1: true, 2: true})
	var a := _make_effect(1, 5, 10)
	var b := _make_effect(2, 5, 20)
	var log: Array = []
	a.log = log
	b.log = log

	stack.push(a)
	stack.push(b)
	stack.resolve_all(func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))

	assert_eq(log, [2, 1], "priority 更高者（b=20）应优先")


# ============================================================================
# 5 级主排序：主动出牌 > 先发己方 > 普通己方 > 敌方
# ============================================================================

func test_full_priority_tier_ordering() -> void:
	var stack: ResolutionStack = ResolutionStackClass.new()
	# 主动出牌 = card 99；先发 = card 1；普通己方 = card 2；敌方 = card 3
	stack.set_sort_context(99, {1: true}, {1: true, 2: true})

	var active := _make_effect(99, 1)   # 主动出牌（t 最小，但仍应第一）
	var first := _make_effect(1, 2)     # 先发己方
	var normal := _make_effect(2, 100)  # 普通己方（t 最大，但仍排在先发后）
	var enemy := _make_effect(3, 999)   # 敌方（t 最大，仍排最后）
	var log: Array = []
	active.log = log
	first.log = log
	normal.log = log
	enemy.log = log

	stack.push(enemy)   # 入队顺序乱序
	stack.push(normal)
	stack.push(first)
	stack.push(active)
	stack.resolve_all(func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))

	assert_eq(log, [99, 1, 2, 3], "5 级主排序：主动出牌 > 先发己方 > 普通己方 > 敌方")


# ============================================================================
# 中分辨率插入：结算期间 push 新效果按优先级插入
# ============================================================================

func test_mid_resolution_insert_respects_priority() -> void:
	## 效果 A（普通己方，t=1）结算时触发 B（先发己方）——
	## B 应立即插入尚未结算队列的前方，先于队列中残留的敌方效果 C。
	## 注意：C 必须是「敌方」（不在 player_side），否则 C 与 A 同层级且 t 更大，
	## 会先于 A 出栈——无法验证 A 触发 B 的插入语义。
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.set_sort_context(-1, {1: true}, {1: true, 2: true})  # 3=敌方（不在 player_side）
	var a := _make_effect(2, 1)  # 普通己方 A
	var c := _make_effect(3, 5)  # 敌方 C（已在队列，t 更大但层级最低）
	var b := _make_effect(1, 2)  # 先发己方 B（结算期间由 A 触发）

	stack.push(a)
	stack.push(c)

	var log: Array = []
	var resolver := func(effect: EffectBase) -> void:
		log.append(effect.source_card_instance_id)
		if effect.source_card_instance_id == 2:  # A 结算时触发 B
			stack.push(b)

	stack.resolve_all(resolver)

	assert_eq(log, [2, 1, 3], "中分辨率插入：A(2) 触发 B(1 先发) 应先于残留敌方 C(3)")


# ============================================================================
# LIFO 出栈语义（栈式触发链的排序基础）
# ============================================================================

func test_lifo_pop_order_within_equal_priority() -> void:
	## 同层级同 t 同 priority 同 card_id 决胜——这里验证 pop 始终弹 back（最高优先级）。
	var stack: ResolutionStack = ResolutionStackClass.new()
	var a := _make_effect(1, 1)
	var b := _make_effect(2, 2)
	var c := _make_effect(3, 3)
	stack.push(a)
	stack.push(b)
	stack.push(c)
	assert_eq(stack.peek().source_card_instance_id, 3, "peek 应看到最高优先级 c")
	assert_eq(stack.pop().source_card_instance_id, 3, "pop 应弹最高优先级 c")
	assert_eq(stack.pop().source_card_instance_id, 2, "其次 b")
	assert_eq(stack.pop().source_card_instance_id, 1, "最后 a")
	assert_true(stack.is_empty(), "出栈后为空")


# ============================================================================
# 空栈 / null 防御
# ============================================================================

func test_empty_stack_pop_returns_null() -> void:
	var stack: ResolutionStack = ResolutionStackClass.new()
	assert_eq(stack.pop(), null, "空栈 pop 应返回 null")
	assert_eq(stack.peek(), null, "空栈 peek 应返回 null")
	assert_true(stack.is_empty(), "空栈 is_empty 为 true")
	assert_eq(stack.size(), 0, "空栈 size 为 0")


func test_push_null_ignored() -> void:
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.push(null)
	assert_eq(stack.size(), 0, "push null 应被忽略")


func test_resolve_all_empty_returns_zero() -> void:
	var stack: ResolutionStack = ResolutionStackClass.new()
	var count: int = stack.resolve_all(func(effect: EffectBase) -> void: pass)
	assert_eq(count, 0, "空栈 resolve_all 应返回 0")


# ============================================================================
# 排序上下文隔离
# ============================================================================

func test_clear_sort_context_degrades_to_field_sorting() -> void:
	## 清空上下文后，所有效果均为「敌方」层级，退化为 activation_sequence 降序。
	var stack: ResolutionStack = ResolutionStackClass.new()
	stack.set_sort_context(1, {1: true}, {1: true})
	stack.clear_sort_context()
	var a := _make_effect(10, 1)
	var b := _make_effect(20, 2)
	var log: Array = []
	a.log = log
	b.log = log
	stack.push(a)
	stack.push(b)
	stack.resolve_all(func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))
	assert_eq(log, [20, 10], "清空上下文后按 activation_sequence 降序")
