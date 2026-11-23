class_name SettlementLootRules
extends RefCounted
## SettlementLootRules —— 战利品选项的几何、状态与标签内核（拆分自 [SettlementRules]）。[br]
##
## [b]职责[/b]：把「战利品那一格怎么画、那一项能不能点、上面写什么」这三件事固定下来——[br]
##   · [method loot_grid_layout] / [method loot_card_content_top]：等宽网格与卡内垂直居中；[br]
##   · [method is_deck_full] / [method loot_option_state] / [method option_clickable]：
##     三项判定（只有卡牌受卡组上限约束）；[br]
##   · [method loot_option_note] / [method loot_option_label]：角标与标题副标题。[br]
## [b]不管什么[/b]：不判定胜负、不决定延迟窗口、不建面板——那些留在 [SettlementRules]。[br]
## [br][b]为什么单独成文件[/b]：本块是「选项本身」的一整套口径（几何 + 状态 + 文案），
## 与面板编排、延迟窗口、战败摘要是四类事；[code]settlement_rules.gd[/code] 挤在一起时
## 超出 300 行软上限（编码标准）。调用方仍从 [SettlementRules] 进入（门面转发）。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射。
##
## 来源: design/gdd/combat-ui-system.md §9 / §边界情况（均匀网格）、
## combat-ui-layout Story 008（AC-1/AC-4）、拆分自 settlement_rules（行数预算）。

## === 战利品选项状态 / 种类常量 ==============================================

## 可选（可点高亮）。
const OPTION_AVAILABLE: String = "available"
## 已选中（高亮——非确认）。
const OPTION_SELECTED: String = "selected"
## 卡组已满（卡牌选项灰显不可选）。
const OPTION_DECK_FULL: String = "deck_full"

## 卡牌类战利品（唯一受卡组上限约束的种类）。
const OPTION_KIND_CARD: String = "card"
## 灵石类战利品。
const OPTION_KIND_LINGSHI: String = "lingshi"
## 消耗品类战利品。
const OPTION_KIND_CONSUMABLE: String = "consumable"

## === 数值常量（GDD 明文）===================================================

## 三选一网格列数（GDD §边界情况：均匀网格 `(panel_width - margins) / 3`）。
const LOOT_COLUMNS: int = 3
## 网格列间隔（px——1920×1080 基准渲染参数）。
const LOOT_GAP: float = 16.0
## 战利品卡格高度（px——渲染参数，非游戏数值）。
const LOOT_CELL_HEIGHT: float = 210.0
## 战利品卡内容块高度（标题 + 副标题 + 角标三段的总高，px——垂直居中基数）。
const CARD_CONTENT_BLOCK_HEIGHT: float = 70.0

## === 选项角标文案（本地化豁免，同 [SettlementRules] 口径）==================

## 卡组已满角标。
const TEXT_DECK_FULL: String = "卡组已满"
## 已选中角标。
const TEXT_SELECTED: String = "已选中"


## 三选一均匀等宽网格布局。[br]
## [br][b]公式[/b]（GDD §边界情况）：
## [code]cell_width = (content_width - gap × (columns - 1)) / columns[/code]，
## 即「(panel_width - margins) / 3」在含列间隔时的严格形式。[br]
## [br][b]窄面板不产负宽[/b]：内容宽度不足以容纳间隔时 cell_width 钳制为 0
## （布局退化但不产生负尺寸——Godot 负 width 会触发警告）。[br]
## [param content_width]: 可用内容宽度（已扣除面板左右内边距）。[br]
## [param gap]: 列间隔（px）。[br]
## [param columns]: 列数（≤0 时按 1 处理）。
## [br][b]返回[/b]: [code]{columns, cell_width, gap, used_width}[/code]。
static func loot_grid_layout(content_width: float, gap: float = LOOT_GAP,
		columns: int = LOOT_COLUMNS) -> Dictionary:
	var cols: int = maxi(columns, 1)
	var safe_gap: float = maxf(gap, 0.0)
	var total_gap: float = safe_gap * float(cols - 1)
	var cell_width: float = maxf((maxf(content_width, 0.0) - total_gap)
			/ float(cols), 0.0)
	return {
		"columns": cols,
		"cell_width": cell_width,
		"gap": safe_gap,
		"used_width": cell_width * float(cols) + total_gap,
	}


## 战利品卡内容块顶边（垂直居中于卡面——标题/副标题/角标三段整体居中）。[br]
## [br][b]为什么进内核[/b]：垂直居中是 GDD §边界情况「均匀网格」的可见要求，
## 但纯几何计算若散落在自绘组件里就无法断言；本函数把口径固定下来，
## 组件只负责调用（窄卡片时钳制为 0，不产生负基线）。[br]
## [param cell_height]: 卡格高度（px）。
static func loot_card_content_top(cell_height: float) -> float:
	return maxf((cell_height - CARD_CONTENT_BLOCK_HEIGHT) * 0.5, 0.0)


## 卡组是否已满——[b]上限未初始化按未满处理[/b]（deck_limit ≤ 0 时不误拦）。[br]
## [param deck_count]: 当前卡组张数。[br]
## [param deck_limit]: 当前境界卡组上限。
static func is_deck_full(deck_count: int, deck_limit: int) -> bool:
	if deck_limit <= 0:
		return false
	return deck_count >= deck_limit


## 战利品选项初始态判定。[br]
## [br][b]只有卡牌受卡组上限约束[/b]——灵石/消耗品在卡组满时仍可选（不占卡位）。[br]
## [param option]: 选项字典（[code]{kind, ...}[/code]）。[br]
## [param deck_count]: 当前卡组张数。[br]
## [param deck_limit]: 当前境界卡组上限。
static func loot_option_state(option: Dictionary, deck_count: int,
		deck_limit: int) -> String:
	if str(option.get("kind", "")) == OPTION_KIND_CARD \
			and is_deck_full(deck_count, deck_limit):
		return OPTION_DECK_FULL
	return OPTION_AVAILABLE


## 选项是否可点（[constant OPTION_DECK_FULL] 不可点，其余可点）。[br]
## [param state]: [method loot_option_state] 的结果。
static func option_clickable(state: String) -> bool:
	return state != OPTION_DECK_FULL


## 选项角标文案（已选中 / 卡组已满 / 空）。
static func loot_option_note(state: String) -> String:
	match state:
		OPTION_SELECTED:
			return TEXT_SELECTED
		OPTION_DECK_FULL:
			return TEXT_DECK_FULL
		_:
			return ""


## 战利品选项标题与副标题（GDD §9 线框「青云剑诀 / (蓝·功法)」「灵石 / ×25」）。[br]
## [param option]: 选项字典——卡牌 [code]{kind, name, rarity, school}[/code]；
## 灵石 [code]{kind, amount}[/code]；消耗品 [code]{kind, name}[/code]。
## [br][b]返回[/b]: [code]{title, subtitle}[/code]。
static func loot_option_label(option: Dictionary) -> Dictionary:
	match str(option.get("kind", "")):
		OPTION_KIND_CARD:
			var rarity: String = str(option.get("rarity", ""))
			var school: String = str(option.get("school", ""))
			var sub: String = ""
			if not rarity.is_empty() and not school.is_empty():
				sub = "（%s·%s）" % [rarity, school]
			else:
				sub = "（功法）"
			return {"title": str(option.get("name", "未知卡牌")), "subtitle": sub}
		OPTION_KIND_LINGSHI:
			return {"title": "灵石", "subtitle": "×%d" % int(option.get("amount", 0))}
		OPTION_KIND_CONSUMABLE:
			return {"title": str(option.get("name", "未知物品")), "subtitle": "（消耗品）"}
		_:
			return {"title": str(option.get("name", "未知")), "subtitle": ""}
