extends RefCounted
## DeckEditingActions —— 卡组编辑的[b]增删与落盘编排[/b]（调系统的那一层）。[br]
## [br][b]为什么单独一处[/b]：界面本体要守 300 行软上限
## （.claude/docs/coding-standards.md），而「按下之后该调谁、拒绝时说哪句中文、写盘
## 走哪条路」与「控件怎么搭、游标怎么动」是两件事（同 [code]deck_view_rows.gd[/code] /
## [code]inventory_pill_use.gd[/code] 的拆因）。[br]
## [br][b]判定归 [DeckBuildRules]，写入归 [DeckEditingSystem][/b]：本模块不自己算上限、
## 不自己改 GSM——它只做「问判定 → 调统一写入入口 → 把结果翻成一句中文」。判定与写入
## 分在两处是有意的：界面要的是「按下去之前就能告诉他为什么不行」，而写入必须经
## [code]DeckEditingSystem[/code] 的四种渠道统一入口（GSM 第二层原子写 + 变更日志）。[br]
## [br][b]为什么写 [code]"edit"[/code] 这个来源[/b]：变更日志的来源标识区分渠道
## （既有 [code]loot[/code] / [code]shop_delete[/code] / [code]shop_sell[/code] /
## [code]craft[/code]），玩家手动编辑是新的一条——日志里要能看出「这张是我自己加的
## 还是打怪掉的」。[br]
## [br][b]落盘沿用自动存档口径[/b]：[code]SaveLoadSystem.auto_save[/code] 是项目里
## 唯一的无人值守写盘点（转场 Phase 2 也走它）。不在本模块里另拼一份
## [code]save_game(slot, data, meta)[/code] —— 那会变成第二处「存档长什么样」。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存卡组、不持行控件——每次调用都拿
## 调用方现取的卡组列表与行载荷。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——面向玩家的短句集中在本文件的
## [code]TEXT_*[/code]（同 [code]deck_view_sources.gd[/code] 口径）。
##
## 来源: ADR-0023 §统一增删入口 / §变更日志、design/gdd/deck-editing-system.md §1/§4、
## design/gdd/main-menu-system.md（自动存档）、ADR-0031 §2、
## 先例 [code]inventory_pill_use.gd[/code]（面板发意图、结算层调系统）。

## 构筑规则（同名上限 / 可加入副本 / 角色卡不入卡组——单一真理来源）。
const RulesScript := preload("res://src/feature/deck/deck_build_rules.gd")
## 卡名读取（卡面字段的拼装口径与界面同源——不各拼一遍名字）。
const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")
## 收藏行的载荷键（与 [code]DeckCollectionRows[/code] 同源——不裸写字符串）。
const CollectionRowsScript := preload("res://src/ui/deck_editing/deck_collection_rows.gd")
## 卡组行的载荷键（与 [code]DeckViewRows[/code] 同源）。
const DeckRowsScript := preload("res://src/ui/hud/deck_view_rows.gd")

## 变更日志的来源标识（玩家手动编辑——见类文档）。
const SOURCE_EDIT: String = "edit"
## 变更日志的附加描述（日志列表里显示在卡名右侧那一列）。
const DETAIL_ADD: String = "编入卡组"
const DETAIL_REMOVE: String = "移出卡组"

## 加入成功的回执（[code]%s[/code] 卡名 / [code]%d[/code] 张数 / [code]%d[/code] 上限）。
const TEXT_ADDED: String = "已加入：%s（卡组 %d/%d）"
## 移出成功的回执（[code]%s[/code] 卡名 / [code]%d[/code] 移出后的张数）。[br]
## [br][b]不带上限分母[/b]：移出这条路拿不到 [code]get_deck_limit()[/code]（界面只把
## 卡组列表传了进来），写一个假分母比不写更糟——张数本身已经回答了「现在还剩几张」。
const TEXT_REMOVED: String = "已移出：%s（卡组剩 %d 张）"
## 落盘成功 / 尚未开局 / 落盘失败三种回执。
const TEXT_SAVED: String = "已保存"
const TEXT_NOTHING_TO_SAVE: String = "还没有开始这一局——没有可保存的进度"
const TEXT_SAVE_FAILED: String = "存档写入失败——请重试"
## 系统二次拒绝时的回执（界面已预判过同一套规则——走到这里说明两侧口径分了叉，
## 不报一个具体的上限原因，免得把「分叉」说成一个它其实没算过的结论）。
const TEXT_SYSTEM_REFUSED: String = "卡组系统拒绝了这次改动——请重试"

## 依赖注入（全部由界面透传；缺任何一个都只影响对应的一个动作，不崩）。
var deck_system: Node = null
var card_system: Node = null
var gsm: Node = null
var save_load: Node = null


## 构造——四个依赖都可后置注入（[method set_dependencies]）。
func _init(p_deck_system: Node = null, p_card_system: Node = null,
		p_gsm: Node = null, p_save_load: Node = null) -> void:
	set_dependencies(p_deck_system, p_card_system, p_gsm, p_save_load)


## 后置注入（生产路径：装配处把 Autoload 接进来——界面不直连 Autoload）。
func set_dependencies(p_deck_system: Node, p_card_system: Node,
		p_gsm: Node, p_save_load: Node) -> void:
	deck_system = p_deck_system
	card_system = p_card_system
	gsm = p_gsm
	save_load = p_save_load


# ═══════════════════════════════════════════════════════════════════════════════
# 增删
# ═══════════════════════════════════════════════════════════════════════════════

## 把收藏里的某一种卡加入卡组（[param p_payload] 为收藏行的载荷）。[br]
## [br][param p_deck_ids] 当前卡组实例 ID 列表（调用方现取——本模块不缓存）。[br]
## [br][param p_limit] 卡组上限（[code]DeckEditingSystem.get_deck_limit()[/code] 的产出）。[br]
## [br][b]返回[/b]：[code]{ok: bool, message: String}[/code]——被拒时 [code]message[/code]
## 是一句中文原因（界面直接显示，不弹窗打断）。[br]
## [br][b]复用行上的读数[/b]：同名张数、可加入副本、同名上限都取自行载荷——它们与玩家
## 在行上看到的「卡组中 N 张」是同一批数，按下那一刻不必再查一遍（也就不可能与显示
## 不一致）。
func add_card(p_payload: Dictionary, p_deck_ids: Array, p_limit: int) -> Dictionary:
	if p_payload.is_empty():
		return _fail(RulesScript.evaluate_unknown()["reason"])
	var name: String = str((p_payload.get(CollectionRowsScript.KEY_FACE) as Dictionary)
			.get(FaceRules.KEY_NAME, ""))
	var verdict: Dictionary = RulesScript.evaluate_add(
			p_deck_ids.size(),
			p_limit,
			name,
			int(p_payload.get(CollectionRowsScript.KEY_IN_DECK, 0)),
			int(p_payload.get(CollectionRowsScript.KEY_SAME_LIMIT, RulesScript.FALLBACK_SAME_NAME_LIMIT)),
			p_payload.get(CollectionRowsScript.KEY_AVAILABLE, []))
	if not bool(verdict["allowed"]):
		return _fail(str(verdict["reason"]))
	var add: Dictionary = _add_via_system([int(verdict["instance_id"])], name)
	if not bool(add["ok"]):
		return add
	return {"ok": true, "message": TEXT_ADDED % [name, p_deck_ids.size() + 1, p_limit]}


## 把卡组里的某一张移出（[param p_payload] 为卡组行的载荷）。[br]
## [br][b]按实例 ID 移除[/b]：卡组行的载荷带 [code]instance_id[/code]——同名多张时
## 移出的必须是玩家选中的那一张，不能按模板删（那会一次删掉全部同名副本）。[br]
## [br][b]返回[/b]：同 [method add_card]。
func remove_card(p_payload: Dictionary, p_deck_ids: Array) -> Dictionary:
	if p_payload.is_empty():
		return _fail(RulesScript.evaluate_unknown()["reason"])
	var instance_id: int = int(p_payload.get(DeckRowsScript.KEY_INSTANCE_ID, 0))
	if instance_id <= 0 or instance_id not in p_deck_ids:
		return _fail(RulesScript.evaluate_unknown()["reason"])
	var verdict: Dictionary = RulesScript.evaluate_remove(p_deck_ids.size(), 1)
	if not bool(verdict["allowed"]):
		return _fail(str(verdict["reason"]))
	var name: String = str((p_payload.get(DeckRowsScript.KEY_FACE) as Dictionary)
			.get(FaceRules.KEY_NAME, ""))
	var remove: Dictionary = _remove_via_system([instance_id], name)
	if not bool(remove["ok"]):
		return remove
	return {"ok": true, "message": TEXT_REMOVED % [name, p_deck_ids.size() - 1]}


# ═══════════════════════════════════════════════════════════════════════════════
# 落盘
# ═══════════════════════════════════════════════════════════════════════════════

## 落盘一次（沿用自动存档口径——见类文档）。[br]
## [br][b]返回[/b]：[code]{ok: bool, message: String}[/code]。[br]
## [br][b]「还没开局」不是失败[/b]：[code]auto_save[/code] 在
## [code]player.identity_id[/code] 为空时返回 [code]null[/code]（没写也没出错——
## 主菜单直接进来编辑就是这个状态）。这一档单独给一句话，与「写盘失败」分开说：
## 前者是「没什么可存的」，后者是「存了但没成」。
func save() -> Dictionary:
	if save_load == null or not save_load.has_method(&"auto_save"):
		return {"ok": false, "message": TEXT_SAVE_FAILED}
	var result: Variant = save_load.call(&"auto_save")
	if result == null:
		return {"ok": false, "message": TEXT_NOTHING_TO_SAVE}
	return {"ok": true, "message": TEXT_SAVED}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 经 [code]DeckEditingSystem[/code] 的统一入口写入（界面不碰 GSM 第二层）。[br]
## [br][b]系统拒绝也算失败[/b]：界面已按同一套规则预判过，走到这里仍被拒说明两侧口径
## 出现了分叉——如实报错比静默当作成功更能让分叉被发现。
func _add_via_system(p_ids: Array, p_name: String) -> Dictionary:
	if deck_system == null or not deck_system.has_method(&"add_cards_to_deck"):
		return _fail(RulesScript.evaluate_unknown()["reason"])
	var ok: bool = bool(deck_system.call(&"add_cards_to_deck", p_ids, SOURCE_EDIT,
			"%s：%s" % [DETAIL_ADD, p_name]))
	return {"ok": ok, "message": "" if ok else TEXT_SYSTEM_REFUSED}


## 经统一删除入口写入（同 [method _add_via_system] 的口径）。
func _remove_via_system(p_ids: Array, p_name: String) -> Dictionary:
	if deck_system == null or not deck_system.has_method(&"remove_cards_from_deck"):
		return _fail(RulesScript.evaluate_unknown()["reason"])
	var ok: bool = bool(deck_system.call(&"remove_cards_from_deck", p_ids, SOURCE_EDIT,
			"%s：%s" % [DETAIL_REMOVE, p_name]))
	return {"ok": ok, "message": "" if ok else RulesScript.TEXT_TOO_FEW % RulesScript.MINIMUM_DECK_SIZE}


## 失败结果（形状与成功一致——调用方不必分支取字段）。
func _fail(p_reason: String) -> Dictionary:
	return {"ok": false, "message": p_reason}
