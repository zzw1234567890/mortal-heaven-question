extends "res://tests/integration/exploration_ui/one_run_smoke_fixture.gd"
## OneRunBattleFixture —— 「从节点图走到战斗」这一段用例的共享装置。[br]
## [br][b]为什么再拆一层[/b]：主装置已含前四步（主菜单 / 身份 / 探索 / 进图），
## 加上战斗这一段就会越过 300 行软上限（.claude/docs/coding-standards.md）。
## 战斗段的动作（点格 → 弹窗 → 确认开战 → 打完 → 回选图）自成一组，
## 且只有战斗相关用例需要它们。[br]
## [br][b]文件前缀[/b]：不以 [code]test_[/code] 开头——只作基类被继承。[br]
## [br][b]场景管理器用桩[/b]：装配器按 [code]/root/SceneManager[/code] 取生产实例，
## 而确认进战斗会真的换场景、拆掉 GUT 的测试树。宿主重注入一次即可把出口指到桩
## （见 [method prepare_battle_path]）。[br]
##
## 来源: design/gdd/exploration-system.md §4/§5、design/gdd/combat-system.md §2、
## design/gdd/exploration-ui-system.md §4b、ADR-0005、ADR-0014 §决策 3/5。

## 节点交互规则常量（弹窗种类词的真理来源）。
const RulesScript := preload("res://src/ui/exploration/node_interaction_rules.gd")
## 解锁门禁（前置通关判定的单点——用例不自己比地图 ID）。
const GateScript := preload("res://src/feature/exploration/exploration_map_gate.gd")

## 首图首通彩头卡的模板 ID（[code]exploration_first_clear_rewards.gd[/code] LOW 档）。
const FIRST_CLEAR_CARD: StringName = &"pei_yuan_dan"


func before_each() -> void:
	super()
	PrimerScript.prime(CardSystem, FIRST_CLEAR_CARD)
	var database: Dictionary = gsm.get("_card_template_database")
	database[str(FIRST_CLEAR_CARD)] = database.get(str(FIRST_CLEAR_CARD), {})
	gsm.set("_card_template_database", database)


func after_each() -> void:
	await super()


# ═══════════════════════════════════════════════════════════════════════════════
# 点格 → 弹窗
# ═══════════════════════════════════════════════════════════════════════════════

## 点一格节点（走交互组件的真实提交入口）。[br]
## [br][b]为什么经 [code]request_move[/code][/b]：它才是点击路径的落地方法
## （[code]_on_renderer_input[/code] 命中测试的下一跳），且负责「动画期间入缓冲」
## 与失败反馈。直调 [code]move_to_node[/code] 会跳过这两层。
func click_node(p_node_id: int) -> void:
	var interactor: Node = _mounted(&"NodeMoveInteractor")
	assert_not_null(interactor, "前置：节点图应挂载交互组件（点击路径的前提）")
	interactor.call(&"request_move", p_node_id)


## 确认当前弹窗（生产由弹窗的 [code]confirmed[/code] 信号驱动，这里走同一入口）。
func confirm_popup() -> void:
	var host: Node = popup_host()
	assert_not_null(host, "前置：弹窗宿主已挂载")
	host.call(&"_on_confirmed")


## 节点图下的弹窗宿主（S17-006 挂载点）。
func popup_host() -> Node:
	return _mounted(&"NodeInteractionPopupHost")


## 当前弹窗种类（无弹窗时为 [code]KIND_NONE[/code]）。
func popup_kind() -> StringName:
	var host: Node = popup_host()
	return RulesScript.KIND_NONE if host == null \
			else StringName(str(host.call(&"get_open_kind")))


## 弹窗正文（弹窗不可用时为空串）。[br]
## [br][b]为什么读控件树里的 "Body"[/b]：弹窗没有 [code]body_text()[/code] 访问器
## ——[method NodeInteractionPopup.open] 把文本直接写进标签
## （node_interaction_popup.gd:133）。标签名是 [code]_build[/code] 写死的稳定契约，
## 比为一个只给测试用的访问器开接口更不容易腐坏。
func popup_body() -> String:
	var host: Node = popup_host()
	if host == null:
		return ""
	var popup: Variant = host.call(&"_popup")
	if popup == null:
		return ""
	var label: Variant = (popup as Node).get_node_or_null(NodePath("Body"))
	return "" if label == null else str((label as Label).text)


# ═══════════════════════════════════════════════════════════════════════════════
# 装配调整（转场改道 + 关动画）
# ═══════════════════════════════════════════════════════════════════════════════

## 把弹窗宿主的场景管理器换成桩，并关掉全部动画。[br]
## [br][b]为什么在挂载后重注入[/b]：装配器按 [code]/root/SceneManager[/code] 取
## 生产实例；[method NodeInteractionPopupHost.setup] 幂等，重调一次即可改道。[br]
## [br][b]为什么必须关动画[/b]：默认偏好从 SettingsStore 读，开着时移动动画 0.4s，
## 到达通知要等动画结束才转发——断言会跑在弹窗弹出之前。
func prepare_battle_path() -> void:
	enable_instant_motion()
	var host: Node = popup_host()
	assert_not_null(host, "前置：弹窗宿主已挂载")
	var screen: Variant = node_graph()
	host.call(&"setup", screen.call(&"renderer"), screen.get(&"viewport"), es,
			mock_sm, get_node_or_null(NodePath("/root/RealmSystem")))


## 关掉交互组件与弹窗宿主的动画（移动直跳终位、到达通知同步转发）。
func enable_instant_motion() -> void:
	var screen: Variant = node_graph()
	if screen == null:
		return
	var interactor: Node = _mounted(&"NodeMoveInteractor")
	if interactor != null:
		interactor.call(&"set_reduce_motion", true)
	var host: Node = popup_host()
	if host != null:
		host.call(&"set_reduce_motion", true)
	screen.set(&"animate", false)


## 节点图下名为 [param p_name] 的挂载子节点。
func _mounted(p_name: StringName) -> Node:
	var screen: Variant = node_graph()
	if screen == null:
		return null
	return screen.get_node_or_null(NodePath(String(p_name)))


# ═══════════════════════════════════════════════════════════════════════════════
# 走到 Boss
# ═══════════════════════════════════════════════════════════════════════════════

## 用真实点击路径从入口一路走到 Boss 节点。[br]
## [br][b]逐跳断言受理[/b]：不接受静默失败——某跳被拒（不可达 / 已访问 / 行动力不足）
## 就地失败，错误信息带上那一跳与拒绝理由。[br]
## [br][b]返回[/b]：走过的节点序列（不含入口）。
func walk_to_boss() -> Array[int]:
	var boss: int = boss_node_id()
	assert_true(boss > 0, "前置：地图应有 Boss 节点")
	var path: Array[int] = path_to(boss)
	assert_true(path.size() > 0, "应存在一条从入口到 Boss 的路径")
	for hop: int in path:
		click_node(hop)
		assert_true(visited().has(hop),
				"点第 %d 格应被受理（已访问=%s，AP=%d）" % [hop, str(visited()), ap()])
	return path


# ═══════════════════════════════════════════════════════════════════════════════
# 打完这场仗
# ═══════════════════════════════════════════════════════════════════════════════

## 跨场景缓存里待消费的开战上下文（未发布时为空字典）。
func launch_context() -> Dictionary:
	return LaunchScript.peek()


## 本图在 [code]map_states[/code] 里的通关计数。
func clear_count(p_map_id: StringName = &"") -> int:
	return int(map_state(p_map_id).get("clear_count", 0))


func is_first_clear(p_map_id: StringName = &"") -> bool:
	return bool(map_state(p_map_id).get("is_first_clear", false))


## 收藏里某模板的实例数。
func owned_count_of(p_template_id: StringName) -> int:
	var count: int = 0
	for card: Variant in gsm.collection.owned_cards:
		if str((card as Dictionary).get("template_id", "")) == str(p_template_id):
			count += 1
	return count


## 本境界的出战人数上限（只读查询——不推算境界数值）。
func max_deploy_limit() -> int:
	var realm_system: Node = get_node_or_null(NodePath("/root/RealmSystem"))
	return int(realm_system.call(&"get_current_property", &"max_deploy")) \
			if realm_system != null else 1


## 各图通关态集合 [code]{地图ID: 是否已通关}[/code]（解锁门禁的入参）。[br]
## [br][b]与界面同一份口径[/b]：[code]ExplorationMapList[/code] 先算这个集合再逐条
## 求值——用例照做，避免逐图现读出现「同一屏里两处读法不一致」。
func cleared_flags() -> Dictionary:
	var out: Dictionary = {}
	for raw_id: Variant in catalog_ids():
		var map_id: StringName = StringName(str(raw_id))
		out[map_id] = bool(map_state(map_id).get("is_first_clear", false))
	return out


## 选图界面上 [param p_map_id] 那一张卡（探明表里没有它时为空字典）。[br]
## [br][b]读 [code]get_map_list[/code] 而不是现算[/b]：那正是界面渲染消费的条目
## （[code]map_select_data.gd:35[/code]），「卡上显示什么」与「用例断言什么」
## 因此是同一份数据——解锁态在界面上怎么变，这里就怎么变。
func map_entry(p_map_id: StringName) -> Dictionary:
	for entry: Variant in es.call(&"get_map_list"):
		if entry is Dictionary and StringName(str((entry as Dictionary).get("map_id", ""))) == p_map_id:
			return entry as Dictionary
	return {}


## 首图的后置地图（[code]unlock_after_clear[/code] 指向首图的那一张）。[br]
## [br][b]从探明表现查[/b]：不写死「血渊秘境」的字面 ID——表改了用例跟着走。
func next_gated_map_id() -> StringName:
	for raw_id: Variant in catalog_ids():
		var map_id: StringName = StringName(str(raw_id))
		if GateScript.prerequisite_of(map_id) == first_map_id():
			return map_id
	return &""
