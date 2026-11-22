extends RefCounted
## MainMenuTexts —— 主菜单的固定词条与版本号读取（从 main_menu.gd 拆出）。[br]
## [br][b]职责[/b]：两件「照本念」的事——[br]
##   · 全部按钮 / 提示的固定中文文案（[constant TEXT_TITLE] … [constant TEXT_NO_SAVE_LOAD]）；[br]
##   · 版本号的读取与落标签（[method read_version] / [method apply_version]）。[br]
## [b]不管什么[/b]：不建控件、不接线、不知道谁是宿主——文案是常量，版本号读的是
## [code]ProjectSettings[/code]（全局单点），两者都不需要宿主上下文。[br]
## [br][b]为什么单独成文件[/b]：[code]main_menu.gd[/code] 超 300 行软上限
## （.claude/docs/coding-standards.md），而「界面上该写哪几个字」与「按钮怎么摆、
## 点下去走哪条导航链、HUD 何时挂」是不同的事。[br]
## [br][b]为什么常量要在主菜单留同名转发[/b]：既有用例按实例读它们
## （[code]menu.TEXT_INVENTORY[/code] / [code]menu.TEXT_DECK_EDIT[/code] /
## [code]menu.TEXT_NO_SAVE_CONTINUE[/code]），转发后取法不变——本件是定义的
## 唯一出处，主菜单只转述（先例 [code]identity_select.gd[/code] 转发
## [code]INTRO_DURATION[/code]）。[br]
## [br][b]词条的本地化豁免[/b]：项目暂无本地化系统——先例
## [code]CultivationBarState.LABEL_*[/code] 同源注记，本地化入库后替换为键。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本件无实例状态，方法一律 static；
## [b]零轮询[/b]：无 [code]_process()[/code]。
##
## 来源: design/gdd/main-menu-system.md §2、story-001-main-menu-scene.md、
## 编码标准「单文件 ≤300 行」。

## 固定 UI 词条（GDD main-menu-system.md §2 原文）。
const TEXT_TITLE: String = "仙途问道"
const TEXT_NEW_GAME: String = "新游戏"
const TEXT_CONTINUE: String = "继续游戏"
const TEXT_SETTINGS: String = "设置"
const TEXT_QUIT: String = "退出"
## 「行囊与道友」入口文案——一个按钮开两个界面（背包 + 角色状态，宿主内页签切换）。
## 名字取「行囊（物）与道友（人）」：玩家的两类诉求各占一字，比「背包」更贴实际内容。
const TEXT_INVENTORY: String = "行囊与道友"
## 「读档」入口文案——与「继续游戏」（读最新档）并列的第三条路径：这一条让玩家
## 自己挑槽位。两条路径都能进游戏，差别只在这里（GDD §新游戏/继续游戏/读档）。
const TEXT_LOAD: String = "读档"
## 「卡组编辑」入口文案——独立场景（[code]SceneID.DECK_EDITING[/code]），
## 与「行囊与道友」（场景内覆盖层）不同：那里改的是行囊，这里改的是出战卡组。[br]
## [br][b]为什么放在这里而不是背包里[/b]：卡组编辑是一屏两栏的编辑界面，塞进页签会
## 与背包的「一件物品一行」形态打架；GDD 也把它列在主菜单入口下。
const TEXT_DECK_EDIT: String = "卡组编辑"
## 无存档时的中文提示（GDD 边界：无档时继续游戏置灰并给出说明）。[br]
## [br][b]为什么两个按钮各说一句[/b]：它们被禁用的原因不同——「继续游戏」要的是
## 「至少有一份档」，「读档」要的是「有一格非空槽位」；共用一句会让其中一边说谎。
const TEXT_NO_SAVE_CONTINUE: String = "还没有存档——先点「新游戏」开始一轮"
const TEXT_NO_SAVE_LOAD: String = "还没有任何存档槽位可读"

## 版本号缺省回退（ProjectSettings 未配置 version 键时的安全默认——
## story Implementation Notes「不硬编码」指不在 UI 层写死版本值，读取失败
## 仍需一个可显示占位）。
const VERSION_FALLBACK: String = "v?"


## 版本号——从 ProjectSettings 读取（story：不硬编码）。[br]
## project.godot [code]application/config/version[/code] = "0.1.0-dev"。
## [br][b]返回[/b]：带 [code]v[/code] 前缀的显示串；未配置时回退
## [constant VERSION_FALLBACK] 并 [method @GlobalScope.push_warning]。
static func read_version() -> String:
	var version: String = str(ProjectSettings.get_setting(
			&"application/config/version", ""))
	if version.is_empty():
		push_warning("MainMenu: project.godot 未配置 application/config/version")
		return VERSION_FALLBACK
	return "v" + version


## 把版本号落进标签。[br]
## [br][b]为什么留一个只做一行赋值的函数[/b]：宿主 [method Node._ready] 读起来是
## 「应用文案 / 应用版本 / 装按键…」一串并列动作，多这一跳比在 _ready 里直写
## [method read_version] 更齐整（同 [method apply_version] 的姊妹项
## [code]MainMenu._apply_texts[/code]）。
static func apply_version(p_label: Label) -> void:
	if p_label != null:
		p_label.text = read_version()
