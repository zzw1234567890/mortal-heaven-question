extends RefCounted
## DeckEditingTemplateWatch —— 卡组编辑界面的[b]模板就绪守望[/b]（接线 + 到点回调）。[br]
## [br][b]为什么单独一处[/b]：界面本体要守 300 行软上限
## （.claude/docs/coding-standards.md），而「等异步模板装载完再刷一次」与
## 「游标怎么动、按下之后调谁、怎么返回」是两件事（同
## [code]deck_editing_view.gd[/code] 的拆因）。[br]
## [br][b]为什么必须有这件事[/b]：卡牌模板由 [code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 分批装载（每帧 10 个），而卡组编辑界面
## [code]_ready[/code] 只刷一次。装载完成前右栏会按 [code]DeckViewRows[/code] 的
## 「取不到模板就不出行」少几张——界面上此后[b]再没有任何东西[/b]会触发第二次刷新，
## 那几行永远缺着，而统计行照样写着「卡组 6/20」：行数口径与屏幕内容从此分叉，
## 玩家看到的是一份少了几行的卡组。[br]
## [br][b]为什么是信号而不是每帧轮询[/b]：装载完成是[b]一次事件[/b]不是一种状态——
## 轮询要在 [code]_process[/code] 里一直问「好了没」，白烧帧；[code]templates_loaded[/code]
## 只在装载收尾时来一次。[br]
## [br][b]为什么允许改接[/b]：卡牌系统是注入的，注入可能晚于第一次接线
## （[code]_ready[/code] 那一刻 [member DeckEditingScreen.card_system] 未必已赋好）
## ——[method watch] 因此在每次刷新时都被调用一次：同一个卡牌系统不重复接，
## 换了一个则把旧线拆掉再接到新的那一个上。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不读卡组、不读收藏、不写任何域——
## 它只知道「谁在装载」「装载完了该喊谁」。
##
## 来源: [code]card_system.gd[/code] 的 [signal CardSystem.templates_loaded]、
## [code]deck_view_rows.gd[/code] 的「取不到就不出行」口径、ADR-0031 §2、
## 先例 [code]deck_editing_view.gd[/code]（同界面的另一处拆层）。

## 模板装载完成信号名（与 [code]card_system.gd[/code] 声明的那一个同字面量）。
const SIGNAL_TEMPLATES_LOADED: StringName = &"templates_loaded"

## 已接线的卡牌系统（null = 还没接上；同一个再传进来不重复接）。
var _watched: Node = null
## 装载完成的回调 [code]func() -> void[/code]（界面传它的 [method refresh]）。
var _on_ready: Callable = Callable()


## 接上「模板装载完成」——同一个卡牌系统只接一次，换了则改接新的那一个。[br]
## [br][param p_cards] 卡牌系统（null / 无该信号 / 已有节点在守时按情况跳过）。[br]
## [br][param p_on_ready] 装载完成时调用的回调 [code]func() -> void[/code]。[br]
## [br][b]返回[/b]：本次是否建立了新接线（重复调用返回 false——调用方据此不必重复记账）。
func watch(p_cards: Node, p_on_ready: Callable) -> bool:
	if p_on_ready.is_valid():
		_on_ready = p_on_ready
	if p_cards == null or p_cards == _watched:
		return false
	if not p_cards.has_signal(SIGNAL_TEMPLATES_LOADED):
		return false
	_release()
	_watched = p_cards
	p_cards.connect(SIGNAL_TEMPLATES_LOADED, _on_templates_loaded)
	return true


## 拆线（界面离屏时调用——信号持有的是本对象，不拆会在界面释放后仍被卡牌系统引用）。[br]
## [br][b]不拆也不崩但会漏**：卡牌系统是 Autoload、活得比界面久，装载完成时它照样
## 会发信号；回调指向的界面若已释放，[method Object.call] 那一步会被引擎拦下
## （悬空 [Callable] 不报错）——但守望对象自己就成了白拿着的引用。拆掉更干净。
func release() -> void:
	_release()
	_on_ready = Callable()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 装载完成——喊一次回调（回调自己决定要不要重刷）。
func _on_templates_loaded(_count: int) -> void:
	if _on_ready.is_valid():
		_on_ready.call()


## 断开与当前卡牌系统的接线（没有接线时为空操作）。
func _release() -> void:
	if _watched == null:
		return
	if is_instance_valid(_watched) and _watched.has_signal(SIGNAL_TEMPLATES_LOADED) \
			and _watched.is_connected(SIGNAL_TEMPLATES_LOADED, _on_templates_loaded):
		_watched.disconnect(SIGNAL_TEMPLATES_LOADED, _on_templates_loaded)
	_watched = null
