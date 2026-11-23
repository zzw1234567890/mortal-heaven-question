class_name SettlementRules
extends RefCounted
## SettlementRules —— 结算面板 Logic 内核纯函数（combat-ui-layout Story 008）。
##
## [b]职责[/b]：[b]结算面板对外唯一入口[/b]——把三类判定与文案转发给各自的实现文件，
## 组件层（面板 / 视图 / 卡片 / 宿主）只 preload 本文件：[br]
##   · 延迟窗口与结果映射：[method loot_clickable] / [method panel_kind_for] /
##     [method confirm_button_enabled] / [method defeat_lines]（本文件实现）；[br]
##   · 战利品选项几何 / 状态 / 标签：[SettlementLootRules]（同目录）；[br]
##   · 两段式文案（选择段标题 / 入账段标记）：[SettlementSectionText]（同目录）；[br]
##   · 撤退双变体与渡劫战前警示：[RetreatRules]（同 story、同目录）。[br]
## [br][b]为什么拆成三份而本文件保留同名转发[/b]：三块职责彼此不相关
## （几何计算 / 中文措辞 / 延迟与结果），挤在一份里超出 300 行软上限
## （.claude/docs/coding-standards.md）；而[b]调用方不该知道拆分发生在我们内部[/b]
## ——多一个 preload 入口就等于「结算规则在哪」有两个答案。常量同样转发，
## 因此 [code]Rules.OPTION_DECK_FULL[/code] 这类既有写法一处都不用改。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射——
## 单元测试零依赖。[br]
## [br][b]文案集中[/b]（GDD §9 线框逐行）：全部中文文案为常量，组件层
## 不出现业务字面量（本地化豁免同 S16/S17 口径，待 localization epic 抽 key）。[br]
## [br][b]阈值集中[/b]（control-manifest 禁止硬编码数值）：0.5s 延迟、三选一列数、
## 50%/80% 修为损失比例、朱砂红色值均有单一出处，组件只读。[br]
## [br][b]结果取值不硬编码[/b]：战斗结果走 [code]CombatSystem.CombatResult[/code]
## 枚举（信号载荷契约的真理来源），不在本文件重复写 1/2/3。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9 战斗结算面板 /
## §边界情况（三选一网格）/ §调优参数、combat-ui-layout Story 008（AC-1~AC-5）、
## DEBT-CUI-008-3（两段式结算文案）。

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

## === 数值常量（GDD 明文）==================================================

## 战利品展示后延迟可点时长（秒——GDD §9「先看清，再选择」）。
const LOOT_CLICK_DELAY_SEC: float = 0.5

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
const TEXT_LOOT_WAITING: String = "战利品展示中…"
const TEXT_LOOT_READY: String = "点击战利品选中，再点确认生效"
const TEXT_CONFIRM_LOOT: String = "确认选择"
const TEXT_SKIP_LOOT: String = "跳过"
const TEXT_RETURN_EXPLORE: String = "返回探索"
## 本次无战利品（上游未产出选项时的兜底提示——不显示"点击选中"以免误导）。
const TEXT_NO_LOOT: String = "本次无战利品"


# ═══════════════════════════════════════════════════════════════════════════════
# 两段式结算文案（选择段 / 入账段——DEBT-CUI-008-3）与战利品选项
# ═══════════════════════════════════════════════════════════════════════════════
#
# 两块的实现分别在 [SettlementSectionText]（措辞与分档阈值）与 [SettlementLootRules]
# （几何 / 状态 / 标签）——本文件按行数预算把实现搬了出去，保留[b]同名常量与同名
# 转发[/b]：调用方（卡片 / 视图 / 面板 / 宿主 / 测试）只 preload 本文件，
# 既有写法一处都不用改，也不必知道拆分发生在内部。

## 文案分档内核（选择段标题 / 确认按钮 / 入账段标记）。
const Section := preload("res://src/ui/combat/shared/settlement_section_text.gd")
## 选项几何与状态内核。
const Loot := preload("res://src/ui/combat/shared/settlement_loot_rules.gd")


## 选择段标题（按实际候选数——见 [method SettlementSectionText.loot_pick_title]）。
static func loot_pick_title(p_option_count: int) -> String:
	return Section.loot_pick_title(p_option_count)


## 候选是否构成「选择」（≥2 项——见 [method SettlementSectionText.has_choice]）。
static func has_choice(p_option_count: int) -> bool:
	return Section.has_choice(p_option_count)


## 已入账 / 未入账两段的段首标记。
static func granted_section_lines(p_lines: Array) -> Array:
	return Section.granted_section_lines(p_lines)


static func pending_section_lines(p_lines: Array) -> Array:
	return Section.pending_section_lines(p_lines)


## 战利品选项状态 / 种类（转发——见 [SettlementLootRules]）。
const OPTION_AVAILABLE: String = Loot.OPTION_AVAILABLE
const OPTION_SELECTED: String = Loot.OPTION_SELECTED
const OPTION_DECK_FULL: String = Loot.OPTION_DECK_FULL
const OPTION_KIND_CARD: String = Loot.OPTION_KIND_CARD
const OPTION_KIND_LINGSHI: String = Loot.OPTION_KIND_LINGSHI
const OPTION_KIND_CONSUMABLE: String = Loot.OPTION_KIND_CONSUMABLE

## 网格与卡格渲染参数（转发）。
const LOOT_COLUMNS: int = Loot.LOOT_COLUMNS
const LOOT_GAP: float = Loot.LOOT_GAP
const LOOT_CELL_HEIGHT: float = Loot.LOOT_CELL_HEIGHT
const CARD_CONTENT_BLOCK_HEIGHT: float = Loot.CARD_CONTENT_BLOCK_HEIGHT

## 选项角标文案（转发）。
const TEXT_DECK_FULL: String = Loot.TEXT_DECK_FULL
const TEXT_SELECTED: String = Loot.TEXT_SELECTED


static func loot_grid_layout(content_width: float, gap: float = LOOT_GAP,
		columns: int = LOOT_COLUMNS) -> Dictionary:
	return Loot.loot_grid_layout(content_width, gap, columns)


static func loot_card_content_top(cell_height: float) -> float:
	return Loot.loot_card_content_top(cell_height)


static func is_deck_full(deck_count: int, deck_limit: int) -> bool:
	return Loot.is_deck_full(deck_count, deck_limit)


static func loot_option_state(option: Dictionary, deck_count: int,
		deck_limit: int) -> String:
	return Loot.loot_option_state(option, deck_count, deck_limit)


static func option_clickable(state: String) -> bool:
	return Loot.option_clickable(state)


static func loot_option_note(state: String) -> String:
	return Loot.loot_option_note(state)


static func loot_option_label(option: Dictionary) -> Dictionary:
	return Loot.loot_option_label(option)


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
## [param option_count]: 战利品选项数量（0 → 本次无战利品；1 → 没有可挑的，
## 就绪期改说「直接确认带走」——「点击选中」在只有一项时是无意义的指引）。[br]
## [br]空战利品时上游没给任何选项（战斗系统暂不产出 loot），若仍显示
## 「点击战利品选中」会让玩家对着空网格点——本函数给出明确兜底文案。[br]
## [br][b]阈值与选择段标题同源[/b]：两处都按「实际候选数」分档（0 / 1 / ≥2），
## 分档点与 [method SettlementSectionText.loot_pick_title] 逐条对齐
## （[code]<= 0[/code] / [code]== 1[/code]），一处改档另一处必须跟着改
## ——否则会出现「标题写 2 选 1 而提示说点确认带走」这类自相矛盾。
static func victory_hint_text(clickable: bool, option_count: int) -> String:
	if option_count <= 0:
		return TEXT_NO_LOOT
	if not clickable:
		return TEXT_LOOT_WAITING
	if option_count == 1:
		return Section.TEXT_PICK_ONE_HINT
	return TEXT_LOOT_READY


## 确认选择按钮是否可点——[b]必须同时满足[/b]「已选中某项」与「已过延迟窗口」。[br]
## [param selected_index]: 已选中选项下标（-1 = 未选中）。[br]
## [param clickable]: 是否已过延迟窗口（[method loot_clickable]）。
static func confirm_button_enabled(selected_index: int, clickable: bool) -> bool:
	return clickable and selected_index >= 0


## 确认按钮文案——按候选数分档（1 项时是「直接带走」，不是「从 N 项里挑一个」）。[br]
## [br][b]与 [method loot_pick_title] 同一阈值[/b]：一处写「N 选 1」而按钮写「确认选择」，
## 玩家会以为漏了一步（真机走查里「候选不足 3 项仍写三选一」正是同一类错）。[br]
## [br][b]转发给 [method SettlementSectionText.confirm_button_text][/b]：多项文案由本
## 文件给（[constant TEXT_CONFIRM_LOOT]），分档阈值与标题共用一处。
static func confirm_button_text(p_option_count: int) -> String:
	return Section.confirm_button_text(p_option_count, TEXT_CONFIRM_LOOT)


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
