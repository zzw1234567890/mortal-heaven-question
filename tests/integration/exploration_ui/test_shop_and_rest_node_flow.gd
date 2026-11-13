extends "res://tests/integration/exploration_ui/shop_rest_node_fixture.gd"
## 商店 / 回复节点的端到端交互 —— 「确认之后」那一段的真实链路。[br]
## [br][b]本文件补的断链[/b]：确认框此前只发 [code]shop_opened[/code] /
## [code]rest_used[/code] 信号，[b]没有任何消费方[/b]——商店确认后什么都不发生，
## 回复确认后 [code]ExplorationSystem.rest_at_node[/code] 还不存在（宿主
## push_warning 返回 0）。本文件走屏幕 → 交互组件 → 弹窗宿主 → Presenter →
## 面板/系统的完整链路，断言「点下去真的有结果」。[br]
## [br][b]覆盖[/b]（本轮任务点名的四条）：[br]
##   1. 到达商店 → 弹窗确认 → 商店面板上架（余额 + 商品行）；[br]
##   2. 买一件 → 灵石扣掉、卡牌进收藏、该行变售罄；[br]
##   3. 灵石不足 → 提示「灵石不足」且一分钱不扣（面板不派发 + 结算层拒绝）；[br]
##   4. 到达回复节点 → 全队按 GDD §公式 7 回血，且不超各自上限。[br]
## [br][b]用真实 Autoload[/b]：ResourceSystem / CardSystem / GSM 都是被测链路的
## 参与者——断言的就是「玩家数据变了」。[br]
## [br]装置（场景搭建、存档快照还原、辅助方法）见
## [code]shop_rest_node_fixture.gd[/code]。[br]
##
## 来源: GDD exploration-system.md §公式 7 / §8 边界、exploration-ui-system.md §4c、
## ADR-0031 §2、本轮「商店节点 + 回复节点的最小可用交互」任务。


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 到达商店 → 确认 → 面板上架
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_node_arrival_confirm_opens_panel_with_balance_and_items() -> void:
	# Arrange——玩家身上有 100 灵石
	_set_ling_shi(100)
	# Act——到达商店节点（交互组件转发的真实载荷）→ 点确认
	_reach(SHOP_NODE, &"shop", _shop_payload(CARD_PRICE, 1))
	_confirm()
	# Assert——面板上架：余额行 + 商品行都在（不是空面板）
	var panel: Variant = _panel()
	assert_not_null(panel, "商店确认后应上架商店面板")
	assert_eq(str(panel.call(&"balance_text")), "灵石：100", "面板显示真实余额")
	assert_eq(int(panel.call(&"item_count")), 1, "面板应按载荷上架一件商品")
	assert_true(str((panel.call(&"item_texts") as Array)[0]).contains("灵石"),
			"商品行文案含价格")


func test_shop_panel_freezes_node_graph_input() -> void:
	# GDD §4c「商店 overlay——节点图冻结」：面板在场期间节点图不吃输入
	_set_ling_shi(100)
	_reach(SHOP_NODE, &"shop", _shop_payload(CARD_PRICE, 1))
	_confirm()
	# Assert——冻结已生效（遮罩拦鼠标、键盘路径关闭、视口冻结）
	assert_true(bool(_presenter().call(&"is_node_graph_frozen")), "面板期间应冻结节点图")
	assert_true(bool(_viewport().get(&"input_frozen")), "视口应冻结缩放/平移")
	assert_eq(_renderer().mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"节点图不应接收点击（面板遮罩之下不得穿透）")
	assert_false(_interactor().is_processing_unhandled_key_input(),
			"面板期间不应处理键盘走位")
	# Act——点「离开」
	_panel().call(&"press_leave")
	# Assert——全部还原（否则下一张地图点不动）
	assert_false(bool(_presenter().call(&"is_node_graph_frozen")), "关闭后应解冻节点图")
	assert_false(bool(_viewport().get(&"input_frozen")), "关闭后应解冻视口")
	assert_eq(_renderer().mouse_filter, Control.MOUSE_FILTER_STOP, "关闭后应恢复鼠标过滤")
	assert_true(_interactor().is_processing_unhandled_key_input(), "关闭后键盘走位应恢复")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 买一件 → 扣灵石 + 进收藏 + 售罄
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_purchase_deducts_lingshi_and_adds_card() -> void:
	# Arrange
	_set_ling_shi(100)
	var cards_before: int = _collection_count()
	_reach(SHOP_NODE, &"shop", _shop_payload(CARD_PRICE, 1))
	_confirm()
	# Act——点第一件商品
	_panel().call(&"press_item", 0)
	# Assert——扣钱、入库、行变售罄
	assert_eq(_ling_shi(), 100 - CARD_PRICE, "购买后应扣掉商品价格")
	assert_eq(_collection_count(), cards_before + 1, "购买后卡牌应进收藏")
	assert_eq(_last_owned_template(), str(CARD_ID), "入库的是货架上那张卡")
	assert_false(bool(_panel().call(&"is_item_enabled", 0)), "买走一件后该行应禁用")
	assert_true(str((_panel().call(&"item_texts") as Array)[0]).contains("已售罄"),
			"售罄状态应有文字标记（不只靠禁用态）")
	assert_true(str(_panel().call(&"message_text")).contains("购入"),
			"面板应回填系统给的成交文案")


func test_shop_purchase_when_short_on_lingshi_warns_and_keeps_money() -> void:
	# Arrange——余额只够一半
	_set_ling_shi(CARD_PRICE - 1)
	var cards_before: int = _collection_count()
	_reach(SHOP_NODE, &"shop", _shop_payload(CARD_PRICE, 1))
	_confirm()
	# Assert——面板把这一行标成不可买并给出文字提示
	assert_false(bool(_panel().call(&"is_item_enabled", 0)), "买不起的行应禁用")
	assert_true(str((_panel().call(&"item_texts") as Array)[0]).contains("灵石不足"),
			"买不起应有「灵石不足」文字标记")
	# Act——点这一行（禁用行不派发意图）
	_panel().call(&"press_item", 0)
	# Assert——钱没动、卡没进
	assert_eq(_ling_shi(), CARD_PRICE - 1, "买不起时不得扣钱")
	assert_eq(_collection_count(), cards_before, "买不起时不得发卡")


func test_shop_purchase_guard_rejects_insufficient_funds_directly() -> void:
	# 结算层的第二道闸——即使面板被绕过（脚本/异常输入），扣费前也会拒绝
	_set_ling_shi(CARD_PRICE - 1)
	var cards_before: int = _collection_count()
	_reach(SHOP_NODE, &"shop", _shop_payload(CARD_PRICE, 1))
	_confirm()
	# Act——绕过面板直接调结算层
	var result: Dictionary = _presenter().call(&"shop").call(&"purchase", 0)
	# Assert
	assert_false(bool(result.get("ok", true)), "余额不足时购买应失败")
	assert_true(str(result.get("message", "")).contains("灵石不足"), "失败文案点名灵石不足")
	assert_eq(int(result.get("spent", -1)), 0, "失败不得报告花费")
	assert_eq(_ling_shi(), CARD_PRICE - 1, "失败不得扣钱")
	assert_eq(_collection_count(), cards_before, "失败不得发卡")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 回复节点 → 回血且不超上限
# ═══════════════════════════════════════════════════════════════════════════════

func test_rest_node_confirm_heals_party_capped_at_max_hp() -> void:
	# Arrange——两名角色各 1/10（合计缺口 18 → 回复 9）
	_reach(REST_NODE, &"rest", {})
	# Act——点「休息」（宿主经探索系统 API 结算，UI 只显示返回值）
	_confirm()
	# Assert——总额正确
	var healed: int = _hinted_amount()
	assert_eq(healed, EXPECTED_HEAL, "全队回复量应为 floor(缺口 × 0.5)")
	assert_eq(_hp_of(CHAR_A) + _hp_of(CHAR_B),
			CHAR_START_HP * 2 + EXPECTED_HEAL, "回复量应真的写进玩家血量")
	# Assert——夹到上限：先分配的角色恰好补满，不是补到 10 以上
	assert_eq(_hp_of(CHAR_A), CHAR_MAX_HP, "先分配的角色应恰好补到上限")
	for char_id: int in [CHAR_A, CHAR_B]:
		assert_true(_hp_of(char_id) <= CHAR_MAX_HP,
				"角色 %d 的 HP 不得超过其上限" % char_id)
	assert_true(_presenter().call(&"last_hint").contains("回复 %d 点生命" % EXPECTED_HEAL),
			"应给出一句回血提示（文案含实际回复量）")


func test_rest_node_confirm_on_full_party_reports_nothing_to_heal() -> void:
	# Arrange——全队满血（无缺口）
	_set_hp(CHAR_A, CHAR_MAX_HP)
	_set_hp(CHAR_B, CHAR_MAX_HP)
	_reach(REST_NODE, &"rest", {})
	# Act
	_confirm()
	# Assert——不写任何状态，给一句「安然无恙」（不显示「回复 0 点」）
	assert_eq(_hp_of(CHAR_A), CHAR_MAX_HP, "满血角色不应被写坏")
	assert_eq(_hp_of(CHAR_B), CHAR_MAX_HP, "满血角色不应被写坏")
	assert_eq(_hinted_amount(), 0, "无缺口时提示里不应出现回复量")
	assert_true(_presenter().call(&"last_hint").contains("安然无恙"),
			"无缺口应给「全队安然无恙」而不是「回复 0 点」")
