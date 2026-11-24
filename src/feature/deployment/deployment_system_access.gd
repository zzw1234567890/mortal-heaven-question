## DeploymentSystem 接缝层（继承链第 3 段）——[b]与外部世界的接触面[/b]。
##
## [b]本层职责[/b]：[br]
##   · 6 个信号出口包装（[method _emit_character_deployed] 等）——转发
##     [code]deployment_emitter.gd[/code]，后者经 GSM 的 [code]_emit_signal_safe[/code]
##     路由（ADR-0007）；[br]
##   · [method _get_gsm]——用 [method SceneTree.root] 查找而非硬引用全局名，避免测试环境
##     无 Autoload 时崩溃（同 [code]StatusEffectSystem._get_gsm[/code] 先例）；[br]
##   · 3 个子模块惰性 getter（序列化 / 阵位分配 / 信号发射）——[code]null[/code] 时按需
##     [code]load().new(self)[/code]。[br]
##
## [b]为什么信号出口住这一层而非链尾[/b]：GDScript 要求被调标识符在[b]本段或祖先段[/b]可见
## （探针实测：基段直接调用派生段的方法是解析期错误），而发射这些信号的
## [code]deployment_system_battle_ops.gd[/code] 与
## [code]deployment_system_unavailable.gd[/code] 都排在链的靠后位置——故出口必须更靠前。[br]
##
## [b]本层不持状态[/b]：3 个子模块引用全在
## [code]deployment_system_fields.gd[/code]，沿链可见。[br]
##
## 来源: ADR-0016 §信号 / ADR-0007 §_emit_signal_safe / .claude/docs/coding-standards.md §文件行数限制。

extends "res://src/feature/deployment/deployment_system_fields.gd"

# === 信号发射包装（委托 → DeploymentEmitter，Sprint 12 Story 018 拆分）============

func _emit_character_deployed(character_id: int, slot_index: int, is_front: bool, deploy_turn: int) -> void:
	_get_emitter().emit_character_deployed(character_id, slot_index, is_front, deploy_turn)

func _emit_character_removed(character_id: int, slot_index: int, reason: String) -> void:
	_get_emitter().emit_character_removed(character_id, slot_index, reason)

func _emit_front_line_breached() -> void:
	_get_emitter().emit_front_line_breached()

func _emit_standby_cleared(character_ids: Array) -> void:
	_get_emitter().emit_standby_cleared(character_ids)

func _emit_character_unavailable(character_id: int) -> void:
	_get_emitter().emit_character_unavailable(character_id)

func _emit_character_revived(character_id: int) -> void:
	_get_emitter().emit_character_revived(character_id)

## 动态获取 GSM Autoload 节点。[br]
## [br]用 SceneTree.root 查找而非硬引用全局名——避免测试环境无 Autoload 时崩溃
## （同 StatusEffectSystem._get_gsm 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 惰性获取序列化子模块（Sprint 9 Story 1 拆分）。
func _get_serializer() -> RefCounted:
	if _serializer == null:
		_serializer = load("res://src/feature/deployment/deployment_serializer.gd").new(self)
	return _serializer


## 惰性获取阵位分配子模块（Sprint 9 Story 1 拆分）。
func _get_slot_allocator() -> RefCounted:
	if _slot_allocator == null:
		_slot_allocator = load("res://src/feature/deployment/deployment_slot_allocator.gd").new(self)
	return _slot_allocator


## 惰性获取信号发射子模块（Sprint 12 Story 018 拆分）。
func _get_emitter() -> RefCounted:
	if _emitter == null:
		_emitter = load("res://src/feature/deployment/deployment_emitter.gd").new(self)
	return _emitter
