extends RefCounted
## LingshiDeckBarStyle —— 灵石/卡组计数组件的[b]显示词表[/b]（纯数据，无行为）。
##
## [b]放什么[/b]：颜色、动画时长、占位图标、GSM 订阅路径、资源类型标识——
## 组件与它的动画模块都从这里取，不各写一份字面。[br]
## [br][b]为什么单独一处[/b]：[code]lingshi_deck_bar.gd[/code] 是门面（生命周期 +
## 刷新编排 + 卡组三态），本文件是它「长什么样、订阅哪条路径」。图标与配色随
## 美术资产管线与主题调整变动，刷新编排不随——两者分开后改颜色不用翻过刷新逻辑。[br]
## [br][b]本地化/资产豁免[/b]：图标为 emoji 占位（真图标归美术图集——替换点即
## [constant ICON_LINGSHI] / [constant ICON_DECK]，见 tech-debt TD-011）；项目暂无
## 本地化系统，故无文本键。数值来源见各常量注记。
##
## 来源: design/gdd/hud-system.md §3、design/ux/hud.md「元素 2/3」、
## ADR-0031、hud Story 003。

## 卡组计数颜色映射（判定标识 → 美术圣经 §4.1 主色调色板）：
## normal=墨色（默认 Label 色）/ yellow=琉璃金 #C8A84E（达上限警示）/
## red=朱砂红 #B3424A（超限警报——美术圣经「生命在流逝」编码复用为警报色）。
const COUNT_COLORS: Dictionary = {
	"normal": Color("#1A1A1A"),
	"yellow": Color("#C8A84E"),
	"red": Color("#B3424A"),
}
## 「超限！」标记色——朱砂红 #B3424A（与 COUNT_COLORS.red 同源，
## OverlimitLabel 的 LabelSettings 直写专用——B-1 修复）。
const COLOR_OVERLIMIT: Color = Color("#B3424A")
## 灵石负值 delta 文本色——朱砂红 #B3424A（支出警示，与 COUNT_COLORS.red
## 同源；正值保持计数器墨色——2026-09-12 TD-013 验证裁决：仅 ± 前缀区分
## 辨识度不足，负值复用警报色增强方向感知）。
const COLOR_DELTA_NEGATIVE: Color = Color("#B3424A")
## 灵石正值 delta 文本色——墨色 #1A1A1A（与 COUNT_COLORS.normal 同源；
## 每轮浮动都要写一次色值——上一轮负值直写会残留，故须显式复位）。
const COLOR_DELTA_POSITIVE: Color = Color("#1A1A1A")

## 灵石数字滚动时长——0.3s（GDD hud-system.md §调优参数表「灵石数字跳动 0.3s」）。
const LINGSHI_ROLL_DURATION: float = 0.3
## 灵石 (+xx/-xx) 浮动标签浮动时长（含淡出——向下浮 18px）。
const DELTA_FLOAT_DURATION: float = 0.8
## delta 浮动标签的下浮距离——18px（2026-09-10 用户裁决：顶行向上浮会顶出 HUD
## 顶边距，改为向下浮）。
const DELTA_FLOAT_DISTANCE: float = 18.0
## 卡组超限红色闪烁全周期——0.8s（realm_bar FALLEN_FLICKER_PERIOD 风格先例）。
const OVERLIMIT_FLICKER_PERIOD: float = 0.8
## 超限闪烁的低透明度端点——0.35（半周期降到此处再回满）。
const OVERLIMIT_FLICKER_LOW_ALPHA: float = 0.35
## 超限静态降级透明度——0.6（reduce-motion 下不建循环 Tween，以半透明静态红呈现）。
const OVERLIMIT_STATIC_ALPHA: float = 0.6

## 订阅过滤常量——GSM 路径前缀（G1 裁决订阅集）。
const PATH_LING_SHI: String = "player.resources.ling_shi"
const PATH_DECK: String = "deck.current_deck"
## 灵石资源类型标识（resource_changed 信号第一参数——gsm_signal_router
## 从路径第三段切出）。
const RES_TYPE_LING_SHI: StringName = &"ling_shi"
## 灵石图标占位字符（真图标归美术资产管线——图集）。
const ICON_LINGSHI: String = "🪙"
## 卡组图标占位字符（同上）。
const ICON_DECK: String = "📜"
## 图标与数字之间的分隔。
const ICON_SEPARATOR: String = " "
## (+xx/-xx) 前缀符号（正值格式串）。
const SIGN_PLUS: String = "+"

## 依赖回落时查找的 Autoload 名（注入为空时用）。
const AUTOLOAD_GSM: StringName = &"GameStateManager"
const AUTOLOAD_DECK: StringName = &"DeckEditingSystem"
