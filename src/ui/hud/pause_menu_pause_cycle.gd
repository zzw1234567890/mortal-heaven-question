extends RefCounted
## PauseMenuPauseCycle —— 暂停菜单的[b]开合配对内核[/b]（从 [PauseMenu] 拆出）。[br]
## [br][b]为什么单独一处[/b]：[code]pause_menu.gd[/code] 越过 300 行软上限
## （.claude/docs/coding-standards.md），而「锁怎么压/怎么弹、什么时候冻结场景树、
## 模糊动画怎么起停」与「按钮怎么摆、动作怎么编排」是两件事（同
## [code]pause_menu_actions.gd[/code] / [code]pause_menu_state.gd[/code] 的拆因）。[br]
## [br][b]顺序是本模块唯一的知识[/b]（ADR-0031 §1.1——开合严格配对）：[br]
##   打开 = [code]InputManager.push_lock(MODAL)[/code] → [code]SceneTree.paused = true[/code]
##   → [code]adapter.suspend()[/code] → 显示（0.3s 模糊动画）。[br]
##   关闭 = 收模糊 Tween → 复位模糊 → [code]adapter.resume()[/code] →
##   [code]SceneTree.paused = false[/code] → 隐藏 → [code]pop_lock[/code]
##   （[b]pop 锁在最后[/b]——顺序反了会出现「还没恢复就被下层吃掉输入」的中间态）。[br]
## [br][b]为什么必须配对[/b]：漏一次 pop，输入再也回不来（玩家被卡在关不掉的菜单里）；
## 多一次 push，锁栈累积到后面的模态认不出自己那把。两者都表现为「一次莫名其妙的
## 卡死」，且症状出现在几步之后——所以这五步写在同一个方法里，调用方无从拆错。[br]
## [br][b]树变认领也归这里[/b]（[method reclaim_lock_if_owner]）：[code]InputManager[/code]
## 对 [code]SceneTree.tree_changed[/code] 挂了一张「场景切换就清锁」的安全网，而它
## 分不清「换场景」与「同一场景里插了个子节点」——暂停期间必然有树变（本菜单自己
## 插读档/卡组面板、通知区域弹 Toast）。锁一没，「暂停中屏蔽下层输入」与 ESC
## owner-check 同时失效。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只做动作，不读也不写玩法数据——
## 模糊强度是纯视觉量，[code]paused[/code] / 锁栈是引擎与 InputManager 的状态。[br]
## [br]来源: ADR-0031 §1.1（开合配对）、design/ux/pause-menu.md（过渡表「打开 0.3s」）、
## hud Story 005、code-review T-1/G-3/B-3。

## 宿主（[PauseMenu] 本体——模糊控件、场景树与 adapter 的来源）。
var _host: Control = null
## 模糊遮罩矩形（模糊强度写在它的 shader 参数上）。
var _blur_rect: ColorRect = null
## 模糊动画时长（由宿主下发——[code]PauseMenu.BLUR_DURATION[/code] 是真理来源）。
var _blur_duration: float = 0.0
## MODAL 锁 source（由宿主下发——[code]PauseMenu.LOCK_SOURCE[/code] 是真理来源，
## 本模块不抄第二份字面量：两处一旦漂移，pop 就找不到 push 的那把锁）。
var _lock_source: StringName = &""
## 活跃模糊 Tween 引用——重开/关闭时 kill 防悬挂回调（code-review T-1）。
var _blur_tween: Tween = null


## 绑定宿主与模糊控件（宿主 [code]_ready[/code] 后调一次；重复调用覆盖）。[br]
## [br][b]为什么控件由宿主传进来[/b]：[code]@onready[/code] 路径引用只在宿主里写
## 一次，本模块不必再抄一份控件路径（路径一改就会漏改一处）。
func bind(p_host: Control, p_blur_rect: ColorRect, p_blur_duration: float,
		p_lock_source: StringName) -> void:
	_host = p_host
	_blur_rect = p_blur_rect
	_blur_duration = p_blur_duration
	_lock_source = p_lock_source


## 打开序列——压 MODAL 锁 → 冻结场景树 → 暂停音频 → 播模糊动画。[br]
## [br][b]幂等守卫在调用方[/b]（[code]PauseMenu.request_open[/code]）：重复打开会
## 把锁栈压成两层，那是行为分叉，不该由本模块猜「你是不是又开了一次」。[br]
## [br][b]冻结先于 suspend[/b]：adapter 内部若走 Tween/计时器，冻结后它仍能跑完
## （音频节点在 PersistentLayer 上、不受 [code]paused[/code] 影响），顺序不影响
## 结果——但「先僵住玩家能做的、再处理听得到的」读起来最清楚。
func acquire() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	InputManager.push_lock(InputManager.LockType.MODAL, _lock_source)
	_host.get_tree().paused = true
	var adapter: Variant = _host.get("audio_adapter")
	if adapter != null:
		adapter.call(&"suspend")
	_host.set("visible", true)
	if bool(_host.get("animate")):
		_play_blur(1.0)


## 关闭序列（严格逆序——pop 锁在最后）。[br]
## [br][b]Tween 一并清理[/b]：HUD 跨场景存续，悬挂的 tween 会在新场景里继续跑完
## 0.3s（模糊还没复位就已经在淡出了）。[br]
## [br][b]幂等守卫在调用方[/b]（[code]PauseMenu.request_close[/code]）：未打开时
## pop 锁会打日志并命中 InputManager 的「source not found」警告路径。[br]
## [br][b]覆盖层收起不在这里[/b]：确认框、读档面板、卡组面板归各自的编排层——
## 宿主在调本方法前后自行收拾（见 [code]PauseMenu._release_pause] 的顺序注记）。
func release() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_stop_blur()
	var adapter: Variant = _host.get("audio_adapter")
	if adapter != null:
		adapter.call(&"resume")
	_host.get_tree().paused = false
	_host.set("visible", false)
	InputManager.pop_lock(_lock_source)


## 树一变就回认 MODAL 锁（原因见类文档「树变认领也归这里」）。[br]
## [br][b]只在锁栈空时认领[/b]：栈非空说明另有活跃模态（转场锁、别人的弹窗），
## 此时不抢——ESC 归它（[code]PauseMenu._unhandled_input[/code] 的
## [code]has_lock[/code] 据此放行）。[br]
## [br][b]顺序确定[/b]：Autoload 的 [code]_ready[/code] 先于场景节点，InputManager
## 先清、本模块后认，故每次树变后栈深恰好回到 1（不累积）。[br]
## [br][b]菜单隐藏时不认领[/b]：否则关掉的菜单会凭空压一把锁，输入再也放不开。
func reclaim_lock_if_owner() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if not bool(_host.get("visible")) or not _host.is_inside_tree():
		return
	if InputManager.get_lock_stack().is_empty():
		InputManager.push_lock(InputManager.LockType.MODAL, _lock_source)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 停止模糊动画并把强度归零（关闭 / 重开前共用——重开从 0 起始）。[br]
## [br][b]为什么必须先 kill[/b]：上一次的 tween 还在插值，新的一次从 0 拉到 1，
## 两个 tween 同时写同一个 shader 参数——画面会在两者之间抖动（code-review T-1）。
func _stop_blur() -> void:
	if _blur_tween != null:
		_blur_tween.kill()
		_blur_tween = null
	_set_blur(0.0)


## 播一次模糊动画（0 → [param p_target]，时长由宿主下发）。[br]
## [br][b]animate == false 时走静态降级[/b]（调用方判定）：直接落终值，不建 Tween
## ——测试与 reduce-motion 偏好都靠它（同 [code]NotificationToastArea.animate[/code]
## 的先例）。
func _play_blur(p_target: float) -> void:
	_stop_blur()
	_blur_tween = _host.create_tween()
	_blur_tween.tween_method(_set_blur, 0.0, p_target, _blur_duration)


## 模糊强度设置（Tween [code]tween_method[/code] 的目标）。[br]
## [br]控件的 [code]visible[/code] 归宿主——本模块只在它可见时被调用（打开序列），
## 关闭序列则由宿主先藏后调（pop 锁在最后，模糊复位在暂停解除之前）。
func _set_blur(p_value: float) -> void:
	if _blur_rect == null or not is_instance_valid(_blur_rect):
		return
	_blur_rect.material.set(&"shader_parameter/blur_amount", p_value)
