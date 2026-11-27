extends RefCounted
## IdentitySelectIntent —— 「这次进身份选择页要不要强制走选择流程」的跨场景意图。[br]
## [br][b]为什么需要[/b]：身份选择场景挂载时会读 [code]IdentitySelectionSystem.is_identity_selected()[/code]，
## 已选过就[b]跳过整个选择 UI[/b] 直奔探索（读档跳过路径，见
## [method IdentitySelectNav.is_skip_needed]）。但「主菜单 → 新游戏」在同一个进程里
## （玩家从游戏里退回主菜单再点新游戏，或存档里已有 identity_id）会因为同一条判据被整体跳过，
## 表现成「点新游戏直接跳到选地图」——听风 2026-11-27 报的 bug。[br]
## [br][b]口径[/b]：新游戏 = 重新选身份，与「读档续玩」分道；发起方（主菜单）只放一份
## [b]一次性意图[/b]，不写任何游戏状态（ADR-0031 §2 零状态所有权）。[br]
## [br][b]一次性[/b]：[method take_force_show] 取走即清——转场完成后不会残留到下一次
## 从别处进入身份选择页（那条路该继续走跳过判定）。[br]
## [br]来源: ADR-0031 §2、ADR-0005（导航唯一入口）、design/gdd/main-menu-system.md
## （新游戏 / 继续游戏 / 读档三条路径）、design/gdd/game-state-manager.md §343
## （身份选择是进入探索前的必选步骤）。

## 待消费的意图（true = 下次进入身份选择页必须渲染选择 UI）。
static var _force_show: bool = false


## 请求「下次进身份选择页必须渲染选择 UI」——主菜单「新游戏」点击时调用。[br]
## [br][b]不在这里导航[/b]：导航仍由调用方经 SceneManager 发起（ADR-0005）。
static func request_force_show() -> void:
	_force_show = true


## 取走本次意图（取后清空——见文件头「一次性」）。[br]
## [br][b]返回[/b]：true = 必须渲染选择 UI；false = 没有意图，按读档跳过判据走。
static func take_force_show() -> bool:
	var value: bool = _force_show
	_force_show = false
	return value


## 清空意图（不消费地丢弃——测试隔离用）。
static func clear() -> void:
	_force_show = false


## 当前是否有待消费意图（只读查询，不消费）。
static func has_pending() -> bool:
	return _force_show
