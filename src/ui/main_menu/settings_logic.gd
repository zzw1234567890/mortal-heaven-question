class_name SettingsLogic
extends RefCounted
## SettingsLogic —— 设置面板 Logic 内核（main-menu Story 002）。
##
## [b]纯函数静态类[/b]（control-manifest Presentation 必需模式——「db_from_percent()
## 纯函数单测」；先例 [MainMenuLogic]）：不 extends Node、不访问任何 Autoload、
## 不持有任何状态——全部逻辑在单次静态调用内完成。[br]
## [br][b]公式真理来源[/b]：[code]design/gdd/main-menu-system.md[/code] §公式
## 「音量百分比→dB 转换」原文：[br]
## [codeblock]
##   db_from_percent(percent):
##     # 0% = -80dB (静音), 100% = 0dB (最大)
##     if percent <= 0: return -80.0
##     return linear_to_db(percent / 100.0)
## [/codeblock]
## 超界输入（<0 或 >100）钳制到 [0, 100] 后按边界值处理
## （QL-STORY-READY 2026-09-07 裁决采纳）。[br]
## [br][b]消费方[/b]：[SettingsPanel] 滑条实时预览、audio 005（启动音量真值加载，
## 经 [SettingsStore] 读文件后套本公式覆盖总线默认 dB）。
##
## @experimental
## 来源: GDD main-menu-system.md §公式、story-002-settings-audio.md、
## control-manifest §Presentation 必需模式。

## === 数据驱动配置 =============================================================

## 0% 静音底值（dB）——GDD 公式原文「0% = -80dB (静音)」。[br]
## 与 [AudioManager.MUTE_VOLUME_DB]（GDD AC-MUTE-01 Master 静音语义）数值一致
## ——两处各自声明：本常量是百分比转换的公式端点，彼常量是静音切换的目标值，
## 语义不同不合并（「同一数值不同决策」非重复）。
const MUTE_DB: float = -80.0

## 百分比下界（钳制边界——低于此值按 0% 静音处理）。
const PERCENT_MIN: float = 0.0

## 百分比上界（钳制边界——高于此值按 100% 满 dB 处理）。
const PERCENT_MAX: float = 100.0

## 百分比满值基准（linear_to_db 归一化分母——GDD 公式原文 percent / 100.0）。
const PERCENT_FULL: float = 100.0

## === 转换纯函数 ===============================================================

## 音量百分比 → 总线 dB（AC-1 / AC-main-menu-008）。[br]
## [br][param percent]: 音量百分比（0~100；超界输入先钳制到 [0, 100]——
## 钳制裁决见类注释）。[br]
## [b]返回[/b]: [code]percent <= 0[/code] → [constant MUTE_DB]（-80.0，静音）；
## 否则 [code]linear_to_db(percent / 100.0)[/code]（100% → 0.0dB，
## 50% → ≈-6.02dB，1% → 非 -80 的有限负值）。[br]
## [br][b]纯函数[/b]：无状态、无 IO——同输入恒同输出（BLOCKING 单测目标）。
static func db_from_percent(percent: float) -> float:
	var clamped: float = clampf(percent, PERCENT_MIN, PERCENT_MAX)
	if clamped <= PERCENT_MIN:
		return MUTE_DB
	return linear_to_db(clamped / PERCENT_FULL)
