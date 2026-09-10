class_name LingshiFormatter
extends RefCounted
## LingshiFormatter —— 灵石 k 格式化 + 卡组计数状态判定 Logic 内核（hud Story 003）。
##
## [b]纯函数静态类[/b]（ADR-0031——格式化/阈值判定逻辑提取为可单测纯函数，
## UI 节点只消费判定结果）：不 extends Node、不访问任何 Autoload、
## 不持有任何状态——全部逻辑在单次静态调用内完成。
##
## [b]语义来源[/b]：design/gdd/hud-system.md §3 展示规则 + §调优参数表 +
## design/ux/hud.md「元素 2：灵石计数」/「元素 3：卡组计数」+ story 003
## 2026-09-10 QL-STORY-READY G2/G3 裁决：[br]
##   - k 格式：<1000 原数字；≥1000 一位小数 k 格式；[b]10000+ 延续 k 格式[/b]
##     （10000→「10.0k」、12500→「12.5k」，不引入万单位——G2 裁决，
##     关闭 GDD L237 待澄清项）[br]
##   - 卡组三态：count<cap normal；count==cap yellow（达上限）；
##     count>cap red+flashing+overlimit+「超限！」[br]
##   - cap<=0 防御：返回 normal（G3 裁决——系统 get_deck_limit() 最低返回 20，
##     此分支不可达，单测仅防御性锁定 count==cap==0 不落入 yellow）
##
## [br]来源: ADR-0031（Logic 内核模式）、story-003-lingshi-deck-counter.md。

## === 数据驱动配置 =============================================================

## k 格式阈值——数据驱动 const（story Required：阈值禁止散落硬编码 if-else；
## GDD §调优参数表「灵石显示阈值（k格式）≥1000」）。调整阈值只改此处。
const K_FORMAT_THRESHOLD: int = 1000

## k 格式后缀（GDD L237 裁决格式「1.2k」）。本地化注记：项目暂无本地化系统，
## 本地化入库后应替换为本地化键（story 约束「UI 文本不硬编码」豁免注记）。
const K_SUFFIX: String = "k"

## 卡组超限标记文本（GDD hud-system.md §3「超限！」）。
## 本地化注记同上。
const LABEL_OVERLIMIT: String = "超限！"

## 卡组计数颜色标识——UI 节点将标识映射为美术圣经色值（纯函数不返回
## Color，避免 Visual 决策混入 Logic 内核——先例 CultivationBarState）。
const COLOR_NORMAL: String = "normal"
const COLOR_YELLOW: String = "yellow"
const COLOR_RED: String = "red"

## === 判定纯函数 ===============================================================

## 格式化灵石显示文本。[br]
## [br][param amount]: 灵石数量。[br]
## [br][b]返回[/b]：<1000 → 原数字字符串（含 0）；≥1000 → 一位小数 k 格式
## （1000→「1.0k」、1250→「1.2k」、9999→「9.9k」、10000→「10.0k」、
## 12500→「12.5k」——G2 裁决延续 k 格式，不设万单位上限）。[br]
## [br][b]安全边界[/b]：负数 → 按原数字返回（GSM 写入侧 [code]_set_resource_ling_shi[/code]
## 已有 [code]maxi(0, value)[/code] 非负守卫，正常数据流不产生负值——此处
## 防御性直显而非钳 0，使异常数据可见而非被静默吞掉；单测锁定该行为）。
static func format_lingshi(amount: int) -> String:
	if amount < 0:
		return str(amount)
	if amount < K_FORMAT_THRESHOLD:
		return str(amount)
	# 整数截断到一位小数（QA 规格：1250→1.2k、9999→9.9k——向下截断而非
	# 四舍五入，9999 不得进位为 10.0k）。纯整数运算避免浮点表示误差
	# （如 1.2 的二进制近似 1.1999… 经 floor 后错截为 1.1k）。
	var tenths: int = (amount * 10) / K_FORMAT_THRESHOLD
	return "%d.%d%s" % [tenths / 10, tenths % 10, K_SUFFIX]


## 计算卡组计数显示状态。[br]
## [br][param count]: 当前卡组张数（deck.current_deck.size()）。[br]
## [param cap]: 卡组上限（DeckEditingSystem.get_deck_limit()——最低 20）。[br]
## [br][b]返回[/b] [code]{color: String, flashing: bool, overlimit: bool,
## label: String}[/code]——[br]
##   - [code]color[/code]: "normal"（count<cap）/ "yellow"（count==cap 达上限）/
##     "red"（count>cap 超限）[br]
##   - [code]flashing[/code]: 仅 red 为 true（超限红色闪烁）[br]
##   - [code]overlimit[/code]: 仅 red 为 true（「超限！」标记显示）[br]
##   - [code]label[/code]: 「count/cap」计数文本（如 "28/30"）——超限时
##     额外由 UI 层叠加 [constant LABEL_OVERLIMIT] 标记（独立 Label，
##     不混入计数文本——保持数字区等宽渲染不被中文截断）[br]
## [br][b]安全边界[/b]：cap<=0 → 防御返回 normal（G3 裁决——系统上限最低 20，
## 此分支不可达；count==cap==0 不得落入 yellow）。count<0 → 按原数字显示
## （与灵石负数同策略：防御性直显）。
static func get_deck_count_state(count: int, cap: int) -> Dictionary:
	if cap <= 0:
		return {
			&"color": COLOR_NORMAL,
			&"flashing": false,
			&"overlimit": false,
			&"label": "%d/%d" % [count, cap],
		}
	if count > cap:
		return {
			&"color": COLOR_RED,
			&"flashing": true,
			&"overlimit": true,
			&"label": "%d/%d" % [count, cap],
		}
	if count == cap:
		return {
			&"color": COLOR_YELLOW,
			&"flashing": false,
			&"overlimit": false,
			&"label": "%d/%d" % [count, cap],
		}
	return {
		&"color": COLOR_NORMAL,
		&"flashing": false,
		&"overlimit": false,
		&"label": "%d/%d" % [count, cap],
	}
