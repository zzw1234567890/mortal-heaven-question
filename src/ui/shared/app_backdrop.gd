extends ColorRect
## AppBackdrop —— 全屏深色背板（主题底色的[b]唯一消费者[/b]）。[br]
## [br][b]为什么要有这个脚本[/b]：[code]ColorRect[/code] 没有主题颜色槽——它的
## [member ColorRect.color] 是普通属性，只能由 [code].tscn[/code] 写字面量。于是同一个
## 「项目深色基底」在几个界面里各写了一份（[code]MainMenu.tscn[/code] /
## [code]map_select_screen.tscn[/code] / [code]node_graph_screen.tscn[/code] /
## [code]combat_scene.tscn[/code] / [code]tribulation_scene.tscn[/code]），其中节点图
## 那一份还悄悄漂成了另一个值——像素走查里四个屏幕的底色呈三支不同的深色。
## 本脚本把「底色是什么」收进 [code]theme/main.tres[/code] 的
## [code]GamePalette/backdrop[/code]：改配色只改一处。[br]
## [br][b]为什么在 [method Node._init] 里读[/b]：放到 [method Node._ready] 会让首帧
## 闪一下默认色。实测未进场景树时 [code]get_theme_color[/code] 对自定义 type 的直查
## 即可解析（项目默认主题经 [code]ThemeDB[/code] 可达），[method Node._init] 是可行且
## 最早的时机。[br]
## [br][b]踩过的坑[/b]：[code].tscn[/code] 里[b]不能[/b]再写 [code]color = ...[/code]
## ——属性回填在 [method Node._init] 之后，会把手里的主题取值覆盖掉；同样地
## [code]script[/code] 要排在 [code].tscn[/code] 的属性之后。所以背板颜色在场景文件里
## 彻底不存在，不是「写在别处」，是没有第二份。[br]
## [br][b]只写颜色、不动布局[/b]：锚点 / [member Control.mouse_filter] 仍由各
## [code].tscn[/code] 自己声明——那些是布局，不是配色（本轮只收敛配色）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读主题、只写自己的绘制属性。
##
## 来源: design/art/art-bible.md §4.7.1（背景层级）、ADR-0031 §1、
## 一周目界面走查 2026-11-22（四屏底色漂成三支）。

## 承载底色的自定义 type 与槽位名（与 [code]theme/main.tres[/code] 同源）。
const PALETTE_TYPE: StringName = &"GamePalette"
const BACKDROP_KEY: StringName = &"backdrop"

## 主题查不到该 token 时的兜底底色。[br]
## [br][b]为什么会走到这里[/b]：脱离项目主题启动（探针脚本、无
## [code]gui/theme/custom[/code] 的最小工程）时 [code]get_theme_color[/code] 会回落到
## 引擎内置默认——纯黑。玩家宁可看到一块项目深色，也不要一块与配色无关的黑。[br]
## [br][b]判据为什么是「等于引擎默认」而不是「主题在不在」[/b]：
## [code]ThemeDB.get_project_theme()[/code] 非空也可能漏写这个 token（本轮重命名
## token 时就真踩到了——六个界面同时变黑），而查不到时的返回值是确定的默认色。
const FALLBACK_COLOR: Color = Color("#0E0F16")


func _init() -> void:
	var themed: Color = get_theme_color(BACKDROP_KEY, PALETTE_TYPE)
	color = FALLBACK_COLOR if themed == Color.BLACK else themed
