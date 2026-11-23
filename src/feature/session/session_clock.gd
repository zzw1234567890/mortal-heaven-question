extends Node
## SessionClock —— 「这一局已游玩多久」的唯一计时器与唯一写入点（Autoload）。[br]
##
## [b]职责[/b]：每帧把真实推进的时长累加进 [code]GameStateManager.session.playtime_seconds[/code]
## ——该字段就是全库「已游玩时长」的[b]唯一数据源[/b]。三条读它的路径（自动存档的
## 槽位元信息、暂停菜单手动存档的槽位元信息、存档容器顶层的 [code]playtime_seconds[/code]）
## 因此天然同源，不存在第二份计数。[br]
## [br][b]为什么需要它[/b]：这个字段此前三方皆缺——没有任何一处写入它，于是存档容器里
## 恒为 0、meta.json 里恒为 0，主菜单摘要行永远写「游玩 0小时0分」。玩家看到的是
## 「我的存档好像没生效」。[br]
## [br][b]为什么用累加 delta 而不是 [code]Time.get_ticks_msec()[/code][/b]：后者的语义是
## 墙上时钟（挂起、最小化、暂停菜单、断点调试全算进去），而这里要的是「玩家真的在玩
## 了多久」；累加 delta 拿到的正是「这一帧游戏推进了多少」。详见
## [code]SessionClockRules[/code] 的类文档（判定与算术都在那里）。[br]
## [br][b]为什么本类不缓存总数[/b]：每次落盘只做
## [code]GSM 现值 + 本次整秒数[/code]，从不持有「我知道了多久」这份副本。
## 于是[b]读档续算无需任何额外接线[/b]——读档把 GSM 的值改写为存档里的基线
## （见 [method SaveLoadSystem.load_game]），下一个整秒自然从基线往上加；
## 也不会出现「计时器记 500、存档写 300」这种两份真理。[br]
## [br][b]暂停不计入[/b]（GDD achievement-system.md §ach_speed_run「playtime_seconds 不含
## 暂停/菜单/加载时间」的暂停那一段）：判定在 [method SessionClockRules.should_accumulate]。
## 引擎在 [code]SceneTree.paused[/code] 时本就不给默认 [code]process_mode[/code] 的节点
## 投递 [code]_process[/code]，那一判是第二道防线——场景若把自己设成
## [code]PROCESS_MODE_ALWAYS[/code]，只有它能挡住「开着暂停菜单时长还在涨」。[br]
## [br][b]测试接缝[/b]：[method advance] 是公开的——用例直接喂固定 delta，不必等真实帧、
## 不必暂停整棵测试树。[br]
## [br]来源: design/gdd/save-load-system.md §存档容器、design/gdd/achievement-system.md §ach_speed_run、
## ADR-0031 §Logic 内核（判定归 [SessionClockRules]）。

## 计时内核（纯函数——可零依赖单测）。
const Rules := preload("res://src/feature/session/session_clock_rules.gd")
## 存档域里的键名（与 [code]SaveLoadSystem._build_save_container[/code]、
## [code]SaveAutoSave.build_meta[/code] 读的是同一个键）。
const KEY_PLAYTIME: String = "playtime_seconds"

## 累计的不足一秒零头（跨帧凑整；读档时清零——见 [method _on_load_completed]）。
var _remainder_sec: float = 0.0


func _ready() -> void:
	name = "SessionClock"
	# 读档成功后把零头清零：存档里的基线是整秒，零头若留着会把「读档前那不到一秒」
	# 加到新基线上（差一秒的事，但「基线 + Δ」这条口径要逐位成立）。
	var sls: Node = _get_autoload(&"SaveLoadSystem")
	if sls != null and sls.has_signal(&"load_completed"):
		sls.connect(&"load_completed", _on_load_completed)


func _process(delta: float) -> void:
	advance(delta)


## 累加一段时长（[method Node._process] 的转发目标——也是测试的确定性接缝）。[br]
## [br][param delta] 本帧 / 本次的时长（秒）。[br]
## [br][b]返回[/b]：本次真正写进 GSM 的整秒数（0 = 没凑满一秒或暂停中）。[br]
## [br][b]暂停中直接返回[/b]：不累零头——暂停期间的时长在语义上不属于「游玩」，
## 记进零头会让暂停结束后凭空多出一秒。
func advance(delta: float) -> int:
	var tree: SceneTree = get_tree()
	var paused: bool = tree != null and tree.paused
	if not Rules.should_accumulate(paused):
		return 0
	var step: Dictionary = Rules.tick(_remainder_sec, delta)
	_remainder_sec = float(step["remainder"])
	var whole: int = int(step["seconds"])
	if whole <= 0:
		return 0
	return _add_seconds(whole)


## 已游玩时长（秒——[b]唯一数据源[/b]的只读窗口）。[br]
## [br][b]返回[/b]：GSM 不可用 / session 域缺席时为 0。
func seconds_played() -> int:
	var session: Variant = _session()
	if session == null:
		return 0
	return maxi(int((session as Dictionary).get(KEY_PLAYTIME, 0)), 0)


## 清零不足一秒的零头（读档后由 [signal SaveLoadSystem.load_completed] 触发）。[br]
## [br][b]为什么公开[/b]：它是「读档续算逐位成立」这条口径的可见动作，测试直接断言它。
func reset_remainder() -> void:
	_remainder_sec = 0.0


## 当前零头（探针——只读）。
func remainder() -> float:
	return _remainder_sec


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 把整秒加到 GSM 现值上并写回。[br]
## [br][b]就地改字典而不是 [code]gsm.session = 新字典[/code][/b]：session 是
## 引用类型，就地写不会换掉整个域对象（与 [code]scene_transition.gd[/code] 写
## [code]gsm.session.current_scene[/code] 同一形态）。[br]
## [br][b]不发射信号[/b]：该字段只被「存档那一刻」读一次，没有订阅者——
## 每写一次就走一趟信号缓冲纯属浪费。读档基线由 [method SaveLoadSystem.load_game]
## 直写，两处都不经信号。
func _add_seconds(seconds: int) -> int:
	var session: Variant = _session()
	if session == null:
		return 0
	var dict: Dictionary = session
	dict[KEY_PLAYTIME] = maxi(int(dict.get(KEY_PLAYTIME, 0)), 0) + seconds
	return seconds


## GSM 的 session 域（不可用 / 不是字典时 null——头无头单测与替身都能安全走过）。
func _session() -> Variant:
	var gsm: Node = _get_autoload(&"GameStateManager")
	if gsm == null:
		return null
	var session: Variant = gsm.get(&"session")
	if session is Dictionary:
		return session
	return null


## 读档完成——成功才清零头（失败时基线没变，零头留着继续凑）。
func _on_load_completed(success: bool) -> void:
	if success:
		reset_remainder()


## 经 SceneTree Autoload 查找（同 [code]SaveAutoSave._get_gsm[/code] 口径——
## 不用全局名，避免测试环境无 Autoload 时崩）。
func _get_autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("/root/" + str(node_name)))
