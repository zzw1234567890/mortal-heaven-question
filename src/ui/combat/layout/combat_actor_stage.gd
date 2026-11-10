class_name CombatActorStage
extends Node
## CombatActorStage —— 战场角色卡装配与排布（Sprint 18 / DEBT-CBT-018-1 残留闭环）。
##
## [b]职责[/b]：把「战斗系统持有的敌我名册」变成战场上的 [CharacterStatusCard]，
## 并把这些卡注册进 [CombatFeedbackCoordinator]——此后 HP 条 / 伤害飘字 /
## 阵亡淡出才有真实数据可消费。[br]
## [br][b]出牌入口（本台同时是交互层的唯一取数点）[/b]：[br]
##   - 施法者：[member actor_selection]（[code]CombatActorSelection[/code]）持有
##     「当前操作角色」——玩家可 [method select_actor] 切换，阵亡后自动顺位，
##     出牌桥按它取施法者；[br]
##   - 手牌：[method hand_snapshot] 折出卡面快照（带 [code]target_type[/code]）；[br]
##   - 目标：[method enemy_candidates] 存活敌方候选池；[method enemy_at] 命中测试。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：名册/HP/ATK 一律经
## [code]combat_actor_reader.gd[/code] 现读；建卡瞬间取一次快照做初始渲染
## （节点表在 [code]actor_stage_roster.gd[/code]，是 UI 节点表不是游戏状态副本）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——建卡由 [method build_roster]
## 显式驱动，排布由容器 [signal Control.resized] 驱动。[br]
## [br][b]拆分[/b]：几何排布归 [code]actor_stage_layout.gd[/code]，节点表与建卡归
## [code]actor_stage_roster.gd[/code]（DEBT-CUI-007-2 / 单文件 300 行软上限）。
##
## @experimental
## 来源: ADR-0031、ADR-0008 §Phase 1/Phase 6、design/ux/combat-ui.md §Layout Zones、
## combat-ui-layout Story 002/003、combat-ui-interaction Story 001、DEBT-CBT-018-1。

## 取数入口（名册 / HP / ATK——单一读取链路）。
const ReaderScript := preload("res://src/ui/combat/layout/combat_actor_reader.gd")
## 排布模块（几何 / 行内居中 / resized 重排）。
const LayoutScript := preload("res://src/ui/combat/layout/actor_stage_layout.gd")
## 节点表与建卡（建卡 / 注册 / 阵亡摘除 / 命中测试）。
const RosterScript := preload("res://src/ui/combat/layout/actor_stage_roster.gd")
## UI 出牌桥（DEBT-CBT-018-10 第四阶段——出牌前取施法者再转交 CombatSystem）。
const PlayBridgeScript := preload("res://src/ui/combat/shared/combat_play_bridge.gd")
## 当前操作角色状态（交互 001——显式施法者）。
const ActorSelectionScript := preload("res://src/ui/combat/shared/combat_actor_selection.gd")
## 手牌快照折出（战斗手牌 → 卡面快照，带 target_type）。
const HandSnapshotScript := preload("res://src/ui/combat/shared/combat_hand_snapshot.gd")
## 阶段常量（CombatPhase.PLAY）。
const PLAY_PHASE: int = 2

## 取数入口实例（RefCounted）。
var _reader: RefCounted = ReaderScript.new()
## 节点表与建卡模块。
var _roster: RefCounted = null
## 排布模块（几何 / 行内居中 / resized 重排）。
var _layout: RefCounted = null
## UI 出牌桥（出牌时取施法者——数据源与 [member _reader] 同一组注入）。
var _play_bridge: RefCounted = PlayBridgeScript.new()
## 卡牌系统（手牌快照的模板回退——可空）。
var _card_system: Node = null
## 战斗系统（阶段查询——可空）。
var _combat: Node = null

## 当前操作角色状态（施法者的唯一真理来源——[method setup] 后由阵位刷新）。
var actor_selection: RefCounted = ActorSelectionScript.new()

## === 容器（CombatLayout 的区域）=============================================

var _ally_container: Control = null
var _enemy_container: Control = null


## 构造——建节点表与排布模块（不依赖场景树时序，同 CombatLayout 先例）。
func _init() -> void:
	_roster = RosterScript.new(_reader)
	_layout = LayoutScript.new(self)


## 注入数据源（全部可空——缺失时对应侧不建卡，不抛错）。[br]
## [br][b]顺带刷新当前操作角色[/b]：阵位是「谁上场了」的唯一来源，
## 注入后立即按它筛出候选——出牌前不必再手动接手一次。
func setup(p_combat: Node, p_deployment: Node, p_card_system: Node = null,
		_p_binding_manager: Node = null) -> void:
	_reader.call(&"setup", p_combat, p_deployment, p_card_system)
	_play_bridge.call(&"setup", p_combat, p_deployment)
	_play_bridge.call(&"set_actor_source", actor_selection)
	_combat = p_combat
	_card_system = p_card_system
	_connect_death(p_combat)
	refresh_actors()


## 按我方阵位刷新当前操作角色（开战 / 阵亡 / 换人后调用）。[br]
## [b]返回[/b]: 刷新后的当前角色 ID（判不出为 [constant ActorSelectionScript.NO_ACTOR]）。
func refresh_actors() -> int:
	return int(actor_selection.call(&"refresh", _player_field()))


## 切换当前操作角色（玩家点选我方角色卡）。[br]
## [br][b]只接受上场且未阵亡的角色[/b]——点错不生效，当前角色保持不变。[br]
## [b]返回[/b]: 是否切换成功。
func select_actor(p_character_id: int) -> bool:
	return bool(actor_selection.call(&"select", p_character_id, _player_field()))


## 当前操作角色 ID（无角色为 -1）。
func current_actor_id() -> int:
	return int(actor_selection.call(&"current_id"))


## 可切换的我方角色 ID（候选——UI 据此决定哪些卡可点）。
func actor_candidates() -> Array:
	return actor_selection.call(&"candidates")


## UI 出牌入口——取当前操作角色作施法者后转交 [code]CombatSystem.play_card()[/code]。
func play_card(p_card_instance_id: int, p_target_indices: Array) -> bool:
	return bool(_play_bridge.call(&"play_card", p_card_instance_id, p_target_indices))


## 同上，但带上拒绝原因与提示文本（交互层显示提示用）。[br]
## 目标为空 → 走默认策略（首个存活敌人）；详见 [code]CombatPlayBridge[/code]。
func play_card_detailed(p_card_instance_id: int,
		p_target_indices: Array) -> Dictionary:
	return _play_bridge.call(&"play_card_detailed", p_card_instance_id,
			p_target_indices)


## 解析目标列表而不出牌——UI 在「选中态 → 确认」之间可先问一次合法性。
func resolve_targets(p_explicit: Array) -> Dictionary:
	return _play_bridge.call(&"resolve_targets", p_explicit)


## 敌方候选池（顺序即 UI 建卡顺序——默认目标与命中测试共用同一份顺序）。
func enemy_candidates() -> Array:
	return _play_bridge.call(&"enemy_candidates")


## 当前施法者 ID（出牌桥口径——判不出为 -1）。
func current_caster_id() -> int:
	return int(_play_bridge.call(&"current_caster_id"))


## 出牌桥实例（出牌交互控制器要注入它——本台是桥的唯一持有者）。
func get_play_bridge() -> RefCounted:
	return _play_bridge


## 手牌快照——战斗手牌折成 [code]{card_instance_id, name, cost, rarity, type,
## target_type, affordable}[/code] 数组（交互层的卡面词来源）。[br]
## [br][b]战斗系统不可用 → 空数组[/b]（手牌区显示「无手牌」，不崩）。
func hand_snapshot() -> Array:
	if _combat == null or not _combat.has_method(&"get_hand"):
		return []
	var hand: Variant = _combat.call(&"get_hand")
	if not (hand is Array):
		return []
	return HandSnapshotScript.build(hand, _card_system)


## 当前战斗阶段（战斗系统不可用 → -1；交互层据此判灵能预览）。
func current_phase() -> int:
	if _combat == null or not _combat.has_method(&"get_current_phase"):
		return -1
	return int(_combat.call(&"get_current_phase"))


## 命中测试——全局坐标下的敌方角色 ID（交互层点选目标用）；无命中 -1。
func enemy_at(p_global_pos: Vector2) -> int:
	return int(_roster.call(&"enemy_at", p_global_pos))


## 命中测试——全局坐标下的我方角色 ID（点击切换当前操作角色用）；无命中 -1。
func ally_at(p_global_pos: Vector2) -> int:
	return int(_roster.call(&"ally_at", p_global_pos))


## 指定卡的落地容器（我方区 / 敌方区）。
func set_containers(p_ally: Control, p_enemy: Control) -> void:
	_ally_container = p_ally
	_enemy_container = p_enemy
	_layout.call(&"attach", _ally_container, _enemy_container)


## 绑定反馈编排器——此后新建的卡自动注册（已建卡也补注册）。
func bind_coordinator(p_coordinator: Control) -> void:
	_roster.call(&"bind_coordinator", p_coordinator)


## 构建全部角色卡（开战时调用）。[br]
## [param p_player_ids] 开战配置里的角色 ID（空 → 回退读 DeploymentSystem 阵位）。[br]
## [br][b]先清后建[/b]：重复开战不会残留上一场的卡与注册关系。
func build_roster(p_player_ids: Array = []) -> void:
	clear_roster()
	_roster.call(&"build_side", _reader.call(&"player_entries", p_player_ids),
			_ally_container, _roster.get(&"ally_cards"))
	_roster.call(&"build_side", _reader.call(&"enemy_entries"), _enemy_container,
			_roster.get(&"enemy_cards"))
	refresh_actors()
	_relayout()


## 清空全部角色卡（战斗结束 / 重开战）。[br]
## [b]顺序[/b]：先从反馈编排器注销（防其持有悬空卡引用），再释放节点。
## [b]立即摘父[/b]：只 queue_free 会让节点滞留到帧末，下一场的 card_count /
## 子节点数会读到「上一场的残影」——先 remove_child 再 queue_free。
func clear_roster() -> void:
	_roster.call(&"clear")
	actor_selection.call(&"clear")


## 查询角色卡（测试与交互层命中测试用；卡被移除/释放后返回 null）。
func get_card(character_id: int) -> Control:
	return _roster.call(&"get_card", character_id) as Control


## 已建卡数量（两侧合计——测试断言用）。
func card_count() -> int:
	return int(_roster.call(&"count"))


## 订阅阵亡信号——卡被战斗侧判死后从节点表摘除，并刷新当前操作角色（阵亡顺位）。[br]
## [br][b]与编排器的分工[/b]：动效（淡出→移除→空位框）归
## [code]CombatFeedbackCoordinator[/code]；本台只维护「谁还有卡」的索引，
## 两个消费者各自订阅同一条信号（ADR-0008 §架构原则 #2 信号不承载逻辑）。[br]
## [b]幂等[/b]：已连接则不重复（_connect_once 先例）。
func _connect_death(source: Node) -> void:
	if source == null or not source.has_signal(&"character_died"):
		return
	var handler: Callable = Callable(self, &"_on_character_died")
	if not source.is_connected(&"character_died", handler):
		source.connect(&"character_died", handler)


func _on_character_died(character_id: int, _side: int, _ids: Array) -> void:
	if bool(_roster.call(&"forget", character_id)):
		refresh_actors()


## 我方阵位快照（部署系统不可用时为空数组——当前角色刷新为「无」）。
func _player_field() -> Array:
	var raw: Variant = _reader.call(&"player_field")
	return raw if raw is Array else []


# === 排布（几何归 actor_stage_layout.gd）=====================================

## 重排两侧全部卡（容器 resized 与建卡后调用）。
func _relayout() -> void:
	_layout.call(&"relayout", _roster.get(&"ally_cards"),
			_roster.get(&"enemy_cards"), _ally_container, _enemy_container)
