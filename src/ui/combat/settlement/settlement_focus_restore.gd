class_name SettlementFocusRestore
extends RefCounted
## SettlementFocusRestore —— 结算面板族开合时的焦点记忆窗口（拆分自 settlement_host）。[br]
##
## [b]职责[/b]：替宿主记住「面板打开前焦点在哪」，并在面板关闭后把它还回去——
## [method remember] 在开面板前喊一声，[method restore] 在关闭出口上还回去；
## 没注入记忆实例时两者都是空操作。[br]
## [b]不管什么[/b]：记忆的实现（[code]CombatFocusMemory[/code]）不归本件，
## 也不决定「关闭出口接在哪」——它只是宿主的一个可空依赖。[br]
## [br][b]为什么单独成文件[/b]：这两件事加上注入/探针共四个方法，是宿主里唯一
## 「每个打开路径都要喊一声、每个关闭路径都要还一次」的横切关注点；
## [code]settlement_host.gd[/code] 挤在一起时超出 300 行软上限（编码标准）。[br]
## [br][b]为什么记在宿主这一层[/b]：弹窗自己不知道「打开它的是谁」——撤退弹窗有两个
## 入口（右上角按钮 / 战斗系统的撤退请求），战利品面板由战斗结束信号打开；
## 「打开前焦点在哪」只有宿主看得到。[br]
## [br][b]为什么必须还原[/b]：不还原的话，玩家取消一次撤退确认之后焦点会跳到默认焦点
## （第一张手牌），每开一次面板就丢一次位置——手柄玩家尤其明显。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：焦点是引擎的状态，本件只转达
## 「记住 / 还回去」两个动作，不自己存控件引用。
##
## 来源: combat-ui-layout Story 004（弹窗关闭后焦点回原处）、
## 拆分自 settlement_host（行数预算）。

## 键盘/手柄焦点记忆（由场景挂载侧注入一个共享实例——整场战斗只有一份）。[br]
## [br][b]为什么由外部注入[/b]：行囊面板挂在战场根上、不归宿主，但它开合同样要还焦点
## ——两处分头记会把彼此的位置覆盖掉，故整场战斗只有一份记忆；而它的兜底（默认焦点）
## 由交互接线在建立时注册，两件东西的装配点都在场景挂载侧。
var _memory: RefCounted = null


## 开弹窗之前记下当前键盘/手柄焦点。[br]
## [br][b]记忆缺失时静默跳过[/b]：headless 单测里宿主不入树，焦点本就无从谈起。
func remember() -> void:
	if _memory != null:
		_memory.call(&"remember_current")


## 面板关闭后把焦点还给打开前的控件（还不了则落链注册的兜底默认焦点）。[br]
## [br][b]三条路径共用一个出口[/b]：战利品面板（含战败返回）、撤退确认、渡劫警示
## 各自在关闭时发信号到这里——一处实现，不必在每块面板里各写一遍。
func restore() -> void:
	if _memory != null:
		_memory.call(&"restore")


## 注入共享的焦点记忆（场景挂载侧在建完焦点链后调用一次）。
func set_memory(p_memory: RefCounted) -> void:
	_memory = p_memory


## 焦点记忆实例（未注入为 null——测试探针）。
func memory() -> RefCounted:
	return _memory
