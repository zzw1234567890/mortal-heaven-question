extends GutTest
## hud Story 002 Logic 内核单测：CultivationBarState.get_cultivation_bar_state 纯函数。
##
## 覆盖 QA Test Cases 的 AC-1（颜色阈值）/ AC-2（脉动）/ AC-3（落难 label）/
## AC-4（化神期满）/ AC-8（正常态 label）/ AC-9（可突破提示）全部规格与 edge cases
## （story 2026-09-09 QL-STORY-READY 裁决修订版）。
##
## 纯函数直调——无需场景树与 Autoload。风格先例：
## tests/integration/hud/test_hud_scene_visibility.gd（arrange/act/assert）。

const S := preload("res://src/ui/hud/cultivation_bar_state.gd")

## 常用境界等级（RealmLevel 枚举镜像——纯函数独立于 GSM，测试本地定义避免
## 依赖 Autoload 脚本）。
const QI_REFINING: int = 1
const GOLDEN_CORE: int = 3
const SPIRIT_TRANSFORMATION: int = 5

const NAME_QI: String = "炼气期"
const NAME_CORE: String = "金丹期"
const NAME_SPIRIT: String = "化神期"


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：进度条颜色阈值判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_cultivation_ratio_below_50_percent_returns_blue() -> void:
	## AC-1: p<50% → "blue"（0%、45%、49.9% 三点）
	# Arrange
	var cases: Array = [[0, 1000], [450, 1000], [499, 1000]]
	for c: Array in cases:
		# Act
		var state: Dictionary = S.get_cultivation_bar_state(
				GOLDEN_CORE, NAME_CORE, false, c[0], c[1])
		# Assert
		assert_eq(state[&"color"], "blue",
				"%d/%d 应为 blue" % [c[0], c[1]])


func test_hud_cultivation_ratio_50_percent_boundary_returns_purple() -> void:
	## AC-1: p=50% 边界 → "purple"（阈值含 50%）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 500, 1000)
	# Assert
	assert_eq(state[&"color"], "purple", "50.0% 边界应为 purple")


func test_hud_cultivation_ratio_50_to_89_returns_purple() -> void:
	## AC-1: 50%≤p<90% → "purple"（60%、80%、89.9%）
	# Arrange
	var cases: Array = [[600, 1000], [800, 1000], [899, 1000]]
	for c: Array in cases:
		# Act
		var state: Dictionary = S.get_cultivation_bar_state(
				GOLDEN_CORE, NAME_CORE, false, c[0], c[1])
		# Assert
		assert_eq(state[&"color"], "purple",
				"%d/%d 应为 purple" % [c[0], c[1]])


func test_hud_cultivation_ratio_90_percent_boundary_returns_gold() -> void:
	## AC-1: p=90% 边界 → "gold"（阈值含 90%）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 900, 1000)
	# Assert
	assert_eq(state[&"color"], "gold", "90.0% 边界应为 gold")


func test_hud_cultivation_ratio_100_percent_returns_gold() -> void:
	## AC-1: p=100% → "gold"
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 1000, 1000)
	# Assert
	assert_eq(state[&"color"], "gold", "100% 应为 gold")


func test_hud_cultivation_max_val_zero_returns_blue_no_pulse() -> void:
	## AC-1 edge: max_val=0 → 防除零——blue 且不脉动，不崩溃
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 0, 0)
	# Assert
	assert_eq(state[&"color"], "blue", "max_val=0 防除零应为 blue")
	assert_false(state[&"pulsing"], "max_val=0 不应脉动")


func test_hud_cultivation_negative_current_returns_blue() -> void:
	## AC-1 edge: current<0 → 负数安全处理（按 0%——blue）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, -100, 1000)
	# Assert
	assert_eq(state[&"color"], "blue", "负数修为按 0% 应为 blue")
	assert_false(state[&"pulsing"], "负数修为不应脉动")


func test_hud_cultivation_overflow_current_clamps_to_gold() -> void:
	## AC-1 edge: current>max_val 溢出 → 按 100% 处理（gold）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 1200, 1000)
	# Assert
	assert_eq(state[&"color"], "gold", "溢出按 100% 应为 gold")
	assert_true(state[&"pulsing"], "溢出按 100% 应脉动")


func test_hud_cultivation_invalid_realm_id_returns_safe_default_and_warns() -> void:
	## AC-1 edge: 非法 realm_id（0/6）→ 安全默认（blue/不脉动/正常 label）+ push_warning
	# Arrange
	var invalid_ids: Array = [0, 6, -1]
	for rid: int in invalid_ids:
		# Act
		var state: Dictionary = S.get_cultivation_bar_state(
				rid, NAME_CORE, false, 900, 1000)
		# Assert —— 90% 修为也不金不脉（安全默认优先于阈值判定）
		assert_eq(state[&"color"], "blue", "realm_id=%d 应安全默认 blue" % rid)
		assert_false(state[&"pulsing"], "realm_id=%d 应不脉动" % rid)
		assert_eq(state[&"label"], NAME_CORE, "realm_id=%d label 应为传入 realm_name" % rid)
		assert_true(state[&"show_bar"], "realm_id=%d 应显示进度条" % rid)
		assert_false(state[&"breakthrough_hint"], "realm_id=%d 不应提示可突破" % rid)
	# push_warning 计数（3 个非法 ID 各 1 次）
	assert_push_warning_count(3, "3 个非法 realm_id 应各 push_warning 1 次")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：脉动动画触发判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_cultivation_pulse_89_99_percent_returns_false() -> void:
	## AC-2 edge: p=89.99% → 不脉动（阈下临界）
	# Arrange + Act —— 8999/10000 = 89.99%
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 8999, 10000)
	# Assert
	assert_false(state[&"pulsing"], "89.99% 不应脉动")


func test_hud_cultivation_pulse_90_percent_returns_true() -> void:
	## AC-2: p=90% → 脉动
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 900, 1000)
	# Assert
	assert_true(state[&"pulsing"], "90% 应脉动")


func test_hud_cultivation_pulse_below_90_returns_false() -> void:
	## AC-2: p<90%（含 0% 与 50% 中段）→ 不脉动
	# Arrange
	var cases: Array = [[0, 1000], [500, 1000], [800, 1000]]
	for c: Array in cases:
		# Act
		var state: Dictionary = S.get_cultivation_bar_state(
				GOLDEN_CORE, NAME_CORE, false, c[0], c[1])
		# Assert
		assert_false(state[&"pulsing"], "%d/%d 不应脉动" % [c[0], c[1]])


func test_hud_cultivation_pulse_spirit_95_percent_true_and_bar_visible() -> void:
	## AC-2 edge（AC-2/AC-4 交互点）: 化神期 95% → pulsing=true 且 show_bar=true
	## （化神未满时不隐藏进度条——「可飞升」仅在满值时触发）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			SPIRIT_TRANSFORMATION, NAME_SPIRIT, false, 950, 1000)
	# Assert
	assert_true(state[&"pulsing"], "化神 95% 应脉动")
	assert_true(state[&"show_bar"], "化神 95% 应仍显示进度条")
	assert_eq(state[&"color"], "gold", "化神 95% 应为 gold")


func test_hud_cultivation_pulse_fallen_always_false() -> void:
	## AC-2（G7 裁决）: is_fallen=true 时 pulsing 恒 false——破碎光效替代脉动
	## 三点覆盖：落难且 ≥90%、落难且修为满、落难且低修为
	# Arrange
	var cases: Array = [[900, 1000], [1000, 1000], [100, 1000]]
	for c: Array in cases:
		# Act
		var state: Dictionary = S.get_cultivation_bar_state(
				QI_REFINING, NAME_QI, true, c[0], c[1])
		# Assert
		assert_false(state[&"pulsing"],
				"落难 %d/%d 不应脉动（破碎光效替代）" % [c[0], c[1]])


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：落难状态显示判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_cultivation_fallen_label_shows_fallen_text() -> void:
	## AC-3: is_fallen=true → label 为「炼气·落难」
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			QI_REFINING, NAME_QI, true, 400, 1000)
	# Assert
	assert_eq(state[&"label"], "炼气·落难", "落难时 label 应为「炼气·落难」")


func test_hud_cultivation_fallen_with_full_cultivation_label_still_fallen() -> void:
	## AC-3 edge: is_fallen=true 且修为满 → label 仍为落难显示（落难优先级最高）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			QI_REFINING, NAME_QI, true, 1000, 1000)
	# Assert
	assert_eq(state[&"label"], "炼气·落难", "落难+修为满 label 仍应为「炼气·落难」")


func test_hud_cultivation_fallen_suppresses_breakthrough_hint() -> void:
	## AC-3 补充（G3/G7 交互）: 落难且修为满 → breakthrough_hint=false
	## （「可突破！」提示被落难状态抑制）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			QI_REFINING, NAME_QI, true, 1000, 1000)
	# Assert
	assert_false(state[&"breakthrough_hint"], "落难时不应显示「可突破！」")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：化神期满修为
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_cultivation_spirit_full_hides_bar_and_shows_ascendable() -> void:
	## AC-4: 化神期 + current==max_val → show_bar=false、label「可飞升」
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			SPIRIT_TRANSFORMATION, NAME_SPIRIT, false, 1000, 1000)
	# Assert
	assert_false(state[&"show_bar"], "化神期满应隐藏进度条")
	assert_eq(state[&"label"], "可飞升", "化神期满 label 应为「可飞升」")


func test_hud_cultivation_spirit_not_full_keeps_bar_and_realm_name() -> void:
	## AC-4 edge: 化神期未满 → 正常显示进度条与境界名
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			SPIRIT_TRANSFORMATION, NAME_SPIRIT, false, 700, 1000)
	# Assert
	assert_true(state[&"show_bar"], "化神未满应显示进度条")
	assert_eq(state[&"label"], NAME_SPIRIT, "化神未满 label 应为境界名")


func test_hud_cultivation_non_spirit_full_keeps_bar_and_realm_name() -> void:
	## AC-4 edge: 非化神期满（金丹 100%）→ 进度条保持显示 + 境界名 label
	## （「可飞升」仅化神期满触发）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 1000, 1000)
	# Assert
	assert_true(state[&"show_bar"], "非化神期满应显示进度条")
	assert_eq(state[&"label"], NAME_CORE, "非化神期满 label 应为境界名")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8：正常态 label（G2 裁决补充）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_cultivation_normal_state_label_equals_realm_name() -> void:
	## AC-8: is_fallen=false 且非化神期满 → label == 传入 realm_name
	## 五境界逐一验证（正常态 label 全走 realm_name 参数）
	# Arrange
	var realms: Array = [
		[QI_REFINING, "炼气期"], [2, "筑基期"], [3, "金丹期"],
		[4, "元婴期"], [SPIRIT_TRANSFORMATION, "化神期"],
	]
	for r: Array in realms:
		# Act —— 未满修为（60%）正常态
		var state: Dictionary = S.get_cultivation_bar_state(
				r[0], r[1], false, 600, 1000)
		# Assert
		assert_eq(state[&"label"], r[1],
				"境界 %s 正常态 label 应为传入 realm_name" % r[1])


# ═══════════════════════════════════════════════════════════════════════════════
# AC-9：可突破提示判定（G3 裁决补充）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_cultivation_full_non_spirit_returns_breakthrough_hint() -> void:
	## AC-9: current==max_val 且 realm 非化神期 → breakthrough_hint=true
	## 四个非化神境界逐一验证（炼气/筑基/金丹/元婴）
	# Arrange
	var non_spirit: Array = [
		[QI_REFINING, "炼气期"], [2, "筑基期"],
		[3, "金丹期"], [4, "元婴期"],
	]
	for r: Array in non_spirit:
		# Act
		var state: Dictionary = S.get_cultivation_bar_state(
				r[0], r[1], false, 1000, 1000)
		# Assert
		assert_true(state[&"breakthrough_hint"],
				"%s 修为满应提示可突破" % r[1])
		assert_true(state[&"show_bar"], "%s 修为满应保持进度条显示" % r[1])


func test_hud_cultivation_spirit_full_no_breakthrough_hint() -> void:
	## AC-9: 化神期满 → breakthrough_hint=false（由 show_bar=false +「可飞升」接管）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			SPIRIT_TRANSFORMATION, NAME_SPIRIT, false, 1000, 1000)
	# Assert
	assert_false(state[&"breakthrough_hint"], "化神期满不应提示「可突破！」")


func test_hud_cultivation_not_full_no_breakthrough_hint() -> void:
	## AC-9 edge: current<max_val（95%）→ breakthrough_hint=false
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 950, 1000)
	# Assert
	assert_false(state[&"breakthrough_hint"], "未满修为不应提示可突破")


func test_hud_cultivation_full_with_max_val_zero_no_breakthrough_hint() -> void:
	## AC-9 edge: max_val=0（0==0 形式上相等）→ 不提示可突破（防除零一致性）
	# Arrange + Act
	var state: Dictionary = S.get_cultivation_bar_state(
			GOLDEN_CORE, NAME_CORE, false, 0, 0)
	# Assert
	assert_false(state[&"breakthrough_hint"], "max_val=0 时不应提示可突破")
