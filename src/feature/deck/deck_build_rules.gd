extends RefCounted
## DeckBuildRules —— 卡组[b]构筑规则[/b]（纯逻辑，不碰控件树、不写任何状态）。[br]
## [br][b]为什么需要单独一处[/b]：卡组编辑界面要在玩家按下的那一刻回答三件事——
## 「卡组装得下吗」「同名卡是不是已经满了」「还有没有没进卡组的副本」，并给出一句
## 中文原因。这三条判定此前全库没有：写入侧 [code]DeckEditingSystem[/code] 只管
## 卡组总张数上限与最低 5 张保护，同名上限从未落地（[code]stack_limit[/code] 字段
## 只在卡牌系统与绑定系统里被读）。判定必须能在没有控件树的用例里逐条摆数据断言，
## 故收成本模块（同 [code]deck_view_rows.gd[/code] / [code]inventory_catalog.gd[/code]
## 的拆因）。[br]
## [br][b]同名上限取 [code]CardTemplate.stack_limit[/code][/b]：卡牌系统已有这个字段
## （[code]assets/cards/templates/*.tres[/code] 里逐张配置），GDD binding-system.md
## §「叠加上限由 cardTemplate.stack_limit 定义」即它的语义来源。本模块[b]不另立一份
## 常量表[/b]——模板没写（0）时才回退 [constant FALLBACK_SAME_NAME_LIMIT]。[br]
## [br][b]越界不写入[/b]：判定与写入分成两步（本模块只判定，写入仍走
## [code]DeckEditingSystem.add_cards_to_deck[/code]）——统一写入入口是 GSM 的第二层
## 原子写（[code]_set_deck_cards[/code]），界面不绕过它直接改 GSM。[br]
## [br][b]角色卡不入卡组[/b]：角色卡占的是 [code]deck.slots[/code] 阵位（身份初始化
## 写入），不进 [code]current_deck[/code]（GDD deck-editing-system.md §「角色位中的
## 角色卡不在卡组张数计数内」）。收藏里同时有角色与非角色，故这一条要在行构建前滤掉。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是 static 纯函数——入参是数据，出参是
## 判定结果；本模块不持卡组、不读 GSM、不写任何域。[br]
## [br][b]文案本地化豁免[/b]：拒绝原因集中在本文件的 [code]TEXT_*[/code]
## （项目暂无本地化系统——同 [code]deck_view_sources.gd[/code] 口径）。[br]
##
## 来源: design/gdd/deck-editing-system.md §1 卡组上限验证 / §4 最低张数保护 /
## §7 卡组上限、design/gdd/binding-system.md §叠加上限、
## design/ux/deck-editing-ui.md（§错误态 卡组已满）、ADR-0031 §2、
## 先例 [code]deck_view_rows.gd[/code]（取数与判定的纯逻辑拆层）。

## 卡牌模板（[code]CardType[/code] 枚举与 [code]stack_limit[/code] 的真理来源）。
const TemplateScript := preload("res://src/core/card_system/card_template.gd")

## 同名上限的兜底值——模板未声明 [code]stack_limit[/code]（取 0）时使用。[br]
## [br]取值 3 与 [code]CardTemplate.stack_limit[/code] 的出厂默认一致
## （binding-system.md §边界：强力效果上限 3 张）。
const FALLBACK_SAME_NAME_LIMIT: int = 3
## 卡组最低张数——与 [code]DeckEditingSystem.MINIMUM_DECK_SIZE[/code] 同值。[br]
## [br][b]为什么各写一份[/b]：那边是写入侧的守卫（GSM 层拒绝），这边是界面的即时
## 反馈（还没按下去就告诉他）。让 UI 去 preload Feature 层 Autoload 的常量会把依赖
## 方向倒过来（症状是 headless 下全局名解析时序问题），同值各写才是本项目既有口径
## （见 [code]deck_view_rows.gd[/code] 对分隔符的处置）。
const MINIMUM_DECK_SIZE: int = 5

## 卡组已达总张数上限。
const TEXT_FULL: String = "卡组已达上限（%d张）"
## 同名卡已达上限（[code]%s[/code] 为卡名）。
const TEXT_SAME_NAME: String = "同名卡已达上限（%s 最多 %d 张）"
## 收藏里有这张卡，但副本都已经在卡组里了。
const TEXT_NO_COPY: String = "没有可加入的副本——它已经在卡组里了"
## 角色卡不进卡组（它在阵位上）。
const TEXT_NOT_ELIGIBLE: String = "角色卡不入卡组——它占的是出战阵位"
## 卡组最低张数保护。
const TEXT_TOO_FEW: String = "卡组至少保留%d张"
## 模板未加载（认不出这张卡是什么）时的拒绝原因。
const TEXT_UNKNOWN: String = "卡牌模板尚未加载——稍后再试"


## 这张牌能不能进卡组（角色卡不能——见类文档）。[br]
## [br][b]模板缺失一律不可入[/b]：认不出类型的卡宁可拒绝，也不臆造一个「大概能进」。
static func is_deck_eligible(p_template: Variant) -> bool:
	if p_template == null or not (p_template is Object):
		return false
	return _int_field(p_template, "type") != TemplateScript.CardType.CHARACTER


## 本张卡的同名上限（[code]stack_limit[/code]；未声明时回退兜底值）。[br]
## [br][b]返回恒 ≥ 1[/b]：取 0 或负数的模板按兜底值处理——上限 0 意味着这张牌永远
## 进不了卡组，那不是一个可玩的状态。
static func same_name_limit(p_template: Variant) -> int:
	var raw: int = _int_field(p_template, "stack_limit")
	if raw <= 0:
		# 角色卡等未配置该字段的模板走兜底（同 [method is_deck_eligible] 的模板判据）
		return FALLBACK_SAME_NAME_LIMIT if p_template != null else FALLBACK_SAME_NAME_LIMIT
	return raw


## 卡组里已有几张同名卡（按实例 ID 反查模板，逐张比较 [code]template_id[/code]）。[br]
## [br][b]为什么按实例反查而不是让调用方先合并[/b]：卡组存的是实例 ID 列表
## （[code]get_deck_cards[/code] 的契约），调用方手上没有「实例 → 模板」的映射；
## 反查由 [code]CardSystem.get_template_by_instance_id[/code] 提供（它同时覆盖场上
## 角色与收藏两条来源）。[br]
## [br]认不出模板的实例[b]不计入[/b]：宁可少算一张（玩家看到「还能再加」然后被写入侧
## 拒绝），也不凭空把它算成同名。
static func copies_in_deck(p_deck_ids: Array, p_template_id: StringName,
		p_cards: Variant) -> int:
	if p_template_id == &"" or p_cards == null:
		return 0
	var count: int = 0
	for raw: Variant in p_deck_ids:
		var template: Variant = template_of_instance(p_cards, id_of(raw))
		if template != null and template_id_of(template) == p_template_id:
			count += 1
	return count


## 卡组里同名卡的实例 ID 集合之外，收藏里可加入的副本（保持收藏顺序）。[br]
## [br][param p_owned_ids] 该模板在收藏里的全部实例 ID。[br]
## [param p_deck_ids] 当前卡组实例 ID 列表。[br]
## [br][b]返回[/b]：还没进卡组的实例 ID 数组（空 = 全部副本都已在卡组里）。
static func available_copies(p_owned_ids: Array, p_deck_ids: Array) -> Array:
	var in_deck: Dictionary = {}
	for raw: Variant in p_deck_ids:
		in_deck[id_of(raw)] = true
	var out: Array = []
	for raw: Variant in p_owned_ids:
		var id: int = id_of(raw)
		if id > 0 and not in_deck.has(id):
			out.append(id)
	return out


## 加入一张卡的判定。[br]
## [br][param p_deck_size] 当前卡组张数。[br]
## [param p_limit] 卡组上限（[code]DeckEditingSystem.get_deck_limit()[/code]——
## 界面侧现取后传进来，本模块不自己去查境界）。[br]
## [param p_name] 卡名（仅用于拒绝文案）。[br]
## [param p_same_name_count] 卡组里已有的同名张数（[method copies_in_deck] 的产出）。[br]
## [param p_available] 可加入的副本 ID 数组（[method available_copies] 的产出）。[br]
## [br][b]返回[/b]：[code]{allowed: bool, reason: String, instance_id: int}[/code]
## —— 允许时 [code]instance_id[/code] 是本次要写入的实例（首个可用副本）。[br]
## [br][b]判定顺序[/b]：能不能入卡组（类型）→ 卡组满没满 → 同名满没满 → 有没有副本。
## 顺序即玩家看到的理由：卡组满了却先报「同名已满」会把人往错的修法上引。
static func evaluate_add(p_deck_size: int, p_limit: int, p_name: String,
		p_same_name_count: int, p_same_name_limit: int, p_available: Array) -> Dictionary:
	if p_deck_size >= p_limit:
		return _reject(TEXT_FULL % p_limit)
	if p_same_name_count >= p_same_name_limit:
		return _reject(TEXT_SAME_NAME % [p_name, p_same_name_limit])
	if p_available.is_empty():
		return _reject(TEXT_NO_COPY)
	return {"allowed": true, "reason": "", "instance_id": int(p_available[0])}


## 移除一张卡的判定（最低 5 张保护——卡组空了就没法开战）。[br]
## [br][param p_deck_size] 当前卡组张数。[br]
## [br][param p_removing] 本次要移除的张数。[br]
static func evaluate_remove(p_deck_size: int, p_removing: int = 1) -> Dictionary:
	if p_deck_size - p_removing < MINIMUM_DECK_SIZE:
		return _reject(TEXT_TOO_FEW % MINIMUM_DECK_SIZE)
	return {"allowed": true, "reason": ""}


## 模板认不出时的统一拒绝（界面在模板异步加载未完成时会走到这里）。[br]
static func evaluate_unknown() -> Dictionary:
	return _reject(TEXT_UNKNOWN)


## 角色卡（或认不出的模板）的拒绝——[method is_deck_eligible] 为假时用。[br]
static func evaluate_ineligible() -> Dictionary:
	return _reject(TEXT_NOT_ELIGIBLE)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 拒绝结果（同 [method evaluate_add] 的形状——调用方不必分支取字段）。
static func _reject(p_reason: String) -> Dictionary:
	return {"allowed": false, "reason": p_reason, "instance_id": 0}


## 从一行原始条目取实例 ID（三种形态都认——与 [code]DeckViewRows.id_of[/code] 同口径）。
## [br][b]公开而非私有[/b]：收藏侧的取数（[code]DeckCollectionRows[/code]）要用同一份
## 判据把 [code]owned_cards[/code] 的字典条目读成实例 ID——各写一遍必然在「浮点 ID」
## 这类边界上分叉。
static func id_of(p_raw: Variant) -> int:
	if p_raw is int or p_raw is float:
		return int(p_raw)
	if p_raw is Dictionary:
		return int((p_raw as Dictionary).get("card_instance_id", 0))
	if p_raw is Object and is_instance_valid(p_raw):
		var obj: Object = p_raw
		var raw_id: Variant = obj.get("card_instance_id")
		if raw_id != null:
			return int(raw_id)
	return 0


## 按实例 ID 查模板（[code]CardSystem[/code] 缺方法 / 查不到时 null——不臆造）。
static func template_of_instance(p_cards: Variant, p_instance_id: int) -> Variant:
	if p_instance_id <= 0 or p_cards == null or not (p_cards is Node):
		return null
	var node: Node = p_cards
	if not is_instance_valid(node) or not node.has_method(&"get_template_by_instance_id"):
		return null
	return node.call(&"get_template_by_instance_id", p_instance_id)


## 模板的模板 ID（卡牌模板的字段名是 [code]card_id[/code]——两处口径不一致，
## 映射只写在本函数里）。
static func template_id_of(p_template: Variant) -> StringName:
	var raw: Variant = (p_template as Object).get(&"card_id")
	return raw if raw is StringName else StringName(str(raw))


## 读整数字段（模板缺失 / 字段类型不符时返回 0——不臆造）。
static func _int_field(p_template: Variant, p_key: String) -> int:
	if p_template == null or not (p_template is Object):
		return 0
	var raw: Variant = (p_template as Object).get(p_key)
	return int(raw) if raw != null else 0
