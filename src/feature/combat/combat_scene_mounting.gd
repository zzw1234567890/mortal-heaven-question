extends RefCounted
## CombatSceneMounting —— 战斗容器的表现层装配（音频 / 面板 / 备战 / 反馈 /
## 结算回流 / 出牌交互）。[br]
## [br][b]职责[/b]：把 [code]CombatScene._ready[/code] 里的六组「装配 + 信号接线」
## 收在一处；容器只保留「先取开战上下文 → 接线 → 放行输入」的时序。[br]
## [br][b]为什么独立成文件[/b]：容器加上开战上下文消费后超出 300 行软上限，而
## 「挂哪些组件」与「什么时候开战 / 退场」是两件事（同
## [code]combat_scene_exits.gd[/code] / [code]combat_scene_battle_setup.gd[/code] 先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只持容器与战场根句柄，依赖一律经容器
## 现读；不缓存任何游戏状态。[br]
##
## 来源: ADR-0031 §1/§2、combat-ui-layout Story 001-008、Sprint 18 结算回流。

## 结算回流接线（battle_ended → CombatResultView）。

## Autoload 查找器——本模块内的查找已收拢到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")

const ResultBridgeScript := preload("res://src/ui/combat/shared/combat_result_bridge.gd")
## 出牌交互接线（输入层 + 手牌供给）。
const InteractionScript := preload("res://src/feature/combat/combat_scene_interaction.gd")
## 行囊装配（条目 → 结算 → 面板 + 入口按钮 + 出牌输入冻结）。
const BagScript := preload("res://src/feature/combat/combat_scene_bag.gd")
## 底部条牌库/弃牌计数订阅（pile_changed → DeckCounter；tech-debt DEBT-CUI-010）。
const DeckWiringScript := preload("res://src/feature/combat/combat_deck_wiring.gd")

## 容器场景（[code]combat_scene.gd[/code]——只经公开成员与公开方法交互）。
var _scene: Control = null
## 战场根（容器 [code]_ready[/code] 已挂载）。
var _root: Control = null
## 备战线是否跳过打开面板（读档续战用——[method wire_all] 前由容器置位）。[br]
## [br][b]跳过的只是「打开」[/b]：面板仍照常 setup 与接线（返回探索的出口要留着），
## 只是不弹出来问「谁上」——阵容在存档里已经回答过了。
var skip_deploy_open: bool = false


## 构造——传入容器与战场根。
func _init(p_scene: Control, p_root: Control) -> void:
	_scene = p_scene
	_root = p_root


## 装配全部接线。[br]
## [param p_deploy_confirmed] 备战面板「确认出战」处理器。[br]
## [param p_deploy_back] 备战面板「返回」处理器。[br]
## [param p_retreat] 结算宿主「撤退确认」处理器。[br]
## [param p_defeat] 结算宿主「战败确认」处理器。[br]
## [br][b]返回[/b]：[code]{result_bridge, interaction_wiring, bag_mount, deck_wiring}[/code]——容器持有
## 这四个句柄用于 [code]_exit_tree[/code] 退订（任一可空）。
## [br][b]行囊最后挂[/b]：它的面板要盖住手牌区与出牌输入层（[method wire_interaction]
## 已经把输入层挂好了），顺序反了面板会被输入层压在下面——看得见点不着。
func wire_all(p_deploy_confirmed: Callable, p_deploy_back: Callable,
		p_retreat: Callable, p_defeat: Callable) -> Dictionary:
	wire_audio()
	wire_panels()
	var deck_wiring: RefCounted = wire_deck_counts()
	wire_deployment(p_deploy_confirmed, p_deploy_back, p_retreat, p_defeat)
	wire_feedback()
	var interaction: RefCounted = wire_interaction()
	var wired: Dictionary = {
		"result_bridge": wire_result_bridge(),
		"interaction_wiring": interaction,
		"bag_mount": wire_bag(interaction),
		"deck_wiring": deck_wiring,
	}
	wire_focus_memory(interaction)
	return wired


## 音频——注入 AudioManager 并请求进入战斗音频状态（AC-7；未注入时静默跳过）。
func wire_audio() -> void:
	var sm: Node = _scene.call(&"_scene_manager")
	if sm == null or not sm.has_method(&"get_audio_manager"):
		return
	var am: Variant = sm.call(&"get_audio_manager")
	if am != null:
		_root.call(&"set_audio_manager", am)
	_root.call(&"request_in_combat_audio")


## 顶部条/底部条/手牌区信号接线（数据源现读 Autoload——缺失时静默跳过，
## 各组件自带 null 守卫）。
func wire_panels() -> void:
	var cs: Node = _combat()
	var topbar: Variant = _root.get("combat_topbar")
	if topbar != null:
		topbar.call(&"bind_signals", cs, _autoload(&"FormationSystem"))
	var bottombar: Variant = _root.get("combat_bottombar")
	if bottombar != null:
		bottombar.call(&"bind_signals", cs, _autoload(&"CostSystem"))
		bottombar.call(&"set_reduce_motion", _reduce_motion())
	var hand: Variant = _root.get("hand_area")
	if hand != null:
		hand.call(&"bind_signals", cs)
		hand.call(&"set_reduce_motion", _reduce_motion())
	# 结算/撤退/渡劫警示宿主（交接后战斗结束 → 面板；确认信号走容器出口）
	_root.call(&"setup_settlement", cs, _scene.call(&"_deck"),
			bool(_scene.get("is_tribulation")))
	if bool(_scene.get("is_tribulation")):
		_root.call(&"show_pre_battle_warning")


## 备战面板——注入依赖、下发名册并打开，接上四个出口信号。[br]
## [br][b]预选[/b]：探索侧带来的玩家阵容在面板打开后由容器点选。[br]
## [br][b]续战时只接线不开面板[/b]（[member skip_deploy_open]）：出口信号照接，
## 但不去问玩家「谁上」——那盘棋已经在存档里下到一半了。
func wire_deployment(p_deploy_confirmed: Callable, p_deploy_back: Callable,
		p_retreat: Callable, p_defeat: Callable) -> void:
	var deploy: Variant = _root.get("deploy_panel")
	if deploy == null:
		return
	deploy.call(&"setup", _autoload(&"GameStateManager"), _autoload(&"CardSystem"),
			_deployment_system(), _autoload(&"BindingManager"))
	deploy.connect(&"confirm_requested", p_deploy_confirmed)
	deploy.connect(&"back_requested", p_deploy_back)
	if not skip_deploy_open:
		_root.call(&"show_deploy_panel", _scene.call(&"_max_deploy"),
				_scene.call(&"_realm_id"), _scene.call(&"_deploy_title"))
		_scene.call(&"_preselect_roster", deploy)
	# 结算宿主出口（持久写入归 interaction epic——容器只做最小闭环）
	var host: Variant = _root.get("settlement_host")
	if host != null:
		host.connect(&"retreat_confirmed", p_retreat)
		host.connect(&"defeat_confirmed", p_defeat)


## 战斗表现层接线（Sprint 18 / DEBT-CBT-018-1 残留闭环）：信号源接
## CombatSystem + DeploymentSystem，HP 终值走 [code]get_character_hp[/code]
## ——UI 不缓存 HP。[br]
## [br][b]降级[/b]：战斗系统不可用时静默跳过（不把「缺数据源」变成崩溃）。
func wire_feedback() -> void:
	var cs: Node = _combat()
	if cs == null:
		return
	var reader: Callable = Callable()
	if cs.has_method(&"get_character_hp"):
		reader = Callable(cs, &"get_character_hp")
	_root.call(&"setup_feedback", cs, _deployment_system(), reader,
			_autoload(&"CardSystem"), _autoload(&"BindingManager"), _reduce_motion())


## 结算回流接线——订阅 battle_ended，把载荷折成 CombatResultView 发布到跨场景
## 缓存（实现见 [code]combat_result_bridge.gd[/code]）。[br]
## [br][b]为什么在场景侧接而不在战斗系统内发布[/b]：战斗系统属 Feature 层，
## 不应知道「有 UI 要显示战绩」；发布时机与展示端同属表现层（ADR-0031 §2）。[br]
## [br][b]返回[/b]：接线实例（战斗系统不可用时 null）。
func wire_result_bridge() -> RefCounted:
	var cs: Node = _combat()
	if cs == null:
		return null
	var bridge: RefCounted = ResultBridgeScript.new()
	bridge.call(&"bind", cs)
	return bridge


## 底部条牌库/弃牌计数订阅——[signal CombatSystem.pile_changed] → 计数组件
## （实现见 [code]combat_deck_wiring.gd[/code]）。[br]
## [br][b]为什么在 [method wire_panels] 之后单独一步[/b]：面板接线负责「组件建好并
## 有信号源」，这一步是「把哪条系统信号接到哪个数字位」的映射——两件事分开后，
## 断链的现场（本债：有组件、有 setter、没人调）一眼可查。[br]
## [br][b]返回[/b]：订阅句柄（任一侧缺失时为 null——容器据此跳过退订）。
func wire_deck_counts() -> RefCounted:
	var cs: Node = _combat()
	var counter: Variant = _deck_counter()
	if cs == null or counter == null:
		return null
	var wiring: RefCounted = DeckWiringScript.new()
	if not bool(wiring.call(&"bind", cs, counter)):
		return null
	return wiring


## 底部条里的计数组件（战场根缺失 / 组件缺失时 null）。
func _deck_counter() -> Control:
	if _root == null:
		return null
	var bar: Variant = _root.get("combat_bottombar")
	if bar == null:
		return null
	var counter: Variant = (bar as Object).get("deck_counter")
	return counter if counter is Control else null


## 出牌交互层 + 手牌供给——装配与开关委托 [code]combat_scene_interaction.gd[/code]
## （手势入口、供牌时机、退订）。
func wire_interaction() -> RefCounted:
	var wiring: RefCounted = InteractionScript.new()
	wiring.call(&"wire", _root, _combat(), _autoload(&"CostSystem"), _reduce_motion())
	return wiring


## 行囊——条目（读真实收藏）/ 效果 / 结算 / 面板四层一次接齐（实现见
## [code]combat_scene_bag.gd[/code]）。[br]
## [br][param p_interaction] 出牌交互接线（开面板时冻结出牌输入）。[br]
## [br][b]取数一律在本层完成[/b]（见 [code]combat_scene_bag.gd[/code] 类文档）：
## 装配点漏接依赖不会报错、只会静默降级，故 Autoload 查表集中在这里，一眼可核。[br]
## [br][b]返回[/b]：挂载模块（退场时 unbind；战场根缺失时为 null）。
func wire_bag(p_interaction: RefCounted) -> RefCounted:
	return BagScript.new().call(&"wire", _root, _combat(), p_interaction,
			_autoload(&"GameStateManager"), _autoload(&"CardSystem"),
			_autoload(&"CostSystem")) as RefCounted


## 焦点记忆接线——把交互层里那一份（挂在焦点链上）交给结算宿主，二者共用。[br]
## [br][b]为什么在行囊之后[/b]：行囊装配时就把它自己那一份接走了（见
## [code]combat_scene_bag.gd[/code] 的 [code]wire[/code] 参数），这里只补结算宿主
## 那一处。[br]
## [br][b]缺交互层时静默跳过[/b]：headless 环境本就没有焦点链，面板照常工作，
## 只是不还原焦点。
func wire_focus_memory(p_interaction: RefCounted) -> void:
	if p_interaction == null or not p_interaction.has_method(&"focus_memory"):
		return
	var memory: Variant = p_interaction.call(&"focus_memory")
	if memory == null:
		return
	var host: Variant = _root.get("settlement_host")
	if host != null and (host as Object).has_method(&"set_focus_memory"):
		host.call(&"set_focus_memory", memory)


## === 容器取数转发 ===========================================================

func _combat() -> Node:
	return _scene.call(&"_combat")


func _deployment_system() -> Node:
	var injected: Variant = _scene.get("deployment_system")
	return injected if injected != null else _autoload(&"DeploymentSystem")


func _reduce_motion() -> bool:
	return bool(_scene.call(&"_read_reduce_motion"))


## Autoload 动态查找（测试环境缺 Autoload 时返回 null——同容器先例）。
func _autoload(p_node_name: StringName) -> Node:
	return AutoloadAccess.find(p_node_name)
