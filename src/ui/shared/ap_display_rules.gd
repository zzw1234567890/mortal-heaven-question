class_name ApDisplayRules
extends RefCounted
## ApDisplayRules —— AP 颜色阈值 + 分段格判定纯函数（hud Story 006）。
##
## [b]职责[/b]：AP（行动力）显示规则的 Logic 内核——颜色阈值状态判定与
## 分段格（每格 1 AP）结构计算。HUD（hud Story 006）与 exploration-ui
## （AP 强化显示组件，后续 story）双消费同一实现，任何一侧不得内联阈值
## （story Control Manifest Required + ADR-0031 Logic 内核模式）。[br]
## 落位 [code]src/ui/shared/[/code]（combat_ui_rules.gd 先例的跨 epic 版——
## 两 epic 间可见的公共模块；QL-STORY-READY 裁决：本 story 为归属实现方，
## 落地须先于 exploration-ui 的 AP story）。[br]
## [br][b]纯函数[/b]：无状态、无副作用、不 extends Node、不访问 Autoload、
## 确定映射——单元测试零依赖（先例 combat_ui_rules.gd / LingshiFormatter /
## KeybindLogic）。[br]
## [br][b]阈值 provisional[/b]：GDD 未定义 AP 阈值——≤20% 紧急 / ≤50% 警告 /
## >50% 正常为临时值，game-designer 签批后锁定（story AC 第 3 条）。
## 阈值常量集中于此，消费方只读不复制。
##
## 来源: ADR-0031、design/gdd/hud-system.md §5、
## hud Story 006（2026-10-20 QL-STORY-READY 复核修订）。

## === 阈值常量（数据驱动——provisional，签批后锁定）=========================

## 紧急阈值（比例 ≤ 此值 → 紧急）。provisional：20%（GDD 未定义，
## game-designer 签批后锁定——story AC 第 3 条）。
const AP_CRITICAL_THRESHOLD: float = 0.2
## 警告阈值（比例 ≤ 此值且 > 紧急阈值 → 警告）。provisional：50%。
const AP_WARNING_THRESHOLD: float = 0.5

## 颜色状态标识（纯函数不返回 Color——Visual 决策不入 Logic 内核，
## 先例 LingshiFormatter.COLOR_* / CombatUiRules 阈值集中模式：组件层
## 将标识映射为美术圣经色值）。
const COLOR_NORMAL: String = "normal"
const COLOR_WARNING: String = "warning"
const COLOR_CRITICAL: String = "critical"

## === 判定纯函数 ===============================================================

## AP 颜色阈值判定 + 分段格结构（story L51：分段判定并入纯函数返回）。[br]
## [br][param current]: 当前 AP。[br]
## [param max_val]: AP 上限（[code]GSM.exploration.max_action_points[/code]）。[br]
## [br][b]返回[/b] [code]{color: String, segments: Array[bool], ratio: float}[/code]——[br]
##   - [code]color[/code]: "critical"（比例 ≤ 20%）/ "warning"（≤ 50%）/
##     "normal"（> 50%）；阈值常量 provisional（见类注释）[br]
##   - [code]segments[/code]: 长度 = max_val 的布尔数组——[code]segments[i][/code]
##     为 true 表示第 i 格（1 基第 i+1 点 AP）已充能点亮，false 表示已消耗
##     熄灭（每格 = 1 AP——story AC 第 4 条；超过 current 的格子熄灭）[br]
##   - [code]ratio[/code]: current / max_val（0.0-1.0，供消费方复用）[br]
## [br][b]安全边界[/b]：[br]
##   - [code]max_val <= 0[/code]（防除零——GSM 未初始化 AP 上限时）：
##     返回 critical + 空分段 + ratio 0.0（AP 不可用时按最保守态显示，
##     不崩溃——先例 LingshiFormatter.get_deck_count_state cap<=0 防御）[br]
##   - [code]current > max_val[/code]（临时 AP 超上限——防御性处理）：
##     比例钳 1.0 判色（normal），分段全部点亮且不越界（超出部分不渲染
##     额外格——AC-1 edge case 规格）
static func get_ap_color_threshold(current: int, max_val: int) -> Dictionary:
	if max_val <= 0:
		return {
			&"color": COLOR_CRITICAL,
			&"segments": [],
			&"ratio": 0.0,
		}
	# current > max_val 防御：钳到上限再判比例/生成分段（分段长度恒 ≤ max_val，
	# 不为超上限的临时 AP 渲染额外格）。
	var effective_current: int = mini(current, max_val)
	if effective_current < 0:
		effective_current = 0
	var ratio: float = float(effective_current) / float(max_val)
	var color: String = COLOR_NORMAL
	if ratio <= AP_CRITICAL_THRESHOLD:
		color = COLOR_CRITICAL
	elif ratio <= AP_WARNING_THRESHOLD:
		color = COLOR_WARNING
	# 分段格：每格 1 AP——前 effective_current 格点亮，其余熄灭。
	var segments: Array = []
	segments.resize(max_val)
	segments.fill(false)
	for i: int in range(effective_current):
		segments[i] = true
	return {
		&"color": color,
		&"segments": segments,
		&"ratio": ratio,
	}
