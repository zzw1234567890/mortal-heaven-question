extends RefCounted
## MapClearPanelRules —— 地图通关结算面板的[b]文案内核[/b]（纯函数）。[br]
## [br][b]职责[/b]：把 [code]MapClearView[/code] 的结算载荷翻成面板该显示的段与行——
## 标题、地图名、通关次数、基础奖励行、首通奖励行、卡牌行文本、卡牌详情行。[br]
## [br][b]为什么单独一处[/b]：[code]map_clear_panel_screen.gd[/code] 只该管「控件怎么
## 搭、意图怎么发」，而「哪些行该出现、每行长什么样」是一次确定映射——纯函数可脱开
## 控件树单测（同 [code]boss_confirm_rules.gd[/code] /
## [code]combat_reward_lines.gd[/code] 先例，ADR-0031 Logic 内核模式）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读入参字典，不读 Autoload、不写任何状态，
## 也不重算奖励数值——数值在 [code]ExplorationMapFlush._settle_boss_defeated[/code]
## 里已经算好并[b]已发放[/b]，本模块只负责措辞。[br]
## [br][b]首通行由标志位决定[/b]（GDD exploration-ui-system.md §7「非首次通关不显示
## 首次通关奖励行」）：判据是载荷的 [code]is_first_clear[/code]，[b]不是[/b]
## 「首通奖励是否为空」——重复通关时上游连 [code]extra[/code] 键都不塞，用「空」当
## 判据会把「首通但配置漏写奖励」也一并藏掉。[br]
## [br][b]文案本地化豁免[/b]：与 node_interaction_rules / settlement_rules 同源口径
## （项目暂无本地化系统），全部中文集中在 [constant TEXT_*]，待 localization epic 抽 key。[br]
##
## 来源: design/gdd/exploration-ui-system.md §7 地图通关结算、
## design/gdd/exploration-system.md §5 地图通关奖励、ADR-0014 §决策 5、
## ADR-0031 §2/§4。

## 结算载荷的键名真理来源（发布方与面板都不裸写字符串）。
const ClearView := preload("res://src/feature/exploration/map_clear_view.gd")

## 面板标题（GDD §7 线框首行）。
const TEXT_TITLE: String = "地图通关！"
## 基础奖励段标题。
const TEXT_BASE_SECTION: String = "📦 通关奖励"
## 首通额外奖励段标题。
const TEXT_FIRST_SECTION: String = "⭐ 首次通关奖励"
## 通关次数行（重复通关时玩家能看出这是第几次）。
const TEXT_CLEAR_COUNT: String = "第 %d 次通关"
## 奖励行（GDD §7 线框「灵石 × 50   修为 × 50」）。
const TEXT_LING_SHI: String = "灵石 × %d"
const TEXT_CULTIVATION: String = "修为 × %d"
## 卡牌行尾注（GDD §7 线框「← 点击查看」）。
const TEXT_CARD_HINT: String = "← 点击查看"
## 稀有度/类型括号（与 [code]combat_reward_lines._card_tag[/code] 同口径）。
const TEXT_TAG_TWO: String = "（%s·%s）"
const TEXT_TAG_ONE: String = "（%s）"
## 确认按钮文案（GDD §7 线框尾行；也是「回到地图选择」的唯一出口）。
const TEXT_CONFIRM: String = "确认"
## 本段无任何奖励时的兜底（不显示空段标题，见 [method has_any_reward]）。
const TEXT_NOTHING: String = "本次无额外奖励"
## 卡牌名兜底（模板与载荷都没给名字）。
const NAME_UNKNOWN_CARD: String = "未知卡牌"


# ═══════════════════════════════════════════════════════════════════════════════
# 面板骨架
# ═══════════════════════════════════════════════════════════════════════════════

## 面板标题（GDD §7 首行）。
static func title() -> String:
	return TEXT_TITLE


## 地图中文名——探明表登记名优先，缺失回退地图 ID（不臆造名字）。[br]
## [br][b]两者都没有时返回空串[/b]：面板会整行省略，不显示一个占位名。
static func map_name(p_view: Dictionary) -> String:
	if p_view == null:
		return ""
	var name: String = str(p_view.get(ClearView.KEY_MAP_NAME, ""))
	if not name.strip_edges().is_empty():
		return name
	return str(p_view.get(ClearView.KEY_MAP_ID, ""))


## 通关次数行（次数 ≤ 0 时返回空串——面板整行省略）。[br]
## [br][b]为什么显示次数[/b]：首通行与重复通行的差别只在「有没有额外奖励」，
## 次数行让玩家确认这一局算第几次，而不必去地图卡片上找。[br]
static func clear_count_text(p_view: Dictionary) -> String:
	if p_view == null:
		return ""
	var count: int = int(p_view.get(ClearView.KEY_CLEAR_COUNT, 0))
	return "" if count <= 0 else TEXT_CLEAR_COUNT % count


## 是否显示首通奖励段（判据是载荷的标志位，不是「奖励是否为空」——见类文档）。[br]
## [br][b]空载荷按 false[/b]：没有结算就没有首通可言。
static func shows_first_section(p_view: Dictionary) -> bool:
	if p_view == null or p_view.is_empty():
		return false
	return bool(p_view.get(ClearView.KEY_IS_FIRST_CLEAR, false))


## 本次结算是否有任何奖励可展示（基础段或首通段）。[br]
## [br][b]用途[/b]：全为零时面板给出 [constant TEXT_NOTHING]，而不是画一个空段标题。[br]
## [br][b]首通段只在 [method shows_first_section] 为真时计入[/b]：重复通关的载荷里
## [code]first_*[/code] 本就是 0 / 空，但判据必须与显示判据同源，否则会出现
## 「显示判据说没有、非空判据说有」的分叉。
static func has_any_reward(p_view: Dictionary) -> bool:
	if p_view == null:
		return false
	if not amount_lines(int(p_view.get(ClearView.KEY_LING_SHI, 0)),
			int(p_view.get(ClearView.KEY_CULTIVATION, 0))).is_empty():
		return true
	if not cards_of(p_view, ClearView.KEY_CARDS).is_empty():
		return true
	if not shows_first_section(p_view):
		return false
	if not amount_lines(int(p_view.get(ClearView.KEY_FIRST_LING_SHI, 0)),
			int(p_view.get(ClearView.KEY_FIRST_CULTIVATION, 0))).is_empty():
		return true
	return not cards_of(p_view, ClearView.KEY_FIRST_CARDS).is_empty()


# ═══════════════════════════════════════════════════════════════════════════════
# 奖励行
# ═══════════════════════════════════════════════════════════════════════════════

## 灵石/修为行——非正数不出行（不显示「灵石 × 0」这种噪音）。[br]
## [br][b]返回[/b]：0~2 行，顺序固定「灵石 → 修为」（与 GDD §7 线框同序）。[br]
## [br][b]UI 零数值计算[/b]：数字由 Feature 层算好传入，本函数只拼接单位。
static func amount_lines(p_ling_shi: int, p_cultivation: int) -> Array:
	var lines: Array = []
	if p_ling_shi > 0:
		lines.append(TEXT_LING_SHI % p_ling_shi)
	if p_cultivation > 0:
		lines.append(TEXT_CULTIVATION % p_cultivation)
	return lines


## 某个段（基础 / 首通）的灵石修为行。[br]
## [br][param p_first] true 取首通三键，false 取基础三键——两段的键名不同但排版相同，
## 归一处保证两段不会各写一套。
static func section_amount_lines(p_view: Dictionary, p_first: bool) -> Array:
	if p_view == null:
		return []
	if p_first:
		return amount_lines(int(p_view.get(ClearView.KEY_FIRST_LING_SHI, 0)),
				int(p_view.get(ClearView.KEY_FIRST_CULTIVATION, 0)))
	return amount_lines(int(p_view.get(ClearView.KEY_LING_SHI, 0)),
			int(p_view.get(ClearView.KEY_CULTIVATION, 0)))


## 某个段的卡牌条目（基础 / 首通）。[br]
## [br][b]为什么分两段取[/b]：基础卡与首通卡在面板上是两段（GDD §7 首通行独立高亮），
## 合并成一段后就无从区分哪张卡是首通彩头。
static func section_cards(p_view: Dictionary, p_first: bool) -> Array:
	if p_view == null:
		return []
	var key: String = ClearView.KEY_FIRST_CARDS if p_first else ClearView.KEY_CARDS
	return cards_of(p_view, key)


## 段内的卡牌条目（缺键 / 非数组 / 脏条目一律丢弃——不臆造卡牌）。[br]
## [br][b]非字典条目按「有 ID 的卡」收下[/b]：发放器产出的是字典，但配置侧允许裸 ID
## 字符串（[method card_row_text] 能处理），故这里只过滤 null 与非容器的杂值。
static func cards_of(p_view: Dictionary, p_key: String) -> Array:
	var raw: Variant = p_view.get(p_key, [])
	if not (raw is Array):
		return []
	var result: Array = []
	for item: Variant in raw:
		if item is Dictionary or item is String or item is StringName:
			result.append(item)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# 卡牌行与详情
# ═══════════════════════════════════════════════════════════════════════════════

## 卡牌行文本（GDD §7 线框「[青云剑诀] 蓝色·功法 ← 点击查看」）。[br]
## [br][b]文字即标记[/b]：名称、稀有度、类型都写在按钮文本里，不靠颜色单独承载
## （色盲可读，且屏幕阅读器可念）。
static func card_row_text(p_entry: Variant) -> String:
	var entry: Dictionary = p_entry if p_entry is Dictionary else {}
	var parts: Array = [card_name(entry)]
	var tag: String = card_tag(entry)
	if not tag.is_empty():
		parts.append(tag)
	parts.append(TEXT_CARD_HINT)
	return " ".join(PackedStringArray(parts))


## 卡牌详情行（点击卡牌行后展示）。[br]
## [br][param p_entry] 结算载荷里的卡牌条目（[code]name / rarity / school[/code]）。[br]
## [param p_extra] 模板侧补充 [code]{description, flavor_text}[/code]（可空——缺省只用
## 载荷字段，不臆造描述文本）。[br]
## [br][b]返回[/b]：名称行 + 可选的稀有度/类型行、描述行、风味行。[br]
## [br][b]为什么详情不放模板读取[/b]：本模块是纯函数，不认识 CardSystem；模板查询由
## 面板的注入点 [code]detail_provider[/code] 完成，结果以 [param p_extra] 交进来
## （UI 零状态所有权的边界）。
static func card_detail_lines(p_entry: Variant, p_extra: Dictionary = {}) -> Array:
	var entry: Dictionary = p_entry if p_entry is Dictionary else {}
	var lines: Array = [card_name(entry)]
	var tag: String = card_tag(entry)
	if not tag.is_empty():
		lines.append(tag)
	for key: String in ["description", "flavor_text"]:
		var text: String = str((p_extra if p_extra != null else {}).get(key, ""))
		if not text.strip_edges().is_empty():
			lines.append(text)
	return lines


## 卡牌展示名——[code]name[/code] > [code]card_id[/code] > 未知卡牌。
static func card_name(p_entry: Variant) -> String:
	var entry: Dictionary = p_entry if p_entry is Dictionary else {}
	var name: String = str(entry.get("name", ""))
	if not name.strip_edges().is_empty():
		return name
	var card_id: String = str(entry.get("card_id", ""))
	return card_id if not card_id.strip_edges().is_empty() else NAME_UNKNOWN_CARD


## 稀有度/类型括号——两者都有才显示「（蓝·功法）」，只有一项时显示「（蓝）」。<br>
## [br][b]载荷里已是中文[/b]：稀有度与类型由 [code]CombatRewardRoller._enrich[/code]
## 翻好（[code]rarity[/code] 是「蓝/紫/金」而不是枚举值），本函数不再查表。
static func card_tag(p_entry: Dictionary) -> String:
	var rarity: String = str(p_entry.get("rarity", ""))
	var school: String = str(p_entry.get("school", ""))
	if not rarity.is_empty() and not school.is_empty():
		return TEXT_TAG_TWO % [rarity, school]
	if not rarity.is_empty() or not school.is_empty():
		return TEXT_TAG_ONE % (rarity if not rarity.is_empty() else school)
	return ""
