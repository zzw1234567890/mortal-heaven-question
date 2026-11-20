extends GutTest
## 弹窗开合时的键盘/手柄焦点记忆（CombatFocusMemory）。[br]
## [br][b]背景[/b]：面板一开就把焦点抢走，关闭时[b]没有任何东西记得它是从哪来的[/b]。
## 当前兜底是「焦点为空就补默认焦点」，于是「取消一次撤退确认」之后焦点从撤退按钮
## 跳到第一张手牌——每开一次面板丢一次位置，手柄玩家得重走整条链。[br]
## [br][b]本文件锁定六条语义[/b]：[br]
##   1. 打开前记下焦点，关闭后还给同一处；[br]
##   2. 记住的控件没了 / 隐藏了 / 被阶段停用 → 落兜底默认焦点；[br]
##   3. 没兜底时如实返回 null（不假装还回去了）；[br]
##   4. 从没记过 → 关闭时什么都不做（鼠标玩家的常态，不该凭空塞一个焦点）；[br]
##   5. 取走即清空（连开两个面板时不把焦点还到更早的位置）；[br]
##   6. 焦点为空时不记忆（鼠标点开面板时焦点常常本来就空着）。[br]
## [br]全部用例使用自建控件树——不触碰 Autoload、不加载战斗场景。

const MemoryScript := preload("res://src/ui/combat/interaction/combat_focus_memory.gd")

var _host: Control = null
var _memory: RefCounted = null


func before_each() -> void:
	_host = Control.new()
	_host.name = "Host"
	_host.size = Vector2(800, 600)
	add_child_autofree(_host)
	_memory = MemoryScript.new()


func after_each() -> void:
	get_viewport().gui_release_focus()
	_memory = null
	await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 还原到原处
# ═══════════════════════════════════════════════════════════════════════════════

## 弹窗打开前焦点在撤退按钮上，关掉后还给撤退按钮（而不是默认焦点）。[br]
## [br][b]这就是本类存在的理由[/b]：现状是关一次面板焦点就搬家。
func test_restore_returns_focus_to_remembered_control() -> void:
	# Arrange
	var retreat: Button = _add_button("RetreatButton", _host)
	var first_card: Button = _add_button("Card0", _host)
	retreat.grab_focus()
	assert_eq(_focus_owner(), retreat, "前置：焦点在撤退按钮上")
	_memory.call(&"remember_current")
	# Act——模拟弹窗抢焦点
	first_card.grab_focus()
	assert_eq(_focus_owner(), first_card, "前置：弹窗内控件已抢走焦点")
	var restored: Variant = _memory.call(&"restore")
	# Assert
	assert_eq(restored, retreat, "应把焦点还给打开前的控件")
	assert_eq(_focus_owner(), retreat, "焦点真的回到了撤退按钮")


## 记住的控件被隐藏 → 判为「还不了」，落兜底默认焦点。[br]
## [br][b]为什么隐藏要算失效[/b]：敌方行动阶段手牌整批退出焦点（[code]focus_mode[/code]
## 置 NONE）且可能被隐藏；把一个已不可见的控件当成落点是自欺。
func test_restore_falls_back_when_target_hidden() -> void:
	# Arrange
	var target: Button = _add_button("Card0", _host)
	var fallback: Button = _add_button("BagButton", _host)
	_memory.call(&"set_fallback", func() -> bool:
		fallback.grab_focus()
		return true)
	target.grab_focus()
	_memory.call(&"remember_current")
	target.visible = false
	# Act
	var restored: Variant = _memory.call(&"restore")
	# Assert
	assert_eq(restored, fallback, "原处不可见时应落兜底")
	assert_eq(_focus_owner(), fallback, "兜底控件应真的拿到焦点")


## 记住的控件被阶段停用（[code]focus_mode = NONE[/code]）→ 同样落兜底。
func test_restore_falls_back_when_target_not_focusable() -> void:
	# Arrange
	var target: Button = _add_button("Card0", _host)
	var fallback: Button = _add_button("BagButton", _host)
	_memory.call(&"set_fallback", func() -> bool:
		fallback.grab_focus()
		return true)
	target.grab_focus()
	_memory.call(&"remember_current")
	target.focus_mode = Control.FOCUS_NONE  # 离开出牌阶段
	# Act
	var restored: Variant = _memory.call(&"restore")
	# Assert
	assert_eq(restored, fallback, "原处不可聚焦时应落兜底")
	assert_eq(_focus_owner(), fallback, "兜底控件应真的拿到焦点")


## 记住的控件被释放 → 不炸，落兜底。
func test_restore_falls_back_when_target_freed() -> void:
	# Arrange
	var target: Button = _add_button("Doomed", _host)
	var fallback: Button = _add_button("BagButton", _host)
	_memory.call(&"set_fallback", func() -> bool:
		fallback.grab_focus()
		return true)
	target.grab_focus()
	_memory.call(&"remember_current")
	target.free()
	# Act
	var restored: Variant = _memory.call(&"restore")
	# Assert
	assert_eq(restored, fallback, "原处已释放时应落兜底")


## 原处还不了、又没注册兜底 → 返回 null（如实报告，不假装成功）。
func test_restore_returns_null_without_fallback() -> void:
	# Arrange
	var target: Button = _add_button("Card0", _host)
	target.grab_focus()
	_memory.call(&"remember_current")
	target.free()
	# Act
	var restored: Variant = _memory.call(&"restore")
	# Assert
	assert_null(restored, "无兜底时还不了就应返回 null")
	assert_null(_focus_owner(), "焦点不该被塞给任何控件")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 没记过就什么都不做
# ═══════════════════════════════════════════════════════════════════════════════

## 从没记过 → [method restore] 是空操作，不会凭空把焦点塞给兜底控件。[br]
## [br][b]为什么这条必须钉住[/b]：鼠标玩家点开面板时焦点常常本来就空着
## （点鼠标不改键盘焦点，实测）；此时「关闭后落默认焦点」正是
## 「关一次面板跳一次焦点」这个症状本身。
func test_restore_is_noop_when_nothing_remembered() -> void:
	# Arrange
	var fallback: Button = _add_button("BagButton", _host)
	_memory.call(&"set_fallback", func() -> bool:
		fallback.grab_focus()
		return true)
	assert_null(_memory.call(&"remembered"), "前置：未记过任何控件")
	# Act
	var restored: Variant = _memory.call(&"restore")
	# Assert
	assert_null(restored, "没记过就应返回 null")
	assert_null(_focus_owner(), "不该凭空落兜底焦点")


## 焦点为空时 [method remember_current] 不记忆（不把 null 写进记忆）。[br]
## [br][b]为什么区分「记住空」与「什么都不记」[/b]：面板套面板时，内层面板若把
## 记忆抹成 null，外层关闭时就再也还不了位置了。
func test_remember_current_skips_when_focus_empty() -> void:
	# Arrange
	var earlier: Button = _add_button("RetreatButton", _host)
	earlier.grab_focus()
	_memory.call(&"remember_current")
	get_viewport().gui_release_focus()
	# Act——焦点空着再记一次
	_memory.call(&"remember_current")
	# Assert
	assert_eq(_memory.call(&"remembered"), earlier, "焦点为空时不该抹掉已有的记忆")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 取走即清空
# ═══════════════════════════════════════════════════════════════════════════════

## 还原过一次之后记忆即空——第二次关闭不重复消费。[br]
## [br][b]为什么必须有这条[/b]：连开两个面板（行囊 → 撤退确认）时，第二个面板关掉
## 若不检查，会把焦点还到第一个面板之前的位置，而不是还给「行囊」。
func test_restore_consumes_memory() -> void:
	# Arrange
	var retreat: Button = _add_button("RetreatButton", _host)
	retreat.grab_focus()
	_memory.call(&"remember_current")
	# Act
	_memory.call(&"restore")
	# Assert
	assert_null(_memory.call(&"remembered"), "还原后记忆应清空")
	assert_null(_memory.call(&"restore"), "再还原一次应为空操作")


## [method clear] 只丢句柄、不还焦点（退场用）。
func test_clear_drops_handle_without_restoring() -> void:
	# Arrange
	var retreat: Button = _add_button("RetreatButton", _host)
	retreat.grab_focus()
	_memory.call(&"remember_current")
	get_viewport().gui_release_focus()
	# Act
	_memory.call(&"clear")
	# Assert
	assert_null(_memory.call(&"remembered"), "clear 后记忆应为空")
	assert_null(_focus_owner(), "clear 不该顺手还焦点")


## [method remember] 可直接记一个控件（手工装配路径）。
func test_remember_accepts_explicit_control() -> void:
	# Arrange
	var target: Button = _add_button("EndTurnButton", _host)
	# Act
	_memory.call(&"remember", target)
	# Assert
	assert_eq(_memory.call(&"remembered"), target, "应记住显式传入的控件")


# ═══════════════════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════════════════

func _add_button(p_name: String, p_parent: Node) -> Button:
	var button := Button.new()
	button.name = p_name
	button.focus_mode = Control.FOCUS_ALL
	button.size = Vector2(80, 30)
	p_parent.add_child(button)
	return button


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()
