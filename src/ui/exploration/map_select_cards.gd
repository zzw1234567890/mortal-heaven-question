extends RefCounted
## MapSelectCards —— 地图卡片的[b]构建与推荐高亮[/b]（从 [MapSelectScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「卡片行怎么建、推荐哪一张」与「列表怎么取、
## 点击怎么分流」是两件事（同 [code]map_select_data.gd[/code] /
## [code]map_select_animator.gd[/code] 拆分先例）。[br]
## [br][b]卡片数组由本模块自持[/b]：宿主只提交「建哪些卡」，之后问「第一张可玩的」
## 「推荐哪一张」都走本模块——数组若要宿主也存一份，两处迟早出现「宿主那份还是旧的」。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只做控件建/改与纯函数判定，不读
## GSM、不写任何玩法状态——推荐哪张地图由 Feature 层算好后以地图 ID 传入。[br]
## [br][b]推荐态为什么落在这里[/b]：通关确认之后玩家回到选图界面，[b]必须有一张卡
## 被点亮[/b]（否则 17 张卡里最显眼的还是刚通完那张）。点亮是纯视觉动作，
## 判据是「卡片的 map_id == 推荐 ID」——UI 不需要理解解锁规则。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面 / §7 通关结算、
## ADR-0031 §2、.claude/rules/ui-code.md（双输入 + 可见焦点 + 色盲可读）。

## MapCard 脚本常量（[code]class_name[/code] 在动态 new 下不可靠——同屏幕先例）。
const MapCardScript := preload("res://src/ui/exploration/map_card.gd")

## 当前卡片数组（与卡片行子节点同序——游标/焦点/高亮的取数口）。
var _cards: Array = []
## 当前推荐的地图 ID（空串 = 没有推荐）。[br]
## [br][b]为什么存它[/b]：推荐是高亮而不是数据，列表重建会把它抹掉——刷新一次就丢的
## 推荐等于没有（[method rebuild] 据此重放）。
var _recommended_id: StringName = &""


## 重建卡片行——按条目数组逐张建卡并接点击回调。[br]
## [br][param p_card_row] 卡片行容器（[code]HBoxContainer[/code]）。[br]
## [param p_entries] 地图条目数组（[code]get_map_list()[/code] 的产物）。[br]
## [param p_on_activated] 点击回调 [code]func(entry: Dictionary) -> void[/code]。[br]
## [br][b]返回[/b]：新建的卡片数组（顺序同条目——只读副本）。[br]
## [br][b]先拆后建[/b]：列表是每次刷新重建的（GSM 变化即重建），旧卡必须显式
## [code]queue_free[/code]——只 [code]remove_child[/code] 会把它们留在树上。[br]
## [br][b]重建后重放推荐态[/b]：见 [member _recommended_id]。
func rebuild(p_card_row: Container, p_entries: Array,
		p_on_activated: Callable) -> Array:
	for child: Node in p_card_row.get_children():
		p_card_row.remove_child(child)
		child.queue_free()
	_cards = []
	for raw: Variant in p_entries:
		var entry: Dictionary = raw
		var card: Panel = MapCardScript.new()
		card.call(&"setup", entry)
		card.connect(&"card_activated", p_on_activated)
		p_card_row.add_child(card)
		_cards.append(card)
	apply_recommendation(_recommended_id)
	return _cards.duplicate()


## 点亮推荐卡（其余卡恢复常态）——[param p_map_id] 为空串时全部熄灭。[br]
## [br][b]返回[/b]：是否真的点亮了某一张（推荐 ID 不在当前列表里时为 false——
## 例如它在别张图之后被刷新掉了）。[br]
## [br][b]找不到就不点亮[/b]：不臆造一张「看起来像推荐」的卡（列表为空 /
## 推荐 ID 拼错时静默，界面不出现假高亮）。
func highlight(p_map_id: StringName) -> bool:
	_recommended_id = StringName(str(p_map_id))
	return apply_recommendation(_recommended_id)


## 当前推荐的地图 ID（空串 = 没有推荐——测试与宿主查询用）。
func recommended_id() -> StringName:
	return _recommended_id


## 第一张已解锁卡（初始焦点目标——键盘焦点环的落点）。[br]
## [br][b]返回[/b]：卡片；全锁 / 列表为空时为 null（不臆造焦点）。[br]
## [br][b]判据走卡片自己的 [code]is_unlocked_card[/code][/b]：字段
## [code]is_unlocked[/code] 是单一真理来源，屏幕的 [code]should_show_lock[/code]
## 是它的取反镜像（两者不互相引用以免 preload 循环）。
func first_unlocked() -> Variant:
	for raw: Variant in _cards:
		var card: Panel = raw as Panel
		if card != null and is_instance_valid(card) \
				and bool(card.call(&"is_unlocked_card")):
			return card
	return null


## 把推荐态写给持有的卡片。[br]
## [br][param p_map_id] 推荐 ID（空串 = 全部熄灭）。[br]
## [br][b]逐张比对 map_id[/b]：卡片自己持有条目（[code]MapCard.entry[/code]），
## 本模块不另存一份条目→卡片的映射（两份迟早漂移）。[br]
## [br][b]返回[/b]：是否命中（无推荐时恒 false）。[br]
func apply_recommendation(p_map_id: StringName) -> bool:
	var hit: bool = false
	for raw: Variant in _cards:
		var card: Panel = raw as Panel
		if card == null or not is_instance_valid(card):
			continue
		var map_id: StringName = StringName(str(
				(card.get(&"entry") as Dictionary).get(&"map_id", "")))
		var matched: bool = not p_map_id.is_empty() and map_id == p_map_id
		card.call(&"set_recommended", matched)
		hit = hit or matched
	return hit
