class_name SettlementRules
extends RefCounted
## SettlementRules —— 结算面板 Logic 内核纯函数（combat-ui-layout Story 008）。
##
## [b]职责[/b]：胜利结算（战利品三选一）与战败摘要的全部判定逻辑——战利品
## 0.5s 延迟可点判定 [method loot_clickable]、三选一网格等宽计算
## [method loot_grid_layout]、战利品选项 3 态判定 [method loot_option_state]、
## 确认按钮启用判定 [method confirm_button_enabled]、战斗结果→面板种类映射
## [method panel_kind_for]、战败文案构建 [method defeat_lines]。
## 撤退双变体与渡劫战前警示见 [RetreatRules]（同 story、同目录，按职责拆分）。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射——
## 单元测试零依赖。[br]
## [br][b]文案集中[/b]（GDD §9 线框逐行）：全部中文文案为本文件常量，组件层
## 不出现业务字面量（本地化豁免同 S16/S17 口径，待 localization epic 抽 key）。[br]
## [br][b]阈值集中[/b]（control-manifest 禁止硬编码数值）：0.5s 延迟、三选一列数、
## 50%/80% 修为损失比例、朱砂红色值均定义于此，组件只读。[br]
## [br][b]结果取值不硬编码[/b]：战斗结果走 [code]CombatSystem.CombatResult[/code]
## 枚举（信号载荷契约的真理来源），不在本文件重复写 1/2/3。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9 战斗结算面板 /
## §边界情况（三选一网格）/ §调优参数、combat-ui-layout Story 008（AC-1~AC-5）。

## CombatSystem 战斗结果枚举真理来源（preload 避免 Autoload 全局名解析）。
const CombatSystemScript := preload("res://src/feature/combat_system.gd")

## === 面板种类常量 =========================================================

## 无面板。
const KIND_NONE: StringName = &""
## 胜利结算（战利品三选一）。
const KIND_VICTORY: StringName = &"victory"
## 战败结算（损失摘要）。
const KIND_DEFEAT: StringName = &"defeat"
## 撤退确认（普通/渡劫两变体——见 [RetreatRules]）。
const KIND_RETREAT: StringName = &"retreat"
## === 战利品选项状态/种类常量 ==============================================

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

## === 数值常量（GDD 明文）==================================================

## 战利品展示后延迟可点时长（秒——GDD §9「先看清，再选择」）。
const LOOT_CLICK_DELAY_SEC: float = 0.5
## 三选一网格列数（GDD §边界情况：均匀网格 `(panel_width - margins) / 3`）。
const LOOT_COLUMNS: int = 3
## 网格列间隔（px——1920×1080 基准渲染参数）。
const LOOT_GAP: float = 16.0
## 战利品卡格高度（px——渲染参数，非游戏数值）。
const LOOT_CELL_HEIGHT: float = 210.0
## 战利品卡内容块高度（标题 + 副标题 + 角标三段的总高，px——垂直居中基数）。
const CARD_CONTENT_BLOCK_HEIGHT: float = 70.0

## 普通战败/撤退的修为损失比例（GDD §9「损失 50% 本次战斗修为」）。
const CULTIVATION_LOSS_NORMAL: float = 0.5
## 渡劫战撤退的修为损失比例（GDD §10 2026-07-24 修订「80%」）。
const CULTIVATION_LOSS_TRIBULATION: float = 0.8

## === 视觉常量 =============================================================

## 朱砂红——渡劫专属警示色（GDD 明文色值 #B3424A；渡劫 80% 与 Boss 50% 不混用）。
const COLOR_DANGER: Color = Color("#B3424A")
## 普通面板边框色（淡墨）。
const COLOR_PANEL_BORDER: Color = Color(0.55, 0.52, 0.44)
## 面板底色。
const COLOR_PANEL_BG: Color = Color(0.10, 0.11, 0.14, 0.97)
## 背景压暗遮罩色。
const COLOR_BACKDROP: Color = Color(0.0, 0.0, 0.0, 0.62)
## 标题文本色。
const COLOR_TITLE: Color = Color(0.94, 0.92, 0.86)
## 正文文本色。
const COLOR_BODY: Color = Color(0.85, 0.82, 0.74)
## 灰显文本色（卡组已满/不可选）。
const COLOR_MUTED: Color = Color(0.52, 0.52, 0.56)
## 已选中高亮色（金色）。
const COLOR_SELECTED: Color = Color("#E8C06A")

## === 文案常量（GDD §9 线框逐行——本地化豁免）===============================

const TEXT_VICTORY_TITLE: String = "🎉 胜利！"
const TEXT_DEFEAT_TITLE: String = "💀 战败"
const TEXT_LOOT_PROMPT: String = "战利品选择（三选一）："
const TEXT_LOOT_WAITING: String = "战利品展示中…"
const TEXT_LOOT_READY: String = "点击战利品选中，再点确认生效"
const TEXT_CONFIRM_LOOT: String = "确认选择"
const TEXT_SKIP_LOOT: String = "跳过"
const TEXT_RETURN_EXPLORE: String = "返回探索"
const TEXT_DECK_FULL: String = "卡组已满"
const TEXT_SELECTED: String = "已选中"
## 本次无战利品（上游未产出选项时的兜底提示——不显示"点击选中"以免误导）。
const TEXT_NO_LOOT: String = "本次无战利品"


# ═══════════════════════════════════════════════════════════════════════════════
# 战利品延迟可点（AC-2）
# ═══════════════════════════════════════════════════════════════════════════════

## 战利品是否已过延迟可点窗口。[br]
## [br][b]边界固化[/b]：恰好 [constant LOOT_CLICK_DELAY_SEC]（0.5s）即视为可点
## （GDD「展示后 0.5s 延迟才变为可点击」——0.5s 整点已展示完毕）。[br]
## [param elapsed]: 面板弹出后经过的秒数（负值视为 0——防御性钳制）。
static func loot_clickable(elapsed: float) -> bool:
	return maxf(elapsed, 0.0) >= LOOT_CLICK_DELAY_SEC


## 延迟窗口提示文案（等待期 / 就绪期）。[br]
## [param clickable]: [method loot_clickable] 的结果。
static func loot_hint_text(clickable: bool) -> String:
	return TEXT_LOOT_READY if clickable else TEXT_LOOT_WAITING


## 胜利面板提示文案（含空战利品兜底）。[br]
## [param clickable]: 是否已过 0.5s 延迟窗口。[br]
## [param option_count]: 战利品选项数量（0 → 本次无战利品）。[br]
## [br]空战利品时上游没给任何选项（战斗系统暂不产出 loot），若仍显示
## 「点击战利品选中」会让玩家对着空网格点——本函数给出明确兜底文案。
static func victory_hint_text(clickable: bool, option_count: int) -> String:
	if option_count <= 0:
		return TEXT_NO_LOOT
	return loot_hint_text(clickable)


# ═══════════════════════════════════════════════════════════════════════════════
# 三选一网格（AC-1）
# ═══════════════════════════════════════════════════════════════════════════════

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


# ═══════════════════════════════════════════════════════════════════════════════
# 卡组满判定与选项状态（AC-4）
# ═══════════════════════════════════════════════════════════════════════════════

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


# ═══════════════════════════════════════════════════════════════════════════════
# 确认按钮（AC-3）
# ═══════════════════════════════════════════════════════════════════════════════

## 确认选择按钮是否可点——[b]必须同时满足[/b]「已选中某项」与「已过延迟窗口」。[br]
## [param selected_index]: 已选中选项下标（-1 = 未选中）。[br]
## [param clickable]: 是否已过延迟窗口（[method loot_clickable]）。
static func confirm_button_enabled(selected_index: int, clickable: bool) -> bool:
	return clickable and selected_index >= 0


# ═══════════════════════════════════════════════════════════════════════════════
# 战斗结果 → 面板种类（AC-2）
# ═══════════════════════════════════════════════════════════════════════════════

## 战斗结果 → 结算面板种类。[br]
## [br][b]未知结果返回 [constant KIND_NONE][/b]（不静默默认成胜利——
## 由调用侧按返回值守卫）。[br]
## [param result]: [code]CombatSystem.CombatResult[/code] 取值。
static func panel_kind_for(result: int) -> StringName:
	if result == CombatSystemScript.CombatResult.VICTORY:
		return KIND_VICTORY
	if result == CombatSystemScript.CombatResult.DEFEAT:
		return KIND_DEFEAT
	if result == CombatSystemScript.CombatResult.RETREAT:
		return KIND_RETREAT
	return KIND_NONE


# ═══════════════════════════════════════════════════════════════════════════════
# 弹窗尺寸（control-manifest Required：弹窗不覆盖全屏）
# ═══════════════════════════════════════════════════════════════════════════════

## 弹窗外框是否满足「不覆盖全屏」（宽高均严格小于视口）。[br]
## [param frame_size]: 弹窗外框尺寸。[br]
## [param viewport_size]: 视口尺寸（≤0 时无法判定——宽松返回 true）。
static func panel_fits_within_viewport(frame_size: Vector2,
		viewport_size: Vector2) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return true
	return frame_size.x < viewport_size.x and frame_size.y < viewport_size.y


# ═══════════════════════════════════════════════════════════════════════════════
# 战败损失摘要（AC-5）
# ═══════════════════════════════════════════════════════════════════════════════

## 战败面板标题（GDD §9 失败面板线框「💀 战败」）。
static func defeat_title() -> String:
	return TEXT_DEFEAT_TITLE


## 修为损失百分比（整数——GDD「损失 50%」）。[br]
## [param is_tribulation]: 是否渡劫战（渡劫撤退 80%，见 [RetreatRules]）。
static func cultivation_loss_percent(is_tribulation: bool = false) -> int:
	var ratio: float = CULTIVATION_LOSS_TRIBULATION if is_tribulation \
			else CULTIVATION_LOSS_NORMAL
	return int(round(ratio * 100.0))


## 战败损失摘要正文行（GDD §9 失败面板线框：修为损失 / 阵亡角色 / 绑定卡）。[br]
## [param summary]: [code]{cultivation_lost: int, dead_names: Array,
## binding_card_count: int}[/code]（字段缺失按 0/空处理）。[br]
## [br][b]返回[/b]: 正文行数组（不含标题）。
static func defeat_lines(summary: Dictionary) -> Array:
	var lines: Array = []
	var lost: int = int(summary.get("cultivation_lost", 0))
	var loss_line: String = "损失 %d%% 本次战斗修为" % cultivation_loss_percent()
	if lost > 0:
		loss_line += "（-%d）" % lost
	lines.append(loss_line)
	var names: Array = summary.get("dead_names", [])
	if names is Array and not names.is_empty():
		var parts: Array = []
		for n: Variant in names:
			parts.append(str(n))
		lines.append("阵亡角色：%s（不可用）" % "、".join(PackedStringArray(parts)))
	else:
		lines.append("阵亡角色：无")
	var binding_count: int = int(summary.get("binding_card_count", 0))
	if binding_count > 0:
		lines.append("绑定卡失去：%d 张（洗回牌库）" % binding_count)
	return lines
