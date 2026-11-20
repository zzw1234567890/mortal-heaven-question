extends RefCounted
## DeckCollectionRows —— 卡组编辑左栏「收藏」的[b]取数与行数据组装[/b]（纯逻辑）。[br]
## [br][b]为什么单独一处[/b]：界面本体要管两栏骨架、游标与键盘输入，而「收藏里有哪几种
## 卡、每种几张已在卡组里、还能加哪几个实例」是另一件事——它能在没有控件树的用例里
## 逐条摆数据断言（同 [code]deck_view_rows.gd[/code] / [code]inventory_model.gd[/code]
## 的拆因）。[br]
## [br][b]按模板合并（与卡组右栏相反）[/b]：收藏要回答的是「我有几张这种卡、其中几张
## 已经在卡组里」——同名的多张副本在这里是同一条信息的数量，铺成 N 行反而看不出
## 「还剩几张能加」。卡组右栏逐实例出行（哪一张在手上是另一回事，见
## [code]deck_view_rows.gd[/code] 的相反口径）。[br]
## [br][b]角色卡不入卡组[/b]：收藏里同时有角色与功法/法宝/丹药，而角色卡占的是
## [code]deck.slots[/code] 阵位（GDD deck-editing-system.md §「角色位中的角色卡不在
## 卡组张数计数内」）——逐条滤掉，判定收在 [code]DeckBuildRules.is_deck_eligible[/code]。[br]
## [br][b]取不到就是不出行[/b]（同 [code]DeckViewRows[/code] 口径）：模板异步加载未完成
## 时那一张不出现，少了几张由 [code]unresolved[/code] 如实报出——宁可少显示一项，
## 也不编造一个名字。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是 static 纯函数，不缓存、不持节点、
## 不写任何域。[br]
##
## 来源: design/ux/deck-editing-ui.md（§卡组浏览 网格 / §卡牌详情浮窗）、
## design/gdd/deck-editing-system.md §5、design/gdd/card-system.md §角色位、
## ADR-0031 §2、先例 [code]deck_view_rows.gd[/code]。

## 卡牌类型 / 稀有度中文名与排序比较器（与背包、卡组查看同一份词表）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 卡面字段与三行文案的拼装（行上的 [code]face[/code] 与左栏观感同源于它）。
const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")
## 详情行文案（与卡组查看共用——「这张牌是什么」在四个面板里只有一个答案）。
const RowsScript := preload("res://src/ui/hud/deck_view_rows.gd")
## 构筑规则（同名上限 / 可加入副本 / 角色卡不入卡组——见 [DeckBuildRules]）。
const RulesScript := preload("res://src/feature/deck/deck_build_rules.gd")

## 「已在卡组里 N/M 张」的标注模板（写进卡面第二行——文字标记，色盲可读）。[br]
## [br]分母是同名上限（模板的 [code]stack_limit[/code]）：只写「卡组中 2 张」的话，
## 玩家看不出「还能再加几张」，而这条规则是加入判定会拒绝他的那一条。
const TEXT_IN_DECK: String = "卡组中 %d/%d 张"
## 模板未加载的张数提示（拼进界面的提示行）。
const TEXT_UNRESOLVED_HINT: String = "（%d 张模板未加载）"

## 行载荷的键（行构建侧与界面共用——不裸写字符串）。[br]
## [br]前四个与 [code]DeckViewRows[/code] 同源（卡面行读的是同一套键）。
const KEY_INSTANCE_ID: String = "instance_id"
const KEY_DETAIL: String = "detail"
const KEY_FACE: String = "face"
const KEY_MARKER: String = "marker"
## 本行的模板 ID（界面据此算「卡组里同名几张」）。
const KEY_TEMPLATE_ID: String = "template_id"
## 本行可加入卡组的副本实例 ID 数组（空 = 复制品都已在卡组里）。
const KEY_AVAILABLE: String = "available"
## 本行在卡组里已有的张数。
const KEY_IN_DECK: String = "in_deck"
## 本行的同名上限（模板的 [code]stack_limit[/code]——界面据此显示「卡组中 N/M 张」，
## 加入判定也读它，免得按下那一刻再查一遍模板）。
const KEY_SAME_LIMIT: String = "same_limit"


## 组装全部行。[br]
## [br][param p_gsm] GSM（读 [code]collection.owned_cards[/code]；不可用时返回空）。[br]
## [param p_cards] CardSystem 引用（可空——空则全部解析不出）。[br]
## [param p_deck_ids] 当前卡组实例 ID 列表（算「已在卡组 N 张」与可加入副本）。[br]
## [br][b]返回[/b]：[code]{rows, total, unresolved}[/code]——[code]rows[/code] 是
## [code]{text, payload}[/code] 数组（直接喂 [code]DeckCardRows.add_rows[/code]），
## [code]total[/code] 为可入卡组的收藏种类数（不含角色卡），[code]unresolved[/code]
## 为解析不出的条数。
static func build(p_gsm: Variant, p_cards: Variant, p_deck_ids: Array) -> Dictionary:
	var owned: Array = _owned_of(p_gsm)
	var merged: Dictionary = {}
	var order: Array = []
	var unresolved: int = 0
	for raw: Variant in owned:
		if not (raw is Dictionary):
			continue
		var instance: Dictionary = raw
		var instance_id: int = RulesScript.id_of(instance)
		var template: Variant = RulesScript.template_of_instance(p_cards, instance_id)
		if template == null:
			unresolved += 1
			continue
		if not RulesScript.is_deck_eligible(template):
			continue  # 角色卡在阵位上，不入卡组
		var template_id: StringName = RulesScript.template_id_of(template)
		if template_id == &"":
			unresolved += 1
			continue
		if not merged.has(template_id):
			merged[template_id] = {"template": template, "owned_ids": []}
			order.append(template_id)
		(merged[template_id]["owned_ids"] as Array).append(instance_id)

	var rows: Array = []
	for template_id: StringName in order:
		rows.append(_row_of(template_id, merged[template_id], p_deck_ids, p_cards))
	rows.sort_custom(CatalogScript.sort_desc_by_rarity)
	return {"rows": rows, "total": rows.size(), "unresolved": unresolved}


## 模板未加载的提示（无缺失时返回空串——与 [code]DeckViewRows.resolution_hint]
## 同形，界面把它拼进提示行）。
static func resolution_hint(p_unresolved: int) -> String:
	if p_unresolved <= 0:
		return ""
	return TEXT_UNRESOLVED_HINT % p_unresolved


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 一种卡一行（卡面字段 + 详情 + 「卡组中 N 张」标注 + 可加入副本）。[br]
## [br][b]实例 ID 取首个可用副本[/b]：卡面行需要一个「这一行代表哪张实例」的答案
## （[code]CardFaceRules.fields_of[/code] 的兜底显示名用它），取第一个尚未入卡组的
## 副本——它同时也是加入时真正会写入的那一张（[code]evaluate_add[/code] 的契约）。
## 全部副本都已在卡组里时退回首个副本（行照样要显示，只是点不动）。
static func _row_of(p_template_id: StringName, p_entry: Dictionary,
		p_deck_ids: Array, p_cards: Variant) -> Dictionary:
	var template: Variant = p_entry["template"]
	var owned_ids: Array = p_entry["owned_ids"]
	var available: Array = RulesScript.available_copies(owned_ids, p_deck_ids)
	var in_deck: int = RulesScript.copies_in_deck(p_deck_ids, p_template_id, p_cards)
	var same_limit: int = RulesScript.same_name_limit(template)
	var shown_id: int = int(available[0]) if not available.is_empty() else RulesScript.id_of(owned_ids[0])
	var face: Dictionary = FaceRules.fields_of(template, shown_id)
	var marker: String = TEXT_IN_DECK % [in_deck, same_limit]
	return {
		"text": FaceRules.face_text(face, marker),
		"payload": {
			KEY_INSTANCE_ID: shown_id,
			KEY_DETAIL: RowsScript.detail_of(template),
			KEY_FACE: face,
			KEY_MARKER: marker,
			KEY_TEMPLATE_ID: p_template_id,
			KEY_AVAILABLE: available,
			KEY_IN_DECK: in_deck,
			KEY_SAME_LIMIT: same_limit,
		},
	}


## 收藏列表（[code]collection.owned_cards[/code]；GSM 不可用 / 域不是数组时为空）。
static func _owned_of(p_gsm: Variant) -> Array:
	if p_gsm == null or not (p_gsm is Node) or not is_instance_valid(p_gsm):
		return []
	var collection: Variant = (p_gsm as Node).get("collection")
	if not (collection is Dictionary):
		return []
	var owned: Variant = (collection as Dictionary).get("owned_cards")
	return owned if owned is Array else []
