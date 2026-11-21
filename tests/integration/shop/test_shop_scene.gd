extends GutTest
## 主菜单坊市（[code]shop_scene.tscn[/code]）端到端 —— 真实场景 + 真实 Autoload。[br]
## [br][b]为什么是集成测试而不是单元测试[/b]：本屏的价值全在「点下去玩家数据真的变了」
## ——灵石扣减走 [code]ResourceSystem[/code]、建卡走 [code]CardSystem[/code]、
## 入收藏走 [code]GameStateManager[/code]，三者都是被测链路的参与者。替身这些依赖
## 就等于把断言换成「我调了那个桩」，验不出「钱货两讫」。[br]
## [br][b]只给一个替身[/b]：空货架那条用例注入一个「不出行」的逻辑替身——
## 它验的是界面在[b]无货可卖[/b]时的形态（空态文案 + 焦点落到「离开」），
## 而真实逻辑层按设计[b]不会[/b]返回空货架（[code]ShopGoodsCatalog.from_state[/code]
## 在条目全非法时回退默认表）。不注入就无法构造这个形态。[br]
## [br][b]存档隔离[/b]：player / collection / 模板校验库 / 校验开关在
## [code]before_each[/code] 快照、[code]after_each[/code] 原样还原
## （同 [code]shop_rest_node_fixture.gd[/code] 口径）。[br]
## [br][b]模板就位[/b]：CardSystem 在 [code]_ready[/code] 里异步装载模板
## （每帧 10 个），装载完成前 [code]ShopLogic.rows[/code] 会把查不到模板的条目
## 全数剔除——货架会是空的。故每次进场景前先同步推进装载
## （[CardTemplatePrimer]），并确保 GSM 的模板库里认得本表的每一件货。[br]
##
## 来源: design/gdd/deck-editing-system.md §3 坊市买卖、
## design/ux/deck-editing-ui.md §坊市-买卡、ADR-0005、ADR-0031 §2、
## 先例 [code]test_shop_and_rest_node_flow.gd[/code]（真实 Autoload + 存档还原）。

const ScreenScene: PackedScene = preload("res://src/feature/shop/shop_scene.tscn")
const CatalogScript := preload("res://src/feature/shop/shop_goods_catalog.gd")
const LogicScript := preload("res://src/feature/shop/shop_logic.gd")
const InventoryScript := preload("res://src/feature/exploration/exploration_shop_inventory.gd")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## 卡牌模板就位助手（异步加载的同步推进）。
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 账上有钱（买得起全列）与没钱（一件也买不起）两档余额。
const RICH: int = 10000
const POOR: int = 1

## 导航桩——记录转场请求，不真跳场景。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 6

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


## 空货架逻辑替身——只用于「无货可卖」那一条形态用例（见文件头「只给一个替身」）。
class EmptyLogic extends RefCounted:
	func balance() -> int:
		return 0

	func rows() -> Array[Dictionary]:
		return []

	func purchase(_p_index: int) -> Dictionary:
		return {"ok": false, "reason": "没有这件商品", "name": "", "price": 0}


var sm: SceneManagerStub = null
var screen: Control = null
var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _db_before: Dictionary = {}
var _validation_before: bool = false


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_db_before = (GameStateManager.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(GameStateManager.validation_enabled)
	_prepare_templates()
	sm = SceneManagerStub.new()
	add_child_autofree(sm)


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	GameStateManager.player = _player_before
	GameStateManager.collection = _collection_before
	GameStateManager.set("_card_template_database", _db_before)
	GameStateManager.validation_enabled = _validation_before
	sm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 模板全部就位 + GSM 校验开启（入收藏的前置条件）。
## [br][br][b]为什么要把每一件货都塞进模板库[/b]：GSM 的校验库在
## [code]enable_validation[/code] 那一刻定型（重复调用不覆盖），只认得当时已装载的
## 模板；而本表的 8 件货未必都在那批里，故逐件补进去（同
## [code]shop_rest_node_fixture.gd[/code] 的补库口径）。
func _prepare_templates() -> void:
	var goods: Array[Dictionary] = CatalogScript.goods()
	var database: Dictionary = GameStateManager.get("_card_template_database")
	for entry: Dictionary in goods:
		var template_id: String = str(entry[CatalogScript.KEY_TEMPLATE_ID])
		PrimerScript.prime(CardSystem, StringName(template_id))
		database[template_id] = database.get(template_id, {})
	GameStateManager.set("_card_template_database", database)
	GameStateManager.validation_enabled = true


## 挂载坊市场景（注入导航桩；[param p_logic] 非空时替换逻辑层）。
func _mount(p_ling_shi: int, p_logic: Variant = null) -> Control:
	_set_ling_shi(p_ling_shi)
	var instance: Control = ScreenScene.instantiate() as Control
	instance.set("scene_manager", sm)
	if p_logic != null:
		instance.set("shop_logic", p_logic)
	add_child_autofree(instance)
	return instance


func _set_ling_shi(p_value: int) -> void:
	GameStateManager._set_resource_ling_shi(p_value)


func _ling_shi() -> int:
	return int(GameStateManager.player.resources.ling_shi)


func _collection_count() -> int:
	return int(GameStateManager.collection.total_count)


func _last_owned_template() -> String:
	var owned: Array = GameStateManager.collection.owned_cards
	if owned.is_empty():
		return ""
	return str((owned[owned.size() - 1] as Dictionary).get("template_id", ""))


## 造一条按键事件。
func _key(p_code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = p_code
	event.pressed = true
	event.echo = false
	return event


## 投递一条真实按键（按下 + 抬起成对——引擎对合成事件同样做 UI 动作派发）。[br]
## [br][b]两条事件都要发、且都要带 [member InputEventKey.physical_keycode][/b]：
## 实测（[code]tools/probe_shop_leave_enter.gd[/code]）只投「按下」一条、且不带
## physical 键码时，焦点在 [Button] 上的回车[b]不会[/b]被翻译成按钮的
## [signal Button.pressed]（[code]ui_accept[/code] 的动作派发只在完整配对上成立）
## ——测试会在「回车没反应」上假红。同 [code]real_input_click_driver.gd[/code]
## 的战斗用例口径。
func _press(p_code: Key) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for is_pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = p_code
		event.physical_keycode = p_code
		event.pressed = is_pressed
		tree.root.push_input(event, true)


# ═══════════════════════════════════════════════════════════════════════════════
# 上架
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_scene_shows_one_row_per_configured_good() -> void:
	# Arrange + Act——进坊市（模板已就位，全列可上架）
	screen = _mount(RICH)
	# Assert——行数与商品表件数一致（不多不少）
	var goods: Array[Dictionary] = CatalogScript.goods()
	assert_eq(screen.item_count(), goods.size(), "行数应与商品表件数一致")
	assert_eq(screen.item_texts().size(), goods.size(), "每个配置项应有一行控件")
	assert_eq(str(screen.balance_text()), "灵石：%d" % RICH, "右上应显示真实余额")


func test_shop_scene_rows_show_name_rarity_and_price() -> void:
	# Arrange + Act
	screen = _mount(RICH)
	var first: String = str(screen.item_texts()[0])
	# Assert——首行文案含名称 / 稀有度 / 价格三件事（不只一个 ID）
	assert_true(first.contains("培元丹"), "首行应含卡牌中文名：%s" % first)
	assert_true(first.contains("白"), "首行应含稀有度：%s" % first)
	assert_true(first.contains("10 灵石"), "首行应含价格：%s" % first)


func test_shop_scene_prices_follow_the_shared_rarity_table() -> void:
	# Arrange——逐件对着稀有度定价表核价（防商品表与定价表漂移）
	var logic: RefCounted = LogicScript.new(ResourceSystem, CardSystem, GameStateManager)
	var rows: Array = logic.call(&"rows")
	var goods: Array[Dictionary] = CatalogScript.goods()
	# Assert——每件货的价格 = 该模板稀有度对应的档位价
	assert_eq(rows.size(), goods.size(), "前置：全部货都应可上架")
	for row: Dictionary in rows:
		var expected: int = InventoryScript.price_for_rarity(int(row["rarity"]))
		assert_eq(int(row["price"]), expected,
				"%s 的价格应与稀有度定价表一致" % str(row["name"]))


# ═══════════════════════════════════════════════════════════════════════════════
# 购买：成功路径
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_scene_buy_row_spends_exact_price_and_adds_card() -> void:
	# Arrange
	screen = _mount(RICH)
	var price: int = int(_goods_price(0))
	var cards_before: int = _collection_count()
	# Act——买首行
	screen.press_item(0)
	# Assert——灵石少得恰好是那一件的价、收藏多一张、且是这件货
	assert_eq(_ling_shi(), RICH - price, "灵石应减少恰好等于价格")
	assert_eq(_collection_count(), cards_before + 1, "收藏应 +1")
	assert_eq(_last_owned_template(), str(_goods_id(0)), "入收藏的应是这一件")


func test_shop_scene_buy_shows_purchase_message() -> void:
	# Arrange
	screen = _mount(RICH)
	# Act
	screen.press_item(0)
	# Assert——提示行出现成功文案（含卡名，玩家看得出买的是什么）
	var message: String = str(screen.message_text())
	assert_true(message.contains("已购入"), "成功应提示已购入：%s" % message)
	assert_true(message.contains("培元丹"), "提示应含卡名：%s" % message)


func test_shop_scene_buy_twice_both_succeed_on_unlimited_stock() -> void:
	# Arrange——坊市是常驻摊位（不像探索节点买走即售罄）
	screen = _mount(RICH)
	var price: int = int(_goods_price(0))
	var cards_before: int = _collection_count()
	# Act——同一件连买两次
	screen.press_item(0)
	screen.press_item(0)
	# Assert——两次都成（钱扣两份、卡进两张，行仍可买）
	assert_eq(_ling_shi(), RICH - price * 2, "连买两次应扣两份钱")
	assert_eq(_collection_count(), cards_before + 2, "连买两次应进两张卡")
	assert_true(screen.is_item_enabled(0), "常驻摊位的货买完仍在售")


# ═══════════════════════════════════════════════════════════════════════════════
# 购买：拒绝路径（一分钱不动）
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_scene_unaffordable_row_changes_nothing_and_explains() -> void:
	# Arrange——余额 1，全列买不起
	screen = _mount(POOR)
	var cards_before: int = _collection_count()
	# Assert——前置：首行买不起（禁用 + 文案标注）
	assert_false(screen.is_item_enabled(0), "前置：买不起的行应禁用")
	assert_true(str(screen.item_texts()[0]).contains("灵石不足"),
			"买不起的行应在文案里写明原因（不只靠颜色）")
	# Act——点那行
	screen.press_item(0)
	# Assert——灵石与收藏都没变，且给了中文原因
	assert_eq(_ling_shi(), POOR, "买不起时不得扣钱")
	assert_eq(_collection_count(), cards_before, "买不起时不得发卡")
	var message: String = str(screen.message_text())
	assert_true(message.contains("灵石不足"), "应给出中文原因：%s" % message)
	assert_true(message.contains("当前 %d" % POOR), "原因里应写清差多少：%s" % message)


func test_shop_scene_poor_shelf_puts_focus_on_leave() -> void:
	# Arrange + Act——余额 1，全列买不起 → 无可选行
	screen = _mount(POOR)
	# Assert——游标无落点，焦点退到「离开」（否则按回车什么都不发生）
	assert_eq(screen.focused_index(), -1, "无买得起的货时游标应无落点")
	assert_true(screen.is_leave_focused(), "此时焦点应落在「离开」上")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_scene_default_focus_lands_on_first_row() -> void:
	# Arrange + Act
	screen = _mount(RICH)
	# Assert——默认焦点在第一行（进场景就能直接按回车买）
	assert_eq(screen.focused_index(), 0, "默认游标应在首行")
	assert_true(screen.is_item_focused(0), "首行应真的持有键盘焦点")


func test_shop_scene_arrow_keys_move_cursor() -> void:
	# Arrange
	screen = _mount(RICH)
	# Act——↓ 再 ↑（真实按键派发）
	_press(KEY_DOWN)
	# Assert
	assert_eq(screen.focused_index(), 1, "↓ 应把游标移到第 2 行")
	assert_true(screen.is_item_focused(1), "第 2 行应取得键盘焦点")
	_press(KEY_UP)
	assert_eq(screen.focused_index(), 0, "↑ 应把游标移回第 1 行")


func test_shop_scene_enter_key_buys_focused_row() -> void:
	# Arrange
	screen = _mount(RICH)
	var price: int = int(_goods_price(1))
	var cards_before: int = _collection_count()
	# Act——↓ 选中第 2 行 → 回车
	_press(KEY_DOWN)
	_press(KEY_ENTER)
	# Assert——买的是游标那一行（不是永远的首行）
	assert_eq(_ling_shi(), RICH - price, "回车应买下游标所在行")
	assert_eq(_collection_count(), cards_before + 1, "回车购买应发出卡")
	assert_eq(_last_owned_template(), str(_goods_id(1)), "入收藏的应是游标那一行")


func test_shop_scene_escape_returns_to_main_menu() -> void:
	# Arrange
	screen = _mount(RICH)
	sm.requests.clear()
	# Act——Esc
	_press(KEY_ESCAPE)
	# Assert——经 SceneManager 回主菜单（ADR-0005 唯一入口 + 音频过渡类型）
	assert_eq(sm.requests.size(), 1, "Esc 应发出一次转场请求")
	assert_eq(int(sm.requests[0]["from"]), SceneManagerScript.SceneID.SHOP, "from 应为当前场景")
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.MAIN_MENU, "应回主菜单")
	assert_eq(int(sm.requests[0]["type"]),
			SceneManagerScript.TransitionType.GAME_TO_MENU, "应走回主菜单的过渡类型")


func test_shop_scene_leave_button_returns_to_main_menu() -> void:
	# Arrange
	screen = _mount(RICH)
	sm.requests.clear()
	# Act——点「离开」
	screen.press_leave()
	# Assert——与 Esc 同一出口
	assert_eq(sm.requests.size(), 1, "「离开」应发出一次转场请求")
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.MAIN_MENU, "应回主菜单")


# ═══════════════════════════════════════════════════════════════════════════════
# 空货架
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_scene_empty_shelf_shows_empty_state_without_error() -> void:
	# Arrange + Act——注入「不出行」的逻辑替身（真实逻辑层按设计不会空货架）
	screen = _mount(RICH, EmptyLogic.new())
	# Assert——零行、空态文案可见、焦点落在「离开」（不留一块没话说的空面板）
	assert_eq(screen.item_count(), 0, "空货架应零行")
	assert_true(str(screen.message_text()).contains("货架空空"),
			"空货架应有空态文案：%s" % str(screen.message_text()))
	assert_true(screen.is_leave_focused(), "空货架时焦点应落在「离开」")
	# Act——此时回车应触发「离开」而不是崩
	sm.requests.clear()
	_press(KEY_ENTER)
	# Assert——发出回主菜单的请求
	assert_eq(sm.requests.size(), 1, "空货架下回车应触发「离开」")


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助：读商品表（按屏幕行下标取——测试里两者相等，见上架用例）
# ═══════════════════════════════════════════════════════════════════════════════

func _goods_id(p_index: int) -> String:
	var goods: Array[Dictionary] = CatalogScript.goods()
	return str((goods[p_index] as Dictionary)[CatalogScript.KEY_TEMPLATE_ID])


func _goods_price(p_index: int) -> int:
	var goods: Array[Dictionary] = CatalogScript.goods()
	return int((goods[p_index] as Dictionary)[CatalogScript.KEY_PRICE])
