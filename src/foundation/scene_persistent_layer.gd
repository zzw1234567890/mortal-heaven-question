extends RefCounted
## ScenePersistentLayer —— SceneManager 持久层子模块（hud Story 001，GAP-2 裁决）。
##
## 管理 PersistentLayer 节点的创建与跨场景持久节点的注册
## （ADR-0031 §1.2 契约）。[br]
## [br][b]挂载位置说明[/b]：ADR-0031 §1.2 表述为「root 直挂的 Node」。
## 本实现将 PersistentLayer 挂为 SceneManager（Autoload）的子节点——
## [code]change_scene_to_file()[/code] 仅释放 [code]current_scene[/code]
## （root 的子节点），Autoload 及其子节点不被销毁，持久性等价；
## 且避免 [method _ready] 阶段对 [code]get_tree().root[/code] 的时序依赖。
##
## [br]来源: ADR-0031 §1.2（表现层架构基线——持久层挂载结构）。

## SceneManager 父节点引用（Autoload 实例）。
var _parent: Node = null

## PersistentLayer 节点（幂等创建——重复调用复用同一节点）。
var _layer: Node = null

## PersistentLayer 节点名（ADR-0031 §1.2 命名契约）。
const LAYER_NAME: StringName = &"PersistentLayer"


## 构造——传入 SceneManager 父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 确保 PersistentLayer 存在（幂等）。[br]
## 已存在同名子节点时复用（防御 [code]_ready()[/code] 被手动调用后
## 节点再次进树导致的重复调用）。
func ensure_layer() -> Node:
	if _layer != null and is_instance_valid(_layer):
		return _layer
	if _parent != null:
		var existing: Node = _parent.get_node_or_null(NodePath(LAYER_NAME))
		if existing != null:
			_layer = existing
			return _layer
	if _parent == null:
		push_error("ScenePersistentLayer: 无父节点引用——无法创建 PersistentLayer")
		return null
	var node := Node.new()
	node.name = LAYER_NAME
	_parent.add_child(node)
	_layer = node
	return _layer


## 获取 PersistentLayer 节点（未创建时返回 null——不触发创建）。
func get_layer() -> Node:
	return _layer


## 注册跨场景持久节点——add_child 到 PersistentLayer。[br]
## [br][b]防呆规则[/b]（重复注册记录警告）：[br]
##   - [param node] 为 null → push_error，忽略[br]
##   - [param node] 已注册于本层 → push_warning，忽略（幂等）[br]
##   - [param node] 已有其他父节点 → push_error，忽略（add_child 会失败）[br]
##   - 同名不同节点已存在 → push_warning，仍添加（Godot 自动重命名）
func register(node: Node) -> void:
	if node == null:
		push_error("PersistentLayer.register: node 为 null")
		return
	var layer: Node = ensure_layer()
	if layer == null:
		return
	if node.get_parent() == layer:
		push_warning("PersistentLayer.register: 节点 '%s' 已注册——忽略重复注册" % node.name)
		return
	if node.get_parent() != null:
		push_error("PersistentLayer.register: 节点 '%s' 已有父节点——先移除后再注册" % node.name)
		return
	if layer.has_node(NodePath(node.name)):
		push_warning("PersistentLayer.register: 同名节点 '%s' 已存在——新节点将被自动重命名" % node.name)
	layer.add_child(node)
