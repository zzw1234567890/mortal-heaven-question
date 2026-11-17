extends RefCounted
## DeckViewRows —— 卡组查看面板的[b]取数与行数据组装[/b]（纯逻辑，不碰控件树）。[br]
## [br][b]为什么单独一处[/b]：面板本身要管骨架、焦点、键盘导航与开关配对，
## 而「牌库里有哪几张、每张叫什么、哪张已经抽到手上」是另一件事——且它能在没有
## 控件树的用例里逐条摆数据断言（同 [code]pause_menu_layout.gd[/code] /
## [code]map_clear_card_detail.gd[/code] 的拆因）。[br]
## [br][b]为什么按实例逐张出行、不按模板合并[/b]：背包（[code]InventoryModel[/code]）
## 合并同名是为了回答「我有几张」；卡组查看要回答的是「[b]哪几张已经抽到手[/b]」
## ——同名的两张实例可能一张在手上、一张还在牌库里，合并就把这条信息抹平了
## （design/ux/deck-editing-ui.md §多入口到达：战斗中显示完整卡组 +
## 「已抽出/仍在牌库」标注）。[br]
## [br][b]取不到就是不出行，不臆造[/b]（同 [code]InventoryModel[/code] 的口径）：
## 卡牌模板异步加载未完成 / 实例 ID 在收藏里查不到时，那一张不出现——宁可少显示
## 一项，也不编造一个名字。少了几张由 [code]unresolved[/code] 计数如实报出，
## 面板据此在提示行说明（把「读不到」和「没有这张」分开）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是 static 纯函数——入参是数据源，
## 出参是行数据；本模块不缓存、不写入、不持节点。[br]
##
## 来源: design/ux/deck-editing-ui.md（§多入口到达 / §打开与关闭）、
## design/ux/pause-menu.md（§Interaction Map 战斗中特殊规则「只读模式」）、
## design/gdd/deck-editing-system.md §5、ADR-0031 §2。

## 卡牌类型 / 稀有度中文名（与背包、商店同一份词表）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 焦点行样式之外，行文案的拼接口径与商店一致（同级分隔符）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")
## 卡面字段与三行文案的拼装（行上的 [code]face[/code] 与 [code]text[/code] 同源
## 于它——见 [method _row_text] 的注记）。
const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")

## 行内各段之间的分隔符（与商店商品行的「 · 」同源）。
const SEPARATOR: String = " · "
## 战斗中牌库状态标注（deck-editing-ui §多入口到达明写的两个词）。
const TEXT_IN_HAND: String = "已抽出"
const TEXT_IN_DECK: String = "仍在牌库"
## 找不到模板时的兜底行文案前缀——只用于计数提示，不做出行内容。
const TEXT_UNRESOLVED_HINT: String = "（%d 张模板未加载）"

## 行载荷的键（面板与测试共用——不裸写字符串）。
const KEY_INSTANCE_ID: String = "instance_id"
const KEY_DETAIL: String = "detail"
## 卡面字段（[method CardFaceRules.fields_of] 的产出）——卡组面板据此画卡面行；
## 缺这一项的行退回纯文本行（见 [code]deck_card_rows.gd[/code]）。
const KEY_FACE: String = "face"
## 本行的牌库标注（空串 = 不标）——卡面行把它拼进第二行。
const KEY_MARKER: String = "marker"


## 组装全部行。[br]
## [br][param p_deck_ids] 卡组实例 ID 列表（[code]DeckEditingSystem.get_deck_cards[/code]）。[br]
## [param p_cards] CardSystem 引用（可空——空则全部解析不出）。[br]
## [param p_combat] CombatSystem 引用（可空——空则不加牌库标注）。[br]
## [br][b]返回[/b]：[code]{rows, total, unresolved}[/code]——[code]rows[/code] 是
## [code]{text, payload}[/code] 数组（直接喂 [code]DeckCardRows.add_rows[/code]；
## 载荷带 [code]face[/code] 与 [code]marker[/code] 供卡面行使用），
## [code]total[/code] 为卡组张数、[code]unresolved[/code] 为解析不出的张数。
static func build(p_deck_ids: Array, p_cards: Variant, p_combat: Variant) -> Dictionary:
	var rows: Array = []
	var unresolved: int = 0
	var hand_ids: Dictionary = hand_ids_of(p_combat)
	for raw: Variant in p_deck_ids:
		var instance_id: int = id_of(raw)
		var template: Variant = _template_of(p_cards, instance_id)
		if template == null:
			unresolved += 1
			continue
		var marker: String = _marker_of(instance_id, hand_ids)
		rows.append({
			"text": _row_text(template, instance_id, hand_ids),
			"payload": {
				KEY_INSTANCE_ID: instance_id,
				KEY_DETAIL: detail_of(template),
				KEY_FACE: FaceRules.fields_of(template, instance_id),
				KEY_MARKER: marker,
			},
		})
	return {"rows": rows, "total": p_deck_ids.size(), "unresolved": unresolved}


## 详情行——选中某张牌后展开的那一块（名称/类型/稀有度/费用 + 正文 + 叙述）。[br]
## [br][b]恒为只读文本[/b]：卡组查看没有「装备/打出」这类动作（战斗中不可编辑
## 卡组，规格 §战斗中特殊规则），详情只是给人看的。[br]
## [br]空字段跳过（描述/叙述未填时不出现空行——同 [code]InventoryPanelLayout[/code]
## 对空段的处置）。
static func detail_of(p_template: Variant) -> Array:
	var lines: Array = []
	var name: String = _field(p_template, "name")
	var type_name: String = CatalogScript.card_type_name(_int_field(p_template, "type"))
	var rarity_name: String = ShopLayoutScript.rarity_name(_int_field(p_template, "rarity"))
	var cost: int = _int_field(p_template, "cost")
	var headline: Array = []
	if not name.is_empty():
		headline.append(name)
	if not type_name.is_empty():
		headline.append(type_name)
	if not rarity_name.is_empty():
		headline.append(rarity_name)
	headline.append("%d 灵力" % cost)
	lines.append(SEPARATOR.join(headline))
	var description: String = _field(p_template, "description")
	if not description.strip_edges().is_empty():
		lines.append(description)
	var flavor: String = _field(p_template, "flavor_text")
	if not flavor.strip_edges().is_empty():
		lines.append(flavor)
	return lines


## 手牌里的实例 ID 集合（空字典 = 不标注）。[br]
## [br][b]为什么要求战斗活跃[/b]：战斗开始前 [code]get_hand()[/code] 是空数组，
## 此时给每张都标「仍在牌库」会凭空断言一件尚未发生的事——非活跃战斗一律不标，
## 行文案退回「只看卡组」（规格只要求战斗中标注）。[br]
## [br][b]能力探测**：战斗系统可能只有 [code]get_hand[/code] 没有 [code]get_deck[/code]
## （半截接线）——两个都在才认，缺一即不标注（宁可不标，也不标错）。
static func hand_ids_of(p_combat: Variant) -> Dictionary:
	var out: Dictionary = {}
	if p_combat == null or not (p_combat is Node) or not is_instance_valid(p_combat):
		return out
	var node: Node = p_combat
	if not node.has_method(&"is_battle_active") or not node.has_method(&"get_hand") \
			or not node.has_method(&"get_deck"):
		return out
	if not bool(node.call(&"is_battle_active")):
		return out
	var hand: Variant = node.call(&"get_hand")
	if not (hand is Array):
		return out
	for raw: Variant in (hand as Array):
		var cid: int = id_of(raw)
		if cid > 0:
			out[cid] = true
	return out


## 从一行原始条目里取卡牌实例 ID（[code]0[/code] = 认不出）。[br]
## [br][b]三种形态都认[/b]：卡组本身存的是整数 ID（[code]get_deck_cards[/code] 的
## 契约），但战斗系统的牌库/手牌在测试与旧路径上可能是
## [code]Dictionary[/code]（[code]card_instance_id[/code]）或
## [code]CardInstance[/code] 对象——判据收在这里，别处不再各写一遍。
static func id_of(p_raw: Variant) -> int:
	if p_raw is int or p_raw is float:
		return int(p_raw)
	if p_raw is Dictionary:
		var dict: Dictionary = p_raw
		return int(dict.get("card_instance_id", dict.get("instance_id", 0)))
	if p_raw is Object and is_instance_valid(p_raw):
		var obj: Object = p_raw
		var raw_id: Variant = obj.get("card_instance_id")
		if raw_id != null:
			return int(raw_id)
	return 0


## 模板加载提示（拼进面板的提示行；无缺失时返回空串）。[br]
## [br][b]为什么要有这一句[/b]：卡牌模板是异步加载的，进战斗那一刻可能还没齐
## ——「卡组只有 3 张」与「有 7 张、4 张还没加载出来」对玩家是两件不同的事。
static func resolution_hint(p_total: int, p_resolved: int, p_unresolved: int) -> String:
	if p_unresolved <= 0:
		return ""
	return TEXT_UNRESOLVED_HINT % p_unresolved


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 一行的文案：名称 · 类型 · 稀有度 · 费用 [+ 牌库标注]。[br]
## [br][b]标注写进文本而不是靠颜色**：色盲可读（.claude/rules/ui-code.md 强制项），
## 也让屏幕阅读器读得出「这张已经抽到手上了」。[br]
## [br][b]与卡面行同源[/b]：标注由 [method _marker_of] 给出、卡面三行由
## [code]CardFaceRules[/code] 给出——本方法只是同一批字段的「一行挤满」版本
## （面板若退回纯文本行，读到的仍是同一张牌的同几项信息）。
static func _row_text(p_template: Variant, p_instance_id: int, p_hand_ids: Dictionary) -> String:
	var parts: Array = []
	var name: String = _field(p_template, "name")
	parts.append(name if not name.is_empty() else "#%d" % p_instance_id)
	var type_name: String = CatalogScript.card_type_name(_int_field(p_template, "type"))
	if not type_name.is_empty() and type_name != name:
		parts.append(type_name)
	var rarity_name: String = ShopLayoutScript.rarity_name(_int_field(p_template, "rarity"))
	if not rarity_name.is_empty():
		parts.append(rarity_name)
	parts.append("%d 灵力" % _int_field(p_template, "cost"))
	var marker: String = _marker_of(p_instance_id, p_hand_ids)
	if not marker.is_empty():
		parts.append(marker)
	return SEPARATOR.join(parts)


## 本行的牌库标注（「已抽出」/「仍在牌库」；非活跃战斗或手牌信息缺失时为空串）。[br]
## [br][b]为什么单独一个函数[/b]：同一条判定有两个消费者——纯文本行把它拼进行文案、
## 卡面行把它拼进第二行。各判一遍就会在「空手牌」这类边界上分叉。
static func _marker_of(p_instance_id: int, p_hand_ids: Dictionary) -> String:
	if p_hand_ids.is_empty():
		return ""
	return TEXT_IN_HAND if p_hand_ids.has(p_instance_id) else TEXT_IN_DECK


## 按实例 ID 查模板（CardSystem 不可用 / 查不到时 null）。
static func _template_of(p_cards: Variant, p_instance_id: int) -> Variant:
	if p_instance_id <= 0:
		return null
	if p_cards == null or not (p_cards is Node) or not is_instance_valid(p_cards):
		return null
	var node: Node = p_cards
	if not node.has_method(&"get_template_by_instance_id"):
		return null
	return node.call(&"get_template_by_instance_id", p_instance_id)


## 读一个字符串字段（模板缺失 / 字段类型不符时返回空串——不臆造）。
static func _field(p_template: Variant, p_key: String) -> String:
	if p_template == null or not (p_template is Object):
		return ""
	var raw: Variant = (p_template as Object).get(p_key)
	return str(raw) if raw != null else ""


## 读一个整数字段（同上，缺失返回 0）。
static func _int_field(p_template: Variant, p_key: String) -> int:
	if p_template == null or not (p_template is Object):
		return 0
	var raw: Variant = (p_template as Object).get(p_key)
	return int(raw) if raw != null else 0
