extends RefCounted
## DeploymentSerializer —— 阵位序列化/反序列化/快照导出子模块（从 deployment_system.gd 拆分）。
##
## 持有对 DeploymentSystem 父节点的引用，通过它访问 _field / _unavailable_characters。[br]
## [br]来源: ADR-0016 §GSM 边界 / GDD deployment-system.md §快照导出。[br]
## [br]Sprint 9 Story 1：从 deployment_system.gd 拆分。

## 父节点引用——DeploymentSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 战斗结束时序列化阵位——导出纯 Dictionary 快照至 GSM.battle.deployment_snapshot。[br]
## [br]6 个阵位逐槽序列化，state 用 FieldState 枚举名 String 序列化（可读性 + 前向兼容）。[br]
## [br][b]返回[/b]: [code]{slot_index: {character_id, is_front, state, deploy_turn}, ...}[/code]——
## 纯原始类型，无 RefCounted/Node 引用（可直接 JSON 序列化）。[br]
## [br]来源: ADR-0016 §关键接口 serialize_field。
func serialize_field() -> Dictionary:
	var result: Dictionary = {}
	var slot_count: int = _parent.get("SLOT_COUNT")
	var field: Dictionary = _parent.get("_field")
	for slot in range(slot_count):
		var entry: Dictionary = field[slot]
		result[slot] = {
			"character_id": entry["character_id"],
			"is_front": entry["is_front"],
			"state": _parent.call("_state_to_string", entry["state"]),
			"deploy_turn": entry["deploy_turn"],
		}
	return result


## 从快照恢复阵位——读档 / 战斗快照恢复入口。[br]
## [br]快照格式同 [method serialize_field] 输出。[br]
## [br][b]安全处理[/b]：空/无效 data 不崩溃——缺字段的 slot 用空位默认值填充；缺 slot 保持空位。[br]
## [br][b]键归一[/b]：内存快照用 int key，JSON round-trip 后 key 变 String——两者均接受（避免读档静默丢阵位）。[br]
## [br][param data] [method serialize_field] 输出的快照 Dictionary。
func deserialize_field(data: Dictionary) -> void:
	_parent.call("_reset_field")
	if data.is_empty():
		return  # 空快照——保持全空阵位
	var slot_count: int = _parent.get("SLOT_COUNT")
	var field: Dictionary = _parent.get("_field")
	for slot in range(slot_count):
		# 键归一：内存快照用 int key，JSON round-trip 后 key 变 String——两者均接受（C-1 修复）
		var entry: Variant = null
		if data.has(slot):
			entry = data[slot]
		elif data.has(str(slot)):
			entry = data[str(slot)]
		else:
			continue  # 缺 slot——保持空位
		if not entry is Dictionary:
			continue  # 非法 entry——保持空位
		var cid: int = int(entry.get("character_id", -1))
		var is_front: bool = bool(entry.get("is_front", _parent.call("_is_front", slot)))
		var state: int = _parent.call("_state_from_string", entry.get("state", "EMPTY"))
		var deploy_turn: int = int(entry.get("deploy_turn", -1))
		field[slot] = {
			"character_id": cid,
			"is_front": is_front,
			"deploy_turn": deploy_turn,
			"state": state,
		}


## 战斗结束时同步不可用角色列表至 GSM——存档持久化入口。[br]
## [br]GSM 不可用时静默跳过（is_instance_valid + has_method 双守卫）。[br]
## [br]来源: ADR-0016 §不可用角色生命周期 §跨战斗持久。
func sync_unavailable_to_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("_set_player_unavailable_characters"):
		return  # GSM 不可用——静默跳过
	var unavailable: Dictionary = _parent.get("_unavailable_characters")
	gsm.call("_set_player_unavailable_characters", unavailable.duplicate(true))


## 从 GSM 存档数据恢复不可用角色列表——读档时。[br]
## [br][b]安全处理[/b]：非法 entry（非 Dictionary）跳过，缺字段填充默认值。[br]
## [br][param data] GSM.player.unavailable_characters 快照 Dictionary。
func load_unavailable_from_gsm(data: Dictionary) -> void:
	var unavailable: Dictionary = _parent.get("_unavailable_characters")
	unavailable.clear()
	for cid: Variant in data.keys():
		var entry: Variant = data[cid]
		if not entry is Dictionary:
			continue  # 非法 entry——跳过
		unavailable[int(cid)] = {
			"death_turn": int(entry.get("death_turn", 0)),
			"death_battle_id": str(entry.get("death_battle_id", "")),
			"revival_methods": entry.get("revival_methods", []),
		}


## 写阵位快照至 GSM battle.deployment_snapshot（战斗结束导出委托）。[br]
## [br]GSM 不可用时静默跳过（is_instance_valid + has_method 双守卫）。[br]
## [br]来源: ADR-0016 §GSM 边界 §snapshot 导出。
func write_snapshot_to_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("_set_battle_deployment_snapshot"):
		return  # GSM 不可用——静默跳过
	gsm.call("_set_battle_deployment_snapshot", serialize_field())


## 动态获取 GSM Autoload 节点。[br]
## [br]用 SceneTree.root 查找而非硬引用全局名——避免测试环境无 Autoload 时崩溃
## （同 StatusEffectSystem._get_gsm 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")
