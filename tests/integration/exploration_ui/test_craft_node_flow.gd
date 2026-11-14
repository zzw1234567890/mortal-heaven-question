extends "res://tests/integration/exploration_ui/craft_node_fixture.gd"
## 炼丹台/炼器台端到端 —— 到达节点 → 面板上架可炼清单 → 点击炼制 → 扣料入库 → 离开。[br]
## [br][b]为什么是集成测试[/b]：本用例穿过「交互组件转发 → CraftNodePresenter → 面板 →
## 探索系统结算 → AlchemySystem → ResourceSystem/CardSystem/GSM」整条链，验证的是接线，
## 而不只是公式（公式与结算层的拒绝路径见 [code]test_exploration_craft.gd[/code]）。[br]
## [br][b]断言点[/b]：[br]
##   · 到达后[b]不需要确认框[/b]——炼制面板直接上架（与采集/传送同类的 overlay）；[br]
##   · 面板列的配方与 [code]AlchemyRecipes[/code] 一致，每行带所需与持有量；[br]
##   · 灵材不足 / 收藏已满的行禁用 + 中文原因，点击不发意图；[br]
##   · 点击可炼行后灵材真的扣、卡真的进收藏，面板重取清单后该行转禁用；[br]
##   · 两个台子共用一份 Presenter，靠面板标题区分；离开时解冻且结果不回退。[br]
## [br]装置见 [code]craft_node_fixture.gd[/code] 的类文档。
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§4/§边界/AC-1、
## design/gdd/exploration-ui-system.md §4c（overlay 先例）、ADR-0028 §craft_pill、
## ADR-0031 §2。

const CraftScript := preload("res://src/feature/exploration/exploration_craft.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 到达 → 面板
# ═══════════════════════════════════════════════════════════════════════════════

func test_craft_arrival_opens_panel_with_recipe_rows() -> void:
	# Act——经交互组件的转发信号到达（生产路径的同一发射点）
	reach(ALCHEMY_NODE, &"alchemy")
	# Assert——无需确认框，面板直接上架；行数 = 配方资源条数
	var p: Variant = panel()
	assert_not_null(p, "炼丹台到达后应上架炼制面板")
	assert_eq(int(p.call(&"entry_count")), ListScript.recipes_of(&"alchemy").size(),
			"面板行数应与配方资源条数一致（读资源，不硬编码）")
	assert_true(str(p.call(&"title_text")).contains("炼丹"), "标题应标明这是炼丹台")


func test_craft_arrival_produces_no_confirm_popup() -> void:
	reach(ALCHEMY_NODE, &"alchemy")
	assert_eq(popup_host().call(&"get_open_kind"), &"",
			"炼制走独立通道——不得开确认弹窗（否则要玩家点两次）")


func test_craft_panel_freezes_node_graph() -> void:
	reach(ALCHEMY_NODE, &"alchemy")
	assert_true(bool(presenter().call(&"is_node_graph_frozen")),
			"炼制面板期间节点图应冻结（GDD §4c overlay 口径）")


func test_forge_node_reuses_presenter_with_own_title() -> void:
	# Act——到达炼器台（同一 Presenter 实例，靠 kind 区分）
	reach(FORGE_NODE, &"forge")
	# Assert——标题换成炼器台，行内容来自炼器配方表
	var p: Variant = panel()
	assert_true(str(p.call(&"title_text")).contains("炼器"),
			"炼器台应显示炼器台标题（同一 Presenter 的两个台子）")
	assert_eq(int(p.call(&"entry_count")), ListScript.recipes_of(&"forge").size(),
			"行数应来自炼器配方资源")


# ═══════════════════════════════════════════════════════════════════════════════
# 行状态（材料不足 / 收藏已满 → 禁用 + 中文原因）
# ═══════════════════════════════════════════════════════════════════════════════

func test_insufficient_rows_disabled_with_reason_and_click_sends_nothing() -> void:
	# Arrange——一件灵材都没有
	reach(ALCHEMY_NODE, &"alchemy")
	var p: Variant = panel()
	var row: int = row_of(p, PILL_ID)
	# Assert——禁用 + 中文原因写明缺口；点击不发意图
	assert_false(bool(p.call(&"is_entry_enabled", row)), "材料不足的行应禁用")
	assert_true(row_text(p, row).contains("灵材不足"), "禁用原因应写进行文本（不只靠颜色）")
	p.call(&"press_entry", row)
	assert_eq(collection_count(), 0, "点击禁用行不得产出卡")


func test_row_text_shows_required_and_held_amounts() -> void:
	# Arrange——下品 5（够炼回春丹）
	set_materials({1: 5})
	reach(ALCHEMY_NODE, &"alchemy")
	var p: Variant = panel()
	var row: int = row_of(p, PILL_ID)
	# Assert——所需与持有并排（玩家不必自己减），该行可点
	assert_true(row_text(p, row).contains("×%d" % PILL_LOW_COST), "行文本应写出所需数量")
	assert_true(row_text(p, row).contains("持 5"), "行文本应写出当前持有量")
	assert_true(bool(p.call(&"is_entry_enabled", row)), "材料够的行应可点")


func test_collection_full_row_disabled_and_state_unchanged() -> void:
	# Arrange——灵材够，但收藏池已满
	set_materials({1: 5})
	GameStateManager.collection.total_count = CraftScript.COLLECTION_CAP
	reach(ALCHEMY_NODE, &"alchemy")
	var p: Variant = panel()
	var row: int = row_of(p, PILL_ID)
	# Assert——该行禁用且原因是「收藏已满」；点也不动状态
	assert_false(bool(p.call(&"is_entry_enabled", row)), "收藏已满时行应禁用")
	assert_true(row_text(p, row).contains("收藏已满"), "禁用原因应为中文「收藏已满」")
	p.call(&"press_entry", row)
	assert_eq(low_cai(), 5, "被拒的炼制不得扣灵材")
	assert_eq(collection_count(), CraftScript.COLLECTION_CAP, "收藏张数不得变化")


# ═══════════════════════════════════════════════════════════════════════════════
# 点击炼制 → 扣料入库
# ═══════════════════════════════════════════════════════════════════════════════

func test_click_crafts_deducts_materials_and_stores_card() -> void:
	# Arrange——下品 2，恰好够炼一炉
	set_materials({1: PILL_LOW_COST})
	reach(ALCHEMY_NODE, &"alchemy")
	var p: Variant = panel()
	# Act——点可炼行（真实信号路径，不直调私有方法）
	p.call(&"press_entry", row_of(p, PILL_ID))
	# Assert——灵材真的扣了、卡真的进收藏、面板重取后该行转禁用
	assert_eq(low_cai(), 0, "点击后应扣掉配方要求的下品灵材")
	assert_eq(collection_count(), 1, "炼成的丹药应入收藏")
	assert_eq(last_owned_template(), PILL_TEMPLATE, "入收藏的应是配方模板")
	assert_true(str(p.call(&"message_text")).begins_with("炼成"), "结果文案应为系统给的中文提示")
	assert_false(bool(p.call(&"is_entry_enabled", row_of(p, PILL_ID))),
			"材料已不够第二炉，该行应转为禁用（面板已重取清单）")


func test_forge_click_crafts_artifact_into_collection() -> void:
	# Arrange——下品 3（恰好够基础法器）
	set_materials({1: 3})
	reach(FORGE_NODE, &"forge")
	var p: Variant = panel()
	# Act
	p.call(&"press_entry", row_of(p, ARTIFACT_ID))
	# Assert
	assert_eq(low_cai(), 0, "炼器应扣掉三份下品灵材")
	assert_eq(last_owned_template(), ARTIFACT_TEMPLATE, "产出的法宝应入收藏")


func test_craft_twice_from_panel_keeps_counts_correct() -> void:
	# Arrange——下品 4，够炼两炉
	set_materials({1: 4})
	reach(ALCHEMY_NODE, &"alchemy")
	var p: Variant = panel()
	# Act——连点两次同一行（面板每次结算后重建行）
	p.call(&"press_entry", row_of(p, PILL_ID))
	p.call(&"press_entry", row_of(p, PILL_ID))
	# Assert
	assert_eq(collection_count(), 2, "两次炼制应产出两张卡")
	assert_eq(low_cai(), 4 - PILL_LOW_COST * 2, "灵材应按两次扣减")


# ═══════════════════════════════════════════════════════════════════════════════
# 离开
# ═══════════════════════════════════════════════════════════════════════════════

func test_craft_cancel_keeps_crafted_result_and_unfreezes() -> void:
	# Arrange——炼一炉后离开
	set_materials({1: 5})
	reach(ALCHEMY_NODE, &"alchemy")
	var p: Variant = panel()
	p.call(&"press_entry", row_of(p, PILL_ID))
	var crafted: int = low_cai()
	# Act——点「离开」
	p.call(&"press_leave")
	# Assert——面板关闭 + 解冻，但已炼成的东西不回退
	assert_null(presenter().call(&"panel"), "离开后不应还有面板")
	assert_false(bool(presenter().call(&"is_node_graph_frozen")), "离开后应解冻")
	assert_eq(low_cai(), crafted, "取消不得回退已扣的材料")
	assert_eq(collection_count(), 1, "取消不得移除已入库的产物")
