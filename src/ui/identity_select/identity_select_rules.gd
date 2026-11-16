extends RefCounted
## IdentitySelectRules —— 身份选择界面的判定与文本拼装（静态纯函数子模块）。
##
## 从 [code]identity_select.gd[/code] 拆出：UI 场景脚本只留节点编排与交互，
## 纯判定/纯拼装集中在这里（static + 无 Autoload 访问 → GUT 可直调）。
##
## [br][b]两级门禁[/b]（story-004 AC-1/AC-2 的扩展）：[br]
##   [code]is_identity_unlocked[/code]——身份是否已由轮回天赋解锁（透传身份表口径）。[br]
##   [code]is_identity_ready[/code]——已解锁[b]且[/b]卡组模板齐备，才允许开局。[br]
##   只锁「未解锁」会漏掉第二种情况：身份解锁了、卡牌资产却没落盘，
##   玩家点确认后 [code]apply_identity[/code] 中途失败——界面必须提前拦住并说清楚。
##
## [br][b]不静默降级[/b]：被拦下时返回明确的提示文案，绝不改用身份①开局。
##
## [br]来源: ADR-0031 §2（UI 零状态所有权）、ADR-0022 §get_available_identities、
## design/gdd/identity-selection-system.md §用户界面需求、story-004-identity-select-ui.md。

## === 固定 UI 词条（GDD §用户界面需求原文；项目暂无本地化系统——先例
## MainMenu.TEXT_* 同源豁免注记，本地化入库后替换为键）============================

const TEXT_TITLE: String = "选择你的开局身份"
const TEXT_CONFIRM_BUTTON: String = "确认选择"
const TEXT_CONFIRM_PROMPT: String = "确定选择？本局不可更改"
## 未解锁提示（GDD §边界情况原文）。
const TEXT_LOCKED_TOAST: String = "该身份需要轮回天赋『苍玄行者』解锁"
## 已解锁但资料不全（卡组模板缺失 / 身份表查无）——禁止开局。
const TEXT_NOT_OPEN_TOAST: String = "该身份暂未开放"
## apply_identity 失败时的兜底提示——绝不无声无息。
const TEXT_APPLY_FAILED_TOAST: String = "开局失败：该身份暂未开放，请另选一个身份"
## 提示弹窗标题（与文案同源，避免标题停留在上一次的语义上）。
const TEXT_LOCKED_TITLE: String = "未解锁身份"
const TEXT_NOT_OPEN_TITLE: String = "身份暂未开放"
const TEXT_APPLY_FAILED_TITLE: String = "开局失败"
## 底部详情面板分段标签（集中成 const 块，不散落魔法字符串）。
const TEXT_DECK_HEADER: String = "初始卡组"
const TEXT_CHARACTER_HEADER: String = "初始角色"
const TEXT_TALENT_HEADER: String = "专属天赋"
const TEXT_LING_SHI_SUFFIX: String = "灵石"

## 未解锁原因标识。
const REASON_LOCKED: StringName = &"locked"
## 已解锁但资源不全 / 身份表查无——归入「暂未开放」。
const REASON_NOT_OPEN: StringName = &"not_open"
## 无阻断。
const REASON_NONE: StringName = &""

## 就绪度子模块——[code]is_ready[/code] / [code]block_reason[/code] 的字段口径来源。
const _Unlock := preload("res://src/feature/identity/identity_unlock.gd")


# === 门禁判定 ===================================================================

## 确认按钮启用态判定（AC-1 / QA AC-1）。[br]
## [br][param selected_id]: 当前选中身份 ID（空 StringName = 未选中）。[br]
## [b]返回[/b]: 空选中 → [code]false[/code]；非空 → [code]true[/code]。[br]
## [br]纯函数——无状态、无 Autoload 访问（static 供 GUT 直调）。[br]
## [br][b]注意[/b]：本函数只答「有没有选」，不答「选中的能不能开局」——
## 后者由 [method is_identity_ready] 叠加（[method confirm_enabled_for] 是两者的合取）。
static func confirm_button_enabled(selected_id: StringName) -> bool:
	return not selected_id.is_empty()


## 解锁状态透传（AC-2 / QA AC-2）。[br]
## [br][param entry]: [code]get_available_identities()[/code] 返回的单条目
## Dictionary（含 [code]is_unlocked[/code] 字段）。[br]
## [b]返回[/b]: 透传 [code]entry.get(&"is_unlocked", false)[/code]——不自算
## 解锁条件（[code]get_available_identities[/code] 已结合轮回天赋状态算好）。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func is_identity_unlocked(entry: Dictionary) -> bool:
	return bool(entry.get(&"is_unlocked", false))


## 开局就绪判定——已解锁且卡组模板齐备。[br]
## [br][param entry]: 同上条目。[br]
## [b]返回[/b]: [code]is_ready[/code] 字段，缺字段时回退 [code]is_unlocked[/code]。[br]
## [br][b]缺字段为何这样回退[/b]：老口径的条目只带 [code]is_unlocked[/code]
## （如既有单测的 mock），此时「已解锁即可开局」是唯一可得的判断；
## 新口径条目一律带 [code]is_ready[/code]，回退不会生效。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func is_identity_ready(entry: Dictionary) -> bool:
	if not is_identity_unlocked(entry):
		return false
	return bool(entry.get(&"is_ready", true))


## 按钮启用态——「选了」且「选中那个能开局」。[br]
## [br][b]返回[/b]: 两者皆真才 true。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func confirm_enabled_for(selected_id: StringName, entry: Dictionary) -> bool:
	return confirm_button_enabled(selected_id) and is_identity_ready(entry)


## 开局阻断原因——供 UI 决定提示文案（边界情况表：未解锁提示天赋名、
## 资料不全提示「暂未开放」）。[br]
## [br][param entry] 身份条目；空字典视为「暂未开放」（身份表查无＝还没做）。[br]
## [br][b]返回[/b]: [constant REASON_NONE] / [constant REASON_LOCKED] /
## [constant REASON_NOT_OPEN]。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func start_block_reason(entry: Dictionary) -> StringName:
	if entry.is_empty():
		return REASON_NOT_OPEN
	if not is_identity_unlocked(entry):
		return REASON_LOCKED
	if not is_identity_ready(entry):
		return REASON_NOT_OPEN
	return REASON_NONE


## 阻断原因 → 面向玩家的提示文案（空串 = 无阻断）。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func blocked_toast_text(entry: Dictionary) -> String:
	match start_block_reason(entry):
		REASON_LOCKED:
			return TEXT_LOCKED_TOAST
		REASON_NOT_OPEN:
			return TEXT_NOT_OPEN_TOAST
		_:
			return ""


## 阻断原因 → 弹窗标题。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func blocked_toast_title(entry: Dictionary) -> String:
	match start_block_reason(entry):
		REASON_LOCKED:
			return TEXT_LOCKED_TITLE
		REASON_NOT_OPEN:
			return TEXT_NOT_OPEN_TITLE
		_:
			return ""


# === 详情面板拼装（纯函数——从 preview 字典读，不硬编码卡名/角色名）=============

## 卡组概览——卡名×数量拼装。
static func deck_summary(preview: Dictionary) -> String:
	var parts: Array[String] = []
	for card_entry: Dictionary in preview.get(&"initial_deck_cards", []):
		parts.append("%s×%d" % [str(card_entry.get(&"card_id", "")),
				int(card_entry.get(&"count", 0))])
	return "、".join(parts)


## 角色概览——角色显示名拼装（从 character_details 读 display_name）。
static func character_summary(preview: Dictionary) -> String:
	var parts: Array[String] = []
	for detail: Dictionary in preview.get(&"character_details", []):
		parts.append(str(detail.get(&"display_name", "")))
	return "+".join(parts)


## 天赋描述——名称 + 描述。
static func talent_summary(preview: Dictionary) -> String:
	var talent: Dictionary = preview.get(&"talent", {})
	return "%s：%s" % [str(talent.get(&"name", "")),
			str(talent.get(&"description", ""))]


## 角色显示名列表——供头像占位渲染（防御 character_details 缺失）。
static func character_names(preview: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for detail: Dictionary in preview.get(&"character_details", []):
		names.append(str(detail.get(&"display_name", "")))
	return names


# === 叙事文本（纯函数）=========================================================

## 叙事文本拆分——按句读拆行（。！？后断行，空行过滤）。
static func split_narrative(text: String) -> Array[String]:
	var lines: Array[String] = []
	var current: String = ""
	for ch: String in text:
		current += ch
		if ch in ["。", "！", "？"]:
			lines.append(current)
			current = ""
	if not current.is_empty():
		lines.append(current)
	if lines.is_empty() and not text.is_empty():
		lines.append(text)
	return lines
