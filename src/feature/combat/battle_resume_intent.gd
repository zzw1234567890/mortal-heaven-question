extends RefCounted
## BattleResumeIntent —— 「这次进战斗是去接着打」的跨场景意图（RefCounted 静态类）。[br]
## [br][b]为什么需要[/b]：战斗场景是「探索点进战斗」与「读档回到战斗」两条路径的共同
## 终点，而它挂载那一刻无从分辨自己是被谁叫来的——[br]
##   · [b]探索进来[/b]：备战面板预选玩家阵容，等玩家点「确认出战」；[br]
##   · [b]读档续战[/b]：玩家要的是[b]接着打[/b]，停在备战面板等于让他从头布阵，
##     而刚读回来的 HP / 回合 / 费用都已经在存档里。[br]
## 读档侧（主菜单 / 暂停菜单共用 [code]main_menu_launch.gd[/code]）在导航前把
## 存档里那段状态留在这里，战斗场景 [code]_ready[/code] 取走。[br]
## [br][b]一次性[/b]：[method take] 取走即清——同一份意图不会让玩家续战两次，
## 也不会残留到「下一次从探索点进战斗」时冒出来（那会让一场全新的仗带着上一场的残血
## 开打）。[br]
## [br][b]为什么不复用 [code]CombatLaunchContext[/code][/b]：那份持有的是「这一场打
## 谁、给什么」的四份输入，随开战一次性消费（[method take] 后清空）；续战快照要在开战
## [b]之后[/b]才用得上（HP / 阶段要写进已经种子好的状态表），生命周期不同。[br]
##
## 来源: ADR-0005（导航唯一仲裁）、ADR-0031 §2 零状态所有权、
## [code]battle_resume_payload.gd[/code] §「能不能回到这场战斗」。

## 载荷模块（可续性判定的唯一真理来源）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")

## 待消费的续战快照（空 = 没有——正常开战路径）。
static var _payload: Dictionary = {}


## 留下「这次进战斗是接着打」的意图——读档成功后调用。[br]
## [br][b]不可续的载荷一律丢弃[/b]（[method PayloadScript.is_resumable_payload]）：
## 宁可不留意图（玩家落到探索地图），也不要把战斗场景引到一场判不出胜负的仗里。
## [br][br][b]返回[/b]：是否真的登记了（调用方据此决定导航目标）。
static func request(p_payload: Dictionary) -> bool:
	if not PayloadScript.is_resumable_payload(p_payload):
		_payload = {}
		return false
	_payload = p_payload.duplicate(true)
	return true


## 取走续战快照（取后清空——见文件头「一次性」）。
static func take() -> Dictionary:
	var payload: Dictionary = _payload
	_payload = {}
	return payload


## 查看当前待消费的意图（测试/预览用——不消费）。
static func peek() -> Dictionary:
	return _payload.duplicate(true)


## 当前是否有待消费的意图（只读查询，不消费）。
static func has_pending() -> bool:
	return not _payload.is_empty()


## 清空意图（不消费地丢弃——测试隔离与「中途放弃」路径用）。
static func clear() -> void:
	_payload = {}
