class_name SessionClockRules
extends RefCounted
## SessionClockRules —— 「已游玩时长」累加的纯判定与纯算术（[SessionClock] 的 Logic 内核）。[br]
##
## [b]职责[/b]：只回答两件事——「这一帧该不该计时」与「累加到多少整秒」。
## 不碰场景树、不碰 GSM、不认识任何 Autoload（可零依赖单测）。[br]
## [br][b]为什么单独成文件[/b]：计时的两处最容易写错的地方都在这里——[br]
##   · [method should_accumulate]：[code]SceneTree.paused[/code] 期间不计入
##     （GDD achievement-system.md「playtime_seconds 不含暂停/菜单/加载时间」的
##     暂停那一段）。判定抽出来，测试不必真去暂停整棵测试树；[br]
##   · [method tick]：帧时长是 float，而存档里的 [code]playtime_seconds[/code] 是整秒
##     ——把「若干帧的零头凑成整秒」做成纯函数，测试用固定 delta 反复调即可，
##     不依赖真实等待。[br]
## [br][b]为什么用 [code]_process(delta)[/code] 累加而不读 [code]Time.get_ticks_msec()[/code]：
## 后者给的是墙上时钟，与「玩家真的在玩」无关——挂起、最小化、暂停菜单、调试断点全都会
## 被算进去，而且读档 / 新开局都要额外记一个起点、每次重算差值。累加 delta 的语义就是
## 「这一帧游戏真的推进了多少」；暂停时引擎本就不投递 [code]_process[/code]（本类仍
## 显式判一次，为什么见 [method should_accumulate]）；读档续算只是把基线写回 GSM
## （[code]SaveLoadSystem.load_game[/code] 反序列化 session 域即成基线，
## [code]SessionClock[/code] 不缓存总数）——没有第二套重算口径。[br]
## [br][b]零状态[/b]（ADR-0031 Logic 内核模式）：无成员变量、全部 static、确定映射。
##
## 来源: design/gdd/save-load-system.md §存档容器（playtime_seconds）、
## design/gdd/achievement-system.md §ach_speed_run、ADR-0031 §Logic 内核。

## 不足 1 分钟时的时长文案（[method format_duration] / [method format_playtime] 共用）。
const TEXT_SUB_MINUTE: String = "不到 1 分钟"
## 一分钟以内的阈值（秒）——小于它时展示层不用「X小时Y分」。
const SUB_MINUTE_SEC: int = 60
## 一小时（秒）——展示层拆「X小时Y分」用。
const SECONDS_PER_HOUR: int = 3600
## 一分钟（秒）。
const SECONDS_PER_MINUTE: int = 60


## 这一帧是否该把时长计入。[br]
## [br][param p_paused] 整棵场景树是否处于暂停（暂停菜单打开时为 true）。[br]
## [br][b]返回[/b]：暂停中不计（[code]false[/code]），其余计（[code]true[/code]）。[br]
## [br][b]为什么暂停要显式判一次[/b]：暂停时 Godot 本就不给 [code]_process[/code]
## 投递帧（默认 [code]process_mode[/code]），实现里那一判是[b]第二道防线[/b]——
## 场景若把自己的 [code]process_mode[/code] 设成 [code]ALWAYS[/code]（HUD 一类常驻
## 节点常这么干），引擎照投，只有这一判能挡住「开着暂停菜单时长还在涨」。[br]
## [br][b]为什么只判暂停[/b]：「已开局了吗」与主菜单 / 加载期的排除都要场景知识，
## 而新开局并不重置 session——本轮只固化这条有明确判据、有 GDD 依据的规则；
## 主菜单停留时间是否计入登记在案（见汇报「遗留」）。
static func should_accumulate(p_paused: bool) -> bool:
	return not p_paused


## 累加一帧时长并把零头凑成整秒。[br]
## [br][param p_accum_sec] 上一帧留下的零头（秒，负数按 0 处理）。[br]
## [br][param p_delta_sec] 本帧时长（秒，负数按 0 处理——引擎给的 delta 恒为正，
## 此钳制只为「调用方传了怪值」时不倒扣时长）。[br]
## [br][b]返回[/b]：[code]{seconds: int, remainder: float}[/code]——本次可写入的整秒数与
## 不足一秒的零头（零头由调用方留存，下一帧继续凑）。[br]
## [br][b]为什么不当场写 float 进 GSM[/b]：存档容器里的 [code]playtime_seconds[/code] 是
## 整数秒（[code]SaveLoadSystem._build_save_container[/code] 口径），主菜单文案也按整秒
## 取整——存一个每帧都在动的小数没有消费者，还会让「读出来的数」与「存下去的数」
## 逐帧不等。
static func tick(p_accum_sec: float, p_delta_sec: float) -> Dictionary:
	var total: float = maxf(p_accum_sec, 0.0) + maxf(p_delta_sec, 0.0)
	var whole: int = int(floor(total))
	return {"seconds": whole, "remainder": total - float(whole)}


## 秒数 → 「X小时Y分」文本（[b]向下取整到分钟[/b]；不足 1 分钟走
## [constant TEXT_SUB_MINUTE]）。[br]
## [br][param p_seconds] 已游玩秒数（负数钳 0——meta 损坏防御）。[br]
## [br][b]返回[/b]：形如 [code]2小时3分[/code]；[code]< 60[/code] 秒时返回
## [constant TEXT_SUB_MINUTE]。[br]
## [br][b]为什么零也要走「不到 1 分钟」[/b]：0 秒与 59 秒对玩家是同一件事——「刚存了一档」
## 与「玩了半分钟」的差别不在数字上，而写「0小时0分」反倒像存档没生效（真机走查的
## 第一反应正是「主菜单恒显示 0小时0分，以为档没存上」）。
static func format_duration(p_seconds: int) -> String:
	var safe: int = maxi(p_seconds, 0)
	if safe < SUB_MINUTE_SEC:
		return TEXT_SUB_MINUTE
	var hours: int = safe / SECONDS_PER_HOUR
	var minutes: int = (safe % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
	return "%d小时%d分" % [hours, minutes]


## 「游玩」+ 时长（摘要行后半句——[method MainMenuLogic.build_save_summary] 消费）。[br]
## [br][b]为什么整句一起出而不是拼前缀[/b]：不足 1 分钟时中文写「游玩不到 1 分钟」
## （中间没有空格），够 1 分钟时写「游玩 2小时3分」（中间有空格）——「要不要空格」
## 是这条规则的一部分，拆成两处必然在某一侧写错。
static func format_playtime(p_seconds: int) -> String:
	if maxi(p_seconds, 0) < SUB_MINUTE_SEC:
		return "游玩" + TEXT_SUB_MINUTE
	return "游玩 " + format_duration(p_seconds)
