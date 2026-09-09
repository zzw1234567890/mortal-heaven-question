class_name CultivationBarState
extends RefCounted
## CultivationBarState —— 境界+修为条判定 Logic 内核（hud Story 002）。
##
## [b]纯函数静态类[/b]（ADR-0031——阈值/状态判定逻辑提取为可单测纯函数，
## UI 节点只消费判定结果）：不 extends Node、不访问任何 Autoload、
## 不持有任何状态——全部逻辑在 [method get_cultivation_bar_state] 单次调用内完成。
##
## [b]语义来源[/b]：design/gdd/hud-system.md §2 展示规则 + design/ux/hud.md
## 「元素 1：境界修为指示器」+ story 002 G1/G2/G3/G7 裁决：[br]
##   - 颜色阈值：<50% 蓝（松石青 #4A9494）、50~90% 紫（烟灰紫 #6E6878）、
##     ≥90% 金（琉璃金 #C8A84E）——美术圣经 §4.1 主色调色板[br]
##   - 脉动：p≥90% 且非落难（落难时恒 false——破碎光效替代脉动，G7 裁决）[br]
##   - label：落难 →「炼气·落难」；化神期满 →「可飞升」；否则 → 传入 realm_name[br]
##   - show_bar：化神期满（realm_id==5 且 current==max_val）→ false[br]
##   - breakthrough_hint：current==max_val 且非化神期满且非落难 → true（G3 裁决）
##
## [br]来源: ADR-0031（Logic 内核模式）、story-002-realm-cultivation-bar.md。

## === 数据驱动配置 =============================================================

## 阈值配置——数据驱动 const（story Required：阈值禁止散落硬编码 if-else）。[br]
## [code]pulse[/code] 为脉动触发阈值（0.9 = 90%）；[code]purple[/code] 为
## 紫-蓝切换阈值（0.5 = 50%）。调整阈值只改此处。
const THRESHOLDS: Dictionary = {
	&"purple": 0.5,
	&"pulse": 0.9,
}

## 化神期境界等级（RealmLevel.SPIRIT_TRANSFORMATION == 5）——「可飞升」判定。
const SPIRIT_TRANSFORMATION_LEVEL: int = 5

## 固定 UI 词条（GDD hud-system.md §2 原文；项目暂无本地化系统——
## 本地化系统入库后应替换为本地化键，见 story 约束「UI 文本不硬编码」豁免注记）。
const LABEL_FALLEN: String = "炼气·落难"
const LABEL_ASCENDABLE: String = "可飞升"

## 填充色标识——UI 节点将标识映射为美术圣经色值（纯函数不返回 Color，
## 避免 Visual 决策混入 Logic 内核）。
const COLOR_BLUE: String = "blue"
const COLOR_PURPLE: String = "purple"
const COLOR_GOLD: String = "gold"

## === 判定纯函数 ===============================================================

## 计算修为条完整显示状态。[br]
## [br][param realm_id]: 境界等级（1-5，RealmLevel 枚举值）。[br]
## [param realm_name]: 境界名称（正常态 label——来源 RealmSystem.realm_table
## 静态数据，由 UI 节点读取后传入，纯函数不访问 Autoload，G2 裁决）。[br]
## [param is_fallen]: 炼气·落难标记（GSM player.is_fallen——G1 裁决数据源）。[br]
## [param current]: 当前修为值。[br]
## [param max_val]: 修为上限。[br]
## [br][b]返回[/b] [code]{color: String, pulsing: bool, label: String,
## show_bar: bool, breakthrough_hint: bool}[/code]——UI 节点消费的全部视觉决策。[br]
## [br][b]安全边界[/b]：[br]
##   - 非法 realm_id（<1 或 >5）→ 安全默认（blue/不脉动/正常 label）+ push_warning[br]
##   - max_val <= 0 → 防除零（按 0% 处理：blue/不脉动）[br]
##   - current < 0 → 按负数安全处理（钳为 0%：blue）[br]
##   - current > max_val → 溢出按 100% 处理（gold）
static func get_cultivation_bar_state(realm_id: int, realm_name: String,
		is_fallen: bool, current: int, max_val: int) -> Dictionary:
	if realm_id < 1 or realm_id > 5:
		push_warning("CultivationBarState: 非法 realm_id %d（有效范围 1-5）——返回安全默认" % realm_id)
		return _safe_default(realm_name)

	var ratio: float = _clamp_ratio(current, max_val)
	var is_spirit_full: bool = realm_id == SPIRIT_TRANSFORMATION_LEVEL \
			and current == max_val and max_val > 0

	var color: String = _color_for_ratio(ratio)
	# 脉动：≥90% 且非落难（落难时破碎光效替代脉动——G7 裁决）
	var pulsing: bool = ratio >= THRESHOLDS[&"pulse"] and not is_fallen
	# label 优先级：落难 > 化神期满 > 正常境界名
	var label: String = realm_name
	if is_fallen:
		label = LABEL_FALLEN
	elif is_spirit_full:
		label = LABEL_ASCENDABLE
	# show_bar：化神期满隐藏进度条（「可飞升」替代）
	var show_bar: bool = not is_spirit_full
	# 可突破提示：修为满且非化神期满且非落难（化神期满由 show_bar=false 接管——G3 裁决）
	var breakthrough_hint: bool = current == max_val and max_val > 0 \
			and not is_spirit_full and not is_fallen

	return {
		&"color": color,
		&"pulsing": pulsing,
		&"label": label,
		&"show_bar": show_bar,
		&"breakthrough_hint": breakthrough_hint,
	}


## === 内部辅助 =================================================================

## 比例钳制——防除零、负数钳 0、溢出钳 1（按 100% 处理）。
static func _clamp_ratio(current: int, max_val: int) -> float:
	if max_val <= 0:
		return 0.0
	var ratio: float = float(current) / float(max_val)
	return clampf(ratio, 0.0, 1.0)


## 比例 → 颜色标识（阈值来自 THRESHOLDS 配置，禁止散落硬编码）。
static func _color_for_ratio(ratio: float) -> String:
	if ratio >= THRESHOLDS[&"pulse"]:
		return COLOR_GOLD
	if ratio >= THRESHOLDS[&"purple"]:
		return COLOR_PURPLE
	return COLOR_BLUE


## 非法 realm_id 的安全默认——blue、不脉动、正常 label、显示进度条、无突破提示。
static func _safe_default(realm_name: String) -> Dictionary:
	return {
		&"color": COLOR_BLUE,
		&"pulsing": false,
		&"label": realm_name,
		&"show_bar": true,
		&"breakthrough_hint": false,
	}
