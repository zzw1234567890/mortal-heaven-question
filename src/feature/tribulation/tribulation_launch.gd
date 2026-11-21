extends RefCounted
## TribulationLaunch —— 渡劫入口的[b]共用件[/b]：两个入口（修炼室 / 探索节点图）调同一段顺序。[br]
## [br][b]为什么必须有这一处[/b]：渡劫有两条玩家入口，但只有一份正确的调用顺序——
## 先 [code]TribulationSystem.trigger_tribulation[/code] 把状态机推进 [code]PREPARING[/code]，
## 再请求转往渡劫场景。渡劫场景进战时 [code]start_tribulation_combat[/code] 会校验这个
## 状态，反过来做（先转场、不触发）就会降级成一场普通战斗：
## [code]TribulationCombat.on_battle_ended[/code] 见状态不是 [code]IN_COMBAT[/code] 直接
## return——[b]打赢了也不进境、打输了也不扣修为[/b]。探索节点图此前正是这条断链
## （只转场、从不触发），玩家从地图进渡劫是空打一场。顺序写在两处就必然有一天
## 只改对一处，故收在此处，两个入口都只调 [method launch]。[br]
## [br][b]失败一律不留残余状态[/b]：一旦进了 [code]PREPARING[/code] 却去不了渡劫场景
## （SceneManager 缺失 / 转场被并发守卫拒绝），必须用
## [code]cancel_tribulation[/code] 退回去——否则玩家被永久卡在「渡劫流程进行中」，
## 连修炼室那行按钮都再也点不动。[br]
## [br][b]文本归属[/b]：结果句放在这里而不是两个界面各写一份——同一个失败原因在两处
## 措辞必然会漂移（同 [code]cultivation_view_rules.gd[/code] 收口文案的口径）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是 static 纯函数——不读 GSM、不持节点，
## 系统引用由调用方传进；本模块只组织调用顺序并把结果讲清楚。[br]
##
## 来源: design/gdd/tribulation-system.md §1 地图渡劫点 + §2 准备阶段 + §6 越阶渡劫、
## design/gdd/cultivation-system.md §6、ADR-0021 §trigger_tribulation /
## §cancel_tribulation / §start_tribulation_combat、ADR-0031 §2。

## 枚举真理来源（TribulationType / TribulationState / 场景枚举——不写魔数）。
const TribulationScript := preload("res://src/feature/tribulation_system.gd")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 结果令牌——调用方据此分派（[code]ok[/code] 为真时只有 [constant OUTCOME_STARTED]）。
const OUTCOME_STARTED: StringName = &"started"
const OUTCOME_TRIBULATION_UNAVAILABLE: StringName = &"tribulation_unavailable"
const OUTCOME_BUSY: StringName = &"busy"
const OUTCOME_NO_SCENE_MANAGER: StringName = &"no_scene_manager"
const OUTCOME_DEPART_FAILED: StringName = &"depart_failed"

## 结果句（面向玩家——见类文档「文本归属」）。
const TEXT_STARTED: String = "已触发渡劫——前往天劫之下，胜则进境。"
const TEXT_BUSY: String = "渡劫流程进行中，先了结这一场。"
const TEXT_TRIBULATION_UNAVAILABLE: String = "渡劫系统不可用，此处暂时无法渡劫。"
const TEXT_NO_SCENE_MANAGER: String = "场景管理器不可用，暂时无法前往渡劫。"
const TEXT_DEPART_FAILED: String = "转场被拒——渡劫已取消，稍后再试。"


## 渡劫入口的唯一顺序（两个入口都走这里）。[br]
## [br][param p_tribulation_system] 渡劫系统（缺失 / 无所需方法时按不可用处理）。[br]
## [param p_scene_manager] 场景管理器（缺失时按不可用处理）。[br]
## [param p_from_scene] 源场景 ID 的[b]兜底值[/b]——SceneManager 支持
## [code]get_current_scene_id[/code] 时以实况为准（两个入口各自的当前场景不同，故由调用方给）。[br]
## [param p_cross_realm] 是否玩家主动选的越阶渡劫（默认 false——见 [method tribulation_type]）。[br]
## [br][b]返回[/b]：[code]{ok, outcome, text}[/code]；[code]ok[/code] 为真表示已受理转场请求。[br]
## [br][b]顺序[/b]：可用性 → [code]trigger_tribulation[/code] → 回读状态必须进
## [code]PREPARING[/code] → 取当前场景 → [code]request_scene_change[/code]；
## 后三步任何一步失败都收尾（[code]cancel_tribulation[/code]）。[br]
## [br][b]回读状态而不是假定成功[/b]：触发会被状态机自己拒绝（修为未满 / 已 3 次失败前的
## 越阶越界等），不看返回值就发「已前往渡劫」是谎报。[br]
static func launch(p_tribulation_system: Node, p_scene_manager: Node,
		p_from_scene: int, p_cross_realm: bool = false) -> Dictionary:
	if not usable(p_tribulation_system):
		return _outcome(false, OUTCOME_TRIBULATION_UNAVAILABLE)
	p_tribulation_system.call(&"trigger_tribulation", tribulation_type(p_cross_realm))
	if state_of(p_tribulation_system) != TribulationScript.TribulationState.PREPARING:
		# 状态机拒绝了这次触发（修为未满 / 越阶越界）——不谎报，也不留残余。
		return _outcome(false, OUTCOME_BUSY)
	if p_scene_manager == null or not p_scene_manager.has_method(&"request_scene_change"):
		cancel_quietly(p_tribulation_system)
		return _outcome(false, OUTCOME_NO_SCENE_MANAGER)
	var from_id: int = p_from_scene
	if p_scene_manager.has_method(&"get_current_scene_id"):
		from_id = int(p_scene_manager.call(&"get_current_scene_id"))
	var accepted: bool = bool(p_scene_manager.call(&"request_scene_change", from_id,
			SceneManagerScript.SceneID.TRIBULATION,
			SceneManagerScript.TransitionType.TRIBULATION))
	if not accepted:
		# 并发守卫拒了转场——已进 PREPARING 却去不了，必须退回去。
		cancel_quietly(p_tribulation_system)
		return _outcome(false, OUTCOME_DEPART_FAILED)
	return _outcome(true, OUTCOME_STARTED)


## 渡劫类型单点——[b]什么时候发 [code]CROSS_REALM[/code][/b]。[br]
## [br]GDD tribulation-system.md §1/§6：越阶渡劫[b]不是默认路径[/b]，是玩家在渡劫台上
## 主动选的选项（「玩家主动选择『越阶渡劫』选项（非默认）」），条件为「当前境界修为已全满
## + 下一大境界的天劫 Boss 已配置」；且不能跳阶（炼气最多渡筑基劫）。因此本函数只看
## 一件事：玩家有没有主动选。其余条件（修为是否已满、境界是否越界）由
## [code]TribulationSystem.trigger_tribulation[/code] 自己校验——本模块不代它判，避免
## 同一条规则写两遍。[br]
## [br][b]当前两个入口都传 false[/b]（修炼室那行按钮与节点图渡劫台按钮给的都是默认
## 正常渡劫）；越阶选项落到界面上时，把玩家的选择透传进来即可，顺序与收尾都不用动。[br]
static func tribulation_type(p_cross_realm_requested: bool) -> int:
	if p_cross_realm_requested:
		return TribulationScript.TribulationType.CROSS_REALM
	return TribulationScript.TribulationType.NORMAL


## 渡劫系统是否真的能用（触发 + 查状态两个方法齐备——拿得到对象不等于它能干活）。[br]
## [br][b]判的是能力不是存在[/b]：桩替身 / 半个系统都可能是非 null。判不过时调用方
## [b]不得发转场[/b]——玩家点了没反应比一句可读的降级文案糟得多。[br]
## [br][b]为什么只查这两个方法[/b]：这与修炼室判定层原有的口径一致
## （[code]cultivation_actions._is_tribulation_usable[/code]）——多查一个方法会把
## 「能干活但缺收尾」的系统判成不可用，反而挡住正常路径；缺
## [code]cancel_tribulation[/code] 时 [method cancel_quietly] 自己会静默跳过。[br]
static func usable(p_tribulation_system: Node) -> bool:
	return p_tribulation_system != null \
			and p_tribulation_system.has_method(&"trigger_tribulation") \
			and p_tribulation_system.has_method(&"get_tribulation_status")


## 当前渡劫状态（读不到时按 [code]NOT_READY[/code]——调用方已先过 [method usable]）。
static func state_of(p_tribulation_system: Node) -> int:
	if p_tribulation_system == null \
			or not p_tribulation_system.has_method(&"get_tribulation_status"):
		return TribulationScript.TribulationState.NOT_READY
	var raw: Variant = p_tribulation_system.call(&"get_tribulation_status")
	if not (raw is Dictionary):
		return TribulationScript.TribulationState.NOT_READY
	return int((raw as Dictionary).get("state", TribulationScript.TribulationState.NOT_READY))


## 退回准备阶段（失败收尾——见类文档；失败本身不影响回执，故不向外报错）。
static func cancel_quietly(p_tribulation_system: Node) -> void:
	if p_tribulation_system != null and p_tribulation_system.has_method(&"cancel_tribulation"):
		p_tribulation_system.call(&"cancel_tribulation")


## 组装结果（字段名唯一出处——调用方按名取，不按下标）。
static func _outcome(p_ok: bool, p_outcome: StringName) -> Dictionary:
	return {"ok": p_ok, "outcome": p_outcome, "text": text_for(p_outcome)}


## 结果对应的中文句（结果令牌 → 文本的唯一映射）。
static func text_for(p_outcome: StringName) -> String:
	match p_outcome:
		OUTCOME_STARTED:
			return TEXT_STARTED
		OUTCOME_BUSY:
			return TEXT_BUSY
		OUTCOME_NO_SCENE_MANAGER:
			return TEXT_NO_SCENE_MANAGER
		OUTCOME_DEPART_FAILED:
			return TEXT_DEPART_FAILED
		_:
			return TEXT_TRIBULATION_UNAVAILABLE
