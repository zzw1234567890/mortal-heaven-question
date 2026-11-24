## GameStateManager.GSMAtomicWrites —— 第二层原子写入方法（提取自 game_state_manager.gd）。[b]链尾[/b]。
##
## 持有对 GSM 父节点的引用，提供全部第二层原子写入方法——修为、资源、战斗、
## 身份、境界、轮回、卡牌收藏、输入锁、场景、剧情 flag、行动力、天赋、章节。
## 每个方法写入数据后通过 [method GameStateManager._buffer_change] 进入帧末信号缓冲管线。
##
## [b]本层职责[/b]：会话域写入 + 三个子域子模块的委托转发面。[br]
##   · 会话域——[method set_input_locks]（InputManager 锁栈的 GSM 镜像）、
##     [method set_session_scene]（SceneManager 独占写入授权，ADR-0005）；[br]
##   · 探索域——[method restore_action_points] 与 7 条 [code]GSMExplorationWrites[/code] 转发；[br]
##   · 战斗域——17 条 [code]GSMBattleWrites[/code] 转发（Sprint 8 Story 8-11 拆分）；[br]
##   · 叙事域——6 条 [code]GSMNarrativeWrites[/code] 转发（Sprint 12 Story 012 拆分）。
##
## [b]为什么 [method restore_action_points] 住这里[/b]：它写的是
## [code]exploration.action_points[/code]，上限也在同一域（ADR-0014）——放进「通用区」
## 会让「探索域写入」散成两处。
##
## [b]路径即契约[/b]：[code]game_state_manager.gd[/code] 按
## [code]res://src/foundation/gsm/gsm_atomic_writes.gd[/code] 这一串字符 [code]load[/code]，
## 故本文件必须留在链尾、文件名逐字不动。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  gsm_atomic_writes_contract.gd  [/code] ← 接缝：4 字段 + init[br]
## [code]  gsm_atomic_writes_player.gd    [/code] ← 玩家域：修为 / 资源 / 身份 / 境界 / 轮回 / 天赋 / 渡劫[br]
## [code]  gsm_atomic_writes_collection.gd[/code] ← 收藏域：实例 ID / 收藏增删 / 模板校验[br]
## [code]  gsm_atomic_writes_deck.gd      [/code] ← 卡组域：卡组 / 阵位 / 变更日志 / 上限修正 / 散功计数[br]
## [code]  gsm_atomic_writes.gd           [/code] ← 本层：会话域 + 三域子模块委托转发[br]
##
## [b]提取原因[/b]：game_state_manager.gd 1080 行 → 拆分（Story 3-9 技术债，Sprint 1 回顾行动项 #2）。
##
## 来源: ADR-0001 §第二层原子写入 + 各系统 ADR 的 GSM 集成合约。

extends "res://src/foundation/gsm/gsm_atomic_writes_deck.gd"


## 设置输入锁栈——仅 [b]InputManager[/b] 调用。[br]
## [br]写入 [code]session.input_locks[/code] 并通过 [signal GameStateManager.batch_updated] 传播变更。[br]
## [br][param locks] [code]Array[Dictionary][/code]——每个元素 [code]{type: int, source: StringName, device_mask: int}[/code]。
func set_input_locks(locks: Array[Dictionary]) -> void:
	var old: Array = _gsm.session.input_locks.duplicate(true)
	_gsm.session.input_locks = locks.duplicate(true)
	_gsm._buffer_change("session.input_locks", old, _gsm.session.input_locks)


## 设置当前场景——仅 [b]SceneManager[/b] 调用（ADR-0005 独占写入授权）。[br]
## [br]写入 [code]session.scene_id[/code] 和 [code]session.current_scene[/code]，
## 通过 [signal GameStateManager.batch_updated] 传播 [signal GameStateManager.scene_changed]。
func set_session_scene(id: int, path: String) -> void:
	var old_id: int = _gsm.session.get("scene_id", 0)
	var old_path: String = _gsm.session.get("current_scene", "")
	_gsm.session.scene_id = id
	_gsm.session.current_scene = path
	_gsm._buffer_change("session.scene_id", old_id, id)
	_gsm._buffer_change("session.current_scene", old_path, path)


## 恢复行动力——委托 → [GSMExplorationWrites]（与同域的 set_exploration_ap 同处）。[br]
## [br][b]为什么归探索域[/b]：写的是 [code]exploration.action_points[/code]，
## 上限也在同一域（ADR-0014）——放在本文件的通用区会让「探索域写入」散成两处。[br]
## [br][b]实现见[/b] [method GSMExplorationWrites.restore_action_points]（含夹上限口径）。
func restore_action_points(amount: int) -> void:
	_exploration_writes.restore_action_points(amount)


# === 探索导航域写入（委托 → GSMExplorationWrites）===========================

func set_exploration_map(map_id: StringName) -> void:
	_exploration_writes.set_exploration_map(map_id)
func set_exploration_position(layer: int, idx: int) -> void:
	_exploration_writes.set_exploration_position(layer, idx)
func reset_exploration_visited(p_initial: Array) -> void:
	_exploration_writes.reset_exploration_visited(p_initial)
func add_visited_node(node_id: int) -> void:
	_exploration_writes.add_visited_node(node_id)
func set_exploration_ap(current: int, max_ap: int) -> void:
	_exploration_writes.set_exploration_ap(current, max_ap)
func update_exploration_map_state(map_id: StringName, changes: Dictionary) -> void:
	_exploration_writes.update_exploration_map_state(map_id, changes)
func clear_exploration_navigation() -> void:
	_exploration_writes.clear_exploration_navigation()


# === 叙事域写入（委托 → GSMNarrativeWrites，Sprint 12 Story 012 拆分）=========

func set_narrative_flag(flag: StringName, value: Variant) -> void:
	_narrative_writes.set_narrative_flag(flag, value)
func advance_chapter(chapter_id: StringName) -> void:
	_narrative_writes.advance_chapter(chapter_id)
func add_required_event_completion(event_id: StringName) -> void:
	_narrative_writes.add_required_event_completion(event_id)
func set_narrative_boss_unlocked(value: bool) -> void:
	_narrative_writes.set_narrative_boss_unlocked(value)
func set_narrative_boss_defeated(value: bool) -> void:
	_narrative_writes.set_narrative_boss_defeated(value)
func set_ending_chosen(branch_id: StringName) -> void:
	_narrative_writes.set_ending_chosen(branch_id)


## 原子写入战斗费用——仅 CostSystem 调用（从 CombatSystem 委托写入权）。[br]
## [br][b]窄范围[/b]：仅写入 battle.current_cost / battle.max_cost——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0015 §GSM 第二层扩展。
# === 战斗域写入（委托 → GSMBattleWrites）===================================

func _set_battle_cost(current_cost: int, max_cost: int) -> void:
	_battle_writes._set_battle_cost(current_cost, max_cost)
func _set_battle_status_snapshot(snapshot: Array) -> void:
	_battle_writes._set_battle_status_snapshot(snapshot)
func _set_battle_deployment_snapshot(snapshot: Dictionary) -> void:
	_battle_writes._set_battle_deployment_snapshot(snapshot)
func _set_player_unavailable_characters(data: Dictionary) -> void:
	_battle_writes._set_player_unavailable_characters(data)
func _set_player_character_hp(character_id: int, hp: Dictionary) -> void:
	_battle_writes._set_player_character_hp(character_id, hp)
func _set_battle_bindings(snapshot: Array) -> void:
	_battle_writes._set_battle_bindings(snapshot)
func _set_battle_formation_snapshot(snapshot: Dictionary) -> void:
	_battle_writes._set_battle_formation_snapshot(snapshot)
func _set_battle_phase(phase: int) -> void:
	_battle_writes._set_battle_phase(phase)
func _increment_battle_turn() -> void:
	_battle_writes._increment_battle_turn()
func _set_battle_turn(turn: int) -> void:
	_battle_writes._set_battle_turn(turn)
func _set_battle_active(active: bool) -> void:
	_battle_writes._set_battle_active(active)
func _set_battle_resume(resume: Dictionary) -> void:
	_battle_writes._set_battle_resume(resume)
func battle_start(config: Dictionary) -> void:
	_battle_writes.battle_start(config)
func battle_end(result: Dictionary) -> void:
	_battle_writes.battle_end(result)
