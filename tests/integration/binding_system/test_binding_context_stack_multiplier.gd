extends GutTest
## get_binding_context() 与减伤路径的叠层系数口径收口测试（DEBT-CBT-018-8）。[br]
## [br]背景：[method BindingManager.get_binding_context] 曾硬编码 [code]stack_multiplier = 1.5[/code]
## （「延后接 CardSystem」的临时值），而减伤路径已改为读模板字段——同一规则两套口径。
## 现两处共用 [BindingStackFactor]：模板字段优先，缺失/≤0 回退 1.5。[br]
## [br]本文件锁定三件事：非 1.5 系数下两条路径取到同一个叠层系数；模板缺失回退 1.5；
## 默认模板（1.5）下既有调用点数值不变（向后兼容）。[br]
## [br]测试策略同 test_damage_reduction_stack_amplify.gd：真实 BindingManager / CardSystem
## Autoload，模板注入 [code]CardSystem.templates[/code] 并在 after_each 还原。

const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const StackFactor := preload("res://src/feature/binding/binding_stack_factor.gd")
const GONGFA: int = BRClass.BindingSlot.GONGFA

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_CTX_MATCH: int = 7501
const CHAR_CTX_MISSING: int = 7502
const CHAR_CTX_ZERO: int = 7503
const CHAR_CTX_DEFAULT: int = 7504
const CHAR_CTX_NATIVE: int = 7505

## 减伤卡基础百分比——两条路径对账时的已知基数。
const BASE_PCT: int = 10

var _binding_ids: Array = []
var _template_backup: Dictionary = {}
var _next_card_id: int = 1


func before_each() -> void:
	_binding_ids.clear()
	_template_backup.clear()
	# 元婴期：每角色 3 个功法位（三层叠加用例的前提）
	BindingManager.cache_slot_limits(GameStateManager.RealmLevel.NASCENT_SOUL)


func after_each() -> void:
	for binding_id: int in _binding_ids:
		BindingManager.remove_binding(binding_id)
	_binding_ids.clear()
	for template_id: StringName in _template_backup.keys():
		var prior: Variant = _template_backup[template_id]
		if prior == null:
			CardSystem.templates.erase(template_id)
		else:
			CardSystem.templates[template_id] = prior
	_template_backup.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## 注入减伤模板——[param multiplier] 为模板声明的每层叠加乘数（≤0 表示未声明）。
func _inject_template(template_id: StringName, multiplier: float,
		native_owner: StringName = &"") -> void:
	_template_backup[template_id] = CardSystem.templates.get(template_id)
	var tpl := CardTemplateClass.new()
	tpl.card_id = template_id
	tpl.type = CardTemplateClass.CardType.TECHNIQUE
	tpl.effect_type = &"damage_reduce"
	tpl.effect_value = BASE_PCT
	tpl.native_effect_value = BASE_PCT + 5
	tpl.native_owner = native_owner
	tpl.stack_multiplier = multiplier
	CardSystem.templates[template_id] = tpl


## 绑定并叠加到指定层数——首张 bind_card，其余逐张 stack_card（共享 binding_id）。
## 返回首个卡牌实例 ID（get_binding_context 的查询键）。
func _bind_stacked(character_id: int, template_id: StringName, target_count: int,
		native_owner: StringName = &"", character_card_id: StringName = &"") -> int:
	var first_card_id: int = 950000 + _next_card_id
	_next_card_id += 1
	var result: Dictionary = BindingManager.bind_card(
			first_card_id, template_id, character_id, GONGFA, native_owner, character_card_id)
	assert_true(bool(result.get("success", false)),
			"前置：%s 应绑定成功（reason=%s）" % [template_id, result.get("reason", "")])
	if not bool(result.get("success", false)):
		return -1
	_binding_ids.append(int(result["binding_id"]))
	for i: int in range(target_count - 1):
		var stacked_card_id: int = 950000 + _next_card_id
		_next_card_id += 1
		var stack_result: Dictionary = BindingManager.stack_card(
				stacked_card_id, template_id, character_id)
		assert_true(bool(stack_result.get("stacked", false)),
				"前置：叠加第 %d 层应成功（reason=%s）" % [i + 2, stack_result.get("reason", "")])
	return first_card_id


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 非 1.5 系数：两条路径取到同一个叠层系数
# ═══════════════════════════════════════════════════════════════════════════════

## 模板 ×2.0、叠 2 层：上下文 multiplier = 1.0 × 2.0^1 = 2.0，减伤 10% × 2.0 = 20%。
func test_binding_context_multiplier_matches_reduction_path_two_stacks() -> void:
	# Arrange——非本命（native_multiplier = 1.0），使上下文 multiplier 即叠层系数
	_inject_template(&"test_ctx_x2", 2.0)
	var card_id: int = _bind_stacked(CHAR_CTX_MATCH, &"test_ctx_x2", 2)
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_CTX_MATCH)
	# Assert
	assert_eq(ctx.get("multiplier"), 2.0, "上下文叠层系数应读模板 ×2.0（非硬编码 1.5）")
	assert_eq(pcts, [20.0], "减伤路径同一系数：10% × 2.0 = 20%")
	assert_almost_eq(float(pcts[0]) / BASE_PCT, float(ctx["multiplier"]), 0.0001,
			"两条路径的叠层系数一致（减伤 / 基础 pct = 上下文 multiplier）")


## 模板 ×2.0、叠 3 层：上下文 multiplier = 2.0^2 = 4.0，减伤 10% × 4.0 = 40%。
func test_binding_context_multiplier_matches_reduction_path_three_stacks() -> void:
	# Arrange
	_inject_template(&"test_ctx_x2", 2.0)
	var card_id: int = _bind_stacked(CHAR_CTX_MATCH, &"test_ctx_x2", 3)
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_CTX_MATCH)
	# Assert
	assert_eq(ctx.get("stack_count"), 3, "上下文应反映 3 层叠加")
	assert_eq(ctx.get("multiplier"), 4.0, "2.0^(3-1) = 4.0")
	assert_eq(pcts, [40.0], "减伤：10% × 4.0 = 40%")
	assert_almost_eq(float(pcts[0]) / BASE_PCT, float(ctx["multiplier"]), 0.0001,
			"两条路径的叠层系数一致")


## 模板 ×1.2（GDD 下限）、叠 3 层：系数 1.44，上下文与减伤同为 1.44。
func test_binding_context_multiplier_matches_reduction_path_lower_bound_multiplier() -> void:
	# Arrange
	_inject_template(&"test_ctx_x12", 1.2)
	var card_id: int = _bind_stacked(CHAR_CTX_MATCH, &"test_ctx_x12", 3)
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_CTX_MATCH)
	# Assert——1.2^2 = 1.44（浮点，用近似断言）
	assert_almost_eq(float(ctx.get("multiplier")), 1.44, 0.0001, "1.2^(3-1) = 1.44")
	assert_almost_eq(float(pcts[0]), BASE_PCT * 1.44, 0.0001, "减伤：10% × 1.44 = 14.4%")
	assert_almost_eq(float(pcts[0]) / BASE_PCT, float(ctx["multiplier"]), 0.0001,
			"两条路径的叠层系数一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 模板缺失 / 未声明：回退 1.5
# ═══════════════════════════════════════════════════════════════════════════════

## 模板在 CardSystem 中不存在：上下文仍给出 1.5^(3-1) = 2.25；减伤路径不臆造来源。
func test_binding_context_falls_back_to_default_when_template_missing() -> void:
	# Arrange——不注入模板，直接以未注册的模板 ID 绑定
	var card_id: int = _bind_stacked(CHAR_CTX_MISSING, &"test_ctx_absent", 3)
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_CTX_MISSING)
	# Assert
	assert_eq(ctx.get("multiplier"), 2.25, "模板缺失回退 1.5：1.5^2 = 2.25")
	assert_eq(pcts, [], "减伤路径模板缺失时不贡献来源（信息不足不猜，不臆造 0%）")


## 模板声明 stack_multiplier = 0（未声明口径）：上下文回退 1.5 → 2.25。
func test_binding_context_falls_back_when_multiplier_not_declared() -> void:
	# Arrange
	_inject_template(&"test_ctx_zero", 0.0)
	var card_id: int = _bind_stacked(CHAR_CTX_ZERO, &"test_ctx_zero", 3)
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	# Assert
	assert_eq(ctx.get("multiplier"), 2.25, "≤0 视为未声明，回退 1.5^2 = 2.25")


## 共用取数模块的直接口径：null 模板 / 无该字段的 Dictionary 都回退 1.5。
func test_stack_factor_defaults_when_template_lacks_field() -> void:
	# Arrange——无 stack_multiplier 键的 Dictionary 等价于「未声明」
	var bare: Dictionary = {"card_id": &"test_bare"}
	# Act & Assert
	assert_eq(StackFactor.multiplier_of(null), 1.5, "null 模板回退 1.5")
	assert_eq(StackFactor.multiplier_of(bare), 1.5, "缺字段回退 1.5")
	assert_eq(StackFactor.stack_factor(3, bare), 2.25, "3 层 → 1.5^2 = 2.25")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 向后兼容与边界
# ═══════════════════════════════════════════════════════════════════════════════

## 默认模板（CardTemplate 默认 1.5）、叠 2 层：数值与改前硬编码 1.5 时完全一致。
func test_binding_context_default_multiplier_keeps_existing_values() -> void:
	# Arrange——注入时显式写 1.5，等同既有模板资产的默认
	_inject_template(&"test_ctx_default", 1.5)
	var card_id: int = _bind_stacked(CHAR_CTX_DEFAULT, &"test_ctx_default", 2)
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_CTX_DEFAULT)
	# Assert
	assert_eq(ctx.get("native_multiplier"), 1.0, "非本命 native_multiplier = 1.0")
	assert_eq(ctx.get("multiplier"), 1.5, "与改前硬编码 1.5 同值（向后兼容）")
	assert_eq(pcts, [15.0], "减伤路径同值：10% × 1.5 = 15%")


## 单层：无论模板系数多少，叠层系数恒为 1.0（公式退化项，不做 pow）。
func test_binding_context_single_stack_ignores_multiplier() -> void:
	# Arrange——模板给高系数，但只有 1 层
	_inject_template(&"test_ctx_x2", 2.0)
	var card_id: int = _bind_stacked(CHAR_CTX_MATCH, &"test_ctx_x2", 1)
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	# Assert
	assert_eq(ctx.get("stack_count"), 1, "仅 1 层")
	assert_eq(ctx.get("multiplier"), 1.0, "1 层不放大（2.0^0 = 1.0）")


## 本命叠层：上下文 multiplier = native 1.5 × 叠层系数；减伤路径本命走原值不乘 1.5——
## 两者共用[b]叠层系数[/b]，本命基数口径的差异是既有设计（GDD §10：叠加乘法与本命乘法独立）。
func test_binding_context_native_stack_shares_stack_factor_only() -> void:
	# Arrange——本命卡（native_owner 与角色卡 ID 分段匹配），模板 ×2.0，叠 2 层
	_inject_template(&"test_ctx_native", 2.0, &"lin_yuan")
	var card_id: int = _bind_stacked(CHAR_CTX_NATIVE, &"test_ctx_native", 2,
			&"lin_yuan", &"char_lin_yuan_base_01")
	# Act
	var ctx: Dictionary = BindingManager.get_binding_context(card_id)
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_CTX_NATIVE)
	# Assert——上下文 1.5 × 2.0 = 3.0；减伤本命原值 15% × 2.0 = 30%
	assert_eq(ctx.get("native_multiplier"), 1.5, "本命 native_multiplier 锁定 1.5")
	assert_eq(ctx.get("multiplier"), 3.0, "1.5 × 2.0^1 = 3.0")
	assert_eq(pcts, [30.0], "本命减伤取 native_effect_value=15 再叠层放大（×2.0）")
