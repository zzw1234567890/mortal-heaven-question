extends "res://tests/integration/deck_editing/deck_editing_fixture.gd"
## 卡组编辑界面 —— 端到端流程用例（真实 Autoload + 真实存档）。[br]
## [br][b]守什么[/b]（本轮任务书的功能清单）：[br]
##   1. 场景挂得起、两栏都不是空的（左收藏右卡组各出了行）；[br]
##   2. 加入一张卡 → 内存卡组 +1 且 [code]GSM.deck[/code] 同步；[br]
##   3. 移出一张 → 同步减少，且删的是玩家选中的那一张（不是按模板全删）；[br]
##   4. 超出同名上限 → 被拒、卡组不变、给出一句中文原因；[br]
##   5. 保存 → 真实写盘 → 重新读回来卡组内容一致；[br]
##   6. 空收藏 / 空卡组的中文提示（不显示一片空白）。[br]
## [br][b]断言的落点[/b]：凡是「卡组变了」一律断 [code]GSM.deck.current_deck[/code]
## 本身，而不是只断界面读数——界面读数与存档分叉正是这类改动最容易出的问题。[br]
##
## 来源: design/gdd/deck-editing-system.md §1/§4、ADR-0023、ADR-0031 §2、
## 测试标准 .claude/rules/test-standards.md（arrange/act/assert + 自主清理）。

## 构筑规则（最低张数等常量从它取——与实现同一份真理来源）。
const RulesScript := preload("res://src/feature/deck/deck_build_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 场景加载与两栏内容
# ═══════════════════════════════════════════════════════════════════════════════

func test_screen_mounts_with_both_columns_populated() -> void:
	## 给足 fixture 收藏（5 丹药 + 2 法宝 + 4 符箓）与一份 6 张的卡组：两栏都该出行。[br]
	## [br][b]为什么两栏都要非空[/b]：只断「界面挂起来了」的话，一个什么都没渲染的
	## 空壳也能通过——而「玩家看不到自己的卡」正是这轮要修的那个毛病。
	# Arrange
	assert_true(seed_collection(), "前置：fixture 收藏应造得出来")
	seed_deck()
	# Act
	mount_screen()
	# Assert
	assert_gt(screen.collection_count(), 0, "左栏（收藏）应有行——收藏里有卡")
	assert_gt(screen.deck_count(), 0, "右栏（卡组）应有行——卡组里有卡")
	assert_eq(screen.collection_count(), 3, "收藏三种模板（丹药/法宝/符箓）各一行（同名合并）")
	assert_eq(screen.deck_count(), 6, "卡组六张逐实例出行")


func test_collection_row_shows_in_deck_count_and_same_name_limit() -> void:
	## 左栏行上要能读出「已在卡组中几张 / 同名上限」——这是加入判定的依据，
	## 也是玩家判断「还能再加几张」的唯一线索（文字标记，色盲可读）。
	# Arrange
	seed_collection()
	seed_deck()  # 3 丹药在卡组里
	mount_screen()
	# Act
	var index: int = collection_index_of(PILL_ID)
	# Assert
	assert_ne(index, -1, "收藏里应有丹药那一行")
	if index == -1:
		return
	var payload: Dictionary = screen.payload_at(NavScript.COLUMN_COLLECTION, index)
	assert_eq(int(payload.get("in_deck", -1)), 3, "丹药在卡组里应有 3 张")
	assert_eq(int(payload.get("same_limit", -1)), 3, "同名上限应取模板的 stack_limit（=3）")
	assert_true(str(screen.collection_texts()[index]).contains("3/3"),
			"行文本应写明「卡组中 3/3 张」，实际：%s" % str(screen.collection_texts()[index]))


func test_deck_column_lists_selected_copies_in_order() -> void:
	## 右栏逐实例按卡组顺序列出：同名的两张在左栏是一条数量、在这里是两行。
	# Arrange
	assert_true(seed_collection(), "前置：fixture 收藏应造得出来")
	var ids: Array = seed_deck()
	mount_screen()
	# Act + Assert
	assert_eq(screen.deck_count(), ids.size(), "右栏行数应等于卡组张数")
	assert_eq(deck_index_of(int(ids[0])), 0, "第 0 行应是卡组里第 0 张")
	assert_eq(deck_index_of(int(ids[5])), 5, "第 5 行应是卡组里第 5 张（顺序即卡组顺序）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 加入 / 移除与 GSM 同步
# ═══════════════════════════════════════════════════════════════════════════════

func test_adding_a_card_grows_memory_deck_and_gsm_together() -> void:
	## 加入一张符箓：动作层成功、GSM 里多出那一个实例 ID、右栏行数跟着 +1。[br]
	## [br][b]断的是实例 ID 而不是张数[/b]：张数相同但换了一张（比如加错模板）
	## 也能让张数断言通过——这一条要钉住「加的就是玩家选的那一张」。
	# Arrange
	seed_collection()
	var ids: Array = seed_deck()
	mount_screen()
	var before: int = deck_ids().size()
	var index: int = collection_index_of(TALISMAN_ID)
	assert_ne(index, -1, "前置：收藏里应有符箓那一行")
	# Act
	var result: Dictionary = add_card_at(index)
	# Assert
	assert_true(bool(result.get("ok", false)), "加入应成功，实际原因：%s" % str(result.get("message", "")))
	assert_eq(deck_ids().size(), before + 1, "GSM 卡组应 +1 张")
	assert_true(int(talismans[0]) in deck_ids() or int(talismans[1]) in deck_ids(),
			"GSM 卡组里应出现一个原本不在卡组里的符箓实例")
	assert_eq(GameStateManager.deck.current_deck.size(), deck_ids().size(),
			"GSM.deck.current_deck 与查询接口应一致")


func test_adding_a_card_refreshes_the_on_screen_deck_column() -> void:
	## 界面在动作成功后重刷两栏——刚加进去的那张必须立刻出现在右栏
	## （不重刷的话玩家会以为没生效而再点一次）。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	var rows_before: int = screen.deck_count()
	var index: int = collection_index_of(TALISMAN_ID)
	# Act
	add_card_at(index)
	screen.refresh()
	# Assert
	assert_eq(screen.deck_count(), rows_before + 1, "重刷后右栏应多一行")


func test_removing_a_card_shrinks_memory_deck_and_gsm_together() -> void:
	## 移出：GSM 里少掉玩家选中的那一个实例，其余照旧。
	# Arrange
	seed_collection()
	var ids: Array = seed_deck()
	mount_screen()
	var victim: int = int(ids[5])
	var index: int = deck_index_of(victim)
	assert_ne(index, -1, "前置：卡组最后一张应在右栏有行")
	var before: int = deck_ids().size()
	# Act
	var result: Dictionary = remove_card_at(index)
	# Assert
	assert_true(bool(result.get("ok", false)), "移出应成功，实际原因：%s" % str(result.get("message", "")))
	assert_eq(deck_ids().size(), before - 1, "GSM 卡组应 -1 张")
	assert_false(victim in deck_ids(), "被移出的那个实例不应还在卡组里")
	assert_true(int(ids[0]) in deck_ids(), "同在卡组里的其他张不应被牵连")


func test_removing_one_copy_leaves_the_other_copies_alone() -> void:
	## [b]回归用例[/b]：同名多张时移出的必须是选中的那一张。[br]
	## [br][b]为什么值得单测[/b]：按模板删（而非按实例删）会一次清掉全部同名副本——
	## 那种实现能让「张数 -1」以外的所有简单断言通过，只有在同名卡组里才暴露。
	# Arrange
	seed_collection()
	var ids: Array = seed_deck()  # 3 张同名丹药都在卡组里
	var two_pills: Array = [int(ids[0]), int(ids[1])]
	mount_screen()
	var index: int = deck_index_of(two_pills[0])
	assert_ne(index, -1, "前置：第一张丹药应在右栏有行")
	# Act
	remove_card_at(index)
	# Assert
	assert_false(two_pills[0] in deck_ids(), "被选中的那张应已移出")
	assert_true(two_pills[1] in deck_ids(), "同名的另一张应仍在卡组里")
	assert_true(int(ids[2]) in deck_ids(), "同名的第三张也应仍在卡组里")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 拒绝路径（不弹窗，给中文原因）
# ═══════════════════════════════════════════════════════════════════════════════

func test_exceeding_same_name_limit_is_rejected_with_reason() -> void:
	## 同名上限 3：卡组里已有 3 张丹药时再加第 4 张 → 被拒、卡组不变、
	## 原因是一句点名了卡名与上限的中文。[br]
	## [br][b]为什么卡组要留出余量[/b]：卡组上限是 20，此时远未满——所以拒绝只可能
	## 来自同名规则，断言不会被「卡组满了」这条别的理由蒙混过去。
	# Arrange
	seed_collection()
	seed_deck()  # 3 张同名丹药已在卡组里
	mount_screen()
	var before: Array = deck_ids()
	var index: int = collection_index_of(PILL_ID)
	assert_ne(index, -1, "前置：收藏里应有丹药那一行")
	# Act
	var result: Dictionary = add_card_at(index)
	# Assert
	assert_false(bool(result.get("ok", true)), "同名已满时应被拒绝")
	assert_eq(deck_ids(), before, "被拒时卡组必须一张不变")
	var message: String = str(result.get("message", ""))
	assert_true(message.contains("同名"), "原因应点明「同名」这条规则，实际：%s" % message)
	assert_true(message.contains("3"), "原因应写出上限张数，实际：%s" % message)


func test_rejection_reason_is_shown_in_the_hint_line_without_a_popup() -> void:
	## 被拒时界面把原因写进提示行（不弹窗打断）——且该行确实可见。[br]
	## [br][b]走界面的按下出口而不是动作层[/b]：动作层给出原因后，界面必须把它显示
	## 出来（只断动作层的返回值等于没测这一屏）——这条路径就是玩家按下时走的路径。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	var index: int = collection_index_of(PILL_ID)
	assert_ne(index, -1, "前置：收藏里应有丹药那一行")
	var before: Array = deck_ids()
	# Act
	screen.press_row(NavScript.COLUMN_COLLECTION, index)
	# Assert
	assert_true(screen.message_text().contains("同名"),
			"提示行应显示拒绝原因，实际：%s" % screen.message_text())
	assert_eq(deck_ids(), before, "被拒之后卡组张数不应变")


func test_reinforcing_below_minimum_deck_size_is_rejected() -> void:
	## 卡组只剩最低张数（5）时再删 → 被拒、卡组不变、原因是「至少保留 N 张」。
	# Arrange
	seed_collection()
	var ids: Array = seed_deck()  # 6 张
	set_deck(ids.slice(0, RulesScript.MINIMUM_DECK_SIZE))  # 削到恰好 5 张
	mount_screen()
	var before: Array = deck_ids()
	assert_eq(before.size(), RulesScript.MINIMUM_DECK_SIZE, "前置：卡组应正好是最低张数")
	# Act
	var result: Dictionary = remove_card_at(0)
	# Assert
	assert_false(bool(result.get("ok", true)), "低于最低张数时应被拒绝")
	assert_eq(deck_ids(), before, "被拒时卡组必须一张不变")
	assert_true(str(result.get("message", "")).contains("至少"),
			"原因应说明最低张数保护，实际：%s" % str(result.get("message", "")))


func test_deck_column_is_disabled_at_minimum_size() -> void:
	## 卡组正好是 5 张时整栏置灰：游标据此跳过，鼠标点击也天然被拦——
	## 玩家看到的是「现在点不动」而不是「点了被拒」。
	# Arrange
	seed_collection()
	var ids: Array = seed_deck()
	set_deck(ids.slice(0, RulesScript.MINIMUM_DECK_SIZE))
	mount_screen()
	# Act + Assert
	assert_true(screen.deck_count() > 0, "前置：卡组栏应有行")
	assert_true(screen.get(&"_view").is_row_disabled(NavScript.COLUMN_DECK, 0),
			"最低张数时卡组栏的行应置灰")


func test_character_cards_never_appear_in_the_collection_column() -> void:
	## 角色卡占的是出战阵位、不进卡组——收藏里滤掉，不占一行。[br]
	## [br][b]装置默认不铺角色卡[/b]：这条断言只有在「角色卡确实在收藏里」时才有意义
	## （收藏为空时它也能通过，但通过的是个空集合）。
	# Arrange
	var character_id: int = give_card(CHARACTER_ID)
	assert_gt(character_id, 0, "前置：角色卡应造得出来（模板已落盘，且在校验库里）")
	seed_collection()
	# Act
	mount_screen()
	# Assert
	assert_eq(screen.collection_count(), 3, "左栏只应有三种非角色卡（角色卡被滤掉）")
	assert_eq(collection_index_of(CHARACTER_ID), -1,
			"角色卡不应出现在左栏——它进的是 deck.slots 而不是 current_deck")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 保存（真实写盘往返）
# ═══════════════════════════════════════════════════════════════════════════════

func test_saved_deck_survives_a_real_disk_round_trip() -> void:
	## 保存后重新读盘：卡组内容逐张一致。[br]
	## [br][b]为什么断的是「读回来」而不是「写入被调用」[/b]：写入被调用与内容真的
	## 落了盘是两件事——中间任何一层序列化漏了卡组，只有读回来才看得出来。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	var index: int = collection_index_of(TALISMAN_ID)
	add_card_at(index)
	screen.refresh()
	var expected: Array = deck_ids()
	# Act
	var result: Dictionary = actions.call(&"save")
	# Assert
	assert_true(bool(result.get("ok", false)), "保存应成功，实际：%s" % str(result.get("message", "")))
	assert_eq(expected.size(), 7, "前置：加完之后应是 7 张")
	# Assert（读回来）
	GameStateManager.deck.current_deck = []
	assert_eq(deck_ids().size(), 0, "前置：内存里的卡组应已清空")
	var load_result: Dictionary = sls.load_game(SLS.SaveSlotType.AUTOSAVE, 0)
	assert_eq(int(load_result.get("result", -1)), SLS.LoadResult.SUCCESS, "读档应成功")
	assert_eq(deck_ids(), expected, "读回来的卡组应与保存时逐张一致")


func test_save_reports_nothing_to_save_before_the_run_has_started() -> void:
	## 还没开局（[code]player.identity_id[/code] 为空）：[code]auto_save[/code]
	## 什么都不写，动作层如实报「没有可保存的进度」而不是假装成功。[br]
	## [br][b]为什么单列一句[/b]：把「没什么可存的」说成「已保存」会让玩家以为
	## 进度落了盘——这两种失败的含义相反。
	# Arrange
	seed_collection()
	seed_deck()
	GameStateManager.player.identity_id = ""
	mount_screen()
	# Act
	var result: Dictionary = actions.call(&"save")
	# Assert
	assert_false(bool(result.get("ok", true)), "未开局时不应报成功")
	assert_true(str(result.get("message", "")).contains("还没有开始"),
			"应说明「还没开局」，实际：%s" % str(result.get("message", "")))


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 空态提示
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_collection_shows_a_chinese_hint_instead_of_a_blank_list() -> void:
	## 一张收藏都没有：左栏空态提示可见且是中文（不显示一片空白）。
	# Arrange
	clear_collection()
	mount_screen()
	# Act + Assert
	assert_eq(screen.collection_count(), 0, "前置：收藏栏应无行")
	assert_true(screen.empty_hint_visible(NavScript.COLUMN_COLLECTION),
			"空收藏时左栏空态提示应可见")
	assert_false(screen.empty_hint_text(NavScript.COLUMN_COLLECTION).strip_edges().is_empty(),
			"空态本身也要有一句中文（不是空白）")
	assert_true(screen.empty_hint_text(NavScript.COLUMN_COLLECTION).contains("收藏"),
			"提示应指明是收藏空了，实际：%s" % screen.empty_hint_text(NavScript.COLUMN_COLLECTION))


func test_empty_deck_shows_a_chinese_hint_instead_of_a_blank_list() -> void:
	## 卡组为空（刚开局还没编牌）：右栏空态提示可见且是中文。
	# Arrange
	seed_collection()
	set_deck([])
	mount_screen()
	# Act + Assert
	assert_eq(screen.deck_count(), 0, "前置：卡组栏应无行")
	assert_true(screen.empty_hint_visible(NavScript.COLUMN_DECK),
			"空卡组时右栏空态提示应可见")
	assert_true(screen.empty_hint_text(NavScript.COLUMN_DECK).contains("卡组"),
			"提示应指明是卡组空了，实际：%s" % screen.empty_hint_text(NavScript.COLUMN_DECK))


func test_non_empty_column_hides_its_empty_hint() -> void:
	## 反例：栏里有卡时那条「还没有卡」的提示必须收起来——不空时说「空」是在说谎。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	# Act + Assert
	assert_false(screen.empty_hint_visible(NavScript.COLUMN_COLLECTION),
			"左栏有卡时空态提示应隐藏")
	assert_false(screen.empty_hint_visible(NavScript.COLUMN_DECK),
			"右栏有卡时空态提示应隐藏")
