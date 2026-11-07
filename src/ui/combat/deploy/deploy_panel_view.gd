class_name DeployPanelView
extends RefCounted
## DeployPanelView —— 备战面板控件树构建器（combat-ui-layout Story 007）。
##
## [b]职责[/b]：只负责把面板的控件树建出来并回传引用字典；不含判定逻辑、
## 不含信号接线、不读数据——判定在 [DeployPanelRules]，编排在 [DeployPanel]。
## 拆分理由：coding-standards 单文件 ≤300 行软上限（面板编排 + 控件构建曾同处一文件）。[br]
## [br][b]构建时机[/b]：在面板 `_init` 中调用（不依赖场景树时序——与
## [FormationZone]/[CombatLayout] 同先例）。[br]
## [br][b]文字即标记[/b]：4 态符号走 [method CanvasItem.draw_string]（非独立纹理），
## 满足 control-manifest「绝不使用独立纹理渲染 UI 图标」。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §8 备战阶段UI、
## combat-ui-layout Story 007（AC-1）。

## === 布局常量（1920×1080 基准）=============================================

const TITLE_HEIGHT: float = 48.0
const GRID_TOP: float = 64.0
const GRID_GAP: float = 10.0
const GRID_COLUMNS: int = 5
const HINT_TOP_OFFSET: float = 8.0
const BUTTON_HEIGHT: float = 40.0
const BUTTON_WIDTH: float = 160.0
const PREVIEW_TOP_OFFSET: float = 16.0

## === 文本视觉常量 ==========================================================

const TITLE_COLOR: Color = Color(0.94, 0.92, 0.86)
const HINT_COLOR: Color = Color(0.85, 0.78, 0.60)
const TOOLTIP_COLOR: Color = Color(0.80, 0.86, 0.92)

## === 按钮文案（本地化豁免——同 S16/S17 口径）================================

const TEXT_CONFIRM: String = "确认出战"
const TEXT_BACK: String = "返回探索"
const TEXT_REPLACE_TITLE: String = "替换角色"


## 构建控件树并挂到 [param root]。[br]
## [br][b]返回[/b]: [code]{title_label, grid, preview, hint_label,
## tooltip_label, confirm_button, back_button, replace_dialog}[/code]。
static func build(root: Control) -> Dictionary:
	var title_label := Label.new()
	title_label.name = "BattleTitle"
	title_label.position = Vector2(0, 8)
	title_label.size = Vector2(900, TITLE_HEIGHT)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	title_label.add_theme_font_size_override("font_size", 22)
	root.add_child(title_label)

	var grid := GridContainer.new()
	grid.name = "CharacterGrid"
	grid.columns = GRID_COLUMNS
	grid.position = Vector2(0, GRID_TOP)
	grid.add_theme_constant_override("h_separation", int(GRID_GAP))
	grid.add_theme_constant_override("v_separation", int(GRID_GAP))
	root.add_child(grid)

	var hint_label := Label.new()
	hint_label.name = "RemainingHint"
	hint_label.add_theme_color_override("font_color", HINT_COLOR)
	hint_label.add_theme_font_size_override("font_size", 14)
	root.add_child(hint_label)

	var tooltip_label := Label.new()
	tooltip_label.name = "SynergyTooltip"
	tooltip_label.add_theme_color_override("font_color", TOOLTIP_COLOR)
	tooltip_label.add_theme_font_size_override("font_size", 12)
	tooltip_label.visible = false
	root.add_child(tooltip_label)

	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = TEXT_CONFIRM
	confirm_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	confirm_button.disabled = true
	root.add_child(confirm_button)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = TEXT_BACK
	back_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	root.add_child(back_button)

	var replace_dialog := ConfirmationDialog.new()
	replace_dialog.name = "ReplaceDialog"
	replace_dialog.title = TEXT_REPLACE_TITLE
	root.add_child(replace_dialog)

	return {
		"title_label": title_label, "grid": grid, "hint_label": hint_label,
		"tooltip_label": tooltip_label, "confirm_button": confirm_button,
		"back_button": back_button, "replace_dialog": replace_dialog,
	}
